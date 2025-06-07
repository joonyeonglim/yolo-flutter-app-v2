import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

/// Example demonstrating camera lifecycle management with YOLOView
/// This shows how to properly stop/pause/resume camera and inference
/// when navigating between screens
class CameraViewLifecycleExample extends StatefulWidget {
  const CameraViewLifecycleExample({super.key});

  @override
  State<CameraViewLifecycleExample> createState() => _CameraViewLifecycleExampleState();
}

class _CameraViewLifecycleExampleState extends State<CameraViewLifecycleExample> 
    with WidgetsBindingObserver {
  static const String modelPath = 'yolo11n';
  
  // Controller to manage camera lifecycle
  final YOLOViewController controller = YOLOViewController();
  
  // Track if camera is currently active
  bool isCameraActive = true;
  
  // Track detection count
  int detectionCount = 0;
  
  @override
  void initState() {
    super.initState();
    // Add observer to handle app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
  }
  
  @override
  void dispose() {
    // Remove observer
    WidgetsBinding.instance.removeObserver(this);
    // Stop camera when disposing
    controller.stop();
    super.dispose();
  }
  
  // Handle app lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
        // App is in background - pause camera
        debugPrint('App paused - pausing camera');
        controller.pause();
        break;
      case AppLifecycleState.resumed:
        // App is back in foreground - resume camera if it was active
        if (isCameraActive) {
          debugPrint('App resumed - resuming camera');
          controller.resume();
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // Handle other states if needed
        break;
    }
  }
  
  void _toggleCamera() {
    setState(() {
      if (isCameraActive) {
        controller.stop();
        isCameraActive = false;
      } else {
        controller.resume();
        isCameraActive = true;
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera Lifecycle Example'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Switch camera button
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: isCameraActive ? () => controller.switchCamera() : null,
            tooltip: 'Switch Camera',
          ),
        ],
      ),
      body: Column(
        children: [
          // Camera view
          Expanded(
            child: Stack(
              children: [
                if (isCameraActive)
                  YOLOView(
                    modelPath: modelPath,
                    task: YOLOTask.detect,
                    controller: controller,
                    onResult: (results) {
                      setState(() {
                        detectionCount++;
                      });
                      debugPrint('Detected ${results.length} objects');
                    },
                  )
                else
                  Container(
                    color: Colors.black,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.videocam_off,
                            size: 64,
                            color: Colors.white54,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Camera Stopped',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Detection count overlay
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Detections: $detectionCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Control buttons
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Camera control button
                ElevatedButton.icon(
                  onPressed: _toggleCamera,
                  icon: Icon(isCameraActive ? Icons.stop : Icons.play_arrow),
                  label: Text(isCameraActive ? 'Stop Camera' : 'Start Camera'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Navigation example
                ElevatedButton.icon(
                  onPressed: () async {
                    // Stop camera before navigating
                    controller.stop();
                    
                    // Navigate to another page
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SecondPage(),
                      ),
                    );
                    
                    // Resume camera when returning if it was active
                    if (isCameraActive) {
                      controller.resume();
                    }
                  },
                  icon: const Icon(Icons.navigate_next),
                  label: const Text('Navigate to Another Page'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Instructions
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Camera Lifecycle Management:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text('• Camera stops when navigating away'),
                        Text('• Camera pauses when app goes to background'),
                        Text('• Camera resumes when app returns to foreground'),
                        Text('• Use Stop/Start button to manually control'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple second page to demonstrate navigation
class SecondPage extends StatelessWidget {
  const SecondPage({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Second Page'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              size: 64,
              color: Colors.green,
            ),
            SizedBox(height: 16),
            Text(
              'Camera was stopped when navigating here',
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'It will resume when you go back',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}