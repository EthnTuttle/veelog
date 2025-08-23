import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:async_button_builder/async_button_builder.dart';
import 'package:models/models.dart';
import 'package:veelog/providers/auth_provider.dart';
import 'package:veelog/widgets/common/profile_avatar.dart';
import 'package:veelog/widgets/follow_button.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ProfileScreen extends HookConsumerWidget {
  final String pubkey;
  final bool isCurrentUser;

  const ProfileScreen({
    super.key,
    required this.pubkey,
    this.isCurrentUser = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserPubkeyProvider);
    final actualIsCurrentUser = isCurrentUser || pubkey == currentUser;
    
    final profileState = ref.watch(
      query<Profile>(
        authors: {pubkey},
        source: LocalAndRemoteSource(background: false),
      ),
    );

    final userNotesState = ref.watch(
      query<Note>(
        authors: {pubkey},
        limit: 20,
        source: LocalAndRemoteSource(stream: true),
      ),
    );

    return Scaffold(
      body: switch (profileState) {
        StorageLoading() => const Center(child: CircularProgressIndicator()),
        StorageError(:final exception) => _buildErrorState(context, exception),
        StorageData(:final models) => _buildProfileContent(
            context, 
            ref,
            models.isNotEmpty ? models.first : null,
            userNotesState,
            actualIsCurrentUser,
          ),
      },
    );
  }

  Widget _buildErrorState(BuildContext context, Exception exception) {
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
            'Error loading profile',
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
    );
  }

  Widget _buildProfileContent(
    BuildContext context,
    WidgetRef ref,
    Profile? profile,
    StorageState<Note> notesState,
    bool isCurrentUser,
  ) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 200.0,
          floating: false,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                    Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            if (isCurrentUser)
              IconButton(
                onPressed: () => _showEditProfileDialog(context, ref, profile),
                icon: const Icon(Icons.edit),
              ),
            PopupMenuButton<String>(
              onSelected: (value) => _handleMenuAction(context, ref, value, profile),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'copy_npub',
                  child: Row(
                    children: [
                      const Icon(Icons.copy),
                      const SizedBox(width: 8),
                      const Text('Copy npub'),
                    ],
                  ),
                ),
                if (isCurrentUser) ...[
                  const PopupMenuItem(
                    value: 'settings',
                    child: Row(
                      children: [
                        Icon(Icons.settings),
                        SizedBox(width: 8),
                        Text('Settings'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'sign_out',
                    child: Row(
                      children: [
                        Icon(Icons.logout),
                        SizedBox(width: 8),
                        Text('Sign Out'),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: _buildProfileInfo(context, ref, profile, isCurrentUser),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(
                  Icons.videocam,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Video Posts',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        switch (notesState) {
          StorageLoading() => const SliverToBoxAdapter(
              child: Center(child: CircularProgressIndicator()),
            ),
          StorageError(:final exception) => SliverToBoxAdapter(
              child: Center(
                child: Text('Error loading posts: $exception'),
              ),
            ),
          StorageData(:final models) => _buildVideoPostsList(context, models),
        },
      ],
    );
  }

  Widget _buildProfileInfo(BuildContext context, WidgetRef ref, Profile? profile, bool isCurrentUser) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProfileAvatar(
                profile: profile,
                radius: 40,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile?.nameOrNpub ?? 'Unknown',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (profile?.nip05 != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.verified,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              profile!.nip05!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          
          if (profile?.about?.isNotEmpty == true) ...[
            const SizedBox(height: 16),
            Text(
              profile!.about!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],

          if (profile?.website != null || profile?.lud16 != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                if (profile?.website != null) ...[
                  Icon(
                    Icons.link,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      profile!.website!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                if (profile?.website != null && profile?.lud16 != null)
                  const SizedBox(width: 16),
                if (profile?.lud16 != null) ...[
                  Icon(
                    Icons.bolt,
                    size: 16,
                    color: Colors.amber,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      profile!.lud16!,
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],
          
          // Follow button for other users
          if (!isCurrentUser) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FollowButton(targetPubkey: pubkey),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVideoPostsList(BuildContext context, List<Note> notes) {
    // Filter for video posts (similar logic as home screen)
    final videoNotes = notes.where((note) => _hasVideoContent(note)).toList();
    
    if (videoNotes.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Text('No video posts yet'),
          ),
        ),
      );
    }

    return SliverList.builder(
      itemCount: videoNotes.length,
      itemBuilder: (context, index) {
        final video = videoNotes[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.videocam,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            title: Text(
              _extractDescription(video.content),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(_formatTimeAgo(video.createdAt)),
            onTap: () => context.push('/video/${video.id}', extra: video),
          ),
        );
      },
    );
  }

  bool _hasVideoContent(Note note) {
    // Same logic as home screen - checking for video content
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

  void _handleMenuAction(BuildContext context, WidgetRef ref, String action, Profile? profile) {
    switch (action) {
      case 'copy_npub':
        final npub = Utils.encodeShareableFromString(pubkey, type: 'npub');
        Clipboard.setData(ClipboardData(text: npub));
        Fluttertoast.showToast(msg: 'npub copied to clipboard');
        break;
      case 'settings':
        // TODO: Navigate to settings screen
        break;
      case 'sign_out':
        _showSignOutDialog(context, ref);
        break;
    }
  }

  void _showSignOutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          AsyncButtonBuilder(
            onPressed: () async {
              await ref.read(authProvider.notifier).signOut();
              if (context.mounted) {
                context.go('/auth');
              }
            },
            child: const Text('Sign Out'),
            builder: (context, child, callback, _) => TextButton(
              onPressed: callback,
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, WidgetRef ref, Profile? profile) {
    // TODO: Implement profile editing dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: const Text('Profile editing will be implemented soon.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}