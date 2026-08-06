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
  try {
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
  } on Object catch (e, s) {
    runApp(_StartupErrorApp(error: e, stack: s));
  }
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.error, required this.stack});

  final Object error;
  final StackTrace stack;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('启动失败')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            '初始化异常：\n$error\n\n$stack',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      ),
    );
  }
}
