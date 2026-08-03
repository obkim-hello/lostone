import 'package:flutter/foundation.dart';

import 'evidence.dart';

/// 会话时间跨度与活跃度分布。
@immutable
class TimelineSpan {
  /// 创建时间线区间。
  const TimelineSpan({
    required this.start,
    required this.end,
    required this.messageCount,
    this.activeHours = const <int, int>{},
  });

  /// 起始时间（UTC）。空会话（[messageCount] == 0）时为 null。
  final DateTime? start;

  /// 结束时间（UTC）。空会话（[messageCount] == 0）时为 null。
  final DateTime? end;

  /// 目标人物消息总数。
  final int messageCount;

  /// 活跃时段直方图：小时(0-23) → 消息数。
  ///
  /// 小时按 `Message.timestamp` 归一到 UTC 后取 `hour` 分桶（保证确定性）。
  final Map<int, int> activeHours;

  @override
  bool operator ==(Object other) =>
      other is TimelineSpan &&
      other.start == start &&
      other.end == end &&
      other.messageCount == messageCount &&
      mapEquals(other.activeHours, activeHours);

  @override
  int get hashCode => Object.hash(
        start,
        end,
        messageCount,
        Object.hashAllUnordered(
          activeHours.entries.map((MapEntry<int, int> e) => Object.hash(e.key, e.value)),
        ),
      );
}

/// 一个被标记的关键事件。
@immutable
class KeyEvent {
  /// 创建关键事件。
  const KeyEvent({
    required this.at,
    required this.summary,
    required this.evidence,
  });

  /// 事件时间（UTC）。
  final DateTime at;

  /// 事件摘要（模板拼装，非 LLM）。
  final String summary;

  /// 支撑该事件的证据。
  final Evidence evidence;

  @override
  bool operator ==(Object other) =>
      other is KeyEvent &&
      other.at == at &&
      other.summary == summary &&
      other.evidence == evidence;

  @override
  int get hashCode => Object.hash(at, summary, evidence);
}

/// 一项偏好/习惯。
@immutable
class Preference {
  /// 创建偏好项。
  const Preference({
    required this.term,
    required this.count,
    required this.evidence,
  });

  /// 偏好词/短语。
  final String term;

  /// 出现次数。
  final int count;

  /// 支撑证据。
  final Evidence evidence;

  @override
  bool operator ==(Object other) =>
      other is Preference &&
      other.term == term &&
      other.count == count &&
      other.evidence == evidence;

  @override
  int get hashCode => Object.hash(term, count, evidence);
}

/// 提取出的记忆集合。
@immutable
class Memories {
  /// 创建记忆集合。
  const Memories({
    required this.timeline,
    this.keyEvents = const <KeyEvent>[],
    this.preferences = const <Preference>[],
  });

  /// 时间线区间与活跃度。
  final TimelineSpan timeline;

  /// 关键事件（带证据）。
  final List<KeyEvent> keyEvents;

  /// 偏好/习惯（带计数与证据）。
  final List<Preference> preferences;

  @override
  bool operator ==(Object other) =>
      other is Memories &&
      other.timeline == timeline &&
      listEquals(other.keyEvents, keyEvents) &&
      listEquals(other.preferences, preferences);

  @override
  int get hashCode => Object.hash(
        timeline,
        Object.hashAll(keyEvents),
        Object.hashAll(preferences),
      );
}
