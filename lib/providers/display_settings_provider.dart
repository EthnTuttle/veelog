import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DisplayMode {
  robust,
  standard,
  compact,
}

final displayModeProvider = StateProvider<DisplayMode>((ref) => DisplayMode.standard);