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
  const FlutterGemmaEngine({this.maxTokens = 1024});

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
    } finally {
      await session.close();
    }
  }
}
