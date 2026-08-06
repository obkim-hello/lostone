import 'package:flutter_test/flutter_test.dart';
import 'package:lostone/models/model_descriptor.dart';
import 'package:lostone/models/model_install.dart';
import 'package:lostone/services/llm/lite_rt_runtime.dart';
import 'package:lostone/services/llm/persona_runtime.dart';

class _FakeEngine implements GemmaEngine {
  _FakeEngine({
    this.ready = true,
    this.completeText = '嗯呐',
    this.tokens = const <String>['嗯', '呐'],
    this.throwOnComplete = false,
    this.throwOnStream = false,
  });

  final bool ready;
  final String completeText;
  final List<String> tokens;
  final bool throwOnComplete;
  final bool throwOnStream;

  int completeCalls = 0;
  int streamCalls = 0;

  @override
  Future<bool> isReady() async => ready;

  @override
  Future<String> complete(
    String prompt, {
    double temperature = 0.2,
    int? maxNewTokens,
  }) async {
    completeCalls++;
    if (throwOnComplete) {
      throw StateError('native failure');
    }
    return completeText;
  }

  @override
  Stream<String> stream(
    String prompt, {
    double temperature = 0.7,
    int? maxNewTokens,
  }) async* {
    streamCalls++;
    for (final String t in tokens) {
      yield t;
    }
    if (throwOnStream) {
      throw StateError('native failure');
    }
  }
}

ModelHandle _handle() => const ModelHandle(
      id: 'smol',
      format: ModelFormat.litertlm,
      capabilities: <ModelCapability>{ModelCapability.text},
      backend: InferenceBackend.cpu,
      engine: EngineKind.liteRtLm,
    );

LiteRtRuntime _runtime(
  _FakeEngine engine, {
  ModelHandle? handle,
}) =>
    LiteRtRuntime(engine: engine, activeHandle: () async => handle);

void main() {
  group('LiteRtRuntime · 可用性', () {
    test('有激活句柄且引擎就绪 → available', () async {
      expect(await _runtime(_FakeEngine(), handle: _handle()).isAvailable(), isTrue);
    });

    test('无激活句柄 → 不可用，不问引擎', () async {
      final _FakeEngine e = _FakeEngine();
      expect(await _runtime(e).isAvailable(), isFalse);
    });

    test('有句柄但引擎未就绪 → 不可用', () async {
      final _FakeEngine e = _FakeEngine(ready: false);
      expect(await _runtime(e, handle: _handle()).isAvailable(), isFalse);
    });
  });

  group('LiteRtRuntime · generate', () {
    test('可用 → ok(text)、source liteRt', () async {
      final _FakeEngine e = _FakeEngine(completeText: '在的');
      final RuntimeResult r =
          await _runtime(e, handle: _handle()).generate('在吗');
      expect(r.isOk, isTrue);
      expect(r.text, '在的');
      expect(r.source, RuntimeSource.liteRt);
    });

    test('无模型 → failure(modelUnavailable)，不调用引擎', () async {
      final _FakeEngine e = _FakeEngine();
      final RuntimeResult r = await _runtime(e).generate('在吗');
      expect(r.error, RuntimeError.modelUnavailable);
      expect(r.source, RuntimeSource.liteRt);
      expect(e.completeCalls, 0);
    });

    test('原生异常 → failure(inferenceFailed)，不抛出', () async {
      final _FakeEngine e = _FakeEngine(throwOnComplete: true);
      final RuntimeResult r =
          await _runtime(e, handle: _handle()).generate('在吗');
      expect(r.error, RuntimeError.inferenceFailed);
    });
  });

  group('LiteRtRuntime · generateStream', () {
    test('可用 → 逐 token 顺序产出', () async {
      final _FakeEngine e =
          _FakeEngine(tokens: const <String>['最', '近', '好吗']);
      final List<String> out =
          await _runtime(e, handle: _handle()).generateStream('在吗').toList();
      expect(out, <String>['最', '近', '好吗']);
    });

    test('无模型 → 抛 modelUnavailable，不调用引擎', () async {
      final _FakeEngine e = _FakeEngine();
      await expectLater(
        _runtime(e).generateStream('在吗'),
        emitsError(const RuntimeException(RuntimeError.modelUnavailable)),
      );
      expect(e.streamCalls, 0);
    });

    test('原生流异常 → 归一为 inferenceFailed', () async {
      final _FakeEngine e = _FakeEngine(
        tokens: const <String>['最'],
        throwOnStream: true,
      );
      await expectLater(
        _runtime(e, handle: _handle()).generateStream('在吗'),
        emitsInOrder(<dynamic>[
          '最',
          emitsError(const RuntimeException(RuntimeError.inferenceFailed)),
        ]),
      );
    });
  });
}
