import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:lostone/models/app_settings.dart';
import 'package:lostone/services/settings/settings_repository.dart';

void main() {
  group('C1 SettingsRepository.load on an empty store returns defaults', () {
    test('InMemorySettingsRepository yields default AppSettings', () async {
      final SettingsRepository repo = InMemorySettingsRepository();

      final AppSettings loaded = await repo.load();

      expect(loaded, const AppSettings());
      expect(loaded.runtime, RuntimeChoice.local);
      expect(loaded.cloudAuthorized, isFalse);
      expect(loaded.activeModelId, isNull);
      expect(loaded.chatTemperature, 0.7);
    });

    test('HiveSettingsRepository yields default AppSettings', () async {
      await _withBox((Box<dynamic> box) async {
        final SettingsRepository repo = HiveSettingsRepository(box: box);

        final AppSettings loaded = await repo.load();

        expect(loaded, const AppSettings());
      });
    });
  });

  group('C2 SettingsRepository round-trips every non-secret field', () {
    const AppSettings custom = AppSettings(
      runtime: RuntimeChoice.cloud,
      cloudAuthorized: true,
      cloudProvider: CloudProvider.anthropic,
      cloudEndpoint: 'https://gw.example.com/v1',
      cloudModel: 'claude-3-5-sonnet-latest',
      activeModelId: 'gemma-3-1b',
      chatTemperature: 0.2,
    );

    test('InMemorySettingsRepository save then load is equal', () async {
      final SettingsRepository repo = InMemorySettingsRepository();

      await repo.save(custom);
      final AppSettings loaded = await repo.load();

      expect(loaded, custom);
    });

    test('HiveSettingsRepository save then load is equal', () async {
      await _withBox((Box<dynamic> box) async {
        final SettingsRepository repo = HiveSettingsRepository(box: box);

        await repo.save(custom);
        final AppSettings loaded = await repo.load();

        expect(loaded, custom);
      });
    });

    test(
      'HiveSettingsRepository clears activeModelId when saved null',
      () async {
        await _withBox((Box<dynamic> box) async {
          final SettingsRepository repo = HiveSettingsRepository(box: box);

          await repo.save(custom);
          await repo.save(custom.copyWith(activeModelId: null));
          final AppSettings loaded = await repo.load();

          expect(loaded.activeModelId, isNull);
        });
      },
    );

    test('HiveSettingsRepository round-trips cloudProvider and cloudModel',
        () async {
      await _withBox((Box<dynamic> box) async {
        final SettingsRepository repo = HiveSettingsRepository(box: box);

        await repo.save(custom);
        final AppSettings loaded = await repo.load();

        expect(loaded.cloudProvider, CloudProvider.anthropic);
        expect(loaded.cloudModel, 'claude-3-5-sonnet-latest');
        expect(loaded.cloudEndpoint, 'https://gw.example.com/v1');
      });
    });

    test('HiveSettingsRepository clears cloudModel when saved null', () async {
      await _withBox((Box<dynamic> box) async {
        final SettingsRepository repo = HiveSettingsRepository(box: box);

        await repo.save(custom);
        await repo.save(custom.copyWith(cloudModel: null));
        final AppSettings loaded = await repo.load();

        expect(loaded.cloudModel, isNull);
      });
    });

    test('HiveSettingsRepository stores no secret keys', () async {
      await _withBox((Box<dynamic> box) async {
        final SettingsRepository repo = HiveSettingsRepository(box: box);

        await repo.save(custom);

        expect(box.containsKey('cloud_api_key'), isFalse);
        expect(box.containsKey('cloudApiKey'), isFalse);
        expect(box.containsKey('hfToken'), isFalse);
      });
    });
  });
}

Future<void> _withBox(Future<void> Function(Box<dynamic> box) body) async {
  final Directory tempDir = Directory.systemTemp.createTempSync(
    'settings_repo_test',
  );
  Hive.init(tempDir.path);
  final Box<dynamic> box = await Hive.openBox<dynamic>(
    HiveSettingsRepository.boxName,
  );
  try {
    await body(box);
  } finally {
    await box.close();
    tempDir.deleteSync(recursive: true);
  }
}
