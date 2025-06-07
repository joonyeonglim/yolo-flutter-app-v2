// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/yolo_result.dart';
import 'package:ultralytics_yolo/yolo_view.dart';
import 'package:ultralytics_yolo/yolo_task.dart';
import 'package:ultralytics_yolo/yolo.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'video_gallery_screen.dart';
import 'package:share_plus/share_plus.dart';

/// A screen that demonstrates real-time YOLO classification using the device camera.
///
/// This screen provides:
/// - Live camera feed with YOLO image classification
/// - Adjustable confidence threshold
/// - Camera controls (flip, zoom)
/// - Performance metrics (FPS)
/// - Top-N classification results display
class CameraInferenceScreen extends StatefulWidget {
  const CameraInferenceScreen({super.key});

  @override
  State<CameraInferenceScreen> createState() => _CameraInferenceScreenState();
}

class _CameraInferenceScreenState extends State<CameraInferenceScreen> {
  List<YOLOResult> _classificationResults = [];
  double _confidenceThreshold = 0.1;
  double _currentFps = 0.0;
  int _frameCount = 0;
  DateTime _lastFpsUpdate = DateTime.now();

  bool _showConfidenceSlider = false;
  bool _isModelLoading = false;
  String? _modelPath;
  String _loadingMessage = '';
  double _currentZoomLevel = 1.0;
  bool _isFrontCamera = false;

  // Recording 관련 변수들
  bool _isRecording = false;
  bool _isProcessingRecording = false;
  String? _recordingPath;
  bool _isCameraReady = false; // 카메라 준비 상태

  final _yoloController = YOLOViewController();
  final _yoloViewKey = GlobalKey<YOLOViewState>();
  final bool _useController = true;

  // 고정된 모델 경로 - best-n-320-20250501 사용
  static const String _fixedModelPath = 'best-n-320-20250501';

