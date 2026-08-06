# PRD-006-Chat Interface

> Product Requirements Document — Chat Interface (streaming conversation with a saved persona + chat history persistence)
>
> **Version**: v1.0 (draft)
> **Status**: 📝 Draft (pending review)
> **Author**: Claude
> **Date**: 2026-08-05
> **Priority**: P0

---

## 📋 Document Info

| Field | Value |
|-------|-------|
| **PRD ID** | PRD-006 |
| **Related ERD** | ERD-Chat-Interface-006-20260805.md |
| **Related Spec** | SPEC-Chat-Interface-006-20260805.md |
| **Depends on** | Module 004 (`ChatEngine`, `PersonaRuntime`, `ChatTurn`/`ChatOptions`/`ChatDelta`/`ChatSession`, `PersonaRuntimeMode`, `RuntimeError`), Module 007 (`ModelRepository` — model status & active handle), Module 009 (`PersonaRepository` — load a saved `Persona`), Module 003 (`Persona`, `PromptTemplate` — read-only reuse) |
| **Related decisions** | ADR-002 (hybrid model strategy), ADR-004 (LLM distillation; conversation has no statistical fallback), ADR-005 (flutter_gemma / LiteRT-LM) |
| **Approval date** | — |
| **Approver** | — |

> **Module map (Phase 4 UI).** The user-facing app is split into three modules, each with its own PRD/ERD/Spec trio: **006 Chat Interface** (this doc — the chat screen + chat history), **009 Persona Library & Distill** (persona persistence, library, and the distill/creation flow), and **010 Settings** (model-management UI on 007 + runtime/mode + cloud authorization). This PRD owns only the conversation surface and its history; it *consumes* a `Persona` loaded by 009 and *reads* model readiness from 007 (with the install/switch UI living in 010).

---

## 1. Background & Goals

### 1.1 Background

Modules 002–004 and 007 delivered the offline pipeline (import → distill → stream in-character replies on a local model), but it is exercised only through a debug-only harness (`LlmHarnessScreen`, `kDebugMode`) that keeps one persona in memory and persists nothing. Module 006 turns the conversation itself into a production surface: a **chat screen** that streams a saved persona's replies token-by-token, plus **durable chat history** so a user can leave and return to an ongoing conversation with a loved one.

Chat history persistence does not exist today (there is no database wiring in the app). Per the project tech stack (CLAUDE.md: SQLite for chat records / persona metadata), Module 006 introduces the SQLite-backed conversation store.

### 1.2 Goals

1. Stream in-character replies that feel human (incremental, responsive, never breaking character).
2. **Persist conversations** per persona so history survives app restarts and is reloaded on reopen.
3. Handle every non-happy path honestly: empty input, no model, cloud not authorized, max-privacy, mid-stream failure, and hard-rule-guard interception — no dead spinners, no silent failures.
4. Preserve upstream contracts: system prompt comes **only** from `PromptTemplate.render()`; conversation has **no statistical fallback** (SPEC-004 §2.4); the `Persona` five-layer shape is unchanged; Modules 003/004 are reused, not modified.

### 1.3 Scope

**In scope:**
- **Chat screen** — message list + composer; `ChatEngine.chat(...)` streaming into a live persona bubble; auto-scroll; app-bar persona identity + confidence/"insufficient material" indicator.
- **Streaming & cancel** — render `ChatDelta` frames incrementally; stop generation mid-stream cleanly (cancel the subscription; retain partial text).
- **Chat history persistence (SQLite)** — a `ChatHistoryRepository`: create session, append turns, list sessions per persona, load turns, delete session. Reconstructs `List<ChatTurn>` for `ChatEngine.chat(...)`.
- **Error & guard states** — distinct, actionable UI per `RuntimeError` case (empty input, model unavailable, cloud unauthorized, max-privacy) and per guard interception (surface the safe reply, in character).
- **Model-readiness read** — consult 007 `ModelRepository` (is a model ready & active?); when not, present an actionable prompt that routes to the 010 install/activate flow (006 does not implement model management itself).

**Out of scope (owned elsewhere / deferred):**
- Persona persistence, library, and the distill/creation flow → **Module 009**.
- Model-management UI, runtime/mode selection, cloud authorization, key entry → **Module 010**.
- Encryption at rest / biometric lock / backup exclusion → **Module 008** (006 provides only an injection seam on the SQLite store).
- Cloud provider HTTP transport (the wire) → Module 004 integration slice (006 consumes the abstraction + authorization gate only).
- Voice / images / rich media; multi-persona group chat → future (v1 is text, 1:1).

---

## 2. User Stories

### Story 1 — Talk and feel it streaming
> As a grieving user, I want replies to flow in, in their voice, so the conversation feels alive rather than like a form submission.

**Acceptance:** Sending a message streams the reply token-by-token; I can stop mid-reply; the persona never says "I am an AI" or violates its hard rules.

