import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

import '../../models/message.dart';
import '../../models/parse_result.dart';
import 'apple_time.dart';
import 'data_parser.dart';
import 'parse_exceptions.dart';

/// iMessage 解析器，只读 `chat.db`（SQLite），不创建自有数据库。
///
/// 读取的只读表（见 ERD §4.2）：`message`（`text`/`date`/`is_from_me`/
/// `handle_id`）、`handle`（`id`）。`date` 为 Apple 绝对时间，经
/// [appleDateToDateTime] 归一（秒/纳秒自适应）。
///
/// 以游标逐行消费，峰值内存与库大小解耦。`text` 为空时回退解码
/// `attributedBody`（iOS 14+/macOS 11+ 将正文存入该 `streamtyped`
/// NSAttributedString BLOB，见 ERD §4.2）；解码失败或确无正文的附件行
/// 产出 `empty_message` 告警而非消息。`ParseOptions.targetContact` 指定
/// 时，仅保留该 handle 与「我」发出的消息。
///
/// 注意：在设备上运行需 `sqlite3_flutter_libs` 打包原生库（分阶段推进）；
/// 桌面/测试宿主复用系统 libsqlite3。
class IMessageParser implements DataParser {
  /// 创建 iMessage 解析器。
  const IMessageParser();

  @override
  DataSource get source => DataSource.imessage;

  @override
  Future<bool> canParse(String filePath) async {
    if (!filePath.toLowerCase().endsWith('.db')) {
      return false;
    }
    if (!File(filePath).existsSync()) {
      return false;
    }
    Database? db;
    try {
      db = sqlite3.open(filePath, mode: OpenMode.readOnly);
      final ResultSet tables = db.select(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='message'",
      );
      return tables.isNotEmpty;
    } on SqliteException {
      return false;
    } finally {
      db?.dispose();
    }
  }

  @override
  Stream<ParseEvent> parse(
    String filePath, {
    ParseOptions options = const ParseOptions(),
  }) async* {
    late final Database db;
    try {
      db = sqlite3.open(filePath, mode: OpenMode.readOnly);
    } on SqliteException catch (e) {
      throw ParseException(
        DataSource.imessage,
        'Cannot open chat.db',
        details: e.message,
      );
    }
    try {
      final PreparedStatement stmt = db.prepare(
        'SELECT m.ROWID AS rowid, m.text AS text, '
        'm.attributedBody AS attributed_body, m.date AS date, '
        'm.is_from_me AS is_from_me, h.id AS handle '
        'FROM message m LEFT JOIN handle h ON m.handle_id = h.ROWID '
        'ORDER BY m.date ASC, m.ROWID ASC',
      );
      try {
        final IteratingCursor cursor = stmt.selectCursor();
        while (cursor.moveNext()) {
          yield* _rowEvents(cursor.current, options);
        }
      } finally {
        stmt.dispose();
      }
    } finally {
      db.dispose();
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

Stream<ParseEvent> _rowEvents(Row row, ParseOptions options) async* {
  final Object? dateRaw = row['date'];
  if (dateRaw is! int) {
    yield const WarningEvent(ParseWarning('malformed_row', 'missing date'));
    return;
  }
  final bool isFromMe = (row['is_from_me'] as int? ?? 0) == 1;
  final String? handle = row['handle'] as String?;
  if (options.targetContact != null &&
      !isFromMe &&
      handle != options.targetContact) {
    return;
  }
  String text = (row['text'] as String?)?.trim() ?? '';
  if (text.isEmpty) {
    final Object? blob = row['attributed_body'];
    if (blob is Uint8List) {
      text = _decodeAttributedBody(blob)?.trim() ?? '';
    }
  }
  if (text.isEmpty) {
    yield const WarningEvent(
      ParseWarning('empty_message', 'message has no text body'),
    );
    return;
  }
  final String sender = isFromMe ? 'me' : (handle ?? 'unknown');
  yield MessageEvent(
    Message(
      id: 'imessage-${row['rowid']}',
      source: DataSource.imessage,
      senderId: sender,
      senderName: sender,
      isFromMe: isFromMe,
      timestamp: appleDateToDateTime(dateRaw),
      type: MessageType.text,
      content: text,
    ),
  );
}

String? _decodeAttributedBody(Uint8List bytes) {
  final int marker = _indexOfAscii(bytes, 'NSString');
  if (marker < 0) {
    return null;
  }
  int i = marker + 'NSString'.length;
  while (i < bytes.length && bytes[i] != 0x2b) {
    i++;
  }
  if (i >= bytes.length) {
    return null;
  }
  i++;
  if (i >= bytes.length) {
    return null;
  }
  int length = bytes[i];
  i++;
  if (length == 0x81) {
    if (i + 1 >= bytes.length) {
      return null;
    }
    length = bytes[i] | (bytes[i + 1] << 8);
    i += 2;
  } else if (length == 0x82) {
    if (i + 3 >= bytes.length) {
      return null;
    }
    length = bytes[i] |
        (bytes[i + 1] << 8) |
        (bytes[i + 2] << 16) |
        (bytes[i + 3] << 24);
    i += 4;
  }
  if (length <= 0 || i + length > bytes.length) {
    return null;
  }
  return utf8.decode(bytes.sublist(i, i + length), allowMalformed: true);
}

int _indexOfAscii(Uint8List bytes, String needle) {
  final List<int> pattern = needle.codeUnits;
  for (int i = 0; i + pattern.length <= bytes.length; i++) {
    bool match = true;
    for (int j = 0; j < pattern.length; j++) {
      if (bytes[i + j] != pattern[j]) {
        match = false;
        break;
      }
    }
    if (match) {
      return i;
    }
  }
  return -1;
}
