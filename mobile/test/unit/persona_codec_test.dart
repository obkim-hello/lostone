import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lostone/models/evidence.dart';
import 'package:lostone/models/memories.dart';
import 'package:lostone/models/message.dart';
import 'package:lostone/models/persona.dart';
import 'package:lostone/models/persona_layers.dart';
import 'package:lostone/services/persona/persona_builder.dart';
import 'package:lostone/services/persona/persona_codec.dart';

import '../helpers/persona_fixtures.dart';

Persona _samplePersona() => Persona(
      id: 'persona-abc',
      schemaVersion: 1,
      personaVersion: 3,
      generatedAt: DateTime.utc(2026, 8, 2, 10),
      identity: const Identity(
        displayName: '妈妈',
        relationToUser: 'mother',
        aliases: <String>['老妈'],
        confidence: Confidence.high,
      ),
      hardRules: const HardRules(mustNeverClaim: <String>['我还活着']),
      expressionStyle: const ExpressionStyle(
        catchphrases: <TermStat>[TermStat(term: '早点睡', count: 42)],
        emojiUsage: <TermStat>[TermStat(term: '😊', count: 88)],
        punctuation: <TermStat>[TermStat(term: '…', count: 120)],
        avgMessageLength: 14,
        confidence: Confidence.high,
      ),
      emotionalLogic: const EmotionalLogic(
        positiveRatio: 0.62,
        negativeRatio: 0.08,
        comfortPatterns: <TermStat>[TermStat(term: '没事的', count: 15)],
        concernPatterns: <TermStat>[TermStat(term: '吃饭了吗', count: 37)],
        confidence: Confidence.medium,
      ),
      relationalBehavior: const RelationalBehavior(
        termsForUser: <TermStat>[TermStat(term: '宝贝', count: 51)],
        initiationRatio: 0.55,
        avgResponseGapMinutes: 12.3,
        confidence: Confidence.medium,
      ),
      tags: const <PersonaTag>[
        PersonaTag(
          label: '报喜不报忧',
          confidence: Confidence.medium,
          evidence: Evidence(
            messageKeyHashes: <String>['a3f5c1e9d2b47'],
            occurrences: 8,
          ),
        ),
      ],
      memories: Memories(
        timeline: TimelineSpan(
          start: DateTime.utc(2023, 1, 1),
          end: DateTime.utc(2025, 12, 31),
          messageCount: 1240,
          activeHours: const <int, int>{20: 210, 21: 305},
        ),
        keyEvents: <KeyEvent>[
          KeyEvent(
            at: DateTime.utc(2023, 5, 20),
            summary: '提及生日',
            evidence: const Evidence(
              messageKeyHashes: <String>['7b9e0a4c8f13d'],
              occurrences: 1,
            ),
          ),
        ],
        preferences: const <Preference>[
          Preference(
            term: '喝汤',
            count: 23,
            evidence: Evidence(
              messageKeyHashes: <String>['c04d2f8a6e57b'],
              sampleExcerpt: '今天喝汤了吗',
              occurrences: 23,
            ),
          ),
        ],
      ),
      source: const PersonaSource(
        sources: <DataSource>{DataSource.wechat},
        totalMessages: 2600,
        personMessages: 1240,
        mergedMessageKeyHashes: <String>{'e18b3d90a2c4f'},
        revisions: <SourceRevision>[
          SourceRevision(
            personaVersion: 1,
            personMessages: 900,
            totalMessages: 1800,
          ),
          SourceRevision(
            personaVersion: 2,
            personMessages: 1100,
            totalMessages: 2200,
          ),
          SourceRevision(
            personaVersion: 3,
            personMessages: 1240,
            totalMessages: 2600,
          ),
        ],
      ),
    );

