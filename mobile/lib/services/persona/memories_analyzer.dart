import '../../models/evidence.dart';
import '../../models/memories.dart';
import '../../models/message.dart';
import 'text_stats.dart';

/// 记忆提取器：从会话中提取时间线/关键事件/偏好。
abstract class MemoriesAnalyzer {
  /// 分析目标人物消息，返回记忆集合。
  ///
  /// [personMessages] 必须已按时间升序、去重。
  Memories analyze(List<Message> personMessages);
}

/// 默认记忆提取器（纯统计、确定性）。
class DefaultMemoriesAnalyzer implements MemoriesAnalyzer {
  /// 创建记忆提取器。
  const DefaultMemoriesAnalyzer({
    this.topN = 20,
    this.maxHashesPerEvidence = 20,
  });

  /// 偏好/事件 Top-N 截断长度。
  final int topN;

  /// 单条证据保留的消息键哈希上限（隐私/体积约束，可截断）。
  final int maxHashesPerEvidence;

  @override
  Memories analyze(List<Message> personMessages) {
    return Memories(
      timeline: _buildTimeline(personMessages),
      keyEvents: _buildKeyEvents(personMessages),
      preferences: _buildPreferences(personMessages),
    );
  }

  TimelineSpan _buildTimeline(List<Message> messages) {
    if (messages.isEmpty) {
      return const TimelineSpan(start: null, end: null, messageCount: 0);
    }
    DateTime min = messages.first.timestamp.toUtc();
    DateTime max = min;
    final Map<int, int> hours = <int, int>{};
    for (final Message m in messages) {
      final DateTime t = m.timestamp.toUtc();
      if (t.isBefore(min)) {
        min = t;
      }
      if (t.isAfter(max)) {
        max = t;
      }
      hours[t.hour] = (hours[t.hour] ?? 0) + 1;
    }
    final List<int> sortedHours = hours.keys.toList()..sort();
    return TimelineSpan(
      start: min,
      end: max,
      messageCount: messages.length,
      activeHours: <int, int>{
        for (final int h in sortedHours) h: hours[h]!,
      },
    );
  }

  List<KeyEvent> _buildKeyEvents(List<Message> messages) {
    final List<KeyEvent> events = <KeyEvent>[];
    for (final Message m in messages) {
      for (final String keyword in kMemorialKeywords) {
        if (m.content.contains(keyword)) {
          events.add(KeyEvent(
            at: m.timestamp.toUtc(),
            summary: '提及$keyword',
            evidence: _evidenceFor(<Message>[m], m.content),
          ));
        }
      }
    }
    events.sort((KeyEvent a, KeyEvent b) {
      final int byTime = a.at.compareTo(b.at);
      return byTime != 0 ? byTime : a.summary.compareTo(b.summary);
    });
    return events.length > topN ? events.sublist(0, topN) : events;
  }

  List<Preference> _buildPreferences(List<Message> messages) {
    final Iterable<String> texts =
        messages.where((Message m) => m.content.isNotEmpty).map((Message m) => m.content);
    final List<TermStat> ngrams = topNgrams(texts, topN: topN);
    return <Preference>[
      for (final TermStat stat in ngrams)
        Preference(
          term: stat.term,
          count: stat.count,
          evidence: _evidenceFor(
            messages.where((Message m) => m.content.contains(stat.term)).toList(),
            null,
          ),
        ),
    ];
  }

  Evidence _evidenceFor(List<Message> supporting, String? excerptSource) {
    final List<String> hashes = <String>[
      for (final Message m in supporting.take(maxHashesPerEvidence))
        messageKeyHash(m),
    ];
    final String? excerpt = excerptSource != null
        ? truncateExcerpt(excerptSource)
        : (supporting.isNotEmpty ? truncateExcerpt(supporting.first.content) : null);
    return Evidence(
      messageKeyHashes: hashes,
      occurrences: supporting.length,
      sampleExcerpt: excerpt,
    );
  }
}
