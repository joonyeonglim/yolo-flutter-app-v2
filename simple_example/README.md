# Simple YOLO Flutter Example

This simple example demonstrates the camera lifecycle management features of the YOLO Flutter plugin.

## Features Demonstrated

### Camera Lifecycle Management

The example shows how to properly manage the camera lifecycle in different scenarios:

1. **Manual Control**: Stop and resume the camera using the controller
2. **Navigation**: Automatically stop camera when navigating away and resume when returning
3. **App Lifecycle**: Automatically pause when app goes to background and resume when returning to foreground

## Key Code Examples

### Creating a Controller

```dart
final YOLOViewController controller = YOLOViewController();
```

### Stopping the Camera

```dart
// Stop camera and inference
await controller.stop();
```

### Resuming the Camera

```dart
// Resume camera and inference
await controller.resume();
```

### Handling App Lifecycle

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  switch (state) {
    case AppLifecycleState.paused:
      controller.pause();
      break;
    case AppLifecycleState.resumed:
      controller.resume();
      break;
  }
}
```

### Navigation Best Practice

```dart
// Before navigating away
await controller.stop();

// Navigate
await Navigator.push(...);

// After returning
await controller.resume();
```

## Running the Example

1. Ensure you have Flutter installed
2. Navigate to the simple_example directory
3. Run `flutter pub get`
4. Run `flutter run`

## Important Notes

- Always stop or pause the camera when it's not visible to save battery and processing power
- The camera will automatically handle permissions on both iOS and Android
- Use a controller to manage multiple camera operations