void main() {
  const PersonaJsonCodec codec = PersonaJsonCodec();
  const DefaultPersonaBuilder builder = DefaultPersonaBuilder();

  group('PersonaCodec', () {
    test('encode/decode 往返值相等（含 tags、消息键哈希证据与 revisions）', () {
      final Persona p = _samplePersona();
      expect(codec.decode(codec.encode(p)), p);
    });

    test('空会话 Persona 往返：timeline.start/end 为 null', () async {
      final Persona p = await builder.build(emptyConversation());
      final Persona r = codec.decode(codec.encode(p));
      expect(r.memories.timeline.start, isNull);
      expect(r.memories.timeline.end, isNull);
      expect(r.tags, isEmpty);
      expect(r, p);
    });

    test('由 build 产出的 Persona 往返相等', () async {
      final Persona p = await builder.build(synthConversation());
      expect(codec.decode(codec.encode(p)), p);
    });

    test('非法 JSON 抛 FormatException', () {
      expect(
        () => codec.decode(utf8.encode('{bad')),
        throwsFormatException,
      );
    });

    test('schema 版本过高抛 PersonaSchemaException', () {
      final List<int> future =
          utf8.encode(json.encode(<String, dynamic>{'schemaVersion': 2}));
      expect(
        () => codec.decode(future),
        throwsA(isA<PersonaSchemaException>()),
      );
    });

    test('ratio 越界视为损坏抛 FormatException', () {
      final Map<String, dynamic> raw =
          json.decode(utf8.decode(codec.encode(_samplePersona())))
              as Map<String, dynamic>;
      (raw['emotionalLogic'] as Map<String, dynamic>)['positiveRatio'] = 1.2;
      expect(
        () => codec.decode(utf8.encode(json.encode(raw))),
        throwsFormatException,
      );
    });

    test('ratio 浮点误差被 clamp 而非报错', () {
      final Map<String, dynamic> raw =
          json.decode(utf8.decode(codec.encode(_samplePersona())))
              as Map<String, dynamic>;
      (raw['emotionalLogic'] as Map<String, dynamic>)['positiveRatio'] =
          1.0000001;
      final Persona r = codec.decode(utf8.encode(json.encode(raw)));
      expect(r.emotionalLogic.positiveRatio, 1.0);
    });

    test('revisions 非连续抛 FormatException', () {
      final Map<String, dynamic> raw =
          json.decode(utf8.decode(codec.encode(_samplePersona())))
              as Map<String, dynamic>;
      final List<dynamic> revisions =
          (raw['source'] as Map<String, dynamic>)['revisions'] as List<dynamic>;
      (revisions[1] as Map<String, dynamic>)['personaVersion'] = 5;
      expect(
        () => codec.decode(utf8.encode(json.encode(raw))),
        throwsFormatException,
      );
    });

    test('messageKeyHashes 含原文分隔符抛 FormatException', () {
      final Map<String, dynamic> raw =
          json.decode(utf8.decode(codec.encode(_samplePersona())))
              as Map<String, dynamic>;
      final Map<String, dynamic> src = raw['source'] as Map<String, dynamic>;
      src['mergedMessageKeyHashes'] = <String>['wechat|mom|2024'];
      expect(
        () => codec.decode(utf8.encode(json.encode(raw))),
        throwsFormatException,
      );
    });

    test('空 label 抛 FormatException', () {
      final Map<String, dynamic> raw =
          json.decode(utf8.decode(codec.encode(_samplePersona())))
              as Map<String, dynamic>;
      final List<dynamic> tags = raw['tags'] as List<dynamic>;
      (tags[0] as Map<String, dynamic>)['label'] = '';
      expect(
        () => codec.decode(utf8.encode(json.encode(raw))),
        throwsFormatException,
      );
    });

    test('decode 端防御性截断超长 sampleExcerpt', () {
      final Map<String, dynamic> raw =
          json.decode(utf8.decode(codec.encode(_samplePersona())))
              as Map<String, dynamic>;
      final Map<String, dynamic> prefs =
          (raw['memories'] as Map<String, dynamic>)['preferences']
              .first as Map<String, dynamic>;
      final Map<String, dynamic> evidence =
          prefs['evidence'] as Map<String, dynamic>;
      evidence['sampleExcerpt'] = 'x' * 200;
      final Persona r = codec.decode(utf8.encode(json.encode(raw)));
      expect(r.memories.preferences.first.evidence.sampleExcerpt!.length, 60);
    });
  });
}
