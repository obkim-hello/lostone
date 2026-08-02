/// 应用配置模型。
///
/// 存储应用的全局配置信息，包含应用名称、版本、运行环境和调试标志。
///
/// 示例：
/// ```dart
/// const config = AppConfig.development;
/// print(config.environment); // development
/// ```
class AppConfig {
  /// 创建一个应用配置。
  ///
  /// 参数：
  /// - [appName]：应用名称，长度 1-50。
  /// - [version]：版本号，格式 X.Y.Z。
  /// - [environment]：运行环境（development/staging/production）。
  /// - [isDebug]：是否启用调试模式，默认为 false。
  const AppConfig({
    required this.appName,
    required this.version,
    required this.environment,
    this.isDebug = false,
  });

  /// 从 JSON 反序列化生成 [AppConfig]。
  factory AppConfig.fromJson(Map<String, dynamic> json) => AppConfig(
    appName: json['appName'] as String,
    version: json['version'] as String,
    environment: json['environment'] as String,
    isDebug: json['isDebug'] as bool? ?? false,
  );

  /// 应用名称。
  final String appName;

  /// 应用版本，遵循语义化版本格式 X.Y.Z。
  final String version;

  /// 运行环境（development/staging/production）。
  final String environment;

  /// 是否启用调试模式。
  final bool isDebug;

  /// 允许的运行环境枚举值。
  static const List<String> allowedEnvironments = <String>[
    'development',
    'staging',
    'production',
  ];

  /// 默认的开发环境配置。
  static const AppConfig development = AppConfig(
    appName: 'Lostone',
    version: '0.1.0',
    environment: 'development',
    isDebug: true,
  );

  /// 默认的生产环境配置。
  static const AppConfig production = AppConfig(
    appName: 'Lostone',
    version: '0.1.0',
    environment: 'production',
  );

  /// 校验配置是否合法。
  ///
  /// 返回 true 表示 [appName]、[version]、[environment] 均满足约束。
  bool validate() {
    return appName.isNotEmpty &&
        appName.length <= 50 &&
        RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version) &&
        allowedEnvironments.contains(environment);
  }

  /// 序列化为 JSON。
  Map<String, dynamic> toJson() => <String, dynamic>{
    'appName': appName,
    'version': version,
    'environment': environment,
    'isDebug': isDebug,
  };
}
