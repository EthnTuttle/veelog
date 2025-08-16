import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:veelog/providers/auth_provider.dart';

// Provider to get current user's following list
final followingListProvider = Provider<Set<String>>((ref) {
  final currentUser = ref.watch(currentUserPubkeyProvider);
  if (currentUser == null) return <String>{};
  
  final contactListState = ref.watch(
    query<ContactList>(
      authors: {currentUser},
      source: LocalAndRemoteSource(),
    ),
  );
  
  return switch (contactListState) {
    StorageData(:final models) when models.isNotEmpty => 
        models.first.followingPubkeys,
    _ => <String>{},
  };
});

// Provider to check if following a specific user
final isFollowingProvider = Provider.family<bool, String>((ref, pubkey) {
  final followingList = ref.watch(followingListProvider);
  return followingList.contains(pubkey);
});

// Provider for following actions
final followingActionsProvider = Provider<FollowingActions>((ref) {
  return FollowingActions(ref);
});

class FollowingActions {
  final Ref ref;
  
  FollowingActions(this.ref);
  
  Future<void> followUser(String pubkeyToFollow) async {
    final currentUser = ref.read(currentUserPubkeyProvider);
    if (currentUser == null) return;
    
    try {
      // Get current following list
      final currentFollowingList = ref.read(followingListProvider);
      final updatedFollowing = {...currentFollowingList, pubkeyToFollow};
      
      // Create contact list with followed users
      final contactList = PartialContactList(
        followPubkeys: updatedFollowing,
      );
      
      // Save and publish
      await ref.read(storageNotifierProvider.notifier).save({contactList as Model});
      await ref.read(storageNotifierProvider.notifier).publish({contactList as Model});
    } catch (e) {
      throw Exception('Failed to follow user: $e');
    }
  }
  
  Future<void> unfollowUser(String pubkeyToUnfollow) async {
    final currentUser = ref.read(currentUserPubkeyProvider);
    if (currentUser == null) return;
    
    try {
      // Get current following list
      final currentFollowingList = ref.read(followingListProvider);
      final updatedFollowing = currentFollowingList.where((pubkey) => pubkey != pubkeyToUnfollow).toSet();
      
      // Create contact list with updated following
      final contactList = PartialContactList(
        followPubkeys: updatedFollowing,
      );
      
      // Save and publish
      await ref.read(storageNotifierProvider.notifier).save({contactList as Model});
      await ref.read(storageNotifierProvider.notifier).publish({contactList as Model});
    } catch (e) {
      throw Exception('Failed to unfollow user: $e');
    }
  }
}