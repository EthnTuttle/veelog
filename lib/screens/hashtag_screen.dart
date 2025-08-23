import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:veelog/widgets/common/profile_avatar.dart';

class HashtagScreen extends ConsumerWidget {
  final String hashtag;

  const HashtagScreen({
    super.key,
    required this.hashtag,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesState = ref.watch(
      query<Note>(
        tags: {'#t': {hashtag}},
        limit: 50,
        source: LocalAndRemoteSource(stream: true),
      ),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text('#$hashtag'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: switch (notesState) {
        StorageLoading() => const Center(child: CircularProgressIndicator()),
        StorageError(:final exception) => Center(
          child: Text('Error: ${exception.toString()}'),
        ),
        StorageData(:final models) => models.isEmpty
            ? _buildEmptyState(context)
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: models.length,
                itemBuilder: (context, index) {
                  final note = models[index];
                  return _buildNoteCard(context, note, ref);
                },
              ),
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.tag,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          const SizedBox(height: 16),
          Text(
            'No posts found',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'No posts with #$hashtag yet',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(BuildContext context, Note note, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProfileAvatar(
                  profile: note.author.value,
                  radius: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.author.value?.nameOrNpub ?? 'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF654321),
                        ),
                      ),
                      Text(
                        _formatTimeAgo(note.createdAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              note.content,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: () => context.push('/profile/${note.author.value?.pubkey ?? note.event.pubkey}'),
                  icon: const Icon(Icons.person, size: 20),
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                if (_hasVideoContent(note))
                  IconButton(
                    onPressed: () => context.push('/video/${note.id}', extra: note),
                    icon: const Icon(Icons.play_circle, size: 20),
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _hasVideoContent(Note note) {
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
    
    final lines = note.content.split('\n');
    for (final line in lines) {
      if (line.trim().startsWith('http') && _isVideoUrl(line.trim())) {
        return true;
      }
    }
    
    return false;
  }

  bool _isVideoUrl(String url) {
    return url.contains('.mp4') || 
           url.contains('.mov') || 
           url.contains('.avi') ||
           url.contains('.webm') ||
           url.contains('.mkv');
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