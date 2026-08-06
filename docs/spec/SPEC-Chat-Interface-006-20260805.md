# SPEC-006-Chat Interface

> Technical Specification — Chat Interface (streaming conversation + SQLite chat history)
>
> **Version**: v1.0 (draft)
> **Status**: 📝 Draft (pending review)
> **Author**: Claude
> **Date**: 2026-08-05

---

## 📋 Document Info

| Field | Value |
|-------|-------|
| **Spec ID** | SPEC-006 |
| **Related PRD** | PRD-Chat-Interface-006-20260805.md |
| **Related ERD** | ERD-Chat-Interface-006-20260805.md |
| **Depends on** | Module 004 (`ChatEngine`/`PersonaRuntime`/`ChatTurn`/`ChatOptions`/`ChatDelta`/`RuntimeError`), Module 007 (`ModelRepository`), Module 009 (`PersonaRepository`), Module 003 (`Persona`/`PromptTemplate`, read-only) |
| **Related decisions** | ADR-002, ADR-004, ADR-005 |

---

## 1. Overview

### 1.1 Responsibilities

Specifies the I/O contracts, pre/postconditions, edge cases, behaviors, and test cases for:
- **`ChatHistoryRepository`** (SQLite; owned by 006) — session/turn persistence keyed by persona id.
- **`ChatSessionNotifier`** (Riverpod `StateNotifier`) — the conversation lifecycle: load a persona (009), open/create a session + turns, drive `ChatEngine.chat(...)` (004), accumulate streamed `ChatDelta`, persist turns, cancel, and map every `RuntimeError`/guard case to a typed UI state.

**Out of scope:** persona persistence/library/distill (009), model-management/authorization UI (010), encryption at rest (008), cloud HTTP transport (004 slice). No modification to Module 003/004/007 contracts. The system prompt is produced **only** by `PromptTemplate.render(persona)` inside 004; conversation has **no statistical fallback** (ADR-004 / SPEC-004 §2.4).

### 1.2 Interface layers

1. **Persistence** — `ChatHistoryRepository` over an injected `DatabaseFactory` (host: `sqflite_common_ffi` in-memory; device: `sqflite`; 008: encrypted/backup-excluded backend).
2. **State/orchestration** — `ChatSessionNotifier` + immutable `ChatSessionState`, exposed via `chatSessionProvider`.
3. **Presentation** — `ChatScreen` (`ConsumerStatefulWidget`) rendering state; no business logic (widget behavior specified only where testable).

---

## 2. Interface Definitions

### 2.1 Primary

**`ChatHistoryRepository`**

```dart
abstract class ChatHistoryRepository {
  Future<ChatSessionMeta> createSession(String personaId, {String? title});
  Future<void> appendTurn(String sessionId, ChatTurn turn);
  Future<List<ChatSessionMeta>> sessionsFor(String personaId); // newest first
  Future<List<ChatTurn>> turnsOf(String sessionId);            // ascending by `at`
  Future<void> deleteSession(String sessionId);
}
```

| Method | Pre | Post |
|--------|-----|------|
| `createSession` | `personaId` non-empty | Inserts a `sessions` row; `started_at == last_at == now (UTC ms)`; returns meta with `turnCount == 0`; id is a fresh UUID. |
| `appendTurn` | session `sessionId` exists; `turn.text` may be any string; `turn.at` UTC | Inserts a `turns` row (role `'user'`/`'persona'`, `at` = epoch ms UTC) **and** updates `sessions.last_at = turn.at` in one transaction. |
| `sessionsFor` | — | Returns sessions with `persona_id == personaId`, ordered `last_at DESC` (newest first); `turnCount` accurate; empty list if none. |
| `turnsOf` | — | Returns turns of `sessionId` ordered `at ASC`; empty list if none / unknown session. |
| `deleteSession` | — | Removes the session row and (cascade) all its turns; no-op if unknown. |

**`ChatSessionNotifier`**

```dart
Future<void> open();                 // load persona + readiness + latest session + turns
Future<void> send(String text);      // persist user turn, stream reply, persist persona turn
Future<void> cancel();               // stop stream, retain partial
Future<void> refreshReadiness();     // re-read 007 after returning from 010
```

