import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/app_config.dart';
import '../models/environment_status.dart';
import '../utils/app_logger.dart';
import 'app_errors.dart';

/// Hive 中用于存放应用元数据的 Box 名称。
const String kAppConfigBoxName = 'lostone';

/// 项目要求的最低 Dart SDK 版本（运行时可校验的部分）。
///
/// Flutter SDK 版本由 `pubspec.yaml` 的 `environment.flutter` 约束在
/// 构建期强制，运行期无法可靠读取，故此处校验 Dart SDK 版本。
const String kMinDartSdkVersion = '3.0.0';

/// 存储层初始化回调。
///
/// 默认实现会初始化 Hive、打开配置 Box 并预热 Secure Storage；
/// 测试可注入替身以避免依赖平台通道。
typedef StorageInitializer = Future<void> Function();

/// 应用初始化管理器（单例）。
///
/// 负责按顺序校验环境、初始化 Hive、Secure Storage 并加载应用配置，
/// 保证初始化流程只执行一次。
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
  /// 流程：校验配置 → 校验环境 → 初始化存储层 → 加载配置。
  /// 若已初始化则忽略并直接返回（幂等）。
  ///
  /// 参数：
  /// - [config]：应用配置，缺省为 [AppConfig.development]。
  /// - [storageInitializer]：存储层初始化回调，缺省为真实实现，
  ///   仅用于测试注入替身。
  /// - [dartSdkVersion]：Dart 版本字符串，缺省读取 `Platform.version`，
  ///   仅用于测试注入。
  ///
  /// 抛出：
  /// - [ArgumentError]：当 [config] 校验失败。
  /// - [EnvironmentError]：当运行环境不满足要求。
  /// - [InitializationError]：当存储层初始化失败。
  Future<void> initialize({
    AppConfig? config,
    StorageInitializer? storageInitializer,
    String? dartSdkVersion,
  }) async {
    if (_initialized) {
      AppLogger.info(_tag, 'Already initialized; ignoring re-initialization');
      return;
    }

    final AppConfig normalized = _normalize(config ?? _config);
    if (!normalized.validate()) {
      throw ArgumentError.value(config, 'config', 'Invalid application config');
    }

    final EnvironmentStatus status = await checkEnvironment(
      dartSdkVersion: dartSdkVersion,
    );
    if (!status.isValid) {
      throw EnvironmentError(status.errors);
    }

    try {
      await (storageInitializer ?? _defaultStorageInitializer)();
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
  /// 校验 Dart SDK 版本是否达到 [kMinDartSdkVersion]，并收集平台信息。
  ///
  /// 参数：
  /// - [dartSdkVersion]：Dart 版本字符串，缺省读取 `Platform.version`，
  ///   仅用于测试注入。
  ///
  /// 返回描述平台、版本与潜在问题的 [EnvironmentStatus]。
  Future<EnvironmentStatus> checkEnvironment({String? dartSdkVersion}) async {
    final List<String> errors = <String>[];
    final List<String> warnings = <String>[];
    final String rawVersion = dartSdkVersion ?? Platform.version;
    final List<int>? detected = _parseSemanticVersion(rawVersion);
    final List<int> required = _parseSemanticVersion(kMinDartSdkVersion)!;

    final Map<String, String> details = <String, String>{
      'operatingSystem': Platform.operatingSystem,
      'operatingSystemVersion': Platform.operatingSystemVersion,
      'dartVersion': rawVersion,
      'minDartSdk': kMinDartSdkVersion,
    };

    if (detected == null) {
      warnings.add('Unable to determine Dart SDK version from "$rawVersion"');
    } else if (_isLower(detected, required)) {
      errors.add(
        'Dart SDK version ${detected.join('.')} is too low, '
        'required >= $kMinDartSdkVersion',
      );
    }

    if (!(Platform.isIOS || Platform.isMacOS || Platform.isAndroid)) {
      warnings.add('Running on an unsupported platform for release');
    }

    return EnvironmentStatus(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      details: details,
    );
  }

  /// 仅用于测试：读取当前配置（无需初始化）。
  @visibleForTesting
  AppConfig get configForTest => _config;

  /// 仅用于测试：重置初始化状态。
  @visibleForTesting
  void resetForTest() {
    _initialized = false;
    _config = AppConfig.development;
  }

  Future<void> _defaultStorageInitializer() async {
    await Hive.initFlutter();
    await Hive.openBox<dynamic>(kAppConfigBoxName);
    await const FlutterSecureStorage().readAll();
  }

  AppConfig _normalize(AppConfig config) {
    return AppConfig(
      appName: config.appName.trim(),
      version: config.version,
      environment: config.environment.toLowerCase(),
      isDebug: config.isDebug,
    );
  }

  List<int>? _parseSemanticVersion(String value) {
    final RegExpMatch? match = RegExp(r'(\d+)\.(\d+)\.(\d+)').firstMatch(value);
    if (match == null) {
      return null;
    }
    return <int>[
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    ];
  }

  bool _isLower(List<int> actual, List<int> minimum) {
    for (int i = 0; i < minimum.length; i++) {
      if (actual[i] != minimum[i]) {
        return actual[i] < minimum[i];
      }
    }
    return false;
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
/// - [EnvironmentError]：当运行环境不满足要求。
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
/// 参数：
/// - [dartSdkVersion]：Dart 版本字符串，缺省读取 `Platform.version`。
///
/// 返回 [EnvironmentStatus]。
Future<EnvironmentStatus> checkEnvironment({String? dartSdkVersion}) =>
    AppInitializer().checkEnvironment(dartSdkVersion: dartSdkVersion);

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
