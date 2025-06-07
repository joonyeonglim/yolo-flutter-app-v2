// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

//
//  This file is part of the Ultralytics YOLO Package, managing camera capture for real-time inference.
//  Licensed under AGPL-3.0. For commercial use, refer to Ultralytics licensing: https://ultralytics.com/license
//  Access the source code: https://github.com/ultralytics/yolo-ios-app
//
//  The VideoCapture component manages the camera and video processing pipeline for real-time
//  object detection. It handles setting up the AVCaptureSession, managing camera devices,
//  configuring camera properties like focus and exposure, and processing video frames for
//  model inference. The class delivers capture frames to the predictor component for real-time
//  analysis and returns results through delegate callbacks. It also supports camera controls
//  such as switching between front and back cameras, zooming, and capturing still photos.

import AVFoundation
import CoreVideo
import UIKit
import Vision

/// Protocol for video recording functionality
public protocol VideoRecordable {
    var isRecording: Bool { get }
    func startRecording(completion: @escaping (URL?, Error?) -> Void)
    func stopRecording(completion: @escaping (URL?, Error?) -> Void)
}

/// Protocol for receiving video capture frame processing results.
@MainActor
protocol VideoCaptureDelegate: AnyObject {
  func onPredict(result: YOLOResult)
  func onInferenceTime(speed: Double, fps: Double)
}

func bestCaptureDevice(position: AVCaptureDevice.Position) -> AVCaptureDevice {
  // print("USE TELEPHOTO: ")
  // print(UserDefaults.standard.bool(forKey: "use_telephoto"))

  if UserDefaults.standard.bool(forKey: "use_telephoto"),
    let device = AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: position)
  {
    return device
  } else if let device = AVCaptureDevice.default(
    .builtInDualCamera, for: .video, position: position)
  {
    return device
  } else if let device = AVCaptureDevice.default(
    .builtInWideAngleCamera, for: .video, position: position)
  {
    return device
  } else {
    fatalError("Missing expected back camera device.")
  }
}

class VideoCapture: NSObject, @unchecked Sendable, VideoRecordable {
  var predictor: Predictor!
  var previewLayer: AVCaptureVideoPreviewLayer?
  weak var delegate: VideoCaptureDelegate?
  var captureDevice: AVCaptureDevice?
  let captureSession = AVCaptureSession()
  var videoInput: AVCaptureDeviceInput? = nil
  let videoOutput = AVCaptureVideoDataOutput()
  var photoOutput = AVCapturePhotoOutput()
  let cameraQueue = DispatchQueue(label: "camera-queue")
  var lastCapturedPhoto: UIImage? = nil
  var inferenceOK = true
  var longSide: CGFloat = 3
  var shortSide: CGFloat = 4
  var frameSizeCaptured = false

  private var currentBuffer: CVPixelBuffer?
  
  // Recording 관련 프로퍼티들
  let movieFileOutput = AVCaptureMovieFileOutput()
  var isRecording = false
  var audioEnabled = true
  var currentPosition = AVCaptureDevice.Position.back
  var currentZoomFactor: CGFloat = 1.0
  var isSlowMotionEnabled = false
  var currentFrameRate: Int = 30
  var recordingCompletionHandler: ((URL?, Error?) -> Void)?
  var currentRecordingURL: URL?

  func setUp(
    sessionPreset: AVCaptureSession.Preset = .hd1280x720,
    position: AVCaptureDevice.Position,
    orientation: UIDeviceOrientation,
    completion: @escaping (Bool) -> Void
  ) {
    cameraQueue.async {
      let success = self.setUpCamera(
        sessionPreset: sessionPreset, position: position, orientation: orientation)
      DispatchQueue.main.async {
        completion(success)
      }
    }
  }

  func setUpCamera(
    sessionPreset: AVCaptureSession.Preset, position: AVCaptureDevice.Position,
    orientation: UIDeviceOrientation
  ) -> Bool {
    captureSession.beginConfiguration()
    captureSession.sessionPreset = sessionPreset

    captureDevice = bestCaptureDevice(position: position)
    videoInput = try! AVCaptureDeviceInput(device: captureDevice!)
    
    // 현재 카메라 위치 저장
    currentPosition = position

    if captureSession.canAddInput(videoInput!) {
      captureSession.addInput(videoInput!)
    }
    var videoOrientaion = AVCaptureVideoOrientation.portrait
    switch orientation {
    case .portrait:
      videoOrientaion = .portrait
    case .landscapeLeft:
      videoOrientaion = .landscapeRight
    case .landscapeRight:
      videoOrientaion = .landscapeLeft
    default:
      videoOrientaion = .portrait
    }
    let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
    previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
    previewLayer.connection?.videoOrientation = videoOrientaion
    self.previewLayer = previewLayer

    let settings: [String: Any] = [
      kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA)
    ]

