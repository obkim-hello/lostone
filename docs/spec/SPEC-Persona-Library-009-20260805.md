# SPEC-009-Persona Library & Distill

> Technical Specification — Persona Library & Distill (persona persistence, library screen, and the distill/creation flow)
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
| **Spec ID** | SPEC-009 |
| **Related PRD** | PRD-Persona-Library-009-20260805.md |
| **Related ERD** | ERD-Persona-Library-009-20260805.md |
| **Depends on** | Module 002 (Conversation + `ImportNotifier`/`importStateProvider`/`DataImportService` — reused), Module 003 (Persona, PersonaJsonCodec — read-only), Module 004 (LlmPersonaBuilder), Module 007 (model readiness) |
| **Related decisions** | ADR-002, ADR-004, ADR-005 |

---

## 1. Overview

This spec defines the exact interfaces, pre/postconditions, edge cases, behaviors, and test cases for Module 009: the `PersonaRepository` persistence layer, the `PersonaLibraryNotifier` and `DistillNotifier` state managers, the **import step** (a `FilePickerFacade` seam composed with Module 002's reused `ImportNotifier`), and the honesty/resilience rules of the library and distill flow. Persisted bytes are exactly `PersonaJsonCodec.encode(persona)`; 009 introduces no second persistence schema and does not modify Modules 002/003/004/007 — including 002's parsers, `DataImportService`, and `ImportNotifier`, which the import step reuses unchanged.

---

## 2. Interface Definitions

### 2.1 `PersonaRepository.save(Persona persona)`
- **Signature**: `Future<void> save(Persona persona)`
- **Preconditions**: `persona.schemaVersion == kPersonaSchemaVersion`; `persona.id` non-empty (a distilled or loaded persona always satisfies this).
- **Behavior**: `codec.encode(persona)` → `transform.onWrite(bytes)` → `directory.writeBytes(persona.id, bytes)`. Writes/overwrites `${persona.id}.persona`.
- **Postconditions**: A subsequent `load(persona.id)` returns a `Persona` equal to the argument (round-trip via codec). A subsequent `list()` includes a `PersonaSummary` for `persona.id`.
- **Errors**: `PersonaStoreException` on write failure (disk full, permission). Does not partially persist a decodable-but-wrong file (write is whole-bytes).

### 2.2 `PersonaRepository.list()`
- **Signature**: `Future<List<PersonaSummary>> list()`
- **Preconditions**: none (an absent/empty directory yields `[]`).
- **Behavior**: enumerate `*.persona`; for each: `readBytes` → `onRead` → `decode` (guarded) → project to `PersonaSummary`. Skip (log + count) any file that fails to read/decode or whose schema exceeds `kPersonaSchemaVersion`. Sort by `generatedAt` descending; ties by `id` ascending.
- **Postconditions**: Returns only successfully decoded summaries, newest first; never throws for a single bad file.
- **Errors**: propagates only a directory-level failure (directory unreadable) as `PersonaStoreException`.

### 2.3 `PersonaRepository.load(String personaId)`
- **Signature**: `Future<Persona> load(String personaId)`
- **Preconditions**: `personaId` non-empty.
- **Behavior**: `readBytes(id)` → null → throw `PersonaStoreException('not found')`; else `onRead` → `codec.decode`.
- **Postconditions**: returns the decoded `Persona` (equal to what `save` wrote).
- **Errors**: `PersonaSchemaException` passes through unchanged (schema too new); any other decode/read error is wrapped as `PersonaStoreException` (with `cause`).

### 2.4 `PersonaRepository.delete(String personaId)`
- **Signature**: `Future<void> delete(String personaId)`
- **Preconditions**: none.
- **Behavior**: `directory.delete(id)`; no-op if the file is absent.
- **Postconditions**: `${id}.persona` no longer exists; `list()` no longer includes it. Idempotent — a second call succeeds with no effect.
- **Errors**: `PersonaStoreException` only on a real removal failure (not on "already absent").

### 2.5 `PersonaLibraryNotifier`
- **`refresh()`**: `Future<void>`. Sets `loading`, calls `repo.list()`, transitions to `ready(summaries, skippedCount)` or `failed(error)` (directory-level failure only).
- **`delete(String id)`**: `Future<void>`. Calls `repo.delete(id)`, then `refresh()`. On repo failure → `failed(error)`, state otherwise unchanged (item not removed from view).
- **Invariant**: an empty library is `ready` with `summaries == []` (not `failed`).

### 2.6 `DistillNotifier`
- **`run(Conversation c, {required PersonaRuntime runtime, LlmBuildOptions options})`**: `Future<void>`.
  - Check `models.getActiveModelHandle()`; null → `failed(noModel)` and return (no build attempted).
  - Else `running` (empty `progressLog`), stream `builder.onLog` lines into `progressLog`, await `builder.build(c, runtime: runtime, options: options)`.
  - Success → `done(persona, usedFallback)`; `usedFallback` is true iff `persona.notes` indicate the 004 statistical fallback fired.
  - Any thrown error → `failed(buildFailed)`. Nothing is saved on `failed`.
- **`save()`**: `Future<void>`. Precondition `phase == done && persona != null`; calls `repo.save(persona)`; on success sets `saved = true`. On failure → `failed(buildFailed)` is not used; surfaces the `PersonaStoreException` to the flow (kept in `error` as a save error) without discarding the reviewed persona.
- **`reset()`**: back to `idle`.

### 2.7 Import step (`FilePickerFacade` + reused `ImportNotifier`)
- **`FilePickerFacade.pick({List<String>? allowedExtensions})`**: `Future<List<String>>`. Returns the selected file paths, or `[]` when the user cancels. Default impl wraps `file_picker`; host tests inject `FakeFilePicker`. 009 introduces no import state type of its own.
- **Import flow contract** (in `DistillFlowScreen`):
  - `pick()` → `[]` (cancel) or empty → surface "No file selected", remain in the flow, attempt nothing (no `importFiles` call). 
  - Non-empty paths → `ref.read(importStateProvider.notifier).importFiles(paths, source: selectedSource)` (Module 002, unchanged). Render `ImportState.phase` (`parsing`/`preprocessing`) as progress.
  - `ImportState.phase == done` → take `ImportState.conversation` and drive `DistillNotifier.run(conversation, ...)`.
  - `ImportState.phase == failed` → show `ImportState.error` with a retry affordance; nothing is distilled or saved.
- **Preconditions**: none (picker may be invoked any time in the flow). **Postconditions**: on `done`, a non-null `Conversation` is available to distill; on cancel/empty/`failed`, flow state is unchanged and no persona is produced.
- **Constraint**: 009 does not parse or transform files itself, does not add a `DataSource`, and does not modify `ImportNotifier`/`DataImportService`.

---

## 3. Data Specs

- **`PersonaSummary`** = `{ id, displayName, relationToUser?, generatedAt(UTC), hasInsufficientMaterial(bool), lowestLayerConfidence(Confidence) }`.
  - `hasInsufficientMaterial` = `persona.notes.any(_isInsufficientMaterialNote)` where the predicate matches the honest "insufficient material" notes 003/004 emit (e.g. notes prefixed to indicate an insufficient layer).
  - `lowestLayerConfidence` = minimum by `Confidence.index` over `identity.confidence`, `expressionStyle.confidence`, `emotionalLogic.confidence`, `relationalBehavior.confidence`.
- **File name**: `${persona.id}.persona`. **Contents**: `PersonaJsonCodec.encode(persona)` bytes, optionally wrapped by `PersonaBytesTransform.onWrite`.
- **`PersonaLibraryState`** = `{ phase(loading|ready|failed), summaries, error?, skippedCount }`.
- **`DistillState`** = `{ phase(idle|running|done|failed), progressLog, persona?, usedFallback, error?(noModel|buildFailed), saved }`.

---

## 4. Edge Cases

| # | Case | Expected behavior |
|---|------|-------------------|
| E1 | Empty library (no files) | `list()` → `[]`; screen shows empty state; `ready` not `failed` |
| E2 | Corrupt `.persona` (bad JSON) | Skipped by `list()` (log + `skippedCount++`); `load()` → `PersonaStoreException` |
| E3 | Higher-schema `.persona` (`schemaVersion > kPersonaSchemaVersion`) | Skipped by `list()` (log); `load()` → `PersonaSchemaException` (passthrough) |
| E4 | `save` with an existing id | Overwrites the file (last-writer-wins); `list()` shows one entry, updated |
| E5 | `delete` of a missing id | No-op, no error (idempotent) |
| E6 | Double `delete` | Second call is a no-op |
| E7 | Distill with no ready/active model | `run` → `failed(noModel)`; no build attempted; UI routes to Module 010 |
| E8 | Distill falls back to statistical engine (empty corpus / maxPrivacy / cloud-unauthorized / parse failure) | `build` returns a valid `Persona` with fallback `notes`; `done(usedFallback=true)`; saveable |
| E9 | Distill on empty `Conversation` (no messages) | 004 returns a valid statistical persona (per its contract); `done(usedFallback=true)`; saveable |
| E10 | Distill build throws | `failed(buildFailed)`; nothing saved; retry available |
| E11 | `save` fails after a successful distill | `error` set (save error); reviewed `persona` retained so the user can retry save |
| E12 | Missing / partial identity (empty displayName) | 004 guarantees a non-empty `displayName` (defaulted); summary still valid; UI uses initials from it |
| E13 | Two files decode to the same id (shouldn't happen; ids are file names) | File name is the id, so this cannot occur; a stray non-`.persona` file is ignored by enumeration |
| E14 | Directory itself unreadable | `list()` → `PersonaStoreException`; `PersonaLibraryNotifier` → `failed(error)` |
| E15 | Import picker cancelled | `pick()` → `[]`; "No file selected"; no `importFiles` call; flow unchanged |
| E16 | Import empty selection | `importFiles([])` → 002 sets `ImportPhase.failed` ("No files selected"); shown with retry; nothing distilled |
| E17 | Import parse failure | 002 `ImportState.phase == failed` (bad/unsupported file); typed `error` shown with retry; nothing distilled or saved |
| E18 | Import success → distill | `ImportState.phase == done`, non-null `conversation`; handed to `DistillNotifier.run(...)` |

---

## 5. Behavior Specs

- **Round-trip fidelity**: `load(id)` after `save(p)` returns a `Persona` equal to `p` (relies on `PersonaJsonCodec` losslessness; 009 adds no lossy transform beyond the optional 008 seam, which must itself round-trip).
- **Ordering**: `list()` is deterministic — `generatedAt` desc, then `id` asc.
- **Resilience**: exactly one bad file among N never reduces the visible library to a failure; the other N-1 render.
- **Honesty**: `hasInsufficientMaterial` / `lowestLayerConfidence` drive the "based on limited data" badge in the list, the detail view, and the distill review — consistently.
- **No silent failures**: every failure is a typed state (`failed(...)`, `PersonaStoreException`, `PersonaSchemaException`) surfaced to the UI; no swallowed exception, no fabricated persona (004 owns the honest fallback).
- **Privacy**: no raw import text is written by 009 beyond what `Persona` already carries; logs contain ids/error classes only.
- **Seam neutrality**: with the default identity `PersonaBytesTransform`, on-disk bytes are exactly `PersonaJsonCodec.encode(persona)`; swapping in an 008 transform changes bytes-at-rest only, not the `PersonaRepository` contract or in-memory results.

---

## 6. Performance Specs

- `save` / `load` / `delete`: single small-file I/O, async, off the UI thread.
- `list`: O(N) file reads + decodes + an O(N log N) sort; async; for tens of personas completes without visible jank. Optional header-only `summarize` seam avoids materializing memories/tags.
- Distill: inherits Module 004's budget (≤ 60 s / 1000 messages, device/model-dependent, ADR-005); progress rendered throughout.

---

## 7. Test Specs

> Host tests use a `MemoryPersonaDirectory` (or temp dir) + a fake/`MockRuntime`-backed `LlmPersonaBuilder`. No device required for C1–C13.

| ID | Case | Setup | Assertion |
|----|------|-------|-----------|
| C1 | Save → list → load round-trip | `save(p)` then `list()`, `load(p.id)` | `list()` has one summary for `p.id`; `load` equals `p` |
| C2 | Newest-first ordering | Save three personas with increasing `generatedAt` | `list()` order is newest → oldest; ties broken by `id` asc |
| C3 | Delete removes and is idempotent | `save(p)`, `delete(p.id)`, `delete(p.id)` | After first delete `list()` excludes it; second delete does not throw |
| C4 | Overwrite semantics | `save(p)` then `save(p')` with same id, different content | `list()` has one entry; `load` returns `p'` |
| C5 | Corrupt file skipped in list | Write garbage bytes as `x.persona` + one valid persona | `list()` returns the valid one; `skippedCount == 1`; no throw |
| C6 | Corrupt file typed error on load | Garbage `x.persona` | `load('x')` throws `PersonaStoreException` |
| C7 | Higher-schema skipped / passthrough | Write a persona JSON with `schemaVersion = kPersonaSchemaVersion + 1` | `list()` skips it (logged); `load` throws `PersonaSchemaException` |
| C8 | Missing id on load | empty directory | `load('nope')` throws `PersonaStoreException` |
| C9 | Empty library | empty directory | `list()` == `[]`; `PersonaLibraryNotifier` → `ready([], 0)` |
| C10 | Encryption-seam round-trip | `FilePersonaRepository` with a non-identity `PersonaBytesTransform` (e.g. reversible XOR) | `save` then `load` equals `p`; on-disk bytes differ from `PersonaJsonCodec.encode(p)` |
| C11 | Summary derivation | Persona with an "insufficient material" note + a `low` layer | `hasInsufficientMaterial == true`; `lowestLayerConfidence == low` |
| C12 | Library delete flow | `PersonaLibraryNotifier` (fake repo) with two personas → `delete(one)` | State transitions to `ready` with one summary; deleted id absent |
| C13 | Distill happy path → save | `DistillNotifier` with fake builder returning a persona + `MockRuntime`, ready model | `idle→running→done(persona)`; `save()` → `saved`; repo has the persona |
| C14 | Distill fallback | Fake builder returns a persona carrying fallback notes | `done(usedFallback=true)`; persona is valid and saveable |
| C15 | Distill no model | `getActiveModelHandle()` → null | `run` → `failed(noModel)`; builder never invoked |
| C16 | Distill build throws | Fake builder throws | `failed(buildFailed)`; nothing saved; `reset()` returns to `idle` |
| C17 | Distill on empty conversation | Empty `Conversation`, ready model, real `DefaultLlmPersonaBuilder` + `MockRuntime` | `done` with a valid persona (statistical), `usedFallback=true`; saveable |
| C18 | Save failure after distill | Fake repo whose `save` throws | `error` set (save error); `state.persona` retained for retry |
| C19 (widget) | Library rows + badge + empty state | Pump `PersonaLibraryScreen` with fake state | Rows show name/relation/badge; empty state shown when `summaries == []`; `kDebugMode` harness button present |
| C20 (widget) | Distill flow states | Pump distill flow through idle/running/done/failed | Progress + log on running; review card + notes on done; no-model prompt routes to 010; error + retry on failed |
| C22 (widget) | Import cancel / empty | Pump import step with `FakeFilePicker` returning `[]` | "No file selected"; `importFiles` not called; no distill |
| C23 (widget) | Import parse failure | `FakeFilePicker` returns a path; fake `ImportNotifier` → `failed(error)` | Error + retry shown; nothing distilled or saved |
| C24 (widget) | Import success → distill hand-off | `FakeFilePicker` returns a path; fake `ImportNotifier` → `done(conversation)` | `conversation` passed to `DistillNotifier.run(...)`; flow advances to distill |
| C21 (device, ADR-005) | End-to-end | Physical device, Gemma 3 1B | Real import (pick a WeChat export) → distill → save → relaunch → `list` shows it → `load` → push 006 chat |

---

## 8. Dependencies
- **002**: `Conversation` (distill input); `ImportNotifier` / `importStateProvider` / `DataImportService` / `DataSource` / `ParseOptions` — the parser/data layer the import step drives (reused unchanged).
- **003**: `Persona`, `persona_layers.dart`, `PersonaJsonCodec`, `PersonaSchemaException`, `Confidence` (read-only reuse).
- **004**: `LlmPersonaBuilder.build`, `LlmBuildOptions`, `PersonaRuntime`, `PersonaRuntimeMode` (distillation; not modified).
- **007**: `ModelRepository.getActiveModelHandle()` (model readiness).
- **010** (sibling): route target for the no-model prompt.
- **008** (future): encrypting `PersonaBytesTransform` + backup exclusion via the seam.
- Package: `path_provider` (app documents directory) — device only; tests use the filesystem seam.
- Package: `file_picker` (import step) — device only, behind `FilePickerFacade`; tests inject `FakeFilePicker`. New dependency (ERD-002 listed it as candidate only).

## 9. Constraints
- No modification to Modules 002/003/004/007; `Persona` gets no new field (no avatar).
- Persisted bytes are exactly `PersonaJsonCodec.encode` (plus optional 008 transform); no second persistence schema.
- Files under the app documents directory, one `${id}.persona` each; ids are the deterministic 004-derived persona ids.
- Riverpod: `StateNotifier` + top-level provider, immutable state, injected defaults (matches `import_providers.dart`).
- Navigation: imperative `Navigator`; library is the home body; `go_router` deferred (Technical Debt).

## 10. Acceptance Criteria
- [ ] `save → list → load` round-trips to an equal `Persona`; `list` is newest-first (C1, C2).
- [ ] `delete` removes the file and is idempotent (C3).
- [ ] `save` on an existing id overwrites (C4).
- [ ] Corrupt / higher-schema files are skipped by `list` (logged, counted) and produce typed errors on `load` (C5–C7).
- [ ] Empty library is a valid `ready` state with an empty list (C9).
- [ ] The 008 encryption seam round-trips without changing the contract (C10).
- [ ] `PersonaSummary` derives `hasInsufficientMaterial` / `lowestLayerConfidence` correctly (C11).
- [ ] Distill: happy path → done → save; fallback → valid saveable persona; no-model → gated to 010; build error → failed, nothing saved (C13–C18).
- [ ] Library and distill widgets render rows/badges/empty/progress/review/no-model/error states (C19, C20).
- [ ] Import step: cancel/empty → no distill; parse failure → typed retryable error; success → `Conversation` handed to distill (C22–C24).
- [ ] On-device: real import → distill → save → reopen → chat handoff works (C21).
- [ ] Modules 002/003/004/007 are unmodified (parsers/`DataImportService`/`ImportNotifier` reused as-is); no new persistence format introduced.

## 11. Change Log
| Version | Date | Change | Author |
|---------|------|--------|--------|
| v1.0 | 2026-08-05 | Initial draft (PersonaRepository + PersonaSummary + notifiers; edge cases, behaviors, C1–C21 test specs) | Claude |
| v1.0.1 | 2026-08-05 | PR #16 review round — trio version bump; no spec-body change (seam change is ERD-009) | Claude |
| v1.1.0 | 2026-08-07 | Scope expansion — import step spec: §2.7 `FilePickerFacade` + reused 002 `ImportNotifier` contract, edge cases E15–E18, tests C22–C24 (+ C21 uses a real import), `file_picker` dependency, acceptance updated | Claude |
