import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:video_player/video_player.dart';
import 'package:veelog/widgets/common/engagement_row.dart';
import 'package:veelog/widgets/common/note_parser.dart';

class VideoDetailScreen extends HookConsumerWidget {
  final Note videoNote;

  const VideoDetailScreen({
    super.key,
    required this.videoNote,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoPlayerController = useState<VideoPlayerController?>(null);
    final chewieController = useState<ChewieController?>(null);

    useEffect(() {
      final videoUrl = _extractVideoUrl(videoNote);
      if (videoUrl != null) {
        _initializeVideo(videoUrl, videoPlayerController, chewieController);
      }
      return () {
        chewieController.value?.dispose();
        videoPlayerController.value?.dispose();
      };
    }, [videoNote.id]);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Video'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Video player area
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              color: Colors.black,
              child: Center(
                child: chewieController.value != null
                    ? Chewie(controller: chewieController.value!)
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.play_circle_outline,
                            size: 64,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading video...',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          
          // Video info and engagement
          Expanded(
            flex: 2,
            child: Container(
              color: const Color(0xFFF5DEB3), // Wheat background
              child: Column(
                children: [
                  // Video description
                  if (videoNote.content.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ParsedContentWidget(
                          note: videoNote,
                          colorPair: [
                            const Color(0xFF654321), // Dark wood
                            const Color(0xFF8B4513), // Medium wood
                          ],
                          onProfileTap: (pubkey) {
                            // TODO: Navigate to profile
                          },
                          onHashtagTap: (hashtag) {
                            // TODO: Navigate to hashtag feed
                          },
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 16),
                  
                  // Engagement row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: EngagementRow(
                      likesCount: 0, // TODO: Get from reactions
                      repostsCount: 0, // TODO: Get from reposts
                      zapsCount: 0, // TODO: Get from zaps
                      zapsSatAmount: 0, // TODO: Get from zaps
                      onLike: () {
                        // TODO: Implement reaction
                      },
                      onRepost: () {
                        // TODO: Implement repost
                      },
                      onZap: () {
                        // TODO: Implement zap
                      },
                    ),
                  ),
                  
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _extractVideoUrl(Note note) {
    // First, try to extract from imeta tags (NIP-92)
    for (final tag in note.tags) {
      if (tag.isNotEmpty && tag[0] == 'imeta') {
        for (int i = 1; i < tag.length; i++) {
          if (tag[i].startsWith('url ')) {
            final url = tag[i].substring(4);
            if (_isVideoUrl(url)) {
              return url;
            }
          }
        }
      }
    }
    
    // Fallback: Extract video URL from note content
    final lines = note.content.split('\n');
    for (final line in lines) {
      if (line.trim().startsWith('http') && _isVideoUrl(line.trim())) {
        return line.trim();
      }
    }
    return null;
  }

  bool _isVideoUrl(String url) {
    return url.contains('.mp4') || 
           url.contains('.mov') || 
           url.contains('.avi') ||
           url.contains('.webm') ||
           url.contains('.mkv');
  }

  Future<void> _initializeVideo(
    String videoUrl,
    ValueNotifier<VideoPlayerController?> videoController,
    ValueNotifier<ChewieController?> chewieController,
  ) async {
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
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
    } catch (e) {
      debugPrint('Error initializing video: $e');
    }
  }
}