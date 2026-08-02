import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'services/app_initializer.dart';

/// 应用入口。
///
/// 初始化依赖后启动 [LostoneApp]。
Future<void> main() async {
  await initializeApp();
  runApp(const ProviderScope(child: LostoneApp()));
}
