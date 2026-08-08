import '../../models/conversation.dart';
import '../../models/evidence.dart';
import '../../models/memories.dart';
import '../../models/message.dart';
import '../../models/persona.dart';
import '../../models/persona_layers.dart';
import '../persona/persona_builder.dart';
import '../persona/persona_codec.dart';
import '../persona/text_stats.dart';
import 'distilled_persona.dart';
import 'persona_mapper.dart';
import 'persona_runtime.dart';
import 'prompt_composer.dart';

/// LLM 生成路径的运行模式（ERD-004 §3.2）。
enum PersonaRuntimeMode {
  /// 本地 LiteRT-LM（默认，原文不出设备）。
  local,

  /// 云端 API（显式授权 opt-in）。
  cloud,

  /// 最大隐私：**不调用任何 LLM**，直接走模块 003 统计兜底。
  maxPrivacy,
}

/// 蒸馏被协作式取消时抛出（[LlmBuildOptions.shouldContinue] 返回 `false`）。
///
/// 进行中的单块推理不可中断，故取消在**块边界**生效：当前块跑完即抛出，
/// 调用方据此丢弃进度、回到初始态（不落盘、不视作失败）。
class DistillCancelledException implements Exception {
  /// 创建取消异常。
  const DistillCancelledException();

  @override
  String toString() => 'DistillCancelledException';
}

/// LLM 蒸馏生成选项（ERD-004 §3.1）。
///
/// 兼含切分/置信/时钟等模块 003 兜底所需字段，便于 LLM 路径失败时无缝回落。
class LlmBuildOptions {
  /// 创建生成选项。
  const LlmBuildOptions({
    this.mode = PersonaRuntimeMode.local,
    this.modelId,
    this.temperature = 0.2,
    this.maxChunkMessages = 400,
    this.cloudAuthorized = false,
    this.personSenderIds = const <String>{},
    this.myIdentifiers = const <String>{},
    this.defaultDisplayName = '未命名',
    this.minMessagesForHigh = 200,
    this.minMessagesForMedium = 50,
    this.topN = 20,
    this.clock,
    this.beforeChunk,
  });

  /// 运行模式。
  final PersonaRuntimeMode mode;

  /// 目标模型 id（供运行时选择；本类不解释其含义）。
  final String? modelId;

  /// 蒸馏采样温度（低温以求忠实、可复现）。
  final double temperature;

  /// 单个蒸馏 prompt 的最大消息数（超出即分块，见 [PromptComposer]）。
  final int maxChunkMessages;

  /// 云端是否已授权（信息性；实际授权由 `CloudRuntime` 内部强制）。
  final bool cloudAuthorized;

  /// 代表“目标人物”的 sender 标识集合（空则取“非用户”）。
  final Set<String> personSenderIds;

  /// 代表“用户自己”的 sender 标识集合。
  final Set<String> myIdentifiers;

  /// 无法从消息推断名称时的 [Identity.displayName] 回退值。
  final String defaultDisplayName;

  /// 达到该目标人物消息数则层置信度可为 high。
  final int minMessagesForHigh;

  /// 达到该消息数则层置信度可为 medium。
  final int minMessagesForMedium;

  /// 各 Top-N 列表的截断长度。
  final int topN;

  /// 注入式时钟（仅用于 `generatedAt` 元信息，绝不入分析结论）。
  final DateTime Function()? clock;

  /// 协作式控制闸门：**每块蒸馏前** await。用于暂停/恢复/取消——暂停时其
  /// 返回的 Future 挂起，恢复时完成；取消则抛 [DistillCancelledException]。
  /// 为空表示不可控。进行中的单块推理不可中断，故控制在**块边界**生效。
  final Future<void> Function()? beforeChunk;

