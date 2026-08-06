import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../models/app_settings.dart';
import '../models/model_descriptor.dart';
import '../models/model_manager_state.dart';
import '../services/model/device_capabilities.dart';
import '../services/model/flutter_gemma_installer.dart';
import '../services/model/model_catalog.dart';
import '../services/model/model_repository.dart';
import '../services/model/model_store.dart';
import '../services/model/secure_token_store.dart';
import '../services/model/token_store.dart';
import '../services/settings/model_manager_notifier.dart';
import '../services/settings/secure_key_store.dart';
import '../services/settings/settings_notifier.dart';
import '../services/settings/settings_repository.dart';

/// Non-secret settings persistence, backed by the app's `settings` Hive box
/// (opened during app initialization). Override in tests.
final Provider<SettingsRepository> settingsRepositoryProvider =
    Provider<SettingsRepository>((Ref ref) {
      return HiveSettingsRepository(
        box: Hive.box<dynamic>(HiveSettingsRepository.boxName),
      );
    });

/// Encrypted cloud API-key store (write via [SettingsNotifier]; read here for
/// Modules 006/009/004 at call time — the key never enters [AppSettings]).
final Provider<SecureKeyStore> cloudKeyStoreProvider = Provider<SecureKeyStore>(
  (Ref ref) => FlutterSecureKeyStore(),
);

/// Encrypted Hugging Face token store (shared with Module 007's downloader).
final Provider<TokenStore> hfTokenStoreProvider = Provider<TokenStore>(
  (Ref ref) => SecureTokenStore(),
);

/// Device capability probe used for model recommendation.
///
/// Note: Module 007 ships only [StaticDeviceCapabilities]; runtime tier
/// detection is outstanding Module 007 debt, so this defaults to a mid-tier
/// device. Override with the detected tier once available.
final Provider<DeviceCapabilities> deviceCapabilitiesProvider =
    Provider<DeviceCapabilities>(
      (Ref ref) => const StaticDeviceCapabilities(tier: DeviceTier.midEnd),
    );

/// Production [ModelRepository] (Module 007 backend).
///
/// Note: per DESIGN-DEBT DD-002 no disk-backed `ModelStore` exists yet, so this
/// uses [InMemoryModelStore]; persistence across launches is outstanding Module
/// 007 debt. Override in tests.
final Provider<ModelRepository> modelRepositoryProvider =
    Provider<ModelRepository>((Ref ref) {
      return DefaultModelRepository(
        catalog: const ModelCatalog(),
        installer: FlutterGemmaInstaller(),
        store: InMemoryModelStore(),
        device: ref.watch(deviceCapabilitiesProvider),
        tokenStore: ref.watch(hfTokenStoreProvider),
      );
    });

/// Global app settings; read by Modules 006/009 for runtime mode, cloud
/// authorization, temperature, and the active-model mirror.
final StateNotifierProvider<SettingsNotifier, AppSettings> appSettingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((Ref ref) {
      final SettingsNotifier notifier = SettingsNotifier(
        repository: ref.watch(settingsRepositoryProvider),
        cloudKeyStore: ref.watch(cloudKeyStoreProvider),
        hfTokenStore: ref.watch(hfTokenStoreProvider),
      );
      notifier.loadInitial();
      return notifier;
    });

/// Model management state for the settings UI; mirrors the active model id into
/// [appSettingsProvider] on change.
final StateNotifierProvider<ModelManagerNotifier, ModelManagerState>
modelManagerProvider =
    StateNotifierProvider<ModelManagerNotifier, ModelManagerState>((Ref ref) {
      final ModelManagerNotifier notifier = ModelManagerNotifier(
        repository: ref.watch(modelRepositoryProvider),
        device: ref.watch(deviceCapabilitiesProvider),
        onActiveChanged: (String? id) =>
            ref.read(appSettingsProvider.notifier).setActiveModelId(id),
      );
      notifier.refresh();
      return notifier;
    });
