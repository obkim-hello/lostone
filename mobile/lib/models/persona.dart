import 'package:flutter/foundation.dart';

import 'evidence.dart';
import 'memories.dart';
import 'message.dart';
import 'persona_layers.dart';

/// Persona 语义模型的当前 schema 版本。
///
/// 读取更高版本的 `.persona` 应报错；读取更低版本按迁移规则升级。
const int kPersonaSchemaVersion = 1;

/// 一次生成/合并的版本快照（审计用，无原文）。
@immutable
class SourceRevision {
  /// 创建修订快照。
  const SourceRevision({
    required this.personaVersion,
    required this.personMessages,
    required this.totalMessages,
  });

  /// 该修订对应的 [Persona.personaVersion]。
  final int personaVersion;

  /// 该修订时目标人物累计消息数。
  final int personMessages;

  /// 该修订时会话累计总消息数。
  final int totalMessages;

  @override
  bool operator ==(Object other) =>
      other is SourceRevision &&
      other.personaVersion == personaVersion &&
      other.personMessages == personMessages &&
      other.totalMessages == totalMessages;

  @override
  int get hashCode =>
      Object.hash(personaVersion, personMessages, totalMessages);
}

/// 数据来源摘要（PRD 中称 `sourceSummary`，即本类；JSON key 为 `source`）。
@immutable
class PersonaSource {
  /// 创建来源摘要。
  const PersonaSource({
    required this.sources,
    required this.totalMessages,
    required this.personMessages,
    required this.mergedMessageKeyHashes,
    this.revisions = const <SourceRevision>[],
    this.segmentationResolved = true,
  });

  /// 涉及的数据源集合。
  final Set<DataSource> sources;

  /// 会话总消息数。
  final int totalMessages;

  /// 目标人物消息数。
  final int personMessages;

  /// 已并入的**消息键哈希**集合（增量去重基石，定义见 [Evidence]）。
  final Set<String> mergedMessageKeyHashes;

  /// 版本修订轨迹（可追溯历史，满足 PRD 用户故事 2「不静默丢弃」）。
  ///
  /// **连续、完整、无裁剪**：`build` 写入首条（`personaVersion==1`），此后每次
  /// `update` 追加一条，故 `revisions` 恒为 `[v1, v2, …, vN]`。
  final List<SourceRevision> revisions;

  /// 目标人物切分是否可靠（见 ERD §4.2 splitBySender 守卫）。
  ///
  /// `true`（默认）：切分依据充分。`false`：方向/组成不可判定，引擎不臆断把
  /// 全体并入人格，各层与 identity 的 `confidence` 强制 `low`。
  final bool segmentationResolved;

  @override
  bool operator ==(Object other) =>
      other is PersonaSource &&
      setEquals(other.sources, sources) &&
      other.totalMessages == totalMessages &&
      other.personMessages == personMessages &&
      setEquals(other.mergedMessageKeyHashes, mergedMessageKeyHashes) &&
      listEquals(other.revisions, revisions) &&
      other.segmentationResolved == segmentationResolved;

  @override
  int get hashCode => Object.hash(
        Object.hashAllUnordered(sources),
        totalMessages,
        personMessages,
        Object.hashAllUnordered(mergedMessageKeyHashes),
        Object.hashAll(revisions),
        segmentationResolved,
      );
}

/// 一个人格模型：五层结构 + 生成元信息。
///
/// Persona 是对话系统（模块 004/005/006）的唯一输入契约，
/// 不直接暴露原始聊天记录。
@immutable
class Persona {
  /// 创建一个 Persona。
  const Persona({
    required this.id,
    required this.schemaVersion,
    required this.personaVersion,
    required this.generatedAt,
    required this.identity,
    required this.hardRules,
    required this.expressionStyle,
    required this.emotionalLogic,
    required this.relationalBehavior,
    required this.tags,
    required this.memories,
    required this.source,
  });

  /// 稳定标识。**确定性派生**：对来源签名
  /// `sortedParticipants | sortedTargetSenderIds | sortedDataSources`
  /// 取 SHA-256 得到（不含首条消息键或消息数，见 ERD §3.1）。
  /// 增量更新时从既有 Persona 原样沿用，跨版本不变。
  final String id;

  /// 语义 schema 版本，见 [kPersonaSchemaVersion]。
  final int schemaVersion;

  /// 内容版本，随每次（含增量）成功生成递增，首次为 1。
  final int personaVersion;

  /// 生成时间（UTC）。仅元信息，不参与任何分析结论。
  final DateTime generatedAt;

  /// 第 2 层：身份。
  final Identity identity;

  /// 第 1 层：硬规则（用户可编辑禁忌，增量永不覆盖）。
  final HardRules hardRules;

  /// 第 3 层：表达风格。
  final ExpressionStyle expressionStyle;

  /// 第 4 层：情感逻辑。
  final EmotionalLogic emotionalLogic;

  /// 第 5 层：关系行为。
  final RelationalBehavior relationalBehavior;

  /// 由统计特征映射出的性格标签（每个附触发依据与置信度）。
  final List<PersonaTag> tags;

  /// 提取出的记忆（时间线/关键事件/偏好）。
  final Memories memories;

  /// 数据来源摘要（数据源、消息数、时间跨度、参与者）。
  final PersonaSource source;

  @override
  bool operator ==(Object other) =>
      other is Persona &&
      other.id == id &&
      other.schemaVersion == schemaVersion &&
      other.personaVersion == personaVersion &&
      other.generatedAt == generatedAt &&
      other.identity == identity &&
      other.hardRules == hardRules &&
      other.expressionStyle == expressionStyle &&
      other.emotionalLogic == emotionalLogic &&
      other.relationalBehavior == relationalBehavior &&
      listEquals(other.tags, tags) &&
      other.memories == memories &&
      other.source == source;

  @override
  int get hashCode => Object.hashAll(<Object?>[
        id,
        schemaVersion,
        personaVersion,
        generatedAt,
        identity,
        hardRules,
        expressionStyle,
        emotionalLogic,
        relationalBehavior,
        Object.hashAll(tags),
        memories,
        source,
      ]);
}
