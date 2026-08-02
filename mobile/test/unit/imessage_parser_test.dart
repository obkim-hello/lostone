import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lostone/models/conversation.dart';
import 'package:lostone/models/message.dart';
import 'package:lostone/models/parse_result.dart';
import 'package:lostone/services/data_import_service.dart';
import 'package:lostone/services/parsers/imessage_parser.dart';
import 'package:sqlite3/sqlite3.dart';

const int _nanos20220101 = 662688000000000000;
const int _oneMinuteNanos = 60000000000;

Future<String> _buildChatDb(Directory dir) async {
  final String path = '${dir.path}/chat.db';
  final Database db = sqlite3.open(path);
  db
    ..execute('CREATE TABLE handle(ROWID INTEGER PRIMARY KEY, id TEXT)')
    ..execute(
      'CREATE TABLE message(ROWID INTEGER PRIMARY KEY, text TEXT, '
      'attributedBody BLOB, date INTEGER, is_from_me INTEGER, '
      'handle_id INTEGER)',
    )
    ..execute('CREATE TABLE chat(ROWID INTEGER PRIMARY KEY, chat_identifier TEXT)')
    ..execute(
      'CREATE TABLE chat_message_join(chat_id INTEGER, message_id INTEGER)',
    )
    ..execute("INSERT INTO handle VALUES (1, 'mom@example.com')")
    ..execute(
      'INSERT INTO message(ROWID, text, date, is_from_me, handle_id) VALUES '
      "(1, '记得吃早饭', $_nanos20220101, 0, 1),"
      "(2, '好的', ${_nanos20220101 + _oneMinuteNanos}, 1, 0),"
      "(3, NULL, ${_nanos20220101 + 2 * _oneMinuteNanos}, 0, 1)",
    );
  db.dispose();
  return path;
}

Uint8List _attributedBody(String text) {
  final List<int> textBytes = utf8.encode(text);
  final List<int> lengthPrefix = textBytes.length < 0x80
      ? <int>[textBytes.length]
      : <int>[0x81, textBytes.length & 0xff, (textBytes.length >> 8) & 0xff];
  return Uint8List.fromList(<int>[
    0x04,
    0x0b,
    ...utf8.encode('streamtyped'),
    ...utf8.encode('NSString'),
    0x01,
    0x94,
    0x84,
    0x01,
    0x2b,
    ...lengthPrefix,
    ...textBytes,
    0x86,
  ]);
}

