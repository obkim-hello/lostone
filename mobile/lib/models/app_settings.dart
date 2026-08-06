import 'package:flutter/foundation.dart';

import '../services/llm/llm_persona_builder.dart' show PersonaRuntimeMode;

/// User-facing runtime choice (ERD-010 §4.1); maps 1:1 to Module 004
/// [PersonaRuntimeMode].
enum RuntimeChoice {
  /// Local on-device inference (default; original text never leaves the device).
  local,

  /// Cloud API inference (explicit opt-in).
  cloud,

  /// Maximum privacy: never invoke an LLM (statistical fallback / chat disabled).
  maxPrivacy,
}

/// Maps a [RuntimeChoice] to the Module 004 [PersonaRuntimeMode] it represents.
PersonaRuntimeMode toRuntimeMode(RuntimeChoice choice) => switch (choice) {
  RuntimeChoice.local => PersonaRuntimeMode.local,
  RuntimeChoice.cloud => PersonaRuntimeMode.cloud,
  RuntimeChoice.maxPrivacy => PersonaRuntimeMode.maxPrivacy,
};

const Object _unset = Object();

/// Immutable, non-secret user settings (ERD-010 §4.1 / SPEC-010 §2.1).
///
/// Persisted via `SettingsRepository` (Hive); read by Modules 006/009 through
/// `appSettingsProvider`. It carries **no secret** — the cloud API key and HF
/// token live only in secure storage, never as fields here.
@immutable
class AppSettings {
  /// Creates a settings value; every field has a local-by-default default.
  const AppSettings({
    this.runtime = RuntimeChoice.local,
    this.cloudAuthorized = false,
    this.activeModelId,
    this.chatTemperature = 0.7,
  });

  /// Selected runtime mode (default [RuntimeChoice.local]).
  final RuntimeChoice runtime;

  /// Whether the user has opted in to cloud inference (default `false`).
  final bool cloudAuthorized;

  /// Mirror of Module 007's active model id (source of truth remains
  /// `ModelRepository.getActiveModelHandle`); `null` when none is active.
  final String? activeModelId;

  /// Chat/distill sampling temperature, clamped to `[0.0, 1.0]` (default 0.7).
  final double chatTemperature;

  /// The Module 004 runtime mode this settings value maps to.
  PersonaRuntimeMode get runtimeMode => toRuntimeMode(runtime);

  /// Returns a copy with the given overrides.
  ///
  /// [activeModelId] is nullable-aware: omit it to keep the current value, or
  /// pass `null` explicitly to clear the active model.
  AppSettings copyWith({
    RuntimeChoice? runtime,
    bool? cloudAuthorized,
    Object? activeModelId = _unset,
    double? chatTemperature,
  }) {
    return AppSettings(
      runtime: runtime ?? this.runtime,
      cloudAuthorized: cloudAuthorized ?? this.cloudAuthorized,
      activeModelId: identical(activeModelId, _unset)
          ? this.activeModelId
          : activeModelId as String?,
      chatTemperature: chatTemperature ?? this.chatTemperature,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.runtime == runtime &&
      other.cloudAuthorized == cloudAuthorized &&
      other.activeModelId == activeModelId &&
      other.chatTemperature == chatTemperature;

  @override
  int get hashCode =>
      Object.hash(runtime, cloudAuthorized, activeModelId, chatTemperature);

  @override
  String toString() =>
      'AppSettings(runtime: $runtime, cloudAuthorized: $cloudAuthorized, '
      'activeModelId: $activeModelId, chatTemperature: $chatTemperature)';
}
