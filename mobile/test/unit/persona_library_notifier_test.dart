import 'package:flutter_test/flutter_test.dart';
import 'package:lostone/models/persona.dart';
import 'package:lostone/models/persona_library_state.dart';
import 'package:lostone/models/persona_summary.dart';
import 'package:lostone/services/persona_library/persona_directory.dart';
import 'package:lostone/services/persona_library/persona_library_notifier.dart';
import 'package:lostone/services/persona_library/persona_repository.dart';

import '../helpers/persona_fixtures.dart';

class _ThrowingListDirectory extends MemoryPersonaDirectory {
  @override
  Future<List<String>> listIds() async => throw StateError('boom');
}

class _ThrowingDeleteRepo implements PersonaRepository {
  @override
  Future<void> delete(String personaId) async =>
      throw const PersonaStoreException('delete failed');

  @override
  Future<Persona> load(String personaId) => throw UnimplementedError();

  @override
  Future<PersonaListResult> list() async =>
      const PersonaListResult(<PersonaSummary>[]);

  @override
  Future<void> save(Persona persona) => throw UnimplementedError();
}

void main() {
  late FilePersonaRepository repo;
  late PersonaLibraryNotifier notifier;

  setUp(() {
    repo = FilePersonaRepository(directory: MemoryPersonaDirectory());
    notifier = PersonaLibraryNotifier(repository: repo);
  });

  test('C9 空库为 ready([], 0)，非 failed', () async {
    await notifier.refresh();
    expect(notifier.state.phase, LibraryPhase.ready);
    expect(notifier.state.summaries, isEmpty);
    expect(notifier.state.skippedCount, 0);
  });

  test('C12 删除其一后 ready 只剩另一', () async {
    await repo.save(fixturePersona(id: 'persona-a'));
    await repo.save(fixturePersona(id: 'persona-b'));
    await notifier.refresh();
    expect(notifier.state.summaries, hasLength(2));

    await notifier.delete('persona-a');
    expect(notifier.state.phase, LibraryPhase.ready);
    expect(
      notifier.state.summaries.map((PersonaSummary s) => s.id),
      <String>['persona-b'],
    );
  });

  test('refresh 目录级失败 → failed', () async {
    final PersonaLibraryNotifier n = PersonaLibraryNotifier(
      repository: FilePersonaRepository(directory: _ThrowingListDirectory()),
    );
    await n.refresh();
    expect(n.state.phase, LibraryPhase.failed);
    expect(n.state.error, isNotNull);
  });

  test('delete 失败 → failed，条目不从视图移除', () async {
    final PersonaLibraryNotifier n =
        PersonaLibraryNotifier(repository: _ThrowingDeleteRepo());
    await n.delete('persona-a');
    expect(n.state.phase, LibraryPhase.failed);
    expect(n.state.error, isNotNull);
  });
}
