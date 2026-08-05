import 'package:flutter_test/flutter_test.dart';
import 'package:lostone/models/evidence.dart';
import 'package:lostone/models/memories.dart';
import 'package:lostone/models/message.dart';
import 'package:lostone/models/persona.dart';
import 'package:lostone/models/persona_layers.dart';
import 'package:lostone/services/llm/distilled_persona.dart';
import 'package:lostone/services/llm/persona_mapper.dart';
import 'package:lostone/services/persona/persona_codec.dart';
import 'package:lostone/services/persona/prompt_template.dart';

Message _msg(String content, {int minute = 0, String name = '妈妈'}) => Message(
      id: 'm$minute-$content',
      source: DataSource.wechat,
      senderId: 'mom',
      senderName: name,
      isFromMe: false,
      timestamp: DateTime.utc(2026, 1, 1, 9, minute),
      type: MessageType.text,
      content: content,
    );

PersonaSource _source(int personMessages) => PersonaSource(
      sources: const <DataSource>{DataSource.wechat},
      totalMessages: personMessages,
      personMessages: personMessages,
      mergedMessageKeyHashes: const <String>{},
      revisions: <SourceRevision>[
        SourceRevision(
          personaVersion: 1,
          personMessages: personMessages,
          totalMessages: personMessages,
        ),
      ],
    );

Persona _map(
  DistilledPersona d,
  List<Message> person, {
  Confidence baseLevel = Confidence.medium,
  HardRules? hardRulesOverride,
}) =>
    const PersonaMapper().map(
      d,
      personMessages: person,
      id: 'persona-test',
      personaVersion: 1,
      generatedAt: DateTime.utc(2026, 1, 2),
      source: _source(person.length),
      baseLevel: baseLevel,
      hardRulesOverride: hardRulesOverride,
    );

