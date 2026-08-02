import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lostone/models/parse_result.dart';
import 'package:lostone/services/parsers/weflow_parser.dart';

void main() {
  late Directory tmp;
  late Directory texts;
  const int rowCount = 100000;

  String pad(int v) => v.toString().padLeft(2, '0');

  String isoUtc(int i) =>
      DateTime.fromMillisecondsSinceEpoch(1785648260000 + i * 1000, isUtc: true)
          .toIso8601String();

  String wallClock(int i) {
    final DateTime d =
        DateTime.fromMillisecondsSinceEpoch(1785648260000 + i * 1000, isUtc: true);
    return '${d.year}-${pad(d.month)}-${pad(d.day)} '
        '${pad(d.hour)}:${pad(d.minute)}:${pad(d.second)}';
  }

  int unixSec(int i) => 1785648260 + i;
  bool isImage(int i) => i % 20 == 0;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('lostone_weflow_bench');
    texts = Directory('${tmp.path}/texts')..createSync();
    final Directory images = Directory('${tmp.path}/images')..createSync();
    File('${images.path}/img.png').writeAsStringSync('synthetic-png-bytes');
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  Future<void> bench(String label, String path) async {
    int messages = 0;
    int media = 0;
    int warnings = 0;
    final Stopwatch sw = Stopwatch()..start();
    await for (final ParseEvent e in const WeFlowParser().parse(path)) {
      switch (e) {
        case MessageEvent():
          messages++;
        case MediaIndexEvent():
          media++;
        case WarningEvent():
          warnings++;
      }
    }
    sw.stop();
    final double seconds = sw.elapsedMilliseconds / 1000.0;
    final double perMinute =
        seconds > 0 ? messages / seconds * 60.0 : double.infinity;
    // ignore: avoid_print
    print('[$label] $messages msgs, $media media, $warnings warn '
        'in ${seconds.toStringAsFixed(2)}s '
        '=> ${(perMinute / 1000).toStringAsFixed(0)}k msg/min');

    expect(messages, rowCount);
    expect(warnings, 0);
    expect(perMinute, greaterThanOrEqualTo(5000));
  }

  group('WeFlowParser 100k benchmark', () {
    test('CSV (streaming)', () async {
      final String path = '${texts.path}/big.csv';
      final IOSink s = File(path).openWrite();
      s.writeln('id,MsgSvrID,type_name,is_sender,talker,msg,src,CreateTime');
      for (int i = 0; i < rowCount; i++) {
        if (isImage(i)) {
          s.writeln('$i,$i,image,${i % 2},user${i % 100},[图片],'
              '../images/img.png,${isoUtc(i)}');
        } else {
          s.writeln('$i,$i,text,${i % 2},user${i % 100},msg $i,,${isoUtc(i)}');
        }
      }
      await s.flush();
      await s.close();
      await bench('CSV ', path);
    });

    test('TXT (streaming)', () async {
      final String path = '${texts.path}/big.txt';
      final IOSink s = File(path).openWrite();
      for (int i = 0; i < rowCount; i++) {
        final String sender = i % 2 == 0 ? 'user${i % 100}' : '我';
        s.writeln("${wallClock(i)} '$sender'");
        s.writeln(isImage(i) ? '../images/img.png' : 'msg $i');
        s.writeln();
      }
      await s.flush();
      await s.close();
      await bench('TXT ', path);
    });

    test('JSON (whole-document)', () async {
      final String path = '${texts.path}/big.json';
      final IOSink s = File(path).openWrite();
      s.write('{"weflow":{"version":"1.0.3","generator":"WeFlow"},'
          '"session":{"wxid":"wxid_x","type":"私聊"},"messages":[');
      for (int i = 0; i < rowCount; i++) {
        if (i > 0) {
          s.write(',');
        }
        if (isImage(i)) {
          s.write('{"localId":$i,"createTime":${unixSec(i)},"type":"图片消息",'
              '"localType":3,"content":"../images/img.png","isSend":${i % 2},'
              '"senderUsername":"user${i % 100}","senderDisplayName":"U${i % 100}"}');
        } else {
          s.write('{"localId":$i,"createTime":${unixSec(i)},"type":"文本消息",'
              '"localType":1,"content":"msg $i","isSend":${i % 2},'
              '"senderUsername":"user${i % 100}","senderDisplayName":"U${i % 100}"}');
        }
      }
      s.write(']}');
      await s.flush();
      await s.close();
      await bench('JSON', path);
    });

    test('HTML (line-based)', () async {
      final String path = '${texts.path}/big.html';
      final IOSink s = File(path).openWrite();
      s.writeln('<html><body><script>window.WEFLOW_DATA = [');
      for (int i = 0; i < rowCount; i++) {
        final String comma = i < rowCount - 1 ? ',' : '';
        final String body = isImage(i)
            ? '<div class=\\"message-content\\">'
                '<img class=\\"message-image\\" src=\\"../images/img.png\\" /></div>'
            : '<div class=\\"message-content\\">'
                '<div class=\\"message-text\\">msg $i</div></div>';
        s.writeln('{"i":$i,"t":${unixSec(i)},"s":${i % 2},'
            '"a":"<img src=\\"avatars/user${i % 100}.jpg\\" alt=\\"U${i % 100}\\" />",'
            '"b":"$body","p":"$i"}$comma');
      }
      s.writeln(']</script></body></html>');
      await s.flush();
      await s.close();
      await bench('HTML', path);
    });
  });
}
