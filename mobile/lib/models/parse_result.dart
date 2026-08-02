import 'message.dart';

/// 媒体字节层的导入档位（文本与索引层始终保存）。
enum MediaTier {
  /// 仅文本 + 媒体索引（路径），不拷贝任何媒体字节。
  textOnly,

  /// 仅拷贝照片与语音字节。
  photoAndVoice,

  /// 拷贝全部媒体字节（默认）。
  all,
}

/// 媒体索引条目：每个图片/视频/语音一条，**只存引用不存字节**。
class MediaIndexEntry {
  /// 创建一条媒体索引。
  const MediaIndexEntry({
    required this.source,
    required this.senderId,
    required this.timestamp,
    required this.type,
    required this.sourceRef,
    this.storedPath,
    this.available = true,
  });

  /// 来源数据源。
  final DataSource source;

  /// 发送者标识。
  final String senderId;

  /// 媒体时间。
  final DateTime timestamp;

  /// 媒体类型（image/voice/video/…）。
  final MessageType type;

  /// 源媒体引用（导出包内相对路径/标识，或书签可解析路径）。
  final String sourceRef;

  /// 已落库字节路径（沙盒内）；未入库（如 [MediaTier.textOnly]）时为 null。
  final String? storedPath;

  /// 源字节是否存在（缺失/被移动时为 false → `missing_media` 告警）。
  final bool available;

  /// JSON 序列化。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'source': source.name,
        'senderId': senderId,
        'timestamp': timestamp.toIso8601String(),
        'type': type.name,
        'sourceRef': sourceRef,
        'storedPath': storedPath,
        'available': available,
      };
}

/// 流式解析事件。解析以事件流产出，峰值内存与文件大小解耦。
sealed class ParseEvent {
  /// 基类构造。
  const ParseEvent();
}

/// 一条已解析消息。
class MessageEvent extends ParseEvent {
  /// 创建消息事件。
  const MessageEvent(this.message);

  /// 消息本体。
  final Message message;
}

/// 一条媒体索引（每个媒体消息随之产出一条）。
///
/// 解析器产出时 `storedPath` 恒为 null（解析器不落字节）；`available`
/// 反映解析器在导出包中能否定位到具体文件引用。字节落地与 `storedPath`
/// 的填充由下游 `MediaStore` 按 [ParseOptions.mediaTier] 完成。
class MediaIndexEvent extends ParseEvent {
  /// 创建媒体索引事件。
  const MediaIndexEvent(this.entry);

  /// 索引条目本体。
  final MediaIndexEntry entry;
}

/// 一条非致命告警。
class WarningEvent extends ParseEvent {
  /// 创建告警事件。
  const WarningEvent(this.warning);

  /// 告警本体。
  final ParseWarning warning;
}

/// 一条解析告警（非致命）。
class ParseWarning {
  /// 创建一条告警。
  const ParseWarning(this.code, this.message, {this.line});

  /// 告警码（如 `missing_exif`、`malformed_row`）。
  final String code;

  /// 人类可读的描述。
  final String message;

  /// 触发告警的行号/位置（可空）。
  final int? line;

  /// JSON 序列化。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'code': code,
        'message': message,
        'line': line,
      };
}

/// 排空事件流后的聚合结果（供小文件/测试便捷使用）。
///
/// 注意：仅在数据量可控时使用；大文件应直接消费 [ParseEvent] 流。
class ParseResult {
  /// 创建解析结果。
  const ParseResult({
    required this.messages,
    this.mediaIndex = const <MediaIndexEntry>[],
    this.warnings = const <ParseWarning>[],
  });

  /// 解析出的消息（未经全局预处理）。
  final List<Message> messages;

  /// 媒体索引层（只存引用，不含字节），由排空 [MediaIndexEvent] 聚合而来。
  ///
  /// 解析器产出时每条 `storedPath` 恒为 null；字节落地与 `storedPath` 填充由
  /// 下游 `MediaStore` 按 [ParseOptions.mediaTier] 完成，不在 [ParseResult] 内。
  final List<MediaIndexEntry> mediaIndex;

  /// 解析过程中的告警。
  final List<ParseWarning> warnings;
}

/// 解析选项。
class ParseOptions {
  /// 创建解析选项。
  const ParseOptions({
    this.targetContact,
    this.extractLocation = false,
    this.myIdentifiers = const <String>[],
    this.mediaTier = MediaTier.all,
  });

  /// 目标联系人（macOS chat.db 等场景）。
  final String? targetContact;

  /// 是否提取地理位置（需授权）。
  final bool extractLocation;

  /// 用于判定 isFromMe 的“我”的标识集合。
  final List<String> myIdentifiers;

  /// 媒体字节层导入档位，默认 [MediaTier.all]（owner 决策）。
  final MediaTier mediaTier;
}