void main() {
  group('PersonaMapper 契约完整性', () {
    test('五层齐全、无 null、schema/version 正确', () {
      final List<Message> person = <Message>[
        _msg('记得吃饭哦', minute: 1),
        _msg('天冷加衣', minute: 2),
      ];
      const DistilledPersona d = DistilledPersona(
        displayName: '妈妈',
        relationToUser: '母亲',
        catchphrases: <String>['记得吃饭'],
        concernPatterns: <String>['天冷加衣'],
        termsForUser: <String>[],
        tags: <String>['关心型'],
      );

      final Persona p = _map(d, person);

      expect(p.schemaVersion, kPersonaSchemaVersion);
      expect(p.personaVersion, 1);
      expect(p.identity.displayName, '妈妈');
      expect(p.identity.relationToUser, '母亲');
      expect(p.expressionStyle.catchphrases,
          contains(const TermStat(term: '记得吃饭', count: 1)));
      expect(p.emotionalLogic.concernPatterns,
          contains(const TermStat(term: '天冷加衣', count: 1)));
      expect(p.generatedAt.isUtc, isTrue);
    });

    test('displayName 缺失 → 回退默认 + identity 低置信 + note', () {
      final Persona p = _map(
        const DistilledPersona(catchphrases: <String>['嗯']),
        <Message>[_msg('嗯')],
      );
      expect(p.identity.displayName, '未命名');
      expect(p.identity.confidence, Confidence.low);
      expect(p.notes, contains('原材料不足：身份'));
    });
  });

  group('T5 · 不得编造事实（原文接地）', () {
    test('原文不含的实体被丢弃、含的保留', () {
      final List<Message> person = <Message>[
        _msg('晚安，早点睡', minute: 1),
        _msg('晚安啦，记得喝茶', minute: 2),
      ];
      const DistilledPersona d = DistilledPersona(
        displayName: '妈妈',
        catchphrases: <String>['晚安', '巴黎铁塔'],
        preferences: <String>['喝茶', '登月计划'],
      );

      final Persona p = _map(d, person);

      final List<String> phrases =
          p.expressionStyle.catchphrases.map((TermStat t) => t.term).toList();
      expect(phrases, contains('晚安'));
      expect(phrases, isNot(contains('巴黎铁塔')));

      final List<String> prefs =
          p.memories.preferences.map((Preference x) => x.term).toList();
      expect(prefs, contains('喝茶'));
      expect(prefs, isNot(contains('登月计划')));
    });

    test('接地词的计数与证据来自真实匹配', () {
      final List<Message> person = <Message>[
        _msg('晚安', minute: 1),
        _msg('晚安好梦', minute: 2),
        _msg('早安', minute: 3),
      ];
      final Persona p = _map(
        const DistilledPersona(
            displayName: '妈妈', catchphrases: <String>['晚安']),
        person,
      );
      final TermStat stat = p.expressionStyle.catchphrases
          .firstWhere((TermStat t) => t.term == '晚安');
      expect(stat.count, 2);
    });
  });

  group('T4 · 素材不足标注', () {
    test('insufficientLayers 标注 → 层低置信 + note', () {
      final Persona p = _map(
        const DistilledPersona(
          displayName: '妈妈',
          catchphrases: <String>['记得吃饭'],
          concernPatterns: <String>['天冷加衣'],
          termsForUser: <String>['宝贝'],
          insufficientLayers: <String>['emotion'],
        ),
        <Message>[
          _msg('记得吃饭', minute: 1),
          _msg('天冷加衣', minute: 2),
          _msg('宝贝乖', minute: 3),
        ],
      );
      expect(p.emotionalLogic.confidence, Confidence.low);
      expect(p.notes, contains('原材料不足：情感逻辑'));
    });

    test('接地后为空的层自动低置信 + note', () {
      final Persona p = _map(
        const DistilledPersona(
          displayName: '妈妈',
          catchphrases: <String>['记得吃饭'],
        ),
        <Message>[_msg('记得吃饭')],
      );
      expect(p.relationalBehavior.confidence, Confidence.low);
      expect(p.notes, contains('原材料不足：关系行为'));
      expect(p.expressionStyle.confidence, Confidence.medium);
      expect(p.notes, isNot(contains('原材料不足：表达风格')));
    });
  });

  group('增量语义（映射层）', () {
    test('hardRulesOverride 原样沿用（永不覆盖）', () {
      const HardRules preserved = HardRules(
        forbiddenTopics: <String>['病情'],
        mustNeverClaim: <String>['我还活着'],
      );
      final Persona p = _map(
        const DistilledPersona(
          displayName: '妈妈',
          forbiddenTopics: <String>['其他'],
          mustNeverClaim: <String>['别的'],
        ),
        <Message>[_msg('嗯')],
        hardRulesOverride: preserved,
      );
      expect(p.hardRules, preserved);
    });
  });

  group('T2/T12/T13 · 隐私持久化与契约往返', () {
    late Persona persona;

    setUp(() {
      persona = _map(
        const DistilledPersona(
          displayName: '妈妈',
          relationToUser: '母亲',
          catchphrases: <String>['记得吃饭'],
          concernPatterns: <String>['天冷加衣'],
          termsForUser: <String>['宝贝'],
          preferences: <String>['喝茶'],
          exemplars: <String>['记得吃饭，别累着自己'],
          tags: <String>['关心型'],
        ),
        <Message>[
          _msg('记得吃饭，别累着自己', minute: 1),
          _msg('天冷加衣，宝贝', minute: 2),
          _msg('喝茶养生', minute: 3),
        ],
      );
    });

    test('PersonaJsonCodec 往返相等', () {
      const PersonaJsonCodec codec = PersonaJsonCodec();
      expect(codec.decode(codec.encode(persona)), persona);
    });

    test('Evidence 仅哈希 + 短示例，无原文分隔符', () {
      final Evidence ev = persona.memories.preferences.first.evidence;
      expect(ev.messageKeyHashes, isNotEmpty);
      for (final String h in ev.messageKeyHashes) {
        expect(h.contains('|'), isFalse);
        expect(h.length, 64);
      }
      expect(ev.sampleExcerpt, isNotNull);
    });

    test('render 不抛错、含关键风格、且不泄漏 notes', () {
      final String prompt = const DefaultPromptTemplate().render(persona);
      expect(prompt, contains('妈妈'));
      expect(prompt, contains('记得吃饭'));
      expect(prompt, isNot(contains('原材料不足')));
    });
  });
}
