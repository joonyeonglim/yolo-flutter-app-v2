import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class PhotoPickerService {
  static final ImagePicker _picker = ImagePicker();
  
  // Sample image paths for each task
  static const Map<String, String> sampleImages = {
    'detect': 'assets/sample_images/street_scene.jpg',
    'segment': 'assets/sample_images/indoor_scene.jpg',
    'classify': 'assets/sample_images/single_object.jpg',
    'pose': 'assets/sample_images/people_activity.jpg',
    'obb': 'assets/sample_images/aerial_view.jpg',
  };
  
  /// Pick image from gallery
  static Future<XFile?> pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );
      return image;
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }
  
  /// Load a sample image for the given task
  static Future<File?> loadSampleImage(String taskKey) async {
    try {
      final assetPath = sampleImages[taskKey];
      if (assetPath == null) return null;
      
      // Load asset as bytes
      final ByteData data = await rootBundle.load(assetPath);
      final Uint8List bytes = data.buffer.asUint8List();
      
      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/sample_$taskKey.jpg');
      await tempFile.writeAsBytes(bytes);
      
      return tempFile;
    } catch (e) {
      print('Error loading sample image: $e');
      return null;
    }
  }
  
  /// Get optimal image for a specific task
  static Future<File?> getOptimalImageForTask(String task) async {
    // First try to load the sample image
    final sampleImage = await loadSampleImage(task);
    if (sampleImage != null) {
      return sampleImage;
    }
    
    // Fallback to gallery picker
    final picked = await pickFromGallery();
    if (picked != null) {
      return File(picked.path);
    }
    
    return null;
  }
}