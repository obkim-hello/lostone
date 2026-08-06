/// Hugging Face token 存储（ERD §4；生产经 Flutter Secure Storage）。
///
/// 受限模型下载时读取；日志脱敏、不落明文到普通存储。宿主测试用
/// [InMemoryTokenStore]。
abstract class TokenStore {
  /// 读取已保存 token；未设置返回 null。
  Future<String?> read();

  /// 保存 token。
  Future<void> write(String token);

  /// 清除 token。
  Future<void> clear();
}

/// 内存态 token 存储（宿主测试用）。
class InMemoryTokenStore implements TokenStore {
  /// 创建内存 token 存储，可给定初始值。
  InMemoryTokenStore({String? initial}) : _token = initial;

  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}
