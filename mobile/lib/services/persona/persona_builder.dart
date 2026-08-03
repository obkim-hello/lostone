import '../../models/conversation.dart';
import '../../models/evidence.dart';
import '../../models/memories.dart';
import '../../models/message.dart';
import '../../models/persona.dart';
import '../../models/persona_layers.dart';
import 'memories_analyzer.dart';
import 'persona_analyzer.dart';
import 'persona_codec.dart';
import 'text_stats.dart';

/// 目标人物切分结果：目标消息、用户消息、切分是否可靠。
typedef SplitResult = (List<Message> person, List<Message> user, bool resolved);

/// 生成选项。
class PersonaBuildOptions {
  /// 创建生成选项。
  const PersonaBuildOptions({
    this.myIdentifiers = const <String>{},
    this.defaultDisplayName = '未命名',
    this.minMessagesForHigh = 200,
    this.minMessagesForMedium = 50,
    this.topN = 20,
    this.clock,
  });

  /// 代表“用户自己”的 sender 标识集合；其补集视为目标人物。
  final Set<String> myIdentifiers;

  /// 无法从消息推断目标人物名称时的 [Identity.displayName] 回退值。
  final String defaultDisplayName;

  /// 达到该目标人物消息数则层置信度可为 high。
  final int minMessagesForHigh;

  /// 达到该消息数则层置信度可为 medium。
  final int minMessagesForMedium;

  /// 各 Top-N 列表的截断长度。
  final int topN;

  /// 注入式时钟（仅用于 `generatedAt` 元信息，不入任何分析结论）。
  ///
  /// 为空时不抛错：`generatedAt` 取确定性哨兵
  /// `DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)`。绝不回退到
  /// `DateTime.now()`。
  final DateTime Function()? clock;
}

/// Persona 构建器：全量生成与增量更新。
abstract class PersonaBuilder {
  /// 首次全量生成 Persona（`personaVersion == 1`）。
  Future<Persona> build(
    Conversation conversation, {
    Set<String> personSenderIds,
    PersonaBuildOptions options,
  });

  /// 增量更新已有 Persona（`personaVersion == existing.personaVersion + 1`）。
  Future<Persona> update(
    Persona existing,
    Conversation newConversation, {
    Set<String> personSenderIds,
    PersonaBuildOptions options,
  });
}

/// 按发送者切分会话（详见 ERD §4.2 / SPEC §4.1 步骤 1）。
///
/// 主判据 `Message.isFromMe`；[personIds] 覆盖、[myIdentifiers] 细化。
/// 返回目标消息、用户消息，以及切分是否可靠 `resolved`。
SplitResult splitBySender(
  Conversation conversation,
  Set<String> personIds,
  Set<String> myIdentifiers,
) {
  final List<Message> person = <Message>[];
  final List<Message> user = <Message>[];
  for (final Message m in conversation.messages) {
    final bool isUser = m.isFromMe || myIdentifiers.contains(m.senderId);
    final bool isTarget =
        personIds.isNotEmpty ? personIds.contains(m.senderId) : !isUser;
    if (isTarget) {
      person.add(m);
    } else {
      user.add(m);
    }
  }

  bool resolved = true;
  if (conversation.messages.isNotEmpty) {
    final bool noPersonIds = personIds.isEmpty;
    final bool noMyIds = myIdentifiers.isEmpty;
    final bool allNotFromMe =
        conversation.messages.every((Message m) => !m.isFromMe);
    final Set<String> targetSenders =
        person.map((Message m) => m.senderId).toSet();
    if (noPersonIds && noMyIds && allNotFromMe) {
      resolved = false;
    } else if (noPersonIds && targetSenders.length > 1) {
      resolved = false;
    }
  }

  return (person, user, resolved);
}

/// 默认 Persona 构建器（纯本地、确定性、无副作用）。
class DefaultPersonaBuilder implements PersonaBuilder {
  /// 创建构建器。
  const DefaultPersonaBuilder({this.maxHashesPerEvidence = 20});

  /// 单条证据保留的消息键哈希上限（隐私/体积约束）。
  final int maxHashesPerEvidence;

