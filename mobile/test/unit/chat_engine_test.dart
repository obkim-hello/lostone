import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lostone/models/evidence.dart';
import 'package:lostone/models/memories.dart';
import 'package:lostone/models/message.dart';
import 'package:lostone/models/persona.dart';
import 'package:lostone/models/persona_layers.dart';
import 'package:lostone/services/llm/chat_engine.dart';
import 'package:lostone/services/llm/chat_types.dart';
import 'package:lostone/services/llm/hard_rule_guard.dart';
import 'package:lostone/services/llm/llm_persona_builder.dart';
import 'package:lostone/services/llm/mock_runtime.dart';
import 'package:lostone/services/llm/persona_runtime.dart';
import 'package:lostone/services/persona/prompt_template.dart';

Persona _persona({HardRules? hardRules, String name = '小雨'}) {
  final DateTime t = DateTime.utc(2026);
  return Persona(
    id: 'persona-test',
    schemaVersion: kPersonaSchemaVersion,
    personaVersion: 1,
    generatedAt: t,
    identity: Identity(displayName: name, confidence: Confidence.high),
    hardRules: hardRules ?? const HardRules(),
    expressionStyle: const ExpressionStyle(confidence: Confidence.high),
    emotionalLogic: const EmotionalLogic(confidence: Confidence.high),
    relationalBehavior: const RelationalBehavior(confidence: Confidence.high),
    tags: const <PersonaTag>[],
    memories: Memories(
      timeline: TimelineSpan(
        start: t,
        end: t,
        messageCount: 1,
      ),
    ),
    source: const PersonaSource(
      sources: <DataSource>{DataSource.wechat},
      totalMessages: 1,
      personMessages: 1,
      mergedMessageKeyHashes: <String>{},
    ),
  );
}

ChatTurn _turn(ChatRole role, String text) =>
    ChatTurn(role: role, text: text, at: DateTime.utc(2026));

Future<List<ChatDelta>> _collect(Stream<ChatDelta> stream) => stream.toList();

