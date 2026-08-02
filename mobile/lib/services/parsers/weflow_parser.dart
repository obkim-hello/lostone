import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;

import '../../models/message.dart';
import '../../models/parse_result.dart';
import 'data_parser.dart';
import 'parse_exceptions.dart';

/// 微信 WeFlow 导出解析器（JSON / CSV / TXT / HTML）。
///
/// WeChat 无官方导出，用户以第三方工具 WeFlow（`generator: "WeFlow"`）导出，
/// 同一会话可产出四种格式。本解析器以其为输入契约（见 ERD §4.3
/// 「输入（微信 WeFlow 导出）」），`source == DataSource.wechat`，`canParse`
/// 按结构签名探测，注册顺序上先于 [WeChatParser]（通用格式）。
///
/// - 方向以导出自带标志（`isSend`/`is_sender`/HTML `s`/TXT `'我'`）为准。
/// - `图片消息` → [MessageType.image] 并产媒体索引（`mediaPath == sourceRef`
///   为导出内相对路径，`storedPath` 恒为 null，字节落地由 `MediaStore` 负责）；
///   `文件消息`/`引用消息` → [MessageType.text]（[MessageType] 无 `file` 值）。
/// - 时间：JSON/HTML 用 Unix 秒，CSV 用 ISO8601 UTC，TXT 用本地墙钟。
/// - JSON 整文档读入、HTML 逐行解析内嵌数据数组、CSV/TXT 逐行流式。
///
/// 测试仅使用结构等价的合成夹具，不含任何真实会话内容。
class WeFlowParser implements DataParser {
  /// 创建 WeFlow 解析器。
  const WeFlowParser();

  static const Set<String> _supportedExtensions = <String>{
    '.json',
    '.csv',
    '.txt',
    '.html',
    '.htm',
  };

  @override
  DataSource get source => DataSource.wechat;

  @override
  Future<bool> canParse(String filePath) async {
    final String ext = p.extension(filePath).toLowerCase();
    if (!_supportedExtensions.contains(ext)) {
      return false;
    }
    switch (ext) {
      case '.json':
        return _looksLikeWeflowJson(filePath);
      case '.csv':
        return _looksLikeWeflowCsv(filePath);
      case '.txt':
        return _looksLikeWeflowTxt(filePath);
      default:
        return _looksLikeWeflowHtml(filePath);
    }
  }

