# PRD-009-Persona Library & Distill

> Product Requirements Document — Persona Library & Distill (persona persistence, library screen, and the distill/creation flow)
>
> **Version**: v1.1.1
> **Status**: ✅ Approved (Project Owner, 2026-08-07)
> **Author**: Claude
> **Date**: 2026-08-05
> **Priority**: P0

---

## 📋 Document Info

| Field | Value |
|-------|-------|
| **PRD ID** | PRD-009 |
| **Related ERD** | ERD-Persona-Library-009-20260805.md |
| **Related Spec** | SPEC-Persona-Library-009-20260805.md |
| **Depends on** | Module 002 (Conversation + `ImportNotifier`/`DataImportService` — the parser/data layer, reused), Module 003 (Persona, PersonaJsonCodec — read-only), Module 004 (LlmPersonaBuilder), Module 007 (model readiness for distill) |
| **Related decisions** | ADR-002, ADR-004, ADR-005 |
| **Approval date** | 2026-08-07 |
| **Approver** | Project Owner |

> **Module map (Phase 4 UI).** The user-facing app is split into three modules, each with its own PRD/ERD/Spec trio: **006 Chat Interface** (the chat screen + chat history), **009 Persona Library & Distill** (this doc — persona persistence, the library, and the distill/creation flow), and **010 Settings** (model-management UI on 007 + runtime/mode + cloud authorization). This module is the **foundation the other two build on**: it owns the `PersonaRepository` that 006 loads from, and the create/keep/reopen/delete lifecycle for personas. It *consumes* the Module 004 `LlmPersonaBuilder` to distill, *reads* model readiness from 007 (routing the install/switch UI to 010), and *reuses* the Module 003 `Persona` shape and `PersonaJsonCodec` without modification. It also **owns the production import entry point** — the file/source-picker UI at the head of the create flow that drives Module 002's `ImportNotifier` to turn a chat export (WeChat, iMessage, …) into a `Conversation`. Module 002 deferred its import UI to Phase 4 (`PRD-Data-Import-002` §out-of-scope); 009 is where that UI lands, because the create flow is the only place a `Conversation` is needed. Parsing itself stays in 002 (unchanged); 009 adds only the UI that invokes it.

---

## 1. Background & Goals

### 1.1 Background

Modules 002–004 and 007 delivered the offline pipeline: import a chat export into a `Conversation` (002), preprocess and split it (003), distill a five-layer `Persona` on a local model (004), with model download/activation managed by 007. Today this pipeline is only exercised through the debug-only harness (`LlmHarnessScreen`, `kDebugMode`), which distills one persona **into memory** and **persists nothing** — quit the app and the persona is gone. There is also no production home content: `home_screen.dart` shows an app-name placeholder plus the dev harness button.

Module 009 turns "creating and keeping a persona" into a production surface. It introduces the **persona persistence layer** (`PersonaRepository`, one `.persona` file per persona under the app documents directory), the **persona library screen** (the new production home: list saved personas, open one to chat, view details, delete, empty state), and the **distill/creation flow** (import a chat export into a `Conversation`, run `LlmPersonaBuilder.build(...)` with progress, review the result honestly, save it). Because the chat screen (006) loads its persona via `PersonaRepository.load(id)`, this module must land first among the Phase-4 UI trio.

**The import-UI gap this closes.** Module 002 shipped the full parser/data layer — the WeChat/iMessage/Weibo/Instagram/EXIF parsers, the `Conversation` model, `DataImportService`, and the `ImportNotifier`/`importStateProvider` state managers — but **explicitly deferred the user-facing import screen** ("导入 UI 的最终视觉设计稿" out of scope; produced by "the Phase-4 UI module"). No Phase-4 module had picked it up, so today `ImportNotifier.importFiles(...)` is reachable only from tests and the sole end-to-end path is the hardcoded sample in the `kDebugMode` `LlmHarnessScreen`. **Importing a real chat export is currently impossible in production.** 009 owns that import UI as the front door of its create flow: pick file(s) → choose source → drive 002's `ImportNotifier` → get a `Conversation` → distill.