void main() {
  group('ChatEngine · 正常流', () {
    test('T14: 逐增量顺序输出、末帧 done、system prompt 仅来自 render', () async {
      final Persona persona = _persona();
      final MockRuntime runtime = MockRuntime(
        tokens: const <String>['你好呀', '，', '最近', '过得', '好吗'],
      );
      const DefaultChatEngine engine = DefaultChatEngine();

      final List<ChatDelta> deltas = await _collect(
        engine.chat(persona, const <ChatTurn>[], '在吗', runtime: runtime),
      );

      final String text = deltas
          .where((ChatDelta d) => !d.done && !d.isError)
          .map((ChatDelta d) => d.textDelta)
          .join();
      expect(text, '你好呀，最近过得好吗');
      expect(deltas.last.done, isTrue);
      expect(deltas.any((ChatDelta d) => d.isError), isFalse);

      const PromptTemplate template = DefaultPromptTemplate();
      final String system = template.render(persona);
      expect(runtime.receivedPrompts, hasLength(1));
      expect(runtime.receivedPrompts.single, startsWith(system));
      expect(runtime.receivedPrompts.single, contains('对方：在吗'));
    });
  });

  group('ChatEngine · 滑窗', () {
    test('T15: 超窗历史保留最近 N 轮，裁剪数被记录', () async {
      final Persona persona = _persona();
      final MockRuntime runtime = MockRuntime(tokens: const <String>['嗯']);
      final List<String> logs = <String>[];
      final DefaultChatEngine engine = DefaultChatEngine(onLog: logs.add);
      final List<ChatTurn> history = <ChatTurn>[
        _turn(ChatRole.user, '第一句'),
        _turn(ChatRole.persona, '第二句'),
        _turn(ChatRole.user, '第三句'),
        _turn(ChatRole.persona, '第四句'),
        _turn(ChatRole.user, '第五句'),
      ];

      await _collect(
        engine.chat(
          persona,
          history,
          '第六句',
          runtime: runtime,
          options: const ChatOptions(maxContextTurns: 2),
        ),
      );

      expect(logs, contains('对话滑窗裁剪最旧 3 轮，保留 2 轮'));
      final String prompt = runtime.receivedPrompts.single;
      expect(prompt, isNot(contains('第一句')));
      expect(prompt, isNot(contains('第三句')));
      expect(prompt, contains('第四句'));
      expect(prompt, contains('第五句'));
      expect(prompt, contains('第六句'));
    });
  });

  group('ChatEngine · 硬规则', () {
    test('T16: 越界回复被拦截改写，mustNeverClaim 不出现', () async {
      final Persona persona = _persona(
        hardRules: const HardRules(mustNeverClaim: <String>['我还活着']),
      );
      final MockRuntime runtime = MockRuntime(
        tokens: const <String>['我', '还', '活着', '呢', '，放心'],
      );
      const DefaultChatEngine engine = DefaultChatEngine();
      const HardRuleGuard guard = HardRuleGuard();

      final List<ChatDelta> deltas = await _collect(
        engine.chat(persona, const <ChatTurn>[], '你还在吗', runtime: runtime),
      );

      final String text = deltas
          .where((ChatDelta d) => !d.done && !d.isError)
          .map((ChatDelta d) => d.textDelta)
          .join();
      expect(text, isNot(contains('我还活着')));
      expect(text, contains(guard.safeReply));
      expect(deltas.last.done, isTrue);
    });

    test('自称 AI 被拦截', () async {
      final Persona persona = _persona();
      final MockRuntime runtime = MockRuntime(
        tokens: const <String>['其实', '我是AI', '啦'],
      );
      const DefaultChatEngine engine = DefaultChatEngine();
      const HardRuleGuard guard = HardRuleGuard();

      final List<ChatDelta> deltas = await _collect(
        engine.chat(persona, const <ChatTurn>[], '你是真人吗', runtime: runtime),
      );

      final String text = deltas
          .where((ChatDelta d) => !d.done && !d.isError)
          .map((ChatDelta d) => d.textDelta)
          .join();
      expect(text, isNot(contains('我是AI')));
      expect(text, contains(guard.safeReply));
    });
  });

  group('ChatEngine · 无模型 / 授权 / 空输入', () {
    test('T17a: maxPrivacy → error(modelUnavailable)，不调用 runtime', () async {
      final Persona persona = _persona();
      final MockRuntime runtime = MockRuntime(tokens: const <String>['嗨']);
      const DefaultChatEngine engine = DefaultChatEngine();

      final List<ChatDelta> deltas = await _collect(
        engine.chat(
          persona,
          const <ChatTurn>[],
          '在吗',
          runtime: runtime,
          options: const ChatOptions(mode: PersonaRuntimeMode.maxPrivacy),
        ),
      );

      expect(deltas, hasLength(1));
      expect(deltas.single.error, RuntimeError.modelUnavailable);
      expect(runtime.receivedPrompts, isEmpty);
    });

    test('T17b: 无就绪模型 → error(modelUnavailable)，无兜底', () async {
      final Persona persona = _persona();
      final MockRuntime runtime =
          MockRuntime(available: false, tokens: const <String>['嗨']);
      const DefaultChatEngine engine = DefaultChatEngine();

      final List<ChatDelta> deltas = await _collect(
        engine.chat(persona, const <ChatTurn>[], '在吗', runtime: runtime),
      );

      expect(deltas, hasLength(1));
      expect(deltas.single.error, RuntimeError.modelUnavailable);
      expect(runtime.receivedPrompts, isEmpty);
    });

    test('T19: 云端未授权 → error(unauthorized)，无网络调用', () async {
      final Persona persona = _persona();
      final MockRuntime runtime = MockRuntime(tokens: const <String>['嗨']);
      const DefaultChatEngine engine = DefaultChatEngine();

      final List<ChatDelta> deltas = await _collect(
        engine.chat(
          persona,
          const <ChatTurn>[],
          '在吗',
          runtime: runtime,
          options: const ChatOptions(mode: PersonaRuntimeMode.cloud),
        ),
      );

      expect(deltas, hasLength(1));
      expect(deltas.single.error, RuntimeError.unauthorized);
      expect(runtime.receivedPrompts, isEmpty);
    });

    test('T20: 空消息 → error(emptyInput)，不调用 runtime', () async {
      final Persona persona = _persona();
      final MockRuntime runtime = MockRuntime(tokens: const <String>['嗨']);
      const DefaultChatEngine engine = DefaultChatEngine();

      final List<ChatDelta> deltas = await _collect(
        engine.chat(persona, const <ChatTurn>[], '   ', runtime: runtime),
      );

      expect(deltas, hasLength(1));
      expect(deltas.single.error, RuntimeError.emptyInput);
      expect(runtime.receivedPrompts, isEmpty);
    });
  });

  group('ChatEngine · 取消', () {
    test('T18: 取消订阅后无更多增量、无异常', () async {
      final Persona persona = _persona();
      final MockRuntime runtime = MockRuntime(
        tokens: const <String>['a', 'b', 'c', 'd', 'e'],
      );
      const DefaultChatEngine engine = DefaultChatEngine(
        guard: HardRuleGuard(selfIdentificationMarkers: <String>[]),
      );

      final List<ChatDelta> events = <ChatDelta>[];
      final Completer<void> firstSeen = Completer<void>();
      late final StreamSubscription<ChatDelta> sub;
      sub = engine
          .chat(persona, const <ChatTurn>[], '说点什么', runtime: runtime)
          .listen(
        (ChatDelta d) {
          events.add(d);
          if (!firstSeen.isCompleted) {
            firstSeen.complete();
          }
        },
        onError: (Object e) => fail('取消后不应抛异常：$e'),
      );

      await firstSeen.future;
      await sub.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(events, hasLength(1));
      expect(events.single.done, isFalse);
    });
  });
}
