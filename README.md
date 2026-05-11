# 🐾 Pet Breed Image Classifier

A simple Flutter app that identifies dog and cat breeds from images using a MobileNetV2 model trained on the Oxford IIIT-Pet dataset (37 breeds).

---

## Features

- Classify pet images from your **gallery** or through your **camera**
- Returns **top 10 breed predictions** with confidence scores
- Runs inference off the main thread via Dart isolates

---

## Supported Breeds

37 breeds from the Oxford IIIT-Pet dataset — 12 cat breeds and 25 dog breeds including Abyssinian, Bengal, Beagle, Boxer, British Shorthair, German Shepherd, Maine Coon, Persian, Pomeranian, and more.

---

## Project Structure

```
assets/
└── models/
    ├── pet_breed_model_with_metadata.tflite   # Trained MobileNetV2 model
    └── labels.txt                             # 37 breed labels
lib/
└── image_detection_page.dart                 # Main classifier screen
```

---

## Main Dependencies

```yaml
dependencies:
  tflite_flutter: ^0.10.4+1
  image: ^4.1.3
  image_picker: ^1.0.7
```

---

## Setup

**1. Add assets to `pubspec.yaml`**
```yaml
flutter:
  assets:
    - assets/models/pet_breed_model_with_metadata.tflite
    - assets/models/labels.txt
```

**2. Add permissions to `AndroidManifest.xml`**
```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
```

**3. Navigate to the page**
```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const ImageDetectionPage()),
);
```

---

## Model Training

The model was trained on the [Oxford IIIT-Pet Dataset](https://www.robots.ox.ac.uk/~vgg/data/pets/) using transfer learning with MobileNetV2 pretrained on ImageNet. Training was done in two phases — first training only the top classification layer, then fine-tuning the last 30 layers of the base model.

| Detail | Value |
|---|---|
| Base model | MobileNetV2 |
| Input size | 224 × 224 × 3 |
| Output | 37 breed probabilities |
| Dataset | Oxford IIIT-Pet |
| Training tool | TensorFlow / Keras (Google Colab) |
| Export format | TensorFlow Lite with metadata |

---
## Known Limitations

- Works best with clear, well-lit images where the pet is the main subject
- Accuracy drops on small or partially visible animals
- Does not detect multiple pets in one image — crop to a single animal for best results
- Live camera breed detection is not yet integrated

---

## License

Dataset usage must respect the [Oxford IIIT-Pet Dataset terms](https://www.robots.ox.ac.uk/~vgg/data/pets/). See the original paper:

> Parkhi et al., *Cats and Dogs*, CVPR 2012