### 1.2 Goals

1. **Persist personas durably.** A distilled `Persona` survives app restarts, is enumerable newest-first, and is reloadable by id — the storage contract 006 consumes.
2. **Make the library the home.** Replace the placeholder body of `home_screen.dart` with a persona library: list, open → chat (006), detail view, delete with confirmation, and an inviting empty state.
3. **Own the create flow, import included.** Import a chat export (file/source picker → Module 002 `ImportNotifier` → `Conversation`) → distill via Module 004 with visible progress → review (surfacing "insufficient material" notes and per-layer confidence honestly) → save. This is the first production path from a raw export to a saved persona.
4. **Be honest and never fail silently.** Corrupt/unsupported `.persona` files are skipped (logged, never crash the list); distill failures surface a typed, actionable message; a distill with no ready model routes the user to 010 rather than spinning.
5. **Preserve upstream contracts.** The `Persona` five-layer shape, `PersonaJsonCodec`, `LlmPersonaBuilder`, and the 003 statistical fallback are reused, not modified. Provide an injection seam so Module 008 can encrypt at rest / exclude from backup without changing the repository contract.

### 1.3 Scope

**In scope:**
- **Persona persistence (`PersonaRepository`)** — `save` / `list` / `load` / `delete` over one `${persona.id}.persona` file each, in the app documents directory, encoded with `PersonaJsonCodec`. Corrupt-file-skipping `list`; typed errors on `load`.
- **Persona summaries (`PersonaSummary`)** — a lightweight list projection (id, display name, relation, generatedAt, insufficient-material flag, lowest-layer confidence) so the library need not fully decode every file's heavy fields for display.
- **Persona library screen** — the production home: list (newest first, initials avatar, confidence / "based on limited data" badge), open → push 006 chat, persona detail view (five layers, notes, source summary), delete with confirmation, empty state.
- **Import entry point (UI only)** — a file/source-picker surface at the head of the create flow: choose the `DataSource`, then pick export file(s) or a directory (via `file_picker: ^8.0.0` — file-based sources pick files; iMessage `chat.db` / Photo-EXIF pick a directory with security-scoped access, per ERD-002 §676), and drive Module 002's `ImportNotifier.importFiles(...)` to produce a `Conversation`. 009 owns the *screen and its states* (idle / picking / parsing / done / failed, surfaced from `ImportState`); it reuses 002's parsers/service unchanged. Supported sources are exactly what 002 parses (WeChat, iMessage, Weibo, Instagram, Photo EXIF).
- **Distill / creation flow** — take the just-imported (or previously imported) `Conversation` → run `LlmPersonaBuilder.build(...)` with progress (`idle → running → done → failed`) → review the resulting persona and its honest notes → save via `PersonaRepository`.
- **Model-readiness gate** — read 007 (`getActiveModelHandle`); if no ready/active model, present an actionable prompt routing to the 010 install/activate flow (009 does not implement model management).
- **008 encryption seam** — a byte-transform / codec-wrapper injection point on the repository, mirroring Module 002's `MediaStore` backup-exclusion hook.

**Out of scope (owned elsewhere / deferred):**
- The chat screen and chat-history persistence → **Module 006** (009 only provides `PersonaRepository.load`).
- Model-management UI, runtime/mode selection, cloud authorization, key entry → **Module 010** (009 only reads readiness and routes there).
- Encryption at rest / biometric lock / backup exclusion → **Module 008** (009 provides only the injection seam).
- The distillation engine, Runtime abstraction, prompt engineering, statistical fallback → **Module 004** (reused, not modified).
- **Parsing** of chat exports (the parsers, `DataImportService`, `ImportNotifier`, `Conversation` model) → **Module 002** (reused unchanged; 009 adds only the UI that *invokes* it and consumes the resulting `Conversation`). 009 does **not** modify any parser or add a new source format.
- Persona **editing** (editing hard rules, renaming, re-distilling in place) → future (v1 is create / keep / reopen / delete). An **avatar image** field does not exist in the 003 `Persona` and is not added here (see §10 / Technical Debt).

