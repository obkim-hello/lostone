import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_settings.dart';
import '../models/distill_state.dart';
import '../models/persona.dart';
import '../models/persona_library_state.dart';
import '../services/llm/cloud_runtime.dart';
import '../services/llm/fallback_runtime.dart';
import '../services/llm/flutter_gemma_engine.dart';
import '../services/llm/lite_rt_runtime.dart';
import '../services/llm/llm_persona_builder.dart';
import '../services/llm/persona_runtime.dart';
import '../services/model/model_repository.dart';
import '../services/persona_library/distill_notifier.dart';
import '../services/persona_library/file_picker_facade.dart';
import '../services/persona_library/persona_library_notifier.dart';
import '../services/persona_library/persona_repository.dart';
import '../services/settings/secure_key_store.dart';
import 'settings_providers.dart';

/// Durable persona persistence (Module 009). Override in tests with a
/// [FilePersonaRepository] over a `MemoryPersonaDirectory`.
final Provider<PersonaRepository> personaRepositoryProvider =
    Provider<PersonaRepository>((Ref ref) => FilePersonaRepository());

/// Platform file/directory picker seam for the import step. Override in tests
/// with a `FakeFilePicker`.
final Provider<FilePickerFacade> filePickerFacadeProvider =
    Provider<FilePickerFacade>((Ref ref) => const DefaultFilePickerFacade());

/// Persona library state for the home body.
final StateNotifierProvider<PersonaLibraryNotifier, PersonaLibraryState>
    personaLibraryProvider =
    StateNotifierProvider<PersonaLibraryNotifier, PersonaLibraryState>(
        (Ref ref) {
  final PersonaLibraryNotifier notifier = PersonaLibraryNotifier(
    repository: ref.watch(personaRepositoryProvider),
  );
  notifier.refresh();
  return notifier;
});

/// Loads a full [Persona] body by id for the detail screen.
///
/// The library list holds only lightweight [PersonaSummary] projections; the
/// detail view decodes the whole persona on demand (auto-disposed on pop).
final AutoDisposeFutureProviderFamily<Persona, String> personaDetailProvider =
    FutureProvider.autoDispose.family<Persona, String>((Ref ref, String id) {
  return ref.watch(personaRepositoryProvider).load(id);
});

/// Distill/create flow state.
final StateNotifierProvider<DistillNotifier, DistillState> distillProvider =
    StateNotifierProvider<DistillNotifier, DistillState>((Ref ref) {
  return DistillNotifier(
    repository: ref.watch(personaRepositoryProvider),
  );
});

/// On-device context window (tokens) for distillation.
///
/// Must comfortably exceed a single chunk's prompt plus its JSON output;
/// paired with [distillChunkMessages] so the composed prompt never overflows
/// the engine (a hard `INVALID_ARGUMENT` on `flutter_gemma`).
const int distillContextTokens = 4096;

/// Max target-person messages per distillation prompt on the on-device path.
///
/// Kept low so each chunk's prompt (template + corpus) stays well under
/// [distillContextTokens]; the builder distills each chunk and merges.
const int distillChunkMessages = 80;

/// Max target-person messages per distillation prompt on the cloud path.
///
/// Cloud models expose a far larger context window (see [CloudRuntime]'s
/// `contextTokens`), so a much bigger chunk keeps the whole corpus in a handful
/// of prompts instead of dozens of device-sized ones — each chunk is a
/// sequential network round-trip, so fewer chunks means a materially faster
/// distillation.
const int cloudDistillChunkMessages = 800;

/// Distillation options derived from the user's runtime choice (SPEC-009 §2.6).
///
/// Cloud uses [cloudDistillChunkMessages] (large context → fewer round-trips);
/// local/max-privacy keep the device-safe [distillChunkMessages] so prompts fit
/// [distillContextTokens]. `mode` mirrors the choice so the max-privacy branch
/// annotates its fallback honestly. Other fields keep Module 004 defaults.
final Provider<LlmBuildOptions> distillOptionsProvider =
    Provider<LlmBuildOptions>((Ref ref) {
  final RuntimeChoice choice = ref.watch(appSettingsProvider).runtime;
  final int chunk = choice == RuntimeChoice.cloud
      ? cloudDistillChunkMessages
      : distillChunkMessages;
  return LlmBuildOptions(
    mode: toRuntimeMode(choice),
    maxChunkMessages: chunk,
    cloudAuthorized: choice == RuntimeChoice.cloud,
  );
});

/// Resolves the [PersonaRuntime] the distill flow passes to
/// [DistillNotifier.run], from the user's [AppSettings.runtime] choice.
///
/// `maxPrivacy` → [FallbackRuntime] (no LLM); `cloud` → [CloudRuntime] over the
/// [cloudTransportProvider] transport, with the API key read lazily from secure
/// storage (unavailable until authorized + keyed, which the distill gate
/// reports honestly); `local` → on-device [LiteRtRuntime]. Host tests override
/// this with a `MockRuntime`.
final Provider<PersonaRuntime> personaRuntimeProvider =
    Provider<PersonaRuntime>((Ref ref) {
  final AppSettings settings = ref.watch(appSettingsProvider);
  if (settings.runtime == RuntimeChoice.maxPrivacy) {
    return const FallbackRuntime();
  }
  if (settings.runtime == RuntimeChoice.cloud) {
    final SecureKeyStore keyStore = ref.watch(cloudKeyStoreProvider);
    return CloudRuntime(
      transport: ref.watch(cloudTransportProvider),
      authorized: settings.cloudAuthorized,
      model: settings.effectiveCloudModel,
      apiKeyLoader: keyStore.read,
    );
  }
  final ModelRepository models = ref.watch(modelRepositoryProvider);
  return LiteRtRuntime(
    engine: const FlutterGemmaEngine(maxTokens: distillContextTokens),
    activeHandle: models.getActiveModelHandle,
    capabilities: const RuntimeCapabilities(
      contextTokens: distillContextTokens,
      maxOutputTokens: 1024,
    ),
  );
});
