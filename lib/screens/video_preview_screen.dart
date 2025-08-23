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
import 'package:veelog/providers/video_quality_provider.dart';

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
      
      // Get quality setting and compress video
      final qualityLevel = ref.read(videoQualityProvider);
      final compressQuality = VideoQualitySettings.getVideoCompressQuality(qualityLevel);
      
      debugPrint('Compressing video with quality: $qualityLevel');
      
      MediaInfo? compressedInfo;
      String compressedPath;
      
      if (qualityLevel == VideoQualityLevel.original) {
        // Skip compression for original quality
        compressedPath = videoPath;
        debugPrint('Using original video without compression');
      } else {
        compressedInfo = await VideoCompress.compressVideo(
          videoPath,
          quality: compressQuality,
          deleteOrigin: false,
          includeAudio: true,
        );
        
        if (compressedInfo == null) {
          throw Exception('Video compression failed');
        }
        compressedPath = compressedInfo.path!;
      }
      
      // Log compression results
      final originalSize = File(videoPath).lengthSync();
      final compressedSize = File(compressedPath).lengthSync();
      
      if (qualityLevel != VideoQualityLevel.original) {
        debugPrint('Video compressed: ${(originalSize / 1024 / 1024).toStringAsFixed(1)}MB → ${(compressedSize / 1024 / 1024).toStringAsFixed(1)}MB');
      } else {
        debugPrint('Using original video: ${(originalSize / 1024 / 1024).toStringAsFixed(1)}MB');
      }
      
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
      
      // Only delete compressed file if it's different from original
      if (qualityLevel != VideoQualityLevel.original) {
        final compressedFile = File(compressedPath);
        if (await compressedFile.exists()) {
          await compressedFile.delete();
        }
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
    String previewText = '';
    
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Description'),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            height: 400,
            child: Column(
              children: [
                // Larger text input
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: controller,
                    onChanged: (text) {
                      setState(() {
                        previewText = text;
                      });
                    },
                    decoration: const InputDecoration(
                      hintText: 'What\'s this video about?',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(12),
                    ),
                    maxLines: null,
                    expands: true,
                    maxLength: 280,
                    textAlignVertical: TextAlignVertical.top,
                  ),
                ),
                
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                
                // Preview section
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Preview:',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        // Note preview
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Kind 1 Note Content:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                previewText.isNotEmpty 
                                    ? previewText 
                                    : '[Video description]',
                                style: TextStyle(
                                  color: previewText.isNotEmpty ? Colors.black : Colors.grey[500],
                                  fontStyle: previewText.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '[Video URL will be inserted here]',
                                style: TextStyle(
                                  color: Colors.blue[600],
                                  fontStyle: FontStyle.italic,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'nostr:[nevent reference]',
                                style: TextStyle(
                                  color: Colors.purple[600],
                                  fontStyle: FontStyle.italic,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Kind 22 preview
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.purple[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.purple[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Kind 22 Short Video Event:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.purple[700],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Title: ${previewText.isNotEmpty ? previewText : "VeeLog Video"}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text(
                                'Description: ${previewText.isNotEmpty ? previewText : "Video log"}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text(
                                'Tags: #veelog #video',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.purple[600],
                                ),
                              ),
                              Text(
                                'IMeta: [URL, hash, MIME type, size, service]',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
      ),
    );
  }
}