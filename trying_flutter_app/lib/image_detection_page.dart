import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

// Isolate inference
Future<List<MapEntry<String, double>>> _runImageInference(
    Map<String, dynamic> args) async {
  final bytes      = args['bytes']      as Uint8List;
  final labels     = args['labels']     as List<String>;
  final modelBytes = args['modelBytes'] as Uint8List;

  final decoded = img.decodeImage(bytes);
  if (decoded == null) return [];

  final resized = img.copyResize(decoded, width: 224, height: 224);

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

  final interpreter = Interpreter.fromBuffer(modelBytes);
  final output      = [List.filled(labels.length, 0.0)];
  interpreter.run(input, output);
  interpreter.close();

  final probs = List<double>.from(output[0]);

  // Return all results sorted by confidence
  final ranked = List.generate(labels.length, (i) =>
      MapEntry(labels[i], probs[i]))
    ..sort((a, b) => b.value.compareTo(a.value));

  return ranked.take(10).toList();
}

// Page
class ImageDetectionPage extends StatefulWidget {
  const ImageDetectionPage({super.key});

  @override
  State<ImageDetectionPage> createState() => _ImageDetectionPageState();
}

class _ImageDetectionPageState extends State<ImageDetectionPage> {

  // ── State ──────────────────────────────────────────────────
  Uint8List?                      _imageBytes;
  List<MapEntry<String, double>>  _results    = [];
  bool                            _isLoading  = false;
  String                          _status     = 'Pick an image to classify';

  // ── Model assets ───────────────────────────────────────────
  Uint8List?   _modelBytes;
  List<String> _labels = [];
  bool         _modelReady = false;

  final ImagePicker _picker = ImagePicker();

  // ── Lifecycle ──────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadModel());
  }

  Future<void> _loadModel() async {
    try {
      setState(() => _status = 'Loading model...');

      final labelData = await DefaultAssetBundle.of(context)
          .loadString('assets/models/labels.txt');
      _labels = labelData
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      final modelData = await DefaultAssetBundle.of(context)
          .load('assets/models/pet_breed_model.tflite');
      _modelBytes = modelData.buffer.asUint8List();

      setState(() {
        _modelReady = true;
        _status     = 'Model ready — ${_labels.length} breeds';
      });
    } catch (e) {
      setState(() => _status = '❌ Model load error: $e');
    }
  }

  // ── Image picking ──────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 100,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _results    = [];
        _status     = 'Image loaded — tap Classify';
      });
    } catch (e) {
      setState(() => _status = '❌ Pick error: $e');
    }
  }

  // ── Run inference ──────────────────────────────────────────
  Future<void> _classify() async {
    if (_imageBytes == null || !_modelReady || _modelBytes == null) return;

    setState(() {
      _isLoading = true;
      _status    = 'Classifying...';
      _results   = [];
    });

    try {
      final results = await compute(_runImageInference, {
        'bytes':      _imageBytes!,
        'labels':     _labels,
        'modelBytes': _modelBytes!,
      });

      setState(() {
        _results   = results;
        _isLoading = false;
        _status    = 'Top prediction: ${results.first.key} '
            '(${(results.first.value * 100).toStringAsFixed(1)}%)';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status    = '❌ Classify error: $e';
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text(
          'Image Breed Classifier',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white)
      ),

      body: Column(
        children: [
          // ── Status bar ─────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            color: const Color(0xFF0F3460),
            child: Row(
              children: [
                Icon(
                  _modelReady
                      ? Icons.check_circle
                      : Icons.hourglass_empty,
                  color: _modelReady
                      ? Colors.greenAccent
                      : Colors.orange,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _status,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          // ── Image preview ──────────────────────────────────
          Expanded(
            flex: 4,
            child: GestureDetector(
              onTap: () => _pickImage(ImageSource.gallery),
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF16213E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white12,
                    width: 1,
                  ),
                ),
                child: _imageBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: Image.memory(
                          _imageBytes!,
                          fit: BoxFit.fitWidth,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 64,
                            color: Colors.white24,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Tap to pick an image',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 15),
                          ),
                        ],
                      ),
              ),
            ),
          ),

          // ── Action buttons ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: () => _pickImage(ImageSource.gallery),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onTap: () => _pickImage(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.search,
                    label: 'Classify',
                    color: Colors.greenAccent,
                    onTap: _imageBytes != null && _modelReady && !_isLoading
                        ? _classify
                        : null,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Results ────────────────────────────────────────
          Expanded(
            flex: 3,
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Colors.greenAccent,
                    ),
                  )
                : _results.isEmpty
                    ? const Center(
                        child: Text(
                          'Results will appear here',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 14),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                            16, 0, 16, 16),
                        itemCount: _results.length,
                        itemBuilder: (context, i) {
                          final entry = _results[i];
                          final pct   = entry.value * 100;
                          final isTop = i == 0;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isTop
                                  ? Colors.green.withAlpha(39)
                                  : const Color(0xFF16213E),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isTop
                                    ? Colors.greenAccent.withAlpha(128)
                                    : Colors.white12,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Rank badge
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: isTop
                                        ? Colors.greenAccent
                                        : Colors.white12,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${i + 1}',
                                      style: TextStyle(
                                        color: isTop
                                            ? Colors.black
                                            : Colors.white54,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Breed name
                                Expanded(
                                  child: Text(
                                    entry.key,
                                    style: TextStyle(
                                      color: isTop
                                          ? Colors.white
                                          : Colors.white70,
                                      fontSize: isTop ? 15 : 13,
                                      fontWeight: isTop
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),

                                // Confidence bar + percentage
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${pct.toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        color: isTop
                                            ? Colors.greenAccent
                                            : Colors.white54,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    SizedBox(
                                      width: 80,
                                      height: 4,
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(2),
                                        child: LinearProgressIndicator(
                                          value: entry.value,
                                          backgroundColor:
                                              Colors.white12,
                                          valueColor:
                                              AlwaysStoppedAnimation(
                                            isTop
                                                ? Colors.greenAccent
                                                : Colors.white38,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),

        ],
      ),
    );
  }
}

// Helper widget
class _ActionButton extends StatelessWidget {
  final IconData  icon;
  final String    label;
  final VoidCallback? onTap;
  final Color     color;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.color = Colors.white70,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: enabled
              ? const Color(0xFF16213E)
              : const Color(0xFF16213E).withAlpha(102),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled ? color.withAlpha(128) : Colors.white12,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: enabled ? color : Colors.white24, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: enabled ? color : Colors.white24,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
