import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;

import '../../models/message.dart';
import '../../models/parse_result.dart';
import 'data_parser.dart';
import 'parse_exceptions.dart';

/// 微信聊天记录解析器（CSV / TXT / HTML，全程流式）。
///
/// - CSV：列名按别名集容错（见 SPEC §3.4.3）。
/// - TXT：支持多行正文续行（见 SPEC §3.4.1）。
/// - HTML：自研分块 tokenizer 按行切块，媒体 `src` 缺失时产出 `missing_media`。
///
/// 媒体占位符按类型保留（见 SPEC §3.4.2）；解析器只产出媒体索引，
/// 从不落字节（`storedPath` 恒为 null）。
class WeChatParser implements DataParser {
  /// 创建微信解析器。
  const WeChatParser();

  static const Set<String> _supportedExtensions = <String>{
    '.csv',
    '.txt',
    '.html',
    '.htm',
  };

  @override
  DataSource get source => DataSource.wechat;

  @override
  Future<bool> canParse(String filePath) async =>
      _supportedExtensions.contains(p.extension(filePath).toLowerCase());

  @override
  Stream<ParseEvent> parse(
    String filePath, {
    ParseOptions options = const ParseOptions(),
  }) {
    switch (p.extension(filePath).toLowerCase()) {
      case '.csv':
        return _csvEvents(filePath, options);
      case '.txt':
        return _txtEvents(filePath, options);
      case '.html':
      case '.htm':
        return _htmlEvents(filePath, options);
      default:
        throw ParseException(
          DataSource.wechat,
          'Unsupported WeChat export extension',
          details: p.extension(filePath),
        );
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

const Set<MessageType> _mediaTypes = <MessageType>{
  MessageType.image,
  MessageType.voice,
  MessageType.video,
  MessageType.location,
};

const String _replacementChar = '�';

Stream<String> _lines(String filePath) => File(filePath)
    .openRead()
    .transform(const Utf8Decoder(allowMalformed: true))
    .transform(const LineSplitter());

Stream<_CsvRecord> _csvRecords(Stream<String> lines) async* {
  final StringBuffer buffer = StringBuffer();
  int quotes = 0;
  int lineNo = 0;
  int startLine = 0;
  await for (final String line in lines) {
    lineNo++;
    if (buffer.isEmpty) {
      startLine = lineNo;
    } else {
      buffer.write('\n');
    }
    buffer.write(line);
    quotes += '"'.allMatches(line).length;
    if (quotes.isEven) {
      yield _CsvRecord(buffer.toString(), startLine);
      buffer.clear();
      quotes = 0;
    }
  }
  if (buffer.isNotEmpty) {
    yield _CsvRecord(buffer.toString(), startLine);
  }
}

Stream<ParseEvent> _csvEvents(String filePath, ParseOptions options) async* {
  const CsvToListConverter converter =
      CsvToListConverter(shouldParseNumbers: false, eol: '\n');
  _Columns? columns;
  int index = 0;
  int emitted = 0;
  await for (final _CsvRecord record in _csvRecords(_lines(filePath))) {
    final int lineNo = record.line;
    if (record.text.trim().isEmpty) {
      continue;
    }
    if (record.text.contains(_replacementChar)) {
      yield WarningEvent(
        ParseWarning('malformed_row', 'invalid encoding', line: lineNo),
      );
      continue;
    }
    final List<dynamic> row = converter.convert(record.text).first;
    if (columns == null) {
      columns = _resolveColumns(row);
      continue;
    }
    final DateTime? ts = _parseTime(_cell(row, columns.time));
    if (ts == null) {
      yield WarningEvent(
        ParseWarning('malformed_row', 'unparseable time', line: lineNo),
      );
      continue;
    }
    yield* _buildEvents(
      sender: _cell(row, columns.sender),
      timestamp: ts,
      rawContent: _cell(row, columns.content),
      index: index++,
      options: options,
    );
    emitted++;
  }
  if (emitted == 0) {
    yield const WarningEvent(
      ParseWarning('empty_file', 'no recognized messages'),
    );
  }
}

Stream<ParseEvent> _txtEvents(String filePath, ParseOptions options) async* {
  final RegExp header = RegExp(
    r'^(.+?)[ \t]+(\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}(?::\d{2})?)\s*$',
  );
  String? sender;
  DateTime? timestamp;
  List<String> body = <String>[];
  int index = 0;
  int lineNo = 0;
  bool sawLine = false;
  await for (final String line in _lines(filePath)) {
    lineNo++;
    sawLine = true;
    if (line.contains(_replacementChar)) {
      yield WarningEvent(
        ParseWarning('malformed_row', 'invalid encoding', line: lineNo),
      );
      continue;
    }
    final RegExpMatch? match = header.firstMatch(line);
    if (match != null) {
      if (sender != null) {
        yield* _flushTxt(sender, timestamp, body, index++, options);
      }
      sender = match.group(1)!.trim();
      timestamp = _parseTime(match.group(2)!);
      body = <String>[];
    } else if (sender != null) {
      body.add(line);
    } else if (line.trim().isNotEmpty) {
      yield WarningEvent(
        ParseWarning('orphan_line', 'text before first header', line: lineNo),
      );
    }
  }
  if (sender != null) {
    yield* _flushTxt(sender, timestamp, body, index, options);
  }
  if (!sawLine) {
    yield const WarningEvent(ParseWarning('empty_file', 'file has no content'));
  }
}

Stream<ParseEvent> _flushTxt(
  String sender,
  DateTime? timestamp,
  List<String> body,
  int index,
  ParseOptions options,
) async* {
  if (timestamp == null) {
    yield const WarningEvent(
      ParseWarning('malformed_row', 'unparseable header time'),
    );
    return;
  }
  yield* _buildEvents(
    sender: sender,
    timestamp: timestamp,
    rawContent: body.join('\n'),
    index: index,
    options: options,
  );
}

Stream<ParseEvent> _htmlEvents(String filePath, ParseOptions options) async* {
  final String dir = p.dirname(filePath);
  int index = 0;
  int lineNo = 0;
  int emitted = 0;
  bool sawLine = false;
  await for (final String line in _lines(filePath)) {
    lineNo++;
    sawLine = true;
    if (line.contains(_replacementChar)) {
      yield WarningEvent(
        ParseWarning('malformed_row', 'invalid encoding', line: lineNo),
      );
      continue;
    }
    if (!line.contains('class="msg"')) {
      continue;
    }
    final DateTime? ts = _parseTime(_attr(line, 'data-time') ?? '');
    if (ts == null) {
      yield WarningEvent(
        ParseWarning('malformed_row', 'unparseable time', line: lineNo),
      );
      continue;
    }
    final String? typeStr = _attr(line, 'data-type');
    final String raw =
        _attr(line, 'data-content') ?? _placeholderFor(typeStr);
    yield* _buildEvents(
      sender: _attr(line, 'data-sender') ?? 'unknown',
      timestamp: ts,
      rawContent: raw,
      index: index++,
      options: options,
      fileRef: _attr(line, 'data-src'),
      mediaDir: dir,
    );
    emitted++;
  }
  if (emitted == 0) {
    yield WarningEvent(
      ParseWarning(
        'empty_file',
        sawLine ? 'no recognized messages' : 'file has no content',
      ),
    );
  }
}

Stream<ParseEvent> _buildEvents({
  required String sender,
  required DateTime timestamp,
  required String rawContent,
  required int index,
  required ParseOptions options,
  String? fileRef,
  String? mediaDir,
}) async* {
  final _Classified classified = _classify(rawContent);
  final bool isFromMe = options.myIdentifiers.contains(sender);
  if (!_mediaTypes.contains(classified.type)) {
    yield MessageEvent(_message(
      sender: sender,
      timestamp: timestamp,
      index: index,
      isFromMe: isFromMe,
      classified: classified,
    ));
    return;
  }
  final String sourceRef = fileRef ?? 'wechat-media-$index';
  final bool available = fileRef == null ||
      mediaDir == null ||
      File(p.join(mediaDir, fileRef)).existsSync();
  yield MessageEvent(_message(
    sender: sender,
    timestamp: timestamp,
    index: index,
    isFromMe: isFromMe,
    classified: classified,
    mediaPath: sourceRef,
  ));
  yield MediaIndexEvent(MediaIndexEntry(
    source: DataSource.wechat,
    senderId: sender,
    timestamp: timestamp,
    type: classified.type,
    sourceRef: sourceRef,
    available: available,
  ));
  if (!available) {
    yield WarningEvent(
      ParseWarning('missing_media', 'referenced media not found: $fileRef'),
    );
  }
}

Message _message({
  required String sender,
  required DateTime timestamp,
  required int index,
  required bool isFromMe,
  required _Classified classified,
  String? mediaPath,
}) =>
    Message(
      id: 'wechat-$index',
      source: DataSource.wechat,
      senderId: sender,
      senderName: sender,
      isFromMe: isFromMe,
      timestamp: timestamp,
      type: classified.type,
      content: classified.content,
      mediaPath: mediaPath,
      metadata: classified.metadata,
    );

_Classified _classify(String raw) {
  final String c = raw.trim();
  switch (c) {
    case '[图片]':
    case '[表情]':
      return _Classified(MessageType.image, c);
    case '[语音]':
      return _Classified(MessageType.voice, c);
    case '[视频]':
      return _Classified(MessageType.video, c);
    case '[位置]':
      return _Classified(MessageType.location, c);
    case '[撤回了一条消息]':
      return _Classified(MessageType.system, c);
    case '[文件]':
    case '[名片]':
    case '[链接]':
    case '[红包]':
    case '[转账]':
      return _Classified(
        MessageType.text,
        c,
        <String, dynamic>{'placeholder': c},
      );
    default:
      return _Classified(MessageType.text, c);
  }
}

String _placeholderFor(String? type) {
  switch (type) {
    case 'image':
      return '[图片]';
    case 'voice':
      return '[语音]';
    case 'video':
      return '[视频]';
    case 'location':
      return '[位置]';
    default:
      return '';
  }
}

_Columns _resolveColumns(List<dynamic> header) {
  final List<String> names = <String>[
    for (final dynamic cell in header) cell.toString().trim().toLowerCase(),
  ];
  final int sender = _firstIndex(names, const <String>[
    'sender',
    '发送人',
    'from',
    'nickname',
    'talker',
  ]);
  final int content = _firstIndex(names, const <String>[
    'content',
    '内容',
    'message',
    'strcontent',
  ]);
  final int time = _firstIndex(names, const <String>[
    'timestamp',
    '时间',
    'time',
    'strtime',
    'createtime',
  ]);
  if (sender < 0 || content < 0 || time < 0) {
    throw ParseException(
      DataSource.wechat,
      'Missing required WeChat CSV column',
      details: 'sender=$sender content=$content time=$time',
    );
  }
  return _Columns(sender: sender, content: content, time: time);
}

int _firstIndex(List<String> names, List<String> aliases) {
  for (final String alias in aliases) {
    final int i = names.indexOf(alias);
    if (i >= 0) {
      return i;
    }
  }
  return -1;
}

String _cell(List<dynamic> row, int index) =>
    index < row.length ? row[index].toString() : '';

DateTime? _parseTime(String raw) {
  final String s = raw.trim();
  if (s.isEmpty) {
    return null;
  }
  final int? epoch = int.tryParse(s);
  if (epoch != null) {
    if (epoch <= 0) {
      return null;
    }
    final int ms = s.length >= 13 ? epoch : epoch * 1000;
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }
  return DateTime.tryParse(s);
}

String? _attr(String line, String name) =>
    RegExp('$name="([^"]*)"').firstMatch(line)?.group(1);

class _CsvRecord {
  const _CsvRecord(this.text, this.line);

  final String text;
  final int line;
}

class _Columns {
  const _Columns({
    required this.sender,
    required this.content,
    required this.time,
  });

  final int sender;
  final int content;
  final int time;
}

class _Classified {
  const _Classified(
    this.type,
    this.content, [
    this.metadata = const <String, dynamic>{},
  ]);

  final MessageType type;
  final String content;
  final Map<String, dynamic> metadata;
}
