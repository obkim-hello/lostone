import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'cloud_runtime.dart';

/// Concrete [CloudTransport] speaking OpenAI Chat Completions or Anthropic
/// Messages over HTTPS (ADR-002 cloud path; ERD-004 §4.1).
///
/// The wire format is chosen by [format]; [endpoint] overrides the provider
/// default base URL (trailing slashes tolerated). A [http.Client] is injectable
/// so the request shaping and response/error mapping are host-testable without
/// real network. Non-2xx responses and connection failures are normalized to
/// [CloudHttpException] for [CloudRuntime] to classify.
class HttpCloudTransport implements CloudTransport {
  /// Creates a transport for [format], optionally against a custom [endpoint].
  HttpCloudTransport({
    required this.format,
    String? endpoint,
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
  })  : endpoint = _normalizeEndpoint(endpoint, format),
        _client = client ?? http.Client();

  /// Wire format (OpenAI-compatible or Anthropic).
  final CloudProvider format;

  /// Base URL (no trailing slash) requests are issued against.
  final String endpoint;

  /// Per-request timeout; a timeout maps to a network [CloudHttpException].
  final Duration timeout;

  final http.Client _client;

  static const String _anthropicVersion = '2023-06-01';

  static String _normalizeEndpoint(String? endpoint, CloudProvider format) {
    String base = (endpoint == null || endpoint.trim().isEmpty)
        ? format.defaultEndpoint
        : endpoint.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    for (final String suffix in <String>['/chat/completions', '/messages']) {
      if (base.endsWith(suffix)) {
        base = base.substring(0, base.length - suffix.length);
        break;
      }
    }
    return base;
  }

  @override
  Future<String> complete(CloudRequest request) async {
    final http.Response response = await _send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudHttpException(
        statusCode: response.statusCode,
        detail: _snippet(response.body),
      );
    }
    return _parse(response.body);
  }

  @override
  Stream<String> stream(CloudRequest request) async* {
    yield await complete(request);
  }

  Future<http.Response> _send(CloudRequest request) async {
    final Uri uri = Uri.parse('$endpoint${_path()}');
    try {
      return await _client
          .post(uri, headers: _headers(request), body: jsonEncode(_body(request)))
          .timeout(timeout);
    } on CloudHttpException {
      rethrow;
    } on Object catch (error) {
      throw CloudHttpException(
        isNetworkError: true,
        detail: '$uri — $error',
      );
    }
  }

  static String _snippet(String body) {
    final String trimmed = body.trim();
    if (trimmed.isEmpty) {
      return '(empty response body)';
    }
    return trimmed.length > 300 ? '${trimmed.substring(0, 300)}…' : trimmed;
  }

  String _path() => switch (format) {
        CloudProvider.openai => '/chat/completions',
        CloudProvider.anthropic => '/messages',
      };

  Map<String, String> _headers(CloudRequest request) => switch (format) {
        CloudProvider.openai => <String, String>{
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${request.apiKey}',
          },
        CloudProvider.anthropic => <String, String>{
            'Content-Type': 'application/json',
            'x-api-key': request.apiKey,
            'anthropic-version': _anthropicVersion,
          },
      };

  Map<String, dynamic> _body(CloudRequest request) {
    final List<Map<String, String>> messages = <Map<String, String>>[
      <String, String>{'role': 'user', 'content': request.prompt},
    ];
    return switch (format) {
      CloudProvider.openai => <String, dynamic>{
          'model': request.model,
          'messages': messages,
          'temperature': request.temperature,
          if (request.maxNewTokens != null) 'max_tokens': request.maxNewTokens,
        },
      CloudProvider.anthropic => <String, dynamic>{
          'model': request.model,
          'messages': messages,
          'temperature': request.temperature,
          'max_tokens': request.maxNewTokens ?? 4096,
        },
    };
  }

  String _parse(String body) {
    final dynamic json;
    try {
      json = jsonDecode(body);
    } on FormatException catch (error) {
      throw CloudHttpException(detail: 'malformed response: $error');
    }
    if (json is! Map<String, dynamic>) {
      throw CloudHttpException(detail: 'unexpected response: ${_snippet(body)}');
    }
    return switch (format) {
      CloudProvider.openai => _parseOpenAi(json, body),
      CloudProvider.anthropic => _parseAnthropic(json, body),
    };
  }

  String _parseOpenAi(Map<String, dynamic> json, String body) {
    final Object? choices = json['choices'];
    if (choices is List && choices.isNotEmpty) {
      final Object? first = choices.first;
      if (first is Map && first['message'] is Map) {
        final Map<Object?, Object?> message = first['message'] as Map;
        final Object? content = message['content'];
        if (content is String) {
          return content;
        }
        final Object? reasoning = message['reasoning_content'];
        if (reasoning is String) {
          return reasoning;
        }
      }
    }
    throw CloudHttpException(detail: 'unexpected response: ${_snippet(body)}');
  }

  String _parseAnthropic(Map<String, dynamic> json, String body) {
    final Object? content = json['content'];
    if (content is List && content.isNotEmpty) {
      final StringBuffer buffer = StringBuffer();
      for (final Object? block in content) {
        if (block is Map && block['type'] == 'text' && block['text'] is String) {
          buffer.write(block['text'] as String);
        }
      }
      if (buffer.isNotEmpty) {
        return buffer.toString();
      }
    }
    throw CloudHttpException(detail: 'unexpected response: ${_snippet(body)}');
  }
}
