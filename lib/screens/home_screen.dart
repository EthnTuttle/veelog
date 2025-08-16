import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
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
    
    // Query video posts from Nostr - only from followed users or self
    final videosState = ref.watch(
      query<Note>(
        authors: currentUser != null 
            ? {...followingList, currentUser} // Include followed users + self
            : followingList.isNotEmpty 
                ? followingList 
                : {}, // Empty set when not authenticated and no following list
        limit: 50,
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
        child: switch (videosState) {
          StorageLoading() => const Center(child: CircularProgressIndicator()),
          StorageError(:final exception) => Center(
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
                  exception.toString(),
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          StorageData(:final models) => models.isEmpty
              ? _buildEmptyState(context)
              : _buildVideoList(context, models),
        },
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

  Widget _buildVideoList(BuildContext context, List<Note> videos) {
    // Filter to only show notes that have video content
    final videoNotes = videos.where((note) => _hasVideoContent(note)).toList();
    
    if (videoNotes.isEmpty) {
      return _buildEmptyState(context);
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: videoNotes.length,
      itemBuilder: (context, index) {
        final video = videoNotes[index];
        final description = _extractDescription(video.content);
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: const Color(0xFFD2B48C), // Tan
          child: ListTile(
            leading: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF8B4513).withValues(alpha: 0.2), // Wood brown
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.videocam,
                    color: const Color(0xFF654321).withValues(alpha: 0.3), // Dark wood
                    size: 24,
                  ),
                  Icon(
                    Icons.play_circle_outline,
                    color: const Color(0xFF654321), // Dark wood
                    size: 32,
                  ),
                ],
              ),
            ),
            title: Text(
              description.isNotEmpty ? description : 'Video post',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Row(
              children: [
                Icon(
                  Icons.videocam,
                  size: 14,
                  color: const Color(0xFF654321), // Dark wood
                ),
                const SizedBox(width: 4),
                Text(
                  'Video • ${_formatTimeAgo(video.createdAt)}',
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
              context.push('/video/${video.id}', extra: video);
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