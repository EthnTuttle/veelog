import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:veelog/providers/auth_provider.dart';
import 'package:veelog/providers/following_provider.dart';
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
        title: const Text('VeeLog'),
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
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        
        // Handle both Note and ShortFormPortraitVideo types
        String description;
        String? videoUrl;
        DateTime createdAt;
        String videoId;
        
        if (video is Note) {
          description = _extractDescription(video.content);
          videoUrl = _extractVideoUrlFromNote(video);
          createdAt = video.createdAt;
          videoId = video.id;
        } else if (video is ShortFormPortraitVideo) {
          description = video.description;
          videoUrl = video.videoUrl;
          createdAt = video.createdAt;
          videoId = video.id;
        } else {
          return const SizedBox.shrink(); // Skip unknown types
        }
        
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
                  color: const Color(0xFF654321), // Dark wood
                ),
                const SizedBox(width: 4),
                Text(
                  '${video is ShortFormPortraitVideo ? "Short Video" : "Video"} • ${_formatTimeAgo(createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            trailing: Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: const Color(0xFF8B4513).withValues(alpha: 0.6), // Wood brown
            ),
            onTap: () {
              if (video is Note) {
                context.push('/video/${video.id}', extra: video);
              } else if (video is ShortFormPortraitVideo) {
                // Convert ShortFormPortraitVideo to Note-like structure for navigation
                // For now, we'll navigate to video detail with the video data
                context.push('/video/$videoId', extra: video);
              }
            },
          ),
        );
      },
    );
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

  Widget _buildVideoThumbnailFromUrl(String? videoUrl) {
    
    return Container(
      width: 56,
      height: 56,
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
                width: 56,
                height: 56,
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