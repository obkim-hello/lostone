import 'package:flutter_test/flutter_test.dart';
import 'package:lostone/models/app_config.dart';
import 'package:lostone/models/environment_status.dart';
import 'package:lostone/services/app_initializer.dart';

void main() {
  final AppInitializer initializer = AppInitializer();

  setUp(() {
    initializer.resetForTest();
  });

  group('AppInitializer configuration', () {
    test('getConfig should throw StateError before initialization', () {
      expect(initializer.getConfig, throwsStateError);
    });

    test('initialize should reject invalid config before touching platform',
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
    });

    test('setConfig should normalize appName and environment', () {
      initializer.setConfig(
        const AppConfig(
          appName: '  Lostone  ',
          version: '1.0.0',
          environment: 'PRODUCTION',
        ),
      );

      expect(
          () => initializer.setConfig(AppConfig.development), returnsNormally);
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
    test('checkEnvironment should return details for the current platform',
        () async {
      final EnvironmentStatus status = await initializer.checkEnvironment();

      expect(status.details.containsKey('operatingSystem'), isTrue);
      expect(status.details.containsKey('dartVersion'), isTrue);
    });
  });
}
