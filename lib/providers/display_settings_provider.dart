import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DisplayMode {
  robust,
  detailed,
  compact,
  standard,
}

final displayModeProvider = StateProvider<DisplayMode>((ref) => DisplayMode.standard);