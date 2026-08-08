import '../../models/persona.dart';
import '../../models/persona_summary.dart';
import '../../utils/app_logger.dart';
import '../persona/persona_codec.dart';
import 'persona_bytes_transform.dart';
import 'persona_directory.dart';

/// I/O / corruption error surfaced by [PersonaRepository.load] and
/// directory-level [PersonaRepository.list] failures (ERD-009 §5.1).
///
/// Distinct from [PersonaSchemaException] (schema too new), which passes
/// through `load()` unchanged.
class PersonaStoreException implements Exception {
  /// Creates the exception.
  const PersonaStoreException(this.message, {this.cause});

  /// Human-readable message (never contains persona content).
  final String message;

  /// The underlying cause, if any.
  final Object? cause;

  @override
  String toString() => 'PersonaStoreException: $message';
}

/// Result of [PersonaRepository.list]: the summaries (newest first) plus the
/// number of corrupt/unsupported files that were skipped during enumeration.
class PersonaListResult {
  /// Creates a list result.
  const PersonaListResult(this.summaries, {this.skippedCount = 0});

  /// Summaries, newest-first; an empty list is a valid result.
  final List<PersonaSummary> summaries;

  /// Corrupt/unsupported files skipped by this enumeration.
  final int skippedCount;
}

/// Durable persistence for distilled personas. One `${id}.persona` file each
/// (ERD-009 §5.1). The persisted bytes are exactly `PersonaJsonCodec.encode`
/// (plus the optional Module 008 transform); no second persistence schema.
abstract class PersonaRepository {
  /// Encode + write `${persona.id}.persona` (overwrites if present).
  Future<void> save(Persona persona);

  /// Enumerate saved personas as summaries, newest first. Corrupt/unsupported
  /// files are skipped (logged, counted), never crashing the list.
  Future<PersonaListResult> list();

  /// Decode a `.persona` file. Throws [PersonaSchemaException] (schema too new)
  /// or [PersonaStoreException] (I/O / missing / corrupt).
  Future<Persona> load(String personaId);

  /// Remove the file. Idempotent: deleting a missing persona is a no-op.
  Future<void> delete(String personaId);
}

/// Default [PersonaRepository] over a [PersonaDirectory], a [PersonaCodec], and
/// a [PersonaBytesTransform] (ERD-009 §3.2). All three are injected with
/// production defaults; host tests inject a [MemoryPersonaDirectory].
class FilePersonaRepository implements PersonaRepository {
  /// Creates a repository with injected collaborators.
  FilePersonaRepository({
    PersonaDirectory? directory,
    PersonaCodec? codec,
    PersonaBytesTransform? transform,
  })  : _directory = directory ?? PathProviderPersonaDirectory(),
        _codec = codec ?? const PersonaJsonCodec(),
        _transform = transform ?? const IdentityPersonaBytesTransform();

  static const String _tag = 'PersonaRepository';

  final PersonaDirectory _directory;
  final PersonaCodec _codec;
  final PersonaBytesTransform _transform;

  @override
  Future<void> save(Persona persona) async {
    if (persona.schemaVersion != kPersonaSchemaVersion) {
      throw PersonaStoreException(
        'unsupported schemaVersion ${persona.schemaVersion}',
      );
    }
    if (persona.id.isEmpty) {
      throw const PersonaStoreException('persona.id is empty');
    }
    try {
      final List<int> bytes = _transform.onWrite(_codec.encode(persona));
      await _directory.writeBytes(persona.id, bytes);
    } on PersonaStoreException {
      rethrow;
    } on Object catch (error) {
      throw PersonaStoreException('write failed for ${persona.id}',
          cause: error);
    }
  }

  @override
  Future<PersonaListResult> list() async {
    final List<String> ids;
    try {
      ids = await _directory.listIds();
    } on Object catch (error) {
      throw PersonaStoreException('directory unreadable', cause: error);
    }

    final List<PersonaSummary> summaries = <PersonaSummary>[];
    int skipped = 0;
    for (final String id in ids) {
      try {
        final List<int>? stored = await _directory.readBytes(id);
        if (stored == null) {
          continue;
        }
        final Persona persona = _codec.decode(_transform.onRead(stored));
        summaries.add(PersonaSummary.fromPersona(persona));
      } on Object catch (error) {
        skipped++;
        AppLogger.warning(_tag, 'skipped $id: ${error.runtimeType}');
      }
    }

    summaries.sort((PersonaSummary a, PersonaSummary b) {
      final int byTime = b.generatedAt.compareTo(a.generatedAt);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
    return PersonaListResult(summaries, skippedCount: skipped);
  }

  @override
  Future<Persona> load(String personaId) async {
    final List<int>? stored;
    try {
      stored = await _directory.readBytes(personaId);
    } on Object catch (error) {
      throw PersonaStoreException('read failed for $personaId', cause: error);
    }
    if (stored == null) {
      throw PersonaStoreException('not found: $personaId');
    }
    try {
      return _codec.decode(_transform.onRead(stored));
    } on PersonaSchemaException {
      rethrow;
    } on Object catch (error) {
      throw PersonaStoreException('corrupt: $personaId', cause: error);
    }
  }

  @override
  Future<void> delete(String personaId) async {
    try {
      await _directory.delete(personaId);
    } on Object catch (error) {
      throw PersonaStoreException('delete failed for $personaId',
          cause: error);
    }
  }
}
