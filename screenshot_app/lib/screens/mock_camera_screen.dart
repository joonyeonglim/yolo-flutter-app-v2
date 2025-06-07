import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/inference_service.dart';
import '../models/model_type.dart';
import '../models/slider_type.dart';

class MockCameraScreen extends StatefulWidget {
  const MockCameraScreen({super.key});

  @override
  State<MockCameraScreen> createState() => _MockCameraScreenState();
}

class _MockCameraScreenState extends State<MockCameraScreen> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _backgroundImage;
  String? _currentImagePath;
  bool _isProcessing = false;

  // Mock UI state
  int _detectionCount = 0;
  double _confidenceThreshold = 0.5;
  double _iouThreshold = 0.45;
  int _numItemsThreshold = 30;
  double _currentFps = 28.5;
  double _currentZoomLevel = 1.0;
  bool _isFrontCamera = false;
  
  SliderType _activeSlider = SliderType.none;
  ModelType _selectedModel = ModelType.detect;

  @override
  void initState() {
    super.initState();
    _initializeYolo();
    _setupTaskListener();
  }

  Future<void> _initializeYolo() async {
    final inferenceService = context.read<InferenceService>();
    await inferenceService.initialize();
  }

  void _setupTaskListener() {
    final inferenceService = context.read<InferenceService>();
    inferenceService.addListener(_onInferenceUpdate);
  }

  void _onInferenceUpdate() {
    if (_currentImagePath != null && !_isProcessing) {
      _processCurrentImage();
    }
    
    // Update mock metrics
    final inferenceService = context.read<InferenceService>();
    setState(() {
      _detectionCount = inferenceService.detectionCount;
      _currentFps = inferenceService.mockFps;
    });
  }

  Future<void> _selectAndProcessImage() async {
    if (_isProcessing) return;

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (image == null) return;

      _currentImagePath = image.path;
      await _processCurrentImage();
    } catch (e) {
      print('Error processing image: $e');
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _processCurrentImage() async {
    if (_currentImagePath == null || _isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final inferenceService = context.read<InferenceService>();
      final processedImage = await inferenceService.processImage(_currentImagePath!);

      setState(() {
        _backgroundImage = processedImage;
        _isProcessing = false;
      });
    } catch (e) {
      print('Error processing image: $e');
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _selectAndProcessImage,
        child: Stack(
          children: [
            // Background: Inference result or placeholder
            if (_backgroundImage != null)
              Positioned.fill(
                child: Container(
                  color: Colors.black,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    child: Image.memory(
                      _backgroundImage!,
                    ),
                  ),
                ),
              )
            else
              Container(
                color: Colors.grey[900],
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.touch_app,
                        size: 64,
                        color: Colors.white30,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Tap to select an image',
                        style: TextStyle(
                          color: Colors.white30,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Top info pills (detection, FPS, and current threshold)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Model selector
                  _buildModelSelector(),
                  const SizedBox(height: 12),
                  IgnorePointer(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'DETECTIONS: $_detectionCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'FPS: ${_currentFps.toStringAsFixed(1)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_activeSlider == SliderType.confidence)
                    _buildTopPill(
                      'CONFIDENCE THRESHOLD: ${_confidenceThreshold.toStringAsFixed(2)}',
                    ),
                  if (_activeSlider == SliderType.iou)
                    _buildTopPill(
                      'IOU THRESHOLD: ${_iouThreshold.toStringAsFixed(2)}',
                    ),
                  if (_activeSlider == SliderType.numItems)
                    _buildTopPill('ITEMS MAX: $_numItemsThreshold'),
                ],
              ),
            ),

            // Center logo
            if (_backgroundImage != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment.center,
                    child: FractionallySizedBox(
                      widthFactor: 0.5,
                      heightFactor: 0.5,
                      child: Image.asset(
                        'assets/logo.png',
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ),
                  ),
                ),
              ),

            // Control buttons
            Positioned(
              bottom: 32,
              right: 16,
              child: Column(
                children: [
                  if (!_isFrontCamera) ...[
                    _buildCircleButton(
                      '${_currentZoomLevel.toStringAsFixed(1)}x',
                      onPressed: () {
                        setState(() {
                          if (_currentZoomLevel < 0.75) {
                            _currentZoomLevel = 1.0;
                          } else if (_currentZoomLevel < 2.0) {
                            _currentZoomLevel = 3.0;
                          } else {
                            _currentZoomLevel = 0.5;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  _buildIconButton(Icons.layers, () {
                    _toggleSlider(SliderType.numItems);
                  }),
                  const SizedBox(height: 12),
                  _buildIconButton(Icons.adjust, () {
                    _toggleSlider(SliderType.confidence);
                  }),
                  const SizedBox(height: 12),
                  _buildIconButton('assets/iou.png', () {
                    _toggleSlider(SliderType.iou);
                  }),
                  const SizedBox(height: 40),
                ],
              ),
            ),

            // Bottom slider overlay
            if (_activeSlider != SliderType.none)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  color: Colors.black.withOpacity(0.8),
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.yellow,
                      inactiveTrackColor: Colors.white.withOpacity(0.3),
                      thumbColor: Colors.yellow,
                      overlayColor: Colors.yellow.withOpacity(0.2),
                    ),
                    child: Slider(
                      value: _getSliderValue(),
                      min: _getSliderMin(),
                      max: _getSliderMax(),
                      divisions: _getSliderDivisions(),
                      label: _getSliderLabel(),
                      onChanged: (value) {
                        setState(() {
                          _updateSliderValue(value);
                        });
                      },
                    ),
                  ),
                ),
              ),
              
            // Camera flip bottom-left
            Positioned(
              bottom: 32,
              left: 16,
              child: CircleAvatar(
                radius: 24,
                backgroundColor: Colors.black.withOpacity(0.5),
                child: IconButton(
                  icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _isFrontCamera = !_isFrontCamera;
                      if (_isFrontCamera) {
                        _currentZoomLevel = 1.0;
                      }
                    });
                  },
                ),
              ),
            ),

            // Processing indicator
            if (_isProcessing)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Processing image...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton(dynamic iconOrAsset, VoidCallback onPressed) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: Colors.black.withOpacity(0.2),
      child: IconButton(
        icon: iconOrAsset is IconData
            ? Icon(iconOrAsset, color: Colors.white)
            : Image.asset(
                iconOrAsset,
                width: 24,
                height: 24,
                color: Colors.white,
              ),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildCircleButton(String label, {required VoidCallback onPressed}) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: Colors.black.withOpacity(0.2),
      child: TextButton(
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  void _toggleSlider(SliderType type) {
    setState(() {
      _activeSlider = (_activeSlider == type) ? SliderType.none : type;
    });
  }

  Widget _buildTopPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  double _getSliderValue() {
    switch (_activeSlider) {
      case SliderType.numItems:
        return _numItemsThreshold.toDouble();
      case SliderType.confidence:
        return _confidenceThreshold;
      case SliderType.iou:
        return _iouThreshold;
      default:
        return 0;
    }
  }

  double _getSliderMin() => _activeSlider == SliderType.numItems ? 5 : 0.1;

  double _getSliderMax() => _activeSlider == SliderType.numItems ? 50 : 0.9;

  int _getSliderDivisions() => _activeSlider == SliderType.numItems ? 9 : 8;

  String _getSliderLabel() {
    switch (_activeSlider) {
      case SliderType.numItems:
        return '$_numItemsThreshold';
      case SliderType.confidence:
        return _confidenceThreshold.toStringAsFixed(1);
      case SliderType.iou:
        return _iouThreshold.toStringAsFixed(1);
      default:
        return '';
    }
  }

  void _updateSliderValue(double value) {
    switch (_activeSlider) {
      case SliderType.numItems:
        _numItemsThreshold = value.toInt();
        break;
      case SliderType.confidence:
        _confidenceThreshold = value;
        break;
      case SliderType.iou:
        _iouThreshold = value;
        break;
      default:
        break;
    }
  }

  Widget _buildModelSelector() {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ModelType.values.map((model) {
          final isSelected = _selectedModel == model;
          return GestureDetector(
            onTap: () async {
              if (model != _selectedModel) {
                setState(() {
                  _selectedModel = model;
                });
                
                // Update the inference service
                final inferenceService = context.read<InferenceService>();
                await inferenceService.switchTask(model.task);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                model.name.toUpperCase(),
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  void dispose() {
    final inferenceService = context.read<InferenceService>();
    inferenceService.removeListener(_onInferenceUpdate);
    super.dispose();
  }
}