void main() {
  late Directory tmp;
  late String dbPath;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('lostone_imsg');
    dbPath = await _buildChatDb(tmp);
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  group('IMessageParser', () {
    test('canParse accepts a chat.db and rejects other files', () async {
      expect(await const IMessageParser().canParse(dbPath), isTrue);
      expect(
        await const IMessageParser().canParse('test/fixtures/wechat_sample.csv'),
        isFalse,
      );
    });

    test('parses text messages ordered by Apple date', () async {
      final ParseResult r = await const IMessageParser().parseAll(dbPath);

      expect(r.messages.length, 2);
      expect(r.messages.first.content, '记得吃早饭');
      expect(r.messages.first.source, DataSource.imessage);
      expect(r.messages.first.timestamp.toUtc(), DateTime.utc(2022, 1, 1));
      expect(
        r.messages.first.timestamp.isBefore(r.messages.last.timestamp),
        isTrue,
      );
    });

    test('maps is_from_me and handle to sender', () async {
      final ParseResult r = await const IMessageParser().parseAll(dbPath);
      final Message fromMom =
          r.messages.firstWhere((Message m) => m.content == '记得吃早饭');
      final Message fromMe =
          r.messages.firstWhere((Message m) => m.content == '好的');

      expect(fromMom.isFromMe, isFalse);
      expect(fromMom.senderId, 'mom@example.com');
      expect(fromMe.isFromMe, isTrue);
      expect(fromMe.senderId, 'me');
    });

    test('empty-text rows yield empty_message warning, not messages', () async {
      final ParseResult r = await const IMessageParser().parseAll(dbPath);

      expect(
        r.warnings.any((ParseWarning w) => w.code == 'empty_message'),
        isTrue,
      );
    });

    test('targetContact filters to that handle plus my messages', () async {
      final ParseResult kept = await const IMessageParser().parseAll(
        dbPath,
        options: const ParseOptions(targetContact: 'mom@example.com'),
      );
      expect(kept.messages.length, 2);

      final ParseResult narrowed = await const IMessageParser().parseAll(
        dbPath,
        options: const ParseOptions(targetContact: 'other@example.com'),
      );
      expect(narrowed.messages.length, 1);
      expect(narrowed.messages.single.isFromMe, isTrue);
    });

    test('falls back to attributedBody when text is NULL', () async {
      final Database db = sqlite3.open(dbPath);
      final PreparedStatement stmt = db.prepare(
        'INSERT INTO message(ROWID, text, attributedBody, date, '
        'is_from_me, handle_id) VALUES (?, NULL, ?, ?, ?, ?)',
      );
      stmt.execute(<Object?>[
        4,
        _attributedBody('晚安好好休息'),
        _nanos20220101 + 3 * _oneMinuteNanos,
        0,
        1,
      ]);
      stmt.dispose();
      db.dispose();

      final ParseResult r = await const IMessageParser().parseAll(dbPath);

      final Message recovered =
          r.messages.firstWhere((Message m) => m.content == '晚安好好休息');
      expect(recovered.senderId, 'mom@example.com');
      expect(recovered.isFromMe, isFalse);
    });

    test('decodes attributedBody with extended (0x81) length prefix', () async {
      final String longText = '早' * 60;
      expect(longText.length * 3, greaterThan(0x7f));
      final Database db = sqlite3.open(dbPath);
      final PreparedStatement stmt = db.prepare(
        'INSERT INTO message(ROWID, text, attributedBody, date, '
        'is_from_me, handle_id) VALUES (?, NULL, ?, ?, ?, ?)',
      );
      stmt.execute(<Object?>[
        5,
        _attributedBody(longText),
        _nanos20220101 + 4 * _oneMinuteNanos,
        0,
        1,
      ]);
      stmt.dispose();
      db.dispose();

      final ParseResult r = await const IMessageParser().parseAll(dbPath);

      expect(r.messages.any((Message m) => m.content == longText), isTrue);
    });

    test('malformed attributedBody degrades to empty_message, no throw',
        () async {
      final Database db = sqlite3.open(dbPath);
      final PreparedStatement stmt = db.prepare(
        'INSERT INTO message(ROWID, text, attributedBody, date, '
        'is_from_me, handle_id) VALUES (?, NULL, ?, ?, ?, ?)',
      );
      final Uint8List junk =
          Uint8List.fromList(<int>[0x04, 0x0b, 0x01, 0x02, 0x03, 0x04, 0x05]);
      stmt.execute(<Object?>[
        6,
        junk,
        _nanos20220101 + 5 * _oneMinuteNanos,
        0,
        1,
      ]);
      stmt.dispose();
      db.dispose();

      final ParseResult r = await const IMessageParser().parseAll(dbPath);

      expect(r.messages.every((Message m) => m.content.isNotEmpty), isTrue);
      expect(r.messages.any((Message m) => m.id == 'imessage-6'), isFalse);
      expect(
        r.warnings.where((ParseWarning w) => w.code == 'empty_message').length,
        greaterThanOrEqualTo(2),
      );
    });

    test('is selected by the registry for a .db file', () async {
      final Conversation c = await DataImportService().importFiles(
        <String>[dbPath],
        source: DataSource.imessage,
      );

      expect(c.source, DataSource.imessage);
      expect(c.messages, isNotEmpty);
    });
  });
}
