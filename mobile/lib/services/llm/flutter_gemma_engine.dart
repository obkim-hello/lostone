import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

import 'lite_rt_runtime.dart';

/// [GemmaEngine] 的 `flutter_gemma` v1.5.2 实现（ADR-005，**设备/原生**）。
///
/// 经现代门面 `FlutterGemma.getActiveModel()`（DD-001 选项 A：不依赖 `filePath`）
/// 取激活模型，`createSession` + `getResponse(Async)` 推理。模型下载/激活由模块
/// 007 经 `flutter_gemma` builder API 完成。
///
/// **不可在宿主/模拟器验证质量**：iOS 模拟器仅 CPU、Metal 上限 256MB，1B/E2B 需真机
/// （ADR-005）；宿主仅经 [LiteRtRuntime] + 假 [GemmaEngine] 做结构/契约测试。
class FlutterGemmaEngine implements GemmaEngine {
  /// 创建引擎。[maxTokens] 为上下文窗口（`.litertlm` 需 ≥1024）。
  ///
  /// 默认 4096：蒸馏 prompt（模板 + 语料分块）远超 1024，窗口过小会触发
  /// `flutter_gemma` 的硬错误 `INVALID_ARGUMENT: Input token ids are too long`。
  /// 注意 `flutter_gemma` 的 `getActiveModel` 按模型名缓存实例、**忽略**后续
  /// 变化的 [maxTokens]，故各推理路径须用一致的窗口，避免先建小窗被复用。
  const FlutterGemmaEngine({this.maxTokens = 4096});

  /// 上下文窗口 token 上限。
  final int maxTokens;

  @override
  Future<bool> isReady() async => FlutterGemma.hasActiveModel();

  @override
  Future<String> complete(
    String prompt, {
    double temperature = 0.2,
    int? maxNewTokens,
  }) async {
    try {
      final InferenceModel model =
          await FlutterGemma.getActiveModel(maxTokens: maxTokens);
      final InferenceModelSession session = await model.createSession(
        temperature: temperature,
        maxOutputTokens: maxNewTokens,
      );
      try {
        await session.addQueryChunk(Message.text(text: prompt, isUser: true));
        return await session.getResponse();
      } finally {
        await session.close();
      }
    } on Object catch (e, s) {
      if (kDebugMode) {
        debugPrint('[FlutterGemmaEngine] complete 失败：$e');
        debugPrintStack(stackTrace: s, maxFrames: 8);
      }
      rethrow;
    }
  }

  @override
  Stream<String> stream(
    String prompt, {
    double temperature = 0.7,
    int? maxNewTokens,
  }) async* {
    final InferenceModel model =
        await FlutterGemma.getActiveModel(maxTokens: maxTokens);
    final InferenceModelSession session = await model.createSession(
      temperature: temperature,
      maxOutputTokens: maxNewTokens,
    );
    try {
      await session.addQueryChunk(Message.text(text: prompt, isUser: true));
      yield* session.getResponseAsync();
    } on Object catch (e, s) {
      if (kDebugMode) {
        debugPrint('[FlutterGemmaEngine] stream 失败：$e');
        debugPrintStack(stackTrace: s, maxFrames: 8);
      }
      rethrow;
    } finally {
      await session.close();
    }
  }
}
