import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:veelog/providers/auth_provider.dart';

final nip05VerificationProvider = FutureProvider<bool>((ref) async {
  final currentUserPubkey = ref.watch(currentUserPubkeyProvider);
  
  if (currentUserPubkey == null) {
    return false;
  }
  
  // Check if the user's npub exists in virginiafreedom.tech's NIP-05 registry
  return _verifyNpubInRegistry(currentUserPubkey);
});

Future<bool> _verifyNpubInRegistry(String pubkey) async {
  try {
    final response = await http.get(
      Uri.parse('https://virginiafreedom.tech/.well-known/nostr.json'),
      headers: {'Accept': 'application/json'},
    );
    
    if (response.statusCode != 200) {
      return false;
    }
    
    final data = json.decode(response.body) as Map<String, dynamic>;
    final names = data['names'] as Map<String, dynamic>?;
    
    if (names == null) return false;
    
    // Check if the pubkey exists in any of the NIP-05 entries
    return names.values.contains(pubkey);
  } catch (e) {
    debugPrint('NIP-05 verification error: $e');
    return false;
  }
}

Future<bool> _verifyNip05Domain(String nip05, String requiredDomain) async {
  try {
    // Parse NIP-05 identifier (name@domain)
    final parts = nip05.split('@');
    if (parts.length != 2) return false;
    
    final domain = parts[1].toLowerCase();
    
    // Check if domain matches required domain
    return domain == requiredDomain.toLowerCase();
  } catch (e) {
    return false;
  }
}