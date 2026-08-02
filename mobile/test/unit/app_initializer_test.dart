import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lostone/models/app_config.dart';
import 'package:lostone/models/environment_status.dart';
import 'package:lostone/services/app_errors.dart';
import 'package:lostone/services/app_initializer.dart';

void main() {
  final AppInitializer initializer = AppInitializer();

  setUp(() {
    initializer.resetForTest();
  });

  group('AppInitializer initialization', () {
    test(
      'should initialize with default config and open the config box',
      () async {
        final Directory tempDir = Directory.systemTemp.createTempSync(
          'lostone_test',
        );
        addTearDown(() => tempDir.deleteSync(recursive: true));

        await initializer.initialize(
          storageInitializer: () async {
            Hive.init(tempDir.path);
            await Hive.openBox<dynamic>(kAppConfigBoxName);
          },
        );

        expect(initializer.isInitialized, isTrue);
        expect(Hive.isBoxOpen(kAppConfigBoxName), isTrue);

        await Hive.box<dynamic>(kAppConfigBoxName).close();
      },
    );

    test('should load and normalize a custom config after init', () async {
      final Directory tempDir = Directory.systemTemp.createTempSync(
        'lostone_test',
      );
      addTearDown(() => tempDir.deleteSync(recursive: true));

      await initializer.initialize(
        config: const AppConfig(
          appName: '  Lostone  ',
          version: '1.2.3',
          environment: 'PRODUCTION',
        ),
        storageInitializer: () async {
          Hive.init(tempDir.path);
          await Hive.openBox<dynamic>(kAppConfigBoxName);
        },
      );

      final AppConfig loaded = initializer.getConfig();
      expect(loaded.appName, equals('Lostone'));
      expect(loaded.environment, equals('production'));
      expect(loaded.version, equals('1.2.3'));

      await Hive.box<dynamic>(kAppConfigBoxName).close();
    });

    test('should throw InitializationError when storage init fails', () async {
      await expectLater(
        initializer.initialize(
          storageInitializer: () async => throw Exception('disk full'),
        ),
        throwsA(isA<InitializationError>()),
      );
      expect(initializer.isInitialized, isFalse);
    });

    test('should be idempotent and ignore re-initialization', () async {
      final Directory tempDir = Directory.systemTemp.createTempSync(
        'lostone_test',
      );
      addTearDown(() => tempDir.deleteSync(recursive: true));

      Future<void> storageInit() async {
        Hive.init(tempDir.path);
        await Hive.openBox<dynamic>(kAppConfigBoxName);
      }

      await initializer.initialize(
        config: AppConfig.production,
        storageInitializer: storageInit,
      );
      await initializer.initialize(
        config: AppConfig.development,
        storageInitializer: storageInit,
      );

      expect(initializer.getConfig().environment, equals('production'));

      await Hive.box<dynamic>(kAppConfigBoxName).close();
    });
  });

  group('AppInitializer configuration', () {
    test('getConfig should throw StateError before initialization', () {
      expect(initializer.getConfig, throwsStateError);
    });

    test(
      'initialize should reject invalid config before touching storage',
      () async {
        const AppConfig invalid = AppConfig(
          appName: '',
          version: 'invalid',
          environment: 'unknown',
        );

        await expectLater(
          initializer.initialize(config: invalid),
          throwsArgumentError,
        );
        expect(initializer.isInitialized, isFalse);
      },
    );

    test('setConfig should normalize appName and environment', () {
      initializer.setConfig(
        const AppConfig(
          appName: '  Lostone  ',
          version: '1.0.0',
          environment: 'PRODUCTION',
        ),
      );

      expect(initializer.configForTest.appName, equals('Lostone'));
      expect(initializer.configForTest.environment, equals('production'));
    });

    test('setConfig should reject invalid config', () {
      expect(
        () => initializer.setConfig(
          const AppConfig(
            appName: 'App',
            version: 'x.y.z',
            environment: 'development',
          ),
        ),
        throwsArgumentError,
      );
    });
  });

  group('AppInitializer environment', () {
    test('checkEnvironment should be valid on the current platform', () async {
      final EnvironmentStatus status = await initializer.checkEnvironment();

      expect(status.isValid, isTrue);
      expect(status.errors, isEmpty);
      expect(status.details.containsKey('operatingSystem'), isTrue);
      expect(status.details.containsKey('dartVersion'), isTrue);
    });

    test('checkEnvironment should fail when the Dart SDK is too low', () async {
      final EnvironmentStatus status = await initializer.checkEnvironment(
        dartSdkVersion: '2.19.0',
      );

      expect(status.isValid, isFalse);
      expect(status.errors, isNotEmpty);
    });

    test(
      'initialize should throw EnvironmentError on a bad environment',
      () async {
        await expectLater(
          initializer.initialize(dartSdkVersion: '2.19.0'),
          throwsA(isA<EnvironmentError>()),
        );
        expect(initializer.isInitialized, isFalse);
      },
    );
  });
}
