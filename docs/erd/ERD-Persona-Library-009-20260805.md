# ERD-009-Persona Library & Distill

> Engineering Requirements Document — Persona Library & Distill (persona persistence, library screen, and the distill/creation flow)
>
> **Version**: v1.1.0 (draft)
> **Status**: 📝 Draft (pending review)
> **Author**: Claude
> **Date**: 2026-08-05
> **Priority**: P0

---

## 📋 Document Info

| Field | Value |
|-------|-------|
| **ERD ID** | ERD-009 |
| **Related PRD** | PRD-Persona-Library-009-20260805.md |
| **Related Spec** | SPEC-Persona-Library-009-20260805.md |
| **Depends on** | Module 002 (Conversation + `ImportNotifier`/`importStateProvider`/`DataImportService` — reused), Module 003 (Persona, PersonaJsonCodec — read-only), Module 004 (LlmPersonaBuilder), Module 007 (model readiness) |
| **Related decisions** | ADR-002, ADR-004, ADR-005 |

---

## 1. Technical Goals

- Define **`PersonaRepository`**: durable, file-per-persona persistence (`save` / `list` / `load` / `delete`) over `PersonaJsonCodec` bytes in the app documents directory, with newest-first enumeration, corrupt-file resilience, and typed errors.
- Define **`PersonaSummary`**: a lightweight list projection derived from a `Persona` (or from a cheap partial decode) so the library never renders raw text and need not materialize heavy layer bodies for the list.
- Define the **008 encryption seam**: a byte-transform / codec-wrapper injection point so encryption-at-rest / backup-exclusion drops in without changing the `PersonaRepository` contract (mirrors Module 002's `MediaStore` backup-exclusion hook).
- Define the **filesystem seam**: an abstraction over the persona directory so host tests use a temp dir / in-memory fs and the device uses `path_provider`.
- Define the **library screen** widget tree + **`PersonaLibraryNotifier`** (StateNotifier: list / refresh / delete) and the **distill flow** + **`DistillNotifier`** (StateNotifier: run `build` with progress; states `idle / running / done / failed`; then `save`).
- Define the **import entry point** at the head of the distill flow: a `file_picker`-backed source picker that drives Module 002's `ImportNotifier.importFiles(...)` to produce a `Conversation`. 009 owns the widget + state surfacing (`ImportState`); it does not touch 002's parsers or `DataImportService`.
- Define the **model-readiness read** from Module 007 and the actionable route to Module 010 (009 does not implement model management).
- Preserve upstream contracts: Modules 002/003/004/007 are reused read-only; no changes to `Persona`, `PersonaJsonCodec`, `LlmPersonaBuilder`, or 002's `ImportNotifier`/`DataImportService`/parsers.

---

## 2. Design Constraints

- **Contract host, not contract author, for personas.** The persisted format is exactly `PersonaJsonCodec.encode(persona)` bytes; 009 introduces no second persistence schema. A file whose `schemaVersion` exceeds `kPersonaSchemaVersion` is skipped by `list()` (logged) and surfaced as `PersonaSchemaException` by `load()`.
- **No modification of 002/003/004/007.** They are consumed as-is. `Persona` has no avatar field and none is added (initials + relation + badge in UI; avatar noted as Technical Debt only, §11).
- **Distillation belongs to Module 004.** 009 wires `LlmPersonaBuilder.build(...)` + a `PersonaRuntime` and renders progress via the builder's `onLog` seam; it does not re-implement distillation, the Runtime abstraction, or the statistical fallback. 004 already handles empty-corpus / maxPrivacy / cloud-unauthorized / parse-failure by falling back to the 003 statistical engine and tagging low-confidence layers + honest `notes`.
- **Model readiness belongs to Module 007; model UI belongs to Module 010.** 009 reads `getActiveModelHandle()`; a null handle produces an actionable prompt that routes to 010. 009 never downloads / activates models.
- **Privacy (ADR-002 / ADR-004).** `.persona` bytes carry only what `Persona` carries (message-key hashes + ≤60-grapheme excerpts, never raw text). Local-by-default distill; cloud opt-in gate honored (owned by 010). No raw text in logs.
- **Riverpod style (pinned).** Legacy `StateNotifier<State>` + top-level `final StateNotifierProvider<Notifier, State>`, immutable state, constructor-injected services with defaults — matching `import_providers.dart`.
- **Navigation (pinned).** No router; `app.dart` sets `home: HomeScreen`; navigation is imperative `Navigator.of(context).push(MaterialPageRoute(...))`. The library becomes the production home body. `go_router` is flagged in Technical Debt, not adopted.

---

## 3. Architecture

### 3.1 Component diagram
```
Home (HomeScreen body replaced) ─ PersonaLibraryScreen
  ├─ PersonaLibraryNotifier (StateNotifier<PersonaLibraryState>)
  │     └─ PersonaRepository.list() / delete()
  ├─ row tap → PersonaRepository.load(id) → push ChatScreen (Module 006)
  ├─ row → PersonaDetailScreen (read-only five layers + notes + source)
  └─ create action → DistillFlowScreen
        ├─ import step → importStateProvider / ImportNotifier.importFiles(paths)  (Module 002)
        │     ├─ FilePickerFacade.pickFiles() | pickDirectory() → path(s) (file_picker; seam for tests)
        │     │     └─ dir sources (iMessage db / Photo-EXIF) → security-scoped bookmark (ERD-002 §676)
        │     └─ ImportState (picking/parsing/done/failed) → Conversation
        └─ DistillNotifier (StateNotifier<DistillState>)
              ├─ readiness: ModelRepository.getActiveModelHandle()  (Module 007)
              │     └─ null → actionable prompt → route to Module 010
              ├─ LlmPersonaBuilder.build(conversation, runtime, options)  (Module 004)
              │     └─ onLog → progress log ; fallback → 003 statistical (inside 004)
              └─ on save → PersonaRepository.save(persona)

PersonaRepository (this module)
  ├─ PersonaJsonCodec.encode/decode              (Module 003, read-only)
  ├─ PersonaDirectory (filesystem seam)          path_provider on device / temp|memfs in tests
  └─ PersonaBytesTransform (008 encryption seam) identity by default; encrypt/exclude-backup later
```

### 3.2 Component design
- **`PersonaRepository`** (abstract) + **`FilePersonaRepository`** (default). Composes: a `PersonaCodec` (default `PersonaJsonCodec`), a `PersonaDirectory` (filesystem seam), and a `PersonaBytesTransform` (008 seam). All three constructor-injected with defaults.
- **`PersonaDirectory`** — resolves and enumerates the persona directory. Default `PathProviderPersonaDirectory` (app documents dir, files matching `*.persona`); test seam `MemoryPersonaDirectory` / temp-dir variant.
- **`PersonaBytesTransform`** — `List<int> onWrite(List<int>)` / `List<int> onRead(List<int>)`, identity by default; Module 008 supplies an encrypting transform and a backup-exclusion hook on `PersonaDirectory` without touching the repository contract.
- **`PersonaLibraryNotifier`** — loads summaries on init, exposes `refresh()` and `delete(id)`, holds an immutable `PersonaLibraryState`.
- **`DistillNotifier`** — orchestrates readiness check → `build(...)` (progress via `onLog`) → holds `DistillState` (`idle / running / done / failed`, carrying the resulting `Persona` and progress lines) → `save()`.
- **Import step** — the head of `DistillFlowScreen`. A `FilePickerFacade` (abstract; default wraps `file_picker`, test seam `FakeFilePicker`) yields path(s) — `pickFiles()` for file-based sources (WeChat CSV/HTML, Weibo/Instagram JSON) or `pickDirectory()` for directory/db sources (iMessage `chat.db`, Photo-EXIF folder, ERD-002 §676). The screen then calls `ref.read(importStateProvider.notifier).importFiles(paths, source: …)` (Module 002, reused unchanged) and renders `ImportState` (`picking / parsing / preprocessing / done / failed`). On `done` the resulting `Conversation` is handed to `DistillNotifier.run(...)`; on `failed`/empty/cancel it shows a typed, retryable message. No new notifier is introduced for import — 009 reuses 002's `ImportNotifier`; only the `FilePickerFacade` seam is new.
- **UI**: `PersonaLibraryScreen` (home body), `PersonaDetailScreen`, `DistillFlowScreen` (import step + distill).

### 3.3 Module dependencies
| Module | Interface used | Purpose |
|--------|----------------|---------|
| 002 | `Conversation`; `ImportNotifier` / `importStateProvider` / `DataImportService` / `DataSource` / `ParseOptions` | Distill input + the parser/data layer the import UI drives (reused unchanged) |
| 003 | `Persona`, layers, `PersonaJsonCodec`, `PersonaSchemaException` | Persisted shape + codec (read-only) |
| 004 | `LlmPersonaBuilder.build`, `LlmBuildOptions`, `PersonaRuntime`, `PersonaRuntimeMode` | Distillation (reused) |
| 007 | `ModelRepository.getActiveModelHandle()` | Model readiness for distill |
| 010 | `appSettingsProvider` (`runtimeMode`/`cloudAuthorized`) + `cloudKeyStoreProvider`; model install/activate route | Mode/gate for distill + cloud-key read-path (below); readiness-gate route target |
| 008 (future) | encrypting `PersonaBytesTransform` + backup exclusion | Drops into the seam |

**Settings → distill runtime binding (seam with 010).** `DistillNotifier` selects the `PersonaRuntime` + `LlmBuildOptions.mode` from 010's `appSettingsProvider` (`runtimeMode` → local `LiteRtRuntime` vs `CloudRuntime`; `cloudAuthorized` → cloud gate; `maxPrivacy` → local-only). When `runtimeMode == cloud` && `cloudAuthorized`, it reads the key at build time via 010's `cloudKeyStoreProvider` (`await ref.read(cloudKeyStoreProvider).read()`) and passes it to the injected `CloudRuntime.apiKey` — never into state, `.persona` bytes, or logs (identical read-path to 006 §3.4). Absent key / unauthorized → 004's gate falls back to the labeled statistical engine (§3, honest `notes`). Fail-safe: unread settings → local defaults.

---

## 4. Data Structures

### 4.1 Core models

**`PersonaSummary`** (new, immutable — the library list projection)
| Field | Type | Notes |
|-------|------|-------|
| id | `String` | Persona id (deterministic, from 004) |
| displayName | `String` | `identity.displayName` (never empty; 004 defaults it) |
| relationToUser | `String?` | `identity.relationToUser` |
| generatedAt | `DateTime` | UTC; list sort key (newest first) |
| hasInsufficientMaterial | `bool` | Derived: `persona.notes` contains any "insufficient material" note |
| lowestLayerConfidence | `Confidence` | `min` over identity/expression/emotion/relation layer confidences |

**`PersonaLibraryState`** (immutable)
| Field | Type | Notes |
|-------|------|-------|
| phase | `LibraryPhase` | `loading / ready / failed` |
| summaries | `List<PersonaSummary>` | Newest-first; empty list is a valid `ready` state (empty library) |
| error | `String?` | Set only on `failed` (e.g. directory unreadable) |
| skippedCount | `int` | Count of corrupt/unsupported files skipped by the last `list()` |

**`DistillState`** (immutable)
| Field | Type | Notes |
|-------|------|-------|
| phase | `DistillPhase` | `idle / running / done / failed` |
| progressLog | `List<String>` | Lines from `LlmPersonaBuilder.onLog` (chunk count, fallback reason) |
| persona | `Persona?` | Set on `done` (result awaiting review/save) |
| usedFallback | `bool` | True when 004 fell back to the statistical engine (from `persona.notes`) |
| error | `DistillError?` | Set on `failed` (`noModel` / `buildFailed`) |
| saved | `bool` | True once `save()` succeeds |

### 4.2 Database / file layout
- **One file per persona**: `${persona.id}.persona` under the app documents directory (`getApplicationDocumentsDirectory()` on device). No index file; `list()` enumerates `*.persona` entries.
- **Ordering**: `list()` decodes each summary and sorts by `generatedAt` descending; ties broken by `id` for stability.
- **Corrupt handling**: per-file decode is guarded; a `FormatException` / `PersonaSchemaException` / read error skips that file, increments `skippedCount`, and logs (no raw content). One bad file never fails the enumeration.
- **008 seam**: bytes pass through `PersonaBytesTransform.onWrite` before hitting disk and `onRead` after reading; backup-exclusion is a `PersonaDirectory` hook (mirrors 002 `MediaStore`).

### 4.3 Storage format
- Exactly `PersonaJsonCodec.encode(persona)` → UTF-8 JSON bytes (see `persona_codec.dart`). No 009-specific fields.
- `PersonaSummary` is derived at read time. Default: decode the full `Persona` and project. Optimization seam (optional): a `summarize(bytes)` that reads only the small header fields (`id`, `identity`, `generatedAt`, `notes`, layer confidences) without materializing memories/tags — behind the same `PersonaDirectory`/codec composition, so it stays a pure read optimization with identical semantics.

---

## 5. Interface Design

### 5.1 `PersonaRepository`
```dart
/// Durable persistence for distilled personas. One `${id}.persona` file each.
abstract class PersonaRepository {
  /// Encode + write ${persona.id}.persona (overwrites if present).
  Future<void> save(Persona persona);

  /// Enumerate saved personas as summaries, newest first. Corrupt/unsupported
  /// files are skipped (logged), never crashing the list.
  Future<List<PersonaSummary>> list();

  /// Decode a .persona file. Throws PersonaSchemaException (schema too new) or
  /// PersonaStoreException (I/O / missing / corrupt).
  Future<Persona> load(String personaId);

  /// Remove the file. Idempotent: deleting a missing persona is a no-op.
  Future<void> delete(String personaId);
}

@immutable
class PersonaSummary {
  const PersonaSummary({
    required this.id,
    required this.displayName,
    required this.relationToUser,
    required this.generatedAt,
    required this.hasInsufficientMaterial,
    required this.lowestLayerConfidence,
  });
  final String id;
  final String displayName;
  final String? relationToUser;
  final DateTime generatedAt;
  final bool hasInsufficientMaterial;
  final Confidence lowestLayerConfidence;
}

/// I/O / corruption error surfaced by load() (distinct from the codec's
/// PersonaSchemaException, which passes through unchanged).
class PersonaStoreException implements Exception {
  const PersonaStoreException(this.message, {this.cause});
  final String message;
  final Object? cause;
}
```

### 5.2 Seams
```dart
/// Filesystem seam: resolve + enumerate + read/write/delete .persona files.
abstract class PersonaDirectory {
  Future<List<String>> listIds();                 // ids with a .persona file
  Future<List<int>?> readBytes(String id);        // null if absent
  Future<void> writeBytes(String id, List<int> bytes);
  Future<void> delete(String id);                 // no-op if absent
}
// PathProviderPersonaDirectory (device) | MemoryPersonaDirectory (host tests)

/// 008 encryption / backup-exclusion seam. Identity by default.
abstract class PersonaBytesTransform {
  List<int> onWrite(List<int> plain);
  List<int> onRead(List<int> stored);
}

/// Import picker seam. Default wraps `file_picker`; tests inject a fake.
abstract class FilePickerFacade {
  /// Pick one or more export files. Returns paths, or `[]` if cancelled.
  /// Used by file-based sources (WeChat CSV/HTML, Weibo/Instagram JSON).
  Future<List<String>> pickFiles({List<String>? allowedExtensions});

  /// Pick a directory and return a path with **persistent** read access
  /// (iOS: a resolved security-scoped bookmark). Returns `null` if cancelled.
  /// Used by directory/db sources (iMessage `chat.db`, Photo-EXIF folder) —
  /// see ERD-002 §676. Null on platforms without directory picking.
  Future<String?> pickDirectory();
}
// DefaultFilePickerFacade (file_picker) | FakeFilePicker (host tests)
```

The import step chooses `pickFiles` vs `pickDirectory` from the selected `DataSource` (file-based → `pickFiles`; iMessage-db / Photo-EXIF → `pickDirectory`), then composes the resulting path(s) with Module 002's `ImportNotifier.importFiles(paths, source:)` — no new import state type; `ImportState` is consumed as-is. **iOS security-scoped bookmark:** directory sources need a bookmark resolved for the duration of the import (`file_picker` returns a security-scoped path; the facade is responsible for `startAccessingSecurityScopedResource` / stop around the read). v1 does not persist bookmarks across launches — a re-import re-picks. See §11 Technical Debt.

### 5.3 Notifiers (Riverpod, pinned style)
```dart
class PersonaLibraryNotifier extends StateNotifier<PersonaLibraryState> {
  PersonaLibraryNotifier({PersonaRepository? repository})
      : _repo = repository ?? FilePersonaRepository(),
        super(const PersonaLibraryState.loading()) { refresh(); }
  Future<void> refresh();          // list() → ready(summaries, skippedCount) | failed(error)
  Future<void> delete(String id);  // repo.delete → optimistic remove → refresh
}
final StateNotifierProvider<PersonaLibraryNotifier, PersonaLibraryState>
    personaLibraryProvider = /* ... */;

class DistillNotifier extends StateNotifier<DistillState> {
  DistillNotifier({LlmPersonaBuilder? builder, PersonaRepository? repository,
                   ModelRepository? models})
      : /* injected defaults */,
        super(const DistillState.idle());
  Future<void> run(Conversation conversation,
      {required PersonaRuntime runtime, LlmBuildOptions options});  // readiness → build → done|failed
  Future<void> save();  // persist state.persona → saved
  void reset();
}
final StateNotifierProvider<DistillNotifier, DistillState>
    distillProvider = /* ... */;
```

---

## 6. Implementation Details

### 6.1 Key algorithms
- **`list()`**: `directory.listIds()` → for each, `readBytes` → `transform.onRead` → `codec.decode` (guarded) → project to `PersonaSummary`; collect successes, count/log skips; sort by `generatedAt` desc, then `id`.
- **`save()`**: `codec.encode(persona)` → `transform.onWrite` → `directory.writeBytes(persona.id, ...)` (overwrites).
- **`load()`**: `directory.readBytes(id)` → null → `PersonaStoreException('not found')`; else `transform.onRead` → `codec.decode` (let `PersonaSchemaException` propagate; wrap other errors as `PersonaStoreException`).
- **`delete()`**: `directory.delete(id)` (no-op if absent).
- **Summary derivation**: `hasInsufficientMaterial = persona.notes.any(isInsufficientMaterialNote)`; `lowestLayerConfidence = min(identity, expressionStyle, emotionalLogic, relationalBehavior confidences)` by `Confidence.index`.
- **Distill run**: check `models.getActiveModelHandle()`; null → `failed(noModel)`. Else `running` (stream `onLog` into `progressLog`) → `builder.build(...)` → `done(persona, usedFallback = notes indicate fallback)`. Any thrown error → `failed(buildFailed)`; nothing is saved on failure.

### 6.2 State management
- Two `StateNotifier`s (§5.3), immutable states (§4.1), constructor-injected services with production defaults; host tests inject fakes. `PersonaLibraryNotifier` refreshes on construction and after `delete`/`save`. `DistillNotifier` is transient to the flow; `save()` on success drives a library `refresh()`.

### 6.3 Error handling
- `list()` never throws for a single bad file — it skips + logs + counts. It fails (`LibraryPhase.failed`) only if the directory itself is unreadable.
- `load()` surfaces typed errors: `PersonaSchemaException` (passthrough) vs `PersonaStoreException` (I/O / missing / corrupt) — the caller (006/detail) shows an honest message.
- Distill: `noModel` → route-to-010 prompt; `buildFailed` → typed, retryable; nothing persisted on failure. No silent catches; no fabricated persona (004 owns the honest statistical fallback).

### 6.4 Logging
- Skips log the file id + error class only (never bytes/content). Distill progress mirrors `LlmPersonaBuilder.onLog` (chunk count, fallback reason) — no raw text, no prompt bodies, no keys.

---

## 7. Test Strategy

### 7.1 Unit (host, deterministic)
- `FilePersonaRepository` over `MemoryPersonaDirectory`: `save → list → load` round-trip (equal `Persona`); newest-first ordering; `delete` + idempotent re-delete; overwrite (last-writer-wins); corrupt-bytes skip in `list` (+ `skippedCount`); higher-schema file → skipped in `list`, `PersonaSchemaException` in `load`; missing id → `PersonaStoreException`; `PersonaBytesTransform` wrapper (e.g. XOR/reverse) round-trips.
- `PersonaLibraryNotifier` (fake repo): loading → ready; empty library; delete → removed + refreshed; directory-failure → failed.
- `DistillNotifier` (fake builder / `MockRuntime`, fake models): happy path `idle→running→done`→save→saved; `noModel` gate; `buildFailed`; fallback path yields a valid saveable `Persona`; `progressLog` captures `onLog`.

### 7.2 Widget
- Library screen: rows, initials avatar, confidence/"limited data" badge, empty state, delete-confirm, open-navigation (mocked), `kDebugMode` harness button retained.
- Import step (`FakeFilePicker` + fake/real `ImportNotifier`): picker invoked → paths → `parsing` progress → `done` hands `Conversation` to distill; cancel (`[]`) and empty selection → typed message, no distill; parse failure (`ImportPhase.failed`) → error + retry.
- Distill flow: source picker, progress + log, review card (notes/confidence), no-model prompt, error/retry, save.

### 7.3 Integration / on-device (ADR-005)
- Device: import → distill (Gemma 3 1B) → save → relaunch → `list` shows it → `load` → push 006 chat. Host/CI = structure/contract + widget with fakes; quality on-device.

---

## 8. Performance
- `list()` async, off UI thread; small JSON files; optional header-only `summarize` seam avoids materializing memories/tags for the list.
- `save`/`load`/`delete` are single small-file operations.
- Distill inherits 004's budget (≤ 60 s / 1000 messages, device/model-dependent); progress shown throughout.

## 9. Security
- `.persona` carries only hashes + short excerpts (003/004), never raw import text; nothing extra persisted by 009.
- Files in the app sandbox; 008 seam enables encryption-at-rest + backup exclusion without contract change.
- Local-by-default distill; cloud opt-in honored (010-owned); no raw text / keys in logs.

## 10. Deployment
- Ships as part of the Flutter app; the library becomes the production `HomeScreen` body (keeps the `kDebugMode` harness button). No new native config beyond `path_provider` (already implied by app documents usage) and **`file_picker: ^8.0.0`** (new dependency for the import step; the version ERD-002 §646 had listed as a candidate). iOS: a one-shot document/directory pick needs no special entitlement; **directory sources additionally require security-scoped bookmark access** around the read (`file_picker` provides the security-scoped path) — file-based sources do not. iOS 16.0+ (ADR-005).

## 11. Technical Debt
- **Avatar image**: `Persona` (003) has no avatar field; v1 uses initials + relation + badge. Adding an avatar would require a 003 schema change — deferred, noted here only.
- **`go_router`**: imperative `Navigator` retained for v1; router migration deferred.
- **Persona editing / rename / in-place re-distill**: not in v1; save is create/overwrite only.
- **Library scale**: full-decode `list()` is fine for tens of personas; if libraries grow large, adopt the header-only `summarize` seam or a small index/cache.
- **Persistent directory access**: v1 resolves an iOS security-scoped bookmark only for the duration of one import; it does not persist the bookmark across launches, so re-importing an iMessage `chat.db` / Photo-EXIF folder re-picks the directory. Persisting bookmarks (incremental re-import without re-picking) is deferred.

## 12. Change Log
| Version | Date | Change | Author |
|---------|------|--------|--------|
| v1.0 | 2026-08-05 | Initial draft (PersonaRepository + library + distill flow; 008 encryption seam + filesystem test seam; two StateNotifiers) | Claude |
| v1.0.1 | 2026-08-05 | PR #16 review — added Settings→distill runtime binding seam (`cloudKeyStoreProvider` read-path, aligns with ERD-006 §3.4) | Claude |
| v1.1.0 | 2026-08-07 | Scope expansion — import UI entry point: new `FilePickerFacade` seam (default `file_picker`, `FakeFilePicker` in tests) composed with 002's reused `ImportNotifier.importFiles(...)` at the head of `DistillFlowScreen`; no new import notifier/state. Updated goals, §3 diagram/components, 002 dependency row, §5.2 seam, §7.2 widget tests, `file_picker` dependency. **PR #18 self-review:** seam split into `pickFiles()` / `pickDirectory()` (directory sources need iOS security-scoped bookmark, ERD-002 §676); pinned `^8.0.0`; softened §10 entitlement note; added §11 persistent-bookmark Technical Debt | Claude |
