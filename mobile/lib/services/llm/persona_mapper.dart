import 'package:characters/characters.dart';

import '../../models/evidence.dart';
import '../../models/memories.dart';
import '../../models/message.dart';
import '../../models/persona.dart';
import '../../models/persona_layers.dart';
import '../persona/text_stats.dart';
import 'distilled_persona.dart';

/// 层键 → 中文层名（用于 `insufficientLayers` 归一与 `notes` 文案）。
const Map<String, String> _kLayerLabels = <String, String>{
  'identity': '身份',
  'expression': '表达风格',
  'emotion': '情感逻辑',
  'relation': '关系行为',
};

/// 把 [DistilledPersona] 映射为对外 `Persona`（模块 003 契约）。
///
/// **原文接地（grounding）**：每个词/短语/例句必须在目标人物**原文**中出现
/// （`content.contains`）才保留，并据此构造 `Evidence`（消息键哈希 + 短示例）；
/// 无原文支撑者一律丢弃——落实 SPEC-004 §5.9/T5「不得编造事实」。抽象性格
/// 标签不逐字接地（本就非引用），但接地成功者附证据、失败者置 `occurrences=0`。
///
/// 素材不足（该层接地后为空，或 [DistilledPersona.insufficientLayers] 标注）
/// 的层 `confidence` 置 `low` 并在 `Persona.notes` 追加「原材料不足：<层名>」
/// （见 [DD-003]，note 不进 system prompt）。
class PersonaMapper {
  /// 创建映射器。
  const PersonaMapper({
    this.maxHashesPerEvidence = 20,
    this.maxTermsPerLayer = 20,
    this.maxKeyEvents = 20,
  });

  /// 单条证据保留的消息键哈希上限（隐私/体积约束）。
  final int maxHashesPerEvidence;

  /// 每层词表 Top-N 截断长度。
  final int maxTermsPerLayer;

  /// keyEvents 截断长度。
  final int maxKeyEvents;

