import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../models/message.dart';
import '../../models/parse_result.dart';
import 'data_parser.dart';
import 'parse_exceptions.dart';

/// 微博私信解析器，读取微博开放平台 `direct_messages` API v2 的 JSON 落盘。
///
/// 输入契约（见 ERD §4.3「输入 JSON（微博私信导出）」）：
/// ```json
/// {
///   "direct_messages": [
///     {"created_at": "Wed Jun 12 08:47:29 +0800 2013",
///      "text": "在吗", "sender_screen_name": "妈妈", "sender_id": 66666}
///   ]
/// }
/// ```
///
/// `created_at` 支持微博/Twitter 风格 `EEE MMM dd HH:mm:ss ±ZZZZ yyyy`
/// （含时区偏移，归一为 UTC）与 Unix 秒/毫秒整数。`sender_screen_name`
/// （回退 `sender_id`）命中 `ParseOptions.myIdentifiers` 即 `isFromMe`。
/// 正文为纯文本，媒体以内联 URL 存于 `text`，故不单列媒体索引。
///
/// JSON 非法或缺 `direct_messages` 数组抛 [ParseException]；单条缺时间/
/// 空文本降级为 `malformed_row`/`empty_message` 告警并跳过，不中断整批。
/// JSON 为整文档结构，须整体读入（非行式流式）。
class WeiboParser implements DataParser {
  /// 创建微博解析器。
  const WeiboParser();

  @override
  DataSource get source => DataSource.weibo;

  @override
  Future<bool> canParse(String filePath) async {
    if (p.extension(filePath).toLowerCase() != '.json') {
      return false;
    }
    try {
      final Object? decoded = jsonDecode(await File(filePath).readAsString());
      return decoded is Map<String, dynamic> &&
          decoded['direct_messages'] is List;
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
    Object? decoded;
    try {
      decoded = jsonDecode(await File(filePath).readAsString());
    } on FormatException catch (e) {
      throw ParseException(
        DataSource.weibo,
        'Invalid Weibo export JSON',
        details: e.message,
      );
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['direct_messages'] is! List) {
      throw ParseException(
        DataSource.weibo,
        'Invalid Weibo export structure',
        details: 'missing "direct_messages" array',
      );
    }
    final List<dynamic> items = decoded['direct_messages'] as List<dynamic>;
    int index = 0;
    for (final dynamic raw in items) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }
      final DateTime? ts = _parseWeiboTime(raw['created_at']);
      if (ts == null) {
        yield const WarningEvent(
          ParseWarning('malformed_row', 'missing or unparseable created_at'),
        );
        continue;
      }
      final String sender = _sender(raw);
      final String text = (raw['text'] as String?)?.trim() ?? '';
      if (text.isEmpty) {
        yield const WarningEvent(
          ParseWarning('empty_message', 'weibo message has no text'),
        );
        continue;
      }
      yield MessageEvent(
        Message(
          id: 'weibo-$index',
          source: DataSource.weibo,
          senderId: sender,
          senderName: sender,
          isFromMe: options.myIdentifiers.contains(sender),
          timestamp: ts,
          type: MessageType.text,
          content: text,
        ),
      );
      index++;
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

String _sender(Map<String, dynamic> raw) {
  final String? name = (raw['sender_screen_name'] as String?)?.trim();
  if (name != null && name.isNotEmpty) {
    return name;
  }
  final Object? id = raw['sender_id'];
  if (id != null) {
    return id.toString();
  }
  return 'unknown';
}

const Map<String, int> _months = <String, int>{
  'Jan': 1,
  'Feb': 2,
  'Mar': 3,
  'Apr': 4,
  'May': 5,
  'Jun': 6,
  'Jul': 7,
  'Aug': 8,
  'Sep': 9,
  'Oct': 10,
  'Nov': 11,
  'Dec': 12,
};

DateTime? _parseWeiboTime(Object? raw) {
  if (raw is int) {
    return _fromUnix(raw);
  }
  if (raw is! String) {
    return null;
  }
  final String s = raw.trim();
  final int? unix = int.tryParse(s);
  if (unix != null) {
    return _fromUnix(unix);
  }
  final List<String> parts = s.split(RegExp(r'\s+'));
  if (parts.length != 6) {
    return null;
  }
  final int? month = _months[parts[1]];
  final int? day = int.tryParse(parts[2]);
  final List<String> hms = parts[3].split(':');
  final int? offset = _tzOffsetMinutes(parts[4]);
  final int? year = int.tryParse(parts[5]);
  if (month == null || day == null || hms.length != 3 ||
      offset == null || year == null) {
    return null;
  }
  final int? hour = int.tryParse(hms[0]);
  final int? minute = int.tryParse(hms[1]);
  final int? second = int.tryParse(hms[2]);
  if (hour == null || minute == null || second == null) {
    return null;
  }
  return DateTime.utc(year, month, day, hour, minute, second)
      .subtract(Duration(minutes: offset));
}

DateTime _fromUnix(int value) => DateTime.fromMillisecondsSinceEpoch(
      value > 1000000000000 ? value : value * 1000,
      isUtc: true,
    );

int? _tzOffsetMinutes(String tz) {
  if (tz.length != 5) {
    return null;
  }
  final String sign = tz[0];
  if (sign != '+' && sign != '-') {
    return null;
  }
  final int? hours = int.tryParse(tz.substring(1, 3));
  final int? minutes = int.tryParse(tz.substring(3, 5));
  if (hours == null || minutes == null) {
    return null;
  }
  final int total = hours * 60 + minutes;
  return sign == '-' ? -total : total;
}
