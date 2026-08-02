/// Apple 绝对时间的纳秒/秒分界阈值（1e12）。
///
/// `chat.db` 的 `message.date` 有两种单位：macOS 10.13 之前为秒，之后为纳秒
/// （均自 2001-01-01 UTC 起）。秒格式约 10^8~10^9，纳秒格式约 10^17~10^18，
/// 取 1e12 为分界，二者相差远超阈值，未来数十年内不会歧义。
const int kAppleNanoThreshold = 1000000000000;

/// 将 `chat.db` 的 Apple 绝对时间 [date] 转换为 UTC [DateTime]。
///
/// [date] 单位按 [kAppleNanoThreshold] 自动判定（秒或纳秒），基准为
/// 2001-01-01 UTC。展示层如需本地时区可再调用 `toLocal()`。
///
/// 示例：
/// ```dart
/// appleDateToDateTime(662688000000000000); // 2022-01-01T00:00:00Z
/// appleDateToDateTime(662688000);          // 2022-01-01T00:00:00Z
/// ```
DateTime appleDateToDateTime(int date) {
  final int seconds =
      date.abs() >= kAppleNanoThreshold ? date ~/ 1000000000 : date;
  return DateTime.utc(2001).add(Duration(seconds: seconds));
}