### Story 2 — Pick up where I left off
> As a user, I want my conversation saved, so that when I reopen the app days later I can continue the same thread instead of starting over.

**Acceptance:** After force-quit and relaunch, opening the persona shows my previous messages; new turns append to the saved session.

### Story 3 — Know why it can't answer
> As a user with no model installed (or in max-privacy mode), I want the app to tell me plainly what's wrong and how to fix it.

**Acceptance:** No active model → a clear state with an action that routes to the install flow (010). Max-privacy / cloud-unauthorized → specific, honest messages; no network call is made.

### Story 4 — Honest about thin material
> As a user whose import had few messages, I want the chat header to signal the persona is based on limited data.

**Acceptance:** When `Persona.notes` indicate insufficient material or layers are low-confidence, the chat header surfaces it.

---

## 3. Feature List

### 3.1 Core features

| # | Feature | Description | Priority |
|---|---------|-------------|----------|
| F1 | Chat screen | Message list + composer; app bar shows persona display name + confidence/notes indicator | P0 |
| F2 | Streaming replies | Render `ChatDelta.append` frames into a live persona bubble; finish on `ChatDelta.finish` | P0 |
| F3 | Cancel generation | Stop an in-flight reply mid-stream; keep partial text; no exception | P0 |
| F4 | Chat history (SQLite) | `ChatHistoryRepository`: session + turns per persona; reload on open; append on each turn | P0 |
| F5 | Error & guard states | Typed UI for `emptyInput` / `modelUnavailable` / `unauthorized` / max-privacy / mid-stream failure; guard safe-reply surfaced in character | P0 |
| F6 | Model-readiness prompt | Read 007 state; if no active model, actionable prompt routing to 010 install/activate | P0 |

### 3.2 Auxiliary features

| # | Feature | Description | Priority |
|---|---------|-------------|----------|
| F7 | Regenerate last reply | Re-run the last turn (new sample) | P2 |
| F8 | Multiple sessions per persona | List/switch/delete conversation threads for one persona | P1 |
| F9 | Session delete confirmation | Guard destructive delete with a confirm dialog | P1 |
| F10 | Copy message | Long-press to copy a bubble's text | P2 |

---

## 4. Non-Functional Requirements

### 4.1 Performance
- First streamed token visible within the model's TTFT budget (ADR-005: local target > 5 tok/s decode; TTFT measured on device, not asserted here).
- UI stays responsive during generation (no jank on the message list; streaming off the platform thread).
- History reads are async and do not block the UI, even for long threads.

### 4.2 Security & Privacy
- Local by default: original text never leaves the device; cloud requires explicit authorization (gate owned by 010; 006 honors it).
- SQLite history is stored in the app sandbox; 006 exposes an injection seam so Module 008 can encrypt it later without contract change.
- 006 must not persist anything the persona itself doesn't already contain (no raw import text beyond what the user typed / the persona said).

### 4.3 Usability
- Every failure state is actionable (tells the user what to do), never a dead spinner.
- Streaming feels human (guard lookback prevents leaked violations — per 004).
- Empty state (no messages yet) invites the first message.

### 4.4 Compatibility
- iOS 16.0+ (ADR-005); large models require a physical device.
- Material Design 3, consistent with the existing `LostoneApp` theme.

---

## 5. Data Requirements

### 5.1 Input
- `Persona` — loaded by Module 009's `PersonaRepository.load(id)`.
- `ChatTurn` history (from `ChatHistoryRepository`) + the new user message → `ChatEngine.chat(...)`.
- 007 `ModelRepository` state (active handle / model readiness).
- Active `ChatOptions` (mode, temperature, context window) — defaults local; mode/authorization sourced from 010's settings.

### 5.2 Output
- Streamed `ChatDelta` frames rendered into the chat UI.
- Persisted chat sessions + turns in SQLite.

### 5.3 Storage
- SQLite database in the app documents/support directory: `sessions` and `turns` tables (see ERD §4.2). Keyed by persona id.
- Injection seam for Module 008 (encryption / backup exclusion).

---

## 6. Interface Requirements

### 6.1 UI surfaces
- **Chat screen**: app bar (persona display name + confidence/notes indicator + optional session menu), scrollable message list (user right / persona left; live streaming bubble), composer (multiline field + send/stop), inline error/guard banners, "no model — install" call-to-action routing to 010.

### 6.2 Interaction flows
1. **Open → reload history → chat**: enter from library (009) → load persona + latest session turns → render → chat.
2. **Send → stream → stop**: type → send (persist user turn) → tokens stream into live bubble → optionally stop → persist final persona turn.
3. **No model → install**: open chat with no active model → actionable prompt → route to 010 install/activate → return → chat.

