import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:veelog/providers/nip05_provider.dart';

enum AppTheme {
  wood,
  nostr,
  bitcoin,
}

final themeProvider = StateProvider<AppTheme>((ref) => AppTheme.wood);

final availableThemesProvider = Provider<List<AppTheme>>((ref) {
  final nip05Verification = ref.watch(nip05VerificationProvider);
  
  return nip05Verification.when(
    data: (isVerified) => isVerified ? AppTheme.values : [AppTheme.wood],
    loading: () => [AppTheme.wood],
    error: (_, __) => [AppTheme.wood],
  );
});

class AppThemes {
  static ThemeData get woodTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF8B4513), // Wood brown
      brightness: Brightness.light,
    ).copyWith(
      surface: const Color(0xFFF5DEB3), // Wheat
      onSurface: const Color(0xFF654321), // Dark wood
      primary: const Color(0xFF8B4513), // Wood brown
      secondary: const Color(0xFFD2B48C), // Tan
    ),
  );

  static ThemeData get woodDarkTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF8B4513),
      brightness: Brightness.dark,
    ).copyWith(
      surface: const Color(0xFF2D1B0E), // Dark wood
      onSurface: const Color(0xFFF5DEB3), // Light wheat
      primary: const Color(0xFFD2B48C), // Tan
      secondary: const Color(0xFF8B4513), // Wood brown
    ),
  );

  static ThemeData get nostrTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF7C3AED), // Purple
      brightness: Brightness.light,
    ).copyWith(
      surface: const Color(0xFFFAF5FF), // Light purple tint
      onSurface: const Color(0xFF581C87), // Dark purple
      primary: const Color(0xFF7C3AED), // Purple
      secondary: const Color(0xFFA855F7), // Light purple
      tertiary: const Color(0xFFE879F9), // Pink purple
    ),
  );

  static ThemeData get nostrDarkTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF7C3AED),
      brightness: Brightness.dark,
    ).copyWith(
      surface: const Color(0xFF1E1B2E), // Dark purple
      onSurface: const Color(0xFFFAF5FF), // Light purple
      primary: const Color(0xFFA855F7), // Bright purple
      secondary: const Color(0xFF7C3AED), // Purple
      tertiary: const Color(0xFFE879F9), // Pink purple
    ),
  );

  static ThemeData get bitcoinTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFF7931A), // Bitcoin orange
      brightness: Brightness.light,
    ).copyWith(
      surface: const Color(0xFFFFF9F0), // Light orange tint
      onSurface: const Color(0xFF92400E), // Dark orange
      primary: const Color(0xFFF7931A), // Bitcoin orange
      secondary: const Color(0xFFFB923C), // Light orange
      tertiary: const Color(0xFFFED7AA), // Pale orange
    ),
  );

  static ThemeData get bitcoinDarkTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFF7931A),
      brightness: Brightness.dark,
    ).copyWith(
      surface: const Color(0xFF2C1810), // Dark orange
      onSurface: const Color(0xFFFFF9F0), // Light orange
      primary: const Color(0xFFFB923C), // Bright orange
      secondary: const Color(0xFFF7931A), // Bitcoin orange
      tertiary: const Color(0xFFFED7AA), // Pale orange
    ),
  );
}