  /// 映射为完整 `Persona`。
  ///
  /// [personMessages] 为已切分/去重的目标人物消息（接地语料）。
  /// [source]/[id]/[personaVersion]/[generatedAt] 由 Builder 组装。
  /// [baseLevel] 已计入切分可靠性（不可靠时传 `low`）。
  /// [hardRulesOverride] 非空则原样沿用（增量「硬规则永不覆盖」），否则由
  /// 蒸馏的 coreRules 构造。
  Persona map(
    DistilledPersona distilled, {
    required List<Message> personMessages,
    required String id,
    required int personaVersion,
    required DateTime generatedAt,
    required PersonaSource source,
    required Confidence baseLevel,
    String defaultDisplayName = '未命名',
    HardRules? hardRulesOverride,
  }) {
    final Set<String> insufficient = <String>{
      for (final String k in distilled.insufficientLayers) k.trim().toLowerCase(),
    };

    final List<TermStat> catchphrases =
        _groundedTerms(distilled.catchphrases, personMessages);
    final List<TermStat> emojis =
        _groundedTerms(distilled.emojis, personMessages);
    final List<TermStat> punctuation =
        _groundedTerms(distilled.punctuation, personMessages);
    final List<TermStat> comfort =
        _groundedTerms(distilled.comfortPatterns, personMessages);
    final List<TermStat> concern =
        _groundedTerms(distilled.concernPatterns, personMessages);
    final List<TermStat> termsForUser =
        _groundedTerms(distilled.termsForUser, personMessages);
    final List<Preference> preferences =
        _groundedPreferences(distilled.preferences, personMessages);
    final List<KeyEvent> keyEvents =
        _groundedExemplars(distilled.exemplars, personMessages);
    final List<PersonaTag> tags = _mapTags(distilled.tags, personMessages);

    final bool identityShort =
        distilled.displayName == null || distilled.displayName!.isEmpty;
    final bool identityLow =
        insufficient.contains('identity') || identityShort;
    final bool expressionLow = insufficient.contains('expression') ||
        (catchphrases.isEmpty && emojis.isEmpty && punctuation.isEmpty);
    final bool emotionLow = insufficient.contains('emotion') ||
        (comfort.isEmpty && concern.isEmpty);
    final bool relationLow =
        insufficient.contains('relation') || termsForUser.isEmpty;

    Confidence levelFor(bool low) => low ? Confidence.low : baseLevel;

    final Identity identity = Identity(
      displayName: identityShort ? defaultDisplayName : distilled.displayName!,
      relationToUser: distilled.relationToUser,
      aliases: _groundedAliases(distilled.aliases, personMessages),
      confidence: levelFor(identityLow),
    );

    final ExpressionStyle expression = ExpressionStyle(
      catchphrases: catchphrases,
      emojiUsage: emojis,
      punctuation: punctuation,
      avgMessageLength: _avgLength(personMessages),
      confidence: levelFor(expressionLow),
    );

    final EmotionalLogic emotion = EmotionalLogic(
      positiveRatio: _ratio(distilled.positiveRatio),
      negativeRatio: _ratio(distilled.negativeRatio),
      comfortPatterns: comfort,
      concernPatterns: concern,
      confidence: levelFor(emotionLow),
    );

    final RelationalBehavior relation = RelationalBehavior(
      termsForUser: termsForUser,
      initiationRatio: _ratio(distilled.initiationRatio),
      avgResponseGapMinutes:
          (distilled.avgResponseGapMinutes ?? 0).clamp(0, double.infinity),
      confidence: levelFor(relationLow),
    );

    final List<String> notes = <String>[
      for (final MapEntry<String, bool> e in <String, bool>{
        'identity': identityLow,
        'expression': expressionLow,
        'emotion': emotionLow,
        'relation': relationLow,
      }.entries)
        if (e.value) '原材料不足：${_kLayerLabels[e.key]}',
    ];

    return Persona(
      id: id,
      schemaVersion: kPersonaSchemaVersion,
      personaVersion: personaVersion,
      generatedAt: generatedAt.toUtc(),
      identity: identity,
      hardRules: hardRulesOverride ?? _hardRules(distilled),
      expressionStyle: expression,
      emotionalLogic: emotion,
      relationalBehavior: relation,
      tags: tags,
      memories: Memories(
        timeline: _timeline(personMessages),
        keyEvents: keyEvents,
        preferences: preferences,
      ),
      source: source,
      notes: notes,
    );
  }

  HardRules _hardRules(DistilledPersona d) => HardRules(
        forbiddenTopics: _dedupNonEmpty(d.forbiddenTopics),
        mustNeverClaim: _dedupNonEmpty(d.mustNeverClaim),
        safetyNotes: _dedupNonEmpty(d.safetyNotes),
      );

  List<TermStat> _groundedTerms(List<String> terms, List<Message> corpus) {
    final List<TermStat> out = <TermStat>[];
    final Set<String> seen = <String>{};
    for (final String term in terms) {
      if (term.isEmpty || !seen.add(term)) {
        continue;
      }
      final int occ = _occurrences(term, corpus);
      if (occ > 0) {
        out.add(TermStat(term: term, count: occ));
      }
    }
    return out.length > maxTermsPerLayer ? out.sublist(0, maxTermsPerLayer) : out;
  }

  List<String> _groundedAliases(List<String> aliases, List<Message> corpus) {
    final List<String> out = <String>[];
    final Set<String> seen = <String>{};
    for (final String a in aliases) {
      if (a.isEmpty || !seen.add(a)) {
        continue;
      }
      final bool grounded = corpus.any((Message m) =>
          m.content.contains(a) || m.senderName.contains(a));
      if (grounded) {
        out.add(a);
      }
    }
    return out;
  }

