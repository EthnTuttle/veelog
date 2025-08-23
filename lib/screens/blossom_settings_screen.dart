import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:veelog/providers/blossom_config_provider.dart';

class BlossomSettingsScreen extends HookConsumerWidget {
  const BlossomSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servers = ref.watch(blossomConfigProvider);
    final notifier = ref.read(blossomConfigProvider.notifier);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface, // Wheat background
      appBar: AppBar(
        title: const Text('Blossom Servers'),
        backgroundColor: Theme.of(context).colorScheme.primary, // Wood brown
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              notifier.resetToDefaults();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reset to default servers')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Info banner
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer, // Tan
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.onSurface,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Upload Strategy',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Videos are uploaded to all enabled servers in parallel. The first successful upload is used.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // Server list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: servers.length,
              itemBuilder: (context, index) {
                final server = servers[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer, // Tan
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: server.enabled 
                          ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)
                          : Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: server.enabled 
                            ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)
                            : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        server.enabled ? Icons.cloud_upload : Icons.cloud_off,
                        color: server.enabled 
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      server.name,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          server.url,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                        ),
                        if (server.requiresAuth)
                          Text(
                            'Requires authentication',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                    trailing: Switch(
                      value: server.enabled,
                      onChanged: (value) => notifier.toggleServer(index),
                      activeThumbColor: Theme.of(context).colorScheme.onSurface,
                      activeTrackColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                  ),
                );
              },
            ),
          ),

          // Add custom server button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showAddServerDialog(context, notifier),
                icon: const Icon(Icons.add),
                label: const Text('Add Custom Server'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  side: const BorderSide(color: Color(0xFF654321)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddServerDialog(BuildContext context, BlossomConfigNotifier notifier) {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    final requiresAuth = ValueNotifier<bool>(false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Blossom Server'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Server Name',
                hintText: 'e.g., My Server',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                hintText: 'https://my-blossom-server.com',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder<bool>(
              valueListenable: requiresAuth,
              builder: (context, value, child) {
                return CheckboxListTile(
                  value: value,
                  onChanged: (newValue) => requiresAuth.value = newValue ?? false,
                  title: const Text('Requires Authentication'),
                  controlAffinity: ListTileControlAffinity.leading,
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.isNotEmpty && urlController.text.isNotEmpty) {
                notifier.addServer(BlossomServerConfig(
                  name: nameController.text,
                  url: urlController.text,
                  requiresAuth: requiresAuth.value,
                ));
                Navigator.of(context).pop();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}