---

## 2. User Stories

### Story 1 — Create and keep a persona
> As a grieving user who just imported our chat history, I want to distill it into a persona and have it saved, so I can come back to it instead of regenerating every time.

**Acceptance:** From an imported `Conversation`, I run distill, see progress, review the result, and save. The persona then appears in my library and is still there after I force-quit and relaunch.

### Story 2 — Reopen across launches
> As a returning user, I want to reopen a saved persona from a list, so I can start (or continue) a conversation with them.

**Acceptance:** The library lists my saved personas newest-first with their name and relation; tapping one opens the chat screen (006) for that persona.

### Story 3 — Honest about thin material
> As a user whose import had few messages, I want the library and detail view to tell me plainly that this persona is based on limited data, so I set my expectations and trust the app.

**Acceptance:** When `Persona.notes` indicate insufficient material or layers are low-confidence, the list row shows a "based on limited data" badge and the detail view spells out which layers are thin. The distill review step shows the same before I save.

### Story 4 — Delete a persona
> As a user, I want to delete a persona I no longer want, so my library reflects only what I choose to keep.

**Acceptance:** Deleting asks for confirmation, then removes the persona and its file; it disappears from the list immediately and stays gone after restart. Deleting something already gone does not error.

### Story 5 — Know when I can't distill yet
> As a first-run user with no model installed, I want the create flow to tell me plainly that I need a model and take me to where I can get one, rather than failing silently.

**Acceptance:** Starting a distill with no ready/active model shows an actionable prompt that routes to the Module 010 install/activate flow; returning with a ready model lets me distill.

### Story 6 — Import my chat history
> As a new user, I want to import my exported chat history (e.g. a WeChat export) from within the app, so I have a conversation to distill — without needing a debug build.

**Acceptance:** From the create flow I can pick my export file(s), optionally pick the source type, and see parsing progress; on success the resulting `Conversation` flows straight into distill. A cancelled pick returns me to the flow unchanged; an empty selection or a parse failure shows a typed, retryable message (never a silent dead-end).

---

## 3. Feature List

### 3.1 Core features

| # | Feature | Description | Priority |
|---|---------|-------------|----------|
| F1 | `PersonaRepository` persistence | `save` / `list` / `load` / `delete` over one `${persona.id}.persona` file each, via `PersonaJsonCodec`, in the app documents directory | P0 |
| F2 | `PersonaSummary` projection | Lightweight list item (id, displayName, relationToUser, generatedAt, hasInsufficientMaterial, lowestLayerConfidence) derived without exposing raw text | P0 |
| F3 | Persona library screen (home) | Newest-first list; initials avatar; confidence / "limited data" badge; empty state; becomes the production home body (keeps the `kDebugMode` harness button) | P0 |
| F4 | Open → chat handoff | Tapping a persona loads it via `load(id)` and pushes the Module 006 chat screen | P0 |
| F5 | Distill / creation flow | Select an imported `Conversation` → `LlmPersonaBuilder.build(...)` with progress → review honest result → `save` | P0 |
| F6 | Model-readiness gate | Read 007; if no active model, actionable prompt routing to 010 (not a dead spinner) | P0 |
| F7 | Delete with confirmation | Confirm dialog → `delete(id)` (idempotent) → row removed | P0 |
| F8 | Persona detail view | Read-only view of the five layers, tags, memories summary, notes, and source summary | P1 |
| F9 | Corrupt-file resilience | `list` skips corrupt/unsupported files with a log; `load` surfaces a typed error | P0 |
| F10 | Import entry point (UI) | Source + file/directory picker (`file_picker: ^8.0.0`; files for WeChat/Weibo/Instagram, directory + security-scoped access for iMessage-db / Photo-EXIF) at the head of the create flow → drives 002 `ImportNotifier.importFiles(...)` → `Conversation`; surfaces `ImportState` (picking / parsing / done / failed); no parser changes | P0 |

