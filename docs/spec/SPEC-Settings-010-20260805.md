# SPEC-010-Settings

> Technical Specification — Settings (interface-level I/O, pre/postconditions, edge cases, test cases)
>
> **Version**: v1.0 (draft)
> **Status**: 📝 Draft (pending review)
> **Author**: Claude
> **Date**: 2026-08-05
> **Priority**: P1

---

## 📋 Document Info

| Field | Value |
|-------|-------|
| **Spec ID** | SPEC-010 |
| **Related PRD** | PRD-Settings-010-20260805.md |
| **Related ERD** | ERD-Settings-010-20260805.md |
| **Depends on** | Module 007 (`ModelRepository` + models), Module 004 (`PersonaRuntimeMode`, `CloudRuntime`), Flutter Secure Storage, Hive |
| **Related decisions** | ADR-002, ADR-004, ADR-005 |

---

## 1. Overview

Specifies the interfaces 010 owns — `RuntimeChoice`, `AppSettings`, `SettingsRepository`, `SecureKeyStore`, `SettingsNotifier`, `ModelManagerNotifier` — with input/output, pre/postconditions, edge cases, and enumerated test cases. 010 is UI + settings persistence over Module 007's `ModelRepository` and Module 004's runtime mode/authorization. It does **not** implement download/storage/activation (007) or inference/authorization enforcement (004). Values 010 persists (`PersonaRuntimeMode`, `cloudAuthorized`, `chatTemperature`, `activeModelId`) are read by Modules 006 and 009.

---

## 2. Interface Definitions

### 2.1 `AppSettings` (immutable value)
- **Fields**: `runtime: RuntimeChoice` (default `local`), `cloudAuthorized: bool` (default `false`), `activeModelId: String?` (default `null`), `chatTemperature: double` (default `0.7`).
- **Derived**: `runtimeMode → PersonaRuntimeMode` (1:1 map).
- **Invariant**: contains **no secret** (API key / HF token are never fields). `copyWith` is nullable-aware for `activeModelId` (can set back to `null`). Value equality over all four fields.

### 2.2 `SettingsRepository.load() → Future<AppSettings>`
- **Input**: none.
- **Output**: stored `AppSettings`; if nothing persisted, the default `AppSettings()`.
- **Pre**: store available. **Post**: no mutation; missing fields fall back to defaults; never throws for "empty" (returns defaults).

### 2.3 `SettingsRepository.save(AppSettings) → Future<void>`
- **Input**: an `AppSettings`.
- **Pre**: store available. **Post**: all four non-secret fields persisted; a subsequent `load()` returns an equal value. **No secret is written** (the type carries none).

### 2.4 `SecureKeyStore` / `TokenStore` (cloud API key / HF token)
- `read() → Future<String?>` (null if unset), `write(String)`, `clear()`.
- **Post**: value stored **only** in Flutter Secure Storage; never in Hive; never logged. `clear()` removes it; subsequent `read()` → `null`.

### 2.5 `SettingsNotifier` (`StateNotifier<AppSettings>`)
- `loadInitial()`: `state = await repository.load()`.
- `setRuntime(RuntimeChoice)`: `state = state.copyWith(runtime:)`; `await repository.save(state)`. **Post**: exposed mode updated; persisted.
- `setCloudAuthorized(bool)`: as above for `cloudAuthorized`.
- `setCloudApiKey(String)`: `await cloudKeyStore.write(key)`. **Post**: key in Secure Storage; **`AppSettings` unchanged** (no state mutation, nothing to Hive). `clearCloudApiKey()`: `cloudKeyStore.clear()`.
- `setHfToken(String)`: `await hfTokenStore.write(token)` (reuse `SecureTokenStore`).
- `setActiveModelId(String?)`: `state = state.copyWith(activeModelId:)`; `save`. **Post**: mirror updated (source of truth remains 007 `getActiveModelHandle`).
- `setChatTemperature(double)`: clamp to a valid range, `copyWith`, `save`.
- **Errors**: a store failure surfaces to the UI (snackbar / save-failed flag) — never swallowed; in-memory state may still reflect intent but the failure is reported.

