import 'package:flutter_test/flutter_test.dart';
import 'package:lostone/models/evidence.dart';
import 'package:lostone/models/memories.dart';
import 'package:lostone/models/persona.dart';
import 'package:lostone/models/persona_layers.dart';
import 'package:lostone/services/persona/persona_builder.dart';

import '../helpers/persona_fixtures.dart';

void main() {
  const DefaultPersonaBuilder builder = DefaultPersonaBuilder();

  group('Persona 值相等与 hashCode', () {
    test('同输入 build 的 Persona 相等且 hashCode 一致', () async {
      final Persona a = await builder.build(synthConversation());
      final Persona b = await builder.build(synthConversation());
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.source, b.source);
      expect(a.source.hashCode, b.source.hashCode);
    });

    test('不同会话的 Persona 不相等', () async {
      final Persona a = await builder.build(synthConversation());
      final Persona b = await builder.build(emptyConversation());
      expect(a == b, isFalse);
    });

    test('SourceRevision 值相等', () {
      const SourceRevision a = SourceRevision(
        personaVersion: 1,
        personMessages: 10,
        totalMessages: 20,
      );
      const SourceRevision b = SourceRevision(
        personaVersion: 1,
        personMessages: 10,
        totalMessages: 20,
      );
      const SourceRevision c = SourceRevision(
        personaVersion: 2,
        personMessages: 10,
        totalMessages: 20,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
    });

    test('各层 hashCode 稳定', () {
      const Identity id = Identity(displayName: '妈妈');
      const EmotionalLogic emotion = EmotionalLogic(positiveRatio: 0.5);
      const RelationalBehavior relation =
          RelationalBehavior(initiationRatio: 0.4);
      const HardRules rules = HardRules(mustNeverClaim: <String>['我还活着']);
      expect(id.hashCode, const Identity(displayName: '妈妈').hashCode);
      expect(emotion.hashCode,
          const EmotionalLogic(positiveRatio: 0.5).hashCode);
      expect(relation.hashCode,
          const RelationalBehavior(initiationRatio: 0.4).hashCode);
      expect(rules.hashCode,
          const HardRules(mustNeverClaim: <String>['我还活着']).hashCode);
      expect(id == const Identity(displayName: '爸爸'), isFalse);
    });
  });

  group('值相等与 hashCode', () {
    test('TermStat 相等', () {
      const TermStat a = TermStat(term: '早点睡', count: 3);
      const TermStat b = TermStat(term: '早点睡', count: 3);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('Evidence 相等（含哈希列表）', () {
      const Evidence a = Evidence(
        messageKeyHashes: <String>['h1', 'h2'],
        occurrences: 2,
      );
      const Evidence b = Evidence(
        messageKeyHashes: <String>['h1', 'h2'],
        occurrences: 2,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('PersonaTag 与 Identity 不同置信度不相等', () {
      const Evidence e = Evidence(occurrences: 1);
      const PersonaTag low = PersonaTag(label: '话痨', evidence: e);
      final PersonaTag high = low.withConfidence(Confidence.high);
      expect(low == high, isFalse);
      expect(high.confidence, Confidence.high);
      expect(high.label, low.label);
    });

    test('withConfidence 仅替换置信度', () {
      const ExpressionStyle style = ExpressionStyle(avgMessageLength: 12);
      final ExpressionStyle high = style.withConfidence(Confidence.high);
      expect(high.avgMessageLength, 12);
      expect(high.confidence, Confidence.high);
      expect(style.confidence, Confidence.low);
    });

    test('TimelineSpan activeHours 顺序无关相等', () {
      const TimelineSpan a = TimelineSpan(
        start: null,
        end: null,
        messageCount: 2,
        activeHours: <int, int>{20: 1, 21: 1},
      );
      const TimelineSpan b = TimelineSpan(
        start: null,
        end: null,
        messageCount: 2,
        activeHours: <int, int>{21: 1, 20: 1},
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('Memories 值相等', () {
      const Memories a = Memories(
        timeline: TimelineSpan(start: null, end: null, messageCount: 0),
      );
      const Memories b = Memories(
        timeline: TimelineSpan(start: null, end: null, messageCount: 0),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
