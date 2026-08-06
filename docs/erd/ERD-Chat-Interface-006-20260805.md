# ERD-006-Chat Interface

> Engineering Requirements Document — Chat Interface (streaming conversation + SQLite chat history)
>
> **Version**: v1.0.1 (draft)
> **Status**: 📝 Draft (pending review)
> **Author**: Claude
> **Date**: 2026-08-05

---

## 📋 Document Info

| Field | Value |
|-------|-------|
| **ERD ID** | ERD-006 |
| **Related PRD** | PRD-Chat-Interface-006-20260805.md |
| **Related Spec** | SPEC-Chat-Interface-006-20260805.md |
| **Depends on** | Module 004 (`ChatEngine`, `PersonaRuntime`, `ChatTurn`/`ChatOptions`/`ChatDelta`/`ChatSession`, `PersonaRuntimeMode`, `RuntimeError`), Module 007 (`ModelRepository` — active handle / `stateOf` / `installed`), Module 009 (`PersonaRepository.load`), Module 010 (`appSettingsProvider` + `cloudKeyStoreProvider` — mode/auth/key read-path, §3.4), Module 003 (`Persona` + `PromptTemplate`, read-only) |
| **Related decisions** | ADR-002 (hybrid model strategy), ADR-004 (LLM distillation; conversation has no statistical fallback), ADR-005 (flutter_gemma / LiteRT-LM) |

> **Module map (Phase 4 UI).** This ERD engineers only the **conversation surface + its history store**. Persona persistence/library/distill flow is Module 009; model-management UI, runtime/mode selection, and cloud authorization live in Module 010; encryption at rest / backup exclusion is Module 008. This module *consumes* a `Persona` from 009, *reads* model readiness from 007, and *drives* 004's `ChatEngine`. It **owns** the new `ChatHistoryRepository` (SQLite).

---

## 1. Technical Goals

### 1.1 Core

- Define a production **chat screen** (`ChatScreen`) whose widget tree renders a persisted conversation, streams a live persona reply, and surfaces every error/guard state honestly.
- Define a **`ChatSessionNotifier`** (legacy Riverpod `StateNotifier`) that owns the conversation lifecycle: load persona (009) → load/create session + turns (`ChatHistoryRepository`) → drive `ChatEngine.chat(...)` → accumulate `ChatDelta` into a live bubble → persist user turn on send and persona turn on finish → cancel cleanly.
- Define the **`ChatHistoryRepository`** contract (SQLite) owned by this module: create session, append turn, list sessions per persona, load turns, delete session (cascade). Reconstructs `List<ChatTurn>` to feed `ChatEngine.chat(...)`.
- Define the **model-readiness read** against 007 (`getActiveModelHandle` / `stateOf` / `installed`) and an actionable "no model" prompt that routes to Module 010's install/activate flow.
- Define the mapping from each `RuntimeError` case and the guard-interception case to a distinct, actionable UI state — no dead spinners, no silent failures.

### 1.2 Performance

- First streamed token rendered within the model's TTFT budget (ADR-005: local target > 5 tok/s decode; TTFT measured on device, not asserted host-side).
- Streaming and history I/O run off the UI thread; the message list never janks during generation (see §8).
- History reads are async and paged-friendly; opening a long thread does not block the first frame.

### 1.3 Quality

- Host + widget tests are fully deterministic via `MockRuntime` (fixed token stream) and in-memory `sqflite_common_ffi`; LLM quality is judged on-device only (ADR-005).
- Contracts preserved: system prompt comes **only** from `PromptTemplate.render(persona)`; conversation has **no statistical fallback**; Modules 003/004/007 are reused, not modified.
- Coverage target > 80% on the deterministic surface (repository + notifier).

---

## 2. Design Constraints

### 2.1 Technical

