import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:veelog/providers/theme_provider.dart';
import 'package:veelog/providers/nip05_provider.dart';

class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nip05Verification = ref.watch(nip05VerificationProvider);
    final currentTheme = ref.watch(themeProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Theme Settings'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: nip05Verification.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorState(context),
        data: (isVerified) => _buildThemeSettings(context, ref, currentTheme, isVerified),
      ),
    );
  }

  Widget _buildThemeSettings(BuildContext context, WidgetRef ref, AppTheme currentTheme, bool isVerified) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (isVerified) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.verified,
                      color: Colors.green[600],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'NIP-05 Verified',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Premium themes unlocked for virginiafreedom.tech users',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        
        Text(
          'Available Themes',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Wood Theme (always available)
        _buildThemeCard(
          context,
          ref,
          AppTheme.wood,
          'Wood Theme',
          'Warm, natural wood-inspired colors',
          const Color(0xFF8B4513),
          const Color(0xFFD2B48C),
          const Color(0xFF654321),
          currentTheme == AppTheme.wood,
          true, // Always enabled
        ),
        
        const SizedBox(height: 12),
        
        const SizedBox(height: 12),
        
        // Nostr Theme (requires verification)
        _buildThemeCard(
          context,
          ref,
          AppTheme.nostr,
          'Nostr Theme',
          'Purple-themed design inspired by Nostr protocol',
          const Color(0xFF7C3AED),
          const Color(0xFFA855F7),
          const Color(0xFFE879F9),
          currentTheme == AppTheme.nostr,
          isVerified,
        ),
        
        const SizedBox(height: 12),
        
        // Bitcoin Theme (requires verification)
        _buildThemeCard(
          context,
          ref,
          AppTheme.bitcoin,
          'Bitcoin Theme',
          'Orange-themed design inspired by Bitcoin',
          const Color(0xFFF7931A),
          const Color(0xFFFB923C),
          const Color(0xFFFED7AA),
          currentTheme == AppTheme.bitcoin,
          isVerified,
        ),
        
        if (!isVerified) ...[
          const SizedBox(height: 24),
          _buildVerificationInfo(context),
        ],
      ],
    );
  }

  Widget _buildThemeCard(
    BuildContext context,
    WidgetRef ref,
    AppTheme theme,
    String title,
    String description,
    Color color1,
    Color color2,
    Color color3,
    bool isSelected,
    bool isEnabled,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: isSelected 
            ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        enabled: isEnabled,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: color1,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: color2,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: color3,
                shape: BoxShape.circle,
                border: color3 == Colors.white ? Border.all(color: Colors.grey[300]!) : null,
              ),
            ),
          ],
        ),
        title: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                color: isEnabled ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (!isEnabled) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.lock,
                size: 16,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ],
          ],
        ),
        subtitle: Text(
          description,
          style: TextStyle(
            color: isEnabled 
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        trailing: isSelected
            ? Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              )
            : null,
        onTap: isEnabled
            ? () => ref.read(themeProvider.notifier).state = theme
            : null,
      ),
    );
  }

  Widget _buildVerificationInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info,
                color: Colors.amber[700],
              ),
              const SizedBox(width: 8),
              Text(
                'How to unlock premium themes',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.amber[800],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '1. Get a NIP-05 identifier from virginiafreedom.tech\n'
            '2. Add it to your Nostr profile\n'
            '3. Restart VeeLog to verify your identity\n'
            '4. Premium themes will be unlocked automatically',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.amber[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
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
            'Error checking verification',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.pop(),
            child: const Text('Back'),
          ),
        ],
      ),
    );
  }
}