    videoOutput.videoSettings = settings
    videoOutput.alwaysDiscardsLateVideoFrames = true
    videoOutput.setSampleBufferDelegate(self, queue: cameraQueue)
    if captureSession.canAddOutput(videoOutput) {
      captureSession.addOutput(videoOutput)
    }
    if captureSession.canAddOutput(photoOutput) {
      captureSession.addOutput(photoOutput)
      photoOutput.isHighResolutionCaptureEnabled = true
      //            photoOutput.isLivePhotoCaptureEnabled = photoOutput.isLivePhotoCaptureSupported
    }
    
    // MovieFileOutput 추가 (Recording 용)
    if captureSession.canAddOutput(movieFileOutput) {
      captureSession.addOutput(movieFileOutput)
    }

    // We want the buffers to be in portrait orientation otherwise they are
    // rotated by 90 degrees. Need to set this _after_ addOutput()!
    // let curDeviceOrientation = UIDevice.current.orientation
    let connection = videoOutput.connection(with: AVMediaType.video)
    connection?.videoOrientation = videoOrientaion
    if position == .front {
      connection?.isVideoMirrored = true
    }

    // Configure captureDevice
    do {
      try captureDevice!.lockForConfiguration()
    } catch {
      print("device configuration not working")
    }
    // captureDevice.setFocusModeLocked(lensPosition: 1.0, completionHandler: { (time) -> Void in })
    if captureDevice!.isFocusModeSupported(AVCaptureDevice.FocusMode.continuousAutoFocus),
      captureDevice!.isFocusPointOfInterestSupported
    {
      captureDevice!.focusMode = AVCaptureDevice.FocusMode.continuousAutoFocus
      captureDevice!.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
    }
    captureDevice!.exposureMode = AVCaptureDevice.ExposureMode.continuousAutoExposure
    captureDevice!.unlockForConfiguration()

    captureSession.commitConfiguration()
    return true
  }

  func start() {
    if !captureSession.isRunning {
      DispatchQueue.global().async {
        self.captureSession.startRunning()
      }
    }
  }

  func stop() {
    if captureSession.isRunning {
      DispatchQueue.global().async {
        self.captureSession.stopRunning()
      }
    }
  }

  func setZoomRatio(ratio: CGFloat) {
    do {
      try captureDevice!.lockForConfiguration()
      defer {
        captureDevice!.unlockForConfiguration()
      }
      captureDevice!.videoZoomFactor = ratio
      currentZoomFactor = ratio
    } catch {}
  }

  private func predictOnFrame(sampleBuffer: CMSampleBuffer) {
    guard let predictor = predictor else {
      print("predictor is nil")
      return
    }
    if currentBuffer == nil, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
      currentBuffer = pixelBuffer
      if !frameSizeCaptured {
        let frameWidth = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let frameHeight = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        longSide = max(frameWidth, frameHeight)
        shortSide = min(frameWidth, frameHeight)
        frameSizeCaptured = true
      }

      /// - Tag: MappingOrientation
      // The frame is always oriented based on the camera sensor,
      // so in most cases Vision needs to rotate it for the model to work as expected.
      var imageOrientation: CGImagePropertyOrientation = .up
      //            switch UIDevice.current.orientation {
      //            case .portrait:
      //                imageOrientation = .up
      //            case .portraitUpsideDown:
      //                imageOrientation = .down
      //            case .landscapeLeft:
      //                imageOrientation = .up
      //            case .landscapeRight:
      //                imageOrientation = .up
      //            case .unknown:
      //                imageOrientation = .up
      //
      //            default:
      //                imageOrientation = .up
      //            }

      predictor.predict(sampleBuffer: sampleBuffer, onResultsListener: self, onInferenceTime: self)
      currentBuffer = nil
    }
  }

  func updateVideoOrientation(orientation: AVCaptureVideoOrientation) {
    guard let connection = videoOutput.connection(with: .video) else { return }

    connection.videoOrientation = orientation
    let currentInput = self.captureSession.inputs.first as? AVCaptureDeviceInput
    if currentInput?.device.position == .front {
      connection.isVideoMirrored = true
    } else {
      connection.isVideoMirrored = false
    }
    let o = connection.videoOrientation
    self.previewLayer?.connection?.videoOrientation = connection.videoOrientation
  }
}