  /// 返回一个按需替换字段的副本。
  LlmBuildOptions copyWith({
    PersonaRuntimeMode? mode,
    String? modelId,
    double? temperature,
    int? maxChunkMessages,
    bool? cloudAuthorized,
    Set<String>? personSenderIds,
    Set<String>? myIdentifiers,
    String? defaultDisplayName,
    int? minMessagesForHigh,
    int? minMessagesForMedium,
    int? topN,
    DateTime Function()? clock,
    Future<void> Function()? beforeChunk,
  }) =>
      LlmBuildOptions(
        mode: mode ?? this.mode,
        modelId: modelId ?? this.modelId,
        temperature: temperature ?? this.temperature,
        maxChunkMessages: maxChunkMessages ?? this.maxChunkMessages,
        cloudAuthorized: cloudAuthorized ?? this.cloudAuthorized,
        personSenderIds: personSenderIds ?? this.personSenderIds,
        myIdentifiers: myIdentifiers ?? this.myIdentifiers,
        defaultDisplayName: defaultDisplayName ?? this.defaultDisplayName,
        minMessagesForHigh: minMessagesForHigh ?? this.minMessagesForHigh,
        minMessagesForMedium: minMessagesForMedium ?? this.minMessagesForMedium,
        topN: topN ?? this.topN,
        clock: clock ?? this.clock,
        beforeChunk: beforeChunk ?? this.beforeChunk,
      );
}

/// LLM 蒸馏 Persona 构建器（ERD-004 §4）。
///
/// 对外仍产出模块 003 的 `Persona` 五层契约，下游（对话/持久化）无感。
abstract class LlmPersonaBuilder {
  /// 首次全量生成（`personaVersion == 1`）。
  ///
  /// 流程：切分/去重（模块 003）→ 组 prompt（分块）→ [runtime] 生成 → 解析 →
  /// **原文接地**映射为 `Persona`。任一 LLM 环节失败或 `maxPrivacy` 时，回落
  /// 模块 003 统计兜底并在 `Persona.notes` 标注。
  Future<Persona> build(
    Conversation conversation, {
    required PersonaRuntime runtime,
    LlmBuildOptions options,
  });

  /// 增量更新已有 Persona（`personaVersion == existing.personaVersion + 1`）。
  ///
  /// 仅对**真实新增**素材（键哈希未命中）重蒸馏得到增量 Persona，再与 [existing]
  /// 结构合并；`hardRules` **永不覆盖**（T9）。无新素材（键哈希全命中）时幂等：
  /// 仅递增版本、追加 revision，五层内容不变（T8）。`.persona` 只存哈希，无法
  /// 复现旧原文，故不重蒸馏旧语料——旧结论经证据/计数结构性合并保留。
  Future<Persona> update(
    Persona existing,
    Conversation newConversation, {
    required PersonaRuntime runtime,
    LlmBuildOptions options,
  });
}

/// 默认 LLM 蒸馏构建器。
class DefaultLlmPersonaBuilder implements LlmPersonaBuilder {
  /// 创建构建器。
  ///
  /// [statisticalBuilder] 为模块 003 兜底（只读复用，不重写）。
  /// [onLog] 接收进度（分块数、失败原因）；为空则静默——但**绝不静默截断**，
  /// 分块信息始终经 [onLog] 暴露。[maxParseRetries] 为解析失败的重试上限。
  DefaultLlmPersonaBuilder({
    this.composer = const PromptComposer(),
    this.parser = const DistillationParser(),
    this.mapper = const PersonaMapper(),
    this.statisticalBuilder = const DefaultPersonaBuilder(),
    void Function(String)? onLog,
    this.maxParseRetries = 1,
  }) : _log = onLog ?? _noop;

  /// prompt 组装器。
  final PromptComposer composer;

  /// 蒸馏结果解析器。
  final DistillationParser parser;

  /// 原文接地映射器。
  final PersonaMapper mapper;

  /// 模块 003 统计兜底构建器。
  final PersonaBuilder statisticalBuilder;

  /// 解析失败的重试上限（生成错误不重试，直接兜底）。
  final int maxParseRetries;