- **Upstream contracts are fixed.** `ChatEngine.chat(persona, history, userMessage, {required runtime, options})` returns `Stream<ChatDelta>`; the module consumes it exactly as-is (see the pinned signature in §5.1). It must not re-render or re-inject the system prompt — that is `PromptTemplate.render(persona)` inside 004.
- **No statistical fallback for conversation** (ADR-004 / SPEC-004 §2.4). When no model is ready / `maxPrivacy` / cloud-unauthorized, `ChatEngine` emits `ChatDelta.failure(...)`; the UI surfaces it, it does **not** degrade to a statistical reply.
- **Runtime wiring is reused from the harness**: `LiteRtRuntime(engine: const FlutterGemmaEngine(), activeHandle: repo.getActiveModelHandle)`, `DefaultChatEngine()`; `initGemmaRuntime()` must complete before the first `chat(...)`. The chosen `PersonaRuntime` is constructor-injected into the notifier for test substitution (`MockRuntime`).
- **Persona has no avatar field** (Module 003 is read-only). The chat header derives its identity block from `identity.displayName` + `identity.relationToUser` + a confidence/"insufficient material" indicator computed from `Persona.notes` and per-layer `Confidence{low,medium,high}`. Do **not** add fields to Module 003.
- **SQLite behind an interface.** Host tests use `sqflite_common_ffi` (in-memory); device uses `sqflite`. The repository takes an injected `DatabaseFactory` + database path so Module 008 can swap an encrypted backend / backup-excluded path without changing the contract.
- **Navigation is imperative.** The app has no router (`app.dart` sets `home: HomeScreen`; `home_screen.dart` uses `Navigator.of(context).push(MaterialPageRoute(...))`). v1 keeps imperative `Navigator` + a light screen factory. `go_router` adoption is deferred (see §11).
- **Riverpod style is legacy** `StateNotifier<State>` + top-level `final StateNotifierProvider<Notifier, State> xProvider`, immutable state classes, constructor-injected services with test-friendly defaults — matching `import_providers.dart`.

### 2.2 Business

- Local by default: original text never leaves the device; cloud requires explicit authorization (gate owned by 010, honored here). No network call is issued when cloud is selected but unauthorized.
- History is stored only in the app sandbox; the module persists nothing beyond what the user typed and what the persona said (no raw import text).

### 2.3 Timeline

- Blocked on: PRD/ERD/Spec 006 approval **and** Module 009 approval (chat needs a `Persona` to load). 004 and 007 are already approved/implemented.
- Sequence: `ChatHistoryRepository` (host, ffi) → `ChatSessionNotifier` (host, `MockRuntime`) → `ChatScreen` widget tests → on-device UAT (physical device, per ADR-005).

---

## 3. Architecture

### 3.1 Component diagram

```
┌──────────────────────────────────────────────────────────────────────┐
│  Module 006 — Chat Interface (Phase 4 UI)                              │
│                                                                        │
│  ChatScreen (Widget)                                                   │
│    ├─ ChatAppBar        displayName + relationToUser + confidence chip │
│    ├─ MessageList        user (right) / persona (left) + live bubble   │
│    ├─ Composer           multiline field; Send ⇄ Stop                  │
│    └─ StateBanner        typed error / guard / no-model CTA → 010      │
│           │ watch / read                                               │
│           ▼                                                            │
│  chatSessionProvider : StateNotifierProvider<ChatSessionNotifier,      │
│                                               ChatSessionState>        │
│    ChatSessionNotifier                                                 │
│      ├─ loadPersona(id)   → 009 PersonaRepository.load(id)             │
│      ├─ openLatestSession / openSession(sessionId)                     │
│      │        → 006 ChatHistoryRepository (sessionsFor / turnsOf /     │
│      │                                      createSession)             │
│      ├─ send(text)        → 004 ChatEngine.chat(...) → Stream<ChatDelta>│
│      │        accumulate .append → live bubble; persist on send/finish │
│      ├─ cancel()          → StreamSubscription.cancel(); retain partial │
│      └─ modelReadiness    → 007 ModelRepository stateOf/installed/      │
│                             getActiveModelHandle                       │
│                                                                        │
│  ChatHistoryRepository (owned here) ──► SQLite (sessions, turns)       │
│      DatabaseFactory injected (ffi host / sqflite device / 008 encrypt)│
└──────────────────────────────────────────────────────────────────────┘
        │ reused, not modified
        ▼
  004 ChatEngine / PersonaRuntime (LiteRtRuntime + FlutterGemmaEngine)
  003 Persona + PromptTemplate.render()   007 ModelRepository   009 PersonaRepository
```

### 3.2 Component design

