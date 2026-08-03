import 'package:flutter_test/flutter_test.dart';
import 'package:lostone/models/memories.dart';
import 'package:lostone/models/message.dart';
import 'package:lostone/services/persona/memories_analyzer.dart';

import '../helpers/persona_fixtures.dart';

void main() {
  const DefaultMemoriesAnalyzer analyzer = DefaultMemoriesAnalyzer();

  group('DefaultMemoriesAnalyzer', () {
    test('空消息：timeline.start/end 为 null', () {
      final Memories m = analyzer.analyze(const <Message>[]);
      expect(m.timeline.start, isNull);
      expect(m.timeline.end, isNull);
      expect(m.timeline.messageCount, 0);
      expect(m.keyEvents, isEmpty);
      expect(m.preferences, isEmpty);
    });

    test('时间线取最早/最晚并按 UTC 分桶活跃时段', () {
      final List<Message> messages = <Message>[
        synthMessage(
          id: '1',
          senderId: 'mom',
          senderName: '妈妈',
          isFromMe: false,
          timestamp: DateTime.utc(2024, 1, 2, 20),
          content: '早点睡',
        ),
        synthMessage(
          id: '2',
          senderId: 'mom',
          senderName: '妈妈',
          isFromMe: false,
          timestamp: DateTime.utc(2024, 1, 1, 21),
          content: '吃饭了吗',
        ),
      ];
      final Memories m = analyzer.analyze(messages);
      expect(m.timeline.start, DateTime.utc(2024, 1, 1, 21));
      expect(m.timeline.end, DateTime.utc(2024, 1, 2, 20));
      expect(m.timeline.messageCount, 2);
      expect(m.timeline.activeHours[20], 1);
      expect(m.timeline.activeHours[21], 1);
    });

    test('纪念性关键词触发关键事件（带证据、按时间排序）', () {
      final List<Message> messages = <Message>[
        synthMessage(
          id: '1',
          senderId: 'mom',
          senderName: '妈妈',
          isFromMe: false,
          timestamp: DateTime.utc(2024, 5, 20),
          content: '今天你生日快乐',
        ),
        synthMessage(
          id: '2',
          senderId: 'mom',
          senderName: '妈妈',
          isFromMe: false,
          timestamp: DateTime.utc(2024, 2, 10),
          content: '春节快乐',
        ),
      ];
      final Memories m = analyzer.analyze(messages);
      expect(m.keyEvents, isNotEmpty);
      expect(m.keyEvents.first.at.isBefore(m.keyEvents.last.at), isTrue);
      expect(m.keyEvents.first.evidence.messageKeyHashes, isNotEmpty);
    });

    test('偏好由高频短语提取并附证据', () {
      final List<Message> messages = <Message>[
        for (int i = 0; i < 4; i++)
          synthMessage(
            id: 'p$i',
            senderId: 'mom',
            senderName: '妈妈',
            isFromMe: false,
            timestamp: DateTime.utc(2024, 1, i + 1),
            content: '记得喝汤',
          ),
      ];
      final Memories m = analyzer.analyze(messages);
      expect(m.preferences, isNotEmpty);
      expect(m.preferences.first.evidence.occurrences, greaterThan(0));
    });
  });
}
