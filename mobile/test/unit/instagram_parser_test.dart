import 'package:flutter_test/flutter_test.dart';
import 'package:lostone/models/conversation.dart';
import 'package:lostone/models/message.dart';
import 'package:lostone/models/parse_result.dart';
import 'package:lostone/services/data_import_service.dart';
import 'package:lostone/services/parsers/instagram_parser.dart';

const String _fixtures = 'test/fixtures';
const String _sample = '$_fixtures/instagram_sample.json';

void main() {
  group('InstagramParser', () {
    test('canParse detects the Meta DYI structure', () async {
      expect(await const InstagramParser().canParse(_sample), isTrue);
      expect(
        await const InstagramParser().canParse('$_fixtures/wechat_sample.csv'),
        isFalse,
      );
    });

    test('parses text and photo messages', () async {
      final ParseResult r = await const InstagramParser().parseAll(_sample);

      expect(r.messages.first.source, DataSource.instagram);
      expect(
        r.messages.any((Message m) => m.content == '记得吃早饭'),
        isTrue,
      );
      expect(
        r.messages.any((Message m) => m.type == MessageType.image),
        isTrue,
      );
    });

    test('converts timestamp_ms to UTC', () async {
      final ParseResult r = await const InstagramParser().parseAll(_sample);
      final Message first =
          r.messages.firstWhere((Message m) => m.content == '记得吃早饭');

      expect(first.timestamp.toUtc(), DateTime.utc(2021, 1, 1));
    });

    test('a message with text and a photo yields two messages', () async {
      final ParseResult r = await const InstagramParser().parseAll(_sample);
      final Iterable<Message> combo =
          r.messages.where((Message m) => m.content == '配张图');

      expect(combo.length, 1);
      expect(
        r.messages.where((Message m) => m.type == MessageType.image).length,
        3,
      );
    });

    test('media index join key matches message mediaPath (single source)',
        () async {
      final ParseResult r = await const InstagramParser().parseAll(_sample);
      final Message img =
          r.messages.firstWhere((Message m) => m.type == MessageType.image);

      expect(
        r.mediaIndex.any((MediaIndexEntry e) => e.sourceRef == img.mediaPath),
        isTrue,
      );
      expect(
        r.mediaIndex.every((MediaIndexEntry e) => e.storedPath == null),
        isTrue,
      );
    });

    test('missing referenced media yields warning and unavailable entry',
        () async {
      final ParseResult r = await const InstagramParser().parseAll(_sample);

      expect(r.mediaIndex.any((MediaIndexEntry e) => !e.available), isTrue);
      expect(
        r.warnings.any((ParseWarning w) => w.code == 'missing_media'),
        isTrue,
      );
    });

    test('marks my messages via myIdentifiers', () async {
      final ParseResult r = await const InstagramParser().parseAll(
        _sample,
        options: const ParseOptions(myIdentifiers: <String>['我']),
      );

      expect(r.messages.any((Message m) => m.isFromMe), isTrue);
    });

    test('is selected by the registry for instagram json', () async {
      final Conversation c = await DataImportService().importFiles(
        <String>[_sample],
        source: DataSource.instagram,
      );

      expect(c.source, DataSource.instagram);
      expect(c.messages, isNotEmpty);
    });
  });
}