### 2.6 `ModelManagerNotifier` (`StateNotifier<ModelManagerState>`)
- `refresh()`: `state = {catalog: repository.catalog(recommendFor: device.tier()), installed: repository.installed(), activeModelId: (await repository.getActiveModelHandle())?.id, progress: unchanged, lastError: cleared}`.
- `install(modelId, {hfToken, allowOverTier})`: subscribe `repository.install(modelId, hfToken:, allowOverTier:)`; fold each `InstallEvent` into `progress[modelId]`; on `failed`, set `lastError`. On done, `refresh()`. **Pre**: `modelId ∈ catalog` (else `install` throws `ArgumentError`; guarded by catalog-driven UI). **Post**: on `ready`, installed list includes it.
- `cancel(modelId)`: `repository.cancel(modelId)`; clear `progress[modelId]`; `refresh()`.
- `delete(modelId)`: `repository.delete(modelId)` (idempotent); if `modelId == activeModelId`, invoke `onActiveChanged(null)`; `refresh()`.
- `activate(modelId)`: `repository.setActive(modelId)` (catch `StateError` for non-ready → `lastError`); on success `onActiveChanged(modelId)`; `refresh()`.

---

## 3. Data Specs

- `RuntimeChoice ∈ {local, cloud, maxPrivacy}`; maps to `PersonaRuntimeMode ∈ {local, cloud, maxPrivacy}` (identical ordering).
- `chatTemperature`: double clamped to `[0.0, 1.0]` (default `0.7`); passed to `ChatOptions`/`LlmBuildOptions` downstream.
- `activeModelId`: an id present in `ModelCatalog` (`smollm2-135m` / `gemma3-1b-it-int4` / `gemma4-e2b`) or `null`.
- `ModelManagerState`: `{catalog: List<ModelDescriptor>, installed: List<InstalledModel>, activeModelId: String?, progress: Map<String, InstallProgress>, lastError: InstallFailure?}`.
- `InstallProgress`: `{state: ModelState, receivedBytes: int, totalBytes: int}`; percent = `totalBytes == 0 ? null : (receivedBytes*100/totalBytes).round()`.
- `InstallFailure`: `{modelId: String, kind: InstallErrorKind}`.
- Hive `settings` box keys: `runtime` (enum name), `cloudAuthorized` (bool), `activeModelId` (String?), `chatTemperature` (double). Secrets: Secure Storage keys `cloud_api_key` (via `SecureKeyStore`), HF token (via `SecureTokenStore`).

---

## 4. Edge Cases

| # | Case | Expected behavior |
|---|------|-------------------|
| E1 | `load()` with empty store | Return default `AppSettings` (local, not authorized, no active, temp 0.7); no throw. |
| E2 | Install a gated model without a token | 007 emits `failed(authRequired)`; notifier sets `lastError = authRequired`; UI routes to HF token field; no crash. |
| E3 | Install over-tier without confirm | `!device.canRun` → UI blocks; 007 with `allowOverTier: false` emits `failed(unsupportedDevice)`; UI offers explicit confirm. |
| E4 | Install over-tier with confirm | `install(..., allowOverTier: true)` proceeds past the tier gate. |
| E5 | Insufficient storage | 007 emits `failed(insufficientStorage)`; distinct "not enough storage" state; offer delete. |
| E6 | Cancel mid-install | `cancel(id)` → 007 cleans half-download, emits `notInstalled`; `progress[id]` cleared; row returns to not-installed. |
| E7 | Delete the active model | `delete(activeId)` frees storage; `onActiveChanged(null)`; `AppSettings.activeModelId → null`; UI shows "no active model". |
| E8 | Switch active model | `activate(readyId)` sets it active; `activeModelId` mirror updated; previous active no longer marked active. |
| E9 | Activate a non-ready model | `setActive` throws `StateError`; caught → `lastError` "model not ready"; no active change. |
| E10 | Cloud mode selected without a key | `runtime == cloud` persisted, but derived UI shows "no key — unusable"; `CloudRuntime` would return `unauthorized`; no network call. |
| E11 | Cloud authorized then key cleared | `clearCloudApiKey()` removes the secret; derived `hasCloudKey == false`; cloud unusable until re-entered. |
| E12 | Secret never in Hive/logs | Setting a cloud key / HF token writes only to the secure store; the Hive map contains no secret; logs show no secret. |
| E13 | Max-privacy selected | `runtime == maxPrivacy` persisted + exposed; 006/009 read it (distill → statistical fallback; chat → disabled state). 010 records only. |
| E14 | Network drop mid-download | 007 emits `failed(network)`; distinct state with retry; partial cleaned by 007. |
| E15 | Corrupted/verification failure | 007 emits `failed(corrupted)`; distinct state with retry (re-download). |
| E16 | Unknown modelId to `install` | `ArgumentError` from 007 (catalog-driven UI prevents; defensive mapping to `unknownModel`). |
| E17 | `save()` failure | Reported to UI (never swallowed); state reflects intent; user can retry save. |

