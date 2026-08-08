import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/persona_library_state.dart';
import 'persona_repository.dart';

/// Drives [PersonaLibraryState] for the library screen (SPEC-009 §2.5).
class PersonaLibraryNotifier extends StateNotifier<PersonaLibraryState> {
  /// Creates the notifier; [repository] defaults to [FilePersonaRepository].
  PersonaLibraryNotifier({PersonaRepository? repository})
      : _repository = repository ?? FilePersonaRepository(),
        super(const PersonaLibraryState.loading());

  final PersonaRepository _repository;

  /// Reloads the summary list.
  ///
  /// `loading` → `ready(summaries, skippedCount)`; a directory-level failure
  /// (not a single bad file) → `failed(error)`. An empty library is a valid
  /// `ready` state, never `failed`.
  Future<void> refresh() async {
    state = const PersonaLibraryState.loading();
    try {
      final PersonaListResult result = await _repository.list();
      state = PersonaLibraryState.ready(
        result.summaries,
        skippedCount: result.skippedCount,
      );
    } on Object catch (error) {
      state = PersonaLibraryState.failed(error.toString());
    }
  }

  /// Deletes [id], then refreshes. On removal failure the state goes to
  /// `failed(error)` and the item remains in view (nothing is dropped locally).
  Future<void> delete(String id) async {
    try {
      await _repository.delete(id);
    } on Object catch (error) {
      state = PersonaLibraryState.failed(error.toString());
      return;
    }
    await refresh();
  }
}
