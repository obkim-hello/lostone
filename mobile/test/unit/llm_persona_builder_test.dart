import 'package:flutter_test/flutter_test.dart';
import 'package:lostone/models/conversation.dart';
import 'package:lostone/models/evidence.dart';
import 'package:lostone/models/memories.dart';
import 'package:lostone/models/message.dart';
import 'package:lostone/models/persona.dart';
import 'package:lostone/models/persona_layers.dart';
import 'package:lostone/services/llm/llm_persona_builder.dart';
import 'package:lostone/services/llm/mock_runtime.dart';
import 'package:lostone/services/llm/persona_runtime.dart';
import 'package:lostone/services/persona/persona_builder.dart';
import 'package:lostone/services/persona/persona_codec.dart';
import 'package:lostone/services/persona/prompt_template.dart';

const String _kJson = '''
{
  "identity": {"displayName": "妈妈", "relationToUser": "母亲"},
  "expression": {"catchphrases": ["记得吃饭", "巴黎铁塔"]},
  "emotion": {"comfortPatterns": ["别怕"], "concernPatterns": ["天冷加衣"]},
  "relation": {"termsForUser": ["宝贝"]},
  "preferences": ["喝茶", "登月计划"],
  "exemplars": ["记得吃饭，别累着自己"],
  "tags": ["关心型"]
}
''';

Message _msg(
  String content, {
  int minute = 0,
  bool fromMe = false,
  String sender = 'mom',
  String name = '妈妈',
  MessageType type = MessageType.text,
}) =>
    Message(
      id: 'm$minute-$content',
      source: DataSource.wechat,
      senderId: fromMe ? 'me' : sender,
      senderName: fromMe ? '我' : name,
      isFromMe: fromMe,
      timestamp: DateTime.utc(2026, 1, 1, 9, minute),
      type: type,
      content: content,
    );

Conversation _conv(List<Message> messages) => Conversation(
      source: DataSource.wechat,
      participants: <String>['我', '妈妈'],
      messages: messages,
      stats: ImportStats(
        totalParsed: messages.length,
        afterDedup: messages.length,
        skipped: 0,
        earliest: messages.isEmpty ? null : messages.first.timestamp,
        latest: messages.isEmpty ? null : messages.last.timestamp,
      ),
    );

List<Message> _corpus() => <Message>[
      _msg('记得吃饭，别累着自己', minute: 1),
      _msg('天冷加衣，宝贝', minute: 2),
      _msg('别怕，有我在', minute: 3),
      _msg('喝茶养生', minute: 4),
      _msg('作业写完了吗', minute: 5, fromMe: true),
    ];

