// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

// lib/yolo_view.dart

import 'dart:async';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ultralytics_yolo/utils/logger.dart';
import 'package:ultralytics_yolo/yolo_result.dart';
import 'package:ultralytics_yolo/yolo_task.dart';
import 'package:ultralytics_yolo/yolo_streaming_config.dart';
import 'package:ultralytics_yolo/yolo_performance_metrics.dart';

/// Controller for interacting with a [YOLOView] widget.
///
/// This controller provides methods to adjust detection thresholds
/// and camera settings for real-time object detection. It manages
/// the communication with the native platform views.
///
/// Example:
/// ```dart
/// class MyDetectorScreen extends StatefulWidget {
///   @override
///   State<MyDetectorScreen> createState() => _MyDetectorScreenState();
/// }
///
/// class _MyDetectorScreenState extends State<MyDetectorScreen> {
///   final controller = YOLOViewController();
///
///   @override
///   Widget build(BuildContext context) {
///     return Column(
///       children: [
///         Expanded(
///           child: YOLOView(
///             modelPath: 'assets/yolov8n.mlmodel',
///             task: YOLOTask.detect,
///             controller: controller,
///             onResult: (results) {
///               print('Detected ${results.length} objects');
///             },
///           ),
///         ),
///         ElevatedButton(
///           onPressed: () => controller.switchCamera(),
///           child: Text('Switch Camera'),
///         ),
///       ],
///     );
///   }
/// }
/// ```
class YOLOViewController {
  MethodChannel? _methodChannel;
  int? _viewId;

  double _confidenceThreshold = 0.5;
  double _iouThreshold = 0.45;
  int _numItemsThreshold = 30;

  /// The current confidence threshold for detections.
  ///
  /// Only detections with confidence scores above this threshold
  /// will be returned. Default is 0.5 (50%).
  double get confidenceThreshold => _confidenceThreshold;

  /// The current Intersection over Union (IoU) threshold.
  ///
  /// Used for non-maximum suppression to filter overlapping
  /// detections. Default is 0.45.
  double get iouThreshold => _iouThreshold;

  /// The maximum number of items to detect per frame.
  ///
  /// Limits the number of detections returned to improve
  /// performance. Default is 30.
  int get numItemsThreshold => _numItemsThreshold;

  /// Whether the controller has been initialized with a platform view.
  ///
  /// Returns true if the controller is connected to a native view and
  /// can receive method calls.
  bool get isInitialized => _methodChannel != null && _viewId != null;

  @visibleForTesting
  void init(MethodChannel methodChannel, int viewId) =>
      _init(methodChannel, viewId);

  void _init(MethodChannel methodChannel, int viewId) {
    _methodChannel = methodChannel;
    _viewId = viewId;
    _applyThresholds();
  }

  Future<void> _applyThresholds() async {
    if (_methodChannel == null) {
      logInfo(
        'YOLOViewController: Warning - Cannot apply thresholds, view not yet created',
      );
      return;
    }
    try {
      await _methodChannel!.invokeMethod('setThresholds', {
        'confidenceThreshold': _confidenceThreshold,
        'iouThreshold': _iouThreshold,
        'numItemsThreshold': _numItemsThreshold,
      });
      logInfo(
        'YOLOViewController: Applied thresholds - confidence: $_confidenceThreshold, IoU: $_iouThreshold, numItems: $_numItemsThreshold',
      );
    } catch (e) {
      logInfo('YOLOViewController: Error applying combined thresholds: $e');
      try {
        logInfo(
          'YOLOViewController: Trying individual threshold methods as fallback',
        );
        await _methodChannel!.invokeMethod('setConfidenceThreshold', {
          'threshold': _confidenceThreshold,
        });
        logInfo(
          'YOLOViewController: Applied confidence threshold: $_confidenceThreshold',
        );
        await _methodChannel!.invokeMethod('setIoUThreshold', {
          'threshold': _iouThreshold,
        });
        logInfo('YOLOViewController: Applied IoU threshold: $_iouThreshold');
        await _methodChannel!.invokeMethod('setNumItemsThreshold', {
          'numItems': _numItemsThreshold,
        });
        logInfo(
          'YOLOViewController: Applied numItems threshold: $_numItemsThreshold',
        );
      } catch (e2) {
        logInfo(
          'YOLOViewController: Error applying individual thresholds: $e2',
        );
      }
    }
  }

