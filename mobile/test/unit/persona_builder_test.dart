import 'package:flutter_test/flutter_test.dart';
import 'package:lostone/models/evidence.dart';
import 'package:lostone/models/persona.dart';
import 'package:lostone/models/persona_layers.dart';
import 'package:lostone/services/persona/persona_builder.dart';
import 'package:lostone/services/persona/persona_codec.dart';

import '../helpers/persona_fixtures.dart';

void main() {
  const DefaultPersonaBuilder builder = DefaultPersonaBuilder();

  group('PersonaBuilder.build', () {
    test('返回五层齐全且无 null 层', () async {
      final Persona p = await builder.build(synthConversation());
      expect(p.identity, isNotNull);
      expect(p.hardRules, isNotNull);
      expect(p.expressionStyle, isNotNull);
      expect(p.emotionalLogic, isNotNull);
      expect(p.relationalBehavior, isNotNull);
      expect(p.personaVersion, 1);
      expect(p.schemaVersion, kPersonaSchemaVersion);
    });

    test('空会话返回 low 置信度且不抛异常；不触发切分守卫', () async {
      final Persona p = await builder.build(emptyConversation());
      expect(p.source.personMessages, 0);
      expect(p.identity.confidence, Confidence.low);
      expect(p.source.segmentationResolved, isTrue);
      expect(p.tags, isEmpty);
      expect(p.memories.timeline.start, isNull);
      expect(p.memories.timeline.end, isNull);
      expect(p.identity.displayName, '未命名');
    });

    test('未注入 clock 时零配置可用，generatedAt 为 epoch 哨兵', () async {
      final Persona p = await builder.build(synthConversation());
      expect(p.generatedAt, DateTime.fromMillisecondsSinceEpoch(0, isUtc: true));
    });

    test('注入 clock 时 generatedAt 归一到 UTC', () async {
      final Persona p = await builder.build(
        synthConversation(),
        options: PersonaBuildOptions(
          clock: () => DateTime.utc(2026, 8, 2, 10),
        ),
      );
      expect(p.generatedAt, DateTime.utc(2026, 8, 2, 10));
    });

    test('默认切分以 isFromMe 判对方，用户消息不计入人格', () async {
      final Persona p = await builder.build(mixedFromMeConversation());
      final int expected = mixedFromMeConversation()
          .messages
          .where((m) => !m.isFromMe)
          .length;
      expect(p.source.personMessages, expected);
      expect(p.source.segmentationResolved, isTrue);
    });

    test('方向不可判定时守卫降级：全 low 且 segmentationResolved=false', () async {
      final Persona p =
          await builder.build(indeterminateDirectionConversation());
      expect(p.source.segmentationResolved, isFalse);
      expect(p.identity.confidence, Confidence.low);
      expect(p.expressionStyle.confidence, Confidence.low);
      expect(p.emotionalLogic.confidence, Confidence.low);
      expect(p.relationalBehavior.confidence, Confidence.low);
    });

    test('显式指定 personSenderIds 时不触发守卫', () async {
      final Persona p = await builder.build(
        indeterminateDirectionConversation(),
        personSenderIds: const <String>{'mom'},
      );
      expect(p.source.segmentationResolved, isTrue);
    });

    test('传 myIdentifiers 即可定“我”，不触发方向守卫', () async {
      final Persona p = await builder.build(
        indeterminateDirectionConversation(),
        options: const PersonaBuildOptions(myIdentifiers: <String>{'someone'}),
      );
      expect(p.source.segmentationResolved, isTrue);
    });

    test('多方会话：仅传 myIdentifiers 不抑制多方守卫', () async {
      final Persona p = await builder.build(
        multiPartyConversation(),
        options: const PersonaBuildOptions(myIdentifiers: <String>{'me'}),
      );
      expect(p.source.segmentationResolved, isFalse);
    });

    test('多方会话：显式 personSenderIds 后正常切分', () async {
      final Persona p = await builder.build(
        multiPartyConversation(),
        personSenderIds: const <String>{'mom'},
      );
      expect(p.source.segmentationResolved, isTrue);
      expect(
        p.source.personMessages,
        multiPartyConversation()
            .messages
            .where((m) => m.senderId == 'mom')
            .length,
      );
    });

    test('口头禅按出现次数统计并截断到 topN', () async {
      final Persona p = await builder.build(repeatedPhraseConversation());
      expect(p.expressionStyle.catchphrases.length, lessThanOrEqualTo(20));
      expect(p.expressionStyle.catchphrases.first.count, greaterThan(1));
    });

    test('options 阈值非法抛 ArgumentError', () async {
      expect(
        () => builder.build(
          synthConversation(),
          options: const PersonaBuildOptions(topN: 0),
        ),
        throwsArgumentError,
      );
      expect(
        () => builder.build(
          synthConversation(),
          options: const PersonaBuildOptions(
            minMessagesForHigh: 10,
            minMessagesForMedium: 50,
          ),
        ),
        throwsArgumentError,
      );
    });

    test('置信度按目标人物消息数分档', () async {
      final Persona p = await builder.build(
        synthConversation(),
        options: const PersonaBuildOptions(
          minMessagesForHigh: 3,
          minMessagesForMedium: 2,
        ),
      );
      expect(p.identity.confidence, Confidence.high);
    });

    test('确定性：同输入两次 build 相等（generatedAt 相同哨兵）', () async {
      final Persona a = await builder.build(synthConversation());
      final Persona b = await builder.build(synthConversation());
      expect(a, b);
    });

    test('timeline.messageCount == source.personMessages', () async {
      final Persona p = await builder.build(synthConversation());
      expect(p.memories.timeline.messageCount, p.source.personMessages);
    });

    test('revisions 起点为连续 v1', () async {
      final Persona p = await builder.build(synthConversation());
      expect(p.source.revisions.single.personaVersion, 1);
    });
  });

  group('PersonaBuilder.update', () {
    test('按消息键去重幂等：内容相同但 Message.id 不同不改变统计', () async {
      final Persona v1 = await builder.build(baseConversation());
      final Persona v2 = await builder.update(v1, sameContentDifferentIds());
      expect(v2.personaVersion, 2);
      expect(v2.source.personMessages, v1.source.personMessages);
      expect(v2.source.mergedMessageKeyHashes, v1.source.mergedMessageKeyHashes);
      expect(v2.id, v1.id);
    });

    test('硬规则永不被覆盖', () async {
      final Persona v1 = await builder.build(baseConversation());
      final Persona withRules = Persona(
        id: v1.id,
        schemaVersion: v1.schemaVersion,
        personaVersion: v1.personaVersion,
        generatedAt: v1.generatedAt,
        identity: v1.identity,
        hardRules: const HardRules(mustNeverClaim: <String>['我还活着']),
        expressionStyle: v1.expressionStyle,
        emotionalLogic: v1.emotionalLogic,
        relationalBehavior: v1.relationalBehavior,
        tags: v1.tags,
        memories: v1.memories,
        source: v1.source,
      );
      final Persona v2 = await builder.update(withRules, moreMessages());
      expect(v2.hardRules.mustNeverClaim, <String>['我还活着']);
    });

    test('revisions 连续：build 写 v1，每次 update 追加，末条==personaVersion',
        () async {
      final Persona v1 = await builder.build(baseConversation());
      expect(v1.source.revisions.single.personaVersion, 1);
      final Persona v2 = await builder.update(v1, moreMessages());
      final Persona v3 = await builder.update(v2, evenMoreMessages());
      expect(
        v3.source.revisions.map((SourceRevision r) => r.personaVersion),
        <int>[1, 2, 3],
      );
      expect(v3.source.revisions.last.personaVersion, v3.personaVersion);
      expect(v3.source.revisions.length, v3.personaVersion);
    });

    test('增量累计目标人物消息数', () async {
      final Persona v1 = await builder.build(baseConversation());
      final Persona v2 = await builder.update(v1, moreMessages());
      expect(
        v2.source.personMessages,
        v1.source.personMessages +
            moreMessages().messages.where((m) => !m.isFromMe).length,
      );
      expect(v2.memories.timeline.messageCount, v2.source.personMessages);
    });

    test('超集重建 id 稳定（不含首条消息/消息数）', () async {
      final Persona a = await builder.build(baseConversation());
      final Persona b = await builder.build(supersetConversation());
      expect(b.id, a.id);
    });

    test('schema 不兼容抛 PersonaSchemaException', () async {
      final Persona v1 = await builder.build(baseConversation());
      final Persona future = Persona(
        id: v1.id,
        schemaVersion: kPersonaSchemaVersion + 1,
        personaVersion: v1.personaVersion,
        generatedAt: v1.generatedAt,
        identity: v1.identity,
        hardRules: v1.hardRules,
        expressionStyle: v1.expressionStyle,
        emotionalLogic: v1.emotionalLogic,
        relationalBehavior: v1.relationalBehavior,
        tags: v1.tags,
        memories: v1.memories,
        source: v1.source,
      );
      await expectLater(
        builder.update(future, moreMessages()),
        throwsA(isA<PersonaSchemaException>()),
      );
    });
  });
}
