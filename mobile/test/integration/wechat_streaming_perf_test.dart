import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lostone/models/parse_result.dart';
import 'package:lostone/services/parsers/wechat_parser.dart';

void main() {
  late Directory tmp;
  late String bigCsv;
  const int rowCount = 100000;

  String pad(int v) => v.toString().padLeft(2, '0');

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('lostone_perf');
    bigCsv = '${tmp.path}/big.csv';
    final IOSink sink = File(bigCsv).openWrite();
    sink.writeln('sender,timestamp,content');
    for (int i = 0; i < rowCount; i++) {
      final String ts =
          '2024-01-${pad((i % 28) + 1)} ${pad(i % 24)}:${pad(i % 60)}:${pad(i % 60)}';
      sink.writeln('user${i % 100},$ts,msg $i');
    }
    await sink.flush();
    await sink.close();
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  group('WeChatParser streaming at scale (ERD §7.3)', () {
    test('consumes 100k rows lazily via the event stream, meets throughput',
        () async {
      int messages = 0;
      int warnings = 0;
      final Stopwatch sw = Stopwatch()..start();
      await for (final ParseEvent e in const WeChatParser().parse(bigCsv)) {
        switch (e) {
          case MessageEvent():
            messages++;
          case WarningEvent():
            warnings++;
          case MediaIndexEvent():
            break;
        }
      }
      sw.stop();

      expect(messages, rowCount);
      expect(warnings, 0);

      final double elapsedSeconds = sw.elapsedMilliseconds / 1000.0;
      final double perMinute =
          elapsedSeconds > 0 ? messages / elapsedSeconds * 60.0 : double.infinity;
      expect(perMinute, greaterThanOrEqualTo(5000));
    });
  });
}
