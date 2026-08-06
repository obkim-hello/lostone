import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/app_config.dart';
import 'providers/app_providers.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

/// Lostone 应用根组件。
///
/// 负责配置 [MaterialApp]、主题以及首页路由。
class LostoneApp extends ConsumerWidget {
  /// 创建应用根组件。
  const LostoneApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppConfig config = ref.watch(appConfigProvider);
    return MaterialApp(
      title: config.appName,
      debugShowCheckedModeBanner: config.isDebug,
      theme: AppTheme.light(),
      home: const HomeScreen(),
    );
  }
}