| Component | Type | Responsibility |
|-----------|------|----------------|
| `ChatScreen` | `ConsumerStatefulWidget` | Widget tree; watches `chatSessionProvider`; wires composer send/stop; auto-scroll; renders banners & CTAs. No business logic. |
| `ChatAppBar` | `Widget` (in `ChatScreen`) | Identity block: `displayName`, `relationToUser`, confidence/"insufficient material" indicator derived from `notes` + layer `Confidence`; optional session menu (F8/F9). |
| `MessageList` | `Widget` | Renders `state.turns` + `state.liveText` (streaming bubble with caret affordance). |
| `Composer` | `Widget` | Multiline field; Send button becomes Stop while `state.streaming`. |
| `ChatSessionNotifier` | `StateNotifier<ChatSessionState>` | Owns lifecycle (§3.1). Constructor-injects `PersonaRepository`, `ChatHistoryRepository`, `ChatEngine`, `PersonaRuntime`, `ModelRepository`, `ChatOptions`, `onLog`. |
| `ChatSessionState` | `@immutable` class | Immutable snapshot: persona, session meta, turns, live text, streaming flag, model readiness, typed error/guard status. |
| `ChatHistoryRepository` | `abstract class` | SQLite CRUD (see §5.1). Behind an interface with injected `DatabaseFactory`. |
| `SqfliteChatHistoryRepository` | `class` | Concrete impl over `sqflite` / `sqflite_common_ffi`. |
| `chatSessionProvider` | `StateNotifierProvider` | Top-level provider wiring the notifier with production defaults. |

### 3.3 Module dependencies

| Direction | Module | Surface used | Notes |
|-----------|--------|--------------|-------|
| consumes | 004 | `ChatEngine.chat`, `PersonaRuntime`, `ChatTurn`/`ChatOptions`/`ChatDelta`, `PersonaRuntimeMode`, `RuntimeError`, `RuntimeException` | Not modified. |
| consumes | 007 | `ModelRepository.getActiveModelHandle` / `stateOf` / `installed` | Readiness read only; install/activate UI is 010. |
| consumes | 009 | `PersonaRepository.load(id)` (+ `PersonaSummary` for entry context) | Chat needs a saved persona. |
| reuses | 003 | `Persona` + layers, `PromptTemplate` (indirectly via 004) | Read-only; no field additions. |
| provides | — | `ChatHistoryRepository`, `chatSessionProvider`, `ChatScreen` | Owned & exported by 006. |
| seam | 008 | injected `DatabaseFactory` + db path | Encryption / backup exclusion swaps the backend, contract unchanged. |
| consumes | 010 | `appSettingsProvider` (`runtime`/`cloudAuthorized`/`chatTemperature`) + cloud-key provider | Read-only; folded into `ChatOptions` + `PersonaRuntime` selection (§3.4). |
| routes to | 010 | model install/activate flow | Reached from the "no model" CTA via imperative `Navigator`. |

### 3.4 Settings → `ChatOptions`/runtime binding (seam with 010)

`ChatSessionNotifier` does **not** hardcode `ChatOptions`. At session start (and on relevant settings changes) `chatSessionProvider` **watches 010's `appSettingsProvider`** and folds it into the engine call:

| `AppSettings` field (010) | Folds into | Effect |
|---------------------------|------------|--------|
| `runtime` (`PersonaRuntimeMode`) | `ChatOptions.mode` **and** selects which injected `PersonaRuntime` is passed to `ChatEngine.chat` (local `LiteRtRuntime` vs `CloudRuntime`; `maxPrivacy` → local-only, no cloud) | Runtime + mode agree; no divergent source of truth. |
| `cloudAuthorized` (bool) | `ChatOptions.cloudAuthorized` | Cloud gate; `CloudRuntime` still enforces it independently (defense in depth). |
| `chatTemperature` (double) | `ChatOptions.temperature` | User-tuned decoding temperature. |

**Fail-safe default:** if `appSettingsProvider` is unread/unavailable, `ChatOptions()` defaults apply (`mode = local`, `cloudAuthorized = false`) — the closed cloud gate means nothing leaks. `maxContextTurns` and `maxNewTokens` remain 006-owned defaults (not user settings in v1).