  /// Sets the confidence threshold for object detection.
  ///
  /// Only detections with confidence scores above [threshold] will be
  /// returned. The value is automatically clamped between 0.0 and 1.0.
  ///
  /// Example:
  /// ```dart
  /// // Only show detections with 70% confidence or higher
  /// await controller.setConfidenceThreshold(0.7);
  /// ```
  Future<void> setConfidenceThreshold(double threshold) async {
    final clampedThreshold = threshold.clamp(0.0, 1.0);
    _confidenceThreshold = clampedThreshold;
    if (_methodChannel == null) {
      logInfo(
        'YOLOViewController: Warning - Cannot apply confidence threshold, view not yet created',
      );
      return;
    }
    try {
      await _methodChannel!.invokeMethod('setConfidenceThreshold', {
        'threshold': clampedThreshold,
      });
      logInfo(
        'YOLOViewController: Applied confidence threshold: $_confidenceThreshold',
      );
    } catch (e) {
      logInfo('YOLOViewController: Error applying confidence threshold: $e');
      return _applyThresholds();
    }
  }

  /// Sets the Intersection over Union (IoU) threshold.
  ///
  /// This threshold is used for non-maximum suppression to filter
  /// overlapping detections. Lower values result in fewer overlapping
  /// boxes. The value is automatically clamped between 0.0 and 1.0.
  ///
  /// Example:
  /// ```dart
  /// // Use stricter overlap filtering
  /// await controller.setIoUThreshold(0.3);
  /// ```
  Future<void> setIoUThreshold(double threshold) async {
    final clampedThreshold = threshold.clamp(0.0, 1.0);
    _iouThreshold = clampedThreshold;
    if (_methodChannel == null) {
      logInfo(
        'YOLOViewController: Warning - Cannot apply IoU threshold, view not yet created',
      );
      return;
    }
    try {
      await _methodChannel!.invokeMethod('setIoUThreshold', {
        'threshold': clampedThreshold,
      });
      logInfo('YOLOViewController: Applied IoU threshold: $_iouThreshold');
    } catch (e) {
      logInfo('YOLOViewController: Error applying IoU threshold: $e');
      return _applyThresholds();
    }
  }

  /// Sets the maximum number of items to detect per frame.
  ///
  /// Limiting the number of detections can improve performance,
  /// especially on lower-end devices. The value is automatically
  /// clamped between 1 and 100.
  ///
  /// Example:
  /// ```dart
  /// // Only detect up to 10 objects per frame
  /// await controller.setNumItemsThreshold(10);
  /// ```
  Future<void> setNumItemsThreshold(int numItems) async {
    final clampedValue = numItems.clamp(1, 100);
    _numItemsThreshold = clampedValue;
    if (_methodChannel == null) {
      logInfo(
        'YOLOViewController: Warning - Cannot apply numItems threshold, view not yet created',
      );
      return;
    }
    try {
      await _methodChannel!.invokeMethod('setNumItemsThreshold', {
        'numItems': clampedValue,
      });
      logInfo(
        'YOLOViewController: Applied numItems threshold: $_numItemsThreshold',
      );
      return _applyThresholds();
    } catch (e) {
      logInfo('YOLOViewController: Error applying numItems threshold: $e');
    }
  }

  /// Sets multiple thresholds at once.
  ///
  /// This method allows updating multiple thresholds in a single call,
  /// which is more efficient than setting them individually.
  ///
  /// Example:
  /// ```dart
  /// await controller.setThresholds(
  ///   confidenceThreshold: 0.6,
  ///   iouThreshold: 0.4,
  ///   numItemsThreshold: 20,
  /// );
  /// ```
  Future<void> setThresholds({
    double? confidenceThreshold,
    double? iouThreshold,
    int? numItemsThreshold,
  }) async {
    if (confidenceThreshold != null) {
      _confidenceThreshold = confidenceThreshold.clamp(0.0, 1.0);
    }
    if (iouThreshold != null) {
      _iouThreshold = iouThreshold.clamp(0.0, 1.0);
    }
    if (numItemsThreshold != null) {
      _numItemsThreshold = numItemsThreshold.clamp(1, 100);
    }
    return _applyThresholds();
  }

  /// Switches between front and back camera.
  ///
  /// This method toggles the camera between front-facing and back-facing modes.
  /// Returns a [Future] that completes when the camera has been switched.
  ///
  /// Example:
  /// ```dart
  /// // Create a controller
  /// final controller = YOLOViewController();
  ///
  /// // Switch between front and back camera
  /// await controller.switchCamera();
  /// ```
  Future<void> switchCamera() async {
    if (_methodChannel == null) {
      logInfo(
        'YOLOViewController: Warning - Cannot switch camera, view not yet created',
      );
      return;
    }
    try {
      await _methodChannel!.invokeMethod('switchCamera');
      logInfo('YOLOViewController: Camera switched successfully');
    } catch (e) {
      logInfo('YOLOViewController: Error switching camera: $e');
    }
  }

