import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:trying_flutter_app/image_detection_page.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context){
    return const MaterialApp(
      home: ImageDetectionPage()
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Top-level isolate function — must be top-level for compute()
// ─────────────────────────────────────────────────────────────
Future<String> _runBreedInference(Map<String, dynamic> args) async {
  final bytes      = args['bytes']      as Uint8List;
  final labels     = args['labels']     as List<String>;
  final modelBytes = args['modelBytes'] as Uint8List;  // 👈 receive bytes

  final decoded = img.decodeImage(bytes);
  if (decoded == null) return 'Error';

  final resized = img.copyResize(decoded, width: 224, height: 224);

  final input = List.generate(
    1,
    (_) => List.generate(
      224,
      (y) => List.generate(224, (x) {
        final pixel = resized.getPixel(112, 112);
        print('R:${pixel.r} G:${pixel.g} B:${pixel.b}');
        return [
          (pixel.r / 127.5) - 1.0,
          (pixel.g / 127.5) - 1.0,
          (pixel.b / 127.5) - 1.0,
        ];
      }),
    ),
  );

  // ✅ fromBuffer works in isolates — no Flutter binding needed
  final interpreter = Interpreter.fromBuffer(modelBytes);
  final output = [List.filled(labels.length, 0.0)];
  interpreter.run(input, output);
  interpreter.close();

  final probs    = List<double>.from(output[0]);
  final top5 = (List.generate(probs.length, (i) => i)
    ..sort((a, b) => probs[b].compareTo(probs[a])))
    .take(5)
    .map((i) => '${labels[i]}: ${(probs[i]*100).toStringAsFixed(1)}%')
    .join(', ');
  print('[Inference] Top 5: $top5');
  final topIndex = probs.indexOf(probs.reduce((a, b) => a > b ? a : b));
  final topConf  = (probs[topIndex] * 100).toStringAsFixed(1);
  return '${labels[topIndex]} ($topConf%)';
}

// ─────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────
class LivePetDetectionScreen extends StatefulWidget {
  const LivePetDetectionScreen({super.key});

  @override
  State<LivePetDetectionScreen> createState() =>
      _LivePetDetectionScreenState();
}

class _LivePetDetectionScreenState
    extends State<LivePetDetectionScreen> {

  // ── Debug logger ───────────────────────────────────────────
  static const bool _kDebug = true;
  int _logThrottle = 0;

  void _log(String msg) {
    if (_kDebug) debugPrint('[PetDetect] $msg');
  }

  // ── YOLO ───────────────────────────────────────────────────
  final YOLOViewController _yoloController = YOLOViewController();
  List<YOLOResult> _detections = [];
  double _fps = 0;
  int petCount = 0;
  final GlobalKey _cameraKey = GlobalKey();
  Uint8List? _modelBytes;

  // ── Breed classifier ───────────────────────────────────────
  List<String> _labels         = [];
  bool         _classifierReady = false;

  // ── Classification state ───────────────────────────────────
  final Map<int, String> _breedResults  = {};
  bool _isClassifying                   = false;
  int  _framesSincePet                  = 0;
  static const _classifyEveryNFrames    = 10;   // ~1 classify/sec at 10fps

  // ── Lifecycle ──────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadLabels();
      await _initYoloController();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ── Load labels only (no Interpreter here — isolate loads it) ──
  Future<void> _loadLabels() async {
    try {
      final raw = await DefaultAssetBundle.of(context)
          .loadString('assets/models/labels.txt');
      _labels = raw
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      final modelData = await DefaultAssetBundle.of(context)
          .load('assets/models/pet_breed_model.tflite');
      _modelBytes = modelData.buffer.asUint8List();

      setState(() => _classifierReady = true);
      _log('✅ Labels (${_labels.length}) and model bytes loaded');
    } catch (e) {
      _log('❌ Load error: $e');
    }
  }

  // ── YOLO controller thresholds ─────────────────────────────
  Future<void> _initYoloController() async {
    try {
      await _yoloController.setConfidenceThreshold(0.15);
      await _yoloController.setIoUThreshold(0.45);
      _log('✅ YOLO thresholds set');
    } catch (e) {
      _log('⚠️ Could not set YOLO thresholds: $e');
    }
  }

  // ── Crop bounding box region from a full frame ─────────────
  Future<Uint8List?> _cropRegion(
      Uint8List frameBytes, Rect normalizedBox) async {
    try {
      final decoded = img.decodeImage(frameBytes);
      if (decoded == null) return null;

      final x = (normalizedBox.left   * decoded.width ).toInt()
          .clamp(0, decoded.width  - 1);
      final y = (normalizedBox.top    * decoded.height).toInt()
          .clamp(0, decoded.height - 1);
      final w = (normalizedBox.width  * decoded.width ).toInt()
          .clamp(1, decoded.width  - x);
      final h = (normalizedBox.height * decoded.height).toInt()
          .clamp(1, decoded.height - y);

      final cropped = img.copyCrop(
          decoded, x: x, y: y, width: w, height: h);
      return img.encodePng(cropped);
    } catch (e) {
      _log('Crop error: $e');
      return null;
    }
  }

  // ── Classify a cropped image via isolate ───────────────────
  Future<String> _classifyBreed(Uint8List cropBytes) async {
    if (_labels.isEmpty || _modelBytes == null) return 'Loading...';
    try {
      return await compute(_runBreedInference, {
        'bytes':       cropBytes,
        'labels':      _labels,
        'modelBytes':  _modelBytes!,
      });
    } catch (e) {
      _log('Classify error: $e');
      return 'Error';
    }
  }
  
  Future<Uint8List?> _captureFrame() async {
    try {
      final boundary = _cameraKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      // Wait for next frame to avoid mid-render capture
      await Future.delayed(Duration.zero);

      final image    = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      image.dispose();
      return byteData?.buffer.asUint8List();
    } catch (e) {
      _log('Frame capture error: $e');
      return null;
    }
  }

  // ── Main YOLO result handler ───────────────────────────────
  Future<void> _onYoloResult(List<YOLOResult> results) async {
    // Throttled logging — once per 30 frames
    _logThrottle++;
    if (_logThrottle % 30 == 0) {
      for (final r in results) {
        _log('${r.className} | ${(r.confidence * 100).toStringAsFixed(1)}%');
      }
    }

    setState(() => _detections = results);

    // Filter pets — log exact names to verify
    final pets = results.asMap().entries.where((e) {
      final name = e.value.className.toLowerCase().trim();
      return name == 'cat' || name == 'dog';
    }).toList();

    if (_logThrottle % 30 == 0) {
      _log('🐾 Pets in frame: ${pets.length}');
    }

    // Throttle classification — only every N frames
    _framesSincePet++;
    if (pets.isEmpty ||
        _framesSincePet < _classifyEveryNFrames ||
        _isClassifying ||
        !_classifierReady) return;

    _framesSincePet = 0;
    _isClassifying  = true;

    // Capture one frame for all crops this round
    final frameBytes = await _captureFrame();
    if (frameBytes == null) {
      _isClassifying = false;
      return;
    }

    final newBreeds = <int, String>{};
    for (final entry in pets) {
      final idx      = entry.key;
      final box      = entry.value.boundingBox;   // normalized Rect
      final cropBytes = await _cropRegion(frameBytes, box);
      if (cropBytes != null) {
        newBreeds[idx] = await _classifyBreed(cropBytes);
        _log('🏷️ [${entry.value.className}] → ${newBreeds[idx]}');
      }
    }

    if (mounted) {
      setState(() => _breedResults
        ..clear()
        ..addAll(newBreeds));
    }
    _isClassifying = false;
  }

  // ── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final petCount = _detections.where((r) {
      final name = r.className.toLowerCase().trim();
      return name == 'cat' || name == 'dog';
    }).length;

    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Layer 1: YOLO live camera ──────────────────────
          RepaintBoundary(
            key: _cameraKey,
            child: YOLOView(
              modelPath: 'assets/models/yolo11n_int8.tflite',
              task: YOLOTask.detect,
              controller: _yoloController,
              confidenceThreshold: 0.25,
              iouThreshold: 0.45,
              lensFacing: LensFacing.back,
              showOverlays: false,
              onResult: (List<YOLOResult> results) {
                _onYoloResult(results);
              },
            ),
          ),
          
          // ── Layer 2: Bounding boxes + breed labels ─────────
          ..._detections.asMap().entries.map((e) {
            final idx       = e.key;
            final detection = e.value;
            final name      = detection.className.toLowerCase().trim();
            final isPet     = name == 'cat' || name == 'dog';
            final box       = detection.boundingBox;

            final left   = box.left   * size.width;
            final top    = box.top    * size.height;
            final width  = box.width  * size.width;
            final height = box.height * size.height;

            final label = isPet
                ? (_breedResults[idx] ?? 'Classifying...')
                : detection.className;

            return Positioned(
              left:   left,
              top:    top,
              width:  width,
              height: height,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isPet ? Colors.greenAccent : Colors.white38,
                    width: isPet ? 2.5 : 1.0,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isPet
                          ? Colors.green.withValues()
                          : Colors.black54,
                      borderRadius: const BorderRadius.only(
                        bottomRight: Radius.circular(4),
                      ),
                    ),
                    child: Text(
                      '$label  ${(detection.confidence * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isPet ? 12 : 10,
                        fontWeight: isPet
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            );
          }),

          // ── Layer 3: Status bar (top) ──────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _classifierReady
                        ? Icons.check_circle
                        : Icons.hourglass_empty,
                    color: _classifierReady
                        ? Colors.greenAccent
                        : Colors.orange,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _classifierReady
                        ? 'Breed classifier ready'
                        : 'Loading classifier...',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: Text(
                        '${_fps.toStringAsFixed(1)} FPS',
                        style: const TextStyle(color: Colors.greenAccent),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Layer 4: Pet counter (bottom) ──────────────────
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$petCount pet(s) detected',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13),
                ),
              ),
            ),
          ),

        ],
      ),
    );
  }
}
