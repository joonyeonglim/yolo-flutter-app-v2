// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

package com.ultralytics.yolo

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.*
import android.util.Log
import android.util.Size
import androidx.camera.core.*
import androidx.camera.core.Camera
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.camera.video.VideoCapture
import androidx.camera.video.Recorder
import androidx.camera.video.Recording
import androidx.camera.video.VideoRecordEvent
import androidx.camera.video.MediaStoreOutputOptions
import androidx.camera.video.Quality
import androidx.camera.video.QualitySelector
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.common.util.concurrent.ListenableFuture
import java.util.concurrent.Executors
import java.io.File
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.TimeUnit

/**
 * Protocol for video recording functionality
 */
interface VideoRecordable {
    val isRecording: Boolean
    fun startRecording(completion: (String?, Exception?) -> Unit)
    fun stopRecording(completion: (String?, Exception?) -> Unit)
}

/**
 * Protocol for receiving video capture frame processing results
 */
interface VideoCaptureDelegate {
    fun onPredict(result: YOLOResult)
    fun onInferenceTime(speed: Double, fps: Double)
}

/**
 * VideoCapture class that manages camera operations and video recording
 * Similar to iOS VideoCapture.swift
 */
class VideoCapture(
    private val context: Context,
    private val previewView: PreviewView
) : VideoRecordable {

    companion object {
        private const val REQUEST_CODE_PERMISSIONS = 10
        private val REQUIRED_PERMISSIONS = arrayOf(
            Manifest.permission.CAMERA,
            Manifest.permission.RECORD_AUDIO
        )
        private const val TAG = "VideoCapture"
        
        // 로그 레벨 제어
        private const val LOG_LEVEL_INFO = 2
        private const val CURRENT_LOG_LEVEL = LOG_LEVEL_INFO
        
        private fun logI(tag: String, message: String) {
            if (CURRENT_LOG_LEVEL <= LOG_LEVEL_INFO) {
                Log.i(tag, message)
            }
        }
        
        private fun logW(tag: String, message: String) {
            Log.w(tag, message)
        }
        
        private fun logE(tag: String, message: String, throwable: Throwable? = null) {
            if (throwable != null) {
                Log.e(tag, message, throwable)
            } else {
                Log.e(tag, message)
            }
        }
    }

    // Predictor and delegate
    var predictor: Predictor? = null
    var delegate: VideoCaptureDelegate? = null
    
    // Lifecycle owner for camera
    private var lifecycleOwner: LifecycleOwner? = null
    
    // Camera config
    private var lensFacing = CameraSelector.LENS_FACING_BACK
    private lateinit var cameraProviderFuture: ListenableFuture<ProcessCameraProvider>
    private var camera: Camera? = null
    
    // Recording 관련 프로퍼티들
    private var videoCapture: VideoCapture<Recorder>? = null
    private var recorder: Recorder? = null
    private var recording: Recording? = null
    override var isRecording = false
        private set
    private var audioEnabled = true
    private var recordingCompletionCallback: ((String?, Exception?) -> Unit)? = null
    
    // Zoom related
    private var currentZoomRatio = 1.0f
    private var minZoomRatio = 1.0f
    private var maxZoomRatio = 10.0f
    var onZoomChanged: ((Float) -> Unit)? = null

    // Detection thresholds
    private var confidenceThreshold = 0.25
    private var iouThreshold = 0.45
    private var numItemsThreshold = 30
    
    // Streaming functionality
    private var streamConfig: YOLOStreamConfig? = null
    private var streamCallback: ((Map<String, Any>) -> Unit)? = null
    
    // Frame counter for streaming
    private var frameNumberCounter: Long = 0
    
    // Throttling variables for performance control
    private var lastInferenceTime: Long = 0
    private var targetFrameInterval: Long? = null // in nanoseconds
    private var throttleInterval: Long? = null // in nanoseconds
    
    // Inference frequency control variables
    private var inferenceFrameInterval: Long? = null // Target inference interval in nanoseconds
    private var frameSkipCount: Int = 0 // Current frame skip counter
    private var targetSkipFrames: Int = 0 // Number of frames to skip between inferences

    // 녹화 중지 타임아웃 핸들러
    private val recordingStopHandler = android.os.Handler(android.os.Looper.getMainLooper())
    private var recordingStopRunnable: Runnable? = null

    // Callback to notify inference results externally
    private var inferenceCallback: ((YOLOResult) -> Unit)? = null
    
    // Callback to notify model load completion
    private var modelLoadCallback: ((Boolean) -> Unit)? = null

    init {
        // Initialize camera provider future
        setUpCamera()
    }

    fun setOnInferenceCallback(callback: (YOLOResult) -> Unit) {
        this.inferenceCallback = callback
    }
    
    fun setStreamConfig(config: YOLOStreamConfig?) {
        this.streamConfig = config
        setupThrottlingFromConfig()
    }
    
    fun setStreamCallback(callback: ((Map<String, Any>) -> Unit)?) {
        this.streamCallback = callback
    }

    fun setOnModelLoadCallback(callback: (Boolean) -> Unit) {
        this.modelLoadCallback = callback
    }

    // region threshold setters
    fun setConfidenceThreshold(conf: Double) {
        confidenceThreshold = conf
        (predictor as? ObjectDetector)?.setConfidenceThreshold(conf)
    }

    fun setIouThreshold(iou: Double) {
        iouThreshold = iou
        (predictor as? ObjectDetector)?.setIouThreshold(iou)
    }

    fun setNumItemsThreshold(n: Int) {
        numItemsThreshold = n
        (predictor as? ObjectDetector)?.setNumItemsThreshold(n)
    }
    // endregion

    // region Camera Setup and Control
    fun setUp(
        sessionPreset: String = "hd1280x720",
        position: Int = CameraSelector.LENS_FACING_BACK,
        completion: (Boolean) -> Unit
    ) {
        lensFacing = position
        val executor = Executors.newSingleThreadExecutor()
        executor.execute {
            val success = setUpCamera()
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                completion(success)
            }
        }
    }

    private fun setUpCamera(): Boolean {
        return try {
            cameraProviderFuture = ProcessCameraProvider.getInstance(context)
            true
        } catch (e: Exception) {
            logE(TAG, "Error setting up camera", e)
            false
        }
    }

    fun start() {
        logI(TAG, "Starting camera - checking permissions")
        if (allPermissionsGranted()) {
            logI(TAG, "Permissions granted - starting camera")
            startCamera()
        } else {
            logI(TAG, "Permissions not granted - requesting permissions")
            val activity = context as? Activity ?: run {
                logE(TAG, "Context is not an Activity - cannot request permissions")
                return
            }
            ActivityCompat.requestPermissions(
                activity,
                REQUIRED_PERMISSIONS,
                REQUEST_CODE_PERMISSIONS
            )
        }
    }

    fun stop() {
        logI(TAG, "Stopping camera")
        try {
            val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
            cameraProviderFuture.addListener({
                val cameraProvider = cameraProviderFuture.get()
                cameraProvider.unbindAll()
                logI(TAG, "Camera stopped successfully")
            }, ContextCompat.getMainExecutor(context))
        } catch (e: Exception) {
            logE(TAG, "Error stopping camera", e)
        }
    }

    fun pause() {
        logI(TAG, "Pausing camera (stopping)")
        stop()
    }

    fun resume() {
        logI(TAG, "Resuming camera")
        if (allPermissionsGranted()) {
            startCamera()
        } else {
            logW(TAG, "Cannot resume camera - permissions not granted")
        }
    }

    private fun allPermissionsGranted() = REQUIRED_PERMISSIONS.all {
        ContextCompat.checkSelfPermission(context, it) == PackageManager.PERMISSION_GRANTED
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        if (requestCode == REQUEST_CODE_PERMISSIONS) {
            if (allPermissionsGranted()) {
                startCamera()
            } else {
                android.widget.Toast.makeText(context, "Camera permission not granted.", android.widget.Toast.LENGTH_SHORT).show()
            }
        }
    }

    private fun startCamera() {
        logI(TAG, "Starting camera setup")
        try {
            cameraProviderFuture.addListener({
                try {
                    logI(TAG, "Getting camera provider")
                    val cameraProvider = cameraProviderFuture.get()

                    val preview = Preview.Builder()
                        .setTargetResolution(Size(1920, 1080))
                        .build()

                    val imageAnalysis = ImageAnalysis.Builder()
                        .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                        .setTargetResolution(Size(320, 320))
                        .build()

                    val executor = Executors.newSingleThreadExecutor()
                    imageAnalysis.setAnalyzer(executor) { imageProxy ->
                        onFrame(imageProxy)
                    }
                    
                    // VideoCapture 설정 (Recording 용) - 화질 개선
                    recorder = Recorder.Builder()
                        .setQualitySelector(QualitySelector.from(Quality.FHD))
                        .build()
                    videoCapture = VideoCapture.withOutput(recorder!!)

                    val cameraSelector = CameraSelector.Builder()
                        .requireLensFacing(lensFacing)
                        .build()

                    logI(TAG, "Unbinding all previous use cases")
                    cameraProvider.unbindAll()

                    try {
                        val owner = lifecycleOwner
                        if (owner == null) {
                            logE(TAG, "No LifecycleOwner available. Call setLifecycleOwner() first.")
                            return@addListener
                        }
                        logI(TAG, "Binding camera use cases to lifecycle")
                        camera = cameraProvider.bindToLifecycle(
                            owner,
                            cameraSelector,
                            preview,
                            imageAnalysis,
                            videoCapture
                        )
                        
                        // Reset zoom to 1.0x when camera starts
                        currentZoomRatio = 1.0f
                        onZoomChanged?.invoke(currentZoomRatio)

                        logI(TAG, "Setting surface provider for preview")
                        preview.setSurfaceProvider(previewView.surfaceProvider)
                        
                        // Initialize zoom
                        camera?.let { cam: Camera ->
                            val cameraInfo = cam.cameraInfo
                            minZoomRatio = cameraInfo.zoomState.value?.minZoomRatio ?: 1.0f
                            maxZoomRatio = cameraInfo.zoomState.value?.maxZoomRatio ?: 1.0f
                            currentZoomRatio = cameraInfo.zoomState.value?.zoomRatio ?: 1.0f
                        }
                        
                        logI(TAG, "Camera setup completed successfully")
                    } catch (e: Exception) {
                        logE(TAG, "Use case binding failed", e)
                    }
                } catch (e: Exception) {
                    logE(TAG, "Error getting camera provider", e)
                }
            }, ContextCompat.getMainExecutor(context))
        } catch (e: Exception) {
            logE(TAG, "Error starting camera", e)
        }
    }

    fun switchCamera() {
        lensFacing = if (lensFacing == CameraSelector.LENS_FACING_BACK) {
            CameraSelector.LENS_FACING_FRONT
        } else {
            CameraSelector.LENS_FACING_BACK
        }
        startCamera()
    }

    fun setZoomLevel(zoomLevel: Float) {
        camera?.let { cam: Camera ->
            val clampedZoomRatio = zoomLevel.coerceIn(minZoomRatio, cam.cameraInfo.zoomState.value?.maxZoomRatio ?: maxZoomRatio)
            cam.cameraControl.setZoomRatio(clampedZoomRatio)
            currentZoomRatio = clampedZoomRatio
            onZoomChanged?.invoke(currentZoomRatio)
        }
    }

    fun setLifecycleOwner(owner: LifecycleOwner) {
        this.lifecycleOwner = owner
    }
    // endregion

    // region Frame Processing
    private fun onFrame(imageProxy: ImageProxy) {
        val bitmap = ImageUtils.toBitmap(imageProxy) ?: run {
            logE(TAG, "Failed to convert ImageProxy to Bitmap")
            imageProxy.close()
            return
        }

        predictor?.let { p ->
            if (!shouldRunInference()) {
                imageProxy.close()
                return
            }
            
            try {
                val result = p.predict(bitmap, imageProxy.height, imageProxy.width, rotateForCamera = true)
                
                val resultWithOriginalImage = if (streamConfig?.includeOriginalImage == true) {
                    result.copy(originalImage = bitmap)
                } else {
                    result
                }

                // Callback to delegate
                delegate?.onPredict(resultWithOriginalImage)
                
                // External callback
                inferenceCallback?.invoke(resultWithOriginalImage)
                
                // Streaming callback
                streamCallback?.let { callback ->
                    if (shouldProcessFrame()) {
                        updateLastInferenceTime()
                        
                        val streamData = convertResultToStreamData(resultWithOriginalImage)
                        val enhancedStreamData = HashMap<String, Any>(streamData)
                        enhancedStreamData["timestamp"] = System.currentTimeMillis()
                        enhancedStreamData["frameNumber"] = frameNumberCounter++
                        
                        callback.invoke(enhancedStreamData)
                    }
                }

            } catch (e: Exception) {
                logE(TAG, "Error during prediction", e)
            }
        }
        imageProxy.close()
    }
    // endregion

    // region Model Management
    fun setModel(modelPath: String, task: YOLOTask, callback: ((Boolean) -> Unit)? = null) {
        Executors.newSingleThreadExecutor().execute {
            try {
                val newPredictor = when (task) {
                    YOLOTask.DETECT -> ObjectDetector(context, modelPath, loadLabels(modelPath), useGpu = true).apply {
                        setConfidenceThreshold(confidenceThreshold)
                        setIouThreshold(iouThreshold)
                        setNumItemsThreshold(numItemsThreshold)
                    }
                    YOLOTask.SEGMENT -> Segmenter(context, modelPath, loadLabels(modelPath), useGpu = true)
                    YOLOTask.CLASSIFY -> Classifier(context, modelPath, loadLabels(modelPath), useGpu = true)
                    YOLOTask.POSE -> PoseEstimator(context, modelPath, loadLabels(modelPath), useGpu = true)
                    YOLOTask.OBB -> ObbDetector(context, modelPath, loadLabels(modelPath), useGpu = true)
                }

                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    this.predictor = newPredictor
                    modelLoadCallback?.invoke(true)
                    callback?.invoke(true)
                }
            } catch (e: Exception) {
                logE(TAG, "Failed to load model: $modelPath", e)
                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    modelLoadCallback?.invoke(false)
                    callback?.invoke(false)
                }
            }
        }
    }

    private fun loadLabels(modelPath: String): List<String> {
        val loadedLabels = YOLOFileUtils.loadLabelsFromAppendedZip(context, modelPath)
        if (loadedLabels != null) {
            return loadedLabels
        }
        
        return listOf(
            "person", "bicycle", "car", "motorcycle", "airplane", "bus", "train", "truck", "boat",
            "traffic light", "fire hydrant", "stop sign", "parking meter", "bench", "bird", "cat", "dog",
            "horse", "sheep", "cow", "elephant", "bear", "zebra", "giraffe", "backpack", "umbrella",
            "handbag", "tie", "suitcase", "frisbee", "skis", "snowboard", "sports ball", "kite",
            "baseball bat", "baseball glove", "skateboard", "surfboard", "tennis racket", "bottle",
            "wine glass", "cup", "fork", "knife", "spoon", "bowl", "banana", "apple", "sandwich",
            "orange", "broccoli", "carrot", "hot dog", "pizza", "donut", "cake", "chair", "couch",
            "potted plant", "bed", "dining table", "toilet", "tv", "laptop", "mouse", "remote",
            "keyboard", "cell phone", "microwave", "oven", "toaster", "sink", "refrigerator", "book",
            "clock", "vase", "scissors", "teddy bear", "hair drier", "toothbrush"
        )
    }
    // endregion

    // region Recording Functions
    override fun startRecording(completion: (String?, Exception?) -> Unit) {
        val videoCapture = this.videoCapture
        if (videoCapture == null) {
            completion(null, Exception("VideoCapture가 초기화되지 않았습니다"))
            return
        }
        
        if (isRecording && recording != null) {
            completion(null, Exception("이미 녹화 중입니다"))
            return
        } else if (isRecording && recording == null) {
            logW(TAG, "녹화 상태 불일치 감지 - isRecording은 true이지만 recording 객체가 null")
            isRecording = false
        }
        
        val availableSpace = getAvailableStorageSpace()
        if (availableSpace < 100 * 1024 * 1024) {
            completion(null, Exception("저장 공간이 부족합니다 (${availableSpace / (1024 * 1024)}MB 사용 가능)"))
            return
        }
        
        val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
        val fileName = "recording_${timestamp}.mp4"
        
        val contentValues = android.content.ContentValues().apply {
            put(android.provider.MediaStore.MediaColumns.DISPLAY_NAME, fileName)
            put(android.provider.MediaStore.MediaColumns.MIME_TYPE, "video/mp4")
            put(android.provider.MediaStore.Video.Media.RELATIVE_PATH, "Movies/YOLORecordings")
        }
        
        val mediaStoreOutputOptions = MediaStoreOutputOptions
            .Builder(context.contentResolver, android.provider.MediaStore.Video.Media.EXTERNAL_CONTENT_URI)
            .setContentValues(contentValues)
            .build()

        val outputOptions = if (audioEnabled) {
            val pendingRecording = recorder!!.prepareRecording(context, mediaStoreOutputOptions)
                
            if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) 
                == PackageManager.PERMISSION_GRANTED) {
                pendingRecording.withAudioEnabled()
            } else {
                logW(TAG, "오디오 권한이 없어 비디오만 녹화합니다")
                pendingRecording
            }
        } else {
            recorder!!.prepareRecording(context, mediaStoreOutputOptions)
        }
        
        isRecording = true
        recordingCompletionCallback = completion
        
        recording = outputOptions.start(ContextCompat.getMainExecutor(context)) { recordEvent: VideoRecordEvent ->
            when (recordEvent) {
                is VideoRecordEvent.Start -> {
                    logI(TAG, "녹화 시작됨")
                }
                is VideoRecordEvent.Finalize -> {
                    logI(TAG, "VideoRecordEvent.Finalize 콜백 호출됨 - hasError: ${recordEvent.hasError()}")
                    
                    recordingStopRunnable?.let { recordingStopHandler.removeCallbacks(it) }
                    recordingStopRunnable = null

                    synchronized(this) {
                        isRecording = false
                        val callback = recordingCompletionCallback
                        recordingCompletionCallback = null
                        this.recording = null
                        
                        if (!recordEvent.hasError()) {
                            val uri = recordEvent.outputResults.outputUri
                            logI(TAG, "녹화 완료: $uri")
                            callback?.invoke(uri.toString(), null)
                        } else {
                            val errorCode = recordEvent.error
                            val errorMsg = when (errorCode) {
                                VideoRecordEvent.Finalize.ERROR_INSUFFICIENT_STORAGE -> "저장 공간 부족"
                                VideoRecordEvent.Finalize.ERROR_INVALID_OUTPUT_OPTIONS -> "잘못된 출력 설정"
                                VideoRecordEvent.Finalize.ERROR_ENCODING_FAILED -> "비디오 인코딩 실패"
                                VideoRecordEvent.Finalize.ERROR_RECORDER_ERROR -> "녹화기 오류"
                                VideoRecordEvent.Finalize.ERROR_NO_VALID_DATA -> "유효한 데이터 없음"
                                VideoRecordEvent.Finalize.ERROR_SOURCE_INACTIVE -> "카메라 소스 비활성"
                                else -> "알 수 없는 오류 (코드: $errorCode)"
                            }
                            val error = Exception("녹화 실패: $errorMsg")
                            logE(TAG, "녹화 실패 - 에러코드: $errorCode, 메시지: $errorMsg", error)
                            callback?.invoke(null, error)
                        }
                    }
                }
                is VideoRecordEvent.Status -> {
                    // Status 이벤트는 너무 자주 발생하므로 로그 생략
                }
                is VideoRecordEvent.Pause -> {
                    logI(TAG, "VideoRecordEvent.Pause - 녹화 일시정지됨")
                }
                is VideoRecordEvent.Resume -> {
                    logI(TAG, "VideoRecordEvent.Resume - 녹화 재개됨")
                }
                else -> {
                    logI(TAG, "기타 VideoRecordEvent: ${recordEvent.javaClass.simpleName}")
                }
            }
        }
    }
    
    override fun stopRecording(completion: (String?, Exception?) -> Unit) {
        logI(TAG, "녹화 중지 요청됨 - 현재 상태: isRecording=$isRecording, recording=${this.recording != null}")
        
        val recording = this.recording
        if (recording == null || !isRecording) {
            logW(TAG, "녹화 중지 실패: 녹화 중이 아님 (recording=$recording, isRecording=$isRecording)")
            completion(null, Exception("녹화 중이 아닙니다"))
            return
        }
        
        if (recordingCompletionCallback != null && recordingCompletionCallback !== completion) {
            logW(TAG, "녹화 중지 실패: 이미 중지 중")
            completion(null, Exception("이미 녹화 중지 중입니다"))
            return
        }
        
        logI(TAG, "녹화 중지 시작...")
        recordingCompletionCallback = completion
        
        recordingStopRunnable = Runnable {
            synchronized(this) {
                if (isRecording || this.recording != null) {
                    logW(TAG, "녹화 중지 타임아웃 - 강제 정리")
                    isRecording = false
                    this.recording = null
                    val callback = recordingCompletionCallback
                    recordingCompletionCallback = null
                    callback?.invoke(null, Exception("녹화 중지 타임아웃"))
                    recordingStopRunnable = null
                }
            }
        }
        
        try {
            logI(TAG, "Recording.stop() 호출 중...")
            recording.stop()
            logI(TAG, "Recording.stop() 호출 완료 - 콜백 대기 중...")
            
            recordingStopRunnable?.let { recordingStopHandler.postDelayed(it, 5000) }
            
        } catch (e: Exception) {
            logE(TAG, "녹화 중지 중 오류 발생: $e")
            recordingStopRunnable?.let { recordingStopHandler.removeCallbacks(it) }
            recordingStopRunnable = null
            synchronized(this) {
                isRecording = false
                this.recording = null
                recordingCompletionCallback = null
            }
            completion(null, e)
        }
    }

    private fun getAvailableStorageSpace(): Long {
        return try {
            val externalDir = context.getExternalFilesDir(null)
            if (externalDir != null) {
                val stat = android.os.StatFs(externalDir.absolutePath)
                stat.availableBlocksLong * stat.blockSizeLong
            } else {
                val stat = android.os.StatFs(context.filesDir.absolutePath)
                stat.availableBlocksLong * stat.blockSizeLong
            }
        } catch (e: Exception) {
            logW(TAG, "저장 공간 확인 실패: $e")
            500L * 1024 * 1024
        }
    }
    
    fun setAudioEnabled(enabled: Boolean) {
        audioEnabled = enabled
    }
    
    fun forceStopRecording() {
        logW(TAG, "강제 녹화 중지 실행")
        synchronized(this) {
            try {
                recording?.stop()
            } catch (e: Exception) {
                logE(TAG, "강제 중지 중 recording.stop() 실패: $e")
            }
            
            isRecording = false
            recording = null
            val callback = recordingCompletionCallback
            recordingCompletionCallback = null
            
            callback?.invoke(null, Exception("강제 중지됨"))
            logI(TAG, "강제 녹화 중지 완료")
        }
    }
    // endregion

    // region Streaming functionality
    private fun setupThrottlingFromConfig() {
        streamConfig?.let { config ->
            config.maxFPS?.let { maxFPS ->
                if (maxFPS > 0) {
                    targetFrameInterval = (1_000_000_000L / maxFPS)
                }
            } ?: run {
                targetFrameInterval = null
            }
            
            config.throttleIntervalMs?.let { throttleMs ->
                if (throttleMs > 0) {
                    throttleInterval = throttleMs * 1_000_000L
                }
            } ?: run {
                throttleInterval = null
            }
            
            config.inferenceFrequency?.let { inferenceFreq ->
                if (inferenceFreq > 0) {
                    inferenceFrameInterval = (1_000_000_000L / inferenceFreq)
                }
            } ?: run {
                inferenceFrameInterval = null
            }
            
            config.skipFrames?.let { skipFrames ->
                if (skipFrames > 0) {
                    targetSkipFrames = skipFrames
                    frameSkipCount = 0
                }
            } ?: run {
                targetSkipFrames = 0
                frameSkipCount = 0
            }
            
            lastInferenceTime = System.nanoTime()
        }
    }
    
    private fun shouldRunInference(): Boolean {
        val now = System.nanoTime()
        
        if (targetSkipFrames > 0) {
            frameSkipCount++
            if (frameSkipCount <= targetSkipFrames) {
                return false
            } else {
                frameSkipCount = 0
                return true
            }
        }
        
        inferenceFrameInterval?.let { interval ->
            if (now - lastInferenceTime < interval) {
                return false
            }
        }
        
        return true
    }
    
    private fun shouldProcessFrame(): Boolean {
        val now = System.nanoTime()
        
        targetFrameInterval?.let { interval ->
            if (now - lastInferenceTime < interval) {
                return false
            }
        }
        
        throttleInterval?.let { interval ->
            if (now - lastInferenceTime < interval) {
                return false
            }
        }
        
        return true
    }
    
    private fun updateLastInferenceTime() {
        lastInferenceTime = System.nanoTime()
    }
    
    private fun convertResultToStreamData(result: YOLOResult): Map<String, Any> {
        val map = HashMap<String, Any>()
        val config = streamConfig ?: return emptyMap()
        
        if (config.includeDetections) {
            val detections = ArrayList<Map<String, Any>>()
            
            for ((detectionIndex, box) in result.boxes.withIndex()) {
                val detection = HashMap<String, Any>()
                detection["classIndex"] = box.index
                detection["className"] = box.cls
                detection["confidence"] = box.conf.toDouble()
                
                val boundingBox = HashMap<String, Any>()
                boundingBox["left"] = box.xywh.left.toDouble()
                boundingBox["top"] = box.xywh.top.toDouble()
                boundingBox["right"] = box.xywh.right.toDouble()
                boundingBox["bottom"] = box.xywh.bottom.toDouble()
                detection["boundingBox"] = boundingBox
                
                val normalizedBox = HashMap<String, Any>()
                normalizedBox["left"] = box.xywhn.left.toDouble()
                normalizedBox["top"] = box.xywhn.top.toDouble()
                normalizedBox["right"] = box.xywhn.right.toDouble()
                normalizedBox["bottom"] = box.xywhn.bottom.toDouble()
                detection["normalizedBox"] = normalizedBox
                
                if (config.includeMasks && result.masks != null && detectionIndex < result.masks!!.masks.size) {
                    val maskData = result.masks!!.masks[detectionIndex]
                    val maskDataDouble = maskData.map { row ->
                        row.map { it.toDouble() }
                    }
                    detection["mask"] = maskDataDouble
                }
                
                if (config.includePoses && detectionIndex < result.keypointsList.size) {
                    val keypoints = result.keypointsList[detectionIndex]
                    val keypointsFlat = mutableListOf<Double>()
                    for (i in keypoints.xy.indices) {
                        keypointsFlat.add(keypoints.xy[i].first.toDouble())
                        keypointsFlat.add(keypoints.xy[i].second.toDouble())
                        if (i < keypoints.conf.size) {
                            keypointsFlat.add(keypoints.conf[i].toDouble())
                        } else {
                            keypointsFlat.add(0.0)
                        }
                    }
                    detection["keypoints"] = keypointsFlat
                }
                
                if (config.includeOBB && detectionIndex < result.obb.size) {
                    val obbResult = result.obb[detectionIndex]
                    val obbBox = obbResult.box
                    
                    val polygon = obbBox.toPolygon()
                    val points = polygon.map { point ->
                        mapOf(
                            "x" to point.x.toDouble(),
                            "y" to point.y.toDouble()
                        )
                    }
                    
                    val obbDataMap = mapOf(
                        "centerX" to obbBox.cx.toDouble(),
                        "centerY" to obbBox.cy.toDouble(),
                        "width" to obbBox.w.toDouble(),
                        "height" to obbBox.h.toDouble(),
                        "angle" to obbBox.angle.toDouble(),
                        "angleDegrees" to (obbBox.angle * 180.0 / Math.PI),
                        "area" to obbBox.area.toDouble(),
                        "points" to points,
                        "confidence" to obbResult.confidence.toDouble(),
                        "className" to obbResult.cls,
                        "classIndex" to obbResult.index
                    )
                    
                    detection["obb"] = obbDataMap
                }
                
                detections.add(detection)
            }
            
            map["detections"] = detections
        }
        
        if (config.includeProcessingTimeMs) {
            val processingTimeMs = result.speed.toDouble()
            map["processingTimeMs"] = processingTimeMs
        }
        
        if (config.includeFps) {
            map["fps"] = result.fps?.toDouble() ?: 0.0
        }
        
        if (config.includeOriginalImage) {
            result.originalImage?.let { bitmap ->
                val outputStream = java.io.ByteArrayOutputStream()
                bitmap.compress(Bitmap.CompressFormat.JPEG, 90, outputStream)
                val imageData = outputStream.toByteArray()
                map["originalImage"] = imageData
            }
        }
        
        return map
    }
    // endregion
} 