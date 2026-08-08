import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_settings.dart';
import '../model/token_store.dart';
import 'secure_key_store.dart';
import 'settings_repository.dart';

/// Owns non-secret [AppSettings] and the cloud/HF secrets (ERD-010 §4 / §7).
///
/// State is [AppSettings] — secrets are **never** part of it. Their presence is
/// exposed only as [hasCloudKey] / [hasHfToken]. Non-secret mutations persist
/// via [SettingsRepository]; secrets write to the injected secure stores.
///
/// Every non-secret setter is optimistic: it updates [state] first (so the UI
/// reflects intent) and then persists. A persistence failure is surfaced via
/// [onSaveError] when provided, otherwise rethrown — it is never swallowed
/// (SPEC-010 E17 / C24).
class SettingsNotifier extends StateNotifier<AppSettings> {
  /// Creates a notifier over the given repository and secure stores.
  ///
  /// [onSaveError] is invoked with the thrown error when a [SettingsRepository]
  /// save fails; if omitted, the error is rethrown to the caller.
  SettingsNotifier({
    required SettingsRepository repository,
    required SecureKeyStore cloudKeyStore,
    required TokenStore hfTokenStore,
    void Function(Object error)? onSaveError,
  }) : _repository = repository,
       _cloudKeyStore = cloudKeyStore,
       _hfTokenStore = hfTokenStore,
       _onSaveError = onSaveError,
       super(const AppSettings());

  final SettingsRepository _repository;
  final SecureKeyStore _cloudKeyStore;
  final TokenStore _hfTokenStore;
  final void Function(Object error)? _onSaveError;

  bool _hasCloudKey = false;
  bool _hasHfToken = false;

  /// Whether a cloud API key is currently stored (never exposes the value).
  bool get hasCloudKey => _hasCloudKey;

  /// Whether a Hugging Face token is currently stored (never exposes the value).
  bool get hasHfToken => _hasHfToken;

  /// Seeds state from [SettingsRepository.load] and refreshes secret presence.
  ///
  /// Called by the provider on construction; defaults are used when nothing is
  /// stored.
  Future<void> loadInitial() async {
    state = await _repository.load();
    _hasCloudKey = (await _cloudKeyStore.read()) != null;
    _hasHfToken = (await _hfTokenStore.read()) != null;
  }

  /// Selects the runtime mode and persists it.
  Future<void> setRuntime(RuntimeChoice choice) =>
      _persist(state.copyWith(runtime: choice));

  /// Sets the cloud opt-in flag and persists it.
  Future<void> setCloudAuthorized(bool authorized) =>
      _persist(state.copyWith(cloudAuthorized: authorized));

  /// Sets the cloud API wire format (OpenAI/Anthropic) and persists it.
  Future<void> setCloudProvider(CloudProvider provider) =>
      _persist(state.copyWith(cloudProvider: provider));

  /// Sets the cloud model name (non-secret) and persists it; pass `null` or an
  /// empty string to fall back to the provider default.
  Future<void> setCloudModel(String? model) {
    final String? trimmed = model?.trim();
    return _persist(
      state.copyWith(
        cloudModel: (trimmed == null || trimmed.isEmpty) ? null : trimmed,
      ),
    );
  }

  /// Sets the cloud endpoint base URL (non-secret) and persists it; pass `null`
  /// or an empty string to fall back to the provider default.
  Future<void> setCloudEndpoint(String? endpoint) {
    final String? trimmed = endpoint?.trim();
    return _persist(
      state.copyWith(
        cloudEndpoint: (trimmed == null || trimmed.isEmpty) ? null : trimmed,
      ),
    );
  }

  /// Stores the cloud API key in secure storage only (never in [state]/Hive).
  Future<void> setCloudApiKey(String key) async {
    await _cloudKeyStore.write(key);
    _hasCloudKey = true;
  }

  /// Removes the stored cloud API key; [hasCloudKey] becomes `false`.
  Future<void> clearCloudApiKey() async {
    await _cloudKeyStore.clear();
    _hasCloudKey = false;
  }

  /// Stores the Hugging Face token in secure storage only.
  Future<void> setHfToken(String token) async {
    await _hfTokenStore.write(token);
    _hasHfToken = true;
  }

  /// Mirrors Module 007's active model id into [AppSettings] and persists it.
  ///
  /// Pass `null` to clear. `ModelRepository.getActiveModelHandle` remains the
  /// source of truth; this value is a mirror for display/restore.
  Future<void> setActiveModelId(String? id) =>
      _persist(state.copyWith(activeModelId: id));

  /// Sets the chat/distill temperature, clamped to `[0.0, 1.0]`, and persists.
  Future<void> setChatTemperature(double temperature) =>
      _persist(state.copyWith(chatTemperature: temperature.clamp(0.0, 1.0)));

  Future<void> _persist(AppSettings next) async {
    state = next;
    try {
      await _repository.save(next);
    } on Object catch (error) {
      final void Function(Object error)? onSaveError = _onSaveError;
      if (onSaveError == null) {
        rethrow;
      }
      onSaveError(error);
    }
  }
}