  final void Function(String) _log;

  static void _noop(String _) {}

  @override
  Future<Persona> build(
    Conversation conversation, {
    required PersonaRuntime runtime,
    LlmBuildOptions options = const LlmBuildOptions(),
  }) async {
    final SplitResult split =
        splitBySender(conversation, options.personSenderIds, options.myIdentifiers);
    final List<Message> person = _dedupSorted(split.$1);
    final bool resolved = split.$3;

    if (person.isEmpty) {
      return _statistical(conversation, options);
    }
    if (options.mode == PersonaRuntimeMode.maxPrivacy) {
      return _statistical(conversation, options,
          note: '统计兜底：最大隐私模式，未调用 LLM');
    }

    final List<Message> textCorpus = <Message>[
      for (final Message m in person)
        if (m.type == MessageType.text && m.content.isNotEmpty) m,
    ];
    if (textCorpus.isEmpty) {
      return _statistical(conversation, options, note: '统计兜底：无可蒸馏文本语料');
    }

    final List<String> prompts =
        composer.compose(textCorpus, maxChunkMessages: options.maxChunkMessages);
    _log('蒸馏分块数：${prompts.length}');

    final List<DistilledPersona> parts = <DistilledPersona>[];
    for (int i = 0; i < prompts.length; i++) {
      if (options.beforeChunk != null) {
        await options.beforeChunk!();
      }
      _log('蒸馏第 ${i + 1}/${prompts.length} 块…');
      final DistilledPersona? d =
          await _generateAndParse(runtime, prompts[i], options.temperature);
      if (d == null) {
        _log('跳过第 ${i + 1}/${prompts.length} 块（生成或解析失败）');
        continue;
      }
      parts.add(d);
    }
    if (parts.isEmpty) {
      return _statistical(conversation, options, note: '统计兜底：LLM 生成或解析失败');
    }
    if (parts.length < prompts.length) {
      _log('已跳过 ${prompts.length - parts.length}/${prompts.length} 块，'
          '基于 ${parts.length} 块合成');
    }

    final DistilledPersona distilled = _mergeDistilled(parts);
    final Confidence baseLevel =
        resolved ? _levelFor(person.length, options) : Confidence.low;
    final Set<String> targetSenderIds =
        person.map((Message m) => m.senderId).toSet();
    final Set<DataSource> sources = _collectSources(conversation);
    final int total = conversation.messages.length;

    return mapper.map(
      distilled,
      personMessages: textCorpus,
      id: _deriveId(conversation.participants, targetSenderIds, sources),
      personaVersion: 1,
      generatedAt: _now(options),
      source: PersonaSource(
        sources: sources,
        totalMessages: total,
        personMessages: person.length,
        mergedMessageKeyHashes: <String>{
          for (final Message m in person) messageKeyHash(m),
        },
        revisions: <SourceRevision>[
          SourceRevision(
            personaVersion: 1,
            personMessages: person.length,
            totalMessages: total,
          ),
        ],
        segmentationResolved: resolved,
      ),
      baseLevel: baseLevel,
      defaultDisplayName: options.defaultDisplayName,
    );
  }

  @override
  Future<Persona> update(
    Persona existing,
    Conversation newConversation, {
    required PersonaRuntime runtime,
    LlmBuildOptions options = const LlmBuildOptions(),
  }) async {
    if (existing.schemaVersion != kPersonaSchemaVersion) {
      throw PersonaSchemaException(
        'existing.schemaVersion ${existing.schemaVersion} '
        '!= $kPersonaSchemaVersion（请先 decode 迁移）',
      );
    }

    final SplitResult split = splitBySender(
        newConversation, options.personSenderIds, options.myIdentifiers);
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
      return _revisionOnly(existing, newVersion, options);
    }

