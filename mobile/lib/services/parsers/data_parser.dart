import '../../models/message.dart';
import '../../models/parse_result.dart';

/// 数据源解析器的统一接口。
///
/// 每个数据源实现一个 [DataParser]；`ParserRegistry` 负责调度。
abstract interface class DataParser {
  /// 本解析器对应的数据源。
  DataSource get source;

  /// 快速判断是否能解析给定文件（基于扩展名/魔数/结构探测）。
  Future<bool> canParse(String filePath);

  /// **流式**解析文件，逐条产出 [ParseEvent]：
  /// [MessageEvent]（消息）、[MediaIndexEvent]（媒体索引）、[WarningEvent]（告警）。
  ///
  /// 每条媒体类消息同时产出一个 [MediaIndexEvent]（`storedPath` 恒为 null）；
  /// 字节落地由下游 `MediaStore` 负责。峰值内存必须与文件大小解耦
  /// （不得全量载入 DOM/字节）。
  ///
  /// 抛出：
  /// - `ParseException`：当文件无法解析（致命，通常在首个事件前）。
  Stream<ParseEvent> parse(
    String filePath, {
    ParseOptions options = const ParseOptions(),
  });

  /// 便捷方法：排空 [parse] 流为 [ParseResult]。仅供小文件/测试使用。
  Future<ParseResult> parseAll(
    String filePath, {
    ParseOptions options = const ParseOptions(),
  });
}