### 3.2 Auxiliary features

| # | Feature | Description | Priority |
|---|---------|-------------|----------|
| A1 | 008 encryption seam | A byte-transform / codec-wrapper injection point so 008 can encrypt / exclude-from-backup without contract change | P1 |
| A2 | Distill progress log | Surface `LlmPersonaBuilder` `onLog` output (chunk count, fallback reason) in the flow UI | P1 |
| A3 | Overwrite-aware save | `save` on an existing id overwrites (last-writer-wins); the review step warns when re-distilling an existing persona id | P2 |
| A4 | Sort / filter library | Sort by generatedAt (default) or name; filter by relation | P2 |

---

## 4. Non-Functional Requirements

### 4.1 Performance
- `list()` of a typical library (tens of personas) completes without blocking the UI; summaries avoid decoding heavy layer bodies where the projection allows (see ERD §4.3).
- Distill inherits Module 004's budget (CLAUDE.md: Persona generation ≤ 60 s / 1000 messages, device- and model-dependent); the flow shows progress throughout and never appears frozen.
- `save` / `load` / `delete` are async and off the UI thread; a single `.persona` file is small (JSON, hashes not raw text).

### 4.2 Security & Privacy
- Personas persist only what the `Persona` already contains — evidence is message-key hashes plus ≤60-grapheme excerpts (per 003/004), never raw import text.
- Files live in the app sandbox (documents directory). 009 exposes an injection seam so Module 008 can encrypt at rest and exclude from iCloud/backup without a contract change.
- Distill honors 004's privacy gating: local by default (original text never leaves the device); cloud is explicit opt-in (authorization owned by 010; 009 honors it). No raw text is written to logs.

### 4.3 Usability
- Every failure state is actionable: corrupt file skipped (library still usable), distill failure explained with retry, no-model prompt routes to 010 — never a dead spinner.
- The library empty state invites the first import/distill.
- "Based on limited data" is surfaced consistently in the list row, the detail view, and the distill review step (honesty per ADR-004).

### 4.4 Compatibility
- iOS 16.0+ (ADR-005); distill quality validated on a physical device (large models cannot run on the simulator).
- Material Design 3, consistent with the existing `LostoneApp` theme; imperative `Navigator` (no router today — see Shared Context / §6).
- Output `.persona` bytes are `PersonaJsonCodec`-compatible and forward-compatible with `kPersonaSchemaVersion` (a file with a higher schema is skipped in `list`, surfaced as `PersonaSchemaException` in `load`).

---

## 5. Data Requirements

### 5.1 Input
- Export file path(s) + optional `DataSource` — picked in 009's import UI, passed to Module 002's `ImportNotifier.importFiles(...)`.
- `Conversation` — an imported, preprocessed conversation from Module 002 (input to distill).
- `LlmBuildOptions` — run mode / model / temperature / split identifiers / default display name (Module 004; defaults local).
- `PersonaRuntime` — the Module 004 runtime (local `LiteRtRuntime` by default), wired from a ready 007 model handle.
- 007 model readiness — `getActiveModelHandle()` (null → route to 010).
- `personaId` — for `load` / `delete` and for the chat handoff.

### 5.2 Output
- `Persona` — the distilled or loaded five-layer model (Module 003 shape, unchanged).
- `.persona` files — one per persona, `PersonaJsonCodec`-encoded bytes, in the app documents directory.
- `List<PersonaSummary>` — the library list projection.

### 5.3 Storage
- One file `${persona.id}.persona` per persona under the app documents directory (`path_provider`); `list()` enumerates the directory. See ERD §4.2.
- Injection seam for Module 008 (encryption / backup exclusion) — a byte-transform / codec wrapper, contract unchanged.
- Host tests use a temp-directory or in-memory filesystem seam; device uses `path_provider`.

---

## 6. Interface Requirements

