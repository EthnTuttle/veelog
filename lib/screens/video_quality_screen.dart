import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:veelog/providers/video_quality_provider.dart';
import 'package:veelog/providers/nip05_provider.dart';

class VideoQualityScreen extends ConsumerWidget {
  const VideoQualityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nip05Verification = ref.watch(nip05VerificationProvider);
    final currentQuality = ref.watch(videoQualityProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5DEB3),
      appBar: AppBar(
        title: const Text('Video Quality'),
        backgroundColor: const Color(0xFF8B4513),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: nip05Verification.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorState(context),
        data: (isVerified) => isVerified 
            ? _buildQualitySettings(context, ref, currentQuality)
            : _buildVerificationRequired(context),
      ),
    );
  }

  Widget _buildVerificationRequired(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFFD2B48C),
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
                Icon(
                  Icons.verified_user,
                  size: 64,
                  color: const Color(0xFF654321),
                ),
                const SizedBox(height: 24),
                Text(
                  'NIP-05 Verification Required',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF654321),
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Video quality settings are available for users with verified NIP-05 identities from:',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B4513).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'virginiafreedom.tech',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF654321),
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'This helps ensure video quality features are used responsibly by verified community members.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF654321).withValues(alpha: 0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF654321),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Back to Settings'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualitySettings(BuildContext context, WidgetRef ref, VideoQualityLevel currentQuality) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFD2B48C),
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
                'Advanced video settings unlocked for virginiafreedom.tech users',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF654321).withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        Text(
          'Video Quality',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: const Color(0xFF654321),
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 16),
        
        ...VideoQualityLevel.values.map((quality) {
          final isSelected = currentQuality == quality;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFD2B48C),
              borderRadius: BorderRadius.circular(12),
              border: isSelected 
                  ? Border.all(color: const Color(0xFF654321), width: 2)
                  : null,
            ),
            child: RadioListTile<VideoQualityLevel>(
              title: Text(
                VideoQualitySettings.getQualityLabel(quality),
                style: TextStyle(
                  color: const Color(0xFF654321),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                VideoQualitySettings.getQualityDescription(quality),
                style: TextStyle(
                  color: const Color(0xFF8B4513).withValues(alpha: 0.8),
                ),
              ),
              value: quality,
              groupValue: currentQuality,
              onChanged: (value) {
                if (value != null) {
                  ref.read(videoQualityProvider.notifier).state = value;
                }
              },
              activeColor: const Color(0xFF654321),
            ),
          );
        }).toList(),
      ],
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