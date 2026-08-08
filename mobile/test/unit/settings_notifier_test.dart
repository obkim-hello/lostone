import 'package:flutter_test/flutter_test.dart';
import 'package:lostone/models/app_settings.dart';
import 'package:lostone/services/llm/llm_persona_builder.dart'
    show PersonaRuntimeMode;
import 'package:lostone/services/model/token_store.dart';
import 'package:lostone/services/settings/secure_key_store.dart';
import 'package:lostone/services/settings/settings_notifier.dart';
import 'package:lostone/services/settings/settings_repository.dart';

class _ThrowingSettingsRepository implements SettingsRepository {
  AppSettings? saved;

  @override
  Future<AppSettings> load() async => const AppSettings();

  @override
  Future<void> save(AppSettings settings) async {
    throw StateError('disk full');
  }
}

class _ThrowingSecureKeyStore implements SecureKeyStore {
  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String key) async => throw StateError('keychain locked');

  @override
  Future<void> clear() async => throw StateError('keychain locked');
}

SettingsNotifier _build({
  SettingsRepository? repository,
  SecureKeyStore? cloudKeyStore,
  TokenStore? hfTokenStore,
  void Function(Object error)? onSaveError,
}) {
  return SettingsNotifier(
    repository: repository ?? InMemorySettingsRepository(),
    cloudKeyStore: cloudKeyStore ?? InMemorySecureKeyStore(),
    hfTokenStore: hfTokenStore ?? InMemoryTokenStore(),
    onSaveError: onSaveError,
  );
}

