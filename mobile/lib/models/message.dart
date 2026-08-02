/// 支持的数据源类型。
enum DataSource {
  /// 微信。
  wechat,

  /// iMessage。
  imessage,

  /// 微博。
  weibo,

  /// Instagram。
  instagram,

  /// 照片元数据。
  photo,

  /// 未知/待自动识别。
  unknown,
}

/// 消息内容类型。
enum MessageType {
  /// 纯文本。
  text,

  /// 图片。
  image,

  /// 语音。
  voice,

  /// 视频。
  video,

  /// 地理位置。
  location,

  /// 系统消息（预处理阶段通常被过滤）。
  system,
}

/// 标准化的单条消息。
///
/// 所有解析器最终都产出 [Message]，屏蔽各数据源的格式差异。
class Message {
  /// 创建一条消息。
  const Message({
    required this.id,
    required this.source,
    required this.senderId,
    required this.senderName,
    required this.isFromMe,
    required this.timestamp,
    required this.type,
    required this.content,
    this.mediaPath,
    this.metadata = const <String, dynamic>{},
  });

  /// JSON 反序列化。
  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as String,
        source: DataSource.values.byName(json['source'] as String),
        senderId: json['senderId'] as String,
        senderName: json['senderName'] as String,
        isFromMe: json['isFromMe'] as bool,
        timestamp: DateTime.parse(json['timestamp'] as String),
        type: MessageType.values.byName(json['type'] as String),
        content: json['content'] as String,
        mediaPath: json['mediaPath'] as String?,
        metadata: (json['metadata'] as Map<String, dynamic>?) ??
            const <String, dynamic>{},
      );

  /// 稳定的消息标识（引用/展示用途，**非去重键**）。
  ///
  /// 去重以内容复合键为准（见 ERD §6.1 算法1）；解析器可用
  /// `<source>-<序号>` 等生成，仅需在单次导入内可引用即可。
  final String id;

  /// 来源数据源。
  final DataSource source;

  /// 发送者标识（平台内唯一）。
  final String senderId;

  /// 发送者展示名。
  final String senderName;

  /// 是否为“我”发出。
  final bool isFromMe;

  /// 消息时间。
  final DateTime timestamp;

  /// 消息类型。
  final MessageType type;

  /// 文本内容（非文本类型可为占位/摘要）。
  final String content;

  /// 媒体文件引用路径（图片/语音/视频，可空）。
  final String? mediaPath;

  /// 额外元数据（如语音时长、经纬度）。
  final Map<String, dynamic> metadata;

  /// JSON 序列化。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'source': source.name,
        'senderId': senderId,
        'senderName': senderName,
        'isFromMe': isFromMe,
        'timestamp': timestamp.toIso8601String(),
        'type': type.name,
        'content': content,
        'mediaPath': mediaPath,
        'metadata': metadata,
      };
}
