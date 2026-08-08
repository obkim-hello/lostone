import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/conversation.dart';
import '../../models/distill_state.dart';
import '../../models/persona.dart';
import '../llm/llm_persona_builder.dart';
import '../llm/persona_runtime.dart';
import 'persona_repository.dart';

/// Builds an [LlmPersonaBuilder] wired to capture progress via [onLog].
///
/// `onLog` is a `DefaultLlmPersonaBuilder` constructor param (not on the
/// [LlmPersonaBuilder] interface), so the notifier injects a factory to bridge
/// progress from both the real builder and test fakes without touching 004.
typedef LlmPersonaBuilderFactory = LlmPersonaBuilder Function(
  void Function(String) onLog,
);

LlmPersonaBuilder _defaultBuilderFactory(void Function(String) onLog) =>
    DefaultLlmPersonaBuilder(onLog: onLog);

/// Prefix of the honest note Module 004 adds when its statistical engine fires
/// as a fallback (max-privacy / no-text-corpus / LLM gen-or-parse failure).
const String _fallbackNotePrefix = '统计兜底';

/// Drives [DistillState] for the create/distill flow (SPEC-009 §2.6).
class DistillNotifier extends StateNotifier<DistillState> {
  /// Creates the notifier.
  ///
  /// [repository] persists the reviewed persona (defaults to
  /// [FilePersonaRepository]). [builderFactory] builds the 004 distiller with
  /// progress capture. Model/runtime readiness is gated per-run on the
  /// [PersonaRuntime] passed to [run] (local, cloud, or fallback).
  DistillNotifier({
    PersonaRepository? repository,
    LlmPersonaBuilderFactory? builderFactory,
  })  : _repository = repository ?? FilePersonaRepository(),
        _builderFactory = builderFactory ?? _defaultBuilderFactory,
        super(const DistillState.idle());

  final PersonaRepository _repository;
  final LlmPersonaBuilderFactory _builderFactory;

  int _runId = 0;
  Completer<void>? _pauseGate;

  /// Runs a distillation over [conversation].
  ///
  /// Gates on `runtime.isAvailable()`: unavailable → `failed(noModel)` with no
  /// build attempted (SPEC E7/C15). This reflects the *selected* runtime — a
  /// local model when local, an authorized+keyed cloud API when cloud — so a
  /// configured cloud runtime unblocks distillation even with no local model.
  /// Otherwise `running` (progress mirrored from the builder's log) →
  /// `done(persona, usedFallback)`. Any thrown error → `failed(buildFailed)`;
  /// nothing is saved.
  Future<void> run(
    Conversation conversation, {
    required PersonaRuntime runtime,
    LlmBuildOptions options = const LlmBuildOptions(),
  }) async {
    final int runId = ++_runId;
    final bool ready = await runtime.isAvailable();
    if (runId != _runId) {
      return;
    }
    if (!ready) {
      state = const DistillState(
        phase: DistillPhase.failed,
        error: DistillError.noModel,
      );
      return;
    }

    state = const DistillState(phase: DistillPhase.running);
    final List<String> log = <String>[];
    final LlmPersonaBuilder builder = _builderFactory((String line) {
      if (runId != _runId) {
        return;
      }
      log.add(line);
      state = state.copyWith(progressLog: List<String>.of(log));
    });

    try {
      final Persona persona = await builder.build(
        conversation,
        runtime: runtime,
        options: options.copyWith(beforeChunk: () => _gate(runId)),
      );
      if (runId != _runId) {
        return;
      }
      state = DistillState(
        phase: DistillPhase.done,
        progressLog: List<String>.of(log),
        persona: persona,
        usedFallback: _usedFallback(persona),
      );
    } on DistillCancelledException {
      return;
    } on Object {
      if (runId != _runId) {
        return;
      }
      state = DistillState(
        phase: DistillPhase.failed,
        progressLog: List<String>.of(log),
        error: DistillError.buildFailed,
      );
    }
  }

  /// Control gate the builder awaits at each chunk boundary.
  ///
  /// Returns immediately when running normally; parks on [_pauseGate] while
  /// paused; throws [DistillCancelledException] when this run was cancelled or
  /// superseded (its [runId] no longer current).
  Future<void> _gate(int runId) async {
    if (runId != _runId) {
      throw const DistillCancelledException();
    }
    final Completer<void>? gate = _pauseGate;
    if (gate != null) {
      await gate.future;
      if (runId != _runId) {
        throw const DistillCancelledException();
      }
    }
  }

  /// Pauses an in-progress run at the next chunk boundary.
  ///
  /// A no-op unless `phase == running` and not already paused. The in-flight
  /// chunk finishes first (on-device inference cannot be interrupted), then the
  /// build parks until [resume] or [cancel].
  void pause() {
    if (state.phase != DistillPhase.running || state.paused) {
      return;
    }
    _pauseGate ??= Completer<void>();
    state = state.copyWith(paused: true);
  }

  /// Resumes a paused run, releasing the build to continue.
  void resume() {
    if (!state.paused) {
      return;
    }
    _pauseGate?.complete();
    _pauseGate = null;
    state = state.copyWith(paused: false);
  }

  /// Stops an in-progress run and returns to `idle`, discarding progress.
  ///
  /// A no-op unless `phase == running`. On-device inference cannot be
  /// interrupted mid-chunk, so the current chunk finishes before the build
  /// observes the cancellation at the next chunk boundary; bumping the run id
  /// makes any late result or log from that run a no-op (SPEC-009 §2.6). Any
  /// paused build is released so it can observe the change and unwind.
  void cancel() {
    if (state.phase != DistillPhase.running) {
      return;
    }
    _runId++;
    _pauseGate?.complete();
    _pauseGate = null;
    state = const DistillState.idle();
  }

  /// Persists the reviewed persona.
  ///
  /// Precondition: `phase == done && persona != null` (otherwise a no-op). On
  /// success sets `saved`. On failure surfaces the store error in `saveError`
  /// and retains the persona so the user can retry (SPEC E11/C18).
  Future<void> save() async {
    final Persona? persona = state.persona;
    if (state.phase != DistillPhase.done || persona == null) {
      return;
    }
    try {
      await _repository.save(persona);
      state = DistillState(
        phase: DistillPhase.done,
        progressLog: state.progressLog,
        persona: persona,
        usedFallback: state.usedFallback,
        saved: true,
      );
    } on Object catch (error) {
      state = state.copyWith(saveError: error.toString());
    }
  }

  /// Resets back to the initial `idle` state.
  void reset() {
    state = const DistillState.idle();
  }

  bool _usedFallback(Persona persona) =>
      persona.notes.any((String note) => note.startsWith(_fallbackNotePrefix));
}
