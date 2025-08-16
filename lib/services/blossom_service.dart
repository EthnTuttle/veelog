import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:models/models.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:veelog/providers/auth_provider.dart';
import 'package:veelog/providers/blossom_config_provider.dart';

class BlossomService {
  static const List<String> defaultServers = [
    'https://blossom.nostr.build',      // Usually doesn't require auth
    'https://cdn.satellite.earth',      // Public server
    'https://files.sovbit.host',        // Public server
    'https://blossom.primal.net',       // Requires auth - try last
  ];

  final Ref ref;

  BlossomService(this.ref);

  Future<BlossomUploadResult> uploadFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw BlossomException('File not found: $filePath');
    }

    final fileBytes = await file.readAsBytes();
    final fileName = file.path.split('/').last;
    final mimeType = lookupMimeType(filePath) ?? 'application/octet-stream';
    
    // The x tag should contain the SHA256 of the raw file content, not the multipart body
    final sha256Hash = sha256.convert(fileBytes).toString().toLowerCase();

    debugPrint('Starting upload: $fileName (${(fileBytes.length / 1024 / 1024).toStringAsFixed(1)}MB)');
    debugPrint('File SHA256: $sha256Hash');
    debugPrint('File size: ${fileBytes.length} bytes');
    
    // Get enabled servers from configuration
    final enabledServers = ref.read(enabledBlossomServersProvider);
    if (enabledServers.isEmpty) {
      throw BlossomException('No Blossom servers configured');
    }

    debugPrint('Attempting parallel upload to ${enabledServers.length} servers');
    
    // Launch parallel uploads to all enabled servers
    final uploadFutures = enabledServers.map((serverConfig) {
      return _uploadToServerWithConfig(
        serverConfig,
        fileBytes,
        fileName,
        mimeType,
        sha256Hash,
      );
    }).toList();

    try {
      // Wait for the first successful upload
      final result = await Future.any(uploadFutures);
      debugPrint('Upload completed successfully (parallel)');
      return result;
    } catch (e) {
      // If all uploads fail, provide detailed error
      debugPrint('All parallel uploads failed');
      
      // Wait a bit for other uploads to complete to get better error info
      await Future.delayed(const Duration(seconds: 2));
      
      throw BlossomException('Failed to upload to any Blossom server: $e');
    }
  }

  Future<BlossomUploadResult> _uploadToServerWithConfig(
    BlossomServerConfig serverConfig,
    List<int> fileBytes,
    String fileName,
    String mimeType,
    String sha256Hash,
  ) async {
    final uploadUrl = '${serverConfig.url}/upload';
    
    try {
      debugPrint('Attempting upload to ${serverConfig.name} (${(fileBytes.length / 1024 / 1024).toStringAsFixed(1)}MB)');
      
      // Create raw PUT request with file bytes (matching Primal/Amethyst pattern)
      final request = http.Request('PUT', Uri.parse(uploadUrl));
      request.bodyBytes = fileBytes;

      // Add headers
      request.headers.addAll({
        'Accept': 'application/json',
        'User-Agent': 'VeeLog/1.0.0',
        'Content-Type': mimeType,
        'Content-Length': fileBytes.length.toString(),
      });

      // Add authentication if required
      if (serverConfig.requiresAuth) {
        final activeSigner = ref.read(Signer.activeSignerProvider);
        final activePubkey = ref.read(Signer.activePubkeyProvider);
        
        if (activeSigner != null && activePubkey != null) {
          try {
            final authEvent = await _createAuthEvent(uploadUrl, activeSigner, sha256Hash, fileBytes.length);
            request.headers['Authorization'] = 'Nostr ${base64.encode(utf8.encode(json.encode(authEvent)))}';
            debugPrint('Added Blossom authentication for ${serverConfig.name}');
          } catch (e) {
            debugPrint('Failed to create auth event for ${serverConfig.name}: $e');
            throw BlossomException('Auth failed for ${serverConfig.name}: $e');
          }
        } else {
          debugPrint('Skipping ${serverConfig.name} - requires auth but user not authenticated (signer: ${activeSigner != null}, pubkey: ${activePubkey != null})');
          throw BlossomException('${serverConfig.name} requires authentication');
        }
      }

      // Send request with timeout
      final response = await http.Client().send(request).then(http.Response.fromStream).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw BlossomException('Upload timeout after 30 seconds to ${serverConfig.name}');
        },
      );
      
      debugPrint('Upload response status from ${serverConfig.name}: ${response.statusCode}');

      debugPrint('Upload response body from ${serverConfig.name}: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final responseData = json.decode(response.body);
          
          // Parse response based on Blossom spec
          final url = responseData['url'] as String?;
          final sha256 = responseData['sha256'] as String?;
          final size = responseData['size'] as int?;
          
          if (url == null) {
            throw BlossomException('${serverConfig.name} did not return URL in response');
          }

          debugPrint('Upload successful to ${serverConfig.name}: $url');
          return BlossomUploadResult(
            url: url,
            sha256: sha256 ?? sha256Hash,
            size: size ?? fileBytes.length,
            mimeType: mimeType,
            serverUrl: serverConfig.url,
            serverName: serverConfig.name,
          );
        } catch (e) {
          throw BlossomException('Failed to parse ${serverConfig.name} response: $e');
        }
      } else {
        throw BlossomException(
          '${serverConfig.name} upload failed with status ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      if (e is BlossomException) rethrow;
      throw BlossomException('Network error with ${serverConfig.name}: $e');
    }
  }


  Future<void> createVideoNote({
    required String description,
    required BlossomUploadResult uploadResult,
    List<String> hashtags = const [],
  }) async {
    // Check if user is authenticated
    final authState = ref.read(authProvider);
    if (!authState.isAuthenticated) {
      throw BlossomException('User must be authenticated to create video notes');
    }

    try {
      // Create content with video URL
      final content = description.isNotEmpty 
          ? '$description\n\n${uploadResult.url}'
          : uploadResult.url;

      // Combine all tags (include video metadata)
      final allTags = <String>[
        ...hashtags.map((tag) => 't $tag'),
        'imeta', // Mark as having media metadata
      ];

      final partialNote = PartialNote(
        content,
        tags: {...allTags, ...hashtags},
      );

      // Sign and save the note
      final activeSigner = ref.read(Signer.activeSignerProvider);
      if (activeSigner != null) {
        final signedNotes = await activeSigner.sign([partialNote]);
        await ref.storage.save(signedNotes.toSet());
        await ref.storage.publish(signedNotes.toSet());
      } else {
        throw BlossomException('No active signer available for creating video note');
      }

      // The note will be available in storage after saving
      // UI will update via providers
    } catch (e) {
      throw BlossomException('Failed to create video note: $e');
    }
  }

  Future<Map<String, dynamic>> _createAuthEvent(String url, Signer signer, String fileHash, int fileSize) async {
    try {
      // Create Blossom auth event based on Amethyst's implementation
      // Using the proper PartialBlossomAuthorization model with SHA256 hash and size
      final authEvent = PartialBlossomAuthorization()
        ..type = BlossomAuthorizationType.upload
        ..hash = fileHash // SHA256 file hash - this was the missing piece!
        ..expiration = DateTime.now().add(const Duration(hours: 1))
        ..content = 'Upload File';
      
      // Add size tag manually (Amethyst pattern)
      authEvent.event.addTagValue('size', fileSize.toString());

      final signedEvents = await signer.sign([authEvent]);
      final signedEvent = signedEvents.first;
      
      final authEventMap = {
        'id': signedEvent.event.id,
        'pubkey': signedEvent.event.pubkey,
        'created_at': signedEvent.event.createdAt.millisecondsSinceEpoch ~/ 1000,
        'kind': signedEvent.event.kind,
        'tags': signedEvent.event.tags,
        'content': signedEvent.event.content,
        'sig': signedEvent.event.signature,
      };
      
      debugPrint('Blossom auth event: ${json.encode(authEventMap)}');
      return authEventMap;
    } catch (e) {
      debugPrint('Error creating Blossom auth event: $e');
      throw BlossomException('Failed to create authentication: $e');
    }
  }
}

class BlossomUploadResult {
  final String url;
  final String sha256;
  final int size;
  final String mimeType;
  final String serverUrl;
  final String serverName;

  BlossomUploadResult({
    required this.url,
    required this.sha256,
    required this.size,
    required this.mimeType,
    required this.serverUrl,
    required this.serverName,
  });

  @override
  String toString() {
    return 'BlossomUploadResult(url: $url, size: $size, server: $serverName)';
  }
}

class BlossomException implements Exception {
  final String message;

  BlossomException(this.message);

  @override
  String toString() => 'BlossomException: $message';
}

final blossomServiceProvider = Provider<BlossomService>((ref) {
  return BlossomService(ref);
});