import 'dart:io';

import 'package:exif/exif.dart';
import 'package:path/path.dart' as p;

import '../../models/message.dart';
import '../../models/parse_result.dart';
import 'data_parser.dart';

/// 照片 EXIF 解析器：将单张照片的拍摄时间（及可选 GPS）归一为一条消息。
///
/// 读取 `EXIF DateTimeOriginal` 作为时间戳；缺失则产出 `missing_exif` 告警
/// 并跳过该照片（见 SPEC §5 边界表）。`ParseOptions.extractLocation` 为
/// true 时**显式解析 GPS IFD**（`GPSLatitude`/`GPSLongitude` + 参考方向），
/// 换算十进制经纬度写入 `Message.metadata`（`latitude`/`longitude`）。
///
/// 系统级定位授权由调用方保证：`extractLocation` 应仅在已授权时为 true
/// （见 SPEC ParseOptions 验证规则）；照片本身无 GPS 时静默不写入。
///
/// 照片文件即媒体：`Message.mediaPath` 与 `MediaIndexEntry.sourceRef` 均为
/// 传入文件路径，`available` 恒真（字节可读）。
///
/// 稳健性：损坏/截断的图片可能令底层 `exif` 解码抛 `RangeError`（`Error`
/// 而非 `Exception`），故本解析器兜底捕获任意失败并降级为 `corrupt_photo`
/// 告警跳过该文件，绝不让异常逃逸中断整批导入。
class PhotoExifParser implements DataParser {
  /// 创建照片 EXIF 解析器。
  const PhotoExifParser();

  @override
  DataSource get source => DataSource.photo;

  @override
  Future<bool> canParse(String filePath) async {
    if (!_supportedExtensions.contains(p.extension(filePath).toLowerCase())) {
      return false;
    }
    return File(filePath).existsSync();
  }

  @override
  Stream<ParseEvent> parse(
    String filePath, {
    ParseOptions options = const ParseOptions(),
  }) async* {
    Map<String, IfdTag> tags;
    try {
      final List<int> bytes = await File(filePath).readAsBytes();
      tags = await readExifFromBytes(bytes);
    } on Object catch (e) {
      yield WarningEvent(
        ParseWarning(
          'corrupt_photo',
          'unreadable photo (${e.runtimeType}): ${p.basename(filePath)}',
        ),
      );
      return;
    }
    final DateTime? timestamp =
        _parseExifDateTime(tags['EXIF DateTimeOriginal']?.printable);
    if (timestamp == null) {
      yield WarningEvent(
        ParseWarning(
          'missing_exif',
          'photo lacks EXIF DateTimeOriginal: ${p.basename(filePath)}',
        ),
      );
      return;
    }
    final Map<String, dynamic> metadata = <String, dynamic>{};
    if (options.extractLocation) {
      final double? latitude =
          _gpsDecimal(tags, 'GPS GPSLatitude', 'GPS GPSLatitudeRef');
      final double? longitude =
          _gpsDecimal(tags, 'GPS GPSLongitude', 'GPS GPSLongitudeRef');
      if (latitude != null && longitude != null) {
        metadata['latitude'] = latitude;
        metadata['longitude'] = longitude;
      }
    }
    yield MessageEvent(
      Message(
        id: 'photo-${p.basename(filePath)}',
        source: DataSource.photo,
        senderId: 'me',
        senderName: 'me',
        isFromMe: true,
        timestamp: timestamp,
        type: MessageType.image,
        content: '[照片]',
        mediaPath: filePath,
        metadata: metadata,
      ),
    );
    yield MediaIndexEvent(
      MediaIndexEntry(
        source: DataSource.photo,
        senderId: 'me',
        timestamp: timestamp,
        type: MessageType.image,
        sourceRef: filePath,
        available: true,
      ),
    );
  }

  @override
  Future<ParseResult> parseAll(
    String filePath, {
    ParseOptions options = const ParseOptions(),
  }) async {
    final List<Message> messages = <Message>[];
    final List<MediaIndexEntry> mediaIndex = <MediaIndexEntry>[];
    final List<ParseWarning> warnings = <ParseWarning>[];
    await for (final ParseEvent event in parse(filePath, options: options)) {
      switch (event) {
        case MessageEvent():
          messages.add(event.message);
        case MediaIndexEvent():
          mediaIndex.add(event.entry);
        case WarningEvent():
          warnings.add(event.warning);
      }
    }
    return ParseResult(
      messages: messages,
      mediaIndex: mediaIndex,
      warnings: warnings,
    );
  }
}

const Set<String> _supportedExtensions = <String>{
  '.jpg',
  '.jpeg',
  '.heic',
  '.heif',
  '.tif',
  '.tiff',
  '.png',
};

DateTime? _parseExifDateTime(String? raw) {
  if (raw == null) {
    return null;
  }
  final List<String> parts = raw.trim().split(' ');
  if (parts.length != 2) {
    return null;
  }
  final List<String> date = parts[0].split(':');
  final List<String> time = parts[1].split(':');
  if (date.length != 3 || time.length != 3) {
    return null;
  }
  final int? year = int.tryParse(date[0]);
  final int? month = int.tryParse(date[1]);
  final int? day = int.tryParse(date[2]);
  final int? hour = int.tryParse(time[0]);
  final int? minute = int.tryParse(time[1]);
  final int? second = int.tryParse(time[2]);
  if (year == null ||
      month == null ||
      day == null ||
      hour == null ||
      minute == null ||
      second == null ||
      year == 0 ||
      month < 1 ||
      month > 12 ||
      day < 1 ||
      day > 31 ||
      hour > 23 ||
      minute > 59 ||
      second > 59) {
    return null;
  }
  return DateTime(year, month, day, hour, minute, second);
}

double? _gpsDecimal(Map<String, IfdTag> tags, String valueKey, String refKey) {
  final IfdValues? values = tags[valueKey]?.values;
  if (values is! IfdRatios || values.ratios.length < 3) {
    return null;
  }
  final double degrees = values.ratios[0].toDouble();
  final double minutes = values.ratios[1].toDouble();
  final double seconds = values.ratios[2].toDouble();
  final double decimal = degrees + minutes / 60.0 + seconds / 3600.0;
  if (decimal.isNaN || decimal.isInfinite) {
    return null;
  }
  final String ref = tags[refKey]?.printable.trim().toUpperCase() ?? '';
  if (ref == 'S' || ref == 'W') {
    return -decimal;
  }
  return decimal;
}
