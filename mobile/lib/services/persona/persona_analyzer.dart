import 'package:characters/characters.dart';

import '../../models/evidence.dart';
import '../../models/memories.dart';
import '../../models/message.dart';
import '../../models/persona_layers.dart';
import 'text_stats.dart';

/// 性格分析器：统计语言风格与情感模式。
abstract class PersonaAnalyzer {
  /// 生成表达风格层。
  ExpressionStyle analyzeExpression(List<Message> personMessages);

  /// 生成情感逻辑层。
  EmotionalLogic analyzeEmotion(List<Message> personMessages);

  /// 生成关系行为层（需用户消息做对照）。
  RelationalBehavior analyzeRelation(
    List<Message> personMessages,
    List<Message> userMessages,
  );

  /// 由统计特征映射出标签集合。
  ///
  /// 同时消费四路信号，覆盖风格类 + 情感类 + 关系类 + 偏好类标签。
  List<PersonaTag> deriveTags(
    ExpressionStyle style,
    EmotionalLogic emotion,
    RelationalBehavior relation,
    Memories memories,
  );
}

/// 默认性格分析器（纯规则/统计、确定性）。
class DefaultPersonaAnalyzer implements PersonaAnalyzer {
  /// 创建性格分析器。
  const DefaultPersonaAnalyzer({
    this.topN = 20,
    this.sessionGapMinutes = 360,
  });

  /// 各 Top-N 列表截断长度。
  final int topN;

  /// 判定“新会话发起”的静默间隔（分钟）。
  final int sessionGapMinutes;

  @override
  ExpressionStyle analyzeExpression(List<Message> personMessages) {
    final List<String> texts = <String>[
      for (final Message m in personMessages)
        if (m.content.isNotEmpty) m.content,
    ];
    return ExpressionStyle(
      catchphrases: topNgrams(texts, topN: topN),
      emojiUsage: emojiStats(texts, topN: topN),
      punctuation: punctuationStats(texts, topN: topN),
      avgMessageLength: _avgLength(texts),
    );
  }

  @override
  EmotionalLogic analyzeEmotion(List<Message> personMessages) {
    final List<String> texts = <String>[
      for (final Message m in personMessages) m.content,
    ];
    return EmotionalLogic(
      positiveRatio: sentimentRatio(texts, kPositiveLexicon),
      negativeRatio: sentimentRatio(texts, kNegativeLexicon),
      comfortPatterns: keywordStats(texts, kComfortPatterns, topN: topN),
      concernPatterns: keywordStats(texts, kConcernPatterns, topN: topN),
    );
  }

  @override
  RelationalBehavior analyzeRelation(
    List<Message> personMessages,
    List<Message> userMessages,
  ) {
    final List<String> personTexts = <String>[
      for (final Message m in personMessages) m.content,
    ];
    final (double initiation, double gap) = _timingStats(
      personMessages,
      userMessages,
    );
    return RelationalBehavior(
      termsForUser: keywordStats(personTexts, kAddressTerms, topN: topN),
      initiationRatio: initiation,
      avgResponseGapMinutes: gap,
    );
  }

  @override
  List<PersonaTag> deriveTags(
    ExpressionStyle style,
    EmotionalLogic emotion,
    RelationalBehavior relation,
    Memories memories,
  ) {
    final List<PersonaTag> tags = <PersonaTag>[];
    void add(String label, int occurrences) {
      tags.add(PersonaTag(
        label: label,
        evidence: Evidence(occurrences: occurrences),
      ));
    }

    if (style.avgMessageLength >= 30) {
      add('话痨', style.avgMessageLength);
    } else if (style.avgMessageLength > 0 && style.avgMessageLength < 8) {
      add('惜字如金', style.avgMessageLength);
    }

    final int emojiTotal = _sum(style.emojiUsage);
    if (emojiTotal >= 3) {
      add('爱用表情', emojiTotal);
    }

    if (emotion.positiveRatio >= 0.5 && emotion.negativeRatio <= 0.15) {
      add('报喜不报忧', (emotion.positiveRatio * 100).round());
    }

    final int concernTotal = _sum(emotion.concernPatterns);
    if (concernTotal >= 3) {
      add('关心型', concernTotal);
    }

    final int comfortTotal = _sum(emotion.comfortPatterns);
    if (comfortTotal >= 3) {
      add('温柔安慰', comfortTotal);
    }

    if (relation.initiationRatio >= 0.6) {
      add('黏人', (relation.initiationRatio * 100).round());
    }

    if (memories.preferences.isNotEmpty &&
        memories.preferences.first.count >= 3) {
      add('常提及${memories.preferences.first.term}',
          memories.preferences.first.count);
    }

    return tags;
  }

  int _avgLength(List<String> texts) {
    if (texts.isEmpty) {
      return 0;
    }
    int total = 0;
    for (final String text in texts) {
      total += text.characters.length;
    }
    return (total / texts.length).round();
  }

  int _sum(List<TermStat> stats) {
    int total = 0;
    for (final TermStat s in stats) {
      total += s.count;
    }
    return total;
  }

  (double, double) _timingStats(
    List<Message> personMessages,
    List<Message> userMessages,
  ) {
    final List<(DateTime, bool)> merged = <(DateTime, bool)>[
      for (final Message m in personMessages) (m.timestamp.toUtc(), true),
      for (final Message m in userMessages) (m.timestamp.toUtc(), false),
    ]..sort(((DateTime, bool) a, (DateTime, bool) b) =>
        a.$1.compareTo(b.$1));
    if (merged.isEmpty) {
      return (0, 0);
    }

    final Duration sessionGap = Duration(minutes: sessionGapMinutes);
    int totalInit = 0;
    int personInit = 0;
    final List<double> responseGaps = <double>[];
    for (int i = 0; i < merged.length; i++) {
      final bool isPerson = merged[i].$2;
      if (i == 0 || merged[i].$1.difference(merged[i - 1].$1) > sessionGap) {
        totalInit++;
        if (isPerson) {
          personInit++;
        }
      } else {
        final bool prevIsUser = !merged[i - 1].$2;
        if (isPerson && prevIsUser) {
          responseGaps.add(
            merged[i].$1.difference(merged[i - 1].$1).inSeconds / 60.0,
          );
        }
      }
    }
    final double initiationRatio =
        totalInit > 0 ? personInit / totalInit : 0;
    final double avgGap = responseGaps.isEmpty
        ? 0
        : responseGaps.reduce((double a, double b) => a + b) /
            responseGaps.length;
    return (initiationRatio, avgGap);
  }
}
