import 'package:flutter_test/flutter_test.dart';
import 'package:lostone/models/evidence.dart';
import 'package:lostone/models/memories.dart';
import 'package:lostone/models/message.dart';
import 'package:lostone/models/persona_layers.dart';
import 'package:lostone/services/persona/persona_analyzer.dart';

import '../helpers/persona_fixtures.dart';

List<Message> _mom(List<String> contents) => <Message>[
      for (int i = 0; i < contents.length; i++)
        synthMessage(
          id: 'm$i',
          senderId: 'mom',
          senderName: '妈妈',
          isFromMe: false,
          timestamp: DateTime.utc(2024, 1, i + 1),
          content: contents[i],
        ),
    ];

void main() {
  const DefaultPersonaAnalyzer analyzer = DefaultPersonaAnalyzer();

  group('analyzeExpression', () {
    test('emoji 与标点分别统计', () {
      final ExpressionStyle s = analyzer.analyzeExpression(_mom(<String>[
        '你好呀！😊',
        '早点睡…😊',
      ]));
      expect(s.emojiUsage.any((TermStat t) => t.term == '😊'), isTrue);
      expect(s.punctuation.any((TermStat t) => t.term == '…'), isTrue);
      expect(s.avgMessageLength, greaterThan(0));
    });

    test('空消息返回空风格', () {
      final ExpressionStyle s = analyzer.analyzeExpression(const <Message>[]);
      expect(s.catchphrases, isEmpty);
      expect(s.avgMessageLength, 0);
    });
  });

  group('analyzeEmotion', () {
    test('正负情感比率落在 [0,1]', () {
      final EmotionalLogic e = analyzer.analyzeEmotion(_mom(<String>[
        '我很开心',
        '别难过',
      ]));
      expect(e.positiveRatio, inInclusiveRange(0, 1));
      expect(e.negativeRatio, inInclusiveRange(0, 1));
    });

    test('关心/安慰模式被捕获', () {
      final EmotionalLogic e = analyzer.analyzeEmotion(_mom(<String>[
        '吃饭了吗',
        '没事的 别担心',
      ]));
      expect(e.concernPatterns, isNotEmpty);
      expect(e.comfortPatterns, isNotEmpty);
    });
  });

  group('analyzeRelation', () {
    test('称呼词与主动比率被计算', () {
      final List<Message> person = _mom(<String>['宝贝 早点睡', '宝贝 吃饭了吗']);
      final List<Message> user = <Message>[
        synthMessage(
          id: 'u1',
          senderId: 'me',
          senderName: '我',
          isFromMe: true,
          timestamp: DateTime.utc(2024, 1, 1, 12),
          content: '好',
        ),
      ];
      final RelationalBehavior r = analyzer.analyzeRelation(person, user);
      expect(r.termsForUser.any((TermStat t) => t.term == '宝贝'), isTrue);
      expect(r.initiationRatio, inInclusiveRange(0, 1));
    });
  });

  group('deriveTags', () {
    test('话痨：平均长度 ≥ 30', () {
      const ExpressionStyle style = ExpressionStyle(avgMessageLength: 40);
      final List<PersonaTag> tags = analyzer.deriveTags(
        style,
        const EmotionalLogic(),
        const RelationalBehavior(),
        const Memories(timeline: TimelineSpan(start: null, end: null, messageCount: 0)),
      );
      expect(tags.any((PersonaTag t) => t.label == '话痨'), isTrue);
    });

    test('爱用表情：emoji 总数 ≥ 3', () {
      const ExpressionStyle style = ExpressionStyle(
        emojiUsage: <TermStat>[TermStat(term: '😊', count: 5)],
      );
      final List<PersonaTag> tags = analyzer.deriveTags(
        style,
        const EmotionalLogic(),
        const RelationalBehavior(),
        const Memories(timeline: TimelineSpan(start: null, end: null, messageCount: 0)),
      );
      expect(tags.any((PersonaTag t) => t.label == '爱用表情'), isTrue);
    });

    test('关心型 + 温柔安慰', () {
      const EmotionalLogic emotion = EmotionalLogic(
        concernPatterns: <TermStat>[TermStat(term: '吃饭了吗', count: 4)],
        comfortPatterns: <TermStat>[TermStat(term: '没事的', count: 3)],
      );
      final List<PersonaTag> tags = analyzer.deriveTags(
        const ExpressionStyle(),
        emotion,
        const RelationalBehavior(),
        const Memories(timeline: TimelineSpan(start: null, end: null, messageCount: 0)),
      );
      expect(tags.any((PersonaTag t) => t.label == '关心型'), isTrue);
      expect(tags.any((PersonaTag t) => t.label == '温柔安慰'), isTrue);
    });

    test('黏人：主动比率 ≥ 0.6', () {
      const RelationalBehavior relation =
          RelationalBehavior(initiationRatio: 0.8);
      final List<PersonaTag> tags = analyzer.deriveTags(
        const ExpressionStyle(),
        const EmotionalLogic(),
        relation,
        const Memories(timeline: TimelineSpan(start: null, end: null, messageCount: 0)),
      );
      expect(tags.any((PersonaTag t) => t.label == '黏人'), isTrue);
    });

    test('常提及偏好词', () {
      const Memories memories = Memories(
        timeline: TimelineSpan(start: null, end: null, messageCount: 0),
        preferences: <Preference>[
          Preference(term: '喝汤', count: 5, evidence: Evidence()),
        ],
      );
      final List<PersonaTag> tags = analyzer.deriveTags(
        const ExpressionStyle(),
        const EmotionalLogic(),
        const RelationalBehavior(),
        memories,
      );
      expect(tags.any((PersonaTag t) => t.label == '常提及喝汤'), isTrue);
    });
  });
}