  @override
  Future<Persona> build(
    Conversation conversation, {
    Set<String> personSenderIds = const <String>{},
    PersonaBuildOptions options = const PersonaBuildOptions(),
  }) async {
    _validateOptions(options);

    final SplitResult split =
        splitBySender(conversation, personSenderIds, options.myIdentifiers);
    final List<Message> person = _dedupSorted(split.$1);
    final List<Message> user = _sortByTimestamp(split.$2);
    final bool resolved = split.$3;

    final MemoriesAnalyzer memoriesAnalyzer =
        DefaultMemoriesAnalyzer(topN: options.topN);
    final PersonaAnalyzer analyzer =
        DefaultPersonaAnalyzer(topN: options.topN);

    final Memories memories = memoriesAnalyzer.analyze(person);
    final ExpressionStyle expression = analyzer.analyzeExpression(person);
    final EmotionalLogic emotion = analyzer.analyzeEmotion(person);
    final RelationalBehavior relation = analyzer.analyzeRelation(person, user);
    final List<PersonaTag> tags =
        analyzer.deriveTags(expression, emotion, relation, memories);

    final Confidence level =
        resolved ? _levelFor(person.length, options) : Confidence.low;

    final Set<String> mergedHashes = <String>{
      for (final Message m in person) messageKeyHash(m),
    };
    final Set<String> targetSenderIds =
        person.map((Message m) => m.senderId).toSet();
    final Set<DataSource> sources = _collectSources(conversation);
    final int total = conversation.messages.length;
    final int personCount = person.length;

    return Persona(
      id: _deriveId(conversation.participants, targetSenderIds, sources),
      schemaVersion: kPersonaSchemaVersion,
      personaVersion: 1,
      generatedAt: _now(options),
      identity: _buildIdentity(person, options).withConfidence(level),
      hardRules: const HardRules(),
      expressionStyle: expression.withConfidence(level),
      emotionalLogic: emotion.withConfidence(level),
      relationalBehavior: relation.withConfidence(level),
      tags: <PersonaTag>[
        for (final PersonaTag t in tags) t.withConfidence(level),
      ],
      memories: memories,
      source: PersonaSource(
        sources: sources,
        totalMessages: total,
        personMessages: personCount,
        mergedMessageKeyHashes: mergedHashes,
        revisions: <SourceRevision>[
          SourceRevision(
            personaVersion: 1,
            personMessages: personCount,
            totalMessages: total,
          ),
        ],
        segmentationResolved: resolved,
      ),
    );
  }