  @override
  void initState() {
    super.initState();
    
    // 초기 상태 명시적으로 설정
    _isRecording = false;
    _isProcessingRecording = false;
    _isCameraReady = false;
    
    _loadModel();

    // Set initial threshold after frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_useController) {
        _yoloController.setThresholds(
          confidenceThreshold: _confidenceThreshold,
          iouThreshold: 0.45, // IoU는 classification에서 사용되지 않지만 기본값 설정
          numItemsThreshold: 30,
        );
      } else {
        _yoloViewKey.currentState?.setThresholds(
          confidenceThreshold: _confidenceThreshold,
          iouThreshold: 0.45,
          numItemsThreshold: 30,
        );
      }
    });

    // 주기적으로 녹화 상태 동기화 (5초마다로 조정)
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _syncRecordingState();
    });
  }

  /// 녹화 상태를 주기적으로 동기화
  Future<void> _syncRecordingState() async {
    if (_isProcessingRecording) return;
    
    try {
      final actualState = await _yoloController.isRecording();
      if (mounted && _isRecording != actualState) {
        print('[YOLO DEBUG] 🔄 상태 동기화: UI($_isRecording) → Native($actualState)');
        setState(() {
          _isRecording = actualState;
        });
      }
    } catch (e) {
      // 상태 확인 실패 시 조용히 처리
      print('[YOLO DEBUG] ⚠️ 상태 동기화 실패: $e');
    }
  }

  /// Called when new classification results are available
  void _onClassificationResults(List<YOLOResult> results) {
    if (!mounted) return;

    _frameCount++;
    final now = DateTime.now();
    final elapsed = now.difference(_lastFpsUpdate).inMilliseconds;

    if (elapsed >= 1000) {
      final calculatedFps = _frameCount * 1000 / elapsed;
      _currentFps = calculatedFps;
      _frameCount = 0;
      _lastFpsUpdate = now;
    }

    // Filter and sort results
    final filteredResults = results
        .where((r) => r.confidence >= _confidenceThreshold)
        .toList();
    
    // Sort by confidence (highest first)
    filteredResults.sort((a, b) => b.confidence.compareTo(a.confidence));

    setState(() {
      _classificationResults = filteredResults.take(5).toList(); // Top 5 results
    });
  }

  /// Recording 시작/중지 (네이티브 상태 기반)
  Future<void> _toggleRecording() async {
    // 중복 요청 및 카메라 미준비 상태 방지
    if (_isProcessingRecording || !_isCameraReady) {
      print('[YOLO DEBUG] 녹화 토글 무시: 처리 중($_isProcessingRecording) 또는 카메라 미준비(!$_isCameraReady)');
      return;
    }
    
    setState(() {
      _isProcessingRecording = true;
    });

    try {
      print('[YOLO DEBUG] === 녹화 토글 시작 ===');
      
      // 네이티브에서 실제 녹화 상태 확인
      print('[YOLO DEBUG] 🔍 네이티브 상태 확인 시작');
      final isCurrentlyRecording = await _yoloController.isRecording();
      print('[YOLO DEBUG] 🔍 네이티브 녹화 상태: $isCurrentlyRecording');
      print('[YOLO DEBUG] 🔍 현재 UI 상태: $_isRecording');
      print('[YOLO DEBUG] 🔍 _isProcessingRecording: $_isProcessingRecording');
      print('[YOLO DEBUG] 🔍 _isCameraReady: $_isCameraReady');
      
      if (isCurrentlyRecording) {
        // 녹화 중지
        print('[YOLO DEBUG] 🛑 녹화 중지 시도');
        print('[YOLO DEBUG] 🛑 stopRecording 호출 전');
        final videoPath = await _yoloController.stopRecording();
        print('[YOLO DEBUG] 🛑 stopRecording 호출 후');
        print('[YOLO DEBUG] 🛑 녹화 중지 완료: $videoPath');
        
        if(mounted) {
          setState(() {
            _isRecording = false;
            _recordingPath = videoPath;
          });
        }
        
        // Android에서 SharedPreferences에 비디오 경로 저장
        if (Platform.isAndroid && videoPath != null) {
          final prefs = await SharedPreferences.getInstance();
          final List<String> videoPaths = prefs.getStringList('recorded_videos') ?? [];
          if (!videoPaths.contains(videoPath)) {
            videoPaths.add(videoPath);
            await prefs.setStringList('recorded_videos', videoPaths);
          }
        }
        
        // 녹화 완료 - 팝업 없이 조용히 처리
      } else {
        // 녹화 시작
        print('[YOLO DEBUG] ▶️ 녹화 시작 시도');
        final videoPath = await _yoloController.startRecording();
        print('[YOLO DEBUG] ▶️ 녹화 시작 완료: $videoPath');
        
        // 녹화 시작 후 네이티브 상태 재확인
        await Future.delayed(const Duration(milliseconds: 500));
        final recordingStateAfterStart = await _yoloController.isRecording();
        print('[YOLO DEBUG] ▶️ 녹화 시작 후 네이티브 상태: $recordingStateAfterStart');
        
        if (mounted) {
          setState(() {
            _isRecording = recordingStateAfterStart; // 실제 네이티브 상태로 설정
            _recordingPath = videoPath;
          });
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('녹화 시작됨'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('[YOLO DEBUG] ❌ 녹화 토글 오류: $e');
      
      // 오류 발생 시 네이티브 상태로 Flutter 상태 동기화
      try {
        final actualState = await _yoloController.isRecording();
        if(mounted) {
          setState(() {
            _isRecording = actualState;
          });
        }
        print('[YOLO DEBUG] 상태 동기화 완료: $_isRecording');
      } catch (syncError) {
        print('[YOLO DEBUG] 상태 동기화 실패: $syncError');
        if (mounted) {
          setState(() {
            _isRecording = false;
          });
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('녹화 오류: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      print('[YOLO DEBUG] === 녹화 토글 완료 ===');
      if (mounted) {
        setState(() {
          _isProcessingRecording = false;
        });
      }
    }
  }

  /// 녹화된 비디오 공유
  void _shareRecording(String path) {
    try {
      Share.shareXFiles([XFile(path)], text: 'YOLO 새 분류 영상');
    } catch (e) {
      print('Sharing video failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // YOLO View
          if (_modelPath != null && !_isModelLoading)
            YOLOView(
              key: _useController
                  ? const ValueKey('yolo_view_static')
                  : _yoloViewKey,
              controller: _useController ? _yoloController : null,
              modelPath: _modelPath!,
              task: YOLOTask.classify, // Classification task
              onResult: _onClassificationResults,
              onPerformanceMetrics: (metrics) {
                if (mounted) {
                  setState(() {
                    _currentFps = metrics.fps;
                  });
                }
              },
              onZoomChanged: (zoomLevel) {
                if (mounted) {
                  setState(() {
                    _currentZoomLevel = zoomLevel;
                  });
                }
              },
            )
          else if (_isModelLoading)
            IgnorePointer(
              child: Container(
                color: Colors.black87,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Ultralytics logo
                      Image.asset(
                        'assets/logo.png',
                        width: 120,
                        height: 120,
                        color: Colors.white.withOpacity(0.8),
                      ),
                      const SizedBox(height: 32),
                      // Loading message
                      Text(
                        _loadingMessage,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      const CircularProgressIndicator(color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),

          // Top info (FPS and confidence threshold)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Title with recording indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isRecording) ...[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          const Text(
                            'BIRD CLASSIFICATION',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (_isRecording) ...[
                            const SizedBox(width: 8),
                            const Text(
                              'REC',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                IgnorePointer(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'FPS: ${_currentFps.toStringAsFixed(1)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'THRESHOLD: ${_confidenceThreshold.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Classification results display
          if (_classificationResults.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 120,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOP PREDICTIONS',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._classificationResults.map((result) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              result.className ?? 'Unknown',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Row(
                              children: [
                                Expanded(
                                  child: LinearProgressIndicator(
                                    value: result.confidence,
                                    backgroundColor: Colors.white24,
                                    valueColor: const AlwaysStoppedAnimation<Color>(
                                      Colors.yellow,
                                    ),
                                    minHeight: 3,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${(result.confidence * 100).toInt()}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ),

          // Center logo - only show when camera is active
          if (_modelPath != null && !_isModelLoading)
            Positioned.fill(
              child: IgnorePointer(
                child: Align(
                  alignment: Alignment.center,
                  child: FractionallySizedBox(
                    widthFactor: 0.5,
                    heightFactor: 0.5,
                    child: Image.asset(
                      'assets/logo.png',
                      color: Colors.white.withOpacity(0.2),
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
                // Recording button
                _buildIconButton(
                  _isProcessingRecording || !_isCameraReady
                    ? Icons.hourglass_empty 
                    : (_isRecording ? Icons.stop : Icons.videocam),
                  _isProcessingRecording || !_isCameraReady ? () {} : _toggleRecording,
                  backgroundColor: _isRecording 
                    ? Colors.red 
                    : (_isProcessingRecording || !_isCameraReady
                      ? Colors.orange 
                      : Colors.black.withOpacity(0.5)),
                  iconColor: Colors.white,
                ),
                const SizedBox(height: 12),
                
                if (!_isFrontCamera) ...[
                  _buildCircleButton(
                    '${_currentZoomLevel.toStringAsFixed(1)}x',
                    onPressed: () {
                      // Cycle through zoom levels: 0.5x -> 1.0x -> 3.0x -> 0.5x
                      double nextZoom;
                      if (_currentZoomLevel < 0.75) {
                        nextZoom = 1.0;
                      } else if (_currentZoomLevel < 2.0) {
                        nextZoom = 3.0;
                      } else {
                        nextZoom = 0.5;
                      }
                      _setZoomLevel(nextZoom);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                _buildIconButton(Icons.tune, () {
                  setState(() {
                    _showConfidenceSlider = !_showConfidenceSlider;
                  });
                }),
                const SizedBox(height: 40),
              ],
            ),
          ),

          // Bottom confidence slider overlay
          if (_showConfidenceSlider)
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'CONFIDENCE THRESHOLD: ${_confidenceThreshold.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: Colors.yellow,
                        inactiveTrackColor: Colors.white.withOpacity(0.3),
                        thumbColor: Colors.yellow,
                        overlayColor: Colors.yellow.withOpacity(0.2),
                      ),
                      child: Slider(
                        value: _confidenceThreshold,
                        min: 0.1,
                        max: 0.9,
                        divisions: 8,
                        label: _confidenceThreshold.toStringAsFixed(1),
                        onChanged: (value) {
                          setState(() {
                            _confidenceThreshold = value;
                          });
                          if (_useController) {
                            _yoloController.setConfidenceThreshold(value);
                          } else {
                            _yoloViewKey.currentState?.setConfidenceThreshold(value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom left buttons
          Positioned(
            bottom: 32,
            left: 16,
            child: Column(
              children: [
                // Gallery button
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.black.withOpacity(0.5),
                  child: IconButton(
                    icon: const Icon(Icons.video_library, color: Colors.white),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const VideoGalleryScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                // Camera flip button
                CircleAvatar(
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
                      if (_useController) {
                        _yoloController.switchCamera();
                      } else {
                        _yoloViewKey.currentState?.switchCamera();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(
    IconData icon, 
    VoidCallback onPressed, {
    Color? backgroundColor,
    Color? iconColor,
  }) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: backgroundColor ?? Colors.black.withOpacity(0.2),
      child: IconButton(
        icon: Icon(icon, color: iconColor ?? Colors.white),
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
        child: Text(label, style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  void _setZoomLevel(double zoomLevel) {
    setState(() {
      _currentZoomLevel = zoomLevel;
    });
    if (_useController) {
      _yoloController.setZoomLevel(zoomLevel);
    } else {
      _yoloViewKey.currentState?.setZoomLevel(zoomLevel);
    }
  }

  Future<void> _loadModel() async {
    setState(() {
      _isModelLoading = true;
      _loadingMessage = 'Loading bird classification model...';
    });

    try {
      // 모델 경로 설정
      setState(() {
        _modelPath = _fixedModelPath;
        _isModelLoading = false;
        _loadingMessage = '';
      });

      // Warm up camera after model is loaded and view is likely built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _warmUpCamera();
      });

    } catch (e) {
      debugPrint('Error loading model: $e');
      if (mounted) {
        setState(() {
          _isModelLoading = false;
          _loadingMessage = 'Failed to load model';
        });
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Model Loading Error'),
            content: Text('Failed to load bird classification model: ${e.toString()}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _warmUpCamera() async {
    // 카메라 준비 상태만 확인하고 실제 녹화는 하지 않음
    if (!mounted || _isCameraReady) return;
    
    try {
      print('[YOLO DEBUG] 📸 Camera 준비 중...');
      // 뷰가 완전히 초기화될 때까지 대기
      await Future.delayed(const Duration(milliseconds: 1000));
      
      // 실제 녹화 상태 확인만 수행 (녹화 시작/중지 없음)
      final isCurrentlyRecording = await _yoloController.isRecording();
      print('[YOLO DEBUG] 📸 현재 녹화 상태: $isCurrentlyRecording');
      
      if (mounted) {
        setState(() {
          _isCameraReady = true;
          _isRecording = isCurrentlyRecording; // 실제 상태로 동기화
        });
      }
      
      print('[YOLO DEBUG] 📸 Camera 준비 완료');
    } catch (e) {
      print('[YOLO DEBUG] ⚠️ Camera 준비 실패: $e');
      if (mounted) {
        setState(() {
          _isCameraReady = true;
          _isRecording = false; // 오류 시 안전하게 false로 설정
        });
      }
    }
  }
}
