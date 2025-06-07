// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

import Flutter
import UIKit

// Helper extension for Float to Double conversion
extension Float {
  var double: Double {
    return Double(self)
  }
}

@MainActor
public class SwiftYOLOPlatformView: NSObject, FlutterPlatformView, FlutterStreamHandler {
  private let frame: CGRect
  private let viewId: Int64
  private let messenger: FlutterBinaryMessenger

  // Event channel for sending detection results
  private let eventChannel: FlutterEventChannel
  private var eventSink: FlutterEventSink?

  // Method channel for receiving control commands
  private let methodChannel: FlutterMethodChannel

  // Reference to YOLOView
  private var yoloView: YOLOView?

  init(
    frame: CGRect,
    viewId: Int64,
    args: Any?,
    messenger: FlutterBinaryMessenger
  ) {
    self.frame = frame
    self.viewId = viewId
    self.messenger = messenger

    // Get viewId passed from Flutter (primarily a string ID)
    let flutterViewId: String
    if let dict = args as? [String: Any], let viewIdStr = dict["viewId"] as? String {
      flutterViewId = viewIdStr
      print("SwiftYOLOPlatformView: Using Flutter-provided viewId: \(flutterViewId)")
    } else {
      // Fallback: Convert numeric viewId to string
      flutterViewId = "\(viewId)"
      print("SwiftYOLOPlatformView: Using fallback numeric viewId: \(flutterViewId)")
    }

    // Setup event channel - create unique channel name using view ID
    let eventChannelName = "com.ultralytics.yolo/detectionResults_\(flutterViewId)"
    print("SwiftYOLOPlatformView: Creating event channel with name: \(eventChannelName)")
    self.eventChannel = FlutterEventChannel(name: eventChannelName, binaryMessenger: messenger)

    // Setup method channel - create unique channel name using view ID
    let methodChannelName = "com.ultralytics.yolo/controlChannel_\(flutterViewId)"
    print("SwiftYOLOPlatformView: Creating method channel with name: \(methodChannelName)")
    self.methodChannel = FlutterMethodChannel(name: methodChannelName, binaryMessenger: messenger)

    super.init()

    // Set self as stream handler for event channel
    self.eventChannel.setStreamHandler(self)

    // Unwrap creation parameters
    if let dict = args as? [String: Any],
      let modelName = dict["modelPath"] as? String,
      let taskRaw = dict["task"] as? String
    {
      let task = YOLOTask.fromString(taskRaw)

      print("SwiftYOLOPlatformView: Received modelPath: \(modelName)")

      // Get new threshold parameters
      let confidenceThreshold = dict["confidenceThreshold"] as? Double ?? 0.5
      let iouThreshold = dict["iouThreshold"] as? Double ?? 0.45

      // Old threshold parameter for backward compatibility
      let oldThreshold = dict["threshold"] as? Double ?? 0.5

      // Determine which thresholds to use (prioritize new parameters)
      print(
        "SwiftYOLOPlatformView: Received thresholds - confidence: \(confidenceThreshold), IoU: \(iouThreshold), old: \(oldThreshold)"
      )

      // Create YOLOView
      yoloView = YOLOView(
        frame: frame,
        modelPathOrName: modelName,
        task: task
      )

      // Hide native UI controls by default
      yoloView?.showUIControls = false

      // Configure YOLOView streaming functionality
      setupYOLOViewStreaming(args: dict)

      // Configure YOLOView
      setupYOLOView(confidenceThreshold: confidenceThreshold, iouThreshold: iouThreshold)

      // Setup method channel handler
      setupMethodChannel()

      // Setup zoom callback
      yoloView?.onZoomChanged = { [weak self] zoomLevel in
        self?.methodChannel.invokeMethod("onZoomChanged", arguments: Double(zoomLevel))
      }

      // Register this view with the factory
      if let yoloView = yoloView {
        SwiftYOLOPlatformViewFactory.register(yoloView, for: Int(viewId))
      }
    }
  }

  // Method for backward compatibility
  private func setupYOLOView(threshold: Double) {
    setupYOLOView(confidenceThreshold: threshold, iouThreshold: 0.45)  // Use default IoU value
  }

