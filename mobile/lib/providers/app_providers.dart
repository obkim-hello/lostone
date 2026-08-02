import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_config.dart';
import '../services/app_initializer.dart';

/// 当前应用配置的全局状态。
final StateProvider<AppConfig> appConfigProvider =
    StateProvider<AppConfig>((Ref ref) {
  return AppConfig.development;
});

/// 应用初始化的阶段。
enum InitializationPhase {
  /// 尚未开始。
  idle,

  /// 正在初始化。
  loading,

  /// 初始化成功。
  success,

  /// 初始化失败。
  failure,
}

/// 应用初始化状态。
class InitializationState {
  /// 创建一个初始化状态。
  ///
  /// 参数：
  /// - [phase]：当前阶段，默认为 [InitializationPhase.idle]。
  /// - [error]：失败时的错误描述。
  const InitializationState({
    this.phase = InitializationPhase.idle,
    this.error,
  });

  /// 当前阶段。
  final InitializationPhase phase;

  /// 失败时的错误描述。
  final String? error;

  /// 基于当前状态创建一个副本并覆盖给定字段。
  InitializationState copyWith({
    InitializationPhase? phase,
    String? error,
  }) {
    return InitializationState(
      phase: phase ?? this.phase,
      error: error ?? this.error,
    );
  }
}

/// 驱动 [InitializationState] 的状态管理器。
class InitializationNotifier extends StateNotifier<InitializationState> {
  /// 创建一个初始化状态管理器。
  InitializationNotifier() : super(const InitializationState());

  /// 执行初始化流程并更新状态。
  ///
  /// 参数：
  /// - [config]：可选的应用配置。
  Future<void> initialize({AppConfig? config}) async {
    state = state.copyWith(phase: InitializationPhase.loading);
    try {
      await initializeApp(config: config);
      state = const InitializationState(phase: InitializationPhase.success);
    } on Exception catch (e) {
      state = InitializationState(
        phase: InitializationPhase.failure,
        error: e.toString(),
      );
    }
  }
}

/// 初始化状态的全局 Provider。
final StateNotifierProvider<InitializationNotifier, InitializationState>
    initializationProvider =
    StateNotifierProvider<InitializationNotifier, InitializationState>(
  (Ref ref) {
    return InitializationNotifier();
  },
);
