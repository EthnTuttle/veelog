# VeeLog 🪵

A simple Nostr vlogging application for recording and sharing short video clips.

## Features

- 📹 **60-Second Video Recording** - Quick video capture with front/back camera switching
- 🌐 **Blossom File Storage** - Decentralized file hosting via Blossom protocol  
- ⚡ **Nostr Integration** - Share videos on the decentralized Nostr network
- 🎨 **Material 3 UI** - Modern design with light/dark theme support
- 📱 **Mobile Optimized** - Native Android experience with proper permissions

## How It Works

1. **Record**: Tap the camera button to record up to 60-second video clips
2. **Preview**: Review your video and add a description
3. **Upload**: Videos are uploaded to Blossom servers (primal.net & nostr.build)
4. **Share**: Posted to Nostr network for decentralized discovery and engagement

## Technical Stack

- **Flutter/Dart** - Cross-platform mobile framework
- **Purplebase** - Nostr SDK for Flutter with local-first architecture
- **Blossom Protocol** - Decentralized file storage for videos
- **Camera Package** - Native camera integration with permission handling
- **Chewie Player** - Professional video playback with controls

## Development

```bash
# Get dependencies
flutter pub get

# Run the app
flutter run

# Build for release
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

## Privacy & Decentralization

VeeLog is built on open protocols:
- **No central servers** - Videos stored on Blossom network
- **No accounts** - Uses Nostr keypairs for identity
- **No tracking** - Fully decentralized architecture
- **Open source** - Transparent and auditable code

---

Powered by [Purplestack](https://purplestack.io)