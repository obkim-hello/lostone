import 'persona_runtime.dart';

/// 测试用 [PersonaRuntime]：注入固定响应/固定 token 序列，做确定性断言。
///
/// 记录收到的 prompt（[receivedPrompts]）供断言"system prompt 只经
/// `PromptTemplate.render`"。注入 [error] 时短路——**不记录 prompt、不产出**，
/// 以此模拟"未授权不发网络请求 / 无模型不推理"。
class MockRuntime implements PersonaRuntime {
  /// 创建 mock runtime。
  ///
  /// [response] 供 [generate]；[tokens] 供 [generateStream]（缺省时以整段
  /// [response] 作为单一 token）。[error] 非空则所有生成失败。
  MockRuntime({
    this.response = '',
    List<String>? tokens,
    this.available = true,
    this.source = RuntimeSource.liteRt,
    this.error,
    this.failAfterTokens,
    RuntimeCapabilities? capabilities,
  })  : _tokens = tokens ??
            (response.isEmpty ? const <String>[] : <String>[response]),
        capabilities = capabilities ??
            const RuntimeCapabilities(
              contextTokens: 4096,
              maxOutputTokens: 1024,
            );

  /// [generate] 返回的固定文本。
  final String response;

  /// 模型是否就绪。
  final bool available;

  /// 结果来源标签。
  final RuntimeSource source;

  /// 注入的分类错误；非空则生成失败（且不记录 prompt / 不产出）。
  final RuntimeError? error;

  /// 流式生成先产出前 N 个 token、再抛 [error]（模拟推理中途失败）。
  ///
  /// 仅 [error] 非空时生效：`null` 保持"开流即抛"（前置失败）；非空则先记录
  /// prompt 并逐 token 产出至该数量后抛 [RuntimeException]。
  final int? failAfterTokens;

  @override
  final RuntimeCapabilities capabilities;

  final List<String> _tokens;

  /// 已收到并"发出"的 prompt 记录（注入 [error] 时不追加）。
  final List<String> receivedPrompts = <String>[];

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<RuntimeResult> generate(String prompt, {double temperature = 0.2}) async {
    if (error != null) {
      return RuntimeResult.failure(error, source: source);
    }
    receivedPrompts.add(prompt);
    return RuntimeResult.ok(response, source: source);
  }

  @override
  Stream<String> generateStream(
    String prompt, {
    double temperature = 0.7,
    int? maxNewTokens,
  }) async* {
    if (error != null && failAfterTokens == null) {
      throw RuntimeException(error!);
    }
    receivedPrompts.add(prompt);
    final int limit = maxNewTokens ?? _tokens.length;
    for (int i = 0; i < _tokens.length && i < limit; i++) {
      if (error != null && i == failAfterTokens) {
        throw RuntimeException(error!);
      }
      await Future<void>.delayed(Duration.zero);
      yield _tokens[i];
    }
    if (error != null) {
      throw RuntimeException(error!);
    }
  }
}
