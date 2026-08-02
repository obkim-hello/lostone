import 'message.dart';
import 'parse_result.dart';

/// 导入结果统计。
class ImportStats {
  /// 创建统计信息。
  const ImportStats({
    required this.totalParsed,
    required this.afterDedup,
    required this.skipped,
    required this.earliest,
    required this.latest,
  });

  /// 解析出的原始条数。
  final int totalParsed;

  /// 清洗与去重后的最终条数（等于 `Conversation.messages.length`）。
  ///
  /// 注意：`skipped` 同时包含系统消息过滤与去重两部分，故本字段是
  /// “清洗+去重后”的结果，不仅是去重。
  final int afterDedup;

  /// 被跳过/过滤的条数。
  final int skipped;

  /// 最早消息时间（可空）。
  final DateTime? earliest;

  /// 最晚消息时间（可空）。
  final DateTime? latest;

  /// JSON 序列化。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'totalParsed': totalParsed,
        'afterDedup': afterDedup,
        'skipped': skipped,
        'earliest': earliest?.toIso8601String(),
        'latest': latest?.toIso8601String(),
      };
}

/// 一次导入产出的标准化会话。
class Conversation {
  /// 创建一个会话。
  const Conversation({
    required this.source,
    required this.participants,
    required this.messages,
    required this.stats,
    this.mediaIndex = const <MediaIndexEntry>[],
    this.warnings = const <ParseWarning>[],
  });

  /// 主要数据源。
  final DataSource source;

  /// 参与者展示名列表（由预处理后消息的 `senderName` 去重收集，
  /// 按首次出现顺序排列）。
  final List<String> participants;

  /// 已清洗、去重、排序后的消息。
  final List<Message> messages;

  /// 导入统计。
  final ImportStats stats;

  /// 跨文件累积的媒体索引层（只存引用，不含字节）。
  final List<MediaIndexEntry> mediaIndex;

  /// 跨文件累积的非致命告警（如 `missing_media`、`malformed_row`、
  /// `empty_file`、`file_too_large` 等），供 UI 呈现。
  final List<ParseWarning> warnings;

  /// JSON 序列化。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'source': source.name,
        'participants': participants,
        'messages': messages.map((Message m) => m.toJson()).toList(),
        'stats': stats.toJson(),
        'mediaIndex':
            mediaIndex.map((MediaIndexEntry e) => e.toJson()).toList(),
        'warnings': warnings.map((ParseWarning w) => w.toJson()).toList(),
      };
}
