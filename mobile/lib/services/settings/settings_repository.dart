import 'package:hive/hive.dart';

import '../../models/app_settings.dart';

/// Persists non-secret [AppSettings] (ERD-010 §4.2 / SPEC-010 §2.2–2.3).
///
/// Secrets (cloud API key, HF token) are **never** handled here — they go
/// through the secure stores. [load] returns defaults when nothing is stored
/// and never throws for an empty store.
abstract class SettingsRepository {
  /// Returns the stored settings, or a default [AppSettings] if none exist.
  Future<AppSettings> load();

  /// Persists all four non-secret fields; a subsequent [load] returns an equal
  /// value.
  Future<void> save(AppSettings settings);
}

/// In-memory [SettingsRepository] for host tests (no Hive, no disk).
class InMemorySettingsRepository implements SettingsRepository {
  /// Creates a fake seeded with [initial] (defaults when omitted).
  InMemorySettingsRepository({AppSettings? initial}) : _settings = initial;

  AppSettings? _settings;

  @override
  Future<AppSettings> load() async => _settings ?? const AppSettings();

  @override
  Future<void> save(AppSettings settings) async => _settings = settings;
}

/// Hive-backed [SettingsRepository] (ERD-010 §4.3).
///
/// Stores one scalar per field in the `settings` box: `runtime` (enum name),
/// `cloudAuthorized` (bool), `activeModelId` (String?), `chatTemperature`
/// (double). Missing keys fall back to defaults. Contains no secret fields.
class HiveSettingsRepository implements SettingsRepository {
  /// Wraps an already-open Hive [box].
  HiveSettingsRepository({required Box<dynamic> box}) : _box = box;

  /// Default name of the Hive box holding settings scalars.
  static const String boxName = 'settings';

  static const String _kRuntime = 'runtime';
  static const String _kCloudAuthorized = 'cloudAuthorized';
  static const String _kActiveModelId = 'activeModelId';
  static const String _kChatTemperature = 'chatTemperature';

  final Box<dynamic> _box;

  @override
  Future<AppSettings> load() async {
    const AppSettings defaults = AppSettings();
    return AppSettings(
      runtime: _readRuntime(defaults.runtime),
      cloudAuthorized:
          _box.get(_kCloudAuthorized, defaultValue: defaults.cloudAuthorized)
              as bool,
      activeModelId: _box.get(_kActiveModelId) as String?,
      chatTemperature:
          (_box.get(_kChatTemperature, defaultValue: defaults.chatTemperature)
                  as num)
              .toDouble(),
    );
  }

  @override
  Future<void> save(AppSettings settings) async {
    await _box.putAll(<String, dynamic>{
      _kRuntime: settings.runtime.name,
      _kCloudAuthorized: settings.cloudAuthorized,
      _kChatTemperature: settings.chatTemperature,
    });
    if (settings.activeModelId == null) {
      await _box.delete(_kActiveModelId);
    } else {
      await _box.put(_kActiveModelId, settings.activeModelId);
    }
  }

  RuntimeChoice _readRuntime(RuntimeChoice fallback) {
    final Object? name = _box.get(_kRuntime);
    if (name is! String) {
      return fallback;
    }
    return RuntimeChoice.values.firstWhere(
      (RuntimeChoice c) => c.name == name,
      orElse: () => fallback,
    );
  }
}
