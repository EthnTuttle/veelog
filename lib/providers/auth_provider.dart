import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:amber_signer/amber_signer.dart';

class AuthState {
  final bool isAuthenticated;
  final String? pubkey;
  final Profile? profile;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.isAuthenticated = false,
    this.pubkey,
    this.profile,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    String? pubkey,
    Profile? profile,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      pubkey: pubkey ?? this.pubkey,
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref ref;

  AuthNotifier(this.ref) : super(const AuthState());

  Future<void> signInWithAmber() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Create and sign in with Amber signer
      final signer = ref.read(amberSignerProvider);
      await signer.signIn();

      // Get the active pubkey after sign-in
      final pubkey = ref.read(Signer.activePubkeyProvider);
      if (pubkey == null) {
        throw Exception('Failed to get public key from Amber');
      }

      // Load user profile
      await _loadUserProfile(pubkey);

      state = state.copyWith(
        isAuthenticated: true,
        pubkey: pubkey,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Amber sign-in failed: ${e.toString()}',
      );
    }
  }

  Future<void> signInWithPrivateKey(String nsec) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Decode private key
      final privateKey = Utils.decodeShareableToString(nsec);
      final pubkey = Utils.derivePublicKey(privateKey);

      // Create in-memory signer and sign in
      final signer = Bip340PrivateKeySigner(privateKey, ref);
      await signer.signIn();

      // Load user profile
      await _loadUserProfile(pubkey);

      state = state.copyWith(
        isAuthenticated: true,
        pubkey: pubkey,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Private key sign-in failed: ${e.toString()}',
      );
    }
  }

  Future<void> _loadUserProfile(String pubkey) async {
    try {
      // Use direct storage query for profile loading
      final profileRequest = RequestFilter<Profile>(
        authors: {pubkey},
        limit: 1,
      ).toRequest();

      final profiles = await ref.read(storageNotifierProvider.notifier).query(
        profileRequest,
        source: LocalAndRemoteSource(background: false),
      );

      if (profiles.isNotEmpty) {
        state = state.copyWith(profile: profiles.first);
      }
    } catch (e) {
      debugPrint('Failed to load user profile: $e');
    }
  }

  Future<void> signOut() async {
    try {
      // Sign out from active signer
      final activeSigner = ref.read(Signer.activeSignerProvider);
      if (activeSigner != null) {
        await activeSigner.signOut();
      }
      
      state = const AuthState();
    } catch (e) {
      debugPrint('Sign-out error: $e');
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  Future<void> checkAuthStatus() async {
    try {
      // Check if there's an active signer
      final pubkey = ref.read(Signer.activePubkeyProvider);
      if (pubkey != null) {
        // Load profile for the active user
        await _loadUserProfile(pubkey);
        state = state.copyWith(
          isAuthenticated: true,
          pubkey: pubkey,
        );
      }
    } catch (e) {
      debugPrint('Error checking auth status: $e');
    }
  }
}

// Amber signer provider
final amberSignerProvider = Provider<AmberSigner>((ref) {
  return AmberSigner(ref);
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

// Convenience provider for checking if user is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(Signer.activePubkeyProvider) != null;
});

// Convenience provider for getting current user's pubkey
final currentUserPubkeyProvider = Provider<String?>((ref) {
  return ref.watch(Signer.activePubkeyProvider);
});

// Convenience provider for getting current user's profile
final currentUserProfileProvider = Provider<Profile?>((ref) {
  final profile = ref.watch(Signer.activeProfileProvider(LocalAndRemoteSource()));
  return profile;
});