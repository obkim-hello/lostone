import 'dart:convert';

import 'package:flutter/foundation.dart';

/// LLM 蒸馏输出解析后的**分层中间态**（模块内部，不落盘、不对外）。
///
/// 字段与 ex-skill 五层对应（ERD-004 §3.3），随后由 `PersonaMapper` 映射为
/// 对外 `Persona`。仅内存态，避免引入第二种持久化契约。
///
/// 各集合为「模型声称」的候选，**未经原文校验**；接地/去伪在 `PersonaMapper`。
@immutable
class DistilledPersona {
  /// 创建中间态。
  const DistilledPersona({
    this.displayName,
    this.relationToUser,
    this.aliases = const <String>[],
    this.forbiddenTopics = const <String>[],
    this.mustNeverClaim = const <String>[],
    this.safetyNotes = const <String>[],
    this.catchphrases = const <String>[],
    this.emojis = const <String>[],
    this.punctuation = const <String>[],
    this.positiveRatio,
    this.negativeRatio,
    this.comfortPatterns = const <String>[],
    this.concernPatterns = const <String>[],
    this.termsForUser = const <String>[],
    this.initiationRatio,
    this.avgResponseGapMinutes,
    this.exemplars = const <String>[],
    this.preferences = const <String>[],
    this.tags = const <String>[],
    this.insufficientLayers = const <String>[],
  });

  /// 身份 · 显示名（缺失时由 mapper 回退默认）。
  final String? displayName;

  /// 身份 · 与用户的关系（语义推断，允许非逐字）。
  final String? relationToUser;

  /// 身份 · 别名/称呼。
  final List<String> aliases;

  /// 边界 · 回避话题。
  final List<String> forbiddenTopics;

  /// 边界 · 绝不声称。
  final List<String> mustNeverClaim;

  /// 边界 · 其他安全说明。
  final List<String> safetyNotes;

  /// 表达 · 口头禅/高频短语（需原文接地）。
  final List<String> catchphrases;

  /// 表达 · 常用 emoji/表情（需原文接地）。
  final List<String> emojis;

  /// 表达 · 标点习惯（需原文接地）。
  final List<String> punctuation;

  /// 情感 · 正向占比 [0,1]（可空）。
  final double? positiveRatio;

  /// 情感 · 负向占比 [0,1]（可空）。
  final double? negativeRatio;

  /// 情感 · 安慰类话语（需原文接地）。
  final List<String> comfortPatterns;

  /// 情感 · 关心/叮嘱类话语（需原文接地）。
  final List<String> concernPatterns;

  /// 关系 · 对用户的称呼（需原文接地）。
  final List<String> termsForUser;

  /// 关系 · 主动发起比例 [0,1]（可空）。
  final double? initiationRatio;

  /// 关系 · 平均回复间隔（分钟，可空）。
  final double? avgResponseGapMinutes;

  /// 「你会怎么说」真实例句（需原文接地）。
  final List<String> exemplars;

  /// 偏好/常提及（需原文接地）。
  final List<String> preferences;

  /// 性格标签（抽象概括，不逐字接地）。
  final List<String> tags;

  /// 「原材料不足」层标注（键：`expression`/`emotion`/`relation`/`identity` 等）。
  final List<String> insufficientLayers;
}

/// 蒸馏输出无法解析为结构化中间态时抛出（供 Builder 重试/兜底，SPEC §5.8）。
@immutable
class DistillationFormatException implements Exception {
  /// 创建异常。
  const DistillationFormatException(this.message);

  /// 说明信息（不含原文/prompt 全文）。
  final String message;

  @override
  String toString() => 'DistillationFormatException: $message';
}

/// 把模型的原始文本响应解析为 [DistilledPersona]。
///
/// 约定输出为 JSON 对象；容忍前后散文与 ```json 代码围栏（取首个 `{` 到末个
/// `}`）。整体 JSON 不可解析时抛 [DistillationFormatException]；单个字段类型
/// 不符时**从宽**按缺省处理（不因个别噪声整体失败）。
class DistillationParser {
  /// 创建解析器。
  const DistillationParser();

  /// 解析原始响应；失败抛 [DistillationFormatException]。
  DistilledPersona parse(String raw) {
    final Map<String, dynamic> root = _extractJson(raw);

    final Map<String, dynamic> identity = _obj(root['identity']);
    final Map<String, dynamic> coreRules = _obj(root['coreRules']);
    final Map<String, dynamic> expression = _obj(root['expression']);
    final Map<String, dynamic> emotion = _obj(root['emotion']);
    final Map<String, dynamic> relation = _obj(root['relation']);

    return DistilledPersona(
      displayName: _str(identity['displayName']),
      relationToUser: _str(identity['relationToUser']),
      aliases: _strList(identity['aliases']),
      forbiddenTopics: _strList(coreRules['forbiddenTopics']),
      mustNeverClaim: _strList(coreRules['mustNeverClaim']),
      safetyNotes: _strList(coreRules['safetyNotes']),
      catchphrases: _strList(expression['catchphrases']),
      emojis: _strList(expression['emojis']),
      punctuation: _strList(expression['punctuation']),
      positiveRatio: _num(emotion['positiveRatio']),
      negativeRatio: _num(emotion['negativeRatio']),
      comfortPatterns: _strList(emotion['comfortPatterns']),
      concernPatterns: _strList(emotion['concernPatterns']),
      termsForUser: _strList(relation['termsForUser']),
      initiationRatio: _num(relation['initiationRatio']),
      avgResponseGapMinutes: _num(relation['avgResponseGapMinutes']),
      exemplars: _strList(root['exemplars']),
      preferences: _strList(root['preferences']),
      tags: _strList(root['tags']),
      insufficientLayers: _strList(root['insufficientLayers']),
    );
  }

  Map<String, dynamic> _extractJson(String raw) {
    final int start = raw.indexOf('{');
    final int end = raw.lastIndexOf('}');
    if (start < 0 || end <= start) {
      throw const DistillationFormatException('响应不含 JSON 对象');
    }
    final Object? decoded;
    try {
      decoded = json.decode(raw.substring(start, end + 1));
    } on FormatException catch (e) {
      throw DistillationFormatException('JSON 解析失败：${e.message}');
    }
    if (decoded is Map) {
      return decoded.cast<String, dynamic>();
    }
    throw const DistillationFormatException('顶层不是 JSON 对象');
  }

  Map<String, dynamic> _obj(Object? v) =>
      v is Map ? v.cast<String, dynamic>() : const <String, dynamic>{};

  String? _str(Object? v) {
    if (v is String && v.trim().isNotEmpty) {
      return v.trim();
    }
    return null;
  }

  List<String> _strList(Object? v) {
    if (v is! List) {
      return const <String>[];
    }
    return <String>[
      for (final Object? e in v)
        if (e is String && e.trim().isNotEmpty) e.trim(),
    ];
  }

  double? _num(Object? v) => v is num ? v.toDouble() : null;
}
