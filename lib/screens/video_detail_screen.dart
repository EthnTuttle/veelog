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
  final dynamic videoNote; // Can be Note or ShortFormPortraitVideo

  const VideoDetailScreen({
    super.key,
    required this.videoNote,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserPubkeyProvider);
    final followingList = ref.watch(followingListProvider);
    
    // Get all video content for swipe navigation (both kinds)
    final notesState = ref.watch(
      query<Note>(
        authors: currentUser != null 
            ? {...followingList, currentUser}
            : followingList,
        limit: 50,
        source: LocalAndRemoteSource(stream: true),
      ),
    );
    
    final shortVideosState = ref.watch(
      query<ShortFormPortraitVideo>(
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
      // Combine and organize video content
      if (notesState is StorageData && shortVideosState is StorageData) {
        final videoNotes = notesState.models.where(_hasVideoContent).toList();
        final allVideos = <dynamic>[];
        allVideos.addAll(videoNotes);
        allVideos.addAll(shortVideosState.models);
        allVideos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        
        final currentVideoId = videoNote is Note ? videoNote.id : (videoNote as ShortFormPortraitVideo).id;
        final currentIndex = allVideos.indexWhere((video) {
          if (video is Note) return video.id == currentVideoId;
          if (video is ShortFormPortraitVideo) return video.id == currentVideoId;
          return false;
        });
        
        if (currentIndex >= 0) {
          currentVideoIndex.value = currentIndex;
          pageController.value = PageController(initialPage: currentIndex);
          
          final videoUrl = _getVideoUrl(allVideos[currentIndex]);
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
    }, [notesState, shortVideosState]);

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
      body: switch ((notesState, shortVideosState)) {
        (StorageLoading(), _) || (_, StorageLoading()) => const Center(child: CircularProgressIndicator()),
        (StorageError(:final exception), _) => Center(
          child: Text('Error loading notes: ${exception.toString()}'),
        ),
        (_, StorageError(:final exception)) => Center(
          child: Text('Error loading videos: ${exception.toString()}'),
        ),
        (StorageData<Note>(:final models), StorageData<ShortFormPortraitVideo>(models: final videoModels)) => _buildSwipeableVideos(
          context, 
          models, 
          videoModels,
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
    List<Note> noteModels,
    List<ShortFormPortraitVideo> videoModels,
    PageController? pageController,
    ValueNotifier<int> currentVideoIndex,
    ValueNotifier<VideoPlayerController?> videoPlayerController,
    ValueNotifier<ChewieController?> chewieController,
  ) {
    // Combine and organize videos by author
    final videoNotes = noteModels.where(_hasVideoContent).toList();
    final allVideos = <dynamic>[];
    allVideos.addAll(videoNotes);
    allVideos.addAll(videoModels);
    allVideos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    // Group videos by author for navigation
    final videosByAuthor = <String, List<dynamic>>{};
    for (final video in allVideos) {
      final authorPubkey = video is Note ? (video.author.value?.pubkey ?? video.event.pubkey) : ((video as ShortFormPortraitVideo).author.value?.pubkey ?? video.event.pubkey);
      videosByAuthor.putIfAbsent(authorPubkey, () => []).add(video);
    }
    
    if (pageController == null || allVideos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        // Swipe left/right for same author videos
        final currentVideo = allVideos[currentVideoIndex.value];
        final currentAuthor = currentVideo is Note ? (currentVideo.author.value?.pubkey ?? currentVideo.event.pubkey) : ((currentVideo as ShortFormPortraitVideo).author.value?.pubkey ?? currentVideo.event.pubkey);
        final authorVideos = videosByAuthor[currentAuthor] ?? [];
        
        if (authorVideos.length <= 1) return;
        
        final currentAuthorIndex = authorVideos.indexWhere((v) {
          final id = v is Note ? v.id : (v as ShortFormPortraitVideo).id;
          final currentId = currentVideo is Note ? currentVideo.id : (currentVideo as ShortFormPortraitVideo).id;
          return id == currentId;
        });
        
        int nextAuthorIndex;
        if (details.primaryVelocity! < 0) {
          // Swipe left - next video from same author
          nextAuthorIndex = (currentAuthorIndex + 1) % authorVideos.length;
        } else {
          // Swipe right - previous video from same author
          nextAuthorIndex = (currentAuthorIndex - 1 + authorVideos.length) % authorVideos.length;
        }
        
        final nextVideo = authorVideos[nextAuthorIndex];
        final nextGlobalIndex = allVideos.indexWhere((v) {
          final id = v is Note ? v.id : (v as ShortFormPortraitVideo).id;
          final nextId = nextVideo is Note ? nextVideo.id : (nextVideo as ShortFormPortraitVideo).id;
          return id == nextId;
        });
        
        if (nextGlobalIndex >= 0) {
          pageController.animateToPage(
            nextGlobalIndex,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      },
      onVerticalDragEnd: (details) {
        // Swipe up/down for different authors
        final currentVideo = allVideos[currentVideoIndex.value];
        final currentAuthor = currentVideo is Note ? (currentVideo.author.value?.pubkey ?? currentVideo.event.pubkey) : ((currentVideo as ShortFormPortraitVideo).author.value?.pubkey ?? currentVideo.event.pubkey);
        final authors = videosByAuthor.keys.toList();
        
        if (authors.length <= 1) return;
        
        final currentAuthorIndex = authors.indexOf(currentAuthor);
        int nextAuthorIndex;
        
        if (details.primaryVelocity! < 0) {
          // Swipe up - next author
          nextAuthorIndex = (currentAuthorIndex + 1) % authors.length;
        } else {
          // Swipe down - previous author
          nextAuthorIndex = (currentAuthorIndex - 1 + authors.length) % authors.length;
        }
        
        final nextAuthor = authors[nextAuthorIndex];
        final nextAuthorVideos = videosByAuthor[nextAuthor] ?? [];
        
        if (nextAuthorVideos.isNotEmpty) {
          final nextVideo = nextAuthorVideos.first;
          final nextGlobalIndex = allVideos.indexWhere((v) {
            final id = v is Note ? v.id : (v as ShortFormPortraitVideo).id;
            final nextId = nextVideo is Note ? nextVideo.id : (nextVideo as ShortFormPortraitVideo).id;
            return id == nextId;
          });
          
          if (nextGlobalIndex >= 0) {
            pageController.animateToPage(
              nextGlobalIndex,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        }
      },
      child: PageView.builder(
        controller: pageController,
        onPageChanged: (index) {
          currentVideoIndex.value = index;
          
          // Initialize new video
          final videoUrl = _getVideoUrl(allVideos[index]);
          if (videoUrl != null) {
            // Dispose previous controllers
            chewieController.value?.dispose();
            videoPlayerController.value?.dispose();
            
            // Initialize new video
            _initializeVideo(videoUrl, videoPlayerController, chewieController);
          }
        },
        itemCount: allVideos.length,
        itemBuilder: (context, index) {
          final video = allVideos[index];
          final isKind22 = video is ShortFormPortraitVideo;
          
          return Column(
            children: [
              // Video player
              Expanded(
                child: Container(
                  color: Colors.black,
                  child: chewieController.value != null
                      ? Center(
                          child: AspectRatio(
                            aspectRatio: videoPlayerController.value?.value.aspectRatio ?? (isKind22 ? 9/16 : 16/9),
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
                    // Video type indicator
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isKind22 
                                ? Colors.purple.withValues(alpha: 0.2)
                                : Colors.blue.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isKind22 ? 'Kind 22 - Short Video' : 'Kind 1 - Video Note',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isKind22 ? Colors.purple[200] : Colors.blue[200],
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Swipe ↔ same user, ↕ different users',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Description
                    if (video is Note && video.content.isNotEmpty)
                      ParsedContentWidget(
                        note: video,
                        colorPair: [Colors.white, Colors.grey[300]!],
                        onProfileTap: (pubkey) => context.push('/profile/$pubkey'),
                        onHashtagTap: (hashtag) => context.push('/hashtag/$hashtag'),
                      )
                    else if (video is ShortFormPortraitVideo && video.description.isNotEmpty)
                      Text(
                        video.description,
                        style: const TextStyle(color: Colors.white),
                      ),
                    
                    const SizedBox(height: 12),
                    
                    // Engagement row with proper video event handling
                    Consumer(
                      builder: (context, ref, child) {
                        // Query reactions, reposts and zaps for this video
                        final videoEventId = video is Note ? video.id : (video as ShortFormPortraitVideo).id;
                        
                        final reactionsState = ref.watch(
                          query<Reaction>(
                            tags: {'#e': {videoEventId}},
                            source: LocalAndRemoteSource(stream: true),
                          ),
                        );
                        
                        final repostsState = ref.watch(
                          query<Repost>(
                            tags: {'#e': {videoEventId}},
                            source: LocalAndRemoteSource(stream: true),
                          ),
                        );
                        
                        final zapsState = ref.watch(
                          query<Zap>(
                            tags: {'#e': {videoEventId}},
                            source: LocalAndRemoteSource(stream: true),
                          ),
                        );
                        
                        final reactions = reactionsState is StorageData ? reactionsState.models : <Reaction>[];
                        final reposts = repostsState is StorageData ? repostsState.models : <Repost>[];
                        final zaps = zapsState is StorageData ? zapsState.models : <Zap>[];
                        
                        final currentUser = ref.watch(currentUserPubkeyProvider);
                        final isLiked = currentUser != null && reactions.any((r) => r.author.value?.pubkey == currentUser);
                        final isReposted = currentUser != null && reposts.any((r) => r.author.value?.pubkey == currentUser);
                        final isZapped = currentUser != null && zaps.any((z) => z.author.value?.pubkey == currentUser);
                        
                        return EngagementRow(
                          likesCount: reactions.length,
                          repostsCount: reposts.length,
                          zapsCount: zaps.length,
                          zapsSatAmount: zaps.fold(0, (sum, zap) => sum + (zap.amount ?? 0)),
                          onLike: () => _handleLike(ref, videoEventId),
                          onRepost: () => _handleRepost(ref, video),
                          onZap: () => _handleZap(ref, videoEventId),
                          isLiked: isLiked,
                          isReposted: isReposted,
                          isZapped: isZapped,
                          isLiking: false,
                          isReposting: false,
                          isZapping: false,
                        );
                      },
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Navigation indicator
                    if (allVideos.length > 1)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${index + 1} of ${allVideos.length}',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
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
      ),
    );
  }
  
  String? _getVideoUrl(dynamic video) {
    if (video is Note) {
      return _extractVideoUrl(video);
    } else if (video is ShortFormPortraitVideo) {
      return video.videoUrl;
    }
    return null;
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
  
  Future<void> _handleLike(WidgetRef ref, String eventId) async {
    try {
      final activeSigner = ref.read(Signer.activeSignerProvider);
      if (activeSigner == null) return;
      
      final reaction = PartialReaction(content: '+');
      // Link to the event being reacted to
      reaction.event.addTag('e', [eventId]);
      final signedEvents = await activeSigner.sign([reaction]);
      
      await ref.read(storageNotifierProvider.notifier).save(signedEvents.toSet());
      await ref.read(storageNotifierProvider.notifier).publish(signedEvents.toSet());
    } catch (e) {
      debugPrint('Error creating reaction: $e');
    }
  }
  
  Future<void> _handleRepost(WidgetRef ref, dynamic video) async {
    try {
      final activeSigner = ref.read(Signer.activeSignerProvider);
      if (activeSigner == null) return;
      
      final eventId = video is Note ? video.id : (video as ShortFormPortraitVideo).id;
      final authorPubkey = video is Note ? (video.author.value?.pubkey ?? video.event.pubkey) : ((video as ShortFormPortraitVideo).author.value?.pubkey ?? video.event.pubkey);
      
      final repost = PartialRepost();
      repost.repostedNoteId = eventId;
      repost.repostedNotePubkey = authorPubkey;
      
      final signedEvents = await activeSigner.sign([repost]);
      
      await ref.read(storageNotifierProvider.notifier).save(signedEvents.toSet());
      await ref.read(storageNotifierProvider.notifier).publish(signedEvents.toSet());
    } catch (e) {
      debugPrint('Error creating repost: $e');
    }
  }
  
  Future<void> _handleZap(WidgetRef ref, String eventId) async {
    try {
      // For now, just show a placeholder message
      // Full zap implementation requires Lightning wallet integration
      debugPrint('Zap functionality requires Lightning wallet setup');
    } catch (e) {
      debugPrint('Error creating zap: $e');
    }
  }
}