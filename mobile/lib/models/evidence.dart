import 'package:flutter/foundation.dart';

/// 结论置信度。
enum Confidence {
  /// 素材不足或信号弱。
  low,

  /// 中等样本量。
  medium,

  /// 样本充足、信号明确。
  high,
}

/// 词/短语统计项。
@immutable
class TermStat {
  /// 创建统计项。
  const TermStat({required this.term, required this.count});

  /// 词或短语。
  final String term;

  /// 出现次数。
  final int count;

  @override
  bool operator ==(Object other) =>
      other is TermStat && other.term == term && other.count == count;

  @override
  int get hashCode => Object.hash(term, count);
}

/// 可解释性证据：把结论回溯到真实消息，**不持久化原文**。
///
/// 只存**消息键哈希**、计数与一条可选短示例（隐私约束，见 ERD §1.2/§8.1）。
///
/// 消息键哈希 = `sha256Hex(source|senderId|timestamp.iso8601|content|type)`，
/// 底层消息键与模块 002 `DataPreprocessor` 去重键逐字段一致，故哈希跨导入
/// 稳定且可用于去重/幂等/回溯；但不可逆，`.persona` 不再写入逐条原文。
/// 不使用 `Message.id`（后者仅单次导入内可引用、跨导入不稳定）。
@immutable
class Evidence {
  /// 创建证据。
  const Evidence({
    this.messageKeyHashes = const <String>[],
    this.sampleExcerpt,
    this.occurrences = 0,
  });

  /// 支撑该结论的消息键哈希列表（SHA-256 十六进制，可截断）。
  final List<String> messageKeyHashes;

  /// 一条短示例（脱敏/截断，≤ 60 字素簇）。用于 UI 可读性，
  /// 是唯一允许出现的原文片段，长度受限。
  final String? sampleExcerpt;

  /// 命中总次数。
  final int occurrences;

  @override
  bool operator ==(Object other) =>
      other is Evidence &&
      listEquals(other.messageKeyHashes, messageKeyHashes) &&
      other.sampleExcerpt == sampleExcerpt &&
      other.occurrences == occurrences;

  @override
  int get hashCode => Object.hash(
        Object.hashAll(messageKeyHashes),
        sampleExcerpt,
        occurrences,
      );
}

/// 性格标签：由统计特征映射出的有限标签。
@immutable
class PersonaTag {
  /// 创建标签。
  const PersonaTag({
    required this.label,
    required this.evidence,
    this.confidence = Confidence.low,
  });

  /// 标签文本（如“话痨”/“爱用表情”/“报喜不报忧”）。
  final String label;

  /// 触发该标签的依据。
  final Evidence evidence;

  /// 该标签的置信度。
  final Confidence confidence;

  /// 返回一个仅替换置信度的副本。
  PersonaTag withConfidence(Confidence value) =>
      PersonaTag(label: label, evidence: evidence, confidence: value);

  @override
  bool operator ==(Object other) =>
      other is PersonaTag &&
      other.label == label &&
      other.evidence == evidence &&
      other.confidence == confidence;

  @override
  int get hashCode => Object.hash(label, evidence, confidence);
}
