import 'dart:io';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:async_button_builder/async_button_builder.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:video_compress/video_compress.dart';
import 'package:veelog/services/blossom_service.dart';

class VideoPreviewScreen extends HookConsumerWidget {
  final String videoPath;

  const VideoPreviewScreen({
    super.key,
    required this.videoPath,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoPlayerController = useState<VideoPlayerController?>(null);
    final chewieController = useState<ChewieController?>(null);
    final isInitialized = useState(false);

    useEffect(() {
      _initializeVideo(videoPath, videoPlayerController, chewieController, isInitialized);
      return () {
        chewieController.value?.dispose();
        videoPlayerController.value?.dispose();
      };
    }, [videoPath]);

    if (!isInitialized.value || chewieController.value == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('Video Preview'),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Video Preview'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Video player
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: videoPlayerController.value!.value.aspectRatio,
                child: Chewie(controller: chewieController.value!),
              ),
            ),
          ),
          
          // Action buttons
          Container(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                // Discard button
                Expanded(
                  child: AsyncButtonBuilder(
                    onPressed: () async {
                      await _discardVideo(videoPath);
                      if (context.mounted) {
                        context.pop();
                      }
                    },
                    child: const Text('Discard'),
                    builder: (context, child, callback, buttonState) {
                      return OutlinedButton(
                        onPressed: callback,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white),
                        ),
                        child: buttonState.when(
                          idle: () => child,
                          loading: () => const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          success: () => const Text('Discarded'),
                          error: (error, stackTrace) => const Text('Error'),
                        ),
                      );
                    },
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Save button
                Expanded(
                  child: AsyncButtonBuilder(
                    onPressed: () async {
                      await _saveVideo(videoPath, context, ref);
                    },
                    child: const Text('Save & Post'),
                    builder: (context, child, callback, buttonState) {
                      return ElevatedButton(
                        onPressed: callback,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: buttonState.when(
                          idle: () => child,
                          loading: () => const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Processing...', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                          success: () => const Text('Posted!'),
                          error: (error, stackTrace) => const Text('Upload Failed'),
                        ),
                      );
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

  Future<void> _initializeVideo(
    String videoPath,
    ValueNotifier<VideoPlayerController?> videoController,
    ValueNotifier<ChewieController?> chewieController,
    ValueNotifier<bool> isInitialized,
  ) async {
    try {
      final controller = VideoPlayerController.file(File(videoPath));
      await controller.initialize();
      
      final chewie = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: true,
        showControls: true,
        aspectRatio: controller.value.aspectRatio,
      );

      videoController.value = controller;
      chewieController.value = chewie;
      isInitialized.value = true;
    } catch (e) {
      debugPrint('Error initializing video: $e');
    }
  }

  Future<void> _discardVideo(String videoPath) async {
    try {
      final file = File(videoPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting video: $e');
    }
  }

  Future<void> _saveVideo(String videoPath, BuildContext context, WidgetRef ref) async {
    try {
      // Show dialog to get video description
      final description = await _showDescriptionDialog(context);
      if (description == null) return; // User cancelled
      
      // Compress video before uploading
      debugPrint('Compressing video...');
      final compressedInfo = await VideoCompress.compressVideo(
        videoPath,
        quality: VideoQuality.LowQuality,
        deleteOrigin: false, // Keep original for now
        includeAudio: true,
      );
      
      if (compressedInfo == null) {
        throw Exception('Video compression failed');
      }
      
      final compressedPath = compressedInfo.path!;
      final originalSize = File(videoPath).lengthSync();
      final compressedSize = File(compressedPath).lengthSync();
      debugPrint('Video compressed: ${(originalSize / 1024 / 1024).toStringAsFixed(1)}MB → ${(compressedSize / 1024 / 1024).toStringAsFixed(1)}MB');
      
      // Upload compressed video to Blossom server
      final blossomService = ref.read(blossomServiceProvider);
      debugPrint('Starting video upload to Blossom...');
      final uploadResult = await blossomService.uploadFile(compressedPath);
      debugPrint('Video upload completed: ${uploadResult.url}');
      
      // Create Nostr note with video metadata
      await blossomService.createVideoNote(
        description: description,
        uploadResult: uploadResult,
        hashtags: ['vlog', 'video', 'veelog'],
      );
      
      // Clean up local video files
      final originalFile = File(videoPath);
      if (await originalFile.exists()) {
        await originalFile.delete();
      }
      
      final compressedFile = File(compressedPath);
      if (await compressedFile.exists()) {
        await compressedFile.delete();
      }
      
      Fluttertoast.showToast(
        msg: "Video uploaded and posted successfully!",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      
      if (context.mounted) {
        context.go('/');
      }
    } catch (e) {
      debugPrint('Error saving video: $e');
      String errorMsg = 'Error uploading video';
      if (e is BlossomException) {
        errorMsg = 'Upload failed: ${e.message}';
      }
      
      Fluttertoast.showToast(
        msg: errorMsg,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  Future<String?> _showDescriptionDialog(BuildContext context) async {
    final controller = TextEditingController();
    
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Description'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'What\'s this video about?',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          maxLength: 280,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Post'),
          ),
        ],
      ),
    );
  }
}