  /// Sets the camera zoom level to a specific value.
  ///
  /// The zoom level must be within the supported range of the camera.
  /// Typical values are 0.5x, 1.0x, 2.0x, 3.0x, etc.
  ///
  /// Example:
  /// ```dart
  /// // Set zoom to 2x
  /// await controller.setZoomLevel(2.0);
  /// ```
  Future<void> setZoomLevel(double zoomLevel) async {
    if (_methodChannel == null) {
      logInfo(
        'YoloViewController: Warning - Cannot set zoom level, view not yet created',
      );
      return;
    }
    try {
      await _methodChannel!.invokeMethod('setZoomLevel', {
        'zoomLevel': zoomLevel,
      });
      logInfo('YoloViewController: Zoom level set to $zoomLevel');
    } catch (e) {
      logInfo('YoloViewController: Error setting zoom level: $e');
    }
  }

  /// Switches to a different YOLO model.
  ///
  /// This method allows changing the model without recreating the entire view.
  /// The view must be created before calling this method.
  ///
  /// Parameters:
  /// - [modelPath]: Path to the new model file
  /// - [task]: The YOLO task type for the new model
  ///
  /// Example:
  /// ```dart
  /// await controller.switchModel(
  ///   'assets/models/yolov8s.mlmodel',
  ///   YOLOTask.segment,
  /// );
  /// ```
  ///
  /// @param modelPath The path to the new model file
  /// @param task The task type for the new model
  Future<void> switchModel(String modelPath, YOLOTask task) async {
    if (_methodChannel == null || _viewId == null) {
      logInfo(
        'YoloViewController: Warning - Cannot switch model, view not yet created',
      );
      return;
    }
    try {
      logInfo('YoloViewController: Switching model with viewId: $_viewId');

      // Call the platform method to switch model
      await const MethodChannel('yolo_single_image_channel').invokeMethod(
        'setModel',
        {'viewId': _viewId, 'modelPath': modelPath, 'task': task.name},
      );

      logInfo(
        'YoloViewController: Model switched successfully to $modelPath with task ${task.name}',
      );
    } catch (e) {
      logInfo('YoloViewController: Error switching model: $e');
      rethrow;
    }
  }

  /// Sets the streaming configuration for real-time detection.
  ///
  /// This method allows dynamic configuration of what data is included
  /// in the detection stream, enabling performance optimization based
  /// on application needs.
  ///
  /// Example:
  /// ```dart
  /// // Switch to minimal streaming for better performance
  /// await controller.setStreamingConfig(
  ///   YOLOStreamingConfig.minimal(),
  /// );
  ///
  /// // Switch to full data streaming
  /// await controller.setStreamingConfig(
  ///   YOLOStreamingConfig.full(),
  /// );
  /// ```
  ///
  /// @param config The streaming configuration to apply
  Future<void> setStreamingConfig(YOLOStreamingConfig config) async {
    if (_methodChannel == null) {
      logInfo(
        'YOLOViewController: Warning - Cannot set streaming config, view not yet created',
      );
      return;
    }
    try {
      await _methodChannel!.invokeMethod('setStreamingConfig', {
        'includeDetections': config.includeDetections,
        'includeClassifications': config.includeClassifications,
        'includeProcessingTimeMs': config.includeProcessingTimeMs,
        'includeFps': config.includeFps,
        'includeMasks': config.includeMasks,
        'includePoses': config.includePoses,
        'includeOBB': config.includeOBB,
        'includeOriginalImage': config.includeOriginalImage,
        'maxFPS': config.maxFPS,
        'throttleInterval': config.throttleInterval?.inMilliseconds,
        'inferenceFrequency': config.inferenceFrequency,
        'skipFrames': config.skipFrames,
      });
      logInfo('YOLOViewController: Streaming config updated');
    } catch (e) {
      logInfo('YOLOViewController: Error setting streaming config: $e');
    }
  }

  /// Stops the camera and inference processing.
  ///
  /// This method completely stops the camera preview and any running
  /// YOLO inference. Use this when navigating away from the detection
  /// screen to conserve battery and processing power.
  ///
  /// Example:
  /// ```dart
  /// // Stop camera when navigating away
  /// await controller.stop();
  /// ```
  Future<void> stop() async {
    if (_methodChannel == null) {
      debugPrint(
        'YOLOViewController: Warning - Cannot stop, view not yet created',
      );
      return;
    }
    try {
      await _methodChannel!.invokeMethod('stop');
      debugPrint('YOLOViewController: Stopped successfully');
    } catch (e) {
      debugPrint('YOLOViewController: Error stopping: $e');
    }
  }

