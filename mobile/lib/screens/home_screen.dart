import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_config.dart';
import '../providers/app_providers.dart';
import 'dev/llm_harness_screen.dart';

/// 应用首页。
///
/// 初始化完成后展示的占位页面，显示当前应用名称与环境。
class HomeScreen extends ConsumerWidget {
  /// 创建首页。
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppConfig config = ref.watch(appConfigProvider);
    return Scaffold(
      appBar: AppBar(title: Text(config.appName)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              config.appName,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text('environment: ${config.environment}'),
            Text('version: ${config.version}'),
            if (kDebugMode) ...<Widget>[
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const LlmHarnessScreen(),
                  ),
                ),
                child: const Text('LLM 联调（dev）'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