    final Persona delta =
        await _buildDelta(newConversation, trulyNew, newUser, runtime, options);
    return _merge(
      existing,
      delta,
      trulyNew,
      newConversation,
      newVersion,
      resolvedNew,
      options,
    );
  }

  Future<Persona> _buildDelta(
    Conversation base,
    List<Message> trulyNew,
    List<Message> newUser,
    PersonaRuntime runtime,
    LlmBuildOptions options,
  ) {
    final List<Message> msgs = <Message>[...trulyNew, ...newUser];
    final Conversation deltaConv = Conversation(
      source: base.source,
      participants: base.participants,
      messages: msgs,
      stats: ImportStats(
        totalParsed: msgs.length,
        afterDedup: msgs.length,
        skipped: 0,
        earliest: null,
        latest: null,
      ),
    );
    return build(deltaConv, runtime: runtime, options: options);
  }

  Persona _revisionOnly(Persona existing, int newVersion, LlmBuildOptions options) =>
      Persona(
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
        notes: existing.notes,
      );

  Persona _merge(
    Persona existing,
    Persona delta,
    List<Message> trulyNew,
    Conversation newConversation,
    int newVersion,
    bool resolvedNew,
    LlmBuildOptions options,
  ) {
    final int aN = existing.source.personMessages;
    final int bN = trulyNew.length;
    final int topN = options.topN;

    final ExpressionStyle expr = _mergeExpression(
        existing.expressionStyle, delta.expressionStyle, aN, bN, topN);
    final EmotionalLogic emo =
        _mergeEmotion(existing.emotionalLogic, delta.emotionalLogic, aN, bN, topN);
    final RelationalBehavior rel = _mergeRelation(
        existing.relationalBehavior, delta.relationalBehavior, aN, bN, topN);
    final Memories mem = _mergeMemories(existing.memories, delta.memories, topN);
    final List<String> aliases = <String>{
      ...existing.identity.aliases,
      ...delta.identity.aliases,
    }.toList()
      ..sort();
    final List<PersonaTag> tags = _mergeTags(existing.tags, delta.tags);

    final int mergedCount = aN + bN;
    final bool segResolved =
        existing.source.segmentationResolved && resolvedNew;
    final Confidence base =
        segResolved ? _levelFor(mergedCount, options) : Confidence.low;

    final bool identityLow = existing.identity.displayName.isEmpty;
    final bool exprLow = expr.catchphrases.isEmpty &&
        expr.emojiUsage.isEmpty &&
        expr.punctuation.isEmpty;
    final bool emoLow =
        emo.comfortPatterns.isEmpty && emo.concernPatterns.isEmpty;
    final bool relLow = rel.termsForUser.isEmpty;
    Confidence lvl(bool low) => low ? Confidence.low : base;

    final int newTotal =
        existing.source.totalMessages + newConversation.messages.length;
    final Set<String> mergedHashes = <String>{
      ...existing.source.mergedMessageKeyHashes,
      for (final Message m in trulyNew) messageKeyHash(m),
    };

    return Persona(
      id: existing.id,
      schemaVersion: kPersonaSchemaVersion,
      personaVersion: newVersion,
      generatedAt: _now(options),
      identity: Identity(
        displayName: existing.identity.displayName,
        relationToUser:
            existing.identity.relationToUser ?? delta.identity.relationToUser,
        aliases: aliases,
        confidence: lvl(identityLow),
      ),
      hardRules: existing.hardRules,
      expressionStyle: expr.withConfidence(lvl(exprLow)),
      emotionalLogic: emo.withConfidence(lvl(emoLow)),
      relationalBehavior: rel.withConfidence(lvl(relLow)),
      tags: tags,
      memories: mem,
      source: PersonaSource(
        sources: <DataSource>{
          ...existing.source.sources,
          ..._collectSources(newConversation),
        },
        totalMessages: newTotal,
        personMessages: mergedCount,
        mergedMessageKeyHashes: mergedHashes,
        revisions: <SourceRevision>[
          ...existing.source.revisions,
          SourceRevision(
            personaVersion: newVersion,
            personMessages: mergedCount,
            totalMessages: newTotal,
          ),
        ],
        segmentationResolved: segResolved,
      ),
      notes: <String>[
        if (identityLow) '原材料不足：身份',
        if (exprLow) '原材料不足：表达风格',
        if (emoLow) '原材料不足：情感逻辑',
        if (relLow) '原材料不足：关系行为',
      ],
    );
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

  List<KeyEvent> _mergeKeyEvents(List<KeyEvent> a, List<KeyEvent> b, int topN) {
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
      final Preference? prev = byTerm[p.term];
      byTerm[p.term] = prev == null
          ? p
          : Preference(
              term: p.term,
              count: prev.count + p.count,
              evidence: _mergeEvidence(prev.evidence, p.evidence),
            );
    }
    final List<Preference> ranked = byTerm.values.toList()
      ..sort((Preference x, Preference y) {
        final int byCount = y.count.compareTo(x.count);
        return byCount != 0 ? byCount : x.term.compareTo(y.term);
      });
    return ranked.length > topN ? ranked.sublist(0, topN) : ranked;
  }

  List<PersonaTag> _mergeTags(List<PersonaTag> a, List<PersonaTag> b) {
    final Map<String, PersonaTag> byLabel = <String, PersonaTag>{};
    for (final PersonaTag t in <PersonaTag>[...a, ...b]) {
      final PersonaTag? prev = byLabel[t.label];
      byLabel[t.label] = prev == null
          ? t
          : PersonaTag(
              label: t.label,
              evidence: _mergeEvidence(prev.evidence, t.evidence),
              confidence: t.confidence.index > prev.confidence.index
                  ? t.confidence
                  : prev.confidence,
            );
    }
    return byLabel.values.toList()
      ..sort((PersonaTag x, PersonaTag y) => x.label.compareTo(y.label));
  }

  Evidence _mergeEvidence(Evidence a, Evidence b) {
    final List<String> hashes = <String>[...a.messageKeyHashes];
    final Set<String> seen = <String>{...hashes};
    for (final String h in b.messageKeyHashes) {
      if (hashes.length >= mapper.maxHashesPerEvidence) {
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

  List<TermStat> _mergeTerms(List<TermStat> a, List<TermStat> b, int topN) {
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

  Future<DistilledPersona?> _generateAndParse(
    PersonaRuntime runtime,
    String prompt,
    double temperature,
  ) async {
    String current = prompt;
    for (int attempt = 0; attempt <= maxParseRetries; attempt++) {
      final double temp = attempt == 0 ? temperature : 0.0;
      final RuntimeResult result =
          await runtime.generate(current, temperature: temp);
      if (!result.isOk) {
        _log('蒸馏生成失败：${result.error}');
        return null;
      }
      try {
        return parser.parse(result.text);
      } on DistillationFormatException catch (e) {
        _log('蒸馏解析失败（第 ${attempt + 1} 次）：${e.message}');
        current = composer.repairPrompt(prompt);
      }
    }
    return null;
  }

  Future<Persona> _statistical(
    Conversation conversation,
    LlmBuildOptions options, {
    String? note,
  }) async {
    final Persona p = await statisticalBuilder.build(
      conversation,
      personSenderIds: options.personSenderIds,
      options: _statOptions(options),
    );
    return note == null ? p : _withNotes(p, <String>[note]);
  }

  PersonaBuildOptions _statOptions(LlmBuildOptions o) => PersonaBuildOptions(
        myIdentifiers: o.myIdentifiers,
        defaultDisplayName: o.defaultDisplayName,
        minMessagesForHigh: o.minMessagesForHigh,
        minMessagesForMedium: o.minMessagesForMedium,
        topN: o.topN,
        clock: o.clock,
      );

  Persona _withNotes(Persona p, List<String> extra) => Persona(
        id: p.id,
        schemaVersion: p.schemaVersion,
        personaVersion: p.personaVersion,
        generatedAt: p.generatedAt,
        identity: p.identity,
        hardRules: p.hardRules,
        expressionStyle: p.expressionStyle,
        emotionalLogic: p.emotionalLogic,
        relationalBehavior: p.relationalBehavior,
        tags: p.tags,
        memories: p.memories,
        source: p.source,
        notes: <String>[...p.notes, ...extra],
      );

  DistilledPersona _mergeDistilled(List<DistilledPersona> parts) {
    if (parts.length == 1) {
      return parts.first;
    }
    List<String> cat(List<String> Function(DistilledPersona) sel) {
      final List<String> out = <String>[];
      final Set<String> seen = <String>{};
      for (final DistilledPersona p in parts) {
        for (final String s in sel(p)) {
          if (s.isNotEmpty && seen.add(s)) {
            out.add(s);
          }
        }
      }
      return out;
    }

    String? firstStr(String? Function(DistilledPersona) sel) {
      for (final DistilledPersona p in parts) {
        final String? v = sel(p);
        if (v != null && v.isNotEmpty) {
          return v;
        }
      }
      return null;
    }

    double? firstNum(double? Function(DistilledPersona) sel) {
      for (final DistilledPersona p in parts) {
        final double? v = sel(p);
        if (v != null) {
          return v;
        }
      }
      return null;
    }

    return DistilledPersona(
      displayName: firstStr((DistilledPersona p) => p.displayName),
      relationToUser: firstStr((DistilledPersona p) => p.relationToUser),
      aliases: cat((DistilledPersona p) => p.aliases),
      forbiddenTopics: cat((DistilledPersona p) => p.forbiddenTopics),
      mustNeverClaim: cat((DistilledPersona p) => p.mustNeverClaim),
      safetyNotes: cat((DistilledPersona p) => p.safetyNotes),
      catchphrases: cat((DistilledPersona p) => p.catchphrases),
      emojis: cat((DistilledPersona p) => p.emojis),
      punctuation: cat((DistilledPersona p) => p.punctuation),
      positiveRatio: firstNum((DistilledPersona p) => p.positiveRatio),
      negativeRatio: firstNum((DistilledPersona p) => p.negativeRatio),
      comfortPatterns: cat((DistilledPersona p) => p.comfortPatterns),
      concernPatterns: cat((DistilledPersona p) => p.concernPatterns),
      termsForUser: cat((DistilledPersona p) => p.termsForUser),
      initiationRatio: firstNum((DistilledPersona p) => p.initiationRatio),
      avgResponseGapMinutes:
          firstNum((DistilledPersona p) => p.avgResponseGapMinutes),
      exemplars: cat((DistilledPersona p) => p.exemplars),
      preferences: cat((DistilledPersona p) => p.preferences),
      tags: cat((DistilledPersona p) => p.tags),
      insufficientLayers: cat((DistilledPersona p) => p.insufficientLayers),
    );
  }

  List<Message> _dedupSorted(List<Message> messages) {
    final List<(int, Message)> indexed = <(int, Message)>[
      for (int i = 0; i < messages.length; i++) (i, messages[i]),
    ]..sort(((int, Message) a, (int, Message) b) {
        final int byTime =
            a.$2.timestamp.toUtc().compareTo(b.$2.timestamp.toUtc());
        return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
      });
    final Set<String> seen = <String>{};
    final List<Message> out = <Message>[];
    for (final (int, Message) e in indexed) {
      if (seen.add(messageKeyHash(e.$2))) {
        out.add(e.$2);
      }
    }
    return out;
  }

  Confidence _levelFor(int personMessages, LlmBuildOptions options) {
    if (personMessages >= options.minMessagesForHigh) {
      return Confidence.high;
    }
    if (personMessages >= options.minMessagesForMedium) {
      return Confidence.medium;
    }
    return Confidence.low;
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

  DateTime _now(LlmBuildOptions options) =>
      options.clock?.call().toUtc() ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}
