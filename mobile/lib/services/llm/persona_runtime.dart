import 'package:flutter/foundation.dart';

/// 推理来源：结果由哪条路径产生（对齐 ERD-004 §3.4）。
enum RuntimeSource {
  /// 本地 LiteRT-LM（默认，经 flutter_gemma，ADR-005）。
  liteRt,

  /// 云端 API（显式授权 opt-in）。
  cloud,

  /// 统计兜底（模块 003，无 LLM）。仅蒸馏可兜底，对话不可。
  fallback,
}

/// 分类的运行时错误（对齐 ERD-004 §3.4 / SPEC-004 §5、§2.4）。
///
/// 用于让上层（Builder 决定是否兜底、ChatEngine 转 `ChatDelta.error`）
/// 精确区分失败原因，绝不静默失败。
enum RuntimeError {
  /// 无就绪模型 / 最大隐私（`maxPrivacy`）：本地不可用（模型未加载）。
  modelUnavailable,

  /// 模型已加载但推理中途失败（OOM / 原生崩溃 / 分词错误）：区别于
  /// [modelUnavailable]，避免把真实推理故障误判为"无模型"而误导兜底/掩盖缺陷。
  inferenceFailed,

  /// 云端未授权（`cloudAuthorized == false`）：不发起任何网络调用。
  unauthorized,

  /// 网络失败（连接/超时/服务端错误）。
  network,

  /// 触达速率或 token 上限（"超限"）。
  rateLimited,

  /// 生成被调用方取消（取消订阅）。
  canceled,

  /// 输入为空（如空 `userMessage`），不产生空回复。
  emptyInput,
}

/// 运行时能力声明：供分块（蒸馏）与滑窗（对话）决策（ERD-004 §4.1）。
@immutable
class RuntimeCapabilities {
  /// 创建能力声明。
  const RuntimeCapabilities({
    required this.contextTokens,
    required this.maxOutputTokens,
    this.supportsStreaming = true,
  });

  /// 上下文窗口 token 上限（决定分块阈值与对话滑窗裁剪）。
  final int contextTokens;

  /// 单次生成的输出 token 上限。
  final int maxOutputTokens;

  /// 是否支持逐 token 流式生成。
  final bool supportsStreaming;

  @override
  bool operator ==(Object other) =>
      other is RuntimeCapabilities &&
      other.contextTokens == contextTokens &&
      other.maxOutputTokens == maxOutputTokens &&
      other.supportsStreaming == supportsStreaming;

  @override
  int get hashCode =>
      Object.hash(contextTokens, maxOutputTokens, supportsStreaming);
}

/// 一次性生成（蒸馏用）的结果（ERD-004 §3.4）。
@immutable
class RuntimeResult {
  /// 创建生成结果。
  const RuntimeResult({
    required this.text,
    required this.source,
    this.truncated = false,
    this.error,
  });

  /// 成功结果的便捷构造：无错误。
  const RuntimeResult.ok(
    this.text, {
    required this.source,
    this.truncated = false,
  }) : error = null;

  /// 失败结果的便捷构造：空文本 + 分类错误。
  const RuntimeResult.failure(
    this.error, {
    required this.source,
  })  : text = '',
        truncated = false;

  /// 模型原始文本响应（失败时为空串）。
  final String text;

  /// 结果来源。
  final RuntimeSource source;

  /// 是否因上下文/长度上限被截断。
  final bool truncated;

  /// 分类错误；`null` 表示成功。
  final RuntimeError? error;

  /// 是否为成功结果。
  bool get isOk => error == null;

  @override
  bool operator ==(Object other) =>
      other is RuntimeResult &&
      other.text == text &&
      other.source == source &&
      other.truncated == truncated &&
      other.error == error;

  @override
  int get hashCode => Object.hash(text, source, truncated, error);
}

/// 携带 [RuntimeError] 的流式异常。
///
/// [PersonaRuntime.generateStream] 在失败时经 `Stream` 的错误通道抛出本类型，
/// 上层（ChatEngine）捕获后映射为 `ChatDelta.error`，实现"不静默失败"。
@immutable
class RuntimeException implements Exception {
  /// 创建携带分类错误的异常。
  const RuntimeException(this.error);

  /// 分类错误。
  final RuntimeError error;

  @override
  String toString() => 'RuntimeException($error)';

  @override
  bool operator ==(Object other) =>
      other is RuntimeException && other.error == error;

  @override
  int get hashCode => error.hashCode;
}

/// 统一的推理运行时抽象（ERD-004 §4.1）：蒸馏与对话共用。
///
/// 实现：[LiteRtRuntime]（本地默认，flutter_gemma）、`CloudRuntime`（opt-in）、
/// `FallbackRuntime`（统计兜底，仅蒸馏）、`MockRuntime`（测试）。
///
/// 隐私：本地实现不发起网络；云端实现在内部校验授权，未授权即失败且不发请求。
abstract class PersonaRuntime {
  /// 模型是否就绪（本地：已下载并激活；云端：已配置且已授权）。
  Future<bool> isAvailable();

  /// 声明上下文长度 / 能力上限，供分块与滑窗决策。
  RuntimeCapabilities get capabilities;

  /// 一次性生成（蒸馏用）。
  ///
  /// 失败时返回 `error != null` 的 [RuntimeResult]（不抛异常），由 Builder
  /// 决定是否走统计兜底。云端实现须在内部校验授权。
  Future<RuntimeResult> generate(String prompt, {double temperature = 0.2});

  /// 流式生成（对话用）：逐 token 产出。
  ///
  /// 失败经 `Stream` 错误通道抛 [RuntimeException]；取消订阅即停止生成。
  Stream<String> generateStream(
    String prompt, {
    double temperature = 0.7,
    int? maxNewTokens,
  });
}
