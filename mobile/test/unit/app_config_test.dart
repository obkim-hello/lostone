import 'package:flutter_test/flutter_test.dart';
import 'package:lostone/models/app_config.dart';

void main() {
  group('AppConfig', () {
    test('should serialize to JSON correctly', () {
      final Map<String, dynamic> json = AppConfig.development.toJson();

      expect(json['appName'], equals('Lostone'));
      expect(json['environment'], equals('development'));
      expect(json['isDebug'], isTrue);
    });

    test('should deserialize from JSON correctly', () {
      final AppConfig config = AppConfig.fromJson(<String, dynamic>{
        'appName': 'Lostone',
        'version': '0.1.0',
        'environment': 'production',
        'isDebug': false,
      });

      expect(config.appName, equals('Lostone'));
      expect(config.environment, equals('production'));
      expect(config.isDebug, isFalse);
    });

    test('should default isDebug to false when missing in JSON', () {
      final AppConfig config = AppConfig.fromJson(<String, dynamic>{
        'appName': 'Lostone',
        'version': '0.1.0',
        'environment': 'staging',
      });

      expect(config.isDebug, isFalse);
    });

    test('should validate a well-formed config', () {
      expect(AppConfig.development.validate(), isTrue);
      expect(AppConfig.production.validate(), isTrue);
    });

    test('should reject empty appName', () {
      const AppConfig config = AppConfig(
        appName: '',
        version: '0.1.0',
        environment: 'development',
      );

      expect(config.validate(), isFalse);
    });

    test('should reject appName longer than 50 characters', () {
      final AppConfig config = AppConfig(
        appName: 'a' * 51,
        version: '0.1.0',
        environment: 'development',
      );

      expect(config.validate(), isFalse);
    });

    test('should reject invalid version format', () {
      const AppConfig config = AppConfig(
        appName: 'Lostone',
        version: 'invalid',
        environment: 'development',
      );

      expect(config.validate(), isFalse);
    });

    test('should reject unknown environment', () {
      const AppConfig config = AppConfig(
        appName: 'Lostone',
        version: '0.1.0',
        environment: 'unknown',
      );

      expect(config.validate(), isFalse);
    });
  });
}
