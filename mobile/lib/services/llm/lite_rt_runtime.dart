import '../../models/model_install.dart';
import 'persona_runtime.dart';

/// 端侧推理引擎接缝（ADR-005）。
///
/// 把 `flutter_gemma` 的 `getActiveModel/createSession/getResponse(Async)` 隐藏在
/// 本接口后，使 [LiteRtRuntime] 的编排（可用性门控、委派、错误归一）宿主可测；
/// 具体实现 [FlutterGemmaEngine] 属设备/原生代码（见 `flutter_gemma_engine.dart`）。
abstract class GemmaEngine {
  /// 是否已有激活模型可推理。
  Future<bool> isReady();

  /// 一次性补全（蒸馏用）。
  Future<String> complete(
    String prompt, {
    double temperature = 0.2,
    int? maxNewTokens,
  });

  /// 流式补全（对话用），逐 token 产出。
  Stream<String> stream(
    String prompt, {
    double temperature = 0.7,
    int? maxNewTokens,
  });
}

/// 本地运行时（ERD-004 §4.1，默认）：`implements PersonaRuntime`。
///
/// 可用性以模块 007 契约为准——经 [activeHandle]（`getActiveModelHandle`）判定，
/// 无激活句柄即不可用（DD-001：不依赖 `filePath`，仅确认存在激活模型）。推理委派
/// [engine]；原生层异常归一为分类 [RuntimeError]（不静默失败）。全程无网络。
class LiteRtRuntime implements PersonaRuntime {
  /// 创建本地运行时。
  ///
  /// [activeHandle] 复用 007 `ModelRepository.getActiveModelHandle`（返回 `null`
  /// 即无激活模型）；[engine] 为端侧推理接缝。
  const LiteRtRuntime({
    required this.engine,
    required this.activeHandle,
    this.capabilities = const RuntimeCapabilities(
      contextTokens: 1024,
      maxOutputTokens: 1024,
    ),
  });

  /// 端侧推理接缝。
  final GemmaEngine engine;

  /// 激活模型句柄来源（007 契约点）。
  final Future<ModelHandle?> Function() activeHandle;

  @override
  final RuntimeCapabilities capabilities;

  @override
  Future<bool> isAvailable() async {
    final ModelHandle? handle = await activeHandle();
    if (handle == null) {
      return false;
    }
    return engine.isReady();
  }

  @override
  Future<RuntimeResult> generate(String prompt, {double temperature = 0.2}) async {
    if (!await isAvailable()) {
      return const RuntimeResult.failure(
        RuntimeError.modelUnavailable,
        source: RuntimeSource.liteRt,
      );
    }
    try {
      final String text =
          await engine.complete(prompt, temperature: temperature);
      return RuntimeResult.ok(text, source: RuntimeSource.liteRt);
    } on Object {
      return const RuntimeResult.failure(
        RuntimeError.modelUnavailable,
        source: RuntimeSource.liteRt,
      );
    }
  }

  @override
  Stream<String> generateStream(
    String prompt, {
    double temperature = 0.7,
    int? maxNewTokens,
  }) async* {
    if (!await isAvailable()) {
      throw const RuntimeException(RuntimeError.modelUnavailable);
    }
    final Stream<String> upstream = engine.stream(
      prompt,
      temperature: temperature,
      maxNewTokens: maxNewTokens,
    );
    try {
      await for (final String token in upstream) {
        yield token;
      }
    } on RuntimeException {
      rethrow;
    } on Object {
      throw const RuntimeException(RuntimeError.modelUnavailable);
    }
  }
}
