import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/debug_providers.dart';

/// Wraps [child] and toggles [debugModeProvider] after 10 quick taps anywhere.
///
/// Uses a translucent [Listener] so the counter advances on every pointer-down
/// — even over buttons and list items — without stealing gestures from the
/// wrapped UI. Taps more than [_resetAfter] apart restart the count.
class DebugTapDetector extends ConsumerStatefulWidget {
  /// Wraps [child] with the hidden debug-mode trigger.
  const DebugTapDetector({required this.child, super.key});

  /// The subtree that receives normal input untouched.
  final Widget child;

  @override
  ConsumerState<DebugTapDetector> createState() => _DebugTapDetectorState();
}

class _DebugTapDetectorState extends ConsumerState<DebugTapDetector> {
  static const int _tapsToToggle = 10;
  static const Duration _resetAfter = Duration(seconds: 2);

  int _taps = 0;
  DateTime? _lastTap;

  void _onPointerDown(PointerDownEvent event) {
    final DateTime now = DateTime.now();
    if (_lastTap == null || now.difference(_lastTap!) > _resetAfter) {
      _taps = 0;
    }
    _lastTap = now;
    _taps++;
    if (_taps >= _tapsToToggle) {
      _taps = 0;
      _toggle();
    }
  }

  void _toggle() {
    final bool enabled = !ref.read(debugModeProvider);
    ref.read(debugModeProvider.notifier).state = enabled;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content:
              Text(enabled ? 'Debug mode enabled' : 'Debug mode disabled'),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      child: widget.child,
    );
  }
}
