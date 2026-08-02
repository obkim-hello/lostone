import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lostone/models/message.dart';
import 'package:lostone/models/parse_result.dart';
import 'package:lostone/services/media_store.dart';

void main() {
  late Directory tmp;
  late Directory dest;

  Future<String> writeSource(String name, String body) async {
    final String path = '${tmp.path}/$name';
    await File(path).writeAsString(body);
    return path;
  }

  MediaIndexEntry entry(
    String sourceRef, {
    MessageType type = MessageType.image,
    bool available = true,
  }) =>
      MediaIndexEntry(
        source: DataSource.photo,
        senderId: 'me',
        timestamp: DateTime(2022),
        type: type,
        sourceRef: sourceRef,
        available: available,
      );

  MediaStore store({
    MediaStorageMode mode = MediaStorageMode.copyIntoSandbox,
    Future<void> Function(Directory dir)? excludeFromBackup,
  }) =>
      MediaStore(
        destinationDir: dest,
        resolveSource: (MediaIndexEntry e) => e.sourceRef,
        mode: mode,
        excludeFromBackup: excludeFromBackup,
      );

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('lostone_media_src');
    dest = await Directory.systemTemp.createTemp('lostone_media_dst');
    await dest.delete(recursive: true);
  });

  tearDown(() async {
    if (tmp.existsSync()) {
      await tmp.delete(recursive: true);
    }
    if (dest.existsSync()) {
      await dest.delete(recursive: true);
    }
  });

  group('MediaStore', () {
    test('textOnly tier copies nothing and leaves storedPath null', () async {
      final String img = await writeSource('a.jpg', 'img');
      final List<MediaIndexEntry> out = await store().landAll(
        <MediaIndexEntry>[entry(img)],
        tier: MediaTier.textOnly,
      );

      expect(out.single.storedPath, isNull);
      expect(dest.existsSync(), isFalse);
    });

    test('all tier copies image, voice, and video bytes into destination',
        () async {
      final String img = await writeSource('a.jpg', 'img');
      final String voice = await writeSource('b.m4a', 'voice');
      final String video = await writeSource('c.mp4', 'video');
      final List<MediaIndexEntry> out = await store().landAll(
        <MediaIndexEntry>[
          entry(img),
          entry(voice, type: MessageType.voice),
          entry(video, type: MessageType.video),
        ],
        tier: MediaTier.all,
      );

      for (final MediaIndexEntry e in out) {
        expect(e.storedPath, isNotNull);
        expect(File(e.storedPath!).existsSync(), isTrue);
      }
    });

    test('photoAndVoice tier copies image and voice but not video', () async {
      final String img = await writeSource('a.jpg', 'img');
      final String voice = await writeSource('b.m4a', 'voice');
      final String video = await writeSource('c.mp4', 'video');
      final List<MediaIndexEntry> out = await store().landAll(
        <MediaIndexEntry>[
          entry(img),
          entry(voice, type: MessageType.voice),
          entry(video, type: MessageType.video),
        ],
        tier: MediaTier.photoAndVoice,
      );

      expect(out[0].storedPath, isNotNull);
      expect(out[1].storedPath, isNotNull);
      expect(out[2].storedPath, isNull);
    });

    test('referenceInPlace mode never copies and keeps storedPath null',
        () async {
      final String img = await writeSource('a.jpg', 'img');
      final List<MediaIndexEntry> out =
          await store(mode: MediaStorageMode.referenceInPlace).landAll(
        <MediaIndexEntry>[entry(img)],
        tier: MediaTier.all,
      );

      expect(out.single.storedPath, isNull);
      expect(dest.existsSync(), isFalse);
    });

    test('missing source marks entry unavailable without throwing', () async {
      final List<MediaIndexEntry> out = await store().landAll(
        <MediaIndexEntry>[entry('${tmp.path}/gone.jpg')],
        tier: MediaTier.all,
      );

      expect(out.single.available, isFalse);
      expect(out.single.storedPath, isNull);
    });

    test('already-unavailable entry is passed through untouched', () async {
      final List<MediaIndexEntry> out = await store().landAll(
        <MediaIndexEntry>[entry('${tmp.path}/x.jpg', available: false)],
        tier: MediaTier.all,
      );

      expect(out.single.available, isFalse);
      expect(out.single.storedPath, isNull);
      expect(dest.existsSync(), isFalse);
    });

    test('excludeFromBackup hook fires once before the first copy', () async {
      int calls = 0;
      final String img = await writeSource('a.jpg', 'img');
      final String voice = await writeSource('b.m4a', 'voice');
      await store(excludeFromBackup: (Directory dir) async {
        calls++;
      }).landAll(
        <MediaIndexEntry>[entry(img), entry(voice, type: MessageType.voice)],
        tier: MediaTier.all,
      );

      expect(calls, 1);
    });

    test('excludeFromBackup hook does not fire when nothing is copied',
        () async {
      int calls = 0;
      final String img = await writeSource('a.jpg', 'img');
      await store(excludeFromBackup: (Directory dir) async {
        calls++;
      }).landAll(
        <MediaIndexEntry>[entry(img)],
        tier: MediaTier.textOnly,
      );

      expect(calls, 0);
    });

    test('colliding basenames land under distinct stored names', () async {
      final Directory sub = await Directory('${tmp.path}/sub').create();
      final String a = await writeSource('dup.jpg', 'first');
      final String b = '${sub.path}/dup.jpg';
      await File(b).writeAsString('second');

      final List<MediaIndexEntry> out = await store().landAll(
        <MediaIndexEntry>[entry(a), entry(b)],
        tier: MediaTier.all,
      );

      expect(out[0].storedPath, isNot(out[1].storedPath));
      expect(File(out[0].storedPath!).existsSync(), isTrue);
      expect(File(out[1].storedPath!).existsSync(), isTrue);
    });

    test('input list is not mutated', () async {
      final String img = await writeSource('a.jpg', 'img');
      final List<MediaIndexEntry> input = <MediaIndexEntry>[entry(img)];
      await store().landAll(input, tier: MediaTier.all);

      expect(input.single.storedPath, isNull);
    });
  });
}
