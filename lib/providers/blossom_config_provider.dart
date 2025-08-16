import 'package:hooks_riverpod/hooks_riverpod.dart';

class BlossomServerConfig {
  final String url;
  final String name;
  final bool requiresAuth;
  final bool enabled;

  const BlossomServerConfig({
    required this.url,
    required this.name,
    this.requiresAuth = false,
    this.enabled = true,
  });

  BlossomServerConfig copyWith({
    String? url,
    String? name,
    bool? requiresAuth,
    bool? enabled,
  }) {
    return BlossomServerConfig(
      url: url ?? this.url,
      name: name ?? this.name,
      requiresAuth: requiresAuth ?? this.requiresAuth,
      enabled: enabled ?? this.enabled,
    );
  }
}

class BlossomConfigNotifier extends StateNotifier<List<BlossomServerConfig>> {
  BlossomConfigNotifier() : super(_defaultServers);

  static const List<BlossomServerConfig> _defaultServers = [
    BlossomServerConfig(
      url: 'https://blossom.primal.net',
      name: 'Primal',
      requiresAuth: true,
      enabled: true, // Primary server - enabled by default
    ),
    BlossomServerConfig(
      url: 'https://blossom.nostr.build',
      name: 'Nostr.build',
      requiresAuth: true, // Enable auth for proper compatibility
      enabled: false, // Disabled by default
    ),
    BlossomServerConfig(
      url: 'https://cdn.satellite.earth',
      name: 'Satellite.earth',
      requiresAuth: true, // Enable auth for proper compatibility
      enabled: false, // Disabled by default
    ),
    BlossomServerConfig(
      url: 'https://files.sovbit.host',
      name: 'Sovbit',
      requiresAuth: true, // Enable auth for proper compatibility
      enabled: false, // Disabled by default
    ),
  ];

  void toggleServer(int index) {
    if (index >= 0 && index < state.length) {
      final servers = List<BlossomServerConfig>.from(state);
      servers[index] = servers[index].copyWith(enabled: !servers[index].enabled);
      state = servers;
    }
  }

  void addServer(BlossomServerConfig server) {
    state = [...state, server];
  }

  void removeServer(int index) {
    if (index >= 0 && index < state.length) {
      final servers = List<BlossomServerConfig>.from(state);
      servers.removeAt(index);
      state = servers;
    }
  }

  void updateServer(int index, BlossomServerConfig server) {
    if (index >= 0 && index < state.length) {
      final servers = List<BlossomServerConfig>.from(state);
      servers[index] = server;
      state = servers;
    }
  }

  void resetToDefaults() {
    state = _defaultServers;
  }

  List<BlossomServerConfig> get enabledServers => state.where((s) => s.enabled).toList();
}

final blossomConfigProvider = StateNotifierProvider<BlossomConfigNotifier, List<BlossomServerConfig>>((ref) {
  return BlossomConfigNotifier();
});

final enabledBlossomServersProvider = Provider<List<BlossomServerConfig>>((ref) {
  final config = ref.watch(blossomConfigProvider);
  return config.where((s) => s.enabled).toList();
});