  @override
  Stream<ParseEvent> parse(
    String filePath, {
    ParseOptions options = const ParseOptions(),
  }) {
    switch (p.extension(filePath).toLowerCase()) {
      case '.json':
        return _jsonEvents(filePath, options);
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
          'Unsupported WeFlow export extension',
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

enum _Kind { text, image, file, quote }

const String _replacementChar = '�';

final RegExp _txtHeader = RegExp(
  r"^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\s+'(.+)'$",
);

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

Future<String> _readHead(String filePath, int maxBytes) async {
  final RandomAccessFile handle = await File(filePath).open();
  try {
    final List<int> bytes = await handle.read(maxBytes);
    return utf8.decode(bytes, allowMalformed: true);
  } finally {
    await handle.close();
  }
}

Future<bool> _looksLikeWeflowJson(String filePath) async {
  final String head = await _readHead(filePath, 4096);
  if (!head.contains('"weflow"')) {
    return false;
  }
  try {
    final dynamic decoded = jsonDecode(await File(filePath).readAsString());
    return decoded is Map &&
        decoded['weflow'] is Map &&
        decoded['messages'] is List;
  } on FormatException {
    return false;
  }
}

Future<bool> _looksLikeWeflowCsv(String filePath) async {
  await for (final String line in _lines(filePath)) {
    final String header = line.replaceAll('﻿', '').trim().toLowerCase();
    if (header.isEmpty) {
      continue;
    }
    return header.contains('is_sender') && header.contains('type_name');
  }
  return false;
}

Future<bool> _looksLikeWeflowTxt(String filePath) async {
  await for (final String line in _lines(filePath)) {
    if (line.trim().isEmpty) {
      continue;
    }
    return _txtHeader.hasMatch(line.trim());
  }
  return false;
}

Future<bool> _looksLikeWeflowHtml(String filePath) async {
  await for (final String line in _lines(filePath)) {
    if (line.contains('window.WEFLOW_DATA')) {
      return true;
    }
  }
  return false;
}

Stream<ParseEvent> _jsonEvents(String filePath, ParseOptions options) async* {
  final String raw = await File(filePath).readAsString();
  dynamic decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException catch (e) {
    throw ParseException(
      DataSource.wechat,
      'Invalid WeFlow JSON',
      details: e.message,
    );
  }
  if (decoded is! Map || decoded['messages'] is! List) {
    throw ParseException(
      DataSource.wechat,
      'WeFlow JSON missing messages array',
    );
  }
  final String dir = p.dirname(filePath);
  final List<dynamic> messages = decoded['messages'] as List<dynamic>;
  int index = 0;
  for (final dynamic item in messages) {
    if (item is! Map) {
      continue;
    }
    final Map<dynamic, dynamic> m = item;
    final DateTime? ts = _fromUnixSeconds(_asInt(m['createTime'])) ??
        _parseTime(m['formattedTime']?.toString() ?? '');
    if (ts == null) {
      yield const WarningEvent(
        ParseWarning('malformed_row', 'unparseable message time'),
      );
      continue;
    }
    final String content = m['content']?.toString() ?? '';
    final _Kind kind = _jsonKind(m['type']?.toString() ?? '', _asInt(m['localType']));
    final String senderId =
        (m['senderUsername']?.toString().trim() ?? '').isEmpty
            ? 'unknown'
            : m['senderUsername']!.toString().trim();
    final String senderName =
        (m['senderDisplayName']?.toString().trim() ?? '').isEmpty
            ? senderId
            : m['senderDisplayName']!.toString().trim();
    yield* _emit(
      index: index++,
      senderId: senderId,
      senderName: senderName,
      isFromMe: _asInt(m['isSend']) == 1,
      timestamp: ts,
      kind: kind,
      text: content,
      mediaRef: kind == _Kind.image ? content : null,
      mediaDir: dir,
    );
  }
}

Stream<ParseEvent> _csvEvents(String filePath, ParseOptions options) async* {
  const CsvToListConverter converter =
      CsvToListConverter(shouldParseNumbers: false, eol: '\n');
  final String dir = p.dirname(filePath);
  _WeflowCols? cols;
  int index = 0;
  bool sawData = false;
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
    if (cols == null) {
      cols = _resolveWeflowCols(row);
      continue;
    }
    final DateTime? ts = _parseTime(_cell(row, cols.time));
    if (ts == null) {
      yield WarningEvent(
        ParseWarning('malformed_row', 'unparseable time', line: lineNo),
      );
      continue;
    }
    sawData = true;
    final String talker = _cell(row, cols.talker);
    final _Kind kind = _csvKind(_cell(row, cols.typeName));
    final String src = cols.src >= 0 ? _cell(row, cols.src).trim() : '';
    yield* _emit(
      index: index++,
      senderId: talker,
      senderName: talker,
      isFromMe: _cell(row, cols.isSend).trim() == '1',
      timestamp: ts,
      kind: kind,
      text: _cell(row, cols.content),
      mediaRef: kind == _Kind.image && src.isNotEmpty ? src : null,
      mediaDir: dir,
    );
  }
  if (!sawData && cols == null) {
    yield const WarningEvent(ParseWarning('empty_file', 'file has no content'));
  }
}

Stream<ParseEvent> _txtEvents(String filePath, ParseOptions options) async* {
  final String dir = p.dirname(filePath);
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
    final RegExpMatch? match = _txtHeader.firstMatch(line.trim());
    if (match != null) {
      if (sender != null) {
        yield* _flushTxt(sender, timestamp, body, index++, dir, options);
      }
      timestamp = _parseTime(match.group(1)!);
      sender = match.group(2)!;
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
    yield* _flushTxt(sender, timestamp, body, index, dir, options);
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
  String dir,
  ParseOptions options,
) async* {
  if (timestamp == null) {
    yield const WarningEvent(
      ParseWarning('malformed_row', 'unparseable header time'),
    );
    return;
  }
  final String content = body.join('\n').trim();
  final bool isFromMe = sender == '我' || options.myIdentifiers.contains(sender);
  final _Kind kind = _txtKind(content);
  yield* _emit(
    index: index,
    senderId: sender,
    senderName: sender,
    isFromMe: isFromMe,
    timestamp: timestamp,
    kind: kind,
    text: content,
    mediaRef: kind == _Kind.image ? content : null,
    mediaDir: dir,
  );
}

Stream<ParseEvent> _htmlEvents(String filePath, ParseOptions options) async* {
  final String dir = p.dirname(filePath);
  int index = 0;
  bool sawLine = false;
  await for (final String rawLine in _lines(filePath)) {
    sawLine = true;
    final String line = rawLine.trim();
    if (!line.startsWith('{"i":')) {
      continue;
    }
    final String json = line.endsWith(',')
        ? line.substring(0, line.length - 1)
        : line;
    dynamic obj;
    try {
      obj = jsonDecode(json);
    } on FormatException {
      yield const WarningEvent(
        ParseWarning('malformed_row', 'unparseable WEFLOW_DATA row'),
      );
      continue;
    }
    if (obj is! Map) {
      continue;
    }
    final DateTime? ts = _fromUnixSeconds(_asInt(obj['t']));
    if (ts == null) {
      yield const WarningEvent(
        ParseWarning('malformed_row', 'unparseable message time'),
      );
      continue;
    }
    final bool isFromMe = _asInt(obj['s']) == 1;
    final String avatar = obj['a']?.toString() ?? '';
    final String bodyHtml = obj['b']?.toString() ?? '';
    final String senderId =
        _avatarWxid(avatar) ?? (isFromMe ? 'me' : 'unknown');
    final String senderName = _avatarAlt(avatar) ?? senderId;
    final String? imgSrc = _htmlImgSrc(bodyHtml);
    if (imgSrc != null) {
      yield* _emit(
        index: index++,
        senderId: senderId,
        senderName: senderName,
        isFromMe: isFromMe,
        timestamp: ts,
        kind: _Kind.image,
        text: '',
        mediaRef: imgSrc,
        mediaDir: dir,
      );
    } else {
      yield* _emit(
        index: index++,
        senderId: senderId,
        senderName: senderName,
        isFromMe: isFromMe,
        timestamp: ts,
        kind: _Kind.text,
        text: _htmlUnescape(_messageText(bodyHtml)),
        mediaDir: dir,
      );
    }
  }
  if (!sawLine) {
    yield const WarningEvent(ParseWarning('empty_file', 'file has no content'));
  }
}

Stream<ParseEvent> _emit({
  required int index,
  required String senderId,
  required String senderName,
  required bool isFromMe,
  required DateTime timestamp,
  required _Kind kind,
  required String text,
  String? mediaRef,
  String? mediaDir,
}) async* {
  if (kind != _Kind.image) {
    final String content = text.trim();
    if (content.isEmpty) {
      yield const WarningEvent(
        ParseWarning('empty_message', 'empty message body'),
      );
      return;
    }
    yield MessageEvent(Message(
      id: 'weflow-$index',
      source: DataSource.wechat,
      senderId: senderId,
      senderName: senderName,
      isFromMe: isFromMe,
      timestamp: timestamp,
      type: MessageType.text,
      content: content,
    ));
    return;
  }
  final String sourceRef = mediaRef ?? 'weflow-media-$index';
  final bool available = mediaRef == null ||
      mediaDir == null ||
      File(p.normalize(p.join(mediaDir, mediaRef))).existsSync();
  yield MessageEvent(Message(
    id: 'weflow-$index',
    source: DataSource.wechat,
    senderId: senderId,
    senderName: senderName,
    isFromMe: isFromMe,
    timestamp: timestamp,
    type: MessageType.image,
    content: '[图片]',
    mediaPath: sourceRef,
  ));
  yield MediaIndexEvent(MediaIndexEntry(
    source: DataSource.wechat,
    senderId: senderId,
    timestamp: timestamp,
    type: MessageType.image,
    sourceRef: sourceRef,
    available: available,
  ));
  if (!available) {
    yield WarningEvent(
      ParseWarning('missing_media', 'referenced media not found: $mediaRef'),
    );
  }
}

_Kind _jsonKind(String type, int localType) {
  if (type == '图片消息' || localType == 3) {
    return _Kind.image;
  }
  if (type == '文件消息') {
    return _Kind.file;
  }
  if (type == '引用消息') {
    return _Kind.quote;
  }
  return _Kind.text;
}

_Kind _csvKind(String typeName) {
  switch (typeName.trim().toLowerCase()) {
    case 'image':
      return _Kind.image;
    case 'file':
      return _Kind.file;
    case 'quote':
      return _Kind.quote;
    default:
      return _Kind.text;
  }
}

_Kind _txtKind(String content) {
  if (content.startsWith('[文件]')) {
    return _Kind.file;
  }
  if (content.contains('[引用 ')) {
    return _Kind.quote;
  }
  return _isImagePath(content) ? _Kind.image : _Kind.text;
}

bool _isImagePath(String content) {
  if (content.isEmpty ||
      content.contains(RegExp(r'\s')) ||
      !content.contains('/')) {
    return false;
  }
  return RegExp(r'\.(png|jpe?g|gif|webp|bmp)$', caseSensitive: false)
      .hasMatch(content);
}

_WeflowCols _resolveWeflowCols(List<dynamic> header) {
  final List<String> names = <String>[
    for (final dynamic cell in header)
      cell.toString().replaceAll('﻿', '').trim().toLowerCase(),
  ];
  final int typeName = names.indexOf('type_name');
  final int isSend = names.indexOf('is_sender');
  final int talker = names.indexOf('talker');
  final int content = names.indexOf('msg');
  final int time = names.indexOf('createtime');
  final int src = names.indexOf('src');
  if (typeName < 0 || isSend < 0 || talker < 0 || content < 0 || time < 0) {
    throw ParseException(
      DataSource.wechat,
      'Missing required WeFlow CSV column',
      details: 'type_name=$typeName is_sender=$isSend talker=$talker '
          'msg=$content CreateTime=$time',
    );
  }
  return _WeflowCols(
    typeName: typeName,
    isSend: isSend,
    talker: talker,
    content: content,
    time: time,
    src: src,
  );
}

String _cell(List<dynamic> row, int index) =>
    index >= 0 && index < row.length ? row[index].toString() : '';

DateTime? _parseTime(String raw) {
  final String s = raw.trim();
  if (s.isEmpty) {
    return null;
  }
  return DateTime.tryParse(s);
}

DateTime? _fromUnixSeconds(int seconds) {
  if (seconds <= 0) {
    return null;
  }
  return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
}

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim()) ?? 0;
  }
  return 0;
}

