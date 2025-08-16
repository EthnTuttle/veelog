import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:async_button_builder/async_button_builder.dart';
import 'package:veelog/providers/following_provider.dart';
import 'package:veelog/providers/auth_provider.dart';
import 'package:fluttertoast/fluttertoast.dart';

class FollowButton extends HookConsumerWidget {
  final String targetPubkey;

  const FollowButton({
    super.key,
    required this.targetPubkey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserPubkeyProvider);
    final isFollowing = ref.watch(isFollowingProvider(targetPubkey));
    
    // Don't show follow button for self
    if (currentUser == targetPubkey) {
      return const SizedBox.shrink();
    }

    return AsyncButtonBuilder(
      onPressed: () async {
        try {
          final actions = ref.read(followingActionsProvider);
          if (isFollowing) {
            await actions.unfollowUser(targetPubkey);
            Fluttertoast.showToast(msg: 'Unfollowed');
          } else {
            await actions.followUser(targetPubkey);
            Fluttertoast.showToast(msg: 'Following');
          }
        } catch (e) {
          Fluttertoast.showToast(
            msg: 'Failed: ${e.toString()}',
            backgroundColor: Colors.red,
          );
        }
      },
      child: Text(isFollowing ? 'Unfollow' : 'Follow'),
      builder: (context, child, callback, buttonState) {
        return isFollowing
            ? OutlinedButton(
                onPressed: buttonState.maybeWhen(
                  loading: () => null,
                  orElse: () => callback,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF654321),
                  side: const BorderSide(color: Color(0xFF654321)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: buttonState.maybeWhen(
                  loading: () => const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  orElse: () => child,
                ),
              )
            : ElevatedButton(
                onPressed: buttonState.maybeWhen(
                  loading: () => null,
                  orElse: () => callback,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF654321),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: buttonState.maybeWhen(
                  loading: () => const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  orElse: () => child,
                ),
              );
      },
    );
  }
}