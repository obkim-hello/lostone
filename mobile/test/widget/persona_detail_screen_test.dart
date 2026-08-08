import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lostone/models/evidence.dart';
import 'package:lostone/models/memories.dart';
import 'package:lostone/models/persona_summary.dart';
import 'package:lostone/providers/persona_library_providers.dart';
import 'package:lostone/screens/persona_library/persona_detail_screen.dart';
import 'package:lostone/services/persona_library/persona_directory.dart';
import 'package:lostone/services/persona_library/persona_repository.dart';
import 'package:lostone/theme/app_theme.dart';

import '../helpers/persona_fixtures.dart';

Widget _app(PersonaRepository repo, PersonaSummary summary) => ProviderScope(
      overrides: <Override>[
        personaRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: PersonaDetailScreen(summary: summary),
      ),
    );

void main() {
  testWidgets('renders full persona layers loaded from the repository',
      (WidgetTester tester) async {
    final FilePersonaRepository repo =
        FilePersonaRepository(directory: MemoryPersonaDirectory());
    const Evidence evidence = Evidence(occurrences: 3);
    await repo.save(fixturePersona(
      id: 'p-full',
      displayName: '妈妈',
      aliases: const <String>['老妈'],
      catchphrases: const <TermStat>[TermStat(term: '记得吃饭', count: 4)],
      tags: const <PersonaTag>[PersonaTag(label: '关心型', evidence: evidence)],
      preferences: const <Preference>[
        Preference(term: '喝茶', count: 2, evidence: evidence),
      ],
    ));
    final PersonaSummary summary =
        PersonaSummary.fromPersona(fixturePersona(id: 'p-full'));

    await tester.pumpWidget(_app(repo, summary));
    await tester.pumpAndSettle();

    expect(find.text('IDENTITY'), findsOneWidget);
    expect(find.text('HOW THEY TALK'), findsOneWidget);
    expect(find.text('老妈'), findsOneWidget);
    expect(find.text('记得吃饭 · 4'), findsOneWidget);

    final Finder list = find.byType(Scrollable);
    await tester.scrollUntilVisible(find.text('RELATIONSHIP'), 300,
        scrollable: list);
    expect(find.text('RELATIONSHIP'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('关心型'), 300, scrollable: list);
    expect(find.text('关心型'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('喝茶'), 300, scrollable: list);
    expect(find.text('喝茶'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.byKey(const Key('detail-delete')), 300,
        scrollable: list);
    expect(find.byKey(const Key('detail-delete')), findsOneWidget);
  });

  testWidgets('shows honesty notes when the persona carries them',
      (WidgetTester tester) async {
    final FilePersonaRepository repo =
        FilePersonaRepository(directory: MemoryPersonaDirectory());
    await repo.save(fixturePersona(
      id: 'p-weak',
      notes: const <String>['原材料不足：情感层证据过少'],
    ));
    final PersonaSummary summary = PersonaSummary.fromPersona(fixturePersona(
      id: 'p-weak',
      notes: const <String>['原材料不足：情感层证据过少'],
    ));

    await tester.pumpWidget(_app(repo, summary));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('detail-notes')), findsOneWidget);
    expect(find.text('原材料不足：情感层证据过少'), findsOneWidget);
  });

  testWidgets('delete confirmation removes the persona and pops',
      (WidgetTester tester) async {
    final FilePersonaRepository repo =
        FilePersonaRepository(directory: MemoryPersonaDirectory());
    await repo.save(fixturePersona(id: 'p-del'));
    final PersonaSummary summary =
        PersonaSummary.fromPersona(fixturePersona(id: 'p-del'));

    await tester.pumpWidget(_app(repo, summary));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
        find.byKey(const Key('detail-delete')), 300,
        scrollable: find.byType(Scrollable));
    await tester.tap(find.byKey(const Key('detail-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail-delete-confirm')));
    await tester.pumpAndSettle();

    final PersonaListResult result = await repo.list();
    expect(result.summaries, isEmpty);
  });
}
