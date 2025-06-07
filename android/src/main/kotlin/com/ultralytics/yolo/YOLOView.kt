// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

package com.ultralytics.yolo

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.*
import android.util.AttributeSet
import android.util.Log
import android.view.*
import android.widget.FrameLayout
import android.widget.Toast
import android.view.ScaleGestureDetector
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
import androidx.camera.video.PendingRecording
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import com.google.common.util.concurrent.ListenableFuture
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.min
import android.widget.TextView
import android.view.Gravity
import java.io.File
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.TimeUnit

class YOLOView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null
) : FrameLayout(context, attrs), DefaultLifecycleObserver {

    // Lifecycle owner for camera
    private var lifecycleOwner: LifecycleOwner? = null

    companion object {
        private const val REQUEST_CODE_PERMISSIONS = 10
        private val REQUIRED_PERMISSIONS = arrayOf(
            Manifest.permission.CAMERA,
            Manifest.permission.RECORD_AUDIO
        )

        private const val TAG = "YOLOView"
        
        // 로그 레벨 제어
        private const val LOG_LEVEL_VERBOSE = 0
        private const val LOG_LEVEL_DEBUG = 1
        private const val LOG_LEVEL_INFO = 2
        private const val LOG_LEVEL_WARN = 3
        private const val LOG_LEVEL_ERROR = 4
        
        // 현재 로그 레벨 설정 (INFO 이상만 표시)
        private const val CURRENT_LOG_LEVEL = LOG_LEVEL_INFO
        
        // 로그 유틸리티 함수들
        private fun logI(tag: String, message: String) {
            if (CURRENT_LOG_LEVEL <= LOG_LEVEL_INFO) {
                Log.i(tag, message)
            }
        }
        
        private fun logW(tag: String, message: String) {
            if (CURRENT_LOG_LEVEL <= LOG_LEVEL_WARN) {
                Log.w(tag, message)
            }
        }
        
        private fun logE(tag: String, message: String, throwable: Throwable? = null) {
            if (CURRENT_LOG_LEVEL <= LOG_LEVEL_ERROR) {
                if (throwable != null) {
                    Log.e(tag, message, throwable)
                } else {
                    Log.e(tag, message)
                }
            }
        }

        // Line thickness and corner radius
        private const val BOX_LINE_WIDTH = 8f
        private const val BOX_CORNER_RADIUS = 12f
        private const val KEYPOINT_LINE_WIDTH = 6f

        // Colors derived from Ultralytics
        private val ultralyticsColors = arrayOf(
            Color.argb(153, 4,   42,  255),
            Color.argb(153, 11,  219, 235),
            Color.argb(153, 243, 243, 243),
            Color.argb(153, 0,   223, 183),
            Color.argb(153, 17,  31,  104),
            Color.argb(153, 255, 111, 221),
            Color.argb(153, 255, 68,  79),
            Color.argb(153, 204, 237, 0),
            Color.argb(153, 0,   243, 68),
            Color.argb(153, 189, 0,   255),
            Color.argb(153, 0,   180, 255),
            Color.argb(153, 221, 0,   186),
            Color.argb(153, 0,   255, 255),
            Color.argb(153, 38,  192, 0),
            Color.argb(153, 1,   255, 179),
            Color.argb(153, 125, 36,  255),
            Color.argb(153, 123, 0,   104),
            Color.argb(153, 255, 27,  108),
            Color.argb(153, 252, 109, 47),
            Color.argb(153, 162, 255, 11)
        )

        // Pose
        private val posePalette = arrayOf(
            floatArrayOf(255f, 128f,  0f),
            floatArrayOf(255f, 153f,  51f),
            floatArrayOf(255f, 178f, 102f),
            floatArrayOf(230f, 230f,   0f),
            floatArrayOf(255f, 153f, 255f),
            floatArrayOf(153f, 204f, 255f),
            floatArrayOf(255f, 102f, 255f),
            floatArrayOf(255f,  51f, 255f),
            floatArrayOf(102f, 178f, 255f),
            floatArrayOf( 51f, 153f, 255f),
            floatArrayOf(255f, 153f, 153f),
            floatArrayOf(255f, 102f, 102f),
            floatArrayOf(255f,  51f,  51f),
            floatArrayOf(153f, 255f, 153f),
            floatArrayOf(102f, 255f, 102f),
            floatArrayOf( 51f, 255f,  51f),
            floatArrayOf(  0f, 255f,   0f),
            floatArrayOf(  0f,   0f, 255f),
            floatArrayOf(255f,   0f,   0f),
            floatArrayOf(255f, 255f, 255f),
        )

        private val kptColorIndices = intArrayOf(
            16,16,16,16,16,
            9, 9, 9, 9, 9, 9,
            0, 0, 0, 0, 0, 0
        )

        private val limbColorIndices = intArrayOf(
            0, 0, 0, 0,
            7, 7, 7,
            9, 9, 9, 9, 9,
            16,16,16,16,16,16,16
        )

        private val skeleton = arrayOf(
            intArrayOf(16, 14),
            intArrayOf(14, 12),
            intArrayOf(17, 15),
            intArrayOf(15, 13),
            intArrayOf(12, 13),
            intArrayOf(6, 12),
            intArrayOf(7, 13),
            intArrayOf(6, 7),
            intArrayOf(6, 8),
            intArrayOf(7, 9),
            intArrayOf(8, 10),
            intArrayOf(9, 11),
            intArrayOf(2, 3),
            intArrayOf(1, 2),
            intArrayOf(1, 3),
            intArrayOf(2, 4),
            intArrayOf(3, 5),
            intArrayOf(4, 6),
            intArrayOf(5, 7)
        )
    }

    // Callback to notify inference results externally
    private var inferenceCallback: ((YOLOResult) -> Unit)? = null
    
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

    /** Set the callback */
    fun setOnInferenceCallback(callback: (YOLOResult) -> Unit) {
        this.inferenceCallback = callback
    }
    
    /** Set streaming configuration */
    fun setStreamConfig(config: YOLOStreamConfig?) {
        this.streamConfig = config
        setupThrottlingFromConfig()
    }
    
    /** Set streaming callback */
    fun setStreamCallback(callback: ((Map<String, Any>) -> Unit)?) {
        this.streamCallback = callback
    }

    // Callback to notify model load completion
    private var modelLoadCallback: ((Boolean) -> Unit)? = null

    /** Set model load completion callback (true: success) */
    fun setOnModelLoadCallback(callback: (Boolean) -> Unit) {
        this.modelLoadCallback = callback
    }

    // Use a PreviewView, forcing a TextureView under the hood
    private val previewView: PreviewView = PreviewView(context).apply {
        // Force TextureView usage so the overlay can be on top
        implementationMode = PreviewView.ImplementationMode.COMPATIBLE
        scaleType = PreviewView.ScaleType.FILL_CENTER
    }

    // The overlay for bounding boxes
    private val overlayView: OverlayView = OverlayView(context)

    private var inferenceResult: YOLOResult? = null
    private var predictor: Predictor? = null
    private var task: YOLOTask = YOLOTask.DETECT
    private var modelName: String = "Model"

    // Camera config
    private var lensFacing = CameraSelector.LENS_FACING_BACK
    
    // Recording 관련 프로퍼티들
    private var videoCapture: VideoCapture<Recorder>? = null
    private var recorder: Recorder? = null
    private var recording: Recording? = null
    private var isRecording = false
    private var audioEnabled = true
    private var recordingCompletionCallback: ((String?, Exception?) -> Unit)? = null
    private lateinit var cameraProviderFuture: ListenableFuture<ProcessCameraProvider>
    private var camera: Camera? = null
    
    // Zoom related
    private var currentZoomRatio = 1.0f
    private var minZoomRatio = 1.0f
    private var maxZoomRatio = 10.0f
    private lateinit var scaleGestureDetector: ScaleGestureDetector
    var onZoomChanged: ((Float) -> Unit)? = null

    // detection thresholds (can be changed externally via setters)
    private var confidenceThreshold = 0.25  // initial value
    private var iouThreshold = 0.45
    private var numItemsThreshold = 30
    private lateinit var zoomLabel: TextView

    // 녹화 중지 타임아웃 핸들러
    private val recordingStopHandler = android.os.Handler(android.os.Looper.getMainLooper())
    private var recordingStopRunnable: Runnable? = null

    init {
        // Clear any existing children
        removeAllViews()

        // 1) A container for the camera preview
        val previewContainer = FrameLayout(context).apply {
            layoutParams = LayoutParams(
                LayoutParams.MATCH_PARENT,
                LayoutParams.MATCH_PARENT
            )
        }

        // 2) Add the previewView to that container
        previewContainer.addView(previewView, LayoutParams(
            LayoutParams.MATCH_PARENT,
            LayoutParams.MATCH_PARENT
        ))

        // 3) Add that container
        addView(previewContainer)

        // 4) Add the overlay on top
        addView(overlayView, LayoutParams(
            LayoutParams.MATCH_PARENT,
            LayoutParams.MATCH_PARENT
        ))

        // Ensure overlay is visually above the preview container
        overlayView.elevation = 100f
        overlayView.translationZ = 100f
        previewContainer.elevation = 1f
        
        // Add zoom label
        zoomLabel = TextView(context).apply {
            layoutParams = LayoutParams(
                LayoutParams.WRAP_CONTENT,
                LayoutParams.WRAP_CONTENT
            ).apply {
                gravity = Gravity.CENTER
            }
            text = "1.0x"
            textSize = 24f
            setTextColor(Color.WHITE)
            setBackgroundColor(Color.argb(128, 0, 0, 0))
            setPadding(16, 8, 16, 8)
            visibility = View.GONE
        }
        addView(zoomLabel)
        
        // Initialize scale gesture detector for pinch-to-zoom
        scaleGestureDetector = ScaleGestureDetector(context, object : ScaleGestureDetector.SimpleOnScaleGestureListener() {
            override fun onScale(detector: ScaleGestureDetector): Boolean {
                val scale = detector.scaleFactor
                val newZoomRatio = currentZoomRatio * scale
                
                // Clamp zoom ratio between min and max
                val clampedZoomRatio = newZoomRatio.coerceIn(minZoomRatio, camera?.cameraInfo?.zoomState?.value?.maxZoomRatio ?: maxZoomRatio)
                
                camera?.cameraControl?.setZoomRatio(clampedZoomRatio)
                currentZoomRatio = clampedZoomRatio
                
                // Notify zoom change
                onZoomChanged?.invoke(currentZoomRatio)
                
                return true
            }
        })

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
    
    fun setZoomLevel(zoomLevel: Float) {
        camera?.let { cam: Camera ->
            // Clamp zoom level between min and max
            val clampedZoomRatio = zoomLevel.coerceIn(minZoomRatio, cam.cameraInfo.zoomState.value?.maxZoomRatio ?: maxZoomRatio)
            
            cam.cameraControl.setZoomRatio(clampedZoomRatio)
            currentZoomRatio = clampedZoomRatio
            
            // Notify zoom change
            onZoomChanged?.invoke(currentZoomRatio)
        }
    }

    // endregion

    // region Model / Task

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

                post {
                    this.task = task
                    this.predictor = newPredictor
                    this.modelName = modelPath.substringAfterLast("/")
                    modelLoadCallback?.invoke(true)
                    callback?.invoke(true)
                }
            } catch (e: Exception) {
                logE(TAG, "Failed to load model: $modelPath", e)
                post {
                    modelLoadCallback?.invoke(false)
                    callback?.invoke(false)
                }
            }
        }
    }

    private fun loadLabels(modelPath: String): List<String> {
        // Try to load labels from model metadata first
        val loadedLabels = YOLOFileUtils.loadLabelsFromAppendedZip(context, modelPath)
        if (loadedLabels != null) {
            return loadedLabels
        }
        
        // Return COCO dataset's 80 classes as a fallback
        // This is much more complete than the previous 7-class hardcoded list
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

    /**
     * Called when a LifecycleOwner is available for camera operations
     */
    fun onLifecycleOwnerAvailable(owner: LifecycleOwner) {
        this.lifecycleOwner = owner
        // Register as a lifecycle observer to handle lifecycle events
        owner.lifecycle.addObserver(this)
        
        // If camera was requested but couldn't start due to missing lifecycle owner, try again
        if (allPermissionsGranted()) {
            startCamera()
        }
    }
    
    // region camera init

    fun initCamera() {
        if (allPermissionsGranted()) {
            startCamera()
        } else {
            val activity = context as? Activity ?: return
            ActivityCompat.requestPermissions(
                activity,
                REQUIRED_PERMISSIONS,
                REQUEST_CODE_PERMISSIONS
            )
        }
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
                Toast.makeText(context, "Camera permission not granted.", Toast.LENGTH_SHORT).show()
            }
        }
    }

    private fun allPermissionsGranted() = REQUIRED_PERMISSIONS.all {
        ContextCompat.checkSelfPermission(context, it) == PackageManager.PERMISSION_GRANTED
    }

    fun startCamera() {

        try {
            val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
            cameraProviderFuture.addListener({
                try {
                    val cameraProvider = cameraProviderFuture.get()

                    val preview = Preview.Builder()
                        .setTargetResolution(android.util.Size(1920, 1080))
                        .build()

                    val imageAnalysis = ImageAnalysis.Builder()
                        .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                        .setTargetResolution(android.util.Size(320, 320))
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

                    cameraProvider.unbindAll()

                    try {
                        val owner = lifecycleOwner
                        if (owner == null) {
                            logE(TAG, "No LifecycleOwner available. Call onLifecycleOwnerAvailable() first.")
                            return@addListener
                        }
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

                        preview.setSurfaceProvider(previewView.surfaceProvider)
                        
                        // Initialize zoom
                        camera?.let { cam: Camera ->
                            val cameraInfo = cam.cameraInfo
                            minZoomRatio = cameraInfo.zoomState.value?.minZoomRatio ?: 1.0f
                            maxZoomRatio = cameraInfo.zoomState.value?.maxZoomRatio ?: 1.0f
                            currentZoomRatio = cameraInfo.zoomState.value?.zoomRatio ?: 1.0f
                        }
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

    fun stopCamera() {
        Log.d(TAG, "Stopping camera")
        try {
            val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
            cameraProviderFuture.addListener({
                val cameraProvider = cameraProviderFuture.get()
                cameraProvider.unbindAll()
                Log.d(TAG, "Camera stopped successfully")
            }, ContextCompat.getMainExecutor(context))
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping camera", e)
        }
    }

    fun pauseCamera() {
        // Android doesn't have a separate pause state, so we'll just stop
        Log.d(TAG, "Pausing camera (stopping)")
        stopCamera()
    }

    fun resumeCamera() {
        Log.d(TAG, "Resuming camera")
        if (allPermissionsGranted()) {
            startCamera()
        } else {
            Log.w(TAG, "Cannot resume camera - permissions not granted")
        }
    }

    // endregion
    
    // Lifecycle methods from DefaultLifecycleObserver
    override fun onStart(owner: LifecycleOwner) {
        if (allPermissionsGranted()) {
            startCamera()
        }
    }

    override fun onStop(owner: LifecycleOwner) {
        // Camera will be automatically stopped by CameraX when lifecycle stops
    }

    // region onFrame (per frame inference)

    private fun onFrame(imageProxy: ImageProxy) {
        val bitmap = ImageUtils.toBitmap(imageProxy) ?: run {
            logE(TAG, "Failed to convert ImageProxy to Bitmap")
            imageProxy.close()
            return
        }

        predictor?.let { p ->
            // Check if we should run inference on this frame
            if (!shouldRunInference()) {
                imageProxy.close()
                return
            }
            
            try {
                // For camera feed, we typically rotate the bitmap
                val result = p.predict(bitmap, imageProxy.height, imageProxy.width, rotateForCamera = true)
                
                // Apply originalImage if streaming config requires it
                val resultWithOriginalImage = if (streamConfig?.includeOriginalImage == true) {
                    result.copy(originalImage = bitmap)  // Reuse bitmap from ImageProxy conversion
                } else {
                    result
                }
                
                inferenceResult = resultWithOriginalImage

                // Callback
                inferenceCallback?.invoke(resultWithOriginalImage)
                
                // Streaming callback (with output throttling)
                streamCallback?.let { callback ->
                    if (shouldProcessFrame()) {
                        updateLastInferenceTime()
                        
                        // Convert to stream data and send
                        val streamData = convertResultToStreamData(resultWithOriginalImage)
                        // Add timestamp and frame info
                        val enhancedStreamData = HashMap<String, Any>(streamData)
                        enhancedStreamData["timestamp"] = System.currentTimeMillis()
                        enhancedStreamData["frameNumber"] = frameNumberCounter++
                        
                        callback.invoke(enhancedStreamData)
                    }
                }

                // Update overlay
                post {
                    overlayView.invalidate()
                }
            } catch (e: Exception) {
                logE(TAG, "Error during prediction", e)
            }
        }
        imageProxy.close()
    }

    // endregion

    // region OverlayView

    private inner class OverlayView(context: Context) : View(context) {
        private val paint = Paint().apply { isAntiAlias = true }

        init {
            // Make background transparent
            setBackgroundColor(Color.TRANSPARENT)
            // Use hardware layer for better z-order 
            setLayerType(LAYER_TYPE_HARDWARE, null)

            // Raise overlay
            elevation = 1000f
            translationZ = 1000f

            setWillNotDraw(false)

            // Make overlay not intercept touch events
            isClickable = false
            isFocusable = false


        }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            val result = inferenceResult ?: return

            val iw = result.origShape.width.toFloat()
            val ih = result.origShape.height.toFloat()

            val vw = width.toFloat()
            val vh = height.toFloat()

            // Scale factor from camera image to view
            val scaleX = vw / iw
            val scaleY = vh / ih
            val scale = max(scaleX, scaleY)

            val scaledW = iw * scale
            val scaledH = ih * scale

            val dx = (vw - scaledW) / 2f
            val dy = (vh - scaledH) / 2f
            
            // Check if using front camera
            val isFrontCamera = lensFacing == CameraSelector.LENS_FACING_FRONT

            when (task) {
                // ----------------------------------------
                // DETECT
                // ----------------------------------------
                YOLOTask.DETECT -> {
                    for (box in result.boxes) {
                        // Adjust alpha based on confidence
                        val alpha = (box.conf * 255).toInt().coerceIn(0, 255)
                        val baseColor = ultralyticsColors[box.index % ultralyticsColors.size]
                        val newColor = Color.argb(
                            alpha,
                            Color.red(baseColor),
                            Color.green(baseColor),
                            Color.blue(baseColor)
                        )

                        // Log the original box.xywh values
                        
                        // Draw bounding box like in the original code
                        var left   = box.xywh.left   * scale + dx
                        var top    = box.xywh.top    * scale + dy
                        var right  = box.xywh.right  * scale + dx
                        var bottom = box.xywh.bottom * scale + dy
                        
                        // Flip vertically for front camera
                        if (isFrontCamera) {
                            val flippedTop = vh - bottom
                            val flippedBottom = vh - top
                            top = flippedTop
                            bottom = flippedBottom
                        }
                        

                        paint.color = newColor
                        paint.style = Paint.Style.STROKE
                        paint.strokeWidth = BOX_LINE_WIDTH
                        canvas.drawRoundRect(
                            left, top, right, bottom,
                            BOX_CORNER_RADIUS, BOX_CORNER_RADIUS,
                            paint
                        )

                        // Label text
                        val labelText = "${box.cls} ${"%.1f".format(box.conf * 100)}%"
                        paint.textSize = 40f
                        val fm = paint.fontMetrics
                        val textWidth = paint.measureText(labelText)
                        val textHeight = fm.bottom - fm.top
                        val pad = 8f

                        // Label background height is (text height + 2*padding)
                        val labelBoxHeight = textHeight + 2 * pad
                        // Place label on top of the box's upper edge
                        val labelBottom = top
                        val labelTop = labelBottom - labelBoxHeight

                        // Rectangle for label background
                        val labelLeft = left
                        val labelRight = left + textWidth + 2 * pad
                        val bgRect = RectF(labelLeft, labelTop, labelRight, labelBottom)

                        // Draw background
                        paint.style = Paint.Style.FILL
                        paint.color = newColor
                        canvas.drawRoundRect(bgRect, BOX_CORNER_RADIUS, BOX_CORNER_RADIUS, paint)

                        // Center text vertically within the rectangle
                        paint.color = Color.WHITE
                        // Center position = (bgRect.top + bgRect.bottom)/2
                        val centerY = (labelTop + labelBottom) / 2
                        // Baseline = centerY - (fm.descent + fm.ascent)/2
                        val baseline = centerY - (fm.descent + fm.ascent) / 2
                        // X coordinate is left-aligned plus padding
                        val textX = labelLeft + pad

                        canvas.drawText(labelText, textX, baseline, paint)
                    }
                }
                // ----------------------------------------
                // SEGMENT
                // ----------------------------------------
                YOLOTask.SEGMENT -> {
                    // Bounding boxes & labels
                    for (box in result.boxes) {
                        val alpha = (box.conf * 255).toInt().coerceIn(0, 255)
                        val baseColor = ultralyticsColors[box.index % ultralyticsColors.size]
                        val newColor = Color.argb(
                            alpha,
                            Color.red(baseColor),
                            Color.green(baseColor),
                            Color.blue(baseColor)
                        )

                        // Draw bounding box
                        var left   = box.xywh.left   * scale + dx
                        var top    = box.xywh.top    * scale + dy
                        var right  = box.xywh.right  * scale + dx
                        var bottom = box.xywh.bottom * scale + dy
                        
                        // Flip vertically for front camera
                        if (isFrontCamera) {
                            val flippedTop = vh - bottom
                            val flippedBottom = vh - top
                            top = flippedTop
                            bottom = flippedBottom
                        }

                        paint.color = newColor
                        paint.style = Paint.Style.STROKE
                        paint.strokeWidth = BOX_LINE_WIDTH
                        canvas.drawRoundRect(
                            left, top, right, bottom,
                            BOX_CORNER_RADIUS, BOX_CORNER_RADIUS,
                            paint
                        )

                        // Label background + text (vertically centered)
                        val labelText = "${box.cls} ${"%.1f".format(box.conf * 100)}%"
                        paint.textSize = 40f
                        val fm = paint.fontMetrics
                        val textWidth = paint.measureText(labelText)
                        val textHeight = fm.bottom - fm.top
                        val pad = 8f

                        val labelBoxHeight = textHeight + 2 * pad
                        val labelBottom = top
                        val labelTop = labelBottom - labelBoxHeight
                        val labelLeft = left
                        val labelRight = left + textWidth + 2 * pad
                        val bgRect = RectF(labelLeft, labelTop, labelRight, labelBottom)

                        paint.style = Paint.Style.FILL
                        paint.color = newColor
                        canvas.drawRoundRect(bgRect, BOX_CORNER_RADIUS, BOX_CORNER_RADIUS, paint)

                        paint.color = Color.WHITE
                        val centerY = (labelTop + labelBottom) / 2
                        val baseline = centerY - (fm.descent + fm.ascent) / 2
                        canvas.drawText(labelText, labelLeft + pad, baseline, paint)
                    }

                    // Segmentation mask
                    result.masks?.combinedMask?.let { maskBitmap ->
                        val src = Rect(0, 0, maskBitmap.width, maskBitmap.height)
                        val dst = RectF(dx, dy, dx + scaledW, dy + scaledH)
                        val maskPaint = Paint().apply { alpha = 128 }
                        
                        if (isFrontCamera) {
                            // For front camera, flip the mask vertically
                            canvas.save()
                            // Translate to center, flip vertically, translate back
                            canvas.translate(0f, vh / 2f)
                            canvas.scale(1f, -1f)
                            canvas.translate(0f, -vh / 2f)
                            canvas.drawBitmap(maskBitmap, src, dst, maskPaint)
                            canvas.restore()
                        } else {
                            canvas.drawBitmap(maskBitmap, src, dst, maskPaint)
                        }
                    }
                }
                // ----------------------------------------
                // CLASSIFY (display large in center)
                // ----------------------------------------
                YOLOTask.CLASSIFY -> {
                    result.probs?.let { probs ->
                        val alpha = (probs.top1Conf * 255).toInt().coerceIn(0, 255)
                        // Select color based on top1Index
                        val baseColor = ultralyticsColors[probs.top1Index % ultralyticsColors.size]
                        val newColor = Color.argb(
                            alpha,
                            Color.red(baseColor),
                            Color.green(baseColor),
                            Color.blue(baseColor)
                        )

                        val labelText = "${probs.top1} ${"%.1f".format(probs.top1Conf * 100)}%"
                        paint.textSize = 60f
                        val textWidth = paint.measureText(labelText)
                        val fm = paint.fontMetrics
                        val textHeight = fm.bottom - fm.top
                        val pad = 16f

                        // Screen center
                        val centerX = vw / 2f
                        val centerY = vh / 2f

                        val bgLeft   = centerX - (textWidth / 2) - pad
                        val bgTop    = centerY - (textHeight / 2) - pad
                        val bgRight  = centerX + (textWidth / 2) + pad
                        val bgBottom = centerY + (textHeight / 2) + pad

                        paint.color = newColor
                        paint.style = Paint.Style.FILL
                        val bgRect = RectF(bgLeft, bgTop, bgRight, bgBottom)
                        canvas.drawRoundRect(bgRect, 20f, 20f, paint)

                        paint.color = Color.WHITE
                        val baseline = centerY - (fm.descent + fm.ascent)/2
                        canvas.drawText(labelText, centerX - (textWidth / 2), baseline, paint)
                    }
                }
                // ----------------------------------------
                // POSE
                // ----------------------------------------
                YOLOTask.POSE -> {
                    // Bounding boxes
                    for (box in result.boxes) {
                        val alpha = (box.conf * 255).toInt().coerceIn(0, 255)
                        val baseColor = ultralyticsColors[box.index % ultralyticsColors.size]
                        val newColor = Color.argb(
                            alpha,
                            Color.red(baseColor),
                            Color.green(baseColor),
                            Color.blue(baseColor)
                        )

                        var left   = box.xywh.left   * scale + dx
                        var top    = box.xywh.top    * scale + dy
                        var right  = box.xywh.right  * scale + dx
                        var bottom = box.xywh.bottom * scale + dy
                        
                        // Flip vertically for front camera
                        if (isFrontCamera) {
                            val flippedTop = vh - bottom
                            val flippedBottom = vh - top
                            top = flippedTop
                            bottom = flippedBottom
                        }

                        paint.color = newColor
                        paint.style = Paint.Style.STROKE
                        paint.strokeWidth = BOX_LINE_WIDTH
                        canvas.drawRoundRect(
                            left, top, right, bottom,
                            BOX_CORNER_RADIUS, BOX_CORNER_RADIUS,
                            paint
                        )
                    }

                    // Keypoints & skeleton
                    for (person in result.keypointsList) {
                        val points = arrayOfNulls<PointF>(person.xyn.size)
                        for (i in person.xyn.indices) {
                            val kp = person.xyn[i]
                            val conf = person.conf[i]
                            if (conf > 0.25f) {
                                val pxCam = kp.first * iw
                                val pyCam = kp.second * ih
                                val px = pxCam * scale + dx
                                var py = pyCam * scale + dy
                                
                                // Flip vertically for front camera
                                if (isFrontCamera) {
                                    py = vh - py
                                }

                                val colorIdx = if (i < kptColorIndices.size) kptColorIndices[i] else 0
                                val rgbArray = posePalette[colorIdx % posePalette.size]
                                paint.color = Color.argb(
                                    255,
                                    rgbArray[0].toInt().coerceIn(0,255),
                                    rgbArray[1].toInt().coerceIn(0,255),
                                    rgbArray[2].toInt().coerceIn(0,255)
                                )
                                paint.style = Paint.Style.FILL
                                canvas.drawCircle(px, py, 8f, paint)

                                points[i] = PointF(px, py)
                            }
                        }

                        // Skeleton connection
                        paint.style = Paint.Style.STROKE
                        paint.strokeWidth = KEYPOINT_LINE_WIDTH
                        for ((idx, bone) in skeleton.withIndex()) {
                            val i1 = bone[0] - 1  // 1-indexed to 0-indexed
                            val i2 = bone[1] - 1
                            val p1 = points.getOrNull(i1)
                            val p2 = points.getOrNull(i2)
                            if (p1 != null && p2 != null) {
                                val limbColorIdx = if (idx < limbColorIndices.size) limbColorIndices[idx] else 0
                                val rgbArray = posePalette[limbColorIdx % posePalette.size]
                                paint.color = Color.argb(
                                    255,
                                    rgbArray[0].toInt().coerceIn(0,255),
                                    rgbArray[1].toInt().coerceIn(0,255),
                                    rgbArray[2].toInt().coerceIn(0,255)
                                )
                                canvas.drawLine(p1.x, p1.y, p2.x, p2.y, paint)
                            }
                        }
                    }
                }
                // ----------------------------------------
                // OBB
                // ----------------------------------------
                YOLOTask.OBB -> {
                    for (obbRes in result.obb) {
                        val alpha = (obbRes.confidence * 255).toInt().coerceIn(0, 255)
                        val baseColor = ultralyticsColors[obbRes.index % ultralyticsColors.size]
                        val newColor = Color.argb(
                            alpha,
                            Color.red(baseColor),
                            Color.green(baseColor),
                            Color.blue(baseColor)
                        )

                        paint.color = newColor
                        paint.style = Paint.Style.STROKE
                        paint.strokeWidth = BOX_LINE_WIDTH

                        // Draw rotated rectangle (polygon) using path
                        val polygon = obbRes.box.toPolygon().map { pt ->
                            val x = pt.x * scaledW + dx
                            var y = pt.y * scaledH + dy
                            
                            // Flip vertically for front camera
                            if (isFrontCamera) {
                                y = vh - y
                            }
                            
                            PointF(x, y)
                        }
                        if (polygon.size >= 4) {
                            val path = Path().apply {
                                moveTo(polygon[0].x, polygon[0].y)
                                for (p in polygon.drop(1)) {
                                    lineTo(p.x, p.y)
                                }
                                close()
                            }
                            canvas.drawPath(path, paint)

                            // Label text
                            val labelText = "${obbRes.cls} ${"%.1f".format(obbRes.confidence * 100)}%"
                            paint.textSize = 40f
                            paint.typeface = Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD)

                            val fm = paint.fontMetrics
                            val textWidth = paint.measureText(labelText)
                            val textHeight = fm.bottom - fm.top
                            val padding = 10f
                            val cornerRadius = 8f

                            // Display background rectangle near polygon[0]
                            val labelBoxHeight = textHeight + 2 * padding
                            val labelBottom = polygon[0].y
                            val labelTop = labelBottom - labelBoxHeight
                            val labelLeft = polygon[0].x
                            val labelRight = labelLeft + textWidth + 2 * padding

                            val bgRect = RectF(labelLeft, labelTop, labelRight, labelBottom)
                            paint.style = Paint.Style.FILL
                            paint.color = newColor
                            canvas.drawRoundRect(bgRect, cornerRadius, cornerRadius, paint)

                            // Center text vertically
                            paint.color = Color.WHITE
                            val centerY = (labelTop + labelBottom) / 2
                            val baseline = centerY - (fm.descent + fm.ascent) / 2
                            val textX = labelLeft + padding
                            canvas.drawText(labelText, textX, baseline, paint)
                        }
                    }
                }
            }
        }
        
        override fun onTouchEvent(event: MotionEvent?): Boolean {
            // Pass through all touch events
            return false
        }
    }
    
    // Scale listener for pinch-to-zoom
    private inner class ScaleListener : ScaleGestureDetector.SimpleOnScaleGestureListener() {
        override fun onScaleBegin(detector: ScaleGestureDetector): Boolean {
            // Show zoom label when pinch starts
            zoomLabel.visibility = View.VISIBLE
            return true
        }
        
        override fun onScale(detector: ScaleGestureDetector): Boolean {
            val scaleFactor = detector.scaleFactor
            val newZoomRatio = currentZoomRatio * scaleFactor
            
            // Clamp zoom within min/max bounds
            val clampedZoom = newZoomRatio.coerceIn(minZoomRatio, maxZoomRatio)
            
            // Apply zoom to camera
            camera?.cameraControl?.setZoomRatio(clampedZoom)
            currentZoomRatio = clampedZoom
            
            // Update zoom label
            zoomLabel.text = String.format("%.1fx", currentZoomRatio)
            
            return true
        }
        
        override fun onScaleEnd(detector: ScaleGestureDetector) {
            // Hide zoom label after 2 seconds
            zoomLabel.postDelayed({
                zoomLabel.visibility = View.GONE
            }, 2000)
        }
    }
    
    // Touch event handling for pinch-to-zoom
    override fun onTouchEvent(event: MotionEvent): Boolean {
        scaleGestureDetector.onTouchEvent(event)
        return true
    }
    
    // region Streaming functionality
    
    /**
     * Setup throttling parameters from streaming configuration
     */
    private fun setupThrottlingFromConfig() {
        streamConfig?.let { config ->
            // Setup maxFPS throttling (for result output)
            config.maxFPS?.let { maxFPS ->
                if (maxFPS > 0) {
                    targetFrameInterval = (1_000_000_000L / maxFPS) // Convert to nanoseconds
                }
            } ?: run {
                targetFrameInterval = null
            }
            
            // Setup throttleInterval (for result output)
            config.throttleIntervalMs?.let { throttleMs ->
                if (throttleMs > 0) {
                    throttleInterval = throttleMs * 1_000_000L // Convert ms to nanoseconds
                }
            } ?: run {
                throttleInterval = null
            }
            
            // Setup inference frequency control
            config.inferenceFrequency?.let { inferenceFreq ->
                if (inferenceFreq > 0) {
                    inferenceFrameInterval = (1_000_000_000L / inferenceFreq) // Convert to nanoseconds
                }
            } ?: run {
                inferenceFrameInterval = null
            }
            
            // Setup frame skipping
            config.skipFrames?.let { skipFrames ->
                if (skipFrames > 0) {
                    targetSkipFrames = skipFrames
                    frameSkipCount = 0 // Reset counter
                }
            } ?: run {
                targetSkipFrames = 0
                frameSkipCount = 0
            }
            
            // Initialize timing
            lastInferenceTime = System.nanoTime()
        }
    }
    
    /**
     * Check if we should run inference on this frame based on inference frequency control
     */
    private fun shouldRunInference(): Boolean {
        val now = System.nanoTime()
        
        // Check frame skipping control first (simpler, more deterministic)
        if (targetSkipFrames > 0) {
            frameSkipCount++
            if (frameSkipCount <= targetSkipFrames) {
                // Still skipping frames
                return false
            } else {
                // Reset counter and allow inference
                frameSkipCount = 0
                return true
            }
        }
        
        // Check inference frequency control (time-based)
        inferenceFrameInterval?.let { interval ->
            if (now - lastInferenceTime < interval) {
                return false
            }
        }
        
        return true
    }
    
    /**
     * Check if we should send results to Flutter based on output throttling settings
     */
    private fun shouldProcessFrame(): Boolean {
        val now = System.nanoTime()
        
        // Check maxFPS throttling
        targetFrameInterval?.let { interval ->
            if (now - lastInferenceTime < interval) {
                return false
            }
        }
        
        // Check throttleInterval
        throttleInterval?.let { interval ->
            if (now - lastInferenceTime < interval) {
                return false
            }
        }
        
        return true
    }
    
    /**
     * Update the last inference time (call this when actually processing)
     */
    private fun updateLastInferenceTime() {
        lastInferenceTime = System.nanoTime()
    }
    
    /**
     * Convert YOLOResult to a Map for streaming (ported from archived YOLOPlatformView)
     * Uses detection index correctly to avoid class index confusion
     */
    private fun convertResultToStreamData(result: YOLOResult): Map<String, Any> {
        val map = HashMap<String, Any>()
        val config = streamConfig ?: return emptyMap()
        
        // Convert detection results (if enabled)
        if (config.includeDetections) {
            val detections = ArrayList<Map<String, Any>>()
            
            // Convert detection boxes - CRITICAL: use detectionIndex, not class index
            for ((detectionIndex, box) in result.boxes.withIndex()) {
                val detection = HashMap<String, Any>()
                detection["classIndex"] = box.index
                detection["className"] = box.cls
                detection["confidence"] = box.conf.toDouble()
                
                // Bounding box in original coordinates
                val boundingBox = HashMap<String, Any>()
                boundingBox["left"] = box.xywh.left.toDouble()
                boundingBox["top"] = box.xywh.top.toDouble()
                boundingBox["right"] = box.xywh.right.toDouble()
                boundingBox["bottom"] = box.xywh.bottom.toDouble()
                detection["boundingBox"] = boundingBox
                
                // Normalized bounding box (0-1)
                val normalizedBox = HashMap<String, Any>()
                normalizedBox["left"] = box.xywhn.left.toDouble()
                normalizedBox["top"] = box.xywhn.top.toDouble()
                normalizedBox["right"] = box.xywhn.right.toDouble()
                normalizedBox["bottom"] = box.xywhn.bottom.toDouble()
                detection["normalizedBox"] = normalizedBox
                
                // Add mask data for segmentation (if available and enabled)
                if (config.includeMasks && result.masks != null && detectionIndex < result.masks!!.masks.size) {
                    val maskData = result.masks!!.masks[detectionIndex] // Get mask for this detection
                    // Convert List<List<Float>> to List<List<Double>> for Flutter compatibility
                    val maskDataDouble = maskData.map { row ->
                        row.map { it.toDouble() }
                    }
                    detection["mask"] = maskDataDouble
                }
                
                // Add pose keypoints (if available and enabled)
                if (config.includePoses && detectionIndex < result.keypointsList.size) {
                    val keypoints = result.keypointsList[detectionIndex]
                    // Convert to flat array [x1, y1, conf1, x2, y2, conf2, ...]
                    val keypointsFlat = mutableListOf<Double>()
                    for (i in keypoints.xy.indices) {
                        keypointsFlat.add(keypoints.xy[i].first.toDouble())
                        keypointsFlat.add(keypoints.xy[i].second.toDouble())
                        if (i < keypoints.conf.size) {
                            keypointsFlat.add(keypoints.conf[i].toDouble())
                        } else {
                            keypointsFlat.add(0.0) // Default confidence if missing
                        }
                    }
                    detection["keypoints"] = keypointsFlat
                }
                
                // Add OBB data (if available and enabled)
                if (config.includeOBB && detectionIndex < result.obb.size) {
                    val obbResult = result.obb[detectionIndex]
                    val obbBox = obbResult.box
                    
                    // Convert OBB to 4 corner points
                    val polygon = obbBox.toPolygon()
                    val points = polygon.map { point ->
                        mapOf(
                            "x" to point.x.toDouble(),
                            "y" to point.y.toDouble()
                        )
                    }
                    
                    // Create comprehensive OBB data map
                    val obbDataMap = mapOf(
                        "centerX" to obbBox.cx.toDouble(),
                        "centerY" to obbBox.cy.toDouble(),
                        "width" to obbBox.w.toDouble(),
                        "height" to obbBox.h.toDouble(),
                        "angle" to obbBox.angle.toDouble(), // radians
                        "angleDegrees" to (obbBox.angle * 180.0 / Math.PI), // degrees for convenience
                        "area" to obbBox.area.toDouble(),
                        "points" to points, // 4 corner points
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
        
        // Add performance metrics (if enabled)
        if (config.includeProcessingTimeMs) {
            val processingTimeMs = result.speed.toDouble()
            map["processingTimeMs"] = processingTimeMs
        } else {
            logW(TAG, "⚠️ Skipping processingTimeMs (includeProcessingTimeMs=${config.includeProcessingTimeMs})")
        }
        
        if (config.includeFps) {
            map["fps"] = result.fps?.toDouble() ?: 0.0
        }
        
        // Add original image (if available and enabled)
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
    
    // region Recording Functions
    
    fun startRecording(completion: (String?, Exception?) -> Unit) {
        val videoCapture = this.videoCapture
        if (videoCapture == null) {
            completion(null, Exception("VideoCapture가 초기화되지 않았습니다"))
            return
        }
        
        // 실제 recording 상태와 플래그 동기화 확인
        if (isRecording && recording != null) {
            completion(null, Exception("이미 녹화 중입니다"))
            return
        } else if (isRecording && recording == null) {
            // 상태 불일치 - 플래그 재설정
            logW(TAG, "녹화 상태 불일치 감지 - isRecording은 true이지만 recording 객체가 null")
            isRecording = false
        }
        
        // 저장 공간 확인 (최소 100MB 필요)
        val availableSpace = getAvailableStorageSpace()
        if (availableSpace < 100 * 1024 * 1024) {
            completion(null, Exception("저장 공간이 부족합니다 (${availableSpace / (1024 * 1024)}MB 사용 가능)"))
            return
        }
        
        // 고유한 파일 이름 생성
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
            // 오디오 포함
            val pendingRecording = recorder!!
                .prepareRecording(context, mediaStoreOutputOptions)
                
            // 오디오 권한 확인
            if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) 
                == PackageManager.PERMISSION_GRANTED) {
                pendingRecording.withAudioEnabled()
            } else {
                // 오디오 권한이 없으면 비디오만 녹화
                logW(TAG, "오디오 권한이 없어 비디오만 녹화합니다")
                pendingRecording
            }
        } else {
            // 비디오만 녹화
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
                    
                    // 녹화 중지 타임아웃이 설정되어 있다면 제거
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
    
    private fun getAvailableStorageSpace(): Long {
        return try {
            val externalDir = context.getExternalFilesDir(null)
            if (externalDir != null) {
                val stat = android.os.StatFs(externalDir.absolutePath)
                stat.availableBlocksLong * stat.blockSizeLong
            } else {
                // Fallback: 내부 저장소 확인
                val stat = android.os.StatFs(context.filesDir.absolutePath)
                stat.availableBlocksLong * stat.blockSizeLong
            }
        } catch (e: Exception) {
            logW(TAG, "저장 공간 확인 실패: $e")
            500L * 1024 * 1024 // 500MB라고 가정
        }
    }
    
    fun stopRecording(completion: (String?, Exception?) -> Unit) {
        logI(TAG, "녹화 중지 요청됨 - 현재 상태: isRecording=$isRecording, recording=${this.recording != null}")
        
        val recording = this.recording
        if (recording == null || !isRecording) {
            logW(TAG, "녹화 중지 실패: 녹화 중이 아님 (recording=$recording, isRecording=$isRecording)")
            completion(null, Exception("녹화 중이 아닙니다"))
            return
        }
        
        // 중복 중지 요청 방지
        if (recordingCompletionCallback != null && recordingCompletionCallback !== completion) {
            logW(TAG, "녹화 중지 실패: 이미 중지 중")
            completion(null, Exception("이미 녹화 중지 중입니다"))
            return
        }
        
        logI(TAG, "녹화 중지 시작...")
        recordingCompletionCallback = completion
        
        // 타임아웃 핸들러 설정
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
            
            // 5초 타임아웃 설정
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
    
    // 녹화 상태 확인 (더 정확한 상태 체크)
    fun isRecording(): Boolean {
        val actualRecording = recording != null
        val flagState = isRecording
        
        // 상태 불일치 감지 및 자동 수정
        if (flagState != actualRecording) {
            logW(TAG, "녹화 상태 불일치 감지: flag=$flagState, actual=$actualRecording - 자동 수정")
            isRecording = actualRecording
        }
        
        return isRecording
    }
    
    // 오디오 활성화/비활성화
    fun setAudioEnabled(enabled: Boolean) {
        audioEnabled = enabled
    }
    
    // 강제 녹화 중지 (비상용)
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
}