  /// Pauses the camera and inference processing.
  ///
  /// This method pauses the camera preview and YOLO inference without
  /// fully releasing resources. Use this for temporary pauses where
  /// you plan to resume shortly.
  ///
  /// Example:
  /// ```dart
  /// // Pause detection temporarily
  /// await controller.pause();
  /// ```
  Future<void> pause() async {
    if (_methodChannel == null) {
      debugPrint(
        'YOLOViewController: Warning - Cannot pause, view not yet created',
      );
      return;
    }
    try {
      await _methodChannel!.invokeMethod('pause');
      debugPrint('YOLOViewController: Paused successfully');
    } catch (e) {
      debugPrint('YOLOViewController: Error pausing: $e');
    }
  }

  /// Resumes the camera and inference processing.
  ///
  /// This method resumes the camera preview and YOLO inference after
  /// being paused or stopped. It reinitializes the camera if necessary.
  ///
  /// Example:
  /// ```dart
  /// // Resume detection after pause
  /// await controller.resume();
  /// ```
  Future<void> resume() async {
    if (_methodChannel == null) {
      debugPrint(
        'YOLOViewController: Warning - Cannot resume, view not yet created',
      );
      return;
    }
    try {
      await _methodChannel!.invokeMethod('resume');
      debugPrint('YOLOViewController: Resumed successfully');
    } catch (e) {
      debugPrint('YOLOViewController: Error resuming: $e');
    }
  }
}

/// A Flutter widget that displays a real-time camera preview with YOLO object detection.
///
/// This widget creates a platform view that runs YOLO inference on camera frames
/// and provides detection results through callbacks. It supports various YOLO tasks
/// including object detection, segmentation, classification, pose estimation, and
/// oriented bounding box detection.
///
/// Example:
/// ```dart
/// YOLOView(
///   modelPath: 'assets/models/yolov8n.mlmodel',
///   task: YOLOTask.detect,
///   onResult: (List<YOLOResult> results) {
///     // Handle detection results
///     for (var result in results) {
///       print('Detected ${result.className} with ${result.confidence}');
///     }
///   },
///   onPerformanceMetrics: (Map<String, double> metrics) {
///     print('FPS: ${metrics['fps']}');
///   },
/// )
/// ```
///
/// The widget requires camera permissions to be granted before use.
/// On iOS, add NSCameraUsageDescription to Info.plist.
/// On Android, add CAMERA permission to AndroidManifest.xml.
class YOLOView extends StatefulWidget {
  /// Path to the YOLO model file.
  ///
  /// The model should be placed in the app's assets folder and
  /// included in pubspec.yaml. Supported formats:
  /// - iOS: .mlmodel (Core ML)
  /// - Android: .tflite (TensorFlow Lite)
  final String modelPath;

  /// The type of YOLO task to perform.
  ///
  /// This must match the task the model was trained for.
  /// See [YOLOTask] for available options.
  final YOLOTask task;

  /// Optional controller for managing detection settings.
  ///
  /// If not provided, a default controller will be created internally.
  /// Use a controller when you need to adjust thresholds or switch cameras.
  final YOLOViewController? controller;

  /// The camera resolution to use.
  ///
  /// Currently not implemented. Reserved for future use.
  final String cameraResolution;

  /// Callback invoked when new detection results are available.
  ///
  /// This callback provides structured, type-safe detection results as [YOLOResult] objects.
  /// It's the recommended callback for basic object detection applications.
  ///
  /// **Usage:** Basic detection, UI updates, simple statistics
  /// **Performance:** Lightweight (~1-2KB per frame)
  /// **Data:** Bounding boxes, class names, confidence scores
  ///
  /// Note: If [onStreamingData] is provided, this callback will NOT be called
  /// to avoid data duplication.
  final Function(List<YOLOResult>)? onResult;

  /// Callback invoked with performance metrics.
  ///
  /// This callback provides structured performance data as [YOLOPerformanceMetrics] objects.
  /// Use this for monitoring app performance and optimizing detection settings.
  ///
  /// **Usage:** Performance monitoring, FPS display, optimization
  /// **Performance:** Very lightweight (~100 bytes per frame)
  /// **Data:** FPS, processing time, frame numbers, timestamps
  ///
  /// Note: If [onStreamingData] is provided, this callback will NOT be called
  /// to avoid data duplication.
  final Function(YOLOPerformanceMetrics)? onPerformanceMetrics;

