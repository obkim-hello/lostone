import '../../models/conversation.dart';
import '../../models/evidence.dart';
import '../../models/message.dart';
import '../../models/persona.dart';
import '../../models/persona_layers.dart';
import '../persona/persona_builder.dart';
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
    for (final String prompt in prompts) {
      final DistilledPersona? d =
          await _generateAndParse(runtime, prompt, options.temperature);
      if (d == null) {
        return _statistical(conversation, options, note: '统计兜底：LLM 生成或解析失败');
      }
      parts.add(d);
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

  Future<DistilledPersona?> _generateAndParse(
    PersonaRuntime runtime,
    String prompt,
    double temperature,
  ) async {
    for (int attempt = 0; attempt <= maxParseRetries; attempt++) {
      final RuntimeResult result =
          await runtime.generate(prompt, temperature: temperature);
      if (!result.isOk) {
        _log('蒸馏生成失败：${result.error}');
        return null;
      }
      try {
        return parser.parse(result.text);
      } on DistillationFormatException catch (e) {
        _log('蒸馏解析失败（第 ${attempt + 1} 次）：${e.message}');
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
