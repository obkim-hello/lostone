import 'dart:io';

import '../models/conversation.dart';
import '../models/message.dart';
import '../models/parse_result.dart';
import '../utils/app_logger.dart';
import 'data_preprocessor.dart';
import 'parser_registry.dart';
import 'parsers/data_parser.dart';
import 'parsers/parse_exceptions.dart';

/// 数据导入编排服务：导入源 → 解析 → 预处理 → 标准化会话。
class DataImportService {
  /// 创建导入服务。可注入自定义注册表/预处理器（便于测试）。
  DataImportService({
    ParserRegistry? registry,
    DataPreprocessor preprocessor = const DataPreprocessor(),
  })  : _registry = registry ?? ParserRegistry(),
        _preprocessor = preprocessor;

  static const String _tag = 'DataImportService';
  static const int _maxFileBytes = 200 * 1024 * 1024;

  final ParserRegistry _registry;
  final DataPreprocessor _preprocessor;

  /// 导入一个或多个文件并产出标准化会话。
  ///
  /// 单文件解析失败会被隔离为告警，不中断整体流程；仅当所有文件均无法
  /// 解析时抛出 [ImportException]。
  ///
  /// 抛出：
  /// - [ArgumentError]：当 [filePaths] 为空。
  /// - [ImportException]：当所有文件均无法解析。
  Future<Conversation> importFiles(
    List<String> filePaths, {
    DataSource? source,
    ParseOptions options = const ParseOptions(),
  }) async {
    if (filePaths.isEmpty) {
      throw ArgumentError.value(filePaths, 'filePaths', 'must not be empty');
    }
    final List<Message> parsed = <Message>[];
    final List<MediaIndexEntry> mediaIndex = <MediaIndexEntry>[];
    final List<ParseWarning> warnings = <ParseWarning>[];
    int parsedFiles = 0;
    for (final String path in filePaths) {
      final ParseResult? result =
          await _parseOne(path, warnings, source: source, options: options);
      if (result == null) {
        continue;
      }
      parsedFiles++;
      parsed.addAll(result.messages);
      mediaIndex.addAll(result.mediaIndex);
      warnings.addAll(result.warnings);
    }
    if (parsedFiles == 0) {
      throw ImportException('No importable data found in the selected files');
    }
    final ({List<Message> messages, int skipped}) result =
        _preprocessor.process(parsed);
    return _assemble(
      result.messages,
      parsed.length,
      result.skipped,
      source,
      mediaIndex,
      warnings,
    );
  }

  Future<ParseResult?> _parseOne(
    String path,
    List<ParseWarning> warnings, {
    required DataSource? source,
    required ParseOptions options,
  }) async {
    final File file = File(path);
    if (!file.existsSync()) {
      warnings.add(const ParseWarning('file_not_found', 'file not found'));
      AppLogger.warning(_tag, 'file not found, skipped');
      return null;
    }
    if (file.lengthSync() > _maxFileBytes) {
      warnings.add(
        const ParseWarning('file_too_large', 'file exceeds size limit'),
      );
      AppLogger.warning(_tag, 'file too large, skipped');
      return null;
    }
    try {
      final DataParser? parser = await _registry.match(path, source: source);
      if (parser == null) {
        warnings.add(const ParseWarning('no_parser', 'no parser matched'));
        AppLogger.warning(_tag, 'no parser matched, skipped');
        return null;
      }
      final ParseResult result = await parser.parseAll(path, options: options);
      AppLogger.info(
        _tag,
        'parsed ${result.messages.length} msgs, '
        '${result.warnings.length} warnings',
      );
      return result;
    } on Exception catch (e) {
      warnings.add(
        ParseWarning('parse_failed', 'parse failed: ${e.runtimeType}'),
      );
      AppLogger.warning(_tag, 'parse failed (${e.runtimeType}), skipped');
      return null;
    }
  }

  Conversation _assemble(
    List<Message> messages,
    int totalParsed,
    int skipped,
    DataSource? source,
    List<MediaIndexEntry> mediaIndex,
    List<ParseWarning> warnings,
  ) {
    final List<String> participants = <String>[];
    final Set<String> seen = <String>{};
    for (final Message m in messages) {
      if (seen.add(m.senderName)) {
        participants.add(m.senderName);
      }
    }
    final ImportStats stats = ImportStats(
      totalParsed: totalParsed,
      afterDedup: messages.length,
      skipped: skipped,
      earliest: messages.isEmpty ? null : messages.first.timestamp,
      latest: messages.isEmpty ? null : messages.last.timestamp,
    );
    return Conversation(
      source: source ??
          (messages.isEmpty ? DataSource.unknown : messages.first.source),
      participants: participants,
      messages: messages,
      stats: stats,
      mediaIndex: mediaIndex,
      warnings: warnings,
    );
  }
}