  @override
  Future<Persona> update(
    Persona existing,
    Conversation newConversation, {
    Set<String> personSenderIds = const <String>{},
    PersonaBuildOptions options = const PersonaBuildOptions(),
  }) async {
    _validateOptions(options);
    if (existing.schemaVersion != kPersonaSchemaVersion) {
      throw PersonaSchemaException(
        'existing.schemaVersion ${existing.schemaVersion} '
        '!= $kPersonaSchemaVersion（请先 decode 迁移）',
      );
    }

    final SplitResult split =
        splitBySender(newConversation, personSenderIds, options.myIdentifiers);
    final List<Message> newPerson = _sortByTimestamp(split.$1);
    final List<Message> newUser = _sortByTimestamp(split.$2);
    final bool resolvedNew = split.$3;

    final Set<String> existingHashes = existing.source.mergedMessageKeyHashes;
    final Set<String> seen = <String>{...existingHashes};
    final List<Message> trulyNew = <Message>[];
    for (final Message m in newPerson) {
      if (seen.add(messageKeyHash(m))) {
        trulyNew.add(m);
      }
    }

    final int newVersion = existing.personaVersion + 1;

    if (trulyNew.isEmpty) {
      return Persona(
        id: existing.id,
        schemaVersion: kPersonaSchemaVersion,
        personaVersion: newVersion,
        generatedAt: _now(options),
        identity: existing.identity,
        hardRules: existing.hardRules,
        expressionStyle: existing.expressionStyle,
        emotionalLogic: existing.emotionalLogic,
        relationalBehavior: existing.relationalBehavior,
        tags: existing.tags,
        memories: existing.memories,
        source: PersonaSource(
          sources: existing.source.sources,
          totalMessages: existing.source.totalMessages,
          personMessages: existing.source.personMessages,
          mergedMessageKeyHashes: existing.source.mergedMessageKeyHashes,
          revisions: <SourceRevision>[
            ...existing.source.revisions,
            SourceRevision(
              personaVersion: newVersion,
              personMessages: existing.source.personMessages,
              totalMessages: existing.source.totalMessages,
            ),
          ],
          segmentationResolved: existing.source.segmentationResolved,
        ),
      );
    }

    final MemoriesAnalyzer memoriesAnalyzer =
        DefaultMemoriesAnalyzer(topN: options.topN);
    final PersonaAnalyzer analyzer =
        DefaultPersonaAnalyzer(topN: options.topN);

    final int aN = existing.source.personMessages;
    final int bN = trulyNew.length;

    final ExpressionStyle mergedExpression = _mergeExpression(
      existing.expressionStyle,
      analyzer.analyzeExpression(trulyNew),
      aN,
      bN,
      options.topN,
    );
    final EmotionalLogic mergedEmotion = _mergeEmotion(
      existing.emotionalLogic,
      analyzer.analyzeEmotion(trulyNew),
      aN,
      bN,
      options.topN,
    );
    final RelationalBehavior mergedRelation = _mergeRelation(
      existing.relationalBehavior,
      analyzer.analyzeRelation(trulyNew, newUser),
      aN,
      bN,
      options.topN,
    );
    final Memories mergedMemories = _mergeMemories(
      existing.memories,
      memoriesAnalyzer.analyze(trulyNew),
      options.topN,
    );
    final List<PersonaTag> tags = analyzer.deriveTags(
      mergedExpression,
      mergedEmotion,
      mergedRelation,
      mergedMemories,
    );

    final int newPersonCount = aN + bN;
    final int newTotal =
        existing.source.totalMessages + newConversation.messages.length;
    final bool segResolved =
        existing.source.segmentationResolved && resolvedNew;
    final Confidence level =
        segResolved ? _levelFor(newPersonCount, options) : Confidence.low;
    final Set<String> mergedHashes = <String>{
      ...existingHashes,
      for (final Message m in trulyNew) messageKeyHash(m),
    };

    return Persona(
      id: existing.id,
      schemaVersion: kPersonaSchemaVersion,
      personaVersion: newVersion,
      generatedAt: _now(options),
      identity: existing.identity.withConfidence(level),
      hardRules: existing.hardRules,
      expressionStyle: mergedExpression.withConfidence(level),
      emotionalLogic: mergedEmotion.withConfidence(level),
      relationalBehavior: mergedRelation.withConfidence(level),
      tags: <PersonaTag>[
        for (final PersonaTag t in tags) t.withConfidence(level),
      ],
      memories: mergedMemories,
      source: PersonaSource(
        sources: <DataSource>{
          ...existing.source.sources,
          ..._collectSources(newConversation),
        },
        totalMessages: newTotal,
        personMessages: newPersonCount,
        mergedMessageKeyHashes: mergedHashes,
        revisions: <SourceRevision>[
          ...existing.source.revisions,
          SourceRevision(
            personaVersion: newVersion,
            personMessages: newPersonCount,
            totalMessages: newTotal,
          ),
        ],
        segmentationResolved: segResolved,
      ),
    );
  }

  void _validateOptions(PersonaBuildOptions options) {
    if (options.topN < 1) {
      throw ArgumentError.value(options.topN, 'topN', '必须 ≥ 1');
    }
    if (options.minMessagesForMedium < 0) {
      throw ArgumentError.value(
        options.minMessagesForMedium,
        'minMessagesForMedium',
        '必须 ≥ 0',
      );
    }
    if (options.minMessagesForHigh < options.minMessagesForMedium) {
      throw ArgumentError.value(
        options.minMessagesForHigh,
        'minMessagesForHigh',
        '必须 ≥ minMessagesForMedium',
      );
    }
  }

  Confidence _levelFor(int personMessages, PersonaBuildOptions options) {
    if (personMessages >= options.minMessagesForHigh) {
      return Confidence.high;
    }
    if (personMessages >= options.minMessagesForMedium) {
      return Confidence.medium;
    }
    return Confidence.low;
  }

