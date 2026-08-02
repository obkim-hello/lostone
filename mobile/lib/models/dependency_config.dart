/// 依赖包配置。
///
/// 描述一个项目依赖及其版本约束与依赖类型。
class DependencyConfig {
  /// 创建一个依赖包配置。
  ///
  /// 参数：
  /// - [name]：包名。
  /// - [version]：版本约束。
  /// - [isDevDependency]：是否为开发依赖，默认为 false。
  const DependencyConfig({
    required this.name,
    required this.version,
    this.isDevDependency = false,
  });

  /// 包名。
  final String name;

  /// 版本约束。
  final String version;

  /// 是否为开发依赖。
  final bool isDevDependency;
}
