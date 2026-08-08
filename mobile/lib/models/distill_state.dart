import 'package:flutter/foundation.dart';

import 'persona.dart';

/// Phase of the distill flow (ERD-009 §4.1).
enum DistillPhase {
  /// Nothing distilled yet.
  idle,

  /// A build is in progress.
  running,

  /// A persona was produced and awaits review/save.
  done,

  /// The build failed.
  failed,
}

/// Typed distill failure (ERD-009 §4.1).
enum DistillError {
  /// No ready/active model — routes the UI to Module 010.
  noModel,

  /// The build threw. Retryable; nothing is saved.
  buildFailed,
}

/// Immutable state of the distill flow (ERD-009 §4.1).
@immutable
class DistillState {
  /// Creates a distill state.
  const DistillState({
    required this.phase,
    this.progressLog = const <String>[],
    this.persona,
    this.usedFallback = false,
    this.error,
    this.saveError,
    this.saved = false,
    this.paused = false,
  });

  /// The initial `idle` state.
  const DistillState.idle() : this(phase: DistillPhase.idle);

  /// Current phase.
  final DistillPhase phase;

  /// Progress lines mirrored from `LlmPersonaBuilder.onLog`.
  final List<String> progressLog;

  /// Set on `done`: the result awaiting review/save.
  final Persona? persona;

  /// True when Module 004 fell back to the statistical engine.
  final bool usedFallback;

  /// Set on `failed`.
  final DistillError? error;

  /// Set when a post-`done` `save()` fails; the reviewed [persona] is retained.
  final String? saveError;

  /// True once `save()` succeeds.
  final bool saved;

  /// True while a `running` build is parked at a chunk boundary via `pause()`.
  final bool paused;

  /// Returns a copy with the given overrides.
  DistillState copyWith({
    DistillPhase? phase,
    List<String>? progressLog,
    Persona? persona,
    bool? usedFallback,
    DistillError? error,
    String? saveError,
    bool? saved,
    bool? paused,
  }) =>
      DistillState(
        phase: phase ?? this.phase,
        progressLog: progressLog ?? this.progressLog,
        persona: persona ?? this.persona,
        usedFallback: usedFallback ?? this.usedFallback,
        error: error ?? this.error,
        saveError: saveError ?? this.saveError,
        saved: saved ?? this.saved,
        paused: paused ?? this.paused,
      );

  @override
  bool operator ==(Object other) =>
      other is DistillState &&
      other.phase == phase &&
      listEquals(other.progressLog, progressLog) &&
      other.persona == persona &&
      other.usedFallback == usedFallback &&
      other.error == error &&
      other.saveError == saveError &&
      other.saved == saved &&
      other.paused == paused;

  @override
  int get hashCode => Object.hash(
        phase,
        Object.hashAll(progressLog),
        persona,
        usedFallback,
        error,
        saveError,
        saved,
        paused,
      );
}
