import 'package:flutter/foundation.dart';

/// 日志级别。
enum LogLevel {
  /// 开发调试信息。
  debug,

  /// 关键运行信息。
  info,

  /// 警告信息。
  warning,

  /// 错误信息。
  error,
}

/// 轻量级日志工具。
///
/// 在调试模式下输出结构化日志，生产环境仅输出 warning 及以上级别，
/// 避免泄露敏感信息。
class AppLogger {
  const AppLogger._();

  /// 输出一条调试日志。
  static void debug(String tag, String message) =>
      _log(LogLevel.debug, tag, message);

  /// 输出一条信息日志。
  static void info(String tag, String message) =>
      _log(LogLevel.info, tag, message);

  /// 输出一条警告日志。
  static void warning(String tag, String message) =>
      _log(LogLevel.warning, tag, message);

  /// 输出一条错误日志。
  static void error(String tag, String message) =>
      _log(LogLevel.error, tag, message);

  static void _log(LogLevel level, String tag, String message) {
    final bool isVerboseLevel =
        level == LogLevel.debug || level == LogLevel.info;
    if (!kDebugMode && isVerboseLevel) {
      return;
    }
    debugPrint('[${level.name.toUpperCase()}] [$tag] $message');
  }
}