  DateTime _now(PersonaBuildOptions options) =>
      options.clock?.call().toUtc() ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  List<Message> _sortByTimestamp(List<Message> messages) {
    final List<(int, Message)> indexed = <(int, Message)>[
      for (int i = 0; i < messages.length; i++) (i, messages[i]),
    ]..sort(((int, Message) a, (int, Message) b) {
        final int byTime =
            a.$2.timestamp.toUtc().compareTo(b.$2.timestamp.toUtc());
        return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
      });
    return <Message>[for (final (int, Message) e in indexed) e.$2];
  }

  List<Message> _dedupSorted(List<Message> messages) {
    final List<Message> sorted = _sortByTimestamp(messages);
    final Set<String> seen = <String>{};
    final List<Message> out = <Message>[];
    for (final Message m in sorted) {
      if (seen.add(messageKeyHash(m))) {
        out.add(m);
      }
    }
    return out;
  }

  Set<DataSource> _collectSources(Conversation conversation) => <DataSource>{
        conversation.source,
        for (final Message m in conversation.messages) m.source,
      };

  String _deriveId(
    List<String> participants,
    Set<String> targetSenderIds,
    Set<DataSource> sources,
  ) {
    final String signature = <String>[
      (participants.toList()..sort()).join(','),
      (targetSenderIds.toList()..sort()).join(','),
      (sources.map((DataSource d) => d.name).toList()..sort()).join(','),
    ].join('|');
    return 'persona-${sha256Hex(signature)}';
  }

  Identity _buildIdentity(List<Message> person, PersonaBuildOptions options) {
    final List<String> names = <String>[
      for (final Message m in person)
        if (m.senderName.isNotEmpty) m.senderName,
    ];
    if (names.isEmpty) {
      return Identity(displayName: options.defaultDisplayName);
    }
    final String displayName = names.first;
    final List<String> aliases =
        (names.toSet()..remove(displayName)).toList()..sort();
    return Identity(displayName: displayName, aliases: aliases);
  }

  ExpressionStyle _mergeExpression(
    ExpressionStyle a,
    ExpressionStyle b,
    int aN,
    int bN,
    int topN,
  ) {
    final int total = aN + bN;
    return ExpressionStyle(
      catchphrases: _mergeTerms(a.catchphrases, b.catchphrases, topN),
      emojiUsage: _mergeTerms(a.emojiUsage, b.emojiUsage, topN),
      punctuation: _mergeTerms(a.punctuation, b.punctuation, topN),
      avgMessageLength: total == 0
          ? 0
          : ((a.avgMessageLength * aN + b.avgMessageLength * bN) / total)
              .round(),
    );
  }

  EmotionalLogic _mergeEmotion(
    EmotionalLogic a,
    EmotionalLogic b,
    int aN,
    int bN,
    int topN,
  ) =>
      EmotionalLogic(
        positiveRatio: _weighted(a.positiveRatio, aN, b.positiveRatio, bN),
        negativeRatio: _weighted(a.negativeRatio, aN, b.negativeRatio, bN),
        comfortPatterns:
            _mergeTerms(a.comfortPatterns, b.comfortPatterns, topN),
        concernPatterns:
            _mergeTerms(a.concernPatterns, b.concernPatterns, topN),
      );

  RelationalBehavior _mergeRelation(
    RelationalBehavior a,
    RelationalBehavior b,
    int aN,
    int bN,
    int topN,
  ) =>
      RelationalBehavior(
        termsForUser: _mergeTerms(a.termsForUser, b.termsForUser, topN),
        initiationRatio:
            _weighted(a.initiationRatio, aN, b.initiationRatio, bN),
        avgResponseGapMinutes: _weighted(
          a.avgResponseGapMinutes,
          aN,
          b.avgResponseGapMinutes,
          bN,
        ),
      );

  Memories _mergeMemories(Memories a, Memories b, int topN) => Memories(
        timeline: _mergeTimeline(a.timeline, b.timeline),
        keyEvents: _mergeKeyEvents(a.keyEvents, b.keyEvents, topN),
        preferences: _mergePreferences(a.preferences, b.preferences, topN),
      );

