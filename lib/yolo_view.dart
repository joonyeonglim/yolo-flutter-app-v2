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
    } catch (e) {
      logInfo('YOLOViewController: Error applying combined thresholds: $e');
      try {
        await _methodChannel!.invokeMethod('setConfidenceThreshold', {
          'threshold': _confidenceThreshold,
        });
        await _methodChannel!.invokeMethod('setIoUThreshold', {
          'threshold': _iouThreshold,
        });
        await _methodChannel!.invokeMethod('setNumItemsThreshold', {
          'numItems': _numItemsThreshold,
        });
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
      await const MethodChannel('yolo_single_image_channel').invokeMethod(
        'setModel',
        {'viewId': _viewId, 'modelPath': modelPath, 'task': task.name},
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
    } catch (e) {
      logInfo('YOLOViewController: Error setting streaming config: $e');
    }
  }

  // region Recording Functions
  
  /// Starts video recording with YOLO inference overlay.
  ///
  /// This method initiates video recording of the camera feed with real-time
  /// YOLO inference results overlaid on the video. The recorded video will
  /// include all detection boxes, classifications, and other visual elements.
  ///
  /// Parameters:
  /// - [includeAudio]: Whether to include audio in the recording (default: true)
  ///
  /// Returns a [Future<String>] containing the file path or URI of the recorded video.
  /// 
  /// Throws an exception if:
  /// - Recording is already in progress
  /// - Camera permissions are not granted
  /// - Storage permissions are not available (Android)
  /// - The device doesn't support video recording
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   final videoPath = await controller.startRecording();
  ///   print('Recording started, will save to: $videoPath');
  /// } catch (e) {
  ///   print('Failed to start recording: $e');
  /// }
  /// ```
  ///
  /// Platform-specific behavior:
  /// - **iOS**: Video saved to app's Documents directory
  /// - **Android**: Video saved to MediaStore (Movies/YOLORecordings)
  Future<String> startRecording({bool includeAudio = true}) async {
    if (_methodChannel == null) {
      throw Exception('Cannot start recording - view not yet created');
    }
    
    try {
      final result = await _methodChannel!.invokeMethod<String>('startRecording', {
        'includeAudio': includeAudio,
      });
      
      if (result == null) {
        throw Exception('Recording failed - no result returned');
      }
      
      return result;
    } catch (e) {
      logInfo('YOLOViewController: Error starting recording: $e');
      rethrow;
    }
  }

  /// Stops the current video recording.
  ///
  /// This method stops the ongoing video recording and finalizes the video file.
  /// The method returns the final path or URI where the completed video is stored.
  ///
  /// Returns a [Future<String>] containing the file path or URI of the completed video.
  ///
  /// Throws an exception if:
  /// - No recording is currently in progress
  /// - An error occurs while finalizing the video
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   final videoPath = await controller.stopRecording();
  ///   print('Recording completed and saved to: $videoPath');
  ///   
  ///   // You can now share, play, or process the video
  ///   await Share.shareFiles([videoPath], text: 'Check out my YOLO detection video!');
  /// } catch (e) {
  ///   print('Failed to stop recording: $e');
  /// }
  /// ```
  ///
  /// Platform-specific behavior:
  /// - **iOS**: Returns file:// URL to the saved video
  /// - **Android**: Returns content:// URI that can be used with MediaStore
  Future<String> stopRecording() async {
    if (_methodChannel == null) {
      throw Exception('Cannot stop recording - view not yet created');
    }
    
    try {
      final result = await _methodChannel!.invokeMethod<String>('stopRecording');
      
      if (result == null) {
        throw Exception('Stop recording failed - no result returned');
      }
      
      return result;
    } catch (e) {
      logInfo('YOLOViewController: Error stopping recording: $e');
      rethrow;
    }
  }

  /// Checks if video recording is currently in progress.
  ///
  /// This method returns the current recording state without affecting
  /// the recording process.
  ///
  /// Returns a [Future<bool>] indicating whether recording is active.
  ///
  /// Example:
  /// ```dart
  /// if (await controller.isRecording()) {
  ///   print('Recording is in progress');
  ///   // Show recording indicator in UI
  /// } else {
  ///   print('Not currently recording');
  ///   // Show start recording button
  /// }
  /// ```
  Future<bool> isRecording() async {
    if (_methodChannel == null) {
      return false;
    }
    
    try {
      final result = await _methodChannel!.invokeMethod<bool>('isRecording');
      return result ?? false;
    } catch (e) {
      logInfo('YOLOViewController: Error checking recording status: $e');
      return false;
    }
  }

  /// Sets whether audio should be included in video recordings.
  ///
  /// This setting affects future recordings started with [startRecording].
  /// It does not affect recordings that are already in progress.
  ///
  /// Parameters:
  /// - [enabled]: Whether to include audio in recordings (default: true)
  ///
  /// Note: On Android, this requires RECORD_AUDIO permission.
  /// If the permission is not granted, recordings will be video-only
  /// regardless of this setting.
  ///
  /// Example:
  /// ```dart
  /// // Disable audio for privacy or performance reasons
  /// await controller.setAudioEnabled(false);
  /// 
  /// // Start a video-only recording
  /// await controller.startRecording();
  /// ```
  Future<void> setAudioEnabled(bool enabled) async {
    if (_methodChannel == null) {
      logInfo(
        'YOLOViewController: Warning - Cannot set audio enabled, view not yet created',
      );
      return;
    }
    
    try {
      await _methodChannel!.invokeMethod('setAudioEnabled', {
        'enabled': enabled,
      });
    } catch (e) {
      logInfo('YOLOViewController: Error setting audio enabled: $e');
    }
  }

  // endregion
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
        _cancelResultSubscription();
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted &&
              (widget.onResult != null ||
                  widget.onPerformanceMetrics != null)) {
            _subscribeToResults();
          }
        });
        return null;
      case 'onZoomChanged':
        final zoomLevel = call.arguments as double?;
        if (zoomLevel != null && widget.onZoomChanged != null) {
          widget.onZoomChanged!(zoomLevel);
        }
        return null;
      default:
        return null;
    }
  }

  void _subscribeToResults() {
    _cancelResultSubscription();

    _resultSubscription = _resultEventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is Map && event.containsKey('test')) {
          return;
        }

        if (event is Map) {
          // Priority system: onStreamingData takes precedence
          if (widget.onStreamingData != null) {
            try {
              // Comprehensive mode: Pass all data via onStreamingData
              final streamData = Map<String, dynamic>.from(event);
              widget.onStreamingData!(streamData);
            } catch (e, s) {
              logInfo('Error processing streaming data: $e');
              logInfo('Stack trace for streaming error: $s');
            }
          } else {
            // Separated mode: Use individual callbacks

            // Handle detection results
            if (widget.onResult != null && event.containsKey('detections')) {
              try {
                final results = _parseDetectionResults(event);
                widget.onResult!(results);
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
                final metrics = YOLOPerformanceMetrics.fromMap(
                  Map<String, dynamic>.from(event),
                );
                widget.onPerformanceMetrics!(metrics);
              } catch (e, s) {
                logInfo('Error parsing performance metrics: $e');
                logInfo('Stack trace for metrics error: $s');
              }
            }
          }
        }
      },
      onError: (dynamic error, StackTrace stackTrace) {
        // Added StackTrace
        logInfo('Error from detection results stream: $error');
        logInfo('Stack trace from stream error: $stackTrace');

        Future.delayed(const Duration(seconds: 2), () {
          if (_resultSubscription != null && mounted) {
            // Check mounted before resubscribing
            _subscribeToResults();
          }
        });
      },
      onDone: () {
        _resultSubscription = null;
      },
    );
  }

  @visibleForTesting
  void cancelResultSubscription() {
    _cancelResultSubscription();
  }

  void _cancelResultSubscription() {
    if (_resultSubscription != null) {
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

    try {
      final results = detectionsData.map((detection) {
        try {
          return YOLOResult.fromMap(detection);
        } catch (e) {
          logInfo('YOLOView: Error parsing single detection: $e');
          rethrow;
        }
      }).toList();

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
    _platformViewId = id;

    // _cancelResultSubscription(); // Already called in _subscribeToResults if needed

    if (widget.onResult != null || widget.onPerformanceMetrics != null) {
      _subscribeToResults();
    }

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
}
