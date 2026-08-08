import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'persona_library/persona_library_screen.dart';

/// 应用首页：保存的 Persona 库（Module 009）。
class HomeScreen extends ConsumerWidget {
  /// 创建首页。
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const PersonaLibraryScreen();
  }
}
