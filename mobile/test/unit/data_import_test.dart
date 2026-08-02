import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lostone/models/conversation.dart';
import 'package:lostone/models/message.dart';
import 'package:lostone/models/parse_result.dart';
import 'package:lostone/services/data_import_service.dart';
import 'package:lostone/services/data_preprocessor.dart';
import 'package:lostone/services/parsers/apple_time.dart';
import 'package:lostone/services/parsers/parse_exceptions.dart';
import 'package:lostone/services/parsers/wechat_parser.dart';

const String _fixtures = 'test/fixtures';

Message _msg({
  required String id,
  required DateTime timestamp,
  String sender = 'a',
  String content = 'hi',
  MessageType type = MessageType.text,
}) =>
    Message(
      id: id,
      source: DataSource.wechat,
      senderId: sender,
      senderName: sender,
      isFromMe: false,
      timestamp: timestamp,
      type: type,
      content: content,
    );

void main() {
  group('WeChatParser CSV', () {
    test('parses WeChat CSV into messages (case 1)', () async {
      final ParseResult r =
          await const WeChatParser().parseAll('$_fixtures/wechat_sample.csv');

      expect(r.messages, isNotEmpty);
      expect(r.messages.first.source, DataSource.wechat);
    });

    test('accepts column aliases (case 10a)', () async {
      final ParseResult r = await const WeChatParser()
          .parseAll('$_fixtures/wechat_aliased_cols.csv');

      expect(r.messages, isNotEmpty);
    });

    test('throws when a required column is missing (case 10b)', () {
      expect(
        () =>
            const WeChatParser().parseAll('$_fixtures/wechat_missing_col.csv'),
        throwsA(isA<ParseException>()),
      );
    });

    test('media placeholders are typed, not dropped (case 9)', () async {
      final ParseResult r =
          await const WeChatParser().parseAll('$_fixtures/wechat_media.csv');

      expect(r.messages.any((Message m) => m.type == MessageType.image), isTrue);
      expect(r.messages.any((Message m) => m.type == MessageType.voice), isTrue);

      final Message hongbao =
          r.messages.firstWhere((Message m) => m.content == '[红包]');
      expect(hongbao.type, MessageType.text);
      expect(hongbao.metadata['placeholder'], '[红包]');

      final ({List<Message> messages, int skipped}) result =
          const DataPreprocessor().process(r.messages);
      expect(
        result.messages.any((Message m) => m.type == MessageType.system),
        isFalse,
      );
    });

    test('emits media index with null storedPath matching messages (case 13)',
        () async {
      final ParseResult r =
          await const WeChatParser().parseAll('$_fixtures/wechat_media.csv');

      expect(r.mediaIndex, isNotEmpty);
      expect(
        r.mediaIndex.every((MediaIndexEntry e) => e.storedPath == null),
        isTrue,
      );

      final Message img =
          r.messages.firstWhere((Message m) => m.type == MessageType.image);
      expect(
        r.mediaIndex.any((MediaIndexEntry e) => e.sourceRef == img.mediaPath),
        isTrue,
      );
    });
  });

  group('WeChatParser TXT', () {
    test('multi-line message keeps continuation lines (case 8)', () async {
      final ParseResult r = await const WeChatParser()
          .parseAll('$_fixtures/wechat_multiline.txt');
      final Message m =
          r.messages.firstWhere((Message x) => x.content.contains('第一行'));

      expect(m.content, '第一行\n第二行\n第三行');
    });
  });

  group('WeChatParser HTML', () {
    test('missing referenced media yields missing_media warning (case 12)',
        () async {
      final ParseResult r = await const WeChatParser()
          .parseAll('$_fixtures/wechat_missing_media.html');

      expect(r.messages, isNotEmpty);
      expect(r.mediaIndex.any((MediaIndexEntry e) => !e.available), isTrue);
      expect(
        r.warnings.any((ParseWarning w) => w.code == 'missing_media'),
        isTrue,
      );
    });
  });

  group('WeChatParser streaming', () {
    test('parse streams with bounded throughput (case 11)', () async {
      final Directory tmp = await Directory.systemTemp.createTemp('lostone');
      final File huge = File('${tmp.path}/wechat_huge.txt');
      final StringBuffer buf = StringBuffer();
      const int total = 3000;
      for (int i = 0; i < total; i++) {
        buf.writeln('张三\t2024-01-01 12:00:00');
        buf.writeln('消息正文 $i');
      }
      await huge.writeAsString(buf.toString());

      int count = 0;
      final Stopwatch sw = Stopwatch()..start();
      await for (final ParseEvent e in const WeChatParser().parse(huge.path)) {
        if (e is MessageEvent) {
          count++;
        }
      }
      sw.stop();
      await tmp.delete(recursive: true);

      expect(count, total);
      final int ms = sw.elapsed.inMilliseconds.clamp(1, 1 << 30);
      final double perMin = count / ms * 60000;
      expect(perMin, greaterThanOrEqualTo(5000));
    });
  });

  group('DataPreprocessor', () {
    test('dedups and sorts ascending (case 2)', () {
      final DateTime early = DateTime(2020, 1, 1, 8);
      final DateTime later = DateTime(2020, 1, 1, 9);
      final Message dup = _msg(id: 'a', timestamp: early, content: 'same');
      final Message dup2 = _msg(id: 'b', timestamp: early, content: 'same');
      final Message laterMsg = _msg(id: 'c', timestamp: later, content: 'later');

      final ({List<Message> messages, int skipped}) result =
          const DataPreprocessor().process(<Message>[dup, dup2, laterMsg]);

      expect(result.messages.length, 2);
      expect(result.skipped, 1);
      expect(
        result.messages.first.timestamp
            .isBefore(result.messages.last.timestamp),
        isTrue,
      );
    });

    test('filters system messages', () {
      final Message sys = _msg(
        id: 's',
        timestamp: DateTime(2020),
        type: MessageType.system,
        content: '[撤回了一条消息]',
      );
      final Message ok = _msg(id: 'k', timestamp: DateTime(2020, 1, 1, 1));

      final ({List<Message> messages, int skipped}) result =
          const DataPreprocessor().process(<Message>[sys, ok]);

      expect(result.messages.length, 1);
      expect(result.skipped, 1);
    });

    test('stable order for equal timestamps', () {
      final DateTime t = DateTime(2020, 5, 5, 5);
      final Message first = _msg(id: '1', timestamp: t, content: 'first');
      final Message second = _msg(id: '2', timestamp: t, content: 'second');

      final ({List<Message> messages, int skipped}) result =
          const DataPreprocessor().process(<Message>[first, second]);

      expect(result.messages.map((Message m) => m.content).toList(),
          <String>['first', 'second']);
    });

    test('trims whitespace and strips control characters', () {
      final Message dirty = _msg(
        id: 'd',
        timestamp: DateTime(2020, 6),
        content: ' hi there ',
      );

      final ({List<Message> messages, int skipped}) result =
          const DataPreprocessor().process(<Message>[dirty]);

      expect(result.messages.single.content, 'hi there');
    });
  });

  group('exceptions', () {
    test('ParseException.toString includes source and details', () {
      final ParseException e = ParseException(
        DataSource.wechat,
        'bad structure',
        details: 'no header',
      );
      expect(e.toString(), contains('wechat'));
      expect(e.toString(), contains('no header'));
    });

    test('ImportException.toString includes message', () {
      expect(ImportException('nothing').toString(), contains('nothing'));
    });
  });

  group('Conversation JSON', () {
    test('serializes source, participants, messages and stats', () {
      final Conversation c = Conversation(
        source: DataSource.wechat,
        participants: const <String>['我', '妈妈'],
        messages: <Message>[_msg(id: 'x', timestamp: DateTime(2021))],
        stats: ImportStats(
          totalParsed: 2,
          afterDedup: 1,
          skipped: 1,
          earliest: DateTime(2021),
          latest: DateTime(2021),
        ),
      );

      final Map<String, dynamic> json = c.toJson();
      expect(json['source'], 'wechat');
      expect(json['participants'], <String>['我', '妈妈']);
      expect((json['messages'] as List<dynamic>).length, 1);
      expect((json['stats'] as Map<String, dynamic>)['afterDedup'], 1);
    });
  });

  group('appleDateToDateTime', () {
    test('converts nanosecond date (case 5a)', () {
      expect(
        appleDateToDateTime(662688000000000000).toUtc(),
        DateTime.utc(2022, 1, 1),
      );
    });

    test('converts second-format date (case 5b)', () {
      expect(appleDateToDateTime(662688000).toUtc(), DateTime.utc(2022, 1, 1));
    });
  });

  group('Message JSON', () {
    test('survives round-trip (case 7)', () {
      final Message sample = Message(
        id: 'wechat-1',
        source: DataSource.wechat,
        senderId: 'mom',
        senderName: '妈妈',
        isFromMe: false,
        timestamp: DateTime.parse('2019-03-01T08:12:00.000'),
        type: MessageType.text,
        content: '记得吃早饭',
        metadata: const <String, dynamic>{'k': 'v'},
      );

      final Message restored = Message.fromJson(sample.toJson());
      expect(restored.toJson(), equals(sample.toJson()));
    });
  });

  group('DataImportService', () {
    test('throws ArgumentError for empty file list (case 3)', () {
      expect(
        () => DataImportService().importFiles(<String>[]),
        throwsArgumentError,
      );
    });

    test('isolates single-file failure as warning (case 4)', () async {
      final Conversation c = await DataImportService().importFiles(
        <String>[
          '$_fixtures/wechat_missing_col.csv',
          '$_fixtures/wechat_sample.csv',
        ],
      );

      expect(c.messages, isNotEmpty);
      expect(c.source, DataSource.wechat);
    });

    test('throws ImportException when all files fail', () {
      expect(
        () => DataImportService()
            .importFiles(<String>['$_fixtures/wechat_missing_col.csv']),
        throwsA(isA<ImportException>()),
      );
    });

    test('assembles participants and stats', () async {
      final Conversation c = await DataImportService().importFiles(
        <String>['$_fixtures/wechat_sample.csv'],
        source: DataSource.wechat,
        options: const ParseOptions(myIdentifiers: <String>['我']),
      );

      expect(c.participants, contains('妈妈'));
      expect(c.stats.afterDedup, c.messages.length);
      expect(c.messages.any((Message m) => m.isFromMe), isTrue);
    });
  });
}
