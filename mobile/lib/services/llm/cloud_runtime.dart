import 'persona_runtime.dart';

/// Cloud API wire format a request is shaped for (SPEC-010 cloud section).
///
/// Determines the endpoint path, auth header, request body, and response
/// parsing a [CloudTransport] uses. Two formats are supported today: the
/// OpenAI-compatible Chat Completions API and Anthropic's Messages API.
enum CloudProvider {
  /// OpenAI-compatible Chat Completions (`POST /chat/completions`,
  /// `Authorization: Bearer`). Also covers Azure OpenAI, Together, Groq, and
  /// other OpenAI-compatible gateways via a custom endpoint.
  openai,

  /// Anthropic Messages API (`POST /messages`, `x-api-key` +
  /// `anthropic-version`).
  anthropic,
}

/// Presentation + default wiring for each [CloudProvider].
extension CloudProviderInfo on CloudProvider {
  /// Human-readable name for the settings UI.
  String get label => switch (this) {
        CloudProvider.openai => 'OpenAI (compatible)',
        CloudProvider.anthropic => 'Anthropic (Claude)',
      };

  /// Default base URL used when the user leaves the endpoint blank.
  String get defaultEndpoint => switch (this) {
        CloudProvider.openai => 'https://api.openai.com/v1',
        CloudProvider.anthropic => 'https://api.anthropic.com/v1',
      };

  /// Default model name used when the user leaves the model blank.
  String get defaultModel => switch (this) {
        CloudProvider.openai => 'gpt-4o-mini',
        CloudProvider.anthropic => 'claude-3-5-sonnet-latest',
      };
}

/// 一次云端推理请求（provider 无关）。
///
/// [apiKey] 由构造方从 Flutter Secure Storage 读出后注入 [CloudRuntime]，再随请求
/// 交给 [CloudTransport]；本层不接触密钥存储，便于测试与解耦。
class CloudRequest {
  /// 创建请求。
  const CloudRequest({
    required this.prompt,
    required this.model,
    required this.apiKey,
    this.temperature = 0.7,
    this.maxNewTokens,
    this.stream = false,
  });

  /// 完整 prompt。
  final String prompt;

  /// 目标模型名（如 `gpt-4o` / `claude-sonnet`）。
  final String model;

  /// 鉴权密钥。
  final String apiKey;

  /// 采样温度。
  final double temperature;

  /// 输出 token 上限。
  final int? maxNewTokens;

  /// 是否流式。
  final bool stream;
}

/// 云端 HTTP 失败（provider 无关）。
///
/// [CloudTransport] 抛出本类型，由 [CloudRuntime] 归一到 [RuntimeError]——错误
/// 分类逻辑因此可在宿主用假 transport 断言，无需真实网络。
class CloudHttpException implements Exception {
  /// 创建异常。
  const CloudHttpException({
    this.statusCode,
    this.isNetworkError = false,
    this.detail,
  });

  /// HTTP 状态码；连接层失败时为 `null`。
  final int? statusCode;

  /// 是否为连接/超时等网络层失败（无状态码）。
  final bool isNetworkError;

  /// Human-readable detail (a truncated response body, a parse hint, or a
  /// connection-error message) surfaced to the user by the "Test connection"
  /// action so a misconfigured endpoint/key is diagnosable, not just "failed".
  final String? detail;

  @override
  String toString() => 'CloudHttpException(statusCode: $statusCode, '
      'network: $isNetworkError, detail: $detail)';
}

/// 云端传输抽象（可注入的接缝）。
///
/// 具体 provider（OpenAI/Anthropic/Gemini）的 HTTP 线缆实现属集成/设备工作，本
/// 接口把它与 [CloudRuntime] 的授权门控 + 错误分类解耦，使后者宿主可测。
abstract class CloudTransport {
  /// 一次性补全，返回完整文本。失败抛 [CloudHttpException]。
  Future<String> complete(CloudRequest request);

  /// 流式补全，逐 token 产出。失败经错误通道抛 [CloudHttpException]。
  Stream<String> stream(CloudRequest request);
}

