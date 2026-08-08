import 'package:flutter/foundation.dart';

import 'persona_summary.dart';

/// Phase of the persona library screen (ERD-009 §4.1).
enum LibraryPhase {
  /// Loading the summary list.
  loading,

  /// Loaded (an empty list is a valid `ready` state).
  ready,

  /// Directory-level failure (e.g. the directory itself is unreadable).
  failed,
}

/// Immutable state of the persona library (ERD-009 §4.1).
@immutable
class PersonaLibraryState {
  /// Creates a library state.
  const PersonaLibraryState({
    required this.phase,
    this.summaries = const <PersonaSummary>[],
    this.error,
    this.skippedCount = 0,
  });

  /// The initial `loading` state.
  const PersonaLibraryState.loading() : this(phase: LibraryPhase.loading);

  /// A `ready` state carrying [summaries] (newest first) and the number of
  /// corrupt/unsupported files [skippedCount] the last `list()` skipped.
  const PersonaLibraryState.ready(
    List<PersonaSummary> summaries, {
    int skippedCount = 0,
  }) : this(
          phase: LibraryPhase.ready,
          summaries: summaries,
          skippedCount: skippedCount,
        );

  /// A `failed` state carrying an [error] message.
  const PersonaLibraryState.failed(String error)
      : this(phase: LibraryPhase.failed, error: error);

  /// Current phase.
  final LibraryPhase phase;

  /// Summaries, newest-first; empty list is a valid `ready` state.
  final List<PersonaSummary> summaries;

  /// Set only on `failed` (e.g. directory unreadable).
  final String? error;

  /// Count of corrupt/unsupported files skipped by the last `list()`.
  final int skippedCount;

  @override
  bool operator ==(Object other) =>
      other is PersonaLibraryState &&
      other.phase == phase &&
      listEquals(other.summaries, summaries) &&
      other.error == error &&
      other.skippedCount == skippedCount;

  @override
  int get hashCode =>
      Object.hash(phase, Object.hashAll(summaries), error, skippedCount);
}
