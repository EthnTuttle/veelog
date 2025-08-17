import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:go_router/go_router.dart';

class VideoRecordingScreen extends HookConsumerWidget {
  const VideoRecordingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cameraController = useState<CameraController?>(null);
    final isRecording = useState(false);
    final isPaused = useState(false);
    final recordingTime = useState(0);
    final isInitialized = useState(false);
    final permissionGranted = useState(false);

    useEffect(() {
      _initializeCamera(cameraController, isInitialized, permissionGranted);
      return () {
        cameraController.value?.dispose();
      };
    }, []);

    useEffect(() {
      Timer? timer;
      if (isRecording.value && !isPaused.value) {
        timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          recordingTime.value++;
          if (recordingTime.value >= 30) { // Reduced from 60 to 30 seconds
            _stopRecording(cameraController.value, isRecording, isPaused, recordingTime, context);
            timer.cancel();
          }
        });
      }
      return () => timer?.cancel();
    }, [isRecording.value, isPaused.value]);

    if (!permissionGranted.value) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5DEB3), // Wheat background
        appBar: AppBar(
          title: const Text('Camera Permission'),
          backgroundColor: const Color(0xFF8B4513), // Wood brown
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.camera_alt_outlined,
                size: 64,
                color: const Color(0xFF654321), // Dark wood
              ),
              const SizedBox(height: 24),
              Text(
                'Camera Access Required',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Text(
                'This app needs camera access to record videos',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () async {
                  final status = await Permission.camera.request();
                  if (status.isGranted) {
                    permissionGranted.value = true;
                    _initializeCamera(cameraController, isInitialized, permissionGranted);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF654321), // Dark wood
                  foregroundColor: Colors.white,
                ),
                child: const Text('Grant Permission'),
              ),
            ],
          ),
        ),
      );
    }

    if (!isInitialized.value || cameraController.value == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5DEB3), // Wheat background
        appBar: AppBar(
          title: const Text('VeeLog'),
          backgroundColor: const Color(0xFF8B4513), // Wood brown
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Record Video'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          // Camera preview
          Positioned.fill(
            child: CameraPreview(cameraController.value!),
          ),
          
          // Recording timer
          if (isRecording.value)
            Positioned(
              top: 20,
              left: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isPaused.value ? Colors.orange : Colors.red,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isPaused.value 
                          ? 'PAUSED ${recordingTime.value}s / 30s'
                          : '${recordingTime.value}s / 30s',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Recording controls
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Pause/Resume button (only visible when recording)
                if (isRecording.value)
                  IconButton(
                    onPressed: () {
                      if (isPaused.value) {
                        _resumeRecording(cameraController.value, isPaused);
                      } else {
                        _pauseRecording(cameraController.value, isPaused);
                      }
                    },
                    icon: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isPaused.value ? Icons.play_arrow : Icons.pause,
                        color: Colors.white,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 48), // Placeholder to maintain spacing
                
                // Record button
                GestureDetector(
                  onTap: () {
                    if (isRecording.value) {
                      _stopRecording(cameraController.value, isRecording, isPaused, recordingTime, context);
                    } else {
                      _startRecording(cameraController.value, isRecording, isPaused);
                    }
                  },
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isRecording.value ? Colors.red : Colors.white,
                      border: Border.all(
                        color: Colors.white,
                        width: 4,
                      ),
                    ),
                    child: isRecording.value
                        ? const Icon(
                            Icons.stop,
                            color: Colors.white,
                            size: 32,
                          )
                        : Container(
                            margin: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.red,
                            ),
                          ),
                  ),
                ),
                
                // Switch camera button
                IconButton(
                  onPressed: () => _switchCamera(cameraController, isInitialized),
                  icon: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.flip_camera_ios,
                      color: Colors.white,
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

  Future<void> _initializeCamera(
    ValueNotifier<CameraController?> cameraController,
    ValueNotifier<bool> isInitialized,
    ValueNotifier<bool> permissionGranted,
  ) async {
    try {
      // Check permission first
      final status = await Permission.camera.status;
      if (!status.isGranted) {
        permissionGranted.value = false;
        return;
      }
      permissionGranted.value = true;

      // Get available cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      // Initialize with back camera if available, otherwise use first camera
      final camera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        camera,
        ResolutionPreset.medium, // Back to medium quality with compression
        enableAudio: true,
      );

      await controller.initialize();
      cameraController.value = controller;
      isInitialized.value = true;
    } catch (e) {
      debugPrint('Camera initialization error: $e');
    }
  }

  Future<void> _startRecording(
    CameraController? controller,
    ValueNotifier<bool> isRecording,
    ValueNotifier<bool> isPaused,
  ) async {
    if (controller == null || !controller.value.isInitialized) return;

    try {
      await controller.startVideoRecording();
      isRecording.value = true;
      isPaused.value = false;
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _pauseRecording(
    CameraController? controller,
    ValueNotifier<bool> isPaused,
  ) async {
    if (controller == null || !controller.value.isRecordingVideo) return;

    try {
      await controller.pauseVideoRecording();
      isPaused.value = true;
    } catch (e) {
      debugPrint('Error pausing recording: $e');
    }
  }

  Future<void> _resumeRecording(
    CameraController? controller,
    ValueNotifier<bool> isPaused,
  ) async {
    if (controller == null || !controller.value.isRecordingPaused) return;

    try {
      await controller.resumeVideoRecording();
      isPaused.value = false;
    } catch (e) {
      debugPrint('Error resuming recording: $e');
    }
  }

  Future<void> _stopRecording(
    CameraController? controller,
    ValueNotifier<bool> isRecording,
    ValueNotifier<bool> isPaused,
    ValueNotifier<int> recordingTime,
    BuildContext context,
  ) async {
    if (controller == null || !isRecording.value) return;

    try {
      final videoFile = await controller.stopVideoRecording();
      isRecording.value = false;
      isPaused.value = false;
      recordingTime.value = 0;
      
      // Navigate to video preview screen
      if (context.mounted) {
        context.push('/video-preview', extra: videoFile.path);
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }
  }

  Future<void> _switchCamera(
    ValueNotifier<CameraController?> cameraController,
    ValueNotifier<bool> isInitialized,
  ) async {
    final currentController = cameraController.value;
    if (currentController == null) return;

    try {
      final cameras = await availableCameras();
      if (cameras.length < 2) return;

      final currentDirection = currentController.description.lensDirection;
      final newCamera = cameras.firstWhere(
        (camera) => camera.lensDirection != currentDirection,
        orElse: () => cameras.first,
      );

      await currentController.dispose();
      
      final newController = CameraController(
        newCamera,
        ResolutionPreset.medium, // Back to medium quality with compression
        enableAudio: true,
      );

      await newController.initialize();
      cameraController.value = newController;
    } catch (e) {
      debugPrint('Error switching camera: $e');
    }
  }
}