  TimelineSpan _mergeTimeline(TimelineSpan a, TimelineSpan b) {
    final Map<int, int> hours = <int, int>{};
    for (final MapEntry<int, int> e in a.activeHours.entries) {
      hours[e.key] = (hours[e.key] ?? 0) + e.value;
    }
    for (final MapEntry<int, int> e in b.activeHours.entries) {
      hours[e.key] = (hours[e.key] ?? 0) + e.value;
    }
    final List<int> sortedHours = hours.keys.toList()..sort();
    return TimelineSpan(
      start: _minNullable(a.start, b.start),
      end: _maxNullable(a.end, b.end),
      messageCount: a.messageCount + b.messageCount,
      activeHours: <int, int>{
        for (final int h in sortedHours) h: hours[h]!,
      },
    );
  }

  List<KeyEvent> _mergeKeyEvents(
    List<KeyEvent> a,
    List<KeyEvent> b,
    int topN,
  ) {
    final List<KeyEvent> merged = <KeyEvent>[...a, ...b];
    final Set<String> seen = <String>{};
    final List<KeyEvent> deduped = <KeyEvent>[];
    for (final KeyEvent e in merged) {
      if (seen.add('${e.at.toUtc().toIso8601String()}|${e.summary}')) {
        deduped.add(e);
      }
    }
    deduped.sort((KeyEvent x, KeyEvent y) {
      final int byTime = x.at.compareTo(y.at);
      return byTime != 0 ? byTime : x.summary.compareTo(y.summary);
    });
    return deduped.length > topN ? deduped.sublist(0, topN) : deduped;
  }

  List<Preference> _mergePreferences(
    List<Preference> a,
    List<Preference> b,
    int topN,
  ) {
    final Map<String, Preference> byTerm = <String, Preference>{};
    for (final Preference p in <Preference>[...a, ...b]) {
      final Preference? existing = byTerm[p.term];
      if (existing == null) {
        byTerm[p.term] = p;
      } else {
        byTerm[p.term] = Preference(
          term: p.term,
          count: existing.count + p.count,
          evidence: _mergeEvidence(existing.evidence, p.evidence),
        );
      }
    }
    final List<Preference> ranked = byTerm.values.toList()
      ..sort((Preference x, Preference y) {
        final int byCount = y.count.compareTo(x.count);
        return byCount != 0 ? byCount : x.term.compareTo(y.term);
      });
    return ranked.length > topN ? ranked.sublist(0, topN) : ranked;
  }

  Evidence _mergeEvidence(Evidence a, Evidence b) {
    final List<String> hashes = <String>[...a.messageKeyHashes];
    final Set<String> seen = <String>{...hashes};
    for (final String h in b.messageKeyHashes) {
      if (hashes.length >= maxHashesPerEvidence) {
        break;
      }
      if (seen.add(h)) {
        hashes.add(h);
      }
    }
    return Evidence(
      messageKeyHashes: hashes,
      occurrences: a.occurrences + b.occurrences,
      sampleExcerpt: a.sampleExcerpt ?? b.sampleExcerpt,
    );
  }

  List<TermStat> _mergeTerms(
    List<TermStat> a,
    List<TermStat> b,
    int topN,
  ) {
    final Map<String, int> counts = <String, int>{};
    for (final TermStat t in <TermStat>[...a, ...b]) {
      counts[t.term] = (counts[t.term] ?? 0) + t.count;
    }
    final List<MapEntry<String, int>> entries = counts.entries.toList()
      ..sort((MapEntry<String, int> x, MapEntry<String, int> y) {
        final int byCount = y.value.compareTo(x.value);
        return byCount != 0 ? byCount : x.key.compareTo(y.key);
      });
    return <TermStat>[
      for (final MapEntry<String, int> e in entries.take(topN))
        TermStat(term: e.key, count: e.value),
    ];
  }

  double _weighted(double aVal, int aN, double bVal, int bN) {
    final int total = aN + bN;
    return total == 0 ? 0 : (aVal * aN + bVal * bN) / total;
  }

  DateTime? _minNullable(DateTime? a, DateTime? b) {
    if (a == null) {
      return b;
    }
    if (b == null) {
      return a;
    }
    return a.isBefore(b) ? a : b;
  }

  DateTime? _maxNullable(DateTime? a, DateTime? b) {
    if (a == null) {
      return b;
    }
    if (b == null) {
      return a;
    }
    return a.isAfter(b) ? a : b;
  }
}
