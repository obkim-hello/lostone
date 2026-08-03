import 'package:flutter/foundation.dart';

import 'evidence.dart';

/// 第 1 层 · 硬规则：显式禁忌与不可逾越的边界。
///
/// 由用户编辑；`PersonaBuilder` 增量更新时**永不覆盖**已有硬规则。
@immutable
class HardRules {
  /// 创建硬规则层。
  const HardRules({
    this.forbiddenTopics = const <String>[],
    this.mustNeverClaim = const <String>[],
    this.safetyNotes = const <String>[],
  });

  /// 禁止触碰的话题。
  final List<String> forbiddenTopics;

  /// AI 绝不可声称的内容（如“我还活着”）。
  final List<String> mustNeverClaim;

  /// 其他安全/伦理约束说明。
  final List<String> safetyNotes;

  @override
  bool operator ==(Object other) =>
      other is HardRules &&
      listEquals(other.forbiddenTopics, forbiddenTopics) &&
      listEquals(other.mustNeverClaim, mustNeverClaim) &&
      listEquals(other.safetyNotes, safetyNotes);

  @override
  int get hashCode => Object.hash(
        Object.hashAll(forbiddenTopics),
        Object.hashAll(mustNeverClaim),
        Object.hashAll(safetyNotes),
      );
}

/// 第 2 层 · 身份：这个人是谁。
@immutable
class Identity {
  /// 创建身份层。
  const Identity({
    required this.displayName,
    this.relationToUser,
    this.aliases = const <String>[],
    this.confidence = Confidence.low,
  });

  /// 显示名称（如“妈妈”）。无可用名称时回退为
  /// `PersonaBuildOptions.defaultDisplayName`（默认“未命名”），
  /// 保证空会话下该字段仍非空。
  final String displayName;

  /// 与用户的关系（母亲/朋友/爱人…）。
  final String? relationToUser;

  /// 昵称/称呼别名（从消息中观察到）。
  final List<String> aliases;

  /// 该层的置信度。
  final Confidence confidence;

  /// 返回一个仅替换置信度的副本。
  Identity withConfidence(Confidence value) => Identity(
        displayName: displayName,
        relationToUser: relationToUser,
        aliases: aliases,
        confidence: value,
      );

  @override
  bool operator ==(Object other) =>
      other is Identity &&
      other.displayName == displayName &&
      other.relationToUser == relationToUser &&
      listEquals(other.aliases, aliases) &&
      other.confidence == confidence;

  @override
  int get hashCode => Object.hash(
        displayName,
        relationToUser,
        Object.hashAll(aliases),
        confidence,
      );
}

/// 第 3 层 · 表达风格：怎么说话。
@immutable
class ExpressionStyle {
  /// 创建表达风格层。
  const ExpressionStyle({
    this.catchphrases = const <TermStat>[],
    this.emojiUsage = const <TermStat>[],
    this.punctuation = const <TermStat>[],
    this.avgMessageLength = 0,
    this.confidence = Confidence.low,
  });

  /// 高频口头禅/句首词（带计数）。
  final List<TermStat> catchphrases;

  /// 高频 emoji/表情（带计数）。
  final List<TermStat> emojiUsage;

  /// 标点习惯统计（如省略号、感叹号密度）。
  final List<TermStat> punctuation;

  /// 平均消息字符长度。
  final int avgMessageLength;

  /// 该层置信度。
  final Confidence confidence;

  /// 返回一个仅替换置信度的副本。
  ExpressionStyle withConfidence(Confidence value) => ExpressionStyle(
        catchphrases: catchphrases,
        emojiUsage: emojiUsage,
        punctuation: punctuation,
        avgMessageLength: avgMessageLength,
        confidence: value,
      );

  @override
  bool operator ==(Object other) =>
      other is ExpressionStyle &&
      listEquals(other.catchphrases, catchphrases) &&
      listEquals(other.emojiUsage, emojiUsage) &&
      listEquals(other.punctuation, punctuation) &&
      other.avgMessageLength == avgMessageLength &&
      other.confidence == confidence;

  @override
  int get hashCode => Object.hash(
        Object.hashAll(catchphrases),
        Object.hashAll(emojiUsage),
        Object.hashAll(punctuation),
        avgMessageLength,
        confidence,
      );
}

/// 第 4 层 · 情感逻辑：如何表达与回应情绪。
@immutable
class EmotionalLogic {
  /// 创建情感逻辑层。
  const EmotionalLogic({
    this.positiveRatio = 0,
    this.negativeRatio = 0,
    this.comfortPatterns = const <TermStat>[],
    this.concernPatterns = const <TermStat>[],
    this.confidence = Confidence.low,
  });

  /// 正向情感词占比 [0,1]。
  final double positiveRatio;

  /// 负向情感词占比 [0,1]。
  final double negativeRatio;

  /// 安慰类话语模式（带计数）。
  final List<TermStat> comfortPatterns;

  /// 关心/叮嘱类话语模式（带计数）。
  final List<TermStat> concernPatterns;

  /// 该层置信度。
  final Confidence confidence;

  /// 返回一个仅替换置信度的副本。
  EmotionalLogic withConfidence(Confidence value) => EmotionalLogic(
        positiveRatio: positiveRatio,
        negativeRatio: negativeRatio,
        comfortPatterns: comfortPatterns,
        concernPatterns: concernPatterns,
        confidence: value,
      );

  @override
  bool operator ==(Object other) =>
      other is EmotionalLogic &&
      other.positiveRatio == positiveRatio &&
      other.negativeRatio == negativeRatio &&
      listEquals(other.comfortPatterns, comfortPatterns) &&
      listEquals(other.concernPatterns, concernPatterns) &&
      other.confidence == confidence;

  @override
  int get hashCode => Object.hash(
        positiveRatio,
        negativeRatio,
        Object.hashAll(comfortPatterns),
        Object.hashAll(concernPatterns),
        confidence,
      );
}

/// 第 5 层 · 关系行为：与用户互动的模式。
@immutable
class RelationalBehavior {
  /// 创建关系行为层。
  const RelationalBehavior({
    this.termsForUser = const <TermStat>[],
    this.initiationRatio = 0,
    this.avgResponseGapMinutes = 0,
    this.confidence = Confidence.low,
  });

  /// 对用户的称呼（带计数）。
  final List<TermStat> termsForUser;

  /// 主动发起对话的比例 [0,1]。
  final double initiationRatio;

  /// 平均回复间隔（分钟）。
  final double avgResponseGapMinutes;

  /// 该层置信度。
  final Confidence confidence;

  /// 返回一个仅替换置信度的副本。
  RelationalBehavior withConfidence(Confidence value) => RelationalBehavior(
        termsForUser: termsForUser,
        initiationRatio: initiationRatio,
        avgResponseGapMinutes: avgResponseGapMinutes,
        confidence: value,
      );

  @override
  bool operator ==(Object other) =>
      other is RelationalBehavior &&
      listEquals(other.termsForUser, termsForUser) &&
      other.initiationRatio == initiationRatio &&
      other.avgResponseGapMinutes == avgResponseGapMinutes &&
      other.confidence == confidence;

  @override
  int get hashCode => Object.hash(
        Object.hashAll(termsForUser),
        initiationRatio,
        avgResponseGapMinutes,
        confidence,
      );
}
