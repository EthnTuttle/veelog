import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:video_player/video_player.dart';
import 'package:veelog/providers/auth_provider.dart';
import 'package:veelog/providers/following_provider.dart';
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
    final currentUser = ref.watch(currentUserPubkeyProvider);
    final followingList = ref.watch(followingListProvider);
    
    // Get all video notes for swipe navigation
    final videosState = ref.watch(
      query<Note>(
        authors: currentUser != null 
            ? {...followingList, currentUser}
            : followingList,
        limit: 50,
        source: LocalAndRemoteSource(stream: true),
      ),
    );
    
    final videoPlayerController = useState<VideoPlayerController?>(null);
    final chewieController = useState<ChewieController?>(null);
    final pageController = useState<PageController?>(null);
    final currentVideoIndex = useState(0);

    useEffect(() {
      // Find all video notes and current video index
      if (videosState is StorageData) {
        final videoNotes = videosState.models.where(_hasVideoContent).toList();
        final currentIndex = videoNotes.indexWhere((note) => note.id == videoNote.id);
        
        if (currentIndex >= 0) {
          currentVideoIndex.value = currentIndex;
          pageController.value = PageController(initialPage: currentIndex);
          
          final videoUrl = _extractVideoUrl(videoNotes[currentIndex]);
          if (videoUrl != null) {
            _initializeVideo(videoUrl, videoPlayerController, chewieController);
          }
        }
      }
      
      return () {
        chewieController.value?.dispose();
        videoPlayerController.value?.dispose();
        pageController.value?.dispose();
      };
    }, [videosState]);

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
      body: switch (videosState) {
        StorageLoading() => const Center(child: CircularProgressIndicator()),
        StorageError(:final exception) => Center(
          child: Text('Error: ${exception.toString()}'),
        ),
        StorageData(:final models) => _buildSwipeableVideos(
          context, 
          models.where(_hasVideoContent).toList(),
          pageController.value,
          currentVideoIndex,
          videoPlayerController,
          chewieController,
        ),
      },
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

  Widget _buildSwipeableVideos(
    BuildContext context,
    List<Note> videoNotes,
    PageController? pageController,
    ValueNotifier<int> currentVideoIndex,
    ValueNotifier<VideoPlayerController?> videoPlayerController,
    ValueNotifier<ChewieController?> chewieController,
  ) {
    if (pageController == null || videoNotes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return PageView.builder(
      controller: pageController,
      onPageChanged: (index) {
        currentVideoIndex.value = index;
        
        // Initialize new video
        final videoUrl = _extractVideoUrl(videoNotes[index]);
        if (videoUrl != null) {
          // Dispose previous controllers
          chewieController.value?.dispose();
          videoPlayerController.value?.dispose();
          
          // Initialize new video
          _initializeVideo(videoUrl, videoPlayerController, chewieController);
        }
      },
      itemCount: videoNotes.length,
      itemBuilder: (context, index) {
        final video = videoNotes[index];
        
        return Column(
          children: [
            // Video player
            Expanded(
              child: Container(
                color: Colors.black,
                child: chewieController.value != null
                    ? Center(
                        child: AspectRatio(
                          aspectRatio: videoPlayerController.value?.value.aspectRatio ?? 16/9,
                          child: Chewie(controller: chewieController.value!),
                        ),
                      )
                    : const Center(child: CircularProgressIndicator()),
              ),
            ),
            
            // Video info and engagement
            Container(
              color: Colors.black,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  if (video.content.isNotEmpty)
                    ParsedContentWidget(
                      note: video,
                      colorPair: [Colors.white, Colors.grey[300]!],
                      onProfileTap: (pubkey) => context.push('/profile/$pubkey'),
                      onHashtagTap: (hashtag) => context.push('/hashtag/$hashtag'),
                    ),
                  
                  const SizedBox(height: 12),
                  
                  // Engagement row
                  EngagementRow(
                    likesCount: 0,
                    repostsCount: 0,
                    zapsCount: 0,
                    zapsSatAmount: 0,
                    onLike: () {
                      // TODO: Implement reaction
                    },
                    onRepost: () {
                      // TODO: Implement repost
                    },
                    onZap: () {
                      // TODO: Implement zap
                    },
                    isLiked: false,
                    isReposted: false,
                    isZapped: false,
                    isLiking: false,
                    isReposting: false,
                    isZapping: false,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Navigation indicator
                  if (videoNotes.length > 1)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${index + 1} of ${videoNotes.length}',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Swipe to navigate',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _extractDescription(String content) {
    // Extract description (everything before the first HTTP URL)
    final lines = content.split('\n');
    final descriptionLines = <String>[];
    
    for (final line in lines) {
      if (line.trim().startsWith('http')) {
        break;
      }
      if (line.trim().isNotEmpty) {
        descriptionLines.add(line.trim());
      }
    }
    
    return descriptionLines.join(' ');
  }

  bool _hasVideoContent(Note note) {
    // Check for imeta tags with video URLs
    for (final tag in note.tags) {
      if (tag.isNotEmpty && tag[0] == 'imeta') {
        for (int i = 1; i < tag.length; i++) {
          if (tag[i].startsWith('url ')) {
            final url = tag[i].substring(4);
            if (_isVideoUrl(url)) {
              return true;
            }
          }
        }
      }
    }
    
    // Check content for video URLs
    final lines = note.content.split('\n');
    for (final line in lines) {
      if (line.trim().startsWith('http') && _isVideoUrl(line.trim())) {
        return true;
      }
    }
    
    // Check for video hashtags
    return note.tags.any((tag) => 
        tag.length >= 2 && 
        tag[0] == 't' && 
        (tag[1] == 'video' || tag[1] == 'vlog' || tag[1] == 'veelog'));
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