extension VideoCapture: AVCaptureVideoDataOutputSampleBufferDelegate {
  func captureOutput(
    _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    guard inferenceOK else { return }
    predictOnFrame(sampleBuffer: sampleBuffer)
  }
  
  // 출력이 삭제되었을 때 호출되는 메서드
  func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    // 프레임 드롭 로깅 (성능 문제 진단용)
    print("DEBUG: 프레임 드롭 발생")
  }
}

extension VideoCapture: AVCapturePhotoCaptureDelegate {
  @available(iOS 11.0, *)
  func photoOutput(
    _ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?
  ) {
    guard let data = photo.fileDataRepresentation(),
      let image = UIImage(data: data)
    else {
      return
    }

    self.lastCapturedPhoto = image
  }
}

extension VideoCapture: ResultsListener, InferenceTimeListener {
  func on(inferenceTime: Double, fpsRate: Double) {
    DispatchQueue.main.async {
      self.delegate?.onInferenceTime(speed: inferenceTime, fps: fpsRate)
    }
  }

  func on(result: YOLOResult) {
    DispatchQueue.main.async {
      self.delegate?.onPredict(result: result)
    }
  }
}

// MARK: - AVCaptureFileOutputRecordingDelegate
extension VideoCapture: AVCaptureFileOutputRecordingDelegate {
  func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
    // 녹화가 시작되면 확실하게 isRecording 플래그를 true로 설정
    isRecording = true
    
    print("DEBUG: 🎬 didStartRecordingTo 호출됨 - 녹화 실제 시작")
    print("DEBUG: 🎬 Recording started to \(fileURL.path)")
    print("DEBUG: 🎬 movieFileOutput.isRecording 값: \(self.movieFileOutput.isRecording)")
    print("DEBUG: 🎬 isRecording 플래그: \(self.isRecording)")
    print("DEBUG: 🎬 connections 개수: \(connections.count)")
    
    // 녹화가 실제로 시작되었는지 확인하기 위해 연결 정보 출력
    for (index, connection) in connections.enumerated() {
      // inputPorts를 통해 미디어 유형 확인
      let mediaTypes = connection.inputPorts.compactMap { $0.mediaType.rawValue }
      let mediaTypeStr = mediaTypes.isEmpty ? "unknown" : mediaTypes.joined(separator: ", ")
      print("DEBUG: 🎬 Connection \(index): \(mediaTypeStr) enabled: \(connection.isEnabled)")
    }
    
    // startRecording의 completion 호출은 여기서 처리하지 않음
    // Flutter로의 응답은 movieFileOutput.startRecording() 호출 직후에 처리됨
  }
  
  func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
    print("DEBUG: 🎬 didFinishRecordingTo 델리게이트 호출됨")
    print("DEBUG: 🎬 파일 URL: \(outputFileURL.path)")
    print("DEBUG: 🎬 오류: \(error?.localizedDescription ?? "없음")")
    
    // 녹화가 끝나면 항상 isRecording 플래그를 false로 설정
    let wasRecording = isRecording
    isRecording = false
    
    print("DEBUG: 🎬 이전 isRecording 상태: \(wasRecording)")
    print("DEBUG: 🎬 recordingCompletionHandler 존재 여부: \(recordingCompletionHandler != nil)")
    
    if let error = error {
      print("DEBUG: 🎬 Recording error: \(error.localizedDescription)")
      
      // 오류 세부 정보 출력 (AVErrorKeys 활용)
      if let avError = error as? AVError {
        print("DEBUG: 🎬 AVError 코드: \(avError.code.rawValue)")
      }
      
      // 녹화 중 오류가 발생해도 콜백 호출
      recordingCompletionHandler?(nil, error)
    } else {
      print("DEBUG: 🎬 Recording finished successfully at \(outputFileURL.path)")
      
      // 파일이 실제로 존재하는지 확인
      let fileExists = FileManager.default.fileExists(atPath: outputFileURL.path)
      print("DEBUG: 🎬 녹화된 파일 존재 여부: \(fileExists ? "있음" : "없음")")
      
      if fileExists {
        // 파일 크기도 확인
        do {
          let attributes = try FileManager.default.attributesOfItem(atPath: outputFileURL.path)
          if let fileSize = attributes[.size] as? Int64 {
            print("DEBUG: 🎬 파일 크기: \(fileSize) bytes")
          }
        } catch {
          print("DEBUG: 🎬 파일 속성 확인 실패: \(error)")
        }
      }
      
      recordingCompletionHandler?(outputFileURL, nil)
    }
    
    print("DEBUG: 🎬 recordingCompletionHandler 호출 완료, 핸들러 정리")
    recordingCompletionHandler = nil
  }
}

