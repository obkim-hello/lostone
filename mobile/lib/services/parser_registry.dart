import '../models/message.dart';
import 'parsers/data_parser.dart';
import 'parsers/imessage_parser.dart';
import 'parsers/instagram_parser.dart';
import 'parsers/photo_exif_parser.dart';
import 'parsers/wechat_parser.dart';
import 'parsers/weibo_parser.dart';

/// 解析器注册与调度：按可选数据源 + `canParse` 探测选出解析器。
class ParserRegistry {
  /// 创建注册表。未提供时注册默认解析器集合。
  ParserRegistry([List<DataParser>? parsers])
      : _parsers = parsers ??
            <DataParser>[
              const WeChatParser(),
              const InstagramParser(),
              const WeiboParser(),
              const IMessageParser(),
              const PhotoExifParser(),
            ];

  final List<DataParser> _parsers;

  /// 根据文件与可选数据源选出解析器；无匹配返回 null。
  ///
  /// 指定 [source] 时仅在该数据源的解析器中匹配。
  Future<DataParser?> match(String filePath, {DataSource? source}) async {
    for (final DataParser parser in _parsers) {
      if (source != null && parser.source != source) {
        continue;
      }
      if (await parser.canParse(filePath)) {
        return parser;
      }
    }
    return null;
  }
}
