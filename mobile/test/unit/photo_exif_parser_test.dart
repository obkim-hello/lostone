import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lostone/models/conversation.dart';
import 'package:lostone/models/message.dart';
import 'package:lostone/models/parse_result.dart';
import 'package:lostone/services/data_import_service.dart';
import 'package:lostone/services/parsers/photo_exif_parser.dart';

List<int> _le16(int v) => <int>[v & 0xff, (v >> 8) & 0xff];

List<int> _le32(int v) => <int>[
      v & 0xff,
      (v >> 8) & 0xff,
      (v >> 16) & 0xff,
      (v >> 24) & 0xff,
    ];

List<int> _entry(int tag, int type, int count, List<int> value4) => <int>[
      ..._le16(tag),
      ..._le16(type),
      ..._le32(count),
      ...value4,
    ];

Uint8List _exifJpeg() {
  const List<int> dateTime = <int>[
    0x32, 0x30, 0x32, 0x32, 0x3a, 0x30, 0x31, 0x3a, 0x30, 0x31,
    0x20, 0x31, 0x32, 0x3a, 0x30, 0x30, 0x3a, 0x30, 0x30, 0x00,
  ];
  final List<int> tiff = <int>[
    0x49, 0x49,
    ..._le16(42),
    ..._le32(8),
    ..._le16(2),
    ..._entry(0x8769, 4, 1, _le32(38)),
    ..._entry(0x8825, 4, 1, _le32(76)),
    ..._le32(0),
    ..._le16(1),
    ..._entry(0x9003, 2, 20, _le32(56)),
    ..._le32(0),
    ...dateTime,
    ..._le16(4),
    ..._entry(0x0001, 2, 2, <int>[0x4e, 0x00, 0x00, 0x00]),
    ..._entry(0x0002, 5, 3, _le32(130)),
    ..._entry(0x0003, 2, 2, <int>[0x45, 0x00, 0x00, 0x00]),
    ..._entry(0x0004, 5, 3, _le32(154)),
    ..._le32(0),
    ..._le32(37), ..._le32(1), ..._le32(0), ..._le32(1), ..._le32(0),
    ..._le32(1),
    ..._le32(122), ..._le32(1), ..._le32(0), ..._le32(1), ..._le32(0),
    ..._le32(1),
  ];
  final List<int> payload = <int>[
    0x45, 0x78, 0x69, 0x66, 0x00, 0x00,
    ...tiff,
  ];
  final int segmentLength = payload.length + 2;
  return Uint8List.fromList(<int>[
    0xff, 0xd8,
    0xff, 0xe1,
    (segmentLength >> 8) & 0xff, segmentLength & 0xff,
    ...payload,
    0xff, 0xd9,
  ]);
}

Uint8List _noExifJpeg() => Uint8List.fromList(<int>[0xff, 0xd8, 0xff, 0xd9]);

void main() {
  late Directory tmp;
  late String withExif;
  late String noExif;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('lostone_exif');
    withExif = '${tmp.path}/with_exif.jpg';
    noExif = '${tmp.path}/no_exif.jpg';
    await File(withExif).writeAsBytes(_exifJpeg());
    await File(noExif).writeAsBytes(_noExifJpeg());
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  group('PhotoExifParser', () {
    test('canParse accepts image extensions and rejects others', () async {
      expect(await const PhotoExifParser().canParse(withExif), isTrue);
      expect(
        await const PhotoExifParser().canParse('test/fixtures/wechat_sample.csv'),
        isFalse,
      );
    });

    test('parses DateTimeOriginal into the message timestamp', () async {
      final ParseResult r = await const PhotoExifParser().parseAll(withExif);

      expect(r.messages.length, 1);
      final Message m = r.messages.single;
      expect(m.source, DataSource.photo);
      expect(m.type, MessageType.image);
      expect(m.timestamp.year, 2022);
      expect(m.timestamp.month, 1);
      expect(m.timestamp.day, 1);
      expect(m.timestamp.hour, 12);
    });

    test('extracts decimal GPS into metadata when extractLocation is on',
        () async {
      final ParseResult r = await const PhotoExifParser().parseAll(
        withExif,
        options: const ParseOptions(extractLocation: true),
      );

      final Message m = r.messages.single;
      expect(m.metadata['latitude'], closeTo(37.0, 0.0001));
      expect(m.metadata['longitude'], closeTo(122.0, 0.0001));
    });

    test('omits GPS when extractLocation is off (default)', () async {
      final ParseResult r = await const PhotoExifParser().parseAll(withExif);

      final Message m = r.messages.single;
      expect(m.metadata.containsKey('latitude'), isFalse);
      expect(m.metadata.containsKey('longitude'), isFalse);
    });

    test('warns missing_exif and yields no message when EXIF datetime absent',
        () async {
      final ParseResult r = await const PhotoExifParser().parseAll(noExif);

      expect(r.messages, isEmpty);
      expect(
        r.warnings.any((ParseWarning w) => w.code == 'missing_exif'),
        isTrue,
      );
    });

    test('media index sourceRef equals mediaPath (single join key)', () async {
      final ParseResult r = await const PhotoExifParser().parseAll(withExif);

      expect(r.mediaIndex.length, 1);
      final MediaIndexEntry entry = r.mediaIndex.single;
      expect(entry.available, isTrue);
      expect(entry.sourceRef, r.messages.single.mediaPath);
      expect(entry.storedPath, isNull);
    });

    test('is selected by the registry for a .jpg file', () async {
      final Conversation c = await DataImportService().importFiles(
        <String>[withExif],
        source: DataSource.photo,
      );

      expect(c.source, DataSource.photo);
      expect(c.messages, isNotEmpty);
    });
  });
}