  /// Callback invoked with comprehensive raw streaming data.
  ///
  /// This callback provides access to ALL available YOLO data including advanced
  /// features like segmentation masks, pose keypoints, oriented bounding boxes,
  /// and original camera frames.
  ///
  /// **Usage:** Advanced AI/ML applications, research, debugging, custom processing
  /// **Performance:** Heavy (~100KB-10MB per frame depending on configuration)
  /// **Data:** Everything from [onResult] + [onPerformanceMetrics] + advanced features
  ///
  /// **IMPORTANT:** When this callback is provided, [onResult] and [onPerformanceMetrics]
  /// will NOT be called to prevent data duplication and improve performance.
  ///
  /// Available data keys:
  /// - `detections`: List<Map> - Raw detection data with all features
  /// - `fps`: double - Current frames per second
  /// - `processingTimeMs`: double - Processing time in milliseconds
  /// - `frameNumber`: int - Sequential frame number
  /// - `timestamp`: int - Timestamp in milliseconds
  /// - `originalImage`: Uint8List? - JPEG encoded camera frame (if enabled)
  final Function(Map<String, dynamic> streamData)? onStreamingData;

  /// Whether to show native UI controls on the camera preview.
  ///
  /// When true, platform-specific UI elements may be displayed,
  /// such as bounding boxes and labels drawn natively.
  final bool showNativeUI;

  /// Callback invoked when the camera zoom level changes.
  ///
  /// Provides the current zoom level as a double value (e.g., 1.0, 2.0, 3.5).
  final Function(double zoomLevel)? onZoomChanged;

  /// Initial streaming configuration for detection results.
  ///
  /// Controls what data is included in the streaming results.
  /// If not specified, uses the default minimal configuration.
  /// Can be changed dynamically via the controller.
  final YOLOStreamingConfig? streamingConfig;

  /// Initial confidence threshold for detections.
  ///
  /// Only detections with confidence above this value will be returned.
  /// Range: 0.0 to 1.0. Default is 0.5.
  final double confidenceThreshold;

  /// Initial IoU (Intersection over Union) threshold.
  ///
  /// Used for non-maximum suppression to filter overlapping detections.
  /// Range: 0.0 to 1.0. Default is 0.45.
  final double iouThreshold;

  const YOLOView({
    super.key,
    required this.modelPath,
    required this.task,
    this.controller,
    this.cameraResolution = '720p',
    this.onResult,
    this.onPerformanceMetrics,
    this.onStreamingData,
    this.showNativeUI = false,
    this.onZoomChanged,
    this.streamingConfig,
    this.confidenceThreshold = 0.5,
    this.iouThreshold = 0.45,
  });

  @override
  State<YOLOView> createState() => YOLOViewState();
}

/// State for the [YOLOView] widget.
///
/// Manages platform view creation, event channel subscriptions,
/// and communication with native YOLO implementations.
class YOLOViewState extends State<YOLOView> {
  late EventChannel _resultEventChannel;
  StreamSubscription<dynamic>? _resultSubscription;
  late MethodChannel _methodChannel;

  late YOLOViewController _effectiveController;

  final String _viewId = UniqueKey().toString();
  int? _platformViewId;

