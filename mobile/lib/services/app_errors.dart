/// 应用初始化失败时抛出的异常。
class InitializationError implements Exception {
  /// 创建一个初始化错误。
  ///
  /// 参数：
  /// - [message]：错误摘要。
  /// - [details]：可选的详细信息。
  InitializationError(this.message, {this.details});

  /// 错误摘要。
  final String message;

  /// 可选的详细信息。
  final String? details;

  @override
  String toString() =>
      'InitializationError: $message${details != null ? ' - $details' : ''}';
}

/// 环境检查失败时抛出的异常。
class EnvironmentError implements Exception {
  /// 创建一个环境检查错误。
  ///
  /// 参数：
  /// - [errors]：导致失败的错误列表。
  EnvironmentError(this.errors);

  /// 导致失败的错误列表。
  final List<String> errors;

  @override
  String toString() =>
      'EnvironmentError:\n${errors.map((String e) => '  - $e').join('\n')}';
}
