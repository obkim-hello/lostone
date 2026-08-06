import 'package:flutter/foundation.dart';

import 'model_descriptor.dart';
import 'model_install.dart';

/// Per-model download/install progress folded from `InstallEvent` (ERD-010 §4).
@immutable
class InstallProgress {
  /// Creates a progress snapshot for one model.
  const InstallProgress({
    required this.state,
    this.receivedBytes = 0,
    this.totalBytes = 0,
  });

  /// Current install state.
  final ModelState state;

  /// Bytes received so far.
  final int receivedBytes;

  /// Total bytes for the download; `0` when unknown.
  final int totalBytes;

  /// Completion fraction in `[0.0, 1.0]`, or `null` when [totalBytes] is
  /// unknown (drives an indeterminate progress bar).
  double? get fraction => totalBytes > 0 ? receivedBytes / totalBytes : null;

  @override
  bool operator ==(Object other) =>
      other is InstallProgress &&
      other.state == state &&
      other.receivedBytes == receivedBytes &&
      other.totalBytes == totalBytes;

  @override
  int get hashCode => Object.hash(state, receivedBytes, totalBytes);
}

/// A typed install failure surfaced to the UI (ERD-010 §4 / §6.3).
@immutable
class InstallFailure {
  /// Creates a failure record for [modelId] with the given [kind].
  const InstallFailure({required this.modelId, required this.kind});

  /// The model the failure applies to.
  final String modelId;

  /// The typed reason (mapped to distinct UI; never a silent failure).
  final InstallErrorKind kind;

  @override
  bool operator ==(Object other) =>
      other is InstallFailure && other.modelId == modelId && other.kind == kind;

  @override
  int get hashCode => Object.hash(modelId, kind);
}

const Object _unset = Object();

/// Immutable state for `ModelManagerNotifier` (ERD-010 §4).
///
/// `catalog`/`installed`/`activeModelId` snapshot the Module 007
/// `ModelRepository`; `progress` is ephemeral per-model install progress;
/// `lastError` holds the most recent typed failure (install or activate).
@immutable
class ModelManagerState {
  /// Creates a state snapshot (empty by default).
  const ModelManagerState({
    this.catalog = const <ModelDescriptor>[],
    this.installed = const <InstalledModel>[],
    this.activeModelId,
    this.progress = const <String, InstallProgress>{},
    this.lastError,
  });

  /// Built-in model catalog, recommended-order first.
  final List<ModelDescriptor> catalog;

  /// Snapshot of installed models.
  final List<InstalledModel> installed;

  /// Id of the active model, or `null` when none is active.
  final String? activeModelId;

  /// Per-model install progress keyed by model id.
  final Map<String, InstallProgress> progress;

  /// Most recent typed failure, or `null` when the last op succeeded.
  final InstallFailure? lastError;

  /// Returns a copy with the given overrides.
  ///
  /// [activeModelId] and [lastError] are nullable-aware: omit to keep the
  /// current value, or pass `null` explicitly to clear.
  ModelManagerState copyWith({
    List<ModelDescriptor>? catalog,
    List<InstalledModel>? installed,
    Object? activeModelId = _unset,
    Map<String, InstallProgress>? progress,
    Object? lastError = _unset,
  }) {
    return ModelManagerState(
      catalog: catalog ?? this.catalog,
      installed: installed ?? this.installed,
      activeModelId: identical(activeModelId, _unset)
          ? this.activeModelId
          : activeModelId as String?,
      progress: progress ?? this.progress,
      lastError: identical(lastError, _unset)
          ? this.lastError
          : lastError as InstallFailure?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ModelManagerState &&
      listEquals(other.catalog, catalog) &&
      listEquals(other.installed, installed) &&
      other.activeModelId == activeModelId &&
      mapEquals(other.progress, progress) &&
      other.lastError == lastError;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(catalog),
    Object.hashAll(installed),
    activeModelId,
    Object.hashAllUnordered(progress.keys),
    lastError,
  );
}