/// 云端运行时（ERD-004 §4.1，opt-in）：`implements PersonaRuntime`。
///
/// 隐私门控（SPEC-004 §2.4 / ERD-004 §6.1）：未授权或无密钥 → 返回 / 抛
/// `unauthorized`，**绝不调用 [transport]、绝不发起网络请求**。授权后由
/// [transport] 发请求，HTTP 失败经 [CloudHttpException] 归一为分类 [RuntimeError]。
class CloudRuntime implements PersonaRuntime {
  /// 创建云端运行时。[authorized] 对应 `cloudAuthorized`，[apiKey] 由构造方从
  /// Secure Storage 读出注入。
  const CloudRuntime({
    required this.transport,
    required this.authorized,
    required this.model,
    this.apiKey,
    this.apiKeyLoader,
    this.capabilities = const RuntimeCapabilities(
      contextTokens: 128000,
      maxOutputTokens: 4096,
    ),
  });

  /// 可注入的传输实现。
  final CloudTransport transport;

  /// 用户是否已显式授权云端。
  final bool authorized;

  /// 目标模型名。
  final String model;

  /// 鉴权密钥；`null`/空即视为未配置。优先于 [apiKeyLoader]。
  final String? apiKey;

  /// Async key source used when [apiKey] is null/empty (e.g. reading Flutter
  /// Secure Storage lazily so a synchronous provider can build this runtime
  /// without holding the secret in memory).
  final Future<String?> Function()? apiKeyLoader;

  @override
  final RuntimeCapabilities capabilities;

  Future<String?> _resolveKey() async {
    if (apiKey != null && apiKey!.isNotEmpty) {
      return apiKey;
    }
    final Future<String?> Function()? loader = apiKeyLoader;
    return loader == null ? null : loader();
  }

  @override
  Future<bool> isAvailable() async {
    if (!authorized) {
      return false;
    }
    final String? key = await _resolveKey();
    return key != null && key.isNotEmpty;
  }

  @override
  Future<RuntimeResult> generate(String prompt, {double temperature = 0.2}) async {
    if (!authorized) {
      return const RuntimeResult.failure(
        RuntimeError.unauthorized,
        source: RuntimeSource.cloud,
      );
    }
    final String? key = await _resolveKey();
    if (key == null || key.isEmpty) {
      return const RuntimeResult.failure(
        RuntimeError.unauthorized,
        source: RuntimeSource.cloud,
      );
    }
    try {
      final String text = await transport.complete(
        CloudRequest(
          prompt: prompt,
          model: model,
          apiKey: key,
          temperature: temperature,
        ),
      );
      return RuntimeResult.ok(text, source: RuntimeSource.cloud);
    } on CloudHttpException catch (e) {
      return RuntimeResult.failure(_mapError(e), source: RuntimeSource.cloud);
    }
  }

  @override
  Stream<String> generateStream(
    String prompt, {
    double temperature = 0.7,
    int? maxNewTokens,
  }) async* {
    if (!authorized) {
      throw const RuntimeException(RuntimeError.unauthorized);
    }
    final String? key = await _resolveKey();
    if (key == null || key.isEmpty) {
      throw const RuntimeException(RuntimeError.unauthorized);
    }
    final Stream<String> upstream = transport.stream(
      CloudRequest(
        prompt: prompt,
        model: model,
        apiKey: key,
        temperature: temperature,
        maxNewTokens: maxNewTokens,
        stream: true,
      ),
    );
    try {
      await for (final String token in upstream) {
        yield token;
      }
    } on CloudHttpException catch (e) {
      throw RuntimeException(_mapError(e));
    }
  }

  RuntimeError _mapError(CloudHttpException e) {
    if (e.isNetworkError) {
      return RuntimeError.network;
    }
    switch (e.statusCode) {
      case 401:
      case 403:
        return RuntimeError.unauthorized;
      case 429:
        return RuntimeError.rateLimited;
      default:
        return RuntimeError.network;
    }
  }
}
