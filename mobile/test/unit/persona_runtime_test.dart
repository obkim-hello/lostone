import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lostone/services/llm/mock_runtime.dart';
import 'package:lostone/services/llm/persona_runtime.dart';

void main() {
  group('RuntimeResult', () {
    test('ok 构造无错误、isOk 为真', () {
      const RuntimeResult r =
          RuntimeResult.ok('hi', source: RuntimeSource.liteRt);
      expect(r.error, isNull);
      expect(r.isOk, isTrue);
      expect(r.text, 'hi');
      expect(r.truncated, isFalse);
    });

    test('failure 构造空文本 + 分类错误、isOk 为假', () {
      const RuntimeResult r = RuntimeResult.failure(
        RuntimeError.unauthorized,
        source: RuntimeSource.cloud,
      );
      expect(r.text, isEmpty);
      expect(r.isOk, isFalse);
      expect(r.error, RuntimeError.unauthorized);
    });

    test('值相等', () {
      expect(
        const RuntimeResult.ok('x', source: RuntimeSource.liteRt),
        const RuntimeResult.ok('x', source: RuntimeSource.liteRt),
      );
      expect(
        const RuntimeResult.ok('x', source: RuntimeSource.liteRt),
        isNot(const RuntimeResult.ok('y', source: RuntimeSource.liteRt)),
      );
    });
  });

  group('MockRuntime.generate', () {
    test('返回固定响应、记录 prompt', () async {
      final MockRuntime rt = MockRuntime(response: '你好呀');
      final RuntimeResult r = await rt.generate('分析这段对话');

      expect(r.isOk, isTrue);
      expect(r.text, '你好呀');
      expect(r.source, RuntimeSource.liteRt);
      expect(rt.receivedPrompts, <String>['分析这段对话']);
    });

    test('注入错误 → 失败结果、不记录 prompt（模拟不发起调用）', () async {
      final MockRuntime rt = MockRuntime(
        source: RuntimeSource.cloud,
        error: RuntimeError.unauthorized,
      );
      final RuntimeResult r = await rt.generate('任意 prompt');

      expect(r.isOk, isFalse);
      expect(r.error, RuntimeError.unauthorized);
      expect(r.text, isEmpty);
      expect(rt.receivedPrompts, isEmpty);
    });
  });

  group('MockRuntime.generateStream', () {
    test('按序逐 token 产出、记录 prompt', () async {
      final MockRuntime rt =
          MockRuntime(tokens: <String>['我', '想', '你', '了']);
      final List<String> out =
          await rt.generateStream('system + user').toList();

      expect(out, <String>['我', '想', '你', '了']);
      expect(rt.receivedPrompts, <String>['system + user']);
    });

    test('maxNewTokens 截断产出', () async {
      final MockRuntime rt =
          MockRuntime(tokens: <String>['a', 'b', 'c', 'd']);
      final List<String> out =
          await rt.generateStream('p', maxNewTokens: 2).toList();

      expect(out, <String>['a', 'b']);
    });

    test('注入错误 → 流经错误通道抛 RuntimeException、不记录 prompt', () async {
      final MockRuntime rt = MockRuntime(
        source: RuntimeSource.cloud,
        error: RuntimeError.network,
      );

      await expectLater(
        rt.generateStream('p'),
        emitsError(
          isA<RuntimeException>()
              .having((RuntimeException e) => e.error, 'error',
                  RuntimeError.network),
        ),
      );
      expect(rt.receivedPrompts, isEmpty);
    });

    test('取消订阅后停止产出、无异常（SPEC T18）', () async {
      final MockRuntime rt = MockRuntime(
        tokens: <String>['1', '2', '3', '4', '5'],
      );
      final List<String> got = <String>[];
      final Completer<void> done = Completer<void>();
      late final StreamSubscription<String> sub;
      sub = rt.generateStream('p').listen((String t) async {
        got.add(t);
        if (got.length == 2) {
          await sub.cancel();
          if (!done.isCompleted) {
            done.complete();
          }
        }
      });

      await done.future;
      await Future<void>.delayed(Duration.zero);

      expect(got, <String>['1', '2']);
    });
  });

  group('MockRuntime.isAvailable / capabilities', () {
    test('available 透传', () async {
      expect(await MockRuntime(available: true).isAvailable(), isTrue);
      expect(await MockRuntime(available: false).isAvailable(), isFalse);
    });

    test('默认能力声明', () {
      final RuntimeCapabilities c = MockRuntime().capabilities;
      expect(c.contextTokens, 4096);
      expect(c.maxOutputTokens, 1024);
      expect(c.supportsStreaming, isTrue);
    });

    test('可注入自定义能力', () {
      final MockRuntime rt = MockRuntime(
        capabilities: const RuntimeCapabilities(
          contextTokens: 512,
          maxOutputTokens: 128,
          supportsStreaming: false,
        ),
      );
      expect(rt.capabilities.contextTokens, 512);
      expect(rt.capabilities.supportsStreaming, isFalse);
    });
  });
}
