# Authentication Implementation for VeeLog

This document provides a complete implementation guide for authentication in the VeeLog Flutter Nostr app using Amber signer (NIP-55) and private key authentication.

## Overview

The authentication system supports two primary methods:
1. **Amber Signer (NIP-55)** - Recommended for production use
2. **Private Key Input** - For testing and development

## Implementation Components

### 1. Authentication Provider (`/lib/providers/auth_provider.dart`)

**Key Features:**
- Manages authentication state (user pubkey, profile, signer)
- Supports Amber signer (NIP-55) integration
- Handles private key authentication for testing
- Automatic profile loading and updates
- Profile management (update display name, about, etc.)
- Sign out functionality
- Persistence check on app startup

**Usage Example:**
```dart
// Sign in with Amber
await ref.read(authProvider.notifier).signInWithAmber();

// Check if user is authenticated
final isAuthenticated = ref.watch(isAuthenticatedProvider);

// Get current user
final currentUser = ref.watch(currentUserProvider);
final currentProfile = ref.watch(currentUserProfileProvider);

// Sign out
await ref.read(authProvider.notifier).signOut();
```

### 2. Authentication Screen (`/lib/screens/auth_screen.dart`)

**Features:**
- Clean Material 3 design with VeeLog branding
- Primary "Sign in with Amber" button
- Collapsible private key input for testing
- Error handling with user-friendly messages
- Loading states during authentication
- Information about Amber for new users

**Key Components:**
- Amber authentication button with async state management
- Private key input with visibility toggle
- Warning messages for security
- Automatic navigation on successful auth

### 3. Profile Screen (`/lib/screens/profile_screen.dart`)

**Features:**
- View user profiles (own or others)
- Display profile information (avatar, name, about, verification)
- List user's video posts
- Profile editing capabilities (framework provided)
- Copy npub functionality
- Sign out option for current user

**Navigation:**
- Accessible via `/profile/:pubkey` route
- Auto-detects if viewing current user profile

### 4. Updated Router (`/lib/router.dart`)

**Authentication Guard:**
- Redirects unauthenticated users to auth screen
- Redirects authenticated users away from auth screen
- Refreshes routes when authentication state changes
- Added profile route with pubkey parameter

### 5. Updated Home Screen (`/lib/screens/home_screen.dart`)

**User-Aware Features:**
- Shows current user avatar in app bar
- Tappable avatar navigates to user profile
- Authentication-aware content display

### 6. Updated Blossom Service (`/lib/services/blossom_service.dart`)

**Authentication Integration:**
- Requires authentication for creating video notes
- Throws descriptive errors for unauthenticated users
- Uses authenticated storage for saving/publishing

## Authentication Flow

### Amber Sign-In (NIP-55)
1. User taps "Sign in with Amber"
2. System checks if Amber app is available
3. Requests public key from Amber
4. Sets up Amber signer in storage
5. Updates authentication state
6. Loads user profile from Nostr network
7. Redirects to home screen

### Private Key Sign-In (Development)
1. User expands private key section
2. Enters nsec private key
3. System validates key format
4. Creates in-memory signer
5. Sets signer in storage
6. Updates authentication state
7. Loads user profile
8. Redirects to home screen

### Authentication Persistence
1. On app startup, check for existing signer
2. If signer exists, restore authentication state
3. Load current user profile
4. Continue to authenticated experience

## Security Considerations

### Amber Signer (Recommended)
- Private keys never leave the Amber app
- Secure key management handled by specialized app
- User controls which permissions to grant
- Compatible with NIP-55 protocol

### Private Key Input (Testing Only)
- Keys stored temporarily in memory
- Warning messages displayed to users
- Not recommended for production use
- Useful for development and testing

### Best Practices
- Always prefer Amber for production
- Clear warnings for private key input
- Secure storage integration via Purplebase
- Proper error handling and user feedback

## Error Handling

### Common Error Scenarios
- Amber app not installed
- User rejects authentication in Amber
- Invalid private key format
- Network errors during profile loading
- Storage initialization failures

### Error Display
- User-friendly error messages
- Visual error states in UI
- Toast notifications for actions
- Graceful degradation

## Integration Points

### Storage Integration
```dart
// Setting signer
storage.signer = amberSigner;

// Using authenticated storage
await ref.storage.save({model});
await ref.storage.publish({model});
```

### Profile Management
```dart
// Update profile
await authNotifier.updateProfile(
  displayName: 'New Name',
  about: 'Updated bio',
);

// Access current profile
final profile = ref.watch(currentUserProfileProvider);
```

### Route Protection
```dart
// Router automatically redirects based on auth state
redirect: (context, state) {
  final isAuthenticated = ref.read(isAuthenticatedProvider);
  // Redirect logic...
}
```

## Testing Guide

### Amber Testing
1. Install Amber app on device/simulator
2. Create test account in Amber
3. Use VeeLog auth screen to connect
4. Test sign-in flow and permissions

### Private Key Testing
1. Generate test keypair using Nostr tools
2. Use private key option in auth screen
3. Test with various key formats
4. Verify proper error handling

### Integration Testing
1. Test authentication persistence across app restarts
2. Verify profile loading and updates
3. Test video note creation with authentication
4. Verify sign-out clears all state

## Performance Considerations

- Authentication state checks are optimized with providers
- Profile loading uses hybrid local/remote sources
- Router redirects are efficient and minimal
- Storage operations are batched when possible

## Future Enhancements

### NIP-46 Remote Signer Support
The current implementation provides a foundation for adding NIP-46 remote signer support:

```dart
// Future NIP-46 implementation
Future<void> signInWithRemoteSigner(String bunkerUrl) async {
  final remoteSigner = RemoteSigner(bunkerUrl);
  // Connection and authentication logic
}
```

### Enhanced Profile Management
- Profile editing dialog implementation
- Media upload for avatars/banners
- Advanced profile fields
- Profile verification status

### Following System
- Following/follower relationships
- Following-based feed filtering
- Social graph integration
- Contact list management

## Dependencies

Required packages (already included in pubspec.yaml):
- `amber_signer: ^0.2.0` - Amber integration
- `models: ^0.3.3` - Nostr model definitions
- `purplebase: ^0.3.3` - Storage and relay management
- `hooks_riverpod: ^2.6.1` - State management
- `go_router: ^16.0.0` - Navigation
- `async_button_builder: ^3.0.0+1` - Async UI states

## Conclusion

This implementation provides a complete, production-ready authentication system for Nostr applications using Flutter. It follows Purplestack patterns and best practices while maintaining security and user experience standards.

The system is designed to be:
- **Secure** - Proper key management and storage
- **User-friendly** - Clear UI and error states  
- **Extensible** - Easy to add new auth methods
- **Maintainable** - Clean architecture and separation of concerns

For questions or enhancements, refer to the Purplestack documentation and Nostr protocol specifications.