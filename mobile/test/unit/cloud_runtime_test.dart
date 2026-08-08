import 'package:flutter_test/flutter_test.dart';
import 'package:lostone/services/llm/cloud_runtime.dart';
import 'package:lostone/services/llm/persona_runtime.dart';

class _FakeTransport implements CloudTransport {
  _FakeTransport({
    this.completeText = '你好',
    this.tokens = const <String>['你', '好'],
    this.throwOn,
    this.throwAfter = 0,
  });

  final String completeText;
  final List<String> tokens;
  final CloudHttpException? throwOn;
  final int throwAfter;

  final List<CloudRequest> completeCalls = <CloudRequest>[];
  final List<CloudRequest> streamCalls = <CloudRequest>[];

  @override
  Future<String> complete(CloudRequest request) async {
    completeCalls.add(request);
    if (throwOn != null) {
      throw throwOn!;
    }
    return completeText;
  }

  @override
  Stream<String> stream(CloudRequest request) async* {
    streamCalls.add(request);
    for (int i = 0; i < tokens.length; i++) {
      if (throwOn != null && i == throwAfter) {
        throw throwOn!;
      }
      yield tokens[i];
    }
    if (throwOn != null && throwAfter >= tokens.length) {
      throw throwOn!;
    }
  }
}

CloudRuntime _runtime(
  _FakeTransport transport, {
  bool authorized = true,
  String? apiKey = 'sk-test',
}) =>
    CloudRuntime(
      transport: transport,
      authorized: authorized,
      apiKey: apiKey,
      model: 'gpt-4o',
    );