void main() {
  group('DefaultLlmPersonaBuilder.build · LLM 正常路径', () {
    test('T1 五层契约 + version 1 + id 与统计引擎一致', () async {
      final Conversation conv = _conv(_corpus());
      final MockRuntime runtime = MockRuntime(response: _kJson);

      final Persona p = await DefaultLlmPersonaBuilder().build(
        conv,
        runtime: runtime,
      );
      final Persona stat = await const DefaultPersonaBuilder().build(conv);

      expect(p.personaVersion, 1);
      expect(p.schemaVersion, kPersonaSchemaVersion);
      expect(p.id, stat.id);
      expect(p.identity.displayName, '妈妈');
      expect(p.identity.relationToUser, '母亲');
      expect(p.source.totalMessages, conv.messages.length);
      expect(runtime.receivedPrompts, hasLength(1));
    });

    test('T5 原文接地：编造实体被丢弃、真实词句保留', () async {
      final Persona p = await DefaultLlmPersonaBuilder().build(
        _conv(_corpus()),
        runtime: MockRuntime(response: _kJson),
      );
      final List<String> phrases =
          p.expressionStyle.catchphrases.map((TermStat t) => t.term).toList();
      expect(phrases, contains('记得吃饭'));
      expect(phrases, isNot(contains('巴黎铁塔')));

      final List<String> prefs =
          p.memories.preferences.map((Preference x) => x.term).toList();
      expect(prefs, contains('喝茶'));
      expect(prefs, isNot(contains('登月计划')));
    });

    test('render 可用且不泄漏 notes', () async {
      final Persona p = await DefaultLlmPersonaBuilder().build(
        _conv(_corpus()),
        runtime: MockRuntime(response: _kJson),
      );
      final String prompt = const DefaultPromptTemplate().render(p);
      expect(prompt, contains('妈妈'));
      expect(prompt, contains('记得吃饭'));
      expect(prompt, isNot(contains('原材料不足')));
    });
  });

  group('DefaultLlmPersonaBuilder.build · 兜底与隐私', () {
    test('T3 空目标语料 → 骨架 Persona，未调用 runtime', () async {
      final MockRuntime runtime = MockRuntime(response: _kJson);
      final Persona p = await DefaultLlmPersonaBuilder().build(
        _conv(<Message>[_msg('在吗', minute: 1, fromMe: true)]),
        runtime: runtime,
      );
      expect(p.personaVersion, 1);
      expect(p.identity.confidence, Confidence.low);
      expect(runtime.receivedPrompts, isEmpty);
    });

    test('T7 maxPrivacy → 统计兜底 + note，未调用 runtime', () async {
      final MockRuntime runtime = MockRuntime(response: _kJson);
      final Persona p = await DefaultLlmPersonaBuilder().build(
        _conv(_corpus()),
        runtime: runtime,
        options: const LlmBuildOptions(mode: PersonaRuntimeMode.maxPrivacy),
      );
      expect(runtime.receivedPrompts, isEmpty);
      expect(p.notes, contains('统计兜底：最大隐私模式，未调用 LLM'));
    });

    test('T6 云端未授权 → 兜底，无网络调用（mock 不记录 prompt）', () async {
      final MockRuntime runtime = MockRuntime(
        response: _kJson,
        source: RuntimeSource.cloud,
        error: RuntimeError.unauthorized,
      );
      final Persona p = await DefaultLlmPersonaBuilder().build(
        _conv(_corpus()),
        runtime: runtime,
        options: const LlmBuildOptions(mode: PersonaRuntimeMode.cloud),
      );
      expect(runtime.receivedPrompts, isEmpty);
      expect(p.notes, contains('统计兜底：LLM 生成或解析失败'));
      expect(p.personaVersion, 1);
    });

    test('生成结果不可解析（重试后）→ 统计兜底', () async {
      final MockRuntime runtime = MockRuntime(response: '这里没有 JSON 花括号');
      final Persona p = await DefaultLlmPersonaBuilder().build(
        _conv(_corpus()),
        runtime: runtime,
      );
      expect(runtime.receivedPrompts, hasLength(2));
      expect(p.notes, contains('统计兜底：LLM 生成或解析失败'));
    });
  });

  group('DefaultLlmPersonaBuilder.build · 分块与非文本', () {
    test('T10 超长语料分块 > 1、合并合法、log 记录分块数', () async {
      final List<Message> many = <Message>[
        for (int i = 0; i < 5; i++) _msg('记得吃饭$i', minute: i + 1),
      ];
      final MockRuntime runtime = MockRuntime(response: _kJson);
      final List<String> logs = <String>[];
      final Persona p = await DefaultLlmPersonaBuilder(
        onLog: logs.add,
      ).build(
        _conv(many),
        runtime: runtime,
        options: const LlmBuildOptions(maxChunkMessages: 2),
      );
      expect(runtime.receivedPrompts.length, greaterThan(1));
      expect(logs, contains('蒸馏分块数：3'));
      expect(p.personaVersion, 1);
      expect(p.identity.displayName, '妈妈');
    });

    test('T11 非文本消息计入 totalMessages 但不进入蒸馏语料', () async {
      final List<Message> msgs = <Message>[
        _msg('记得吃饭，别累着自己', minute: 1),
        _msg('天冷加衣，宝贝', minute: 2),
        _msg('[图片]', minute: 3, type: MessageType.image),
      ];
      final MockRuntime runtime = MockRuntime(response: _kJson);
      final Persona p = await DefaultLlmPersonaBuilder().build(
        _conv(msgs),
        runtime: runtime,
      );
      expect(p.source.totalMessages, 3);
      expect(runtime.receivedPrompts.single, isNot(contains('[图片]')));
      expect(runtime.receivedPrompts.single, contains('记得吃饭'));
    });
  });

  group('DefaultLlmPersonaBuilder.update · 增量', () {
    test('T8 无新素材（键哈希全命中）→ 幂等：五层不变，仅版本/修订', () async {
      final DefaultLlmPersonaBuilder builder = DefaultLlmPersonaBuilder();
      final Conversation conv = _conv(_corpus());
      final Persona base = await builder.build(
        conv,
        runtime: MockRuntime(response: _kJson),
      );

      final MockRuntime runtime = MockRuntime(response: _kJson);
      final Persona updated = await builder.update(
        base,
        conv,
        runtime: runtime,
      );

      expect(updated.personaVersion, base.personaVersion + 1);
      expect(updated.id, base.id);
      expect(updated.source.revisions, hasLength(base.source.revisions.length + 1));
      expect(updated.expressionStyle, base.expressionStyle);
      expect(updated.emotionalLogic, base.emotionalLogic);
      expect(updated.relationalBehavior, base.relationalBehavior);
      expect(updated.memories, base.memories);
      expect(runtime.receivedPrompts, isEmpty);
    });

    test('T9 增量后 existing.hardRules 永不被覆盖', () async {
      final DefaultLlmPersonaBuilder builder = DefaultLlmPersonaBuilder();
      final Persona base = await builder.build(
        _conv(_corpus()),
        runtime: MockRuntime(response: _kJson),
      );
      const HardRules userRules = HardRules(
        forbiddenTopics: <String>['病情'],
        mustNeverClaim: <String>['我还活着'],
      );
      final Persona edited = _withHardRules(base, userRules);

      final Conversation more = _conv(<Message>[
        _msg('多穿点别感冒', minute: 10),
        _msg('按时睡觉', minute: 11),
        _msg('作业写了吗', minute: 12, fromMe: true),
      ]);
      final Persona updated = await builder.update(
        edited,
        more,
        runtime: MockRuntime(response: _kJson),
      );

      expect(updated.hardRules, userRules);
      expect(updated.personaVersion, edited.personaVersion + 1);
    });

    test('实质新增 → 合并计数累加、来源哈希扩张、契约完整', () async {
      final DefaultLlmPersonaBuilder builder = DefaultLlmPersonaBuilder();
      final Persona base = await builder.build(
        _conv(_corpus()),
        runtime: MockRuntime(response: _kJson),
      );
      final Conversation more = _conv(<Message>[
        _msg('记得吃饭，别累着自己', minute: 20),
        _msg('天冷加衣，宝贝', minute: 21),
      ]);
      final Persona updated = await builder.update(
        base,
        more,
        runtime: MockRuntime(response: _kJson),
      );

      expect(updated.personaVersion, 2);
      expect(updated.source.personMessages,
          greaterThan(base.source.personMessages));
      expect(
        updated.source.mergedMessageKeyHashes.length,
        greaterThan(base.source.mergedMessageKeyHashes.length),
      );
      final TermStat merged = updated.expressionStyle.catchphrases
          .firstWhere((TermStat t) => t.term == '记得吃饭');
      final TermStat original = base.expressionStyle.catchphrases
          .firstWhere((TermStat t) => t.term == '记得吃饭');
      expect(merged.count, greaterThan(original.count));
      expect(const PersonaJsonCodec().decode(const PersonaJsonCodec().encode(updated)),
          updated);
    });

    test('schemaVersion 不符 → 抛 PersonaSchemaException', () async {
      final DefaultLlmPersonaBuilder builder = DefaultLlmPersonaBuilder();
      final Persona base = await builder.build(
        _conv(_corpus()),
        runtime: MockRuntime(response: _kJson),
      );
      final Persona stale = _withSchemaVersion(base, kPersonaSchemaVersion + 1);
      expect(
        () => builder.update(stale, _conv(_corpus()),
            runtime: MockRuntime(response: _kJson)),
        throwsA(isA<PersonaSchemaException>()),
      );
    });
  });
}

Persona _withHardRules(Persona p, HardRules rules) => Persona(
      id: p.id,
      schemaVersion: p.schemaVersion,
      personaVersion: p.personaVersion,
      generatedAt: p.generatedAt,
      identity: p.identity,
      hardRules: rules,
      expressionStyle: p.expressionStyle,
      emotionalLogic: p.emotionalLogic,
      relationalBehavior: p.relationalBehavior,
      tags: p.tags,
      memories: p.memories,
      source: p.source,
      notes: p.notes,
    );

Persona _withSchemaVersion(Persona p, int schemaVersion) => Persona(
      id: p.id,
      schemaVersion: schemaVersion,
      personaVersion: p.personaVersion,
      generatedAt: p.generatedAt,
      identity: p.identity,
      hardRules: p.hardRules,
      expressionStyle: p.expressionStyle,
      emotionalLogic: p.emotionalLogic,
      relationalBehavior: p.relationalBehavior,
      tags: p.tags,
      memories: p.memories,
      source: p.source,
      notes: p.notes,
    );
