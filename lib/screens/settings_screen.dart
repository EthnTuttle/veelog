import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:veelog/providers/auth_provider.dart';
import 'package:veelog/providers/display_settings_provider.dart';
import 'package:veelog/widgets/common/profile_avatar.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:models/models.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final currentProfile = authState.profile;

    return Scaffold(
      backgroundColor: const Color(0xFFF5DEB3), // Wheat background
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF8B4513), // Wood brown
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User Profile Section
          if (authState.isAuthenticated) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFD2B48C), // Tan
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B4513).withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Profile avatar and info
                  Row(
                    children: [
                      ProfileAvatar(
                        profile: currentProfile,
                        radius: 32,
                        borderColors: [
                          const Color(0xFF654321),
                          const Color(0xFF8B4513),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentProfile?.nameOrNpub ?? 'Unnamed',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: const Color(0xFF654321),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () => _copyToClipboard(
                                context,
                                Utils.encodeShareableFromString(authState.pubkey!, type: 'npub'),
                                'npub copied!',
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8, 
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B4513).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  Utils.encodeShareableFromString(authState.pubkey!, type: 'npub'),
                                  style: const TextStyle(
                                    color: Color(0xFF654321),
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Edit Profile Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // TODO: Navigate to profile edit screen
                        context.push('/profile/${authState.pubkey}');
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('View Profile'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF654321),
                        side: const BorderSide(color: Color(0xFF654321)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],

          // App Settings Section
          _buildSettingsSection(
            context,
            'App Settings',
            [
              _buildSettingsTile(
                context,
                icon: Icons.palette,
                title: 'Theme',
                subtitle: 'Customize app appearance',
                onTap: () => context.push('/settings/theme'),
              ),
              _buildDisplayModeTile(context, ref),
              _buildSettingsTile(
                context,
                icon: Icons.videocam,
                title: 'Video Quality',
                subtitle: 'Requires NIP-05 verification',
                onTap: () => context.push('/settings/video-quality'),
              ),
              _buildSettingsTile(
                context,
                icon: Icons.storage,
                title: 'Blossom Servers',
                subtitle: 'Configure video upload servers',
                onTap: () {
                  context.push('/settings/blossom');
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // About Section
          _buildSettingsSection(
            context,
            'About',
            [
              _buildSettingsTile(
                context,
                icon: Icons.info,
                title: 'Version',
                subtitle: '0.1.0',
                onTap: () {},
              ),
              _buildSettingsTile(
                context,
                icon: Icons.code,
                title: 'Source Code',
                subtitle: 'View on GitHub',
                onTap: () => _openGitHubRepo(),
              ),
              _buildSettingsTile(
                context,
                icon: Icons.favorite,
                title: 'Powered by Purplestack',
                subtitle: 'Nostr development framework',
                onTap: () => _openPurpleStackSite(),
              ),
            ],
          ),

          // Sign Out (if authenticated)
          if (authState.isAuthenticated) ...[
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(authProvider.notifier).signOut();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red[700],
                  side: BorderSide(color: Colors.red[300]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(
    BuildContext context,
    String title,
    List<Widget> tiles,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(children: tiles),
        ),
      ],
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF8B4513).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: const Color(0xFF654321),
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }

  Widget _buildDisplayModeTile(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(displayModeProvider);
    
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF8B4513).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.view_list,
          color: Theme.of(context).colorScheme.primary,
          size: 20,
        ),
      ),
      title: Text(
        'Display Mode',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        _getDisplayModeLabel(currentMode),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onTap: () => _showDisplayModeDialog(context, ref),
    );
  }

  String _getDisplayModeLabel(DisplayMode mode) {
    switch (mode) {
      case DisplayMode.robust:
        return 'Robust - Maximum video metadata';
      case DisplayMode.compact:
        return 'Compact - Minimal space';
      case DisplayMode.standard:
        return 'Standard - Balanced view';
    }
  }

  void _showDisplayModeDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Display Mode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: DisplayMode.values.map((mode) {
            return RadioListTile<DisplayMode>(
              title: Text(_getDisplayModeLabel(mode)),
              value: mode,
              groupValue: ref.read(displayModeProvider),
              onChanged: (value) {
                if (value != null) {
                  ref.read(displayModeProvider.notifier).state = value;
                  Navigator.of(context).pop();
                }
              },
              activeColor: Theme.of(context).colorScheme.primary,
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
  }
  
  void _openGitHubRepo() async {
    const url = 'https://github.com/EthnTuttle/veelog';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }
  
  void _openPurpleStackSite() async {
    const url = 'https://github.com/purplebase/purplestack';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }
}