---
title: Usage Guide
description: Comprehensive examples and patterns for using YOLO in Flutter - from basic detection to advanced multi-instance workflows
path: /integrations/flutter/usage/
---

# Usage Guide

Master the Ultralytics YOLO Flutter plugin with comprehensive examples and real-world patterns.

## 📖 Table of Contents

- [Basic Usage Patterns](#basic-usage-patterns)
- [All YOLO Tasks](#all-yolo-tasks)
- [Multi-Instance Support](#multi-instance-support)
- [Real-time Camera Processing](#real-time-camera-processing)
- [Advanced Configurations](#advanced-configurations)
- [Error Handling](#error-handling)
- [Best Practices](#best-practices)

## 🎯 Basic Usage Patterns

### Single Image Detection

```dart
import 'package:ultralytics_yolo/yolo.dart';
import 'dart:io';

class ObjectDetector {
  late YOLO yolo;

  Future<void> initializeYOLO() async {
    yolo = YOLO(
      modelPath: 'yolo11n',
      task: YOLOTask.detect,
    );

    await yolo.loadModel();
    print('YOLO model loaded successfully!');
  }

  Future<List<Map<String, dynamic>>> detectObjects(File imageFile) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      final results = await yolo.predict(imageBytes);

      return List<Map<String, dynamic>>.from(results['boxes'] ?? []);
    } catch (e) {
      print('Detection error: $e');
      return [];
    }
  }
}
```

### Batch Processing

```dart
class BatchProcessor {
  final YOLO yolo;

  BatchProcessor(this.yolo);

  Future<Map<String, List<dynamic>>> processImageBatch(
    List<File> images,
  ) async {
    final results = <String, List<dynamic>>{};

    for (final image in images) {
      final imageBytes = await image.readAsBytes();
      final detection = await yolo.predict(imageBytes);
      results[image.path] = detection['boxes'] ?? [];
    }

    return results;
  }
}
```

## 🎨 All YOLO Tasks

### 🔍 Object Detection

```dart
class DetectionExample {
  Future<void> runDetection() async {
    final yolo = YOLO(
      modelPath: 'yolo11n',
      task: YOLOTask.detect,
    );

    await yolo.loadModel();

    final imageBytes = await loadImageBytes();
    final results = await yolo.predict(imageBytes);

    // Process bounding boxes
    final boxes = results['boxes'] as List<dynamic>;
    for (final box in boxes) {
      print('Object: ${box['class']}');
      print('Confidence: ${box['confidence']}');
      print('Box: x=${box['x']}, y=${box['y']}, w=${box['width']}, h=${box['height']}');
    }
  }
}
```

### 🎭 Instance Segmentation

```dart
class SegmentationExample {
  Future<void> runSegmentation() async {
    final yolo = YOLO(
      modelPath: 'yolo11n-seg',
      task: YOLOTask.segment,
    );

    await yolo.loadModel();

    final imageBytes = await loadImageBytes();
    final results = await yolo.predict(imageBytes);

    // Process segmentation masks
    final boxes = results['boxes'] as List<dynamic>;
    for (final box in boxes) {
      print('Object: ${box['class']}');
      print('Mask available: ${box.containsKey('mask')}');

      // Access mask data if available
      if (box.containsKey('mask')) {
        final mask = box['mask'];
        // Process mask data for overlay rendering
      }
    }
  }
}
```

### 🏷️ Image Classification

```dart
class ClassificationExample {
  Future<void> runClassification() async {
    final yolo = YOLO(
      modelPath: 'yolo11n-cls',
      task: YOLOTask.classify,
    );

    await yolo.loadModel();

    final imageBytes = await loadImageBytes();
    final results = await yolo.predict(imageBytes);

    // Process classification results
    final classifications = results['classifications'] as List<dynamic>? ?? [];
    for (final classification in classifications) {
      print('Class: ${classification['class']}');
      print('Confidence: ${classification['confidence']}');
    }
  }
}
```

### 🤸 Pose Estimation

```dart
class PoseEstimationExample {
  Future<void> runPoseEstimation() async {
    final yolo = YOLO(
      modelPath: 'yolo11n-pose',
      task: YOLOTask.pose,
    );

    await yolo.loadModel();

    final imageBytes = await loadImageBytes();
    final results = await yolo.predict(imageBytes);

    // Process pose keypoints
    final poses = results['poses'] as List<dynamic>? ?? [];
    for (final pose in poses) {
      print('Person detected with ${pose['keypoints']?.length ?? 0} keypoints');

      // Access individual keypoints
      final keypoints = pose['keypoints'] as List<dynamic>? ?? [];
      for (int i = 0; i < keypoints.length; i++) {
        final keypoint = keypoints[i];
        print('Keypoint $i: x=${keypoint['x']}, y=${keypoint['y']}, confidence=${keypoint['confidence']}');
      }
    }
  }
}
```

### 📦 Oriented Bounding Box (OBB)

```dart
class OBBExample {
  Future<void> runOBBDetection() async {
    final yolo = YOLO(
      modelPath: 'yolo11n-obb',
      task: YOLOTask.obb,
    );

    await yolo.loadModel();

    final imageBytes = await loadImageBytes();
    final results = await yolo.predict(imageBytes);

    // Process oriented bounding boxes
    final boxes = results['boxes'] as List<dynamic>;
    for (final box in boxes) {
      print('Object: ${box['class']}');
      print('Confidence: ${box['confidence']}');
      print('Rotation: ${box['angle']} degrees');

      // Access rotated box coordinates
      final points = box['points'] as List<dynamic>? ?? [];
      print('Box corners: $points');
    }
  }
}
```

## 🔀 Multi-Instance Support

### Parallel Model Execution

```dart
class MultiInstanceExample {
  late YOLO detector;
  late YOLO segmenter;
  late YOLO classifier;

  Future<void> initializeMultipleModels() async {
    // Create multiple instances with unique IDs
    detector = YOLO(
      modelPath: 'yolo11n',
      task: YOLOTask.detect,
      useMultiInstance: true, // Enable multi-instance mode
    );

    segmenter = YOLO(
      modelPath: 'yolo11n-seg',
      task: YOLOTask.segment,
      useMultiInstance: true,
    );

    classifier = YOLO(
      modelPath: 'yolo11n-cls',
      task: YOLOTask.classify,
      useMultiInstance: true,
    );

    // Load all models in parallel
    await Future.wait([
      detector.loadModel(),
      segmenter.loadModel(),
      classifier.loadModel(),
    ]);

    print('All models loaded successfully!');
  }

  Future<Map<String, dynamic>> runComprehensiveAnalysis(
    Uint8List imageBytes,
  ) async {
    // Run all models on the same image simultaneously
    final results = await Future.wait([
      detector.predict(imageBytes),
      segmenter.predict(imageBytes),
      classifier.predict(imageBytes),
    ]);

    return {
      'detection': results[0],
      'segmentation': results[1],
      'classification': results[2],
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<void> dispose() async {
    // Clean up all instances
    await Future.wait([
      detector.dispose(),
      segmenter.dispose(),
      classifier.dispose(),
    ]);
  }
}
```

### Model Comparison Workflow

```dart
class ModelComparison {
  late YOLO modelA;
  late YOLO modelB;

  Future<void> initializeComparison() async {
    modelA = YOLO(
      modelPath: 'yolo11n',
      task: YOLOTask.detect,
      useMultiInstance: true,
    );

    modelB = YOLO(
      modelPath: 'yolo11s', // Different model size
      task: YOLOTask.detect,
      useMultiInstance: true,
    );

    await Future.wait([
      modelA.loadModel(),
      modelB.loadModel(),
    ]);
  }

  Future<Map<String, dynamic>> compareModels(Uint8List imageBytes) async {
    final stopwatchA = Stopwatch()..start();
    final resultA = await modelA.predict(imageBytes);
    stopwatchA.stop();

    final stopwatchB = Stopwatch()..start();
    final resultB = await modelB.predict(imageBytes);
    stopwatchB.stop();

    return {
      'model_a': {
        'results': resultA,
        'inference_time': stopwatchA.elapsedMilliseconds,
        'detections_count': (resultA['boxes'] as List).length,
      },
      'model_b': {
        'results': resultB,
        'inference_time': stopwatchB.elapsedMilliseconds,
        'detections_count': (resultB['boxes'] as List).length,
      },
    };
  }
}
```

## 📹 Real-time Camera Processing

### Basic Camera Integration

```dart
import 'package:ultralytics_yolo/yolo_view.dart';

class CameraDetectionScreen extends StatefulWidget {
  @override
  _CameraDetectionScreenState createState() => _CameraDetectionScreenState();
}

class _CameraDetectionScreenState extends State<CameraDetectionScreen> {
  late YOLOViewController controller;
  List<YOLOResult> currentResults = [];

  @override
  void initState() {
    super.initState();
    controller = YOLOViewController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Camera view with YOLO processing
          YOLOView(
            modelPath: 'yolo11n',
            task: YOLOTask.detect,
            controller: controller,
            onResult: (results) {
              setState(() {
                currentResults = results;
              });
            },
            onPerformanceMetrics: (metrics) {
              print('FPS: ${metrics.fps.toStringAsFixed(1)}');
              print('Processing time: ${metrics.processingTimeMs.toStringAsFixed(1)}ms');
            },
          ),

          // Overlay UI
          Positioned(
            top: 50,
            left: 20,
            child: Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Objects: ${currentResults.length}',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

### Advanced Streaming Configuration

```dart
import 'package:ultralytics_yolo/yolo_streaming_config.dart';

class AdvancedCameraScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: YOLOView(
        modelPath: 'yolo11n',
        task: YOLOTask.detect,

        // Configure streaming behavior
        streamingConfig: YOLOStreamingConfig.throttled(
          maxFPS: 15, // Limit to 15 FPS for battery saving
          includeMasks: false, // Disable masks for performance
          includeOriginalImage: false, // Save bandwidth
        ),

        // Comprehensive callback
        onStreamingData: (data) {
          final detections = data['detections'] as List? ?? [];
          final fps = data['fps'] as double? ?? 0.0;
          final originalImage = data['originalImage'] as Uint8List?;

          print('Streaming: ${detections.length} detections at ${fps.toStringAsFixed(1)} FPS');

          // Process complete frame data
          processFrameData(detections, originalImage);
        },
      ),
    );
  }

  void processFrameData(List detections, Uint8List? imageData) {
    // Custom processing logic
    for (final detection in detections) {
      final className = detection['className'] as String?;
      final confidence = detection['confidence'] as double?;

      if (confidence != null && confidence > 0.8) {
        print('High confidence detection: $className (${(confidence * 100).toStringAsFixed(1)}%)');
      }
    }
  }
}
```

## ⚙️ Advanced Configurations

### Custom Thresholds and Performance Tuning

```dart
class AdvancedConfiguration {
  late YOLO yolo;
  late YOLOViewController controller;

  Future<void> setupOptimizedYOLO() async {
    yolo = YOLO(
      modelPath: 'yolo11n',
      task: YOLOTask.detect,
    );

    await yolo.loadModel();

    controller = YOLOViewController();

    // Optimize for your use case
    await controller.setThresholds(
      confidenceThreshold: 0.6,  // Higher for fewer false positives
      iouThreshold: 0.4,         // Lower for more distinct objects
      numItemsThreshold: 20,     // Limit max detections
    );
  }

  Future<List<dynamic>> optimizedPrediction(Uint8List imageBytes) async {
    // Use custom thresholds during prediction
    final results = await yolo.predict(
      imageBytes,
      confidenceThreshold: 0.7,  // Override global setting
      iouThreshold: 0.3,
    );

    return results['boxes'] ?? [];
  }
}
```

### Model Switching

```dart
class ModelSwitcher {
  late YOLO yolo;
  String currentModel = '';

  Future<void> initializeWithModel(String modelPath) async {
    yolo = YOLO(
      modelPath: modelPath,
      task: YOLOTask.detect,
    );

    await yolo.loadModel();
    currentModel = modelPath;
  }

  Future<void> switchToModel(String newModelPath, YOLOTask newTask) async {
    try {
      // Switch model dynamically (requires view to be set)
      await yolo.switchModel(newModelPath, newTask);
      currentModel = newModelPath;
      print('Switched to model: $newModelPath');
    } catch (e) {
      print('Model switch failed: $e');
      // Fallback: create new instance
      await initializeWithModel(newModelPath);
    }
  }
}
```

## 🛡️ Error Handling

### Robust Error Management

```dart
class RobustYOLOService {
  YOLO? yolo;
  bool isModelLoaded = false;

  Future<bool> safeInitialize(String modelPath) async {
    try {
      yolo = YOLO(
        modelPath: modelPath,
        task: YOLOTask.detect,
      );

      await yolo!.loadModel();
      isModelLoaded = true;
      return true;

    } on ModelLoadingException catch (e) {
      print('Model loading failed: ${e.message}');
      return false;
    } on PlatformException catch (e) {
      print('Platform error: ${e.message}');
      return false;
    } catch (e) {
      print('Unexpected error: $e');
      return false;
    }
  }

  Future<List<dynamic>?> safePrediction(Uint8List imageBytes) async {
    if (!isModelLoaded || yolo == null) {
      print('Model not loaded');
      return null;
    }

    try {
      final results = await yolo!.predict(imageBytes);
      return results['boxes'];

    } on ModelNotLoadedException catch (e) {
      print('Model not loaded: ${e.message}');
      // Attempt to reload
      await safeInitialize(yolo!.modelPath);
      return null;

    } on InferenceException catch (e) {
      print('Inference failed: ${e.message}');
      return null;

    } on InvalidInputException catch (e) {
      print('Invalid input: ${e.message}');
      return null;

    } catch (e) {
      print('Prediction error: $e');
      return null;
    }
  }

  Future<void> safeDispose() async {
    try {
      await yolo?.dispose();
      isModelLoaded = false;
    } catch (e) {
      print('Dispose error: $e');
    }
  }
}
```

## 🎯 Best Practices

### Memory Management

```dart
class MemoryEfficientYOLO {
  static const int MAX_CONCURRENT_INSTANCES = 3;
  final List<YOLO> activeInstances = [];

  Future<YOLO> createManagedInstance(String modelPath, YOLOTask task) async {
    // Limit concurrent instances
    if (activeInstances.length >= MAX_CONCURRENT_INSTANCES) {
      // Dispose oldest instance
      final oldest = activeInstances.removeAt(0);
      await oldest.dispose();
    }

    final yolo = YOLO(
      modelPath: modelPath,
      task: task,
      useMultiInstance: true,
    );

    await yolo.loadModel();
    activeInstances.add(yolo);

    return yolo;
  }

  Future<void> disposeAll() async {
    await Future.wait(
      activeInstances.map((yolo) => yolo.dispose()),
    );
    activeInstances.clear();
  }
}
```

### Performance Monitoring

```dart
class PerformanceMonitor {
  final List<double> inferenceTimes = [];
  final List<double> fpsValues = [];

  void onPerformanceUpdate(YOLOPerformanceMetrics metrics) {
    inferenceTimes.add(metrics.processingTimeMs);
    fpsValues.add(metrics.fps);

    // Keep only last 100 measurements
    if (inferenceTimes.length > 100) {
      inferenceTimes.removeAt(0);
      fpsValues.removeAt(0);
    }

    // Log performance warnings
    if (metrics.processingTimeMs > 200) {
      print('⚠️ Slow inference: ${metrics.processingTimeMs.toStringAsFixed(1)}ms');
    }

    if (metrics.fps < 10) {
      print('⚠️ Low FPS: ${metrics.fps.toStringAsFixed(1)}');
    }
  }

  Map<String, double> getPerformanceStats() {
    if (inferenceTimes.isEmpty) return {};

    final avgInferenceTime = inferenceTimes.reduce((a, b) => a + b) / inferenceTimes.length;
    final avgFps = fpsValues.reduce((a, b) => a + b) / fpsValues.length;

    return {
      'average_inference_time_ms': avgInferenceTime,
      'average_fps': avgFps,
      'performance_rating': avgFps > 20 ? 5.0 : avgFps > 15 ? 4.0 : avgFps > 10 ? 3.0 : 2.0,
    };
  }
}
```

## 🎓 Example Applications

### Security Camera System

```dart
class SecuritySystem {
  late YOLO detector;
  final List<String> alertClasses = ['person', 'car', 'truck'];

  Future<void> initialize() async {
    detector = YOLO(
      modelPath: 'yolo11n',
      task: YOLOTask.detect,
    );
    await detector.loadModel();
  }

  Future<bool> analyzeFrame(Uint8List frameBytes) async {
    final results = await detector.predict(frameBytes);
    final boxes = results['boxes'] as List;

    // Check for security-relevant objects
    for (final box in boxes) {
      final className = box['class'] as String;
      final confidence = box['confidence'] as double;

      if (alertClasses.contains(className) && confidence > 0.8) {
        await triggerAlert(className, confidence);
        return true;
      }
    }

    return false;
  }

  Future<void> triggerAlert(String objectClass, double confidence) async {
    print('🚨 Security Alert: $objectClass detected (${(confidence * 100).toStringAsFixed(1)}% confidence)');
    // Implement notification logic
  }
}
```

This comprehensive usage guide covers all major patterns and use cases for the YOLO Flutter plugin. For specific API details, check the [API Reference](api.md), and for performance optimization, see the [Performance Guide](performance.md).
