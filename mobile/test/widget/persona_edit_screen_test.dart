import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lostone/models/persona.dart';
import 'package:lostone/providers/persona_library_providers.dart';
import 'package:lostone/screens/persona_library/persona_edit_screen.dart';
import 'package:lostone/services/persona_library/persona_directory.dart';
import 'package:lostone/services/persona_library/persona_repository.dart';
import 'package:lostone/theme/app_theme.dart';

import '../helpers/persona_fixtures.dart';

Widget _app(PersonaRepository repo, Persona persona) => ProviderScope(
      overrides: <Override>[
        personaRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: PersonaEditScreen(persona: persona),
      ),
    );

void main() {
  testWidgets('editing identity + notes bumps version and records an audit note',
      (WidgetTester tester) async {
    final FilePersonaRepository repo =
        FilePersonaRepository(directory: MemoryPersonaDirectory());
    final Persona original = fixturePersona(
      id: 'p-edit',
      displayName: '妈妈',
      notes: const <String>['原材料不足：情感层证据过少'],
    );
    await repo.save(original);

    await tester.pumpWidget(_app(repo, original));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('edit-name')), '妈妈 (edited)');
    await tester.enterText(find.byKey(const Key('edit-relation')), 'mom');
    await tester.enterText(
        find.byKey(const Key('edit-aliases')), 'ma\nmama');
    await tester.tap(find.byKey(const Key('edit-save')));
    await tester.pumpAndSettle();

    final Persona saved = await repo.load('p-edit');
    expect(saved.identity.displayName, '妈妈 (edited)');
    expect(saved.identity.relationToUser, 'mom');
    expect(saved.identity.aliases, <String>['ma', 'mama']);
    expect(saved.personaVersion, 2);
    expect(saved.source.revisions.length, 2);
    expect(saved.source.revisions.last.personaVersion, 2);
    expect(
      saved.notes.where((String n) => n.startsWith(kManualEditNotePrefix)),
      hasLength(1),
    );
    expect(saved.notes, contains('原材料不足：情感层证据过少'));
  });

  testWidgets('re-editing does not accumulate duplicate audit notes',
      (WidgetTester tester) async {
    final FilePersonaRepository repo =
        FilePersonaRepository(directory: MemoryPersonaDirectory());
    final Persona base = fixturePersona(id: 'p-again');
    final Persona edited = base.copyWith(
      personaVersion: 2,
      notes: <String>['${kManualEditNotePrefix}2026-08-06'],
      source: base.source.copyWith(
        revisions: <SourceRevision>[
          ...base.source.revisions,
          const SourceRevision(
            personaVersion: 2,
            personMessages: 5,
            totalMessages: 10,
          ),
        ],
      ),
    );
    await repo.save(edited);

    await tester.pumpWidget(_app(repo, edited));
    await tester.pumpAndSettle();

    expect(find.text('${kManualEditNotePrefix}2026-08-06'), findsNothing);

    await tester.tap(find.byKey(const Key('edit-save')));
    await tester.pumpAndSettle();

    final Persona saved = await repo.load('p-again');
    expect(saved.personaVersion, 3);
    expect(
      saved.notes.where((String n) => n.startsWith(kManualEditNotePrefix)),
      hasLength(1),
    );
  });

  testWidgets('an empty display name blocks saving', (WidgetTester tester) async {
    final FilePersonaRepository repo =
        FilePersonaRepository(directory: MemoryPersonaDirectory());
    final Persona original = fixturePersona(id: 'p-empty');
    await repo.save(original);

    await tester.pumpWidget(_app(repo, original));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('edit-name')), '   ');
    await tester.tap(find.byKey(const Key('edit-save')));
    await tester.pumpAndSettle();

    expect(find.text('A display name is required.'), findsOneWidget);
    final Persona saved = await repo.load('p-empty');
    expect(saved.personaVersion, 1);
  });
}
