import 'package:flutter/foundation.dart';

import 'evidence.dart';
import 'persona.dart';

/// True when [note] is one of the honest "insufficient material" notes that
/// Modules 003/004 emit for an under-supported layer (prefixed `原材料不足：`).
bool isInsufficientMaterialNote(String note) => note.startsWith('原材料不足');

/// Lightweight library-list projection of a [Persona] (ERD-009 §4.1).
///
/// Derived read-time from a decoded persona so the library never renders raw
/// text and need not materialize heavy layer bodies for the list.
@immutable
class PersonaSummary {
  /// Creates a summary.
  const PersonaSummary({
    required this.id,
    required this.displayName,
    required this.relationToUser,
    required this.generatedAt,
    required this.hasInsufficientMaterial,
    required this.lowestLayerConfidence,
  });

  /// Projects a [PersonaSummary] from a decoded [persona].
  factory PersonaSummary.fromPersona(Persona persona) {
    Confidence min(Confidence a, Confidence b) =>
        a.index <= b.index ? a : b;
    final Confidence lowest = <Confidence>[
      persona.expressionStyle.confidence,
      persona.emotionalLogic.confidence,
      persona.relationalBehavior.confidence,
    ].fold(persona.identity.confidence, min);
    return PersonaSummary(
      id: persona.id,
      displayName: persona.identity.displayName,
      relationToUser: persona.identity.relationToUser,
      generatedAt: persona.generatedAt.toUtc(),
      hasInsufficientMaterial:
          persona.notes.any(isInsufficientMaterialNote),
      lowestLayerConfidence: lowest,
    );
  }

  /// Persona id (deterministic, from Module 004).
  final String id;

  /// `identity.displayName` (never empty; Module 004 defaults it).
  final String displayName;

  /// `identity.relationToUser` (may be null).
  final String? relationToUser;

  /// Generation time (UTC); the list sort key (newest first).
  final DateTime generatedAt;

  /// Whether any layer was flagged as built on insufficient material.
  final bool hasInsufficientMaterial;

  /// Minimum confidence across the four analyzed layers.
  final Confidence lowestLayerConfidence;

  @override
  bool operator ==(Object other) =>
      other is PersonaSummary &&
      other.id == id &&
      other.displayName == displayName &&
      other.relationToUser == relationToUser &&
      other.generatedAt == generatedAt &&
      other.hasInsufficientMaterial == hasInsufficientMaterial &&
      other.lowestLayerConfidence == lowestLayerConfidence;

  @override
  int get hashCode => Object.hash(
        id,
        displayName,
        relationToUser,
        generatedAt,
        hasInsufficientMaterial,
        lowestLayerConfidence,
      );
}
