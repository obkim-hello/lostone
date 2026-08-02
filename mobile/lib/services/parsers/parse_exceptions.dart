import '../../models/message.dart';

/// 解析致命错误。
class ParseException implements Exception {
  /// 创建解析异常。
  ParseException(this.source, this.message, {this.details});

  /// 出错的数据源。
  final DataSource source;

  /// 错误摘要。
  final String message;

  /// 可选详情。
  final String? details;

  @override
  String toString() =>
      'ParseException(${source.name}): $message${details != null ? ' - $details' : ''}';
}

/// 整体导入失败（所有文件均未产出任何消息时由 `DataImportService` 抛出）。
class ImportException implements Exception {
  /// 创建一个导入异常。
  ImportException(this.message);

  /// 错误摘要。
  final String message;

  @override
  String toString() => 'ImportException: $message';
}