### 6.3 UI elements
- Chat bubble: user vs persona styling; streaming bubble shows a typing/caret affordance.
- Composer: multiline text field; send button becomes stop during generation.
- Error banner: typed to the `RuntimeError`/guard case with an action where applicable.

---

## 7. Interface Dependencies

### 7.1 Provides
- `ChatHistoryRepository` (new, SQLite) — session/turn CRUD keyed by persona id (see ERD §5 / Spec §2).
- Riverpod providers for the chat session/streaming state and model-readiness (see ERD §6.2).
- Production chat screen.

### 7.2 Depends on
- **004**: `ChatEngine.chat(...)`, `PersonaRuntime` (`LiteRtRuntime` + `FlutterGemmaEngine`, `CloudRuntime`, `FallbackRuntime`), `ChatTurn`/`ChatOptions`/`ChatDelta`/`ChatSession`, `PersonaRuntimeMode`, `RuntimeError`.
- **007**: `ModelRepository.getActiveModelHandle`, `stateOf`, `installed`.
- **009**: `PersonaRepository.load(id)` (and `PersonaSummary` for entry context).
- **003**: `Persona` + layers, `PromptTemplate` (read-only reuse; not modified).

---

## 8. Acceptance Criteria

### 8.1 Chat
- [ ] Sending a message streams the reply incrementally, ending with a finish frame.
- [ ] Cancel stops generation mid-stream without exception; partial text is retained.
- [ ] The persona never emits a hard-rule violation; the guard's safe reply is shown instead, in character.

### 8.2 History
- [ ] A conversation survives app restart and reloads on reopen.
- [ ] Each user and persona turn is persisted; sessions are keyed by persona id.
- [ ] Deleting a session removes it and its turns.

### 8.3 Error handling (no silent failures)
- [ ] No active model → actionable "install a model" state routing to 010 (not a dead spinner).
- [ ] Max-privacy → generation disabled with an explicit message.
- [ ] Cloud selected but not authorized → explicit message; no network call is made.
- [ ] Mid-stream runtime failure → typed error banner; partial reply retained; retry available.

### 8.4 Contracts preserved
- [ ] System prompt is produced only by `PromptTemplate.render()`.
- [ ] Chat has no statistical fallback (matches SPEC-004 §2.4).
- [ ] Modules 003 and 004 are reused, not modified.

---

## 9. Test Strategy

### 9.1 Unit
- `ChatHistoryRepository` against an in-memory / temp SQLite db: create→append→list→load round-trip, delete, ordering by `at`.
- Chat session state notifier with a `MockRuntime`: streaming accumulation, cancel, each `RuntimeError` case, guard interception.

### 9.2 Widget
- Chat screen with a `MockRuntime`-backed engine: bubbles render, streaming updates, stop button, error banners, empty/no-model states.

### 9.3 Integration / on-device (UAT)
- Physical device (ADR-005): chat with Gemma 3 1B; judge fidelity + guard behavior; verify history reload. Non-blocking for host CI (host = structure/contract + widget tests with mocks).

---

## 10. Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Chat history overlaps Module 008 (encryption) | Rework | 006 defines the repository contract + plaintext SQLite impl with an encryption injection seam; 008 swaps the backend, contract unchanged |
| No model installed is the common first-run state | Dead-end UX | Actionable prompt routing to 010; chat degrades gracefully |
| LLM non-determinism → flaky UI tests | Flaky CI | All host/widget tests use `MockRuntime`; quality judged on-device only |
| SQLite plugin (sqflite) needs device/platform channels | Host tests can't hit real db | Repository behind an interface; host tests use `sqflite_common_ffi` (in-memory) or a fake; device uses `sqflite` |

---

## 11. Milestones

1. Docs approved (PRD + ERD + Spec) — and 009 approved (chat needs a persona to load).
2. TDD: `ChatHistoryRepository` (host, ffi) → chat session provider → chat screen widget tests.
3. Model-readiness prompt wiring to 010.
4. On-device UAT (physical device, per ADR-005).

---

## 12. Appendix

### 12.1 References
- ADR-002 / ADR-004 / ADR-005 (CLAUDE.md).
- ERD-Chat-Interface-006-20260805.md, SPEC-Chat-Interface-006-20260805.md.
- Sibling surfaces: PRD-Persona-Library-009-20260805.md, PRD-Settings-010-20260805.md.

### 12.2 Glossary
- **Persona**: the five-layer character model (Module 003).
- **Runtime**: `PersonaRuntime` inference backend (local LiteRT / cloud / fallback).
- **Hard-rule guard**: output post-filter preventing character-breaking / forbidden output (Module 004).
- **Session / turn**: a conversation thread and one message within it (SQLite history model).

### 12.3 Change log
| Version | Date | Change | Author |
|---------|------|--------|--------|
| v1.0 | 2026-08-05 | Initial draft (narrowed to chat + history after the 3-module split) | Claude |