String? _avatarWxid(String avatar) =>
    RegExp(r'src="avatars/(.+?)\.(?:jpg|jpeg|png)"').firstMatch(avatar)?.group(1);

String? _avatarAlt(String avatar) {
  final String? alt = RegExp(r'alt="(.*?)"').firstMatch(avatar)?.group(1);
  if (alt == null || alt.trim().isEmpty) {
    return null;
  }
  return _htmlUnescape(alt);
}

String? _htmlImgSrc(String bodyHtml) =>
    RegExp(r'<img[^>]*\bsrc="([^"]*)"').firstMatch(bodyHtml)?.group(1);

String _messageText(String bodyHtml) =>
    RegExp(r'class="message-text">(.*?)</div>', dotAll: true)
        .firstMatch(bodyHtml)
        ?.group(1) ??
    '';

String _htmlUnescape(String input) => input
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&#x27;', "'")
    .replaceAll('&amp;', '&');

class _CsvRecord {
  const _CsvRecord(this.text, this.line);

  final String text;
  final int line;
}

class _WeflowCols {
  const _WeflowCols({
    required this.typeName,
    required this.isSend,
    required this.talker,
    required this.content,
    required this.time,
    required this.src,
  });

  final int typeName;
  final int isSend;
  final int talker;
  final int content;
  final int time;
  final int src;
}