  // Setup YOLOView and connect callbacks (using new parameters)
  private func setupYOLOView(confidenceThreshold: Double, iouThreshold: Double) {
    guard let yoloView = yoloView else { return }

    // Debug information
    print(
      "SwiftYOLOPlatformView: setupYOLOView - Setting up detection callback with confidenceThreshold: \(confidenceThreshold), iouThreshold: \(iouThreshold)"
    )

    // YOLOView streaming is now configured separately
    // Keep simple detection callback for compatibility
    yoloView.onDetection = { result in
      print(
        "SwiftYOLOPlatformView: onDetection callback triggered with \(result.boxes.count) detections"
      )
    }

    // Set thresholds
    updateThresholds(confidenceThreshold: confidenceThreshold, iouThreshold: iouThreshold)
  }

  // Method to update threshold (kept for backward compatibility)
  private func updateThreshold(threshold: Double) {
    updateThresholds(confidenceThreshold: threshold, iouThreshold: nil)
  }

  // Overloaded method for setting just numItemsThreshold
  private func updateThresholds(numItemsThreshold: Int) {
    updateThresholds(
      confidenceThreshold: Double(self.yoloView?.sliderConf.value ?? 0.5),
      iouThreshold: nil,
      numItemsThreshold: numItemsThreshold
    )
  }

  // Method to update multiple thresholds
  private func updateThresholds(
    confidenceThreshold: Double, iouThreshold: Double?, numItemsThreshold: Int? = nil
  ) {
    guard let yoloView = yoloView else { return }

    print(
      "SwiftYoloPlatformView: Updating thresholds - confidence: \(confidenceThreshold), IoU: \(String(describing: iouThreshold)), numItems: \(String(describing: numItemsThreshold))"
    )

    // Set confidence threshold
    yoloView.sliderConf.value = Float(confidenceThreshold)
    yoloView.sliderChanged(yoloView.sliderConf)

    // Set IoU threshold only if specified
    if let iou = iouThreshold {
      yoloView.sliderIoU.value = Float(iou)
      yoloView.sliderChanged(yoloView.sliderIoU)
    }

    // Set numItems threshold only if specified
    if let numItems = numItemsThreshold {
      yoloView.sliderNumItems.value = Float(numItems)
      yoloView.sliderChanged(yoloView.sliderNumItems)
    }
  }

