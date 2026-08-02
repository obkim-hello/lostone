import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/app_config.dart';
import '../models/environment_status.dart';
import 'app_errors.dart';
import '../utils/app_logger.dart';

/// Hive 中用于存放应用元数据的 Box 名称。
const String kAppConfigBoxName = 'lostone';

/// 应用初始化管理器（单例）。
///
/// 负责按顺序初始化 Hive、Secure Storage 并加载应用配置，保证
/// 初始化流程只执行一次。
///
/// 示例：
/// ```dart
/// final initializer = AppInitializer();
/// await initializer.initialize();
/// ```
class AppInitializer {
  AppInitializer._internal();

  /// 返回全局唯一的初始化器实例。
  factory AppInitializer() => _instance;

  static final AppInitializer _instance = AppInitializer._internal();

  static const String _tag = 'AppInitializer';

  bool _initialized = false;
  AppConfig _config = AppConfig.development;

  /// 当前初始化流程是否已完成。
  bool get isInitialized => _initialized;

  /// 初始化应用所需的全部依赖。
  ///
  /// 参数：
  /// - [config]：应用配置，缺省为 [AppConfig.development]。
  ///
  /// 抛出：
  /// - [ArgumentError]：当 [config] 校验失败。
  /// - [InitializationError]：当依赖初始化失败。
  Future<void> initialize({AppConfig? config}) async {
    final AppConfig normalized = _normalize(config ?? _config);
    if (!normalized.validate()) {
      throw ArgumentError.value(config, 'config', 'Invalid application config');
    }

    if (_initialized) {
      _config = normalized;
      AppLogger.info(_tag, 'Already initialized; config updated');
      return;
    }

    try {
      await Hive.initFlutter();
      await Hive.openBox<dynamic>(kAppConfigBoxName);
      await const FlutterSecureStorage().readAll();
      _config = normalized;
      _initialized = true;
      AppLogger.info(_tag, 'Application initialized successfully');
    } on Exception catch (e) {
      throw InitializationError(
        'Failed to initialize application',
        details: e.toString(),
      );
    }
  }

  /// 返回当前应用配置。
  ///
  /// 抛出：
  /// - [StateError]：当尚未完成初始化。
  AppConfig getConfig() {
    if (!_initialized) {
      throw StateError('AppInitializer has not been initialized');
    }
    return _config;
  }

  /// 在运行时更新应用配置。
  ///
  /// 参数：
  /// - [config]：新的配置，将被规范化并校验。
  ///
  /// 抛出：
  /// - [ArgumentError]：当 [config] 校验失败。
  void setConfig(AppConfig config) {
    final AppConfig normalized = _normalize(config);
    if (!normalized.validate()) {
      throw ArgumentError.value(config, 'config', 'Invalid application config');
    }
    _config = normalized;
  }

  /// 检查运行环境是否满足要求。
  ///
  /// 返回描述平台、版本与潜在问题的 [EnvironmentStatus]。
  Future<EnvironmentStatus> checkEnvironment() async {
    final List<String> errors = <String>[];
    final List<String> warnings = <String>[];
    final Map<String, String> details = <String, String>{
      'operatingSystem': Platform.operatingSystem,
      'operatingSystemVersion': Platform.operatingSystemVersion,
      'dartVersion': Platform.version,
    };

    if (Platform.isIOS || Platform.isMacOS || Platform.isAndroid) {
      AppLogger.debug(
          _tag, 'Environment platform: ${Platform.operatingSystem}');
    } else {
      warnings.add('Running on an unsupported desktop platform for release');
    }

    return EnvironmentStatus(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      details: details,
    );
  }

  /// 仅用于测试：重置初始化状态。
  @visibleForTesting
  void resetForTest() {
    _initialized = false;
    _config = AppConfig.development;
  }

  AppConfig _normalize(AppConfig config) {
    return AppConfig(
      appName: config.appName.trim(),
      version: config.version,
      environment: config.environment.toLowerCase(),
      isDebug: config.isDebug,
    );
  }
}

/// 初始化 Flutter 应用。
///
/// 内部委托给 [AppInitializer] 单例。
///
/// 参数：
/// - [config]：应用配置，缺省为 [AppConfig.development]。
///
/// 抛出：
/// - [ArgumentError]：当 [config] 校验失败。
/// - [InitializationError]：当依赖初始化失败。
///
/// 示例：
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await initializeApp();
///   runApp(const LostoneApp());
/// }
/// ```
Future<void> initializeApp({AppConfig? config}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppInitializer().initialize(config: config);
}

/// 检查开发/运行环境是否符合要求。
///
/// 返回 [EnvironmentStatus]。
Future<EnvironmentStatus> checkEnvironment() =>
    AppInitializer().checkEnvironment();

/// 获取当前应用配置。
///
/// 抛出：
/// - [StateError]：当尚未完成初始化。
AppConfig getAppConfig() => AppInitializer().getConfig();

/// 在运行时设置应用配置。
///
/// 参数：
/// - [config]：新的配置。
void setAppConfig(AppConfig config) => AppInitializer().setConfig(config);
