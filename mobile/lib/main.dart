import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'models/app_config.dart';
import 'providers/app_providers.dart';
import 'services/app_initializer.dart';

/// 应用入口。
///
/// 初始化依赖后，用已加载的配置种子化 [appConfigProvider] 并启动
/// [LostoneApp]。
Future<void> main() async {
  await initializeApp();
  final AppConfig config = getAppConfig();
  runApp(
    ProviderScope(
      overrides: <Override>[
        appConfigProvider.overrideWith((Ref ref) => config),
      ],
      child: const LostoneApp(),
    ),
  );
}