### 6.1 UI surfaces
- **Persona library screen (home)**: app bar (title + create/distill action), scrollable persona list (initials avatar, display name, relation, relative generatedAt, confidence / "limited data" badge), empty state (invite to create), overflow per-row action (open / view details / delete). Keeps the existing `kDebugMode` harness button.
- **Persona detail view**: read-only five layers, tags, memories summary, notes ("insufficient material"), source summary (message counts, sources, version); actions: open chat, delete.
- **Distill / creation flow**: **import step** (file picker via `file_picker`, optional source selector, parse progress + typed error/retry, sourced from `ImportState`) → source picker (use the just-imported `Conversation`, or choose a previously imported one), run button, progress indicator + log, review card (identity + confidence badges + notes), save / discard; no-model prompt routing to 010; typed error state with retry.

### 6.2 Interaction flows
1. **Import → distill → review → save**: enter create flow → import a chat export (pick file(s) → optional source → 002 `ImportNotifier` parses → `Conversation`) → (readiness check; if no model → route to 010) → run `build(...)` with progress → review honest result → save → return to library showing the new persona. (A previously imported `Conversation` may be reused without re-importing.)
2. **Open → chat**: library → tap a persona → `load(id)` → push the Module 006 chat screen.
3. **Delete**: library → row action delete → confirm → `delete(id)` → row removed.
4. **Corrupt file present**: library `list()` skips it with a log; the rest of the library renders normally.

### 6.3 UI elements
- List row: initials avatar (no image field exists), display name, relation, relative time, confidence / "based on limited data" badge.
- Distill review card: identity, per-layer confidence chips, notes list, save / discard buttons.
- Banners: no-model call-to-action (routes to 010); distill error (typed, with retry).
- Confirm dialog: guards destructive delete.

---

## 7. Interface Dependencies

### 7.1 Provides
- **`PersonaRepository`** — `save` / `list` / `load` / `delete` (see ERD §5 / Spec §2). **Consumed by Module 006** via `load(id)`, and by 010 where it needs persona context.
- **`PersonaSummary`** — the list projection type (see Spec §3).
- **`PersonaStoreException`** — typed I/O error for `load` (schema errors pass through as `PersonaSchemaException`).
- Riverpod providers: `PersonaLibraryNotifier` (list/refresh/delete) and `DistillNotifier` (run distill with progress → save) (see ERD §6.2).
- The production persona library screen (new home body) + persona detail view + distill flow.

### 7.2 Depends on
- **002**: `Conversation` (distill input); `ImportNotifier` / `importStateProvider` / `DataImportService` / `DataSource` / `ParseOptions` — the parser/data layer the 009 import UI drives (reused unchanged).
- **003**: `Persona` + layers, `PersonaJsonCodec` / `PersonaSchemaException` (read-only reuse; not modified).
- **004**: `LlmPersonaBuilder.build(...)`, `LlmBuildOptions`, `PersonaRuntimeMode`, `PersonaRuntime` (distill).
- **007**: `ModelRepository.getActiveModelHandle()` (model readiness; null → route to 010).
- **010** (sibling): the model install/activate + runtime/mode + cloud-authorization UI the readiness gate routes to.
- **008** (future): swaps in an encrypting byte-transform behind the repository's injection seam.

---

## 8. Acceptance Criteria

### 8.1 Persistence
- [ ] `save(persona)` then `list()` returns a summary for that persona; `load(id)` round-trips to an equal `Persona` (via `PersonaJsonCodec`).
- [ ] `list()` returns personas newest-first (by `generatedAt`).
- [ ] Personas survive app restart (files on disk, re-enumerated on next launch).
- [ ] `delete(id)` removes the file; a second `delete(id)` is a no-op (idempotent).
- [ ] `save` with an existing id overwrites that persona's file (last-writer-wins).

### 8.2 Library & handoff
- [ ] The library replaces the placeholder home body and keeps the `kDebugMode` harness button.
- [ ] A persona row shows display name, relation, and a confidence / "limited data" badge derived from `notes` / layer confidence.
- [ ] Empty library shows an inviting empty state (not a blank screen).
- [ ] Tapping a persona loads it and pushes the Module 006 chat screen.

