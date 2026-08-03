import 'package:characters/characters.dart';

import '../../models/evidence.dart';
import '../../models/memories.dart';
import '../../models/persona.dart';
import '../../models/persona_layers.dart';

/// Prompt 语气档位。
enum PromptTone {
  /// 简洁。
  concise,

  /// 温暖（默认）。
  warm,

  /// 详尽。
  detailed,
}

/// Prompt 渲染选项。
class PromptOptions {
  /// 创建渲染选项。
  const PromptOptions({
    this.tone = PromptTone.warm,
    this.maxChars = 2000,
  });

  /// 语气档位。
  final PromptTone tone;

  /// 输出长度上限（字素簇）。
  final int maxChars;
}

/// Prompt 模板渲染器。
abstract class PromptTemplate {
  /// 把 Persona 渲染为确定性的 system prompt。
  String render(Persona persona, {PromptOptions options});
}

/// 默认 Prompt 模板（纯本地、确定性、仅取 Persona 字段）。
class DefaultPromptTemplate implements PromptTemplate {
  /// 创建模板。
  const DefaultPromptTemplate();

  @override
  String render(
    Persona persona, {
    PromptOptions options = const PromptOptions(),
  }) {
    final List<String> lines = <String>[];
    lines.add('你现在扮演“${persona.identity.displayName}”。');
    if (persona.identity.relationToUser != null) {
      lines.add('你与对方的关系：${persona.identity.relationToUser}。');
    }
    if (persona.identity.aliases.isNotEmpty) {
      lines.add('你可能被称呼为：${persona.identity.aliases.join('、')}。');
    }

    _appendHardRules(lines, persona.hardRules);
    _appendStyle(lines, persona.expressionStyle, options.tone);
    _appendEmotion(lines, persona.emotionalLogic, options.tone);
    _appendRelation(lines, persona.relationalBehavior, options.tone);
    _appendTags(lines, persona.tags);

    if (options.tone == PromptTone.detailed) {
      _appendMemories(lines, persona.memories);
    }

    lines.add('请始终以第一人称、贴合以上风格自然回应，绝不承认自己是 AI 或程序。');

    return _clip(lines.join('\n'), options.maxChars);
  }

  void _appendHardRules(List<String> lines, HardRules rules) {
    if (rules.mustNeverClaim.isNotEmpty) {
      lines.add('绝不声称：${rules.mustNeverClaim.join('、')}。');
    }
    if (rules.forbiddenTopics.isNotEmpty) {
      lines.add('回避话题：${rules.forbiddenTopics.join('、')}。');
    }
    for (final String note in rules.safetyNotes) {
      lines.add('约束：$note。');
    }
  }

  void _appendStyle(
    List<String> lines,
    ExpressionStyle style,
    PromptTone tone,
  ) {
    final int limit = _termLimit(tone);
    final List<String> phrases = _terms(style.catchphrases, limit);
    if (phrases.isNotEmpty) {
      lines.add('常用口头禅：${phrases.join('、')}。');
    }
    final List<String> emojis = _terms(style.emojiUsage, limit);
    if (emojis.isNotEmpty) {
      lines.add('常用表情：${emojis.join(' ')}。');
    }
    if (tone != PromptTone.concise && style.avgMessageLength > 0) {
      lines.add('句子平均长度约 ${style.avgMessageLength} 字。');
    }
  }

  void _appendEmotion(
    List<String> lines,
    EmotionalLogic emotion,
    PromptTone tone,
  ) {
    final int limit = _termLimit(tone);
    final List<String> comfort = _terms(emotion.comfortPatterns, limit);
    if (comfort.isNotEmpty) {
      lines.add('安慰对方时会说：${comfort.join('、')}。');
    }
    final List<String> concern = _terms(emotion.concernPatterns, limit);
    if (concern.isNotEmpty) {
      lines.add('关心对方时会说：${concern.join('、')}。');
    }
  }

  void _appendRelation(
    List<String> lines,
    RelationalBehavior relation,
    PromptTone tone,
  ) {
    final List<String> terms = _terms(relation.termsForUser, _termLimit(tone));
    if (terms.isNotEmpty) {
      lines.add('你会这样称呼对方：${terms.join('、')}。');
    }
  }

  void _appendTags(List<String> lines, List<PersonaTag> tags) {
    if (tags.isEmpty) {
      return;
    }
    final List<String> labels = <String>[
      for (final PersonaTag t in tags) t.label,
    ];
    lines.add('性格特征：${labels.join('、')}。');
  }

  void _appendMemories(List<String> lines, Memories memories) {
    final List<String> prefs = <String>[
      for (final Preference p in memories.preferences.take(5)) p.term,
    ];
    if (prefs.isNotEmpty) {
      lines.add('常提及：${prefs.join('、')}。');
    }
    final List<String> events = <String>[
      for (final KeyEvent e in memories.keyEvents.take(5)) e.summary,
    ];
    if (events.isNotEmpty) {
      lines.add('值得记住的片段：${events.join('；')}。');
    }
  }

  int _termLimit(PromptTone tone) {
    switch (tone) {
      case PromptTone.concise:
        return 3;
      case PromptTone.warm:
        return 5;
      case PromptTone.detailed:
        return 10;
    }
  }

  List<String> _terms(List<TermStat> stats, int limit) => <String>[
        for (final TermStat s in stats.take(limit)) s.term,
      ];

  String _clip(String text, int maxChars) {
    final Characters chars = text.characters;
    if (chars.length <= maxChars) {
      return text;
    }
    return chars.take(maxChars).toString();
  }
}
