import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../models/message.dart';
import '../../models/parse_result.dart';
import 'data_parser.dart';
import 'parse_exceptions.dart';

/// Instagram 私信解析器，读取 Meta「下载你的信息」导出的 `message_1.json`。
///
/// 导出结构（稳定的官方 schema）：
/// ```json
/// {
///   "participants": [{"name": "..."}],
///   "messages": [
///     {"sender_name": "...", "timestamp_ms": 0, "content": "...",
///      "photos": [{"uri": "media/x.jpg"}]}
///   ]
/// }
/// ```
///
/// 一条消息可同时含文本与若干媒体（`photos`/`videos`/`gifs`/`audio_files`）：
/// 文本产出一条文本消息，每个媒体产出一条对应类型消息 + 一条媒体索引；
/// `uri` 指向文件缺失时产出 `missing_media`。
/// JSON 为整文档结构，须整体读入（非行式流式）。
class InstagramParser implements DataParser {
  /// 创建 Instagram 解析器。
  const InstagramParser();

  @override
  DataSource get source => DataSource.instagram;

  @override
  Future<bool> canParse(String filePath) async {
    if (p.extension(filePath).toLowerCase() != '.json') {
      return false;
    }
    try {
      final Object? decoded = jsonDecode(await File(filePath).readAsString());
      return decoded is Map<String, dynamic> &&
          decoded['messages'] is List &&
          decoded['participants'] is List;
    } on FormatException {
      return false;
    } on FileSystemException {
      return false;
    }
  }

  @override
  Stream<ParseEvent> parse(
    String filePath, {
    ParseOptions options = const ParseOptions(),
  }) async* {
    final String dir = p.dirname(filePath);
    Object? decoded;
    try {
      decoded = jsonDecode(await File(filePath).readAsString());
    } on FormatException catch (e) {
      throw ParseException(
        DataSource.instagram,
        'Invalid Instagram export JSON',
        details: e.message,
      );
    }
    if (decoded is! Map<String, dynamic> || decoded['messages'] is! List) {
      throw ParseException(
        DataSource.instagram,
        'Invalid Instagram export structure',
        details: 'missing "messages" array',
      );
    }
    final List<dynamic> messages = decoded['messages'] as List<dynamic>;
    int index = 0;
    for (final dynamic raw in messages) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }
      final DateTime? ts = _timestamp(raw['timestamp_ms']);
      if (ts == null) {
        yield const WarningEvent(
          ParseWarning('malformed_row', 'missing timestamp_ms'),
        );
        continue;
      }
      final String sender = (raw['sender_name'] as String?)?.trim() ?? 'unknown';
      final bool isFromMe = options.myIdentifiers.contains(sender);
      final String? content = (raw['content'] as String?)?.trim();
      if (content != null && content.isNotEmpty) {
        yield MessageEvent(_textMessage(sender, ts, index++, isFromMe, content));
      }
      for (final _MediaKind kind in _mediaKinds) {
        final List<dynamic> items = raw[kind.field] is List
            ? raw[kind.field] as List<dynamic>
            : <dynamic>[];
        for (final dynamic item in items) {
          final String? uri = item is Map<String, dynamic>
              ? item['uri'] as String?
              : null;
          if (uri == null || uri.isEmpty) {
            continue;
          }
          yield* _mediaEvents(sender, ts, index++, isFromMe, uri, dir, kind);
        }
      }
    }
  }

  @override
  Future<ParseResult> parseAll(
    String filePath, {
    ParseOptions options = const ParseOptions(),
  }) async {
    final List<Message> messages = <Message>[];
    final List<MediaIndexEntry> mediaIndex = <MediaIndexEntry>[];
    final List<ParseWarning> warnings = <ParseWarning>[];
    await for (final ParseEvent event in parse(filePath, options: options)) {
      switch (event) {
        case MessageEvent():
          messages.add(event.message);
        case MediaIndexEvent():
          mediaIndex.add(event.entry);
        case WarningEvent():
          warnings.add(event.warning);
      }
    }
    return ParseResult(
      messages: messages,
      mediaIndex: mediaIndex,
      warnings: warnings,
    );
  }
}

class _MediaKind {
  const _MediaKind(this.field, this.type, this.label);

  final String field;
  final MessageType type;
  final String label;
}

const List<_MediaKind> _mediaKinds = <_MediaKind>[
  _MediaKind('photos', MessageType.image, '[图片]'),
  _MediaKind('videos', MessageType.video, '[视频]'),
  _MediaKind('gifs', MessageType.video, '[动图]'),
  _MediaKind('audio_files', MessageType.voice, '[语音]'),
];

Stream<ParseEvent> _mediaEvents(
  String sender,
  DateTime timestamp,
  int index,
  bool isFromMe,
  String uri,
  String dir,
  _MediaKind kind,
) async* {
  final bool available = File(p.join(dir, uri)).existsSync();
  yield MessageEvent(
    Message(
      id: 'instagram-$index',
      source: DataSource.instagram,
      senderId: sender,
      senderName: sender,
      isFromMe: isFromMe,
      timestamp: timestamp,
      type: kind.type,
      content: kind.label,
      mediaPath: uri,
    ),
  );
  yield MediaIndexEvent(
    MediaIndexEntry(
      source: DataSource.instagram,
      senderId: sender,
      timestamp: timestamp,
      type: kind.type,
      sourceRef: uri,
      available: available,
    ),
  );
  if (!available) {
    yield WarningEvent(
      ParseWarning('missing_media', 'referenced media not found: $uri'),
    );
  }
}

Message _textMessage(
  String sender,
  DateTime timestamp,
  int index,
  bool isFromMe,
  String content,
) =>
    Message(
      id: 'instagram-$index',
      source: DataSource.instagram,
      senderId: sender,
      senderName: sender,
      isFromMe: isFromMe,
      timestamp: timestamp,
      type: MessageType.text,
      content: content,
    );

DateTime? _timestamp(Object? raw) {
  if (raw is int) {
    return DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true);
  }
  if (raw is String) {
    final int? ms = int.tryParse(raw);
    if (ms != null) {
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    }
  }
  return null;
}
