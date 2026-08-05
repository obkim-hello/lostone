import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'token_store.dart';

/// 生产 [TokenStore]：Hugging Face token 经 Flutter Secure Storage 加密落盘。
///
/// 日志脱敏，不输出完整 token（安全要求）。
class SecureTokenStore implements TokenStore {
  /// 创建加密 token 存储，可注入自定义 [storage]。
  SecureTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _key = 'hf_token';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}
