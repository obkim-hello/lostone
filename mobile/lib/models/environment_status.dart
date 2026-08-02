/// 环境检查结果。
///
/// 由 `checkEnvironment` 返回，描述开发/运行环境是否满足要求。
class EnvironmentStatus {
  /// 创建一个环境检查结果。
  ///
  /// 参数：
  /// - [isValid]：环境是否有效。
  /// - [errors]：错误列表，默认为空。
  /// - [warnings]：警告列表，默认为空。
  /// - [details]：附加的详细信息，默认为空。
  const EnvironmentStatus({
    required this.isValid,
    this.errors = const <String>[],
    this.warnings = const <String>[],
    this.details = const <String, String>{},
  });

  /// 环境是否有效。
  final bool isValid;

  /// 错误列表（当 [isValid] 为 false 时说明失败原因）。
  final List<String> errors;

  /// 警告列表（不影响有效性，但需要关注）。
  final List<String> warnings;

  /// 环境的详细信息，例如平台与版本号。
  final Map<String, String> details;
}
