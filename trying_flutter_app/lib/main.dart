import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class LivePetDetectionScreen extends StatefulWidget {
  const LivePetDetectionScreen({super.key});

  @override
  State<LivePetDetectionScreen> createState() =>
      _LivePetDetectionScreenState();
}

class _LivePetDetectionScreenState extends State<LivePetDetectionScreen> {
  // ── YOLO detector ──────────────────────────────────────────────
  List<DetectedObject> _detections = [];

  // ── Breed classifier ───────────────────────────────────────────
  Interpreter? _classifier;
  List<String>  _labels    = [];
  bool          _classifierReady = false;

  // ── Per-box breed results ──────────────────────────────────────
  // Maps detection index → "BreedName (conf%)"
  final Map<int, String> _breedResults = {};
  bool _isClassifying = false;

  // YOLO class IDs for cat (15) and dog (16) in COCO
  static const _petClassIds = {15, 16};

  // ── Lifecycle ──────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadClassifier();
  }

  @override
  void dispose() {
    _classifier?.close();
    super.dispose();
  }

  // ── Load breed classifier + labels ────────────────────────────
  Future<void> _loadClassifier() async {
    try {
      _classifier = await Interpreter.fromAsset(
        'assets/models/pet_breed_model_with_metadata.tflite',
      );

      final labelData = await DefaultAssetBundle.of(context)
          .loadString('assets/models/labels.txt');
      _labels = labelData
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      setState(() => _classifierReady = true);
      debugPrint('✅ Breed classifier ready — ${_labels.length} breeds');
    } catch (e) {
      debugPrint('❌ Classifier load error: $e');
    }
  }

  // ── Classify a single cropped pet image ───────────────────────
  Future<String> _classifyBreed(Uint8List cropBytes) async {
    if (_classifier == null || _labels.isEmpty) return 'Loading...';

    // Decode & resize to 224×224
    final decoded = img.decodeImage(cropBytes);
    if (decoded == null) return 'Error';
    final resized = img.copyResize(decoded, width: 224, height: 224);

    // Normalize to [0, 1] float32
    final input = List.generate(
      1,
      (_) => List.generate(
        224,
        (y) => List.generate(224, (x) {
          final pixel = resized.getPixel(x, y);
          return [
            pixel.r / 255.0,
            pixel.g / 255.0,
            pixel.b / 255.0,
          ];
        }),
      ),
    );

    // Output buffer: [1, 37]
    final output = List.filled(1 * _labels.length, 0.0)
        .reshape([1, _labels.length]);

    _classifier!.run(input, output);

    // Find top prediction
    final probs    = List<double>.from(output[0] as List);
    final topIndex = probs.indexOf(probs.reduce((a, b) => a > b ? a : b));
    final topConf  = (probs[topIndex] * 100).toStringAsFixed(1);
    final topLabel = _labels[topIndex];

    return '$topLabel ($topConf%)';
  }

  // ── Called every YOLO frame ────────────────────────────────────
  Future<void> _onYoloResult(List<DetectedObject> results) async {
    setState(() => _detections = results);

    // Only run breed classifier when not already busy
    if (_isClassifying || !_classifierReady) return;
    _isClassifying = true;

    final pets = results
        .asMap()
        .entries
        .where((e) => _petClassIds.contains(e.value.classIndex))
        .toList();

    final newBreeds = <int, String>{};

    for (final entry in pets) {
      final idx       = entry.key;
      final detection = entry.value;

      // detection.croppedImage is the Uint8List of the bounding box crop
      if (detection.croppedImage != null) {
        newBreeds[idx] = await _classifyBreed(detection.croppedImage!);
      }
    }

    if (mounted) {
      setState(() {
        _breedResults
          ..clear()
          ..addAll(newBreeds);
      });
    }

    _isClassifying = false;
  }

  // ── UI ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [

          // ── Layer 1: YOLO live camera view ──────────────────────
          YOLOView(
            modelPath: 'assets/models/yolo11n_int8.tflite',
            confidenceThreshold: 0.5,
            iouThreshold: 0.45,
            lensFacing: LensFacing.back,
            showOverlays: true,   // shows YOLO bounding boxes
            onResult: _onYoloResult,
          ),

          // ── Layer 2: Breed labels overlaid per detection ─────────
          if (_detections.isNotEmpty)
            ..._detections.asMap().entries
                .where((e) => _petClassIds.contains(e.value.classIndex))
                .map((e) {
                  final idx       = e.key;
                  final detection = e.value;
                  final breed     = _breedResults[idx] ?? 'Classifying...';
                  final box       = detection.boundingBox;
                  final size      = MediaQuery.of(context).size;

                  // Convert normalized box to screen coords
                  final left   = box.left   * size.width;
                  final top    = box.top    * size.height;
                  final width  = box.width  * size.width;

                  return Positioned(
                    left: left,
                    top:  top > 30 ? top - 28 : top + 4,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: width),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        breed,
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                }),

          // ── Layer 3: Status bar (top) ────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _classifierReady ? Icons.check_circle : Icons.hourglass_empty,
                    color: _classifierReady ? Colors.greenAccent : Colors.orange,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _classifierReady
                        ? 'Breed classifier ready'
                        : 'Loading classifier...',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),

          // ── Layer 4: Detection count (bottom) ───────────────────
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_breedResults.length} pet(s) detected',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