  // Setup method channel call handler
  private func setupMethodChannel() {
    // Set method channel handler
    methodChannel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else {
        result(
          FlutterError(
            code: "not_available", message: "YoloPlatformView was disposed", details: nil))
        return
      }

      switch call.method {
      case "setThreshold":
        // Maintained for backward compatibility
        if let args = call.arguments as? [String: Any],
          let threshold = args["threshold"] as? Double
        {
          print("SwiftYOLOPlatformView: Received setThreshold call with threshold: \(threshold)")
          self.updateThreshold(threshold: threshold)
          result(nil)  // Success
        } else {
          result(
            FlutterError(
              code: "invalid_args", message: "Invalid arguments for setThreshold", details: nil))
        }

      case "setConfidenceThreshold":
        // Individual method for setting confidence threshold
        if let args = call.arguments as? [String: Any],
          let threshold = args["threshold"] as? Double
        {
          print(
            "SwiftYoloPlatformView: Received setConfidenceThreshold call with value: \(threshold)")
          self.updateThresholds(
            confidenceThreshold: threshold,
            iouThreshold: nil,
            numItemsThreshold: nil
          )
          result(nil)  // Success
        } else {
          result(
            FlutterError(
              code: "invalid_args", message: "Invalid arguments for setConfidenceThreshold",
              details: nil))
        }

      case "setIoUThreshold", "setIouThreshold":
        // Individual method for setting IoU threshold
        if let args = call.arguments as? [String: Any],
          let threshold = args["threshold"] as? Double
        {
          print("SwiftYOLOPlatformView: Received setIoUThreshold call with value: \(threshold)")
          self.updateThresholds(
            confidenceThreshold: Double(self.yoloView?.sliderConf.value ?? 0.5),
            iouThreshold: threshold,
            numItemsThreshold: nil
          )
          result(nil)  // Success
        } else {
          result(
            FlutterError(
              code: "invalid_args", message: "Invalid arguments for setIoUThreshold", details: nil))
        }

      case "setNumItemsThreshold":
        // New method for setting numItems threshold
        if let args = call.arguments as? [String: Any],
          let numItems = args["numItems"] as? Int
        {
          print("SwiftYOLOPlatformView: Received setNumItemsThreshold call with value: \(numItems)")
          // Keep current confidence and IoU thresholds
          self.updateThresholds(
            numItemsThreshold: numItems
          )
          result(nil)  // Success
        } else {
          result(
            FlutterError(
              code: "invalid_args", message: "Invalid arguments for setNumItemsThreshold",
              details: nil))
        }

      case "setThresholds":
        // New method for setting multiple thresholds
        if let args = call.arguments as? [String: Any],
          let confidenceThreshold = args["confidenceThreshold"] as? Double
        {
          // IoU and numItems thresholds are optional
          let iouThreshold = args["iouThreshold"] as? Double
          let numItemsThreshold = args["numItemsThreshold"] as? Int

          print(
            "SwiftYoloPlatformView: Received setThresholds call with confidence: \(confidenceThreshold), IoU: \(String(describing: iouThreshold)), numItems: \(String(describing: numItemsThreshold))"
          )
          self.updateThresholds(
            confidenceThreshold: confidenceThreshold,
            iouThreshold: iouThreshold,
            numItemsThreshold: numItemsThreshold
          )
          result(nil)  // Success
        } else {
          result(
            FlutterError(
              code: "invalid_args", message: "Invalid arguments for setThresholds", details: nil))
        }

      case "setShowUIControls":
        // Method to toggle native UI controls visibility
        if let args = call.arguments as? [String: Any],
          let show = args["show"] as? Bool
        {
          print("SwiftYOLOPlatformView: Setting UI controls visibility to \(show)")
          yoloView?.showUIControls = show
          result(nil)  // Success
        } else {
          result(
            FlutterError(
              code: "invalid_args", message: "Invalid arguments for setShowUIControls", details: nil
            ))
        }

      case "switchCamera":
        print("SwiftYoloPlatformView: Received switchCamera call")
        self.yoloView?.switchCameraTapped()
        result(nil)  // Success

      case "setZoomLevel":
        if let args = call.arguments as? [String: Any],
          let zoomLevel = args["zoomLevel"] as? Double
        {
          print("SwiftYoloPlatformView: Received setZoomLevel call with value: \(zoomLevel)")
          self.yoloView?.setZoomLevel(CGFloat(zoomLevel))
          result(nil)  // Success
        } else {
          result(
            FlutterError(
              code: "invalid_args", message: "Invalid arguments for setZoomLevel", details: nil))
        }

      case "setStreamingConfig":
        // Method to update streaming configuration
        if let args = call.arguments as? [String: Any] {
          print("SwiftYOLOPlatformView: Received setStreamingConfig call")
          let streamConfig = YOLOStreamConfig.from(dict: args)
          self.yoloView?.setStreamConfig(streamConfig)
          print("SwiftYOLOPlatformView: YOLOView streaming config updated")
          result(nil)  // Success
        } else {
          result(
            FlutterError(
              code: "invalid_args", message: "Invalid arguments for setStreamingConfig",
              details: nil
            ))
        }

      // Recording methods
      case "startRecording":
        if let args = call.arguments as? [String: Any],
           let includeAudio = args["includeAudio"] as? Bool {
          print("SwiftYOLOPlatformView: Received startRecording call with includeAudio: \(includeAudio)")
          
          // VideoCapture에서 recording 시작
          guard let yoloView = self.yoloView else {
            result(FlutterError(code: "not_available", message: "YOLOView not available", details: nil))
            return
          }
          
          let videoCapture = yoloView.videoCapture
          
          videoCapture.startRecording { [weak self] url, error in
            DispatchQueue.main.async {
              if let error = error {
                result(FlutterError(code: "recording_error", message: error.localizedDescription, details: nil))
              } else if let url = url {
                result(url.absoluteString)
              } else {
                result(FlutterError(code: "recording_error", message: "Recording failed - no URL returned", details: nil))
              }
            }
          }
        } else {
          result(FlutterError(code: "invalid_args", message: "Invalid arguments for startRecording", details: nil))
        }

      case "stopRecording":
        print("SwiftYOLOPlatformView: Received stopRecording call")
        
        guard let yoloView = self.yoloView else {
          result(FlutterError(code: "not_available", message: "YOLOView not available", details: nil))
          return
        }
        
        let videoCapture = yoloView.videoCapture
        
        videoCapture.stopRecording { [weak self] url, error in
          DispatchQueue.main.async {
            if let error = error {
              result(FlutterError(code: "recording_error", message: error.localizedDescription, details: nil))
            } else if let url = url {
              result(url.absoluteString)
            } else {
              result(FlutterError(code: "recording_error", message: "Stop recording failed - no URL returned", details: nil))
            }
          }
        }

      case "isRecording":
        print("SwiftYOLOPlatformView: Received isRecording call")
        
        guard let yoloView = self.yoloView else {
          result(false)
          return
        }
        
        let videoCapture = yoloView.videoCapture
        
        result(videoCapture.isRecording)

      case "setAudioEnabled":
        if let args = call.arguments as? [String: Any],
           let enabled = args["enabled"] as? Bool {
          print("SwiftYOLOPlatformView: Received setAudioEnabled call with enabled: \(enabled)")
          
          guard let yoloView = self.yoloView else {
            result(FlutterError(code: "not_available", message: "YOLOView not available", details: nil))
            return
          }
          
          let videoCapture = yoloView.videoCapture
          
          videoCapture.audioEnabled = enabled
          result(nil)
        } else {
          result(FlutterError(code: "invalid_args", message: "Invalid arguments for setAudioEnabled", details: nil))
        }

      case "stop":
        // Stop camera and inference
        print("SwiftYOLOPlatformView: Stopping camera and inference")
        yoloView?.stop()
        result(nil)  // Success

      case "pause":
        // Pause camera and inference (iOS doesn't distinguish pause from stop)
        print("SwiftYOLOPlatformView: Pausing camera and inference")
        yoloView?.stop()
        result(nil)  // Success

      case "resume":
        // Resume camera and inference
        print("SwiftYOLOPlatformView: Resuming camera and inference")
        yoloView?.resume()
        result(nil)  // Success

      case "switchCamera":
        // Switch between front and back camera
        print("SwiftYOLOPlatformView: Switching camera")
        yoloView?.videoCapture.switchCamera()
        result(nil)  // Success

      // Additional methods can be added here in the future

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Configure YOLOView streaming functionality based on creation parameters
  private func setupYOLOViewStreaming(args: [String: Any]) {
    guard let yoloView = yoloView else { return }

    // Parse streaming configuration from args
    let streamingConfigParam = args["streamingConfig"] as? [String: Any]

    let streamConfig: YOLOStreamConfig
    if let configDict = streamingConfigParam {
      print("SwiftYOLOPlatformView: Creating YOLOStreamConfig from creation params: \(configDict)")
      streamConfig = YOLOStreamConfig.from(dict: configDict)
    } else {
      // Use default minimal configuration for optimal performance
      print("SwiftYOLOPlatformView: Using default streaming config")
      streamConfig = YOLOStreamConfig.DEFAULT
    }

    // Configure YOLOView with the stream config
    yoloView.setStreamConfig(streamConfig)
    print("SwiftYOLOPlatformView: YOLOView streaming configured: \(streamConfig)")

    // Set up streaming callback to forward data to Flutter via event channel
    yoloView.setStreamCallback { [weak self] streamData in
      // Forward streaming data from YOLOView to Flutter
      self?.sendStreamDataToFlutter(streamData)
    }
  }

  /// Send stream data to Flutter via event channel
  private func sendStreamDataToFlutter(_ streamData: [String: Any]) {
    print(
      "SwiftYOLOPlatformView: Sending stream data to Flutter: \(streamData.keys.joined(separator: ", "))"
    )

    guard let eventSink = self.eventSink else {
      print("SwiftYOLOPlatformView: eventSink is nil - no listener for events")
      return
    }

    // Send event on main thread
    DispatchQueue.main.async {
      print("SwiftYOLOPlatformView: Sending stream data to Flutter via eventSink")
      eventSink(streamData)
    }
  }

  public func view() -> UIView {
    return yoloView ?? UIView()
  }

  // MARK: - FlutterStreamHandler Protocol

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    print("SwiftYOLOPlatformView: onListen called - Stream handler connected")
    self.eventSink = events
    print("SwiftYOLOPlatformView: eventSink set successfully")
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    print("SwiftYOLOPlatformView: onCancel called - Stream handler disconnected")
    self.eventSink = nil
    return nil
  }

  // MARK: - Cleanup

  deinit {
    // Clean up event channel
    eventSink = nil
    eventChannel.setStreamHandler(nil)

    // Clean up method channel
    methodChannel.setMethodCallHandler(nil)

    // Unregister from factory using Task
    let capturedViewId = Int(viewId)
    Task { @MainActor in
      SwiftYOLOPlatformViewFactory.unregister(for: capturedViewId)
    }

    // Clean up YOLOView
    // Only set to nil because MainActor-isolated methods can't be called directly
    yoloView = nil

    // Note: stop() method call was removed due to MainActor issues
    // If setting up later in a Task, use code like this:
    // Task { @MainActor in
    //    self.yoloView?.stop()
    // }
  }
}
