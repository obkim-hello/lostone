import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lostone/models/conversation.dart';
import 'package:lostone/models/message.dart';
import 'package:lostone/models/parse_result.dart';
import 'package:lostone/services/data_import_service.dart';
import 'package:lostone/services/parsers/parse_exceptions.dart';
import 'package:lostone/services/parsers/weibo_parser.dart';

void main() {
  late Directory tmp;

  Future<String> writeJson(String name, Object body) async {
    final String path = '${tmp.path}/$name';
    await File(path).writeAsString(jsonEncode(body));
    return path;
  }

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('lostone_weibo');
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  group('WeiboParser', () {
    test('canParse accepts direct_messages json and rejects others', () async {
      final String ok = await writeJson('dm.json', <String, dynamic>{
        'direct_messages': <dynamic>[],
      });
      final String notWeibo = await writeJson('other.json', <String, dynamic>{
        'messages': <dynamic>[],
      });

      expect(await const WeiboParser().canParse(ok), isTrue);
      expect(await const WeiboParser().canParse(notWeibo), isFalse);
      expect(await const WeiboParser().canParse('nope.csv'), isFalse);
    });

    test('parses Weibo-style created_at into UTC timestamp', () async {
      final String path = await writeJson('dm.json', <String, dynamic>{
        'direct_messages': <dynamic>[
          <String, dynamic>{
            'created_at': 'Wed Jun 12 08:47:29 +0800 2013',
            'text': '在吗',
            'sender_screen_name': '妈妈',
          },
        ],
      });

      final ParseResult r = await const WeiboParser().parseAll(path);

      expect(r.messages.length, 1);
      final Message m = r.messages.single;
      expect(m.source, DataSource.weibo);
      expect(m.type, MessageType.text);
      expect(m.content, '在吗');
      expect(m.senderName, '妈妈');
      expect(m.timestamp.isUtc, isTrue);
      expect(m.timestamp, DateTime.utc(2013, 6, 12, 0, 47, 29));
    });

    test('accepts unix seconds and milliseconds for created_at', () async {
      final String path = await writeJson('dm.json', <String, dynamic>{
        'direct_messages': <dynamic>[
          <String, dynamic>{
            'created_at': 1371026849,
            'text': 'seconds',
            'sender_screen_name': 'a',
          },
          <String, dynamic>{
            'created_at': 1371026849000,
            'text': 'millis',
            'sender_screen_name': 'a',
          },
        ],
      });

      final ParseResult r = await const WeiboParser().parseAll(path);

      expect(r.messages.length, 2);
      expect(r.messages[0].timestamp, DateTime.utc(2013, 6, 12, 8, 47, 29));
      expect(r.messages[1].timestamp, DateTime.utc(2013, 6, 12, 8, 47, 29));
    });

    test('marks my messages via myIdentifiers on screen name or id', () async {
      final String path = await writeJson('dm.json', <String, dynamic>{
        'direct_messages': <dynamic>[
          <String, dynamic>{
            'created_at': 1371026849,
            'text': 'from me by name',
            'sender_screen_name': '我',
          },
          <String, dynamic>{
            'created_at': 1371026849,
            'text': 'from me by id',
            'sender_id': 77777,
          },
          <String, dynamic>{
            'created_at': 1371026849,
            'text': 'from them',
            'sender_screen_name': '妈妈',
          },
        ],
      });

      final ParseResult r = await const WeiboParser().parseAll(
        path,
        options: const ParseOptions(myIdentifiers: <String>['我', '77777']),
      );

      expect(r.messages[0].isFromMe, isTrue);
      expect(r.messages[1].isFromMe, isTrue);
      expect(r.messages[2].isFromMe, isFalse);
    });

    test('warns malformed_row on missing/unparseable created_at', () async {
      final String path = await writeJson('dm.json', <String, dynamic>{
        'direct_messages': <dynamic>[
          <String, dynamic>{'text': 'no time', 'sender_screen_name': 'a'},
          <String, dynamic>{
            'created_at': 'not a date',
            'text': 'bad time',
            'sender_screen_name': 'a',
          },
        ],
      });

      final ParseResult r = await const WeiboParser().parseAll(path);

      expect(r.messages, isEmpty);
      expect(
        r.warnings.where((ParseWarning w) => w.code == 'malformed_row').length,
        2,
      );
    });

    test('warns empty_message and skips blank text', () async {
      final String path = await writeJson('dm.json', <String, dynamic>{
        'direct_messages': <dynamic>[
          <String, dynamic>{
            'created_at': 1371026849,
            'text': '   ',
            'sender_screen_name': 'a',
          },
        ],
      });

      final ParseResult r = await const WeiboParser().parseAll(path);

      expect(r.messages, isEmpty);
      expect(
        r.warnings.any((ParseWarning w) => w.code == 'empty_message'),
        isTrue,
      );
    });

    test('throws ParseException on invalid JSON', () async {
      final String path = '${tmp.path}/broken.json';
      await File(path).writeAsString('{not json');

      expect(
        () => const WeiboParser().parseAll(path),
        throwsA(isA<ParseException>()),
      );
    });

    test('throws ParseException when direct_messages array is absent', () async {
      final String path = await writeJson('dm.json', <String, dynamic>{
        'foo': 'bar',
      });

      expect(
        () => const WeiboParser().parseAll(path),
        throwsA(isA<ParseException>()),
      );
    });

    test('is selected by the registry for weibo json', () async {
      final String path = await writeJson('dm.json', <String, dynamic>{
        'direct_messages': <dynamic>[
          <String, dynamic>{
            'created_at': 1371026849,
            'text': 'hi',
            'sender_screen_name': '妈妈',
          },
        ],
      });

      final Conversation c = await DataImportService().importFiles(
        <String>[path],
        source: DataSource.weibo,
      );

      expect(c.source, DataSource.weibo);
      expect(c.messages.single.content, 'hi');
    });
  });
}