| Method | Pre | Post |
|--------|-----|------|
| `open` | `personaId` set | `persona` loaded (009); `readiness` computed (007); latest session opened or one created; `turns` loaded ascending; `phase = ready` (or `error` on load failure). |
| `send` | not `streaming` | `text.trim().isEmpty` ⇒ `status = emptyInput`, no engine call. Else: user turn persisted; engine streamed into `liveText`; on `finish` persona turn persisted & folded into `turns`; on `failure`/guard ⇒ typed `status` (§4.3). `readiness != ready` in local mode ⇒ `status = noModel`, no engine call. |
| `cancel` | — | Idempotent; cancels subscription; retains non-empty `liveText` as a partial persona turn; `phase = ready`, `status = canceled`; no exception. |
| `refreshReadiness` | — | Re-reads 007; updates `readiness`; clears `noModel` status if now ready. |

### 2.2 Auxiliary

- `ChatSessionMeta` (ERD §4.1) — immutable session header `{id, personaId, startedAt, lastMessageAt, title?, turnCount}`.
- `ChatSessionState` (ERD §4.1) — `{phase, persona?, session?, turns, liveText, streaming, readiness, status?}`.
- `ChatStatus` — `{emptyInput, noModel, maxPrivacy, cloudUnauthorized, inferenceFailed, network, rateLimited, guardIntercepted, canceled}`.
- `ModelReadiness` — `{unknown, ready, noActiveModel, notInstalled}`.
- `chatSessionProvider` — `StateNotifierProvider<ChatSessionNotifier, ChatSessionState>`, constructed per `personaId` with production defaults.
- `ChatScreen.route(personaId) → MaterialPageRoute` — imperative entry from the 009 library.

---

## 3. Data Specs

### 3.1 Input

| Input | Type | Constraint |
|-------|------|-----------|
| personaId | `String` | Non-empty; resolvable by 009 `PersonaRepository.load`. |
| userMessage (`send`) | `String` | Trimmed non-empty to reach the engine (empty ⇒ §4.1). |
| persona | `Persona` | 003/004 product; five layers; consumed read-only. |
| options | `ChatOptions` | ERD §3.5 of 004; default `mode=local, temperature=0.7, maxContextTurns=10, cloudAuthorized=false`. |
| runtime | `PersonaRuntime` | Injected; production `LiteRtRuntime(engine: FlutterGemmaEngine(), activeHandle: repo.getActiveModelHandle)`; tests inject `MockRuntime`. |
| model state | 007 | `getActiveModelHandle()` / `stateOf` / `installed()`. |

### 3.2 Output

| Output | Type | Notes |
|--------|------|-------|
| `ChatSessionState` stream | Riverpod state | Re-emitted on every transition (incremental `liveText` during streaming). |
| Persisted `sessions`/`turns` | SQLite rows | Epoch ms UTC; `role` `'user'`/`'persona'`; survives restart. |
| `List<ChatTurn>` | for engine | `turnsOf(session)` reconstructs history handed to `ChatEngine.chat` (prior turns, ascending). |

### 3.3 Transforms

- `ChatTurn.at (DateTime UTC) ⇄ INTEGER at` : `at.millisecondsSinceEpoch` ⇄ `DateTime.fromMillisecondsSinceEpoch(v, isUtc: true)`.
- `ChatRole ⇄ TEXT` : `ChatRole.user ⇄ 'user'`, `ChatRole.persona ⇄ 'persona'`.
- `ChatDelta` stream → `state.liveText` accumulation; on `finish` → committed `ChatTurn(role: persona, text: liveText, at: now)`.
- Header indicator ← `Persona.notes` (e.g. "insufficient material") + per-layer `Confidence{low,medium,high}` (no avatar field consumed).

---

## 4. Edge Cases

### 4.1 Input

| # | Case | Handling |
|---|------|----------|
| E1 | Empty / whitespace `userMessage` | `status = emptyInput`; runtime not called; no turn persisted. |
| E2 | `personaId` not resolvable by 009 | `phase = error`; message; no session created. |
| E3 | Very long history exceeding context window | Full history persisted; 004 slides window at `maxContextTurns` and reports trim via `onLog`; 006 does not trim persistence. |
| E4 | Empty history (first turn) | `open` creates a session; `send` streams normally with empty prior turns. |

### 4.2 State