  @override
  void initState() {
    super.initState();

    final resultChannelName = 'com.ultralytics.yolo/detectionResults_$_viewId';
    _resultEventChannel = EventChannel(resultChannelName);

    final controlChannelName = 'com.ultralytics.yolo/controlChannel_$_viewId';
    _methodChannel = MethodChannel(controlChannelName);

    _setupController();

    if (widget.onResult != null ||
        widget.onPerformanceMetrics != null ||
        widget.onStreamingData != null) {
      _subscribeToResults();
    }

    // Apply initial streaming config if provided
    if (widget.streamingConfig != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _effectiveController.setStreamingConfig(widget.streamingConfig!);
      });
    }
  }

  void _setupController() {
    if (widget.controller != null) {
      _effectiveController = widget.controller!;
    } else {
      _effectiveController = YOLOViewController();
    }
    // Don't initialize here since we don't have the platform view ID yet
    // It will be initialized in _onPlatformViewCreated
  }

  @override
  void didUpdateWidget(YOLOView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      _setupController();
    }

    if (oldWidget.onResult != widget.onResult ||
        oldWidget.onPerformanceMetrics != widget.onPerformanceMetrics ||
        oldWidget.onStreamingData != widget.onStreamingData) {
      if (widget.onResult == null &&
          widget.onPerformanceMetrics == null &&
          widget.onStreamingData == null) {
        _cancelResultSubscription();
      } else {
        // If at least one callback is now non-null, ensure subscription
        _subscribeToResults();
      }
    }

    if (oldWidget.showNativeUI != widget.showNativeUI) {
      _methodChannel.invokeMethod('setShowUIControls', {
        'show': widget.showNativeUI,
      });
    }

    // Handle model or task changes
    if (_platformViewId != null &&
        (oldWidget.modelPath != widget.modelPath ||
            oldWidget.task != widget.task)) {
      _effectiveController
          .switchModel(widget.modelPath, widget.task)
          .catchError((e) {
            logInfo('YoloView: Error switching model in didUpdateWidget: $e');
          });
    }
  }

  @override
  void dispose() {
    // TODO: Uncomment when stop() method is available
    // Stop camera and inference before disposing
    // _effectiveController.stop().catchError((e) {
    //   logInfo('YOLOView: Error stopping camera during dispose: $e');
    // });

    // Cancel event subscriptions
    _cancelResultSubscription();

    // Clean up method channel handler
    _methodChannel.setMethodCallHandler(null);

    super.dispose();
  }

  @visibleForTesting
  void subscribeToResults() => _subscribeToResults();

  @visibleForTesting
  StreamSubscription<dynamic>? get resultSubscription => _resultSubscription;

  @visibleForTesting
  MethodChannel get methodChannel => _methodChannel;

  @visibleForTesting
  YOLOViewController get effectiveController => _effectiveController;

  @visibleForTesting
  Future<dynamic> handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'recreateEventChannel':
        logInfo(
          'YOLOView: Platform requested recreation of event channel for $_viewId',
        );
        _cancelResultSubscription();
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted &&
              (widget.onResult != null ||
                  widget.onPerformanceMetrics != null)) {
            _subscribeToResults();
            logInfo('YOLOView: Event channel recreated for $_viewId');
          }
        });
        return null;
      case 'onZoomChanged':
        final zoomLevel = call.arguments as double?;
        if (zoomLevel != null && widget.onZoomChanged != null) {
          logInfo('YoloView: Zoom level changed to $zoomLevel');
          widget.onZoomChanged!(zoomLevel);
        }
        return null;
      default:
        logInfo('YOLOView: Unknown method call: ${call.method}');
        return null;
    }
  }

  void _subscribeToResults() {
    _cancelResultSubscription();

    logInfo(
      'YOLOView: Setting up event stream listener for channel: ${_resultEventChannel.name}',
    );

    _resultSubscription = _resultEventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        logInfo('YOLOView: Received event from native platform: $event');

        if (event is Map && event.containsKey('test')) {
          logInfo('YOLOView: Received test message: ${event['test']}');
          return;
        }

        if (event is Map) {
          // Priority system: onStreamingData takes precedence
          if (widget.onStreamingData != null) {
            try {
              // Comprehensive mode: Pass all data via onStreamingData
              final streamData = Map<String, dynamic>.from(event);
              widget.onStreamingData!(streamData);
              logInfo(
                'YOLOView: Called onStreamingData callback (comprehensive mode) with keys: ${streamData.keys.toList()}',
              );
            } catch (e, s) {
              logInfo('Error processing streaming data: $e');
              logInfo('Stack trace for streaming error: $s');
            }
          } else {
            // Separated mode: Use individual callbacks
            logInfo('YOLOView: Using separated callback mode');

            // Handle detection results
            if (widget.onResult != null && event.containsKey('detections')) {
              try {
                final List<dynamic> detections = event['detections'] ?? [];
                logInfo('YOLOView: Received ${detections.length} detections');

                for (var i = 0; i < detections.length && i < 3; i++) {
                  final detection = detections[i];
                  final className = detection['className'] ?? 'unknown';
                  final confidence = detection['confidence'] ?? 0.0;
                  logInfo(
                    'YOLOView: Detection $i - $className (${(confidence * 100).toStringAsFixed(1)}%)',
                  );
                }

                final results = _parseDetectionResults(event);
                logInfo('YOLOView: Parsed results count: ${results.length}');
                widget.onResult!(results);
                logInfo('YOLOView: Called onResult callback with results');
              } catch (e, s) {
                logInfo('Error parsing detection results: $e');
                logInfo('Stack trace for detection error: $s');
                logInfo(
                  'YOLOView: Event keys for detection error: ${event.keys.toList()}',
                );
                if (event.containsKey('detections')) {
                  final detections = event['detections'];
                  logInfo(
                    'YOLOView: Detections type for error: ${detections.runtimeType}',
                  );
                  if (detections is List && detections.isNotEmpty) {
                    logInfo(
                      'YOLOView: First detection keys for error: ${detections.first?.keys?.toList()}',
                    );
                  }
                }
              }
            }

            // Handle performance metrics
            if (widget.onPerformanceMetrics != null) {
              try {
                logInfo(
                  'YOLOView: 🔍 Raw event data for performance metrics: $event',
                );
                final metrics = YOLOPerformanceMetrics.fromMap(
                  Map<String, dynamic>.from(event),
                );
                widget.onPerformanceMetrics!(metrics);
                logInfo(
                  'YOLOView: Called onPerformanceMetrics callback: ${metrics.toString()}',
                );
              } catch (e, s) {
                logInfo('Error parsing performance metrics: $e');
                logInfo('Stack trace for metrics error: $s');
                logInfo(
                  'YOLOView: Event keys for metrics error: ${event.keys.toList()}',
                );
              }
            }
          }
        } else {
          logInfo(
            'YOLOView: Received invalid event format or no relevant callbacks are set. Event type: ${event.runtimeType}',
          );
        }
      },
      onError: (dynamic error, StackTrace stackTrace) {
        // Added StackTrace
        logInfo('Error from detection results stream: $error');
        logInfo('Stack trace from stream error: $stackTrace');

        Future.delayed(const Duration(seconds: 2), () {
          if (_resultSubscription != null && mounted) {
            // Check mounted before resubscribing
            logInfo('YOLOView: Attempting to resubscribe after error');
            _subscribeToResults();
          } else {
            logInfo(
              'YOLOView: Not resubscribing (stream already null or widget disposed)',
            );
          }
        });
      },
      onDone: () {
        logInfo('YOLOView: Event stream closed for $_viewId');
        _resultSubscription = null;
      },
    );
    logInfo('YOLOView: Event stream listener setup complete for $_viewId');
  }

  @visibleForTesting
  void cancelResultSubscription() {
    _cancelResultSubscription();
  }

  void _cancelResultSubscription() {
    if (_resultSubscription != null) {
      logInfo('YOLOView: Cancelling existing result subscription for $_viewId');
      _resultSubscription!.cancel();
      _resultSubscription = null;
    }
  }

  @visibleForTesting
  List<YOLOResult> parseDetectionResults(Map<dynamic, dynamic> event) {
    return _parseDetectionResults(event);
  }

  List<YOLOResult> _parseDetectionResults(Map<dynamic, dynamic> event) {
    final List<dynamic> detectionsData = event['detections'] ?? [];
    logInfo('YOLOView: Parsing ${detectionsData.length} detections');

    if (detectionsData.isNotEmpty) {
      final first = detectionsData.first;
      logInfo(
        'YOLOView: First detection structure: ${first.runtimeType} with keys: ${first is Map ? first.keys.toList() : "not a map"}',
      );

      if (first is Map) {
        logInfo('YOLOView: ClassIndex: ${first["classIndex"]}');
        logInfo('YOLOView: ClassName: ${first["className"]}');
        logInfo('YOLOView: Confidence: ${first["confidence"]}');
        logInfo('YOLOView: BoundingBox: ${first["boundingBox"]}');
        logInfo('YOLOView: NormalizedBox: ${first["normalizedBox"]}');
      }
    }

    try {
      final results = detectionsData.map((detection) {
        try {
          return YOLOResult.fromMap(detection);
        } catch (e) {
          logInfo('YOLOView: Error parsing single detection: $e');
          logInfo('YOLOView: Problem detection data: $detection');
          rethrow;
        }
      }).toList();

      logInfo('YOLOView: Successfully parsed ${results.length} results');
      return results;
    } catch (e) {
      logInfo('YOLOView: Error parsing detections list: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    const viewType = 'com.ultralytics.yolo/YOLOPlatformView';
    final creationParams = <String, dynamic>{
      'modelPath': widget.modelPath,
      'task': widget.task.name,
      'confidenceThreshold': widget.confidenceThreshold,
      'iouThreshold': widget.iouThreshold,
      'numItemsThreshold': _effectiveController.numItemsThreshold,
      'viewId': _viewId,
    };

    // Add streaming config to creation params if provided
    if (widget.streamingConfig != null) {
      creationParams['streamingConfig'] = {
        'includeDetections': widget.streamingConfig!.includeDetections,
        'includeClassifications':
            widget.streamingConfig!.includeClassifications,
        'includeProcessingTimeMs':
            widget.streamingConfig!.includeProcessingTimeMs,
        'includeFps': widget.streamingConfig!.includeFps,
        'includeMasks': widget.streamingConfig!.includeMasks,
        'includePoses': widget.streamingConfig!.includePoses,
        'includeOBB': widget.streamingConfig!.includeOBB,
        'includeOriginalImage': widget.streamingConfig!.includeOriginalImage,
        'maxFPS': widget.streamingConfig!.maxFPS,
        'throttleInterval':
            widget.streamingConfig!.throttleInterval?.inMilliseconds,
      };
    }

    // This was causing issues in initState/didUpdateWidget, better to call once after view created.
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   if (mounted) { // Ensure widget is still mounted
    //    _methodChannel.invokeMethod('setShowUIControls', {'show': widget.showNativeUI});
    //   }
    // });

    Widget platformView;
    if (defaultTargetPlatform == TargetPlatform.android) {
      platformView = AndroidView(
        viewType: viewType,
        layoutDirection: TextDirection.ltr,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      platformView = UiKitView(
        viewType: viewType,
        layoutDirection: TextDirection.ltr,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
      );
    } else {
      platformView = const Center(
        child: Text('Platform not supported for YOLOView'),
      );
    }
    return platformView;
  }

  @visibleForTesting
  void triggerPlatformViewCreated(int id) => _onPlatformViewCreated(id);

  void _onPlatformViewCreated(int id) {
    logInfo(
      'YOLOView: Platform view created with system id: $id, our viewId: $_viewId',
    );

    _platformViewId = id;

    // _cancelResultSubscription(); // Already called in _subscribeToResults if needed

    if (widget.onResult != null || widget.onPerformanceMetrics != null) {
      logInfo(
        'YOLOView: Re-subscribing to results after platform view creation for $_viewId',
      );
      _subscribeToResults();
    }

    logInfo('YoloView: Initializing controller with platform view ID: $id');
    _effectiveController._init(
      _methodChannel,
      id,
    ); // Re-init controller with the now valid method channel

    _methodChannel.invokeMethod('setShowUIControls', {
      'show': widget.showNativeUI,
    });

    _methodChannel.setMethodCallHandler(handleMethodCall);
  }

  // Methods to be called via GlobalKey
  /// Sets the confidence threshold through the widget's state.
  ///
  /// This method can be called using a GlobalKey to access the state:
  /// ```dart
  /// final key = GlobalKey<YOLOViewState>();
  /// // Later...
  /// key.currentState?.setConfidenceThreshold(0.7);
  /// ```
  Future<void> setConfidenceThreshold(double threshold) {
    return _effectiveController.setConfidenceThreshold(threshold);
  }

  /// Sets the IoU threshold through the widget's state.
  ///
  /// This method can be called using a GlobalKey to access the state.
  Future<void> setIoUThreshold(double threshold) {
    return _effectiveController.setIoUThreshold(threshold);
  }

  /// Sets the maximum number of items threshold through the widget's state.
  ///
  /// This method can be called using a GlobalKey to access the state.
  Future<void> setNumItemsThreshold(int numItems) {
    return _effectiveController.setNumItemsThreshold(numItems);
  }

  /// Sets multiple thresholds through the widget's state.
  ///
  /// This method can be called using a GlobalKey to access the state.
  Future<void> setThresholds({
    double? confidenceThreshold,
    double? iouThreshold,
    int? numItemsThreshold,
  }) {
    return _effectiveController.setThresholds(
      confidenceThreshold: confidenceThreshold,
      iouThreshold: iouThreshold,
      numItemsThreshold: numItemsThreshold,
    );
  }

  /// Switches between front and back camera.
  ///
  /// This method toggles the camera between front-facing and back-facing modes.
  /// It delegates to the effective controller's switchCamera method.
  /// Returns a [Future] that completes when the camera has been switched.
  Future<void> switchCamera() {
    return _effectiveController.switchCamera();
  }

  /// Sets the camera zoom level to a specific value.
  ///
  /// The zoom level must be within the supported range of the camera.
  /// Typical values are 0.5x, 1.0x, 2.0x, 3.0x, etc.
  /// It delegates to the effective controller's setZoomLevel method.
  /// Returns a [Future] that completes when the zoom level has been set.
  Future<void> setZoomLevel(double zoomLevel) {
    return _effectiveController.setZoomLevel(zoomLevel);
  }

  /// Stops the camera and inference processing.
  ///
  /// This method can be called using a GlobalKey to access the state:
  /// ```dart
  /// final key = GlobalKey<YOLOViewState>();
  /// // Later...
  /// key.currentState?.stop();
  /// ```
  Future<void> stop() {
    return _effectiveController.stop();
  }

  /// Pauses the camera and inference processing.
  ///
  /// This method can be called using a GlobalKey to access the state.
  Future<void> pause() {
    return _effectiveController.pause();
  }

  /// Resumes the camera and inference processing.
  ///
  /// This method can be called using a GlobalKey to access the state.
  Future<void> resume() {
    return _effectiveController.resume();
  }
}
