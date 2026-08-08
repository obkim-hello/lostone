import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether app-wide debug mode is enabled.
///
/// Toggled by the hidden 10-tap gesture (`DebugTapDetector`); surfaces
/// developer affordances such as the raw distillation console log. Session
/// scoped — it resets on relaunch.
final StateProvider<bool> debugModeProvider = StateProvider<bool>((Ref ref) {
  return false;
});
