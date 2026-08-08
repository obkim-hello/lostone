import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lostone/models/app_settings.dart';
import 'package:lostone/providers/persona_library_providers.dart';
import 'package:lostone/providers/settings_providers.dart';
import 'package:lostone/services/llm/llm_persona_builder.dart'
    show LlmBuildOptions, PersonaRuntimeMode;
import 'package:lostone/services/model/token_store.dart';
import 'package:lostone/services/settings/secure_key_store.dart';
import 'package:lostone/services/settings/settings_notifier.dart';
import 'package:lostone/services/settings/settings_repository.dart';

Future<ProviderContainer> _containerFor(RuntimeChoice choice) async {
  final SettingsNotifier notifier = SettingsNotifier(
    repository: InMemorySettingsRepository(),
    cloudKeyStore: InMemorySecureKeyStore(),
    hfTokenStore: InMemoryTokenStore(),
  );
  await notifier.setRuntime(choice);
  return ProviderContainer(
    overrides: <Override>[
      appSettingsProvider.overrideWith((Ref ref) => notifier),
    ],
  );
}

void main() {
  group('distillOptionsProvider · runtime-aware chunk sizing', () {
    test('local → device-safe chunk size + local mode', () async {
      final ProviderContainer container =
          await _containerFor(RuntimeChoice.local);
      addTearDown(container.dispose);

      final LlmBuildOptions options = container.read(distillOptionsProvider);
      expect(options.maxChunkMessages, distillChunkMessages);
      expect(options.mode, PersonaRuntimeMode.local);
      expect(options.cloudAuthorized, isFalse);
    });

    test('cloud → large chunk size (big context) + cloud mode', () async {
      final ProviderContainer container =
          await _containerFor(RuntimeChoice.cloud);
      addTearDown(container.dispose);

      final LlmBuildOptions options = container.read(distillOptionsProvider);
      expect(options.maxChunkMessages, cloudDistillChunkMessages);
      expect(cloudDistillChunkMessages, greaterThan(distillChunkMessages));
      expect(options.mode, PersonaRuntimeMode.cloud);
      expect(options.cloudAuthorized, isTrue);
    });

    test('maxPrivacy → device-safe chunk size + maxPrivacy mode', () async {
      final ProviderContainer container =
          await _containerFor(RuntimeChoice.maxPrivacy);
      addTearDown(container.dispose);

      final LlmBuildOptions options = container.read(distillOptionsProvider);
      expect(options.maxChunkMessages, distillChunkMessages);
      expect(options.mode, PersonaRuntimeMode.maxPrivacy);
    });
  });
}