### 8.3 Distill flow
- [ ] The create flow can import a chat export: pick file(s) → optional source → 002 `ImportNotifier.importFiles(...)` → a `Conversation`, with parse progress shown and typed, retryable errors on empty selection / cancel / parse failure (no silent dead-end).
- [ ] The imported `Conversation` flows straight into distill without leaving the flow; parsers/`DataImportService` are unmodified (009 adds UI only).
- [ ] Distilling an imported `Conversation` runs `LlmPersonaBuilder.build(...)`, shows progress, then a review of the result including any "insufficient material" notes.
- [ ] Saving from review persists the persona and returns to the library with it listed.
- [ ] Distill with no ready/active model shows an actionable prompt routing to 010 (not a dead spinner).
- [ ] Distill fallback (empty corpus / maxPrivacy / cloud-unauthorized / parse failure) still produces a valid `Persona` (via 004's statistical fallback) and is saveable, with the fallback noted.

### 8.4 Resilience (no silent failures)
- [ ] A corrupt or higher-schema `.persona` file is skipped by `list()` with a log; the rest of the library renders.
- [ ] `load()` of a corrupt file surfaces a typed error (`PersonaSchemaException` passthrough or `PersonaStoreException`), not a crash.
- [ ] Distill failure surfaces a typed, retryable error; nothing is saved on failure.

### 8.5 Contracts preserved
- [ ] Modules 002/003/004/007 are reused, not modified — including 002's parsers, `DataImportService`, and `ImportNotifier` (009 adds only the import UI that drives them).
- [ ] `.persona` bytes are produced/consumed only by `PersonaJsonCodec`; no new persistence format is introduced.
- [ ] The 008 encryption seam is present and exercised by a wrapper in tests without changing the `PersonaRepository` contract.

---

## 9. Test Strategy

### 9.1 Unit
- `PersonaRepository` against a temp-dir / in-memory filesystem seam: `save → list → load` round-trip; newest-first ordering; `delete` + idempotent re-delete; overwrite semantics; corrupt-file skip in `list`; typed error in `load`; encryption-seam wrapper round-trips.
- `PersonaLibraryNotifier` with a fake repository: load / refresh / delete state transitions; empty state; corrupt-file-skipped still yields a usable list.
- `DistillNotifier` with a fake `LlmPersonaBuilder` / `MockRuntime`: `idle → running → done` (happy path) → save; `idle → running → failed` (typed error, nothing saved); fallback path yields a valid saveable `Persona`; no-model gate.

### 9.2 Widget
- Library screen: list rows, badges, empty state, delete-confirm, open-navigation (mocked), harness button in `kDebugMode`.
- Import step: file-picker invocation (mocked `file_picker`), source selection, `ImportState` progress (picking / parsing / done / failed), empty-selection / cancel / parse-failure typed errors + retry, hand-off of the resulting `Conversation` into distill.
- Distill flow: source picker, progress, review card with notes/confidence, no-model prompt, error/retry, save.

### 9.3 Integration / on-device (UAT)
- Physical device (ADR-005): import → distill on Gemma 3 1B → save → reopen after relaunch → hand off to 006 chat. Host/CI covers structure/contract + widget tests with fakes; quality judged on-device.

---

## 10. Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Persistence overlaps Module 008 (encryption at rest) | Rework | 009 defines the `PersonaRepository` contract + plaintext impl with a byte-transform injection seam; 008 swaps the transform, contract unchanged (mirrors 002 `MediaStore`) |
| No model installed is the common first-run state | Dead-end distill UX | Readiness gate → actionable prompt routing to 010; library still usable without a model |
| Corrupt / higher-schema `.persona` file | Library crash / data loss | `list` skips + logs; `load` surfaces a typed error; never crash the enumeration |
| Users expect avatar images | Perceived incompleteness | 003 `Persona` has no avatar field; use initials + relation + badge; note avatar as future Technical Debt only (do not modify 003) |
| LLM non-determinism → flaky distill tests | Flaky CI | Distill tests use a fake builder / `MockRuntime`; quality judged on-device only |
| Duplicate ids from re-distilling the same `Conversation` | Silent overwrite | `id` is deterministic (004); `save` is last-writer-wins and the review step warns when overwriting an existing id |
| `file_picker` not yet in `pubspec.yaml` (ERD-002 §646 listed it as candidate only) | Import UI cannot pick files | 009 adds `file_picker: ^8.0.0` as a real dependency; import UI wraps it behind the `FilePickerFacade` seam (`pickFiles` / `pickDirectory`) so widget tests mock the picker (no native dialog in host tests) |
| Directory sources (iMessage `chat.db`, Photo-EXIF) need security-scoped access on iOS (ERD-002 §676) | Read fails / silent empty import | `FilePickerFacade.pickDirectory()` returns a security-scoped path; the facade brackets the read with start/stop access. v1 does not persist bookmarks across launches (re-import re-picks) — noted as Technical Debt (ERD-009 §11) |
| Import surface overlaps Module 002's deferred UI | Ownership ambiguity / rework | 009 formally owns the import *UI* (screen + states); 002 keeps parsers/service/`ImportNotifier` — the split is recorded here and in DOCUMENT-STATUS.md so 002 is not reopened |

---

## 11. Milestones

1. Docs approved (PRD + ERD + Spec).
2. TDD: `PersonaRepository` (host, temp-dir/in-memory) → `PersonaLibraryNotifier` → `DistillNotifier`.
3. Library screen + detail view + distill flow widget tests; wire library as the home body.
4. Model-readiness routing to 010; 008 encryption-seam wrapper test.
5. On-device UAT (import → distill → save → reopen → chat, per ADR-005).

---

## 12. Appendix

### 12.1 References
- ADR-002 / ADR-004 / ADR-005 (CLAUDE.md).
- ERD-Persona-Library-009-20260805.md, SPEC-Persona-Library-009-20260805.md.
- Sibling surfaces: PRD-Chat-Interface-006-20260805.md, PRD-Settings-010-20260805.md.
- Upstream contracts: `mobile/lib/models/persona.dart`, `persona_layers.dart`, `mobile/lib/services/persona/persona_codec.dart`, `mobile/lib/services/llm/llm_persona_builder.dart`, `mobile/lib/models/conversation.dart`.

### 12.2 Glossary
- **Persona**: the five-layer character model (Module 003).
- **`.persona` file**: the `PersonaJsonCodec`-encoded, on-disk representation of one persona.
- **PersonaSummary**: a lightweight list projection for the library.
- **Distill**: LLM distillation of a `Conversation` into a `Persona` (Module 004).
- **Insufficient material**: an honest note (ADR-004) when a layer lacks enough source data; surfaced as a badge.

### 12.3 Change log
| Version | Date | Change | Author |
|---------|------|--------|--------|
| v1.0 | 2026-08-05 | Initial draft (persona persistence + library + distill flow; 3-module Phase-4 split) | Claude |
| v1.0.1 | 2026-08-05 | PR #16 review round — trio version bump; no PRD-body change (seam change is ERD-009) | Claude |
| v1.1.0 | 2026-08-07 | Scope expansion — 009 now owns the **production import UI entry point** (file/source picker → 002 `ImportNotifier` → `Conversation`) at the head of the create flow, closing the Phase-4 import-UI gap (002 deferred its UI, no module had claimed it). Parsing stays in 002 (reused unchanged). Added Story 6, F10, import in §1/§3/§5/§6/§8/§9, `file_picker` dependency + risk rows. **PR #18 self-review:** pinned `file_picker: ^8.0.0`; import supports file *and* directory pick (iMessage-db / Photo-EXIF need a security-scoped directory per ERD-002 §676) + added risk row | Claude |
| v1.1.1 | 2026-08-07 | ✅ **Approved (Project Owner)** — trio PRD/ERD/Spec status → Approved, approval date 2026-08-07; development unblocked (matrix row 009 → ✅/✅/✅). No content change | Project Owner |
