import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lostone/models/message.dart';
import 'package:lostone/models/parse_result.dart';
import 'package:lostone/services/parser_registry.dart';
import 'package:lostone/services/parsers/data_parser.dart';
import 'package:lostone/services/parsers/parse_exceptions.dart';
import 'package:lostone/services/parsers/weflow_parser.dart';

const String _fixtures = 'test/fixtures';
const String _weflow = '$_fixtures/weflow/texts';
const String _json = '$_weflow/chat.json';
const String _csv = '$_weflow/chat.csv';
const String _txt = '$_weflow/chat.txt';
const String _html = '$_weflow/chat.html';

List<Message> _texts(ParseResult r) => r.messages
    .where((Message m) => m.type == MessageType.text)
    .toList(growable: false);

void main() {
  group('WeFlowParser canParse', () {
    test('detects WeFlow JSON by weflow signature', () async {
      expect(await const WeFlowParser().canParse(_json), isTrue);
      expect(
        await const WeFlowParser().canParse('$_fixtures/instagram_sample.json'),
        isFalse,
      );
    });

    test('rejects JSON that has the weflow token but wrong structure', () async {
      expect(
        await const WeFlowParser().canParse('$_weflow/notweflow.json'),
        isFalse,
      );
    });

    test('detects WeFlow CSV by is_sender/type_name columns', () async {
      expect(await const WeFlowParser().canParse(_csv), isTrue);
      expect(
        await const WeFlowParser().canParse('$_fixtures/wechat_sample.csv'),
        isFalse,
      );
    });

    test('detects WeFlow TXT by timestamp-first header', () async {
      expect(await const WeFlowParser().canParse(_txt), isTrue);
      expect(
        await const WeFlowParser().canParse('$_fixtures/wechat_multiline.txt'),
        isFalse,
      );
    });

    test('detects WeFlow HTML by WEFLOW_DATA marker', () async {
      expect(await const WeFlowParser().canParse(_html), isTrue);
      expect(
        await const WeFlowParser()
            .canParse('$_fixtures/wechat_missing_media.html'),
        isFalse,
      );
    });
  });

  group('WeFlowParser JSON', () {
    test('maps types, direction, timestamps and media', () async {
      final ParseResult r = await const WeFlowParser().parseAll(_json);

      expect(r.messages.length, 6);
      expect(r.messages.every((Message m) => m.source == DataSource.wechat),
          isTrue);
      expect(
        r.messages.map((Message m) => m.isFromMe).toList(),
        <bool>[false, true, true, false, false, true],
      );

      final Message first = r.messages.first;
      expect(first.type, MessageType.text);
      expect(first.content, '在吗<3');
      expect(first.senderId, 'wxid_synth001');
      expect(first.senderName, '小明');
      expect(first.timestamp,
          DateTime.fromMillisecondsSinceEpoch(1785648260000, isUtc: true));

      final Message image = r.messages[2];
      expect(image.type, MessageType.image);
      expect(image.content, '[图片]');
      expect(image.mediaPath, '../images/img_ab.png');

      expect(_texts(r).any((Message m) => m.content == '[文件] notes.txt'),
          isTrue);
      expect(_texts(r).any((Message m) => m.content == '记得带伞[引用 阿花：在的]'),
          isTrue);
    });

    test('emits media index with single join key and missing_media', () async {
      final ParseResult r = await const WeFlowParser().parseAll(_json);

      expect(r.mediaIndex.length, 2);
      expect(
        r.mediaIndex.every((MediaIndexEntry e) => e.storedPath == null),
        isTrue,
      );
      final MediaIndexEntry present = r.mediaIndex
          .firstWhere((MediaIndexEntry e) => e.sourceRef.contains('img_ab'));
      expect(present.available, isTrue);
      final MediaIndexEntry missing = r.mediaIndex
          .firstWhere((MediaIndexEntry e) => e.sourceRef.contains('missing_zz'));
      expect(missing.available, isFalse);
      expect(
        r.warnings.where((ParseWarning w) => w.code == 'missing_media').length,
        1,
      );
    });

    test('throws ParseException on invalid JSON', () async {
      expect(
        () => const WeFlowParser().parseAll('$_weflow/bad.json'),
        throwsA(isA<ParseException>()),
      );
    });
  });

  group('WeFlowParser CSV', () {
    test('parses columns, BOM header and media path', () async {
      final ParseResult r = await const WeFlowParser().parseAll(_csv);

      expect(r.messages.length, 6);
      expect(
        r.messages.map((Message m) => m.isFromMe).toList(),
        <bool>[false, true, true, false, false, true],
      );
      expect(r.messages.first.content, '在吗<3');
      expect(r.messages.first.senderId, 'wxid_synth001');
      expect(r.messages[1].senderId, '阿花');

      final Message image = r.messages[2];
      expect(image.type, MessageType.image);
      expect(image.mediaPath, '../images/img_ab.png');
      expect(image.timestamp,
          DateTime.utc(2026, 8, 2, 5, 24, 24));

      expect(r.mediaIndex.length, 2);
      expect(
        r.warnings.where((ParseWarning w) => w.code == 'missing_media').length,
        1,
      );
    });

    test('throws when required columns are absent', () async {
      expect(
        () => const WeFlowParser()
            .parseAll('$_fixtures/wechat_missing_col.csv'),
        throwsA(isA<ParseException>()),
      );
    });

    test('preserves messages with embedded newlines (quoted field)', () async {
      final ParseResult r =
          await const WeFlowParser().parseAll('$_weflow/multiline.csv');

      expect(r.messages.length, 2);
      expect(r.messages.first.content, '第一行\n第二行');
      expect(r.messages[1].content, '好的');
    });
  });

  group('WeFlowParser TXT', () {
    test('parses timestamp-first blocks and bare media paths', () async {
      final ParseResult r = await const WeFlowParser().parseAll(_txt);

      expect(r.messages.length, 6);
      expect(
        r.messages.map((Message m) => m.isFromMe).toList(),
        <bool>[false, true, true, false, false, true],
      );
      expect(r.messages.first.content, '在吗<3');
      expect(r.messages.first.senderName, 'wxid_synth001');
      expect(r.messages[1].isFromMe, isTrue);

      final Message image = r.messages[2];
      expect(image.type, MessageType.image);
      expect(image.mediaPath, '../images/img_ab.png');

      expect(
        _texts(r).any((Message m) => m.content == '记得带伞[引用 阿花：在的]'),
        isTrue,
      );
      expect(
        r.warnings.where((ParseWarning w) => w.code == 'missing_media').length,
        1,
      );
    });

    test('does not misclassify file/bare-name tokens as images', () async {
      final ParseResult r =
          await const WeFlowParser().parseAll('$_weflow/edge.txt');

      expect(r.messages.length, 3);
      expect(r.messages[0].type, MessageType.text);
      expect(r.messages[0].content, '[文件]照片.jpg');
      expect(r.messages[1].type, MessageType.text);
      expect(r.messages[1].content, 'logo.png');
      expect(r.messages[2].type, MessageType.image);
      expect(r.messages[2].mediaPath, '../images/img_ab.png');
      expect(r.mediaIndex.length, 1);
    });
  });

  group('WeFlowParser HTML', () {
    test('parses embedded WEFLOW_DATA and unescapes entities', () async {
      final ParseResult r = await const WeFlowParser().parseAll(_html);

      expect(r.messages.length, 6);
      expect(
        r.messages.map((Message m) => m.isFromMe).toList(),
        <bool>[false, true, true, false, false, true],
      );
      expect(r.messages.first.content, '在吗<3');
      expect(r.messages.first.senderId, 'wxid_synth001');
      expect(r.messages.first.senderName, '小明');
      expect(r.messages.first.timestamp,
          DateTime.fromMillisecondsSinceEpoch(1785648260000, isUtc: true));

      final Message image = r.messages[2];
      expect(image.type, MessageType.image);
      expect(image.mediaPath, '../images/img_ab.png');

      expect(r.mediaIndex.length, 2);
      expect(
        r.warnings.where((ParseWarning w) => w.code == 'missing_media').length,
        1,
      );
    });
  });

  group('WeFlowParser JSON detection', () {
    test('detects weflow key even when it follows a large messages array',
        () async {
      final Directory tmp =
          await Directory.systemTemp.createTemp('lostone_wfj');
      final File f = File('${tmp.path}/tail.json');
      final StringBuffer buf = StringBuffer('{"messages":[');
      for (int i = 0; i < 500; i++) {
        if (i > 0) {
          buf.write(',');
        }
        buf.write('{"createTime":1785648260,"type":"文本消息","localType":1,'
            '"content":"msg $i","isSend":0,"senderUsername":"user$i"}');
      }
      buf.write('],"weflow":{"version":"1.0.3","generator":"WeFlow"}}');
      await f.writeAsString(buf.toString());

      expect(await const WeFlowParser().canParse(f.path), isTrue);
      await tmp.delete(recursive: true);
    });
  });

  group('WeFlowParser kind metadata', () {
    test('file and quote messages retain a weflow_kind signal', () async {
      final ParseResult r = await const WeFlowParser().parseAll(_json);

      final Message file = _texts(r)
          .firstWhere((Message m) => m.content == '[文件] notes.txt');
      expect(file.metadata['weflow_kind'], 'file');

      final Message quote = _texts(r)
          .firstWhere((Message m) => m.content == '记得带伞[引用 阿花：在的]');
      expect(quote.metadata['weflow_kind'], 'quote');

      expect(r.messages.first.metadata.containsKey('weflow_kind'), isFalse);
    });
  });

  group('WeFlowParser warning codes', () {
    test('image row with empty src is flagged missing, not available',
        () async {
      final Directory tmp =
          await Directory.systemTemp.createTemp('lostone_wfm');
      final File f = File('${tmp.path}/nosrc.csv');
      await f.writeAsString(
        'type_name,is_sender,talker,msg,src,CreateTime\n'
        'image,0,阿花,[图片],,2026-08-02T05:24:24Z\n',
      );

      final ParseResult r = await const WeFlowParser().parseAll(f.path);
      await tmp.delete(recursive: true);

      expect(r.mediaIndex.length, 1);
      expect(r.mediaIndex.first.available, isFalse);
      expect(
        r.warnings.where((ParseWarning w) => w.code == 'missing_media').length,
        1,
      );
    });

    test('empty file emits empty_file', () async {
      final Directory tmp =
          await Directory.systemTemp.createTemp('lostone_wfe');
      final File f = File('${tmp.path}/empty.csv');
      await f.writeAsString('');

      final ParseResult r = await const WeFlowParser().parseAll(f.path);
      await tmp.delete(recursive: true);

      expect(
        r.warnings.any((ParseWarning w) => w.code == 'empty_file'),
        isTrue,
      );
    });

    test('TXT text before first header emits orphan_line', () async {
      final Directory tmp =
          await Directory.systemTemp.createTemp('lostone_wfo');
      final File f = File('${tmp.path}/orphan.txt');
      await f.writeAsString(
        "掉队的一行\n"
        "2026-08-02 13:24:20 '阿花'\n"
        "在的\n",
      );

      final ParseResult r = await const WeFlowParser().parseAll(f.path);
      await tmp.delete(recursive: true);

      expect(
        r.warnings.any((ParseWarning w) => w.code == 'orphan_line'),
        isTrue,
      );
      expect(r.messages.length, 1);
    });

    test('empty message body emits empty_message', () async {
      final Directory tmp =
          await Directory.systemTemp.createTemp('lostone_wfem');
      final File f = File('${tmp.path}/blank.csv');
      await f.writeAsString(
        'type_name,is_sender,talker,msg,src,CreateTime\n'
        'text,0,阿花,   ,,2026-08-02T05:24:24Z\n',
      );

      final ParseResult r = await const WeFlowParser().parseAll(f.path);
      await tmp.delete(recursive: true);

      expect(r.messages, isEmpty);
      expect(
        r.warnings.any((ParseWarning w) => w.code == 'empty_message'),
        isTrue,
      );
    });

    test('unparseable time emits malformed_row', () async {
      final Directory tmp =
          await Directory.systemTemp.createTemp('lostone_wfr');
      final File f = File('${tmp.path}/badtime.csv');
      await f.writeAsString(
        'type_name,is_sender,talker,msg,src,CreateTime\n'
        'text,0,阿花,在的,,not-a-time\n',
      );

      final ParseResult r = await const WeFlowParser().parseAll(f.path);
      await tmp.delete(recursive: true);

      expect(
        r.warnings.any((ParseWarning w) => w.code == 'malformed_row'),
        isTrue,
      );
    });
  });

  group('ParserRegistry routing', () {
    test('routes WeFlow files to WeFlowParser under wechat', () async {
      final ParserRegistry registry = ParserRegistry();
      for (final String path in <String>[_json, _csv, _txt, _html]) {
        final DataParser? parser = await registry.match(path);
        expect(parser, isA<WeFlowParser>(), reason: path);
        expect(parser!.source, DataSource.wechat);
      }
    });

    test('generic WeChat files still route to WeChatParser', () async {
      final ParserRegistry registry = ParserRegistry();
      final DataParser? parser =
          await registry.match('$_fixtures/wechat_sample.csv');
      expect(parser, isNotNull);
      expect(parser, isNot(isA<WeFlowParser>()));
      expect(parser!.source, DataSource.wechat);
    });
  });
}
