# YOLO Flutter Screenshot App

A specialized Flutter application for generating high-quality screenshots that simulate real-time YOLO inference for marketing and documentation purposes.

## Purpose

This app creates professional screenshots that appear to show live camera inference but actually use pre-selected images. This approach ensures:
- Consistent, high-quality screenshots
- Perfect framing and lighting
- Reliable demonstration of all YOLO features
- Easy generation of marketing materials

## Features

- Mock camera UI that matches the real app exactly
- Support for all YOLO tasks (detect, segment, classify, pose, OBB)
- Photo library integration for custom images
- Pre-loaded sample images optimized for each task
- Realistic FPS counter and performance metrics
- Layered UI design for authentic appearance

## Quick Start

1. Install dependencies:
   ```bash
   flutter pub get
   ```

2. Run the app:
   ```bash
   flutter run
   ```

3. Generate screenshots:
   - Tap the screen to select an image
   - Choose a YOLO task from the selector
   - Wait for inference to complete
   - Take a screenshot using your device's screenshot function

## Architecture

The app uses a layered approach:
1. **Background Layer**: Annotated image from YOLO inference
2. **UI Layer**: Mock camera controls and displays
3. **Overlay Effects**: Subtle blur and opacity for realism

## Sample Images

The app includes pre-selected images optimized for each task:
- Detection: Street scenes with multiple objects
- Segmentation: Complex indoor environments
- Classification: Clear single-object images
- Pose: People in various activities
- OBB: Aerial views with oriented objects

## Tips for Best Screenshots

1. Use high-quality source images (1080p or higher)
2. Ensure good lighting and contrast in source images
3. Frame subjects appropriately for each task
4. Let the inference complete before taking screenshot
5. Use device's native screenshot function for best quality

## Development

See `docs/implementation_strategy.md` for detailed technical documentation.