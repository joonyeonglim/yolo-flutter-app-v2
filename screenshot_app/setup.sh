#!/bin/bash

echo "Setting up YOLO Flutter Screenshot App..."

# Create platform folders if they don't exist
if [ ! -d "android" ] || [ ! -d "ios" ]; then
  echo "Creating platform folders..."
  flutter create . --platforms=android,ios
fi

# Get Flutter dependencies
echo "Installing Flutter dependencies..."
flutter pub get

# Create iOS podfile if needed
if [ -d "ios" ]; then
  echo "Setting up iOS..."
  cd ios
  pod install || echo "CocoaPods not installed or iOS setup not needed"
  cd ..
fi

# Create assets directory for Android models
echo "Creating Android assets directory..."
mkdir -p android/app/src/main/assets

# Add sample images reminder
echo ""
echo "✅ Setup complete!"
echo ""
echo "📱 For Android:"
echo "   Add YOLO TFLite models to: android/app/src/main/assets/"
echo "   - yolo11n.tflite, yolo11n-seg.tflite, etc."
echo ""
echo "📱 For iOS:"
echo "   Add YOLO CoreML models to Xcode project"
echo "   - yolo11n.mlpackage, yolo11n-seg.mlpackage, etc."
echo ""
echo "📸 Don't forget to add sample images to:"
echo "   assets/sample_images/"
echo ""
echo "Recommended images:"
echo "- street_scene.jpg (for detection)"
echo "- indoor_scene.jpg (for segmentation)" 
echo "- single_object.jpg (for classification)"
echo "- people_activity.jpg (for pose)"
echo "- aerial_view.jpg (for OBB)"
echo ""
echo "Run 'flutter run' to start the app!"