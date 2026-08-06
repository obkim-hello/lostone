import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypted store for the single cloud API key (ERD-010 §4 / §7).
///
/// Uses the same Flutter Secure Storage mechanism as Module 007's
/// `SecureTokenStore` (HF token), under the distinct key `cloud_api_key`. The
/// key is **never** part of [AppSettings], never written to Hive, and never
/// logged. Consumers (Modules 006/009/004) read it at call time via
/// `cloudKeyStoreProvider`.
abstract class SecureKeyStore {
  /// Reads the stored cloud API key; returns `null` when none is set.
  Future<String?> read();

  /// Persists [key] as the cloud API key.
  Future<void> write(String key);

  /// Removes the stored cloud API key.
  Future<void> clear();
}

/// In-memory [SecureKeyStore] for host tests (no secure storage, no disk).
class InMemorySecureKeyStore implements SecureKeyStore {
  /// Creates a fake seeded with [initial] (unset when omitted).
  InMemorySecureKeyStore({String? initial}) : _key = initial;

  String? _key;

  @override
  Future<String?> read() async => _key;

  @override
  Future<void> write(String key) async => _key = key;

  @override
  Future<void> clear() async => _key = null;
}

/// Production [SecureKeyStore]: cloud API key encrypted via Flutter Secure
/// Storage under `cloud_api_key`.
///
/// Log-safe: the value is never emitted.
class FlutterSecureKeyStore implements SecureKeyStore {
  /// Creates the encrypted store; an alternate [storage] may be injected.
  FlutterSecureKeyStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String _key = 'cloud_api_key';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String key) => _storage.write(key: _key, value: key);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}