| # | Case | Handling |
|---|------|----------|
| E5 | No active model (local mode) | `readiness = noActiveModel`/`notInstalled`; `send` short-circuits `status = noModel` + CTA → 010; no engine call, no fallback. |
| E6 | Max-privacy mode | `status = maxPrivacy`; generation disabled with explicit message; no engine call. |
| E7 | Cloud selected, unauthorized | `status = cloudUnauthorized`; **no network call**. |
| E8 | Cancel mid-stream | Subscription cancelled; non-empty `liveText` kept as partial persona turn; `status = canceled`; no exception. |
| E9 | `send` while already streaming | No-op (guarded). |
| E10 | Session delete cascade | `deleteSession` removes session + all its turns (FK cascade); `sessionsFor` no longer lists it. |
| E11 | Corrupt / missing session on open | If active session id missing, create a fresh session; `phase = ready`; log the recovery; never crash. |

### 4.3 Exceptions

| # | `RuntimeError` / path | `ChatStatus` | Retain partial? | Retry? |
|---|----------------------|--------------|-----------------|--------|
| E12 | `emptyInput` | `emptyInput` | n/a | n/a |
| E13 | `modelUnavailable` (no model / maxPrivacy) | `noModel` / `maxPrivacy` | n/a | via 010 / mode change |
| E14 | `unauthorized` | `cloudUnauthorized` | n/a | after authorizing (010) |
| E15 | `inferenceFailed` (mid-stream native/OOM) | `inferenceFailed` | yes | yes (re-run last user turn) |
| E16 | `network` | `network` | yes | yes |
| E17 | `rateLimited` | `rateLimited` | yes | later |
| E18 | `canceled` | `canceled` | yes | resend |
| E19 | guard interception (004 yields safe reply + finish) | `guardIntercepted` | safe reply committed | n/a |
| E20 | `RuntimeException` escaping stream `onError` | mapped as its `RuntimeError` | as above | as above |
| E21 | Repository I/O failure | `phase = error` | turns not silently dropped | user-driven |

---

## 5. Behavior Specs

### 5.1 Normal

1. **Open → reload → chat.** From the 009 library, push `ChatScreen.route(personaId)`. `open()` loads the persona (009), computes readiness (007), opens the latest session (or creates one), loads turns ascending, renders history; `phase = ready`.
2. **Send → stream → finish.** User types, taps Send. `send(text)`: persist user turn (and render it right-aligned) → subscribe to `ChatEngine.chat(persona, priorTurns, text, runtime, options)` → each `ChatDelta.append` grows the live left-aligned bubble (auto-scroll) → on `ChatDelta.finish` the persona turn is persisted and folded into `turns`; `liveText` cleared; `phase = ready`.
3. **Reload after restart.** After force-quit, reopening the persona shows prior turns; new turns append to the same session.
4. **Multiple sessions (F8/F9).** `sessionsFor(personaId)` lists newest-first; selecting one calls `open` on it; deleting one (with confirm) calls `deleteSession` (cascade).

### 5.2 Exceptional

- Each row of §4.3 produces its typed `ChatStatus` with an actionable UI (banner + optional action). No dead spinner: `phase` leaves `streaming` on every terminal frame (`finish` or `failure`) and on `onError`.
- Guard interception (E19): 004 emits the safe reply as normal `append` frames followed by `finish`; 006 commits it as a persona turn and sets an informational `guardIntercepted` status — the persona stays in character; hard-rule violations never render.
- The system prompt is never assembled by 006; it originates solely from `PromptTemplate.render(persona)` inside 004.

### 5.3 Concurrency

- At most one active `chat(...)` subscription per notifier; `send` is guarded against re-entry (E9).
- `cancel` and stream completion race safely: `cancel` is idempotent; a `finish`/`failure` arriving after `cancel` is ignored (subscription already cancelled).
- `appendTurn` runs in a single SQLite transaction (row insert + `last_at` update) so a concurrent `sessionsFor` never observes a torn state.
- `dispose()` cancels the active subscription (no state mutation after dispose).

---

## 6. Performance Specs

| Metric | Target |
|--------|--------|
| First token visible | Within model TTFT budget (device; ADR-005; not asserted host-side) |
| Streaming increment latency | < 500ms (device; per SPEC-004 §7) |
| Decode throughput | > 5 tok/s (iPhone 15+; iOS Metal per device baseline) |
| List frame budget | No dropped frames while streaming; only live bubble + scroll rebuild per frame |
| `open` (load history) | Async; first frame not blocked; indexed reads (`idx_turns_session`) for long threads |
| `sessionsFor` | Indexed (`idx_sessions_persona`), newest-first without a full scan |

