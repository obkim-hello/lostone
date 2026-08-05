import 'persona_runtime.dart';

/// 统计兜底运行时（ERD-004 §4.1）：**不推理**，恒定报告「无模型」。
///
/// 当无就绪模型、最大隐私（`maxPrivacy`）或注入为占位运行时时使用：
/// [generate] 恒返回 `error: modelUnavailable`（`source: fallback`），由
/// `LlmPersonaBuilder` 据此改走模块 003 统计兜底路径；[generateStream] 经错误
/// 通道抛 [RuntimeException]——对话**不可**兜底，只能失败（对齐 SPEC-004 §2.4）。
///
/// 不发起任何网络调用、不读写模型文件。
class FallbackRuntime implements PersonaRuntime {
  /// 创建统计兜底运行时。
  const FallbackRuntime();

  @override
  Future<bool> isAvailable() async => false;

  @override
  RuntimeCapabilities get capabilities => const RuntimeCapabilities(
        contextTokens: 0,
        maxOutputTokens: 0,
        supportsStreaming: false,
      );

  @override
  Future<RuntimeResult> generate(String prompt, {double temperature = 0.2}) async =>
      const RuntimeResult.failure(
        RuntimeError.modelUnavailable,
        source: RuntimeSource.fallback,
      );

  @override
  Stream<String> generateStream(
    String prompt, {
    double temperature = 0.7,
    int? maxNewTokens,
  }) async* {
    throw const RuntimeException(RuntimeError.modelUnavailable);
  }
}
