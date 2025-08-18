import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:veelog/providers/auth_provider.dart';
import 'package:veelog/providers/following_provider.dart';
import 'package:veelog/providers/display_settings_provider.dart';
import 'package:veelog/widgets/common/profile_avatar.dart';

class HomeScreen extends HookConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserPubkeyProvider);
    final currentUserProfile = ref.watch(currentUserProfileProvider);
    final followingList = ref.watch(followingListProvider);
    
    // Query video posts from Nostr - both kind 1 notes and kind 22 short videos
    final notesState = ref.watch(
      query<Note>(
        authors: currentUser != null 
            ? {...followingList, currentUser} // Include followed users + self
            : followingList.isNotEmpty 
                ? followingList 
                : {}, // Empty set when not authenticated and no following list
        limit: 25,
        source: LocalAndRemoteSource(stream: true),
      ),
    );

    final shortVideosState = ref.watch(
      query<ShortFormPortraitVideo>(
        authors: currentUser != null 
            ? {...followingList, currentUser}
            : followingList.isNotEmpty 
                ? followingList 
                : {},
        limit: 25,
        source: LocalAndRemoteSource(stream: true),
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5DEB3), // Wheat background
      appBar: AppBar(
        title: Row(
          children: [
            const Text('VeeLog'),
            const SizedBox(width: 8),
            Icon(
              Icons.home,
              size: 20,
              color: Colors.white,
            ),
          ],
        ),
        backgroundColor: const Color(0xFF8B4513), // Wood brown
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
          if (currentUser != null)
            GestureDetector(
              onTap: () => context.push('/profile/$currentUser'),
              child: Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: ProfileAvatar(
                  profile: currentUserProfile,
                  radius: 18,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: _buildCombinedVideoFeed(context, notesState, shortVideosState),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/record'),
        backgroundColor: const Color(0xFF654321), // Dark wood
        child: const Icon(Icons.videocam, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.video_library_outlined,
            size: 64,
            color: const Color(0xFF654321), // Dark wood
          ),
          const SizedBox(height: 16),
          Text(
            'No videos in your feed',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Follow other users to see their videos, or record your own',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => context.push('/record'),
            icon: const Icon(Icons.videocam),
            label: const Text('Record Video'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF654321), // Dark wood
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCombinedVideoFeed(BuildContext context, StorageState<Note> notesState, StorageState<ShortFormPortraitVideo> shortVideosState) {
    // Handle loading states
    if (notesState is StorageLoading || shortVideosState is StorageLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Handle error states
    if (notesState is StorageError) {
      return _buildErrorState(context, 'Error loading notes: ${(notesState as StorageError).exception}');
    }
    if (shortVideosState is StorageError) {
      return _buildErrorState(context, 'Error loading videos: ${(shortVideosState as StorageError).exception}');
    }

    // Combine data from both sources
    final notes = notesState is StorageData ? notesState.models : <Note>[];
    final shortVideos = shortVideosState is StorageData ? shortVideosState.models : <ShortFormPortraitVideo>[];

    // Filter notes to only include those with video content
    final videoNotes = notes.where(_hasVideoContent).toList();

    // Create combined list sorted by creation time
    final combinedVideos = <dynamic>[];
    combinedVideos.addAll(videoNotes);
    combinedVideos.addAll(shortVideos); // All ShortFormPortraitVideo are videos by definition
    combinedVideos.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (combinedVideos.isEmpty) {
      return _buildEmptyState(context);
    }

    return _buildVideoList(context, combinedVideos);
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading videos',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildVideoList(BuildContext context, List<dynamic> videos) {
    if (videos.isEmpty) {
      return _buildEmptyState(context);
    }
    
    return Consumer(
      builder: (context, ref, child) {
        final displayMode = ref.watch(displayModeProvider);
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: videos.length,
          itemBuilder: (context, index) {
            final video = videos[index];
            return _buildVideoCard(context, video, displayMode);
          },
        );
      },
    );
  }

  Widget _buildVideoCard(BuildContext context, dynamic video, DisplayMode displayMode) {
    // Handle both Note and ShortFormPortraitVideo types
    String description;
    String? videoUrl;
    DateTime createdAt;
    String videoId;
    String authorPubkey;
    
    if (video is Note) {
      description = _extractDescription(video.content);
      videoUrl = _extractVideoUrlFromNote(video);
      createdAt = video.createdAt;
      videoId = video.id;
      authorPubkey = video.author.value?.pubkey ?? video.event.pubkey;
    } else if (video is ShortFormPortraitVideo) {
      description = video.description;
      videoUrl = video.videoUrl;
      createdAt = video.createdAt;
      videoId = video.id;
      authorPubkey = video.author.value?.pubkey ?? video.event.pubkey;
    } else {
      return const SizedBox.shrink(); // Skip unknown types
    }
    
    switch (displayMode) {
      case DisplayMode.compact:
        return _buildCompactCard(context, video, description, videoUrl, createdAt, videoId);
      case DisplayMode.detailed:
        return _buildDetailedCard(context, video, description, videoUrl, createdAt, videoId, authorPubkey);
      case DisplayMode.robust:
        return _buildRobustCard(context, video, description, videoUrl, createdAt, videoId, authorPubkey);
      case DisplayMode.standard:
        return _buildStandardCard(context, video, description, videoUrl, createdAt, videoId);
    }
  }

  Widget _buildStandardCard(BuildContext context, dynamic video, String description, String? videoUrl, DateTime createdAt, String videoId) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFFD2B48C), // Tan
      child: ListTile(
        leading: _buildVideoThumbnailFromUrl(videoUrl),
        title: Text(
          description.isNotEmpty ? description : 'Video post',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Icon(
              video is ShortFormPortraitVideo ? Icons.video_collection : Icons.videocam,
              size: 14,
              color: const Color(0xFF654321),
            ),
            const SizedBox(width: 4),
            Text(
              '${video is ShortFormPortraitVideo ? "Kind 22" : "Kind 1"} • ${_formatTimeAgo(createdAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: const Color(0xFF8B4513).withValues(alpha: 0.6),
        ),
        onTap: () => _navigateToVideo(context, video, videoId),
      ),
    );
  }

  Widget _buildCompactCard(BuildContext context, dynamic video, String description, String? videoUrl, DateTime createdAt, String videoId) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: const Color(0xFFD2B48C),
      child: ListTile(
        dense: true,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF8B4513).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            video is ShortFormPortraitVideo ? Icons.video_collection : Icons.videocam,
            color: const Color(0xFF654321),
            size: 20,
          ),
        ),
        title: Text(
          description.isNotEmpty ? description : 'Video',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14),
        ),
        subtitle: Text(
          '${video is ShortFormPortraitVideo ? "K22" : "K1"} • ${_formatTimeAgo(createdAt)}',
          style: const TextStyle(fontSize: 12),
        ),
        onTap: () => _navigateToVideo(context, video, videoId),
      ),
    );
  }

  Widget _buildDetailedCard(BuildContext context, dynamic video, String description, String? videoUrl, DateTime createdAt, String videoId, String authorPubkey) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: const Color(0xFFD2B48C),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildVideoThumbnailFromUrl(videoUrl),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        description.isNotEmpty ? description : 'Video post',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            video is ShortFormPortraitVideo ? Icons.video_collection : Icons.videocam,
                            size: 16,
                            color: const Color(0xFF654321),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            video is ShortFormPortraitVideo ? 'Short Video (Kind 22)' : 'Video Note (Kind 1)',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatTimeAgo(createdAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                ElevatedButton(
                  onPressed: () => _navigateToVideo(context, video, videoId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF654321),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(80, 32),
                  ),
                  child: const Text('Watch'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRobustCard(BuildContext context, dynamic video, String description, String? videoUrl, DateTime createdAt, String videoId, String authorPubkey) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      color: const Color(0xFFD2B48C),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Consumer(
                  builder: (context, ref, child) {
                    final authorState = ref.watch(query<Profile>(authors: {authorPubkey}));
                    final author = authorState is StorageData ? authorState.models.firstOrNull : null;
                    return ProfileAvatar(
                      profile: author,
                      radius: 20,
                    );
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Consumer(
                        builder: (context, ref, child) {
                          final authorState = ref.watch(query<Profile>(authors: {authorPubkey}));
                          final author = authorState is StorageData ? authorState.models.firstOrNull : null;
                          return Text(
                            author?.nameOrNpub ?? 'Unknown',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF654321),
                            ),
                          );
                        },
                      ),
                      Text(
                        Utils.encodeShareableFromString(authorPubkey, type: 'npub'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          color: const Color(0xFF8B4513).withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      video is ShortFormPortraitVideo ? Icons.video_collection : Icons.videocam,
                      size: 16,
                      color: const Color(0xFF654321),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: video is ShortFormPortraitVideo 
                            ? const Color(0xFF654321).withValues(alpha: 0.2)
                            : const Color(0xFF8B4513).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        video is ShortFormPortraitVideo ? 'Kind 22' : 'Kind 1',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF654321),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: _buildVideoThumbnailFromUrl(videoUrl, width: double.infinity, height: 200),
            ),
            const SizedBox(height: 12),
            Text(
              description.isNotEmpty ? description : 'Video post',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatTimeAgo(createdAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.favorite_border, size: 20),
                      color: const Color(0xFF654321),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.share, size: 20),
                      color: const Color(0xFF654321),
                    ),
                    ElevatedButton(
                      onPressed: () => _navigateToVideo(context, video, videoId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF654321),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(80, 36),
                      ),
                      child: const Text('Watch'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToVideo(BuildContext context, dynamic video, String videoId) {
    if (video is Note) {
      context.push('/video/${video.id}', extra: video);
    } else if (video is ShortFormPortraitVideo) {
      context.push('/video/$videoId', extra: video);
    }
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
        (tag[1] == 'video' || tag[1] == 'vlog'));
  }

  bool _isVideoUrl(String url) {
    return url.contains('.mp4') || 
           url.contains('.mov') || 
           url.contains('.avi') ||
           url.contains('.webm') ||
           url.contains('.mkv');
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

  String? _extractVideoUrlFromNote(Note note) {
    return _extractVideoUrl(note.content);
  }

  Widget _buildVideoThumbnailFromUrl(String? videoUrl, {double? width, double? height}) {
    
    return Container(
      width: width ?? 56,
      height: height ?? 56,
      decoration: BoxDecoration(
        color: const Color(0xFF8B4513).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (videoUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: '${videoUrl.replaceAll('.mp4', '')}.jpg', // Try thumbnail
                width: width ?? 56,
                height: height ?? 56,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Container(
                  color: const Color(0xFF8B4513).withValues(alpha: 0.2),
                  child: Icon(
                    Icons.videocam,
                    color: const Color(0xFF654321).withValues(alpha: 0.6),
                    size: 24,
                  ),
                ),
                placeholder: (context, url) => Container(
                  color: const Color(0xFF8B4513).withValues(alpha: 0.2),
                  child: Icon(
                    Icons.videocam,
                    color: const Color(0xFF654321).withValues(alpha: 0.6),
                    size: 24,
                  ),
                ),
              ),
            ),
          Icon(
            Icons.play_circle_outline,
            color: const Color(0xFF654321),
            size: 32,
          ),
        ],
      ),
    );
  }

  String? _extractVideoUrl(String content) {
    final lines = content.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('http') && _isVideoUrl(trimmed)) {
        return trimmed;
      }
    }
    return null;
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}