void main() {
  group('CloudRuntime · 授权门控', () {
    test('已授权且有密钥 → isAvailable true', () async {
      expect(await _runtime(_FakeTransport()).isAvailable(), isTrue);
    });

    test('未授权 → isAvailable false', () async {
      final CloudRuntime r = _runtime(_FakeTransport(), authorized: false);
      expect(await r.isAvailable(), isFalse);
    });

    test('无密钥 → isAvailable false', () async {
      expect(await _runtime(_FakeTransport(), apiKey: null).isAvailable(), isFalse);
      expect(await _runtime(_FakeTransport(), apiKey: '').isAvailable(), isFalse);
    });

    test('generate 未授权 → unauthorized，不调用 transport', () async {
      final _FakeTransport t = _FakeTransport();
      final RuntimeResult r = await _runtime(t, authorized: false).generate('嗨');
      expect(r.error, RuntimeError.unauthorized);
      expect(r.source, RuntimeSource.cloud);
      expect(t.completeCalls, isEmpty);
    });

    test('generate 无密钥 → unauthorized，不调用 transport', () async {
      final _FakeTransport t = _FakeTransport();
      final RuntimeResult r = await _runtime(t, apiKey: null).generate('嗨');
      expect(r.error, RuntimeError.unauthorized);
      expect(t.completeCalls, isEmpty);
    });

    test('generateStream 未授权 → 抛 unauthorized，不调用 transport', () async {
      final _FakeTransport t = _FakeTransport();
      final Stream<String> s = _runtime(t, authorized: false).generateStream('嗨');
      await expectLater(
        s,
        emitsError(const RuntimeException(RuntimeError.unauthorized)),
      );
      expect(t.streamCalls, isEmpty);
    });
  });

  group('CloudRuntime · 成功路径', () {
    test('generate 成功 → ok(text)、source cloud、请求携带 prompt/温度/密钥', () async {
      final _FakeTransport t = _FakeTransport(completeText: '在的呀');
      final RuntimeResult r =
          await _runtime(t).generate('在吗', temperature: 0.3);
      expect(r.isOk, isTrue);
      expect(r.text, '在的呀');
      expect(r.source, RuntimeSource.cloud);
      expect(t.completeCalls.single.prompt, '在吗');
      expect(t.completeCalls.single.temperature, 0.3);
      expect(t.completeCalls.single.apiKey, 'sk-test');
      expect(t.completeCalls.single.model, 'gpt-4o');
    });

    test('generateStream 成功 → 逐 token 顺序产出', () async {
      final _FakeTransport t =
          _FakeTransport(tokens: const <String>['最', '近', '还好']);
      final List<String> out =
          await _runtime(t).generateStream('近来如何').toList();
      expect(out, <String>['最', '近', '还好']);
      expect(t.streamCalls.single.stream, isTrue);
    });
  });

  group('CloudRuntime · 错误分类', () {
    test('generate 401 → unauthorized', () async {
      final _FakeTransport t =
          _FakeTransport(throwOn: const CloudHttpException(statusCode: 401));
      expect((await _runtime(t).generate('x')).error, RuntimeError.unauthorized);
    });

    test('generate 429 → rateLimited', () async {
      final _FakeTransport t =
          _FakeTransport(throwOn: const CloudHttpException(statusCode: 429));
      expect((await _runtime(t).generate('x')).error, RuntimeError.rateLimited);
    });

    test('generate 500 → network', () async {
      final _FakeTransport t =
          _FakeTransport(throwOn: const CloudHttpException(statusCode: 500));
      expect((await _runtime(t).generate('x')).error, RuntimeError.network);
    });

    test('generate 连接失败 → network', () async {
      final _FakeTransport t =
          _FakeTransport(throwOn: const CloudHttpException(isNetworkError: true));
      expect((await _runtime(t).generate('x')).error, RuntimeError.network);
    });

    test('generateStream 中途 429 → 抛 rateLimited', () async {
      final _FakeTransport t = _FakeTransport(
        tokens: const <String>['a', 'b', 'c'],
        throwOn: const CloudHttpException(statusCode: 429),
        throwAfter: 1,
      );
      await expectLater(
        _runtime(t).generateStream('x'),
        emitsInOrder(<dynamic>[
          'a',
          emitsError(const RuntimeException(RuntimeError.rateLimited)),
        ]),
      );
    });
  });

  group('CloudRuntime · apiKeyLoader（懒读密钥）', () {
    CloudRuntime loaderRuntime(
      _FakeTransport transport, {
      required Future<String?> Function() loader,
    }) =>
        CloudRuntime(
          transport: transport,
          authorized: true,
          apiKey: null,
          apiKeyLoader: loader,
          model: 'gpt-4o',
        );

    test('apiKey 为空时经 loader 取密钥 → isAvailable true', () async {
      final CloudRuntime r =
          loaderRuntime(_FakeTransport(), loader: () async => 'sk-lazy');
      expect(await r.isAvailable(), isTrue);
    });

    test('loader 返回空 → isAvailable false，generate unauthorized', () async {
      final _FakeTransport t = _FakeTransport();
      final CloudRuntime r = loaderRuntime(t, loader: () async => '');
      expect(await r.isAvailable(), isFalse);
      expect((await r.generate('嗨')).error, RuntimeError.unauthorized);
      expect(t.completeCalls, isEmpty);
    });

    test('generate 经 loader 密钥 → 请求携带该密钥', () async {
      final _FakeTransport t = _FakeTransport(completeText: 'ok');
      final CloudRuntime r = loaderRuntime(t, loader: () async => 'sk-lazy');
      final RuntimeResult res = await r.generate('嗨');
      expect(res.isOk, isTrue);
      expect(t.completeCalls.single.apiKey, 'sk-lazy');
    });

    test('apiKey 非空时优先于 loader（loader 不调用）', () async {
      final _FakeTransport t = _FakeTransport();
      bool loaderCalled = false;
      final CloudRuntime r = CloudRuntime(
        transport: t,
        authorized: true,
        apiKey: 'sk-explicit',
        apiKeyLoader: () async {
          loaderCalled = true;
          return 'sk-lazy';
        },
        model: 'gpt-4o',
      );
      await r.generate('嗨');
      expect(loaderCalled, isFalse);
      expect(t.completeCalls.single.apiKey, 'sk-explicit');
    });
  });

  group('CloudProviderInfo · 默认线缆', () {
    test('OpenAI 默认端点/模型/标签', () {
      expect(CloudProvider.openai.defaultEndpoint, 'https://api.openai.com/v1');
      expect(CloudProvider.openai.defaultModel, 'gpt-4o-mini');
      expect(CloudProvider.openai.label, 'OpenAI (compatible)');
    });

    test('Anthropic 默认端点/模型/标签', () {
      expect(
        CloudProvider.anthropic.defaultEndpoint,
        'https://api.anthropic.com/v1',
      );
      expect(CloudProvider.anthropic.defaultModel, 'claude-3-5-sonnet-latest');
      expect(CloudProvider.anthropic.label, 'Anthropic (Claude)');
    });
  });
}
