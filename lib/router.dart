import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:veelog/screens/home_screen.dart';
import 'package:veelog/screens/video_recording_screen.dart';
import 'package:veelog/screens/video_preview_screen.dart';
import 'package:veelog/screens/video_detail_screen.dart';
import 'package:veelog/screens/auth_screen.dart';
import 'package:veelog/screens/profile_screen.dart';
import 'package:veelog/screens/settings_screen.dart';
import 'package:veelog/screens/blossom_settings_screen.dart';
import 'package:veelog/providers/auth_provider.dart';
import 'package:models/models.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isAuthenticated = ref.read(isAuthenticatedProvider);
      final isAuthPage = state.fullPath == '/auth';
      
      // Redirect to auth page if not authenticated
      if (!isAuthenticated && !isAuthPage) {
        return '/auth';
      }
      
      // Redirect to home if authenticated and on auth page
      if (isAuthenticated && isAuthPage) {
        return '/';
      }
      
      return null;
    },
    routes: [
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/record',
        builder: (context, state) => const VideoRecordingScreen(),
      ),
      GoRoute(
        path: '/video-preview',
        builder: (context, state) {
          final videoPath = state.extra as String;
          return VideoPreviewScreen(videoPath: videoPath);
        },
      ),
      GoRoute(
        path: '/video/:noteId',
        builder: (context, state) {
          final note = state.extra as Note;
          return VideoDetailScreen(videoNote: note);
        },
      ),
      GoRoute(
        path: '/profile/:pubkey',
        builder: (context, state) {
          final pubkey = state.pathParameters['pubkey']!;
          final currentUser = ref.read(currentUserPubkeyProvider);
          return ProfileScreen(
            pubkey: pubkey,
            isCurrentUser: pubkey == currentUser,
          );
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/blossom',
        builder: (context, state) => const BlossomSettingsScreen(),
      ),
    ],
    refreshListenable: GoRouterRefreshStream(ref),
  );
});

// Helper class for router refresh
class GoRouterRefreshStream extends ChangeNotifier {
  late final ProviderSubscription _subscription;

  GoRouterRefreshStream(Ref ref) {
    _subscription = ref.listen(
      isAuthenticatedProvider,
      (previous, next) {
        notifyListeners();
      },
      fireImmediately: false,
    );
  }

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}