## 7. Test Specs

> Deterministic host/widget tests only; all use `MockRuntime` (fixed token stream) and `sqflite_common_ffi` in-memory. LLM quality is on-device UAT (non-blocking for CI).

### 7.1 Unit

**Repository (`SqfliteChatHistoryRepository` over ffi in-memory):**

| ID | Case | Assertion |
|----|------|-----------|
| C1 | create → append → list round-trip | `createSession` then two `appendTurn`; `sessionsFor` returns the session with `turnCount == 2`. |
| C2 | turn ordering | `turnsOf` returns turns ascending by `at`, regardless of insert order. |
| C3 | session ordering (newest first) | Two sessions with different `last_at`; `sessionsFor` returns `last_at DESC`. |
| C4 | `appendTurn` updates `last_at` | After appending a later turn, session `lastMessageAt == turn.at`. |
| C5 | role/timestamp transform | `'user'`/`'persona'` and epoch-ms UTC round-trip to `ChatRole`/UTC `DateTime` exactly. |
| C6 | delete cascade | `deleteSession` removes session; `turnsOf` returns empty and `sessionsFor` omits it (FK pragma ON). |
| C7 | unknown session | `turnsOf(unknown)` → `[]`; `deleteSession(unknown)` → no-op, no throw. |
| C8 | empty persona | `sessionsFor(personaWithNone)` → `[]`. |
| C9 | restart durability | Reopen the same in-memory/temp db → previously persisted turns still present. |

**Notifier (`ChatSessionNotifier` + `MockRuntime` + in-memory repo + fake `PersonaRepository`/`ModelRepository`):**

| ID | Case | Assertion |
|----|------|-----------|
| C10 | streaming happy path | Mock emits `['你','好','呀']` → `liveText` grows in order; on finish, one persona `ChatTurn('你好呀')` persisted; `phase == ready`. |
| C11 | user turn persisted on send | After `send`, a `user` turn exists in the session before the persona turn. |
| C12 | prior turns handed to engine | Engine receives `turns` **before** the new user message (matches harness `_send` semantics). |
| C13 | empty message (E1) | `send('  ')` → `status == emptyInput`; runtime not invoked; no turn persisted. |
| C14 | no active model (E5) | `getActiveModelHandle` → null, local mode → `status == noModel`; engine not called. |
| C15 | max-privacy (E6) | `options.mode == maxPrivacy` → `ChatDelta.failure(modelUnavailable)` → `status == maxPrivacy`; no fallback. |
| C16 | cloud unauthorized (E7) | `mode == cloud, cloudAuthorized == false` → `status == cloudUnauthorized`; MockRuntime records **no** generate call. |
| C17 | mid-stream inferenceFailed (E15) | Mock throws `RuntimeException(inferenceFailed)` after 2 tokens → `status == inferenceFailed`; partial `liveText` retained; retry re-runs. |
| C18 | network failure (E16) | `RuntimeException(network)` → `status == network`; partial retained. |
| C19 | rateLimited (E17) | `RuntimeError.rateLimited` → `status == rateLimited`. |
| C20 | guard interception (E19) | Mock emits a violating string; 004 yields safe reply + finish → committed persona turn == safe reply; `status == guardIntercepted`; `mustNeverClaim` text absent. |
| C21 | cancel mid-stream (E8) | `cancel()` after 2 tokens → no further `liveText` growth; partial persona turn persisted; `status == canceled`; no exception. |
| C22 | no re-entry (E9) | `send` while `streaming` → no-op; single subscription. |
| C23 | window trimming (E3) | History > `maxContextTurns` → all turns persisted; engine sees full prior history and slides internally; `onLog` trim notice observed. |
| C24 | history round-trip | `open` → `send` ×2 → new notifier `open` same session → `turns` equals persisted sequence. |
| C25 | delete cascade via notifier | Deleting the active session clears it; `sessionsFor` omits it. |
| C26 | corrupt/missing session (E11) | Active session id absent → fresh session created; `phase == ready`; recovery logged. |
| C27 | refreshReadiness after 010 | Handle null → ready between calls → `readiness == ready`, `noModel` status cleared. |
| C28 | privacy logging | `onLog` output contains no message/prompt text or secrets. |

