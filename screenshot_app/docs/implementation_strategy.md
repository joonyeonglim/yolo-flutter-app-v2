# Screenshot App Implementation Strategy

## Overview
A specialized Flutter app designed to create high-quality screenshots that simulate real-time YOLO inference. The app displays a mock camera UI with actual inference results from selected photos, creating the appearance of live detection for marketing materials.

## Purpose
- Generate professional screenshots for pub.dev and GitHub
- Overcome limitations of capturing real-time camera feeds
- Ensure consistent, high-quality visual demonstrations
- Support all YOLO tasks (detect, segment, classify, pose, obb)

## Architecture

### 1. App Structure
```
screenshot_app/
├── lib/
│   ├── main.dart
│   ├── screens/
│   │   └── mock_camera_screen.dart
│   ├── widgets/
│   │   ├── mock_camera_ui.dart
│   │   ├── task_selector.dart
│   │   └── result_overlay.dart
│   ├── services/
│   │   ├── photo_picker_service.dart
│   │   └── inference_service.dart
│   └── models/
│       └── screenshot_config.dart
├── assets/
│   ├── sample_images/
│   └── mock_ui_elements/
├── pubspec.yaml
└── README.md
```

### 2. Core Components

#### MockCameraScreen
- Main screen that mimics the real camera interface
- Layered structure:
  1. Background: Annotated image from inference
  2. Middle: Semi-transparent overlay for depth
  3. Foreground: Mock UI elements (buttons, labels, FPS counter)

#### PhotoPickerService
- Handles image selection from photo library
- Provides image preprocessing for optimal inference
- Supports both gallery and pre-loaded sample images

#### InferenceService
- Wrapper around the ultralytics_yolo plugin
- Manages single image inference
- Returns annotated images for display

#### MockCameraUI
- Replicates the exact UI from the real camera app
- Includes:
  - Task selection buttons
  - Model name display
  - FPS counter (shows realistic values)
  - Confidence/IoU sliders
  - Camera switch button (non-functional)

### 3. User Flow

1. **Launch App**
   - Display mock camera UI with placeholder background
   - Show default task (detection) selected

2. **Image Selection**
   - Tap anywhere on screen (except UI buttons)
   - Opens photo picker
   - User selects image

3. **Inference Process**
   - Show loading indicator
   - Run inference with selected task
   - Receive annotated image

4. **Display Result**
   - Place annotated image as background
   - Apply slight blur/darkening for realism
   - Update FPS counter to realistic value (e.g., 28.5 FPS)
   - Show detection count or classification results

5. **Task Switching**
   - User can switch tasks
   - Re-run inference on same image
   - Update UI to reflect new task

### 4. Visual Design

#### Layer Composition
```
┌─────────────────────────┐
│  Status Bar (Native)    │
├─────────────────────────┤
│  ┌───────┐ ┌─────────┐  │ <- Mock UI Layer
│  │ Model │ │ 28.5FPS │  │    (Foreground)
│  └───────┘ └─────────┘  │
│                         │
│  [Annotated Image]      │ <- Inference Result
│                         │    (Background)
│  ┌─────────────────┐   │
│  │ Task Selector   │   │ <- Mock UI Layer
│  └─────────────────┘   │    (Foreground)
├─────────────────────────┤
│  Navigation Bar        │
└─────────────────────────┘
```

#### Styling Guidelines
- Match exact colors from real app
- Use same fonts and sizes
- Maintain consistent spacing
- Add subtle shadows for depth

### 5. Technical Implementation

#### State Management
```dart
class ScreenshotState {
  final YOLOTask selectedTask;
  final String? selectedImagePath;
  final Uint8List? annotatedImage;
  final bool isProcessing;
  final double mockFps;
  final int detectionCount;
}
```

#### Image Processing Pipeline
1. Load selected image
2. Resize to optimal dimensions
3. Run YOLO inference
4. Receive annotated result
5. Apply post-processing effects
6. Display with mock UI overlay

#### Mock Data Generation
- FPS: Random between 25-30 with decimals
- Processing time: Calculated from mock FPS
- Detection counts: From actual inference
- Confidence values: From actual inference

### 6. Sample Images Strategy

Include pre-loaded images optimized for each task:
- **Detection**: Street scene with people and vehicles
- **Segmentation**: Indoor scene with multiple objects
- **Classification**: Clear single object (dog, cat, etc.)
- **Pose**: People doing sports/activities
- **OBB**: Aerial view with oriented objects

### 7. Implementation Phases

#### Phase 1: Basic Structure
- Create Flutter app structure
- Set up dependencies
- Implement basic mock UI

#### Phase 2: Photo Selection
- Integrate image_picker
- Add sample images
- Implement image loading

#### Phase 3: Inference Integration
- Connect ultralytics_yolo plugin
- Implement inference service
- Handle all task types

#### Phase 4: UI Polish
- Match exact camera app styling
- Add animations and transitions
- Implement loading states

#### Phase 5: Screenshot Optimization
- Test with various images
- Fine-tune visual effects
- Create screenshot presets

### 8. Configuration Options

```dart
class ScreenshotConfig {
  // Visual settings
  final double backgroundOpacity = 0.9;
  final double blurRadius = 0.5;
  
  // Mock data ranges
  final double minFps = 25.0;
  final double maxFps = 30.0;
  
  // UI settings
  final bool showConfidenceSlider = true;
  final bool showIouSlider = true;
  final bool showModelSelector = true;
}
```

### 9. Testing Strategy

- Test with various image sizes
- Verify all task types work correctly
- Ensure UI matches real app exactly
- Test on different screen sizes
- Validate screenshot quality

### 10. Future Enhancements

- Video frame extraction for more realistic results
- Preset scenes for common use cases
- Batch screenshot generation
- Export with different backgrounds
- Automated screenshot capture for all tasks

## Success Criteria

1. Screenshots are indistinguishable from real camera feed
2. All YOLO tasks produce high-quality results
3. UI perfectly matches the actual camera app
4. Easy to generate multiple screenshots quickly
5. Results suitable for marketing materials

## Notes

- Keep the implementation simple and focused
- Prioritize visual quality over functionality
- Ensure consistent results across platforms
- Document screenshot creation process