**Cloud API-key read-path (seam with 010/004).** When `runtime == cloud` and `cloudAuthorized == true`, the notifier obtains the key **from 010's `SecureKeyStore` via the provider 010 exposes** (never from `AppSettings`/Hive) and passes it to the injected `CloudRuntime` (`apiKey`) at chat time. If the key is absent, the runtime's gate returns `RuntimeError.unauthorized` → surfaced as the cloud-unauthorized banner (§6). 006 never persists, caches, or logs the key. (009 uses the identical read-path at distill time.)

---

## 4. Data Structures

### 4.1 Core models

**`ChatSessionMeta`** (owned by 006; the persisted session header)

| Field | Type | Notes |
|-------|------|-------|
| id | `String` | Session id (UUID v4 string). Primary key. |
| personaId | `String` | FK to the persona (009's `Persona.id`). |
| startedAt | `DateTime` | UTC; session creation time. |
| lastMessageAt | `DateTime` | UTC; timestamp of the most recent turn (drives newest-first ordering). |
| title | `String?` | Optional user/derived label. |
| turnCount | `int` | Number of turns in the session (derived on read). |

```dart
@immutable
class ChatSessionMeta {
  const ChatSessionMeta({
    required this.id,
    required this.personaId,
    required this.startedAt,
    required this.lastMessageAt,
    this.title,
    this.turnCount = 0,
  });
  final String id;
  final String personaId;
  final DateTime startedAt;
  final DateTime lastMessageAt;
  final String? title;
  final int turnCount;
}
```

**`ChatTurn`** (reused from 004 `chat_types.dart`, **not** redefined): `{ChatRole role, String text, DateTime at}` where `at` is UTC. Persisted as one `turns` row; `role` stored as `'user'`/`'persona'`.

**`ChatSessionState`** (006 UI state; immutable)

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| phase | `ChatPhase` | `loading` | `loading` / `ready` / `streaming` / `error`. |
| persona | `Persona?` | null | Loaded via 009. |
| session | `ChatSessionMeta?` | null | Active session. |
| turns | `List<ChatTurn>` | `[]` | Persisted history, ascending by `at`. |
| liveText | `String` | `''` | Accumulated `ChatDelta.append` for the in-flight persona bubble. |
| streaming | `bool` | false | True while a `chat(...)` subscription is active. |
| readiness | `ModelReadiness` | `unknown` | Derived from 007 (see §4.1 `ModelReadiness`). |
| status | `ChatStatus?` | null | Typed non-happy state (see below); null when nominal. |

**`ChatStatus`** — the honest, typed UI state (no dead spinner). One of:
`emptyInput`, `noModel` (→ CTA to 010), `maxPrivacy`, `cloudUnauthorized`, `inferenceFailed` (retryable, partial retained), `network` (retryable), `rateLimited`, `guardIntercepted` (safe reply shown, informational), `canceled` (partial retained). Each maps 1:1 from a `RuntimeError` case or the guard path (see §6.3).

**`ModelReadiness`** — `{unknown, ready, noActiveModel, notInstalled}`, computed from 007 `getActiveModelHandle()` (non-null ⇒ `ready`) and `installed()`/`stateOf(...)`.

### 4.2 Database design

Two tables. Timestamps are **epoch milliseconds, UTC**. `role` is `'user'`|`'persona'`.

```sql
CREATE TABLE sessions(
  id          TEXT PRIMARY KEY,
  persona_id  TEXT NOT NULL,
  started_at  INTEGER NOT NULL,
  last_at     INTEGER NOT NULL,
  title       TEXT
);
CREATE INDEX idx_sessions_persona ON sessions(persona_id, last_at DESC);

CREATE TABLE turns(
  id          TEXT PRIMARY KEY,
  session_id  TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  role        TEXT NOT NULL,
  text        TEXT NOT NULL,
  at          INTEGER NOT NULL
);
CREATE INDEX idx_turns_session ON turns(session_id, at ASC);
```

- **PRAGMA foreign_keys = ON** is set on every open (sqflite disables FK enforcement by default) so `ON DELETE CASCADE` actually removes child `turns` when a session is deleted.
- `sessionsFor(personaId)` reads via `idx_sessions_persona` ordered `last_at DESC` (newest first). `turnCount` is a correlated `COUNT(*)` (or a joined `GROUP BY`) over `turns`.
- `turnsOf(sessionId)` reads via `idx_turns_session` ordered `at ASC` (chronological).
- `appendTurn` inserts the turn row and updates the parent `sessions.last_at` in one transaction.
- Schema version tracked via `PRAGMA user_version` = 1 for forward migration.

### 4.3 Storage format

- Database file `chat_history.db` in the app support/documents directory (path injected). Host tests pass the `sqflite_common_ffi` in-memory factory (`inMemoryDatabasePath`).
- **Module 008 seam**: the repository never opens a path itself — it receives a `DatabaseFactory` + `String path` (and optional open callbacks). 008 supplies an encrypted factory (e.g. SQLCipher-style) and/or a backup-excluded path; the `ChatHistoryRepository` contract is unchanged.
- The store holds only turn text (what the user typed / the persona said). No raw import corpus, no prompt text, no persona internals are persisted here.

---

## 5. Interface Design

### 5.1 Public interfaces

**Pinned upstream (004) — consumed, not defined here:**

```dart
Stream<ChatDelta> ChatEngine.chat(
  Persona persona,
  List<ChatTurn> history,
  String userMessage, {
  required PersonaRuntime runtime,
  ChatOptions options = const ChatOptions(),
});
```
Emits `ChatDelta.append(text)` frames, a terminal `ChatDelta.finish()`, or a terminal `ChatDelta.failure(RuntimeError)` (empty input / maxPrivacy / cloud-unauthorized / runtime-unavailable). On guard interception it yields the safe reply then `finish()`.

**Owned by 006 — `ChatHistoryRepository`:**

```dart
abstract class ChatHistoryRepository {
  /// Create a new session for [personaId]; returns its meta (turnCount == 0).
  Future<ChatSessionMeta> createSession(String personaId, {String? title});

  /// Append one turn; updates the session's last_at in the same transaction.
  Future<void> appendTurn(String sessionId, ChatTurn turn);

  /// Sessions for a persona, newest first (by last_at DESC).
  Future<List<ChatSessionMeta>> sessionsFor(String personaId);

  /// Turns of a session, ascending by `at`.
  Future<List<ChatTurn>> turnsOf(String sessionId);

  /// Delete a session and (cascade) all its turns.
  Future<void> deleteSession(String sessionId);
}
```

### 5.2 Class interfaces

**`ChatSessionNotifier`** (legacy `StateNotifier`, constructor-injected deps with defaults):

```dart
class ChatSessionNotifier extends StateNotifier<ChatSessionState> {
  ChatSessionNotifier({
    required this.personaId,
    PersonaRepository? personaRepo,
    ChatHistoryRepository? history,
    ChatEngine? engine,
    required this.runtime,
    ModelRepository? models,
    this.options = const ChatOptions(),
    void Function(String message)? onLog,
  }) : ... , super(const ChatSessionState());

  /// Load persona (009), read model readiness (007), open the latest session
  /// or create one, load its turns. Sets phase → ready | error.
  Future<void> open();

  /// Persist the user turn, start ChatEngine.chat(...), accumulate append
  /// frames into liveText; on finish persist the persona turn and fold
  /// liveText into turns. Maps failure/guard to ChatStatus. No-op if streaming.
  Future<void> send(String text);

  /// Cancel the in-flight stream; retain liveText as a (partial) persona turn
  /// if non-empty; phase → ready, status → canceled. Idempotent.
  Future<void> cancel();

  /// Re-read 007 readiness (after returning from the 010 install flow).
  Future<void> refreshReadiness();

  @override
  void dispose(); // cancels the active subscription
}

final StateNotifierProvider<ChatSessionNotifier, ChatSessionState>
    chatSessionProvider = ...; // family-like: constructed per personaId
```

Screen factory (imperative nav, pinned): `ChatScreen.route(personaId)` returns a `MaterialPageRoute` pushed from the 009 library.

---

## 6. Implementation Details

### 6.1 Key algorithms

**Streaming accumulation.** `send(text)`:
1. Guard: if `state.streaming` → no-op. If `text.trim().isEmpty` → set `status = emptyInput`, do not call the engine.
2. Optimistically append a user `ChatTurn(role: user, text, at: now.toUtc())` to `state.turns`; `await history.appendTurn(sessionId, userTurn)` (create session lazily if none).
3. Set `phase = streaming`, `liveText = ''`. Subscribe to `engine.chat(persona, priorTurns, text, runtime: runtime, options: options)`.
4. On `ChatDelta.append` → `liveText += delta.textDelta` (state emitted for incremental render). On `ChatDelta.failure` → map error → `ChatStatus`, stop, retain `liveText` as partial (see §6.3). On `ChatDelta.finish` → if `liveText` non-empty, persist a persona `ChatTurn`, fold into `turns`, clear `liveText`; `phase = ready`.
5. The `priorTurns` handed to the engine are `state.turns` **before** the new user turn (the engine appends the user message itself), matching the harness call (`_send` passes `prior`).

**Window trimming** is handled inside 004 (`maxContextTurns`, default 10); 006 passes the full loaded history and lets `ChatEngine` slide the window — 006 does **not** trim persistence. All turns remain in SQLite.

**Model readiness.** On `open()` and `refreshReadiness()`: `handle = await models.getActiveModelHandle()`. `handle != null` ⇒ `ready`; else if `models.installed().isNotEmpty` ⇒ `noActiveModel`; else `notInstalled`. When not `ready` and mode is `local`, `send` short-circuits to `status = noModel` with a CTA routing to 010 (no engine call), matching the "no statistical fallback" rule.

### 6.2 State management

- One `ChatSessionNotifier` per open persona conversation; state is a single immutable `ChatSessionState` replaced on each transition (no in-place mutation), matching `import_providers.dart`.
- The streaming bubble is `state.liveText`; the committed history is `state.turns`. The widget renders `turns` followed by a live bubble when `streaming && liveText.isNotEmpty`.
- Auto-scroll: after each state emission with growing `liveText`/`turns`, the screen scrolls to bottom via a `ScrollController` post-frame callback (as in the harness `_addLog`).

### 6.3 Error handling (no silent failures)

Every non-happy path is a **typed, actionable** state — never a dead spinner, never a swallowed exception.

| Source | `RuntimeError` / path | `ChatStatus` | UI |
|--------|----------------------|--------------|-----|
| empty send | `emptyInput` (or pre-checked) | `emptyInput` | inline hint; Send stays enabled; no engine call |
| no active model / maxPrivacy | `modelUnavailable` | `noModel` / `maxPrivacy` | banner + CTA → 010 install/activate (noModel); explicit "generation disabled" (maxPrivacy) |
| cloud selected, not authorized | `unauthorized` | `cloudUnauthorized` | banner explaining authorization needed; **no network call** issued |
| mid-stream native/inference failure | `inferenceFailed` | `inferenceFailed` | error banner; partial `liveText` retained; **Retry** re-runs the last user turn |
| network failure (cloud) | `network` | `network` | error banner; Retry |
| rate / token limit | `rateLimited` | `rateLimited` | error banner; Retry later |
| user stop | `canceled` (local) | `canceled` | partial retained as persona turn; no exception |
| hard-rule guard hit | (guard path in 004) | `guardIntercepted` | the safe reply is shown in character; informational, non-blocking |

- The subscription's `onError` (a `RuntimeException` escaping the stream) is caught and mapped identically to a `ChatDelta.failure`, so no uncaught error reaches the zone.
- Repository failures (corrupt/missing session, I/O) surface as `phase = error` with a message; they never silently drop turns.

### 6.4 Logging

- The notifier and repository take an injected `void Function(String) onLog` (default no-op), mirroring `DefaultChatEngine`/`DefaultLlmPersonaBuilder`.
- Logs record lifecycle events (session opened, turn persisted, window-trim notices relayed from 004, error class, cancel) — **never** message text, prompt text, or secrets (privacy per CLAUDE.md).

---

## 7. Test Strategy

- **Unit (host, ffi + MockRuntime), > 80% on repository + notifier.**
  - `SqfliteChatHistoryRepository` over `sqflite_common_ffi` in-memory: create→append→list→load round-trip; newest-first session ordering; ascending turn ordering; `appendTurn` updates `last_at`; `deleteSession` cascade (turns gone); FK pragma enforced; missing session behavior.
  - `ChatSessionNotifier` with `MockRuntime` (fixed token stream) + in-memory repo: streaming accumulation & finish; persistence of user turn on send and persona turn on finish; cancel retains partial; each `RuntimeError` → `ChatStatus`; guard interception surfaces safe reply; readiness gating (`noModel` short-circuit); window trimming delegated to 004 (assert full history persisted, engine receives prior turns).
- **Widget (host, MockRuntime-backed engine).** `ChatScreen`: bubbles render (user right / persona left); live bubble grows during streaming; Send⇄Stop toggle; typed error/guard banners; empty state; no-model CTA present and routes.
- **Integration / on-device (UAT, non-blocking for host CI).** Physical device (ADR-005): chat with Gemma 3 1B, judge fidelity + guard behavior, verify history reload after force-quit. Host/CI = structure/contract + widget tests with mocks only.

See SPEC §7 for enumerated cases (C1..Cn).

---

## 8. Performance

| Metric | Target |
|--------|--------|
| First token visible | Within model TTFT budget (ADR-005; measured on device, not asserted host-side) |
| Streaming increment latency | < 500ms (device; per SPEC-004 §7) |
| Decode throughput | > 5 tok/s (iPhone 15+; iOS Metal throughput per device baseline) |
| Message-list frame budget | No dropped frames during streaming; state diffing minimizes rebuilds |
| History read (open thread) | Async; first frame not blocked; indexed reads for long threads |
| Peak inference memory | < 2GB (delegated to 004/007 runtime) |

- Streaming rebuilds are scoped (only the live bubble + scroll position change per frame); committed turns are stable.
- Repository reads use the two covering indexes; large threads are read ascending and can be lazily windowed by the list view.

## 9. Security

- Local by default; original text never leaves the device. Cloud requires explicit authorization (010's gate, honored here); an unauthorized cloud send issues **no** network call and surfaces `cloudUnauthorized`.
- The SQLite store lives in the app sandbox; the injected `DatabaseFactory`/path seam lets Module 008 add encryption at rest and backup exclusion without a contract change.
- Persisted data is limited to turn text; no raw import corpus, prompts, or secrets. Logs are redacted (no message/prompt/key text).

## 10. Deployment

- Adds a `sqflite` (device) + `sqflite_common_ffi` (host test) dependency; no platform-channel work beyond plugin registration. iOS 16.0+ (ADR-005); large models require a physical device.
- No router change: `ChatScreen` is pushed imperatively from the 009 library. No new build config.
- `initGemmaRuntime()` must be invoked during app/runtime bootstrap before the first `chat(...)` (reused from harness wiring).

## 11. Technical Debt

| ID | Item | Plan |
|----|------|------|
| TD-006-1 | Imperative `Navigator` + screen factory; no typed routes | Candidate `go_router` adoption across 006/009/010; not in v1. |
| TD-006-2 | `turnCount` via correlated count | Acceptable for v1 thread sizes; denormalize a counter column if profiling shows cost. |
| TD-006-3 | Encryption/backup exclusion deferred to 008 | 006 ships plaintext SQLite behind the `DatabaseFactory` seam; 008 swaps the backend. |
| TD-006-4 | Regenerate (F7) / multi-session switch (F8) partial in v1 | Contract supports it (`sessionsFor`/`deleteSession`); UI polish is P1/P2. |
| TD-006-5 | Cloud transport is a 004 integration slice | 006 consumes the abstraction + authorization gate only. |

## 12. Change Log

| Date | Version | Change | Author |
|------|---------|--------|--------|
| 2026-08-05 | v1.0 (draft) | Initial draft — chat screen + `ChatSessionNotifier` + `ChatHistoryRepository` (SQLite) engineered against the approved 006 PRD and pinned 004/007/009/003 contracts | Claude |
| 2026-08-05 | v1.0.1 (draft) | PR #16 review — added §3.4 Settings→`ChatOptions`/runtime binding seam + cloud API-key read-path; listed Module 010 in "Depends on" | Claude |

---

> This document follows the Lostone document-driven development process. Status: 📝 Draft (pending review).
