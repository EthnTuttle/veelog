import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:veelog/providers/auth_provider.dart';

final nip05VerificationProvider = FutureProvider<bool>((ref) async {
  final currentUser = ref.watch(currentUserProfileProvider);
  
  if (currentUser?.nip05 == null || currentUser!.nip05!.isEmpty) {
    return false;
  }
  
  // Check if NIP-05 is verified with virginiafreedom.tech
  return _verifyNip05Domain(currentUser.nip05!, 'virginiafreedom.tech');
});

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