// MARK: - Recording Functions
extension VideoCapture {
  func startRecording(completion: @escaping (URL?, Error?) -> Void) {
    print("DEBUG: 🎬 startRecording 호출됨")
    print(getCurrentRecordingStatus())
    
    // 이미 녹화 중인지 실제 movieFileOutput 상태로 확인
    if movieFileOutput.isRecording {
      print("DEBUG: 🎬 이미 녹화 중이므로 시작 불가")
      completion(nil, NSError(domain: "VideoCapture", code: 100, userInfo: [NSLocalizedDescriptionKey: "이미 녹화 중입니다"]))
      return
    }
    
    // isRecording 플래그가 true인데 실제로 녹화가 진행 중이 아닌 경우
    if isRecording && !movieFileOutput.isRecording {
      print("DEBUG: 상태 불일치 감지 - isRecording은 true이나 실제로는 녹화 중이 아님")
      isRecording = false // 상태 재설정
    }
    
    // 고유한 파일 이름 생성: 타임스탬프 + UUID
    let timestamp = Date().timeIntervalSince1970
    let uuid = UUID().uuidString.prefix(8)
    let fileName = "recording_\(timestamp)_\(uuid).mp4"
    
    // Documents 디렉토리에 저장 (갤러리에서 접근 가능)
    let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let fileURL = documentsDir.appendingPathComponent(fileName)
    
    // 파일이 이미 존재하면 삭제
    try? FileManager.default.removeItem(at: fileURL)

    cameraQueue.async { [weak self] in
      guard let self = self else { 
        DispatchQueue.main.async { completion(nil, NSError(domain: "VideoCapture", code: 105, userInfo: [NSLocalizedDescriptionKey: "VideoCapture 객체가 해제됨"])) }
        return 
      }
      
      // captureSession이 실행 중인지 확인
      guard self.captureSession.isRunning else {
        DispatchQueue.main.async { completion(nil, NSError(domain: "VideoCapture", code: 107, userInfo: [NSLocalizedDescriptionKey: "카메라 세션이 실행 중이 아님"])) }
        return
      }
      
      // 출력이 모두 설정되어 있는지 확인
      if !self.captureSession.outputs.contains(self.movieFileOutput) {
        // 출력이 없으면 다시 추가 시도
        self.captureSession.beginConfiguration()
        if self.captureSession.canAddOutput(self.movieFileOutput) {
          self.captureSession.addOutput(self.movieFileOutput)
          print("DEBUG: movieFileOutput 다시 추가됨")
        }
        self.captureSession.commitConfiguration()
        
        // 여전히 없으면 오류 반환
        if !self.captureSession.outputs.contains(self.movieFileOutput) {
          DispatchQueue.main.async { completion(nil, NSError(domain: "VideoCapture", code: 110, userInfo: [NSLocalizedDescriptionKey: "movieFileOutput을 세션에 추가할 수 없음"])) }
          return
        }
      }
      
      if self.movieFileOutput.isRecording == false {
        // 디버그: movieFileOutput 상태 확인
        print("DEBUG: movieFileOutput 상태 확인 - 연결된 출력 개수: \(self.captureSession.outputs.count)")
        print("DEBUG: movieFileOutput이 captureSession에 포함되어 있는지: \(self.captureSession.outputs.contains(self.movieFileOutput))")
        
        let connections = self.movieFileOutput.connections
        if !connections.isEmpty {
          print("DEBUG: movieFileOutput에 \(connections.count)개의 연결이 있습니다")
          for (index, connection) in connections.enumerated() {
            // inputPorts를 통해 미디어 유형 확인
            let mediaTypes = connection.inputPorts.compactMap { $0.mediaType.rawValue }
            let mediaTypeStr = mediaTypes.isEmpty ? "unknown" : mediaTypes.joined(separator: ", ")
            print("DEBUG: Connection \(index): \(mediaTypeStr) enabled: \(connection.isEnabled)")
          }
        } else {
          print("DEBUG: ⚠️ movieFileOutput에 연결이 없습니다! 이는 녹화가 작동하지 않는 원인일 수 있습니다.")
          
          DispatchQueue.main.async {
            completion(nil, NSError(domain: "VideoCapture", code: 111, userInfo: [NSLocalizedDescriptionKey: "movieFileOutput에 연결이 없음"]))
          }
          return
        }
        
        // 오디오 입력이 없는 경우 추가
        if self.audioEnabled && !self.hasAudioInput() {
          self.addAudioInput()
        }
        
        // 현재 줌 팩터 저장 (참조용)
        let currentZoom = self.currentZoomFactor
        print("DEBUG: Current zoom factor before recording: \(currentZoom)")
        
        // 비디오 설정 구성
        if let connection = self.movieFileOutput.connection(with: .video) {
          // 비디오 방향 설정
          connection.videoOrientation = .portrait
          connection.isVideoMirrored = self.currentPosition == AVCaptureDevice.Position.front
          
          // 슬로우 모션 모드인 경우 추가 설정
          if self.isSlowMotionEnabled {
            print("DEBUG: 슬로우 모션 모드로 녹화 시작 - \(self.currentFrameRate) FPS")
            
            // 비디오 안정화 설정 (가능한 경우)
            if connection.isVideoStabilizationSupported {
              connection.preferredVideoStabilizationMode = .auto
            }
          } else {
            // 비디오 안정화 설정 (가능한 경우)
            if connection.isVideoStabilizationSupported {
              connection.preferredVideoStabilizationMode = .auto
            }
          }
        }
        
        self.currentRecordingURL = fileURL
        
        print("DEBUG: recordingCompletionHandler 설정 완료")
        
        // 녹화 시작 시도
        // iOS 14+ 에서만 가능한 추가 구성
        if #available(iOS 14.0, *) {
          if let audioConnection = self.movieFileOutput.connection(with: .audio) {
            // 오디오 설정이 가능한지 확인
            if audioConnection.isActive && !audioConnection.isEnabled {
              audioConnection.isEnabled = true
            }
          }
        }
        
        print("DEBUG: 🎬 녹화 시작 시도 to \(fileURL.path)")
        self.movieFileOutput.startRecording(to: fileURL, recordingDelegate: self)
        print("DEBUG: 🎬 movieFileOutput.startRecording() 호출 완료")
        
        // 즉시 Flutter로 응답 반환 (실제 녹화 시작은 델리게이트에서 확인)
        DispatchQueue.main.async {
          completion(fileURL, nil)
        }
        
        // 녹화가 실제로 시작될 때까지 짧은 시간 대기
        // didStartRecordingTo 델리게이트가 호출되면 isRecording이 true로 설정됨
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
          print("DEBUG: 🎬 녹화 시작 후 상태 확인")
          print("DEBUG: 🎬 isRecording: \(self.isRecording)")
          print("DEBUG: 🎬 movieFileOutput.isRecording: \(self.movieFileOutput.isRecording)")
        }
      } else {
        DispatchQueue.main.async {
          completion(nil, NSError(domain: "VideoCapture", code: 101, userInfo: [NSLocalizedDescriptionKey: "녹화 시작 실패 - 이미 다른 녹화가 진행 중"]))
        }
      }
    }
  }
  
  func stopRecording(completion: @escaping (URL?, Error?) -> Void) {
    print("DEBUG: 🎬 stopRecording 호출됨")
    print(getCurrentRecordingStatus())
    
    // 실제 녹화 상태 확인 (이중 검증)
    if !movieFileOutput.isRecording {
      print("DEBUG: 🎬 movieFileOutput.isRecording이 false - 녹화 중이 아님")
      // 상태 불일치 감지 - isRecording 플래그 재설정
      if isRecording {
        print("DEBUG: 🎬 상태 불일치 감지 - isRecording은 true이나 실제로는 녹화 중이 아님")
        isRecording = false
      }
      
      // 사용자에게 오류 반환
      completion(nil, NSError(domain: "VideoCapture", code: 102, userInfo: [NSLocalizedDescriptionKey: "녹화 중이 아닙니다"]))
      return
    }
    
    print("DEBUG: movieFileOutput.isRecording이 true - 녹화 중지 진행")
    
    cameraQueue.async { [weak self] in
      guard let self = self else {
        print("DEBUG: VideoCapture 객체가 해제됨")
        DispatchQueue.main.async { completion(nil, NSError(domain: "VideoCapture", code: 108, userInfo: [NSLocalizedDescriptionKey: "VideoCapture 객체가 해제됨"])) }
        return
      }
      
      // 녹화 중인지 다시 확인 (비동기 작업 중 상태가 변경되었을 수 있음)
      if self.movieFileOutput.isRecording {
        print("DEBUG: 녹화 중지 시도 중...")
        
        // recordingCompletionHandler를 stopRecording용으로 설정
        self.recordingCompletionHandler = { [weak self] (url, error) in
          guard let self = self else {
            DispatchQueue.main.async { completion(url, error) }
            return
          }
          
          print("DEBUG: 🎬 recordingCompletionHandler 호출됨 (중지)")
          self.isRecording = false
          
          DispatchQueue.main.async {
            if let error = error {
              print("DEBUG: 🎬 녹화 중지 오류: \(error)")
              completion(nil, error)
            } else if let url = url {
              print("DEBUG: 🎬 녹화 성공적으로 완료됨: \(url.path)")
              completion(url, nil)
            } else {
              print("DEBUG: 🎬 녹화가 중지되었으나 URL이 없음")
              completion(nil, NSError(domain: "VideoCapture", code: 109, userInfo: [NSLocalizedDescriptionKey: "녹화 URL을 찾을 수 없음"]))
            }
          }
        }
        
        print("DEBUG: movieFileOutput.stopRecording() 호출")
        // 녹화 중지
        self.movieFileOutput.stopRecording()
        print("DEBUG: movieFileOutput.stopRecording() 호출 완료")
      } else {
        // 이 시점에서는 isRecording과 실제 녹화 상태가 불일치하는 상황
        print("DEBUG: ⚠️ 상태 불일치: stopRecording 호출됨 - 실제 녹화 중이 아님")
        
        // 상태 정리 및 초기화
        self.isRecording = false
        
        DispatchQueue.main.async {
          completion(nil, NSError(domain: "VideoCapture", code: 103, userInfo: [NSLocalizedDescriptionKey: "녹화가 이미 중지됨"]))
        }
      }
    }
  }

  // 오디오 입력이 있는지 확인하는 헬퍼 메서드
  func hasAudioInput() -> Bool {
    return captureSession.inputs.contains { input in
      guard let deviceInput = input as? AVCaptureDeviceInput else { return false }
      return deviceInput.device.hasMediaType(.audio)
    }
  }
  
  // 오디오 입력을 추가하는 헬퍼 메서드
  func addAudioInput() {
    captureSession.beginConfiguration()
    
    if let audioDevice = AVCaptureDevice.default(for: .audio) {
      do {
        let audioInput = try AVCaptureDeviceInput(device: audioDevice)
        if captureSession.canAddInput(audioInput) {
          captureSession.addInput(audioInput)
          print("DEBUG: Added audio input for recording")
        }
      } catch {
        print("DEBUG: Could not create audio input: \(error)")
      }
    }
    
    captureSession.commitConfiguration()
  }
  
  // 현재 녹화 상태를 종합적으로 확인하는 메서드
  func getCurrentRecordingStatus() -> String {
    let movieFileOutputRecording = movieFileOutput.isRecording
    let handlerExists = recordingCompletionHandler != nil
    let currentURL = currentRecordingURL?.path ?? "nil"
    
    return """
    DEBUG: 📊 녹화 상태 종합:
    - isRecording 플래그: \(isRecording)
    - movieFileOutput.isRecording: \(movieFileOutputRecording)
    - recordingCompletionHandler 존재: \(handlerExists)
    - currentRecordingURL: \(currentURL)
    """
  }
}