---

## 5. Behavior Specs

- **Defaults & local-first**: fresh install → `AppSettings()` = local / not authorized / no active / 0.7. No cloud call is possible without opt-in + key.
- **Single source of truth**: 006 and 009 read mode/auth/temperature via `appSettingsProvider`; `activeModelId` in settings is a mirror — model readiness authority is `ModelRepository.getActiveModelHandle()`.
- **Install lifecycle**: `notInstalled → downloading(progress) → verifying → ready`, or `→ failed(kind)`; the UI reflects exactly the states/errors 007 emits (no invented states).
- **No silent failures**: every `InstallErrorKind` maps to a distinct, actionable UI state (§4, ERD §6.3); `setActive` and store failures are surfaced.
- **Secret isolation**: secrets flow only to Secure Storage; they are never part of `AppSettings`, never persisted to Hive, never logged.
- **Reuse**: 007 and 004 are consumed unmodified; 010 adds only UI + settings.

---

## 6. Performance Specs

- Install progress events reflected in UI within 007's < 500ms callback budget; no dropped/coalesced-to-invisible frames beyond throttling.
- `SettingsRepository.load/save`: local Hive, async, effectively sub-frame; `load()` resolved before `appSettingsProvider` is first read.
- Catalog/installed rendering O(n) for small n; `stateOf`/`usedBytes` O(1)~O(n).

---

## 7. Test Specs

All host tests use a **fake `ModelRepository`** with deterministic `InstallEvent` streams, an **in-memory `SettingsRepository`**, and **in-memory secure stores** (no real network, disk, or plugins).

| # | Test | Asserts |
|---|------|---------|
| C1 | `load()` empty store | Returns default `AppSettings` (E1). |
| C2 | Settings round-trip | `save(s)` then `load()` returns a value equal to `s` (all four fields). |
| C3 | `setRuntime` persists + exposes | State + persisted `runtime` updated; `runtimeMode` maps correctly for all three choices. |
| C4 | `setCloudAuthorized` persists | `cloudAuthorized` toggles and survives reload. |
| C5 | Secret isolation — cloud key | `setCloudApiKey` writes to fake secure store; Hive map has no `cloud_api_key`; `AppSettings` unchanged; no secret in captured logs (E12). |
| C6 | Secret isolation — HF token | `setHfToken` writes to `SecureTokenStore` fake only; not in Hive; not logged. |
| C7 | Clear cloud key | `clearCloudApiKey` → `read() == null`; derived `hasCloudKey == false` (E11). |
| C8 | Install progress fold | Scripted `downloading(25/50/100) → verifying → ready`; `progress[id]` percent advances; ends `ready` (F2). |
| C9 | Install authRequired | Gated stream emits `failed(authRequired)`; `lastError.kind == authRequired` (E2). |
| C10 | Install insufficientStorage | `failed(insufficientStorage)` → distinct error (E5). |
| C11 | Install unsupportedDevice (no confirm) | `!canRun`, `allowOverTier:false` → `failed(unsupportedDevice)` (E3). |
| C12 | Install over-tier confirmed | `allowOverTier:true` bypasses tier gate; proceeds to `ready` (E4). |
| C13 | Install network failure | `failed(network)` → distinct retry state (E14). |
| C14 | Install corrupted | `failed(corrupted)` → distinct retry state (E15). |
| C15 | Cancel mid-install | `cancel(id)` → `notInstalled`; `progress[id]` cleared (E6). |
| C16 | Activate ready model | `activate(id)` → active; `activeModelId` mirror + `onActiveChanged(id)` fired (E8, F3). |
| C17 | Activate non-ready model | `setActive` `StateError` caught → `lastError`; active unchanged (E9). |
| C18 | Delete active model | `delete(activeId)` → active cleared; `AppSettings.activeModelId == null` (E7). |
| C19 | Delete non-active (idempotent) | `delete` frees; active unchanged; deleting absent id is a no-op. |
| C20 | Cloud-without-key derived state | `runtime == cloud`, no key → derived "unusable/no key"; a wired `CloudRuntime` returns `unauthorized`; no network (E10). |
| C21 | Max-privacy exposure | `setRuntime(maxPrivacy)` → `appSettingsProvider.runtimeMode == PersonaRuntimeMode.maxPrivacy` (E13). |
| C22 | Recommendation ordering | `catalog(recommendFor: simulatorCpu)` ranks SmolLM runnable-first; 1B/E2B flagged over-tier (widget/state). |
| C23 | Chat temperature clamp | `setChatTemperature(2.0)` clamps to 1.0; persisted. |
| C24 | Save failure surfaced | Fake `save` throws → error reported, not swallowed (E17). |
| C25 (widget) | Screen states | Catalog renders recommended-first; progress bar animates; each typed error row shows; confirm-delete dialog appears; secret fields obscured. |

Coverage target > 80% on notifiers + repository + mappers.

---

## 8. Dependencies

| Dependency | Use |
|------------|-----|
| Module 007 `ModelRepository` + models | catalog/install/cancel/delete/activate/state; `InstallEvent`/`InstallErrorKind`/`ModelState`/`DeviceTier`; `SecureTokenStore` |
| Module 007 `DeviceCapabilities` | tier + `canRun` for recommendation/over-tier gating |
| Module 004 `PersonaRuntimeMode`, `CloudRuntime` | mode mapping + cloud authorization semantics |
| Flutter Secure Storage | cloud API key (`SecureKeyStore`), HF token (`SecureTokenStore`) |
| Hive | non-secret `AppSettings` |
| Riverpod | `StateNotifierProvider` + DI |

---

## 9. Constraints

- 010 adds no inference/download/storage logic; it drives 007 and reads/records 004's mode/auth.
- Secrets only in Secure Storage — never Hive, never logs.
- Local by default; cloud strictly opt-in; max-privacy never triggers an LLM call (enforced downstream, recorded here).
- iOS 16.0+ (ADR-005); simulator/host tier limited to SmolLM 135M; quality UAT on-device.
- Imperative `Navigator` (no router); `go_router` deferred (ERD §11).
- Production `ModelRepository` uses a **disk-backed** `ModelStore` (not `InMemoryModelStore`); `freeBytes` precheck gap tracked as DD-002.

---

## 10. Acceptance Criteria

Mirrors PRD §8:
- [ ] Catalog renders with device-tier recommendation; gated + installed/active badges correct (C22, C25).
- [ ] Install streams progress to `ready`; activate marks active; `activeModelId` mirrors 007 (C8, C16).
- [ ] Cancel returns to not-installed; delete frees storage and clears active when deleting the active model (C15, C18).
- [ ] Each `InstallErrorKind` yields a distinct, actionable state; gated-without-token → authRequired; over-tier gated behind confirm (C9–C14, C11–C12).
- [ ] Defaults local / not-authorized; cloud opt-in stores key in Secure Storage only; cloud-without-key unusable with no network; max-privacy exposed (C1, C3, C5, C20, C21).
- [ ] `AppSettings` round-trips; secrets never in Hive/logs; provider read by 006/009 (C2, C5, C6).
- [ ] Modules 007 and 004 reused, not modified.

---

## 11. Change Log

| Version | Date | Change | Author |
|---------|------|--------|--------|
| v1.0 | 2026-08-05 | Initial draft (settings interfaces, edge cases, C1–C25 test specs) | Claude |
