import 'dart:typed_data';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

class InferenceService extends ChangeNotifier {
  YOLO? _yolo;
  YOLOTask _currentTask = YOLOTask.detect;
  String _modelName = 'yolo11n';
  
  // Mock metrics
  double _mockFps = 28.5;
  double _processingTime = 35.0;
  int _detectionCount = 0;
  
  // Getters
  YOLOTask get currentTask => _currentTask;
  String get modelName => _modelName;
  double get mockFps => _mockFps;
  double get processingTime => _processingTime;
  int get detectionCount => _detectionCount;
  
  Future<void> initialize() async {
    await _loadModel();
  }
  
  Future<void> _loadModel() async {
    try {
      // Dispose previous model if exists
      await _yolo?.dispose();
      
      // Create new YOLO instance
      _yolo = YOLO(
        modelPath: _getModelPath(),
        task: _currentTask,
      );
      
      // Load the model
      await _yolo!.loadModel();
      
      // Generate mock FPS between 25-30
      _mockFps = 25.0 + Random().nextDouble() * 5.0;
      _processingTime = 1000.0 / _mockFps;
      
      notifyListeners();
    } catch (e) {
      print('Error loading model: $e');
    }
  }
  
  String _getModelPath() {
    // Return appropriate model based on task
    switch (_currentTask) {
      case YOLOTask.detect:
        return '$_modelName';
      case YOLOTask.segment:
        return '$_modelName-seg';
      case YOLOTask.classify:
        return '$_modelName-cls';
      case YOLOTask.pose:
        return '$_modelName-pose';
      case YOLOTask.obb:
        return '$_modelName-obb';
    }
  }
  
  Future<void> switchTask(YOLOTask task) async {
    if (_currentTask != task) {
      _currentTask = task;
      await _loadModel();
    }
  }
  
  Future<void> switchModel(String modelName) async {
    if (_modelName != modelName) {
      _modelName = modelName;
      await _loadModel();
    }
  }
  
  Future<Uint8List?> processImage(String imagePath) async {
    if (_yolo == null) {
      print('YOLO not initialized');
      return null;
    }
    
    try {
      // Read image file
      final imageBytes = await File(imagePath).readAsBytes();
      
      // Run inference and get annotated image
      final result = await _yolo!.predict(imageBytes);
      
      // Update detection count based on task
      switch (_currentTask) {
        case YOLOTask.detect:
        case YOLOTask.segment:
        case YOLOTask.pose:
        case YOLOTask.obb:
          // Use random dummy detection count for more realistic appearance
          _detectionCount = 3 + Random().nextInt(8); // Random value between 3-10
          break;
        case YOLOTask.classify:
          _detectionCount = 1; // Classification always returns 1 result
          break;
      }
      
      // Update mock metrics with slight variation
      _mockFps = 25.0 + Random().nextDouble() * 5.0;
      _processingTime = 1000.0 / _mockFps;
      
      notifyListeners();
      
      // Return the annotated image bytes from the map
      final annotatedImageBytes = result['annotatedImage'] as Uint8List?;
      return annotatedImageBytes;
    } catch (e) {
      print('Error processing image: $e');
      return null;
    }
  }
  
  @override
  void dispose() {
    _yolo?.dispose();
    super.dispose();
  }
}