void main() {
  group('C3 setRuntime persists and maps runtimeMode', () {
    test('all three choices persist and map to PersonaRuntimeMode', () async {
      final InMemorySettingsRepository repo = InMemorySettingsRepository();
      final SettingsNotifier notifier = _build(repository: repo);
      await notifier.loadInitial();

      await notifier.setRuntime(RuntimeChoice.cloud);
      expect(notifier.state.runtime, RuntimeChoice.cloud);
      expect(notifier.state.runtimeMode, PersonaRuntimeMode.cloud);
      expect((await repo.load()).runtime, RuntimeChoice.cloud);

      await notifier.setRuntime(RuntimeChoice.maxPrivacy);
      expect(notifier.state.runtimeMode, PersonaRuntimeMode.maxPrivacy);

      await notifier.setRuntime(RuntimeChoice.local);
      expect(notifier.state.runtimeMode, PersonaRuntimeMode.local);
    });
  });

  group('C4 setCloudAuthorized persists and survives reload', () {
    test('toggles and is reloadable', () async {
      final InMemorySettingsRepository repo = InMemorySettingsRepository();
      final SettingsNotifier notifier = _build(repository: repo);
      await notifier.loadInitial();

      await notifier.setCloudAuthorized(true);

      expect(notifier.state.cloudAuthorized, isTrue);
      expect((await repo.load()).cloudAuthorized, isTrue);
    });
  });

  group('C5 secret isolation — cloud key', () {
    test('cloud key goes to secure store, never Hive/state', () async {
      final InMemorySettingsRepository repo = InMemorySettingsRepository();
      final InMemorySecureKeyStore keyStore = InMemorySecureKeyStore();
      final SettingsNotifier notifier = _build(
        repository: repo,
        cloudKeyStore: keyStore,
      );
      await notifier.loadInitial();

      await notifier.setCloudApiKey('sk-secret-123');

      expect(await keyStore.read(), 'sk-secret-123');
      expect(notifier.hasCloudKey, isTrue);
      expect(notifier.state, const AppSettings());
      expect((await repo.load()).toString().contains('sk-secret-123'), isFalse);
    });
  });

  group('C6 secret isolation — HF token', () {
    test('HF token goes to token store only', () async {
      final InMemorySettingsRepository repo = InMemorySettingsRepository();
      final InMemoryTokenStore tokenStore = InMemoryTokenStore();
      final SettingsNotifier notifier = _build(
        repository: repo,
        hfTokenStore: tokenStore,
      );
      await notifier.loadInitial();

      await notifier.setHfToken('hf_abc');

      expect(await tokenStore.read(), 'hf_abc');
      expect(notifier.hasHfToken, isTrue);
      expect(notifier.state, const AppSettings());
    });
  });

  group('C7 clear cloud key', () {
    test('clearCloudApiKey removes the secret and derived flag', () async {
      final InMemorySecureKeyStore keyStore = InMemorySecureKeyStore(
        initial: 'sk-old',
      );
      final SettingsNotifier notifier = _build(cloudKeyStore: keyStore);
      await notifier.loadInitial();
      expect(notifier.hasCloudKey, isTrue);

      await notifier.clearCloudApiKey();

      expect(await keyStore.read(), isNull);
      expect(notifier.hasCloudKey, isFalse);
    });
  });

  group('C20 cloud-without-key derived state', () {
    test('runtime cloud with no key → hasCloudKey false', () async {
      final SettingsNotifier notifier = _build();
      await notifier.loadInitial();

      await notifier.setRuntime(RuntimeChoice.cloud);
      await notifier.setCloudAuthorized(true);

      expect(notifier.state.runtime, RuntimeChoice.cloud);
      expect(notifier.hasCloudKey, isFalse);
    });
  });

  group('C21 max-privacy exposure', () {
    test('maxPrivacy maps to PersonaRuntimeMode.maxPrivacy', () async {
      final SettingsNotifier notifier = _build();
      await notifier.loadInitial();

      await notifier.setRuntime(RuntimeChoice.maxPrivacy);

      expect(notifier.state.runtimeMode, PersonaRuntimeMode.maxPrivacy);
    });
  });

  group('C23 chat temperature clamp', () {
    test('setChatTemperature(2.0) clamps to 1.0 and persists', () async {
      final InMemorySettingsRepository repo = InMemorySettingsRepository();
      final SettingsNotifier notifier = _build(repository: repo);
      await notifier.loadInitial();

      await notifier.setChatTemperature(2.0);
      expect(notifier.state.chatTemperature, 1.0);
      expect((await repo.load()).chatTemperature, 1.0);

      await notifier.setChatTemperature(-0.5);
      expect(notifier.state.chatTemperature, 0.0);
    });
  });

  group('C24 save failure surfaced', () {
    test(
      'onSaveError invoked, error not swallowed, state reflects intent',
      () async {
        Object? reported;
        final SettingsNotifier notifier = _build(
          repository: _ThrowingSettingsRepository(),
          onSaveError: (Object error) => reported = error,
        );

        await notifier.setCloudAuthorized(true);

        expect(reported, isA<StateError>());
        expect(notifier.state.cloudAuthorized, isTrue);
      },
    );

    test('without onSaveError the failure rethrows', () async {
      final SettingsNotifier notifier = _build(
        repository: _ThrowingSettingsRepository(),
      );

      await expectLater(
        notifier.setCloudAuthorized(true),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('G3 secret-write failure is not swallowed', () {
    test('setCloudApiKey rethrows and hasCloudKey stays false', () async {
      final SettingsNotifier notifier = _build(
        cloudKeyStore: _ThrowingSecureKeyStore(),
      );
      await notifier.loadInitial();

      await expectLater(
        notifier.setCloudApiKey('sk-secret'),
        throwsA(isA<StateError>()),
      );
      expect(notifier.hasCloudKey, isFalse);
    });

    test('clearCloudApiKey rethrows and hasCloudKey stays true', () async {
      final SettingsNotifier notifier = _build(
        cloudKeyStore: _ThrowingSecureKeyStore(),
      );
      await notifier.loadInitial();

      await expectLater(
        notifier.clearCloudApiKey(),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('cloud provider + model setters', () {
    test('setCloudProvider persists and survives reload', () async {
      final InMemorySettingsRepository repo = InMemorySettingsRepository();
      final SettingsNotifier notifier = _build(repository: repo);
      await notifier.loadInitial();

      await notifier.setCloudProvider(CloudProvider.anthropic);

      expect(notifier.state.cloudProvider, CloudProvider.anthropic);
      expect((await repo.load()).cloudProvider, CloudProvider.anthropic);
    });

    test('setCloudModel trims, blanks map to null (provider default)', () async {
      final SettingsNotifier notifier = _build();
      await notifier.loadInitial();

      await notifier.setCloudModel('  claude-3-5-sonnet-latest  ');
      expect(notifier.state.cloudModel, 'claude-3-5-sonnet-latest');

      await notifier.setCloudModel('   ');
      expect(notifier.state.cloudModel, isNull);
    });
  });

  group('G1 copyWith preserves set fields on unrelated writes', () {
    test('activeModelId/cloudEndpoint survive a runtime change', () async {
      final SettingsNotifier notifier = _build();
      await notifier.loadInitial();
      await notifier.setActiveModelId('gemma3-1b-it-int4');
      await notifier.setCloudEndpoint('https://api.example.test/v1');

      await notifier.setRuntime(RuntimeChoice.cloud);

      expect(notifier.state.activeModelId, 'gemma3-1b-it-int4');
      expect(notifier.state.cloudEndpoint, 'https://api.example.test/v1');
      expect(notifier.state.runtime, RuntimeChoice.cloud);
    });

    test('explicit null clears activeModelId while others persist', () async {
      final SettingsNotifier notifier = _build();
      await notifier.loadInitial();
      await notifier.setActiveModelId('gemma3-1b-it-int4');
      await notifier.setCloudAuthorized(true);

      await notifier.setActiveModelId(null);

      expect(notifier.state.activeModelId, isNull);
      expect(notifier.state.cloudAuthorized, isTrue);
    });
  });
}