  List<Preference> _groundedPreferences(
    List<String> terms,
    List<Message> corpus,
  ) {
    final List<Preference> out = <Preference>[];
    final Set<String> seen = <String>{};
    for (final String term in terms) {
      if (term.isEmpty || !seen.add(term)) {
        continue;
      }
      final Evidence? ev = _evidenceFor(term, corpus);
      if (ev != null) {
        out.add(Preference(term: term, count: ev.occurrences, evidence: ev));
      }
    }
    out.sort((Preference x, Preference y) {
      final int byCount = y.count.compareTo(x.count);
      return byCount != 0 ? byCount : x.term.compareTo(y.term);
    });
    return out.length > maxTermsPerLayer
        ? out.sublist(0, maxTermsPerLayer)
        : out;
  }

  List<KeyEvent> _groundedExemplars(
    List<String> exemplars,
    List<Message> corpus,
  ) {
    final List<KeyEvent> out = <KeyEvent>[];
    final Set<String> seen = <String>{};
    for (final String ex in exemplars) {
      if (ex.isEmpty || !seen.add(ex)) {
        continue;
      }
      final Message? first = _firstMatch(ex, corpus);
      if (first == null) {
        continue;
      }
      out.add(KeyEvent(
        at: first.timestamp.toUtc(),
        summary: ex,
        evidence: _evidenceFor(ex, corpus)!,
      ));
    }
    out.sort((KeyEvent x, KeyEvent y) {
      final int byTime = x.at.compareTo(y.at);
      return byTime != 0 ? byTime : x.summary.compareTo(y.summary);
    });
    return out.length > maxKeyEvents ? out.sublist(0, maxKeyEvents) : out;
  }

  List<PersonaTag> _mapTags(List<String> labels, List<Message> corpus) {
    final List<PersonaTag> out = <PersonaTag>[];
    final Set<String> seen = <String>{};
    for (final String label in labels) {
      if (label.isEmpty || !seen.add(label)) {
        continue;
      }
      final Evidence? ev = _evidenceFor(label, corpus);
      out.add(PersonaTag(
        label: label,
        evidence: ev ?? const Evidence(),
        confidence: ev == null ? Confidence.low : Confidence.medium,
      ));
    }
    return out;
  }

  Evidence? _evidenceFor(String term, List<Message> corpus) {
    final List<Message> matches = <Message>[
      for (final Message m in corpus)
        if (m.content.contains(term)) m,
    ];
    if (matches.isEmpty) {
      return null;
    }
    return Evidence(
      messageKeyHashes: <String>[
        for (final Message m in matches.take(maxHashesPerEvidence))
          messageKeyHash(m),
      ],
      occurrences: matches.length,
      sampleExcerpt: truncateExcerpt(matches.first.content),
    );
  }

  Message? _firstMatch(String term, List<Message> corpus) {
    for (final Message m in corpus) {
      if (m.content.contains(term)) {
        return m;
      }
    }
    return null;
  }

  int _occurrences(String term, List<Message> corpus) {
    int count = 0;
    for (final Message m in corpus) {
      if (m.content.contains(term)) {
        count++;
      }
    }
    return count;
  }

  int _avgLength(List<Message> corpus) {
    final List<String> texts = <String>[
      for (final Message m in corpus)
        if (m.content.isNotEmpty) m.content,
    ];
    if (texts.isEmpty) {
      return 0;
    }
    int total = 0;
    for (final String t in texts) {
      total += t.characters.length;
    }
    return (total / texts.length).round();
  }

  TimelineSpan _timeline(List<Message> corpus) {
    if (corpus.isEmpty) {
      return const TimelineSpan(start: null, end: null, messageCount: 0);
    }
    DateTime min = corpus.first.timestamp.toUtc();
    DateTime max = min;
    final Map<int, int> hours = <int, int>{};
    for (final Message m in corpus) {
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
      messageCount: corpus.length,
      activeHours: <int, int>{
        for (final int h in sortedHours) h: hours[h]!,
      },
    );
  }

  double _ratio(double? v) => v == null ? 0 : v.clamp(0.0, 1.0);

  List<String> _dedupNonEmpty(List<String> items) {
    final List<String> out = <String>[];
    final Set<String> seen = <String>{};
    for (final String s in items) {
      if (s.isNotEmpty && seen.add(s)) {
        out.add(s);
      }
    }
    return out;
  }
}