### 7.2 Widget

| ID | Case | Assertion |
|----|------|-----------|
| C29 | bubbles render | Given persisted turns, user bubbles right-aligned, persona left-aligned. |
| C30 | streaming updates | Live bubble text grows across frames as Mock emits. |
| C31 | Send ⇄ Stop toggle | Send becomes Stop while `streaming`; tapping Stop calls `cancel`. |
| C32 | typed banners | Each `ChatStatus` renders its banner; `noModel` shows a CTA that pushes the 010 route. |
| C33 | empty state | No turns → empty-state prompt inviting the first message. |
| C34 | header indicator | Persona with low-confidence layers / "insufficient material" note → header shows the indicator; no avatar widget. |

### 7.3 Test data

- `MockRuntime`: fixed token sequences; a variant that throws `RuntimeException(error)` after N tokens; an `isAvailable()` toggle.
- Fake `PersonaRepository`: returns a fixed `Persona` (mix of `Confidence.low`/`high` layers, non-empty `notes`) and an unresolvable id for E2.
- Fake `ModelRepository`: `getActiveModelHandle` null/non-null; `installed()` empty/non-empty for `noActiveModel` vs `notInstalled`.
- In-memory db via `databaseFactoryFfi` + `inMemoryDatabasePath`; a temp-file variant for C9 durability.

## 8. Dependencies

- **004**: `ChatEngine.chat`, `PersonaRuntime`, `ChatTurn`/`ChatOptions`/`ChatDelta`/`RuntimeError`/`RuntimeException`, `PersonaRuntimeMode` — consumed, not modified.
- **007**: `ModelRepository.getActiveModelHandle` / `stateOf` / `installed`.
- **009**: `PersonaRepository.load(id)` (+ `PersonaSummary`).
- **003**: `Persona` + layers, `PromptTemplate` (via 004; read-only).
- **Packages**: `sqflite` (device), `sqflite_common_ffi` (host tests), `flutter_riverpod`, `uuid` (session/turn ids).
- **008 seam**: injected `DatabaseFactory` + path (encryption / backup exclusion).

## 9. Constraints

- System prompt **only** from `PromptTemplate.render(persona)`; conversation has **no statistical fallback**; Modules 003/004/007 reused, not modified.
- No fields added to Module 003 (`Persona` has no avatar; header derives from `identity` + `notes` + `Confidence`).
- Imperative `Navigator` + screen factory (no `go_router` in v1).
- Legacy Riverpod `StateNotifier` + top-level provider; immutable state; constructor-injected deps with defaults (matches `import_providers.dart`).
- Timestamps epoch-ms UTC; `role` stored `'user'`/`'persona'`; `PRAGMA foreign_keys = ON` for cascade.
- No silent failures: every non-happy path is a typed `ChatStatus`/`error` phase; logs are redacted.

## 10. Acceptance Criteria

Mirrors PRD §8.

- **Chat**: sending streams incrementally, ending with a finish frame (C10, C30); cancel stops without exception, partial retained (C21, C31); guard's safe reply shown in character, no violation rendered (C20).
- **History**: conversation survives restart and reloads (C9, C24); each user & persona turn persisted, sessions keyed by persona id (C1, C11); delete removes session + turns (C6, C25).
- **Error handling (no silent failures)**: no active model → actionable CTA → 010 (C14, C32); max-privacy disabled with message (C15); cloud-unauthorized → explicit message, no network call (C16); mid-stream failure → typed banner, partial retained, retry (C17, C18).
- **Contracts preserved**: system prompt only from `PromptTemplate.render` (verified via 004 wiring); no statistical fallback (C15); Modules 003/004 unmodified.

## 11. Change Log

| Date | Version | Change | Author |
|------|---------|--------|--------|
| 2026-08-05 | v1.0 (draft) | Initial draft — `ChatHistoryRepository` + `ChatSessionNotifier` contracts, edge cases, behaviors, and enumerated test specs (C1..C34) against the approved 006 PRD, ERD-006, and pinned 004/007/009/003 contracts | Claude |

---

> This document follows the Lostone document-driven development process. Status: 📝 Draft (pending review).
