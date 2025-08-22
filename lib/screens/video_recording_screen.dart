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
    final showSettings = useState(false);
    final currentResolution = useState(ResolutionPreset.medium);
    final enableAudio = useState(true);
    final flashMode = useState(FlashMode.off);
    final cameras = useState<List<CameraDescription>>([]);
    final currentCameraIndex = useState(0);

    useEffect(() {
      _initializeCamera(cameraController, isInitialized, permissionGranted, cameras, currentCameraIndex, currentResolution, enableAudio);
      return () {
        cameraController.value?.dispose();
      };
    }, []);

    useEffect(() {
      Timer? timer;
      if (isRecording.value && !isPaused.value) {
        timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          recordingTime.value++;
          // Removed time limit - record as long as needed
        });
      }
      return () => timer?.cancel();
    }, [isRecording.value, isPaused.value]);

    if (!permissionGranted.value) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface, // Wheat background
        appBar: AppBar(
          title: const Text('Camera Permission'),
          backgroundColor: Theme.of(context).colorScheme.primary, // Wood brown
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.camera_alt_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.onSurface, // Dark wood
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
                    _initializeCamera(cameraController, isInitialized, permissionGranted, cameras, currentCameraIndex, currentResolution, enableAudio);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.onSurface, // Dark wood
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
        backgroundColor: Theme.of(context).colorScheme.surface, // Wheat background
        appBar: AppBar(
          title: const Text('VeeLog'),
          backgroundColor: Theme.of(context).colorScheme.primary, // Wood brown
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Record Video'),
        backgroundColor: Colors.black,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
                          ? 'PAUSED ${_formatTime(recordingTime.value)}'
                          : _formatTime(recordingTime.value),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Camera settings panel
          if (showSettings.value)
            Positioned(
              top: 80,
              right: 16,
              child: Container(
                width: 280,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Camera Settings',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          onPressed: () => showSettings.value = false,
                          icon: const Icon(Icons.close, color: Colors.white, size: 20),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Resolution setting
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Resolution', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        if (isRecording.value)
                          const Text('(locked)', style: TextStyle(color: Colors.orange, fontSize: 10)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      decoration: BoxDecoration(
                        color: isRecording.value 
                          ? Colors.white.withValues(alpha: 0.05) 
                          : Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<ResolutionPreset>(
                          value: currentResolution.value,
                          isExpanded: true,
                          dropdownColor: Colors.grey[800],
                          style: TextStyle(
                            color: isRecording.value ? Colors.white54 : Colors.white,
                          ),
                          items: ResolutionPreset.values.map((resolution) {
                            return DropdownMenuItem(
                              value: resolution,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(_getResolutionLabel(resolution)),
                              ),
                            );
                          }).toList(),
                          onChanged: !isRecording.value ? (value) {
                            if (value != null) {
                              currentResolution.value = value;
                              _reinitializeCamera(cameraController, isInitialized, cameras, currentCameraIndex, currentResolution, enableAudio);
                            }
                          } : null,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Audio toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text('Audio', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            if (isRecording.value)
                              const Padding(
                                padding: EdgeInsets.only(left: 8),
                                child: Text('(locked)', style: TextStyle(color: Colors.orange, fontSize: 10)),
                              ),
                          ],
                        ),
                        Switch(
                          value: enableAudio.value,
                          onChanged: !isRecording.value ? (value) {
                            enableAudio.value = value;
                            _reinitializeCamera(cameraController, isInitialized, cameras, currentCameraIndex, currentResolution, enableAudio);
                          } : null,
                          thumbColor: WidgetStateProperty.all(
                            isRecording.value ? Colors.white54 : Colors.white,
                          ),
                          inactiveThumbColor: Colors.grey,
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Flash mode
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Flash', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        IconButton(
                          onPressed: () => _toggleFlash(cameraController.value, flashMode),
                          icon: Icon(
                            flashMode.value == FlashMode.off ? Icons.flash_off :
                            flashMode.value == FlashMode.always ? Icons.flash_on :
                            Icons.flash_auto,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          
          // Top controls (available during and before recording)
          Positioned(
            top: 20,
            right: 20,
            child: Column(
              children: [
                // Settings button (always available)
                IconButton(
                  onPressed: () => showSettings.value = !showSettings.value,
                  icon: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: showSettings.value ? Colors.white.withValues(alpha: 0.8) : Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.settings,
                      color: showSettings.value ? Colors.black : Colors.white,
                    ),
                  ),
                ),
                
                // Quick flash toggle during recording
                if (isRecording.value)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: IconButton(
                      onPressed: () => _toggleFlash(cameraController.value, flashMode),
                      icon: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          flashMode.value == FlashMode.off ? Icons.flash_off :
                          flashMode.value == FlashMode.always ? Icons.flash_on :
                          Icons.flash_auto,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
              ],
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
                      showSettings.value = false; // Hide settings when starting recording
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
                  onPressed: () => _switchCamera(cameraController, isInitialized, cameras, currentCameraIndex, currentResolution, enableAudio),
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

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String _getResolutionLabel(ResolutionPreset preset) {
    switch (preset) {
      case ResolutionPreset.low:
        return 'Low (480p)';
      case ResolutionPreset.medium:
        return 'Medium (720p)';
      case ResolutionPreset.high:
        return 'High (1080p)';
      case ResolutionPreset.veryHigh:
        return 'Very High (1440p)';
      case ResolutionPreset.ultraHigh:
        return 'Ultra High (4K)';
      case ResolutionPreset.max:
        return 'Maximum';
    }
  }

  Future<void> _initializeCamera(
    ValueNotifier<CameraController?> cameraController,
    ValueNotifier<bool> isInitialized,
    ValueNotifier<bool> permissionGranted,
    ValueNotifier<List<CameraDescription>> cameras,
    ValueNotifier<int> currentCameraIndex,
    ValueNotifier<ResolutionPreset> currentResolution,
    ValueNotifier<bool> enableAudio,
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
      final availableCamerasList = await availableCameras();
      if (availableCamerasList.isEmpty) return;
      cameras.value = availableCamerasList;

      // Initialize with back camera if available, otherwise use first camera
      final backCameraIndex = availableCamerasList.indexWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
      );
      currentCameraIndex.value = backCameraIndex != -1 ? backCameraIndex : 0;

      final controller = CameraController(
        availableCamerasList[currentCameraIndex.value],
        currentResolution.value,
        enableAudio: enableAudio.value,
      );

      await controller.initialize();
      cameraController.value = controller;
      isInitialized.value = true;
    } catch (e) {
      debugPrint('Camera initialization error: $e');
    }
  }

  Future<void> _reinitializeCamera(
    ValueNotifier<CameraController?> cameraController,
    ValueNotifier<bool> isInitialized,
    ValueNotifier<List<CameraDescription>> cameras,
    ValueNotifier<int> currentCameraIndex,
    ValueNotifier<ResolutionPreset> currentResolution,
    ValueNotifier<bool> enableAudio,
  ) async {
    final currentController = cameraController.value;
    if (currentController != null) {
      await currentController.dispose();
    }
    
    isInitialized.value = false;
    
    try {
      final controller = CameraController(
        cameras.value[currentCameraIndex.value],
        currentResolution.value,
        enableAudio: enableAudio.value,
      );

      await controller.initialize();
      cameraController.value = controller;
      isInitialized.value = true;
    } catch (e) {
      debugPrint('Camera reinitialization error: $e');
    }
  }

  Future<void> _toggleFlash(
    CameraController? controller,
    ValueNotifier<FlashMode> flashMode,
  ) async {
    if (controller == null || !controller.value.isInitialized) return;

    try {
      FlashMode newMode;
      switch (flashMode.value) {
        case FlashMode.off:
          newMode = FlashMode.always;
          break;
        case FlashMode.always:
          newMode = FlashMode.auto;
          break;
        case FlashMode.auto:
        case FlashMode.torch:
          newMode = FlashMode.off;
          break;
      }
      
      await controller.setFlashMode(newMode);
      flashMode.value = newMode;
    } catch (e) {
      debugPrint('Error toggling flash: $e');
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
    ValueNotifier<List<CameraDescription>> cameras,
    ValueNotifier<int> currentCameraIndex,
    ValueNotifier<ResolutionPreset> currentResolution,
    ValueNotifier<bool> enableAudio,
  ) async {
    final currentController = cameraController.value;
    if (currentController == null || cameras.value.length < 2) return;

    try {
      await currentController.dispose();
      isInitialized.value = false;
      
      // Switch to next camera
      currentCameraIndex.value = (currentCameraIndex.value + 1) % cameras.value.length;
      
      final newController = CameraController(
        cameras.value[currentCameraIndex.value],
        currentResolution.value,
        enableAudio: enableAudio.value,
      );

      await newController.initialize();
      cameraController.value = newController;
      isInitialized.value = true;
    } catch (e) {
      debugPrint('Error switching camera: $e');
    }
  }
}