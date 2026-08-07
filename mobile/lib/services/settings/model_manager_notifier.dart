import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/model_install.dart';
import '../../models/model_manager_state.dart';
import '../model/device_capabilities.dart';
import '../model/model_repository.dart';

/// Drives the model-management UI over Module 007's [ModelRepository]
/// (ERD-010 §4 / §6).
///
/// [refresh] snapshots catalog/installed/active; [install] folds each
/// `InstallEvent` into per-model [InstallProgress]; [cancel]/[delete]/[activate]
/// proxy the repository and re-snapshot. On active-model changes it calls
/// [onActiveChanged] so `SettingsNotifier` can mirror the id into `AppSettings`.
class ModelManagerNotifier extends StateNotifier<ModelManagerState> {
  /// Creates a notifier; [onActiveChanged] fires with the new active id (or
  /// `null`) whenever activation or deletion changes the active model.
  ModelManagerNotifier({
    required ModelRepository repository,
    required DeviceCapabilities device,
    void Function(String? id)? onActiveChanged,
  }) : _repository = repository,
       _device = device,
       _onActiveChanged = onActiveChanged,
       super(const ModelManagerState());

  final ModelRepository _repository;
  final DeviceCapabilities _device;
  final void Function(String? id)? _onActiveChanged;

  /// Snapshots catalog (recommended for the current device), installed models,
  /// and the active id; clears [ModelManagerState.lastError].
  Future<void> refresh() async {
    await _repository.syncInstalled();
    final String? activeId = (await _repository.getActiveModelHandle())?.id;
    state = state.copyWith(
      catalog: _repository.catalog(recommendFor: _device.tier()),
      installed: _repository.installed(),
      activeModelId: activeId,
      lastError: null,
    );
  }

  /// Installs [modelId], folding each `InstallEvent` into progress/state.
  ///
  /// A gated model requires [hfToken]; [allowOverTier] bypasses the tier gate
  /// after explicit user confirmation. On a `failed` event the typed reason is
  /// recorded in [ModelManagerState.lastError] and the snapshot is left intact;
  /// otherwise the repository is re-snapshotted on completion.
  Future<void> install(
    String modelId, {
    String? hfToken,
    bool allowOverTier = false,
  }) async {
    bool failed = false;
    final Stream<InstallEvent> events = _repository.install(
      modelId,
      hfToken: hfToken,
      allowOverTier: allowOverTier,
    );
    await for (final InstallEvent event in events) {
      final Map<String, InstallProgress> next = Map<String, InstallProgress>.of(
        state.progress,
      );
      next[modelId] = InstallProgress(
        state: event.state,
        receivedBytes: event.receivedBytes,
        totalBytes: event.totalBytes,
      );
      if (event.state == ModelState.failed) {
        failed = true;
        state = state.copyWith(
          progress: next,
          lastError: InstallFailure(
            modelId: modelId,
            kind: event.error ?? InstallErrorKind.unknown,
          ),
        );
      } else {
        state = state.copyWith(progress: next);
      }
    }
    if (!failed) {
      await refresh();
    }
  }

  /// Cancels an in-progress download and clears its progress entry.
  Future<void> cancel(String modelId) async {
    await _repository.cancel(modelId);
    final Map<String, InstallProgress> next = Map<String, InstallProgress>.of(
      state.progress,
    )..remove(modelId);
    state = state.copyWith(progress: next);
    await refresh();
  }

  /// Deletes [modelId] (idempotent); if it was active, clears the active model
  /// and notifies via [onActiveChanged].
  Future<void> delete(String modelId) async {
    final String? previousActive = state.activeModelId;
    await _repository.delete(modelId);
    final Map<String, InstallProgress> next = Map<String, InstallProgress>.of(
      state.progress,
    )..remove(modelId);
    state = state.copyWith(progress: next);
    await refresh();
    if (state.activeModelId != previousActive) {
      _onActiveChanged?.call(state.activeModelId);
    }
  }

  /// Activates a ready [modelId]; a non-ready model surfaces as
  /// [ModelManagerState.lastError] with the active model unchanged.
  Future<void> activate(String modelId) async {
    try {
      await _repository.setActive(modelId);
    } on Object {
      state = state.copyWith(
        lastError: InstallFailure(
          modelId: modelId,
          kind: InstallErrorKind.unknown,
        ),
      );
      return;
    }
    await refresh();
    _onActiveChanged?.call(state.activeModelId);
  }

  /// Clears the active model so none is active; installed files are kept.
  /// Notifies via [onActiveChanged] with `null`.
  Future<void> deactivate() async {
    await _repository.deactivate();
    await refresh();
    _onActiveChanged?.call(state.activeModelId);
  }
}
