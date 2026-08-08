import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lostone/models/distill_state.dart';
import 'package:lostone/models/evidence.dart';
import 'package:lostone/models/persona_summary.dart';
import 'package:lostone/providers/persona_library_providers.dart';
import 'package:lostone/screens/persona_library/distill_flow_screen.dart';
import 'package:lostone/screens/persona_library/persona_library_screen.dart';
import 'package:lostone/services/persona_library/distill_notifier.dart';
import 'package:lostone/services/persona_library/persona_directory.dart';
import 'package:lostone/services/persona_library/persona_repository.dart';
import 'package:lostone/theme/app_theme.dart';

import '../helpers/persona_fixtures.dart';

class _RunningDistill extends DistillNotifier {
  _RunningDistill()
      : super(
          repository: FilePersonaRepository(directory: MemoryPersonaDirectory()),
        ) {
    state = const DistillState(
      phase: DistillPhase.running,
      progressLog: <String>['蒸馏分块数：2', '蒸馏第 1/2 块…'],
    );
  }
}

Widget _app(PersonaRepository repo) => ProviderScope(
      overrides: <Override>[
        personaRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const PersonaLibraryScreen(),
      ),
    );

void main() {
  test('badge predicate covers insufficient material and low confidence', () {
    final PersonaSummaryMatchers matchers = PersonaSummaryMatchers();
    matchers.expectBadged(
      identityConfidence: Confidence.high,
      emotionConfidence: Confidence.low,
    );
    matchers.expectBadged(insufficient: true);
    matchers.expectNotBadged();
  });

  testWidgets('C19 empty library shows empty state + dev harness button',
      (WidgetTester tester) async {
    final FilePersonaRepository repo =
        FilePersonaRepository(directory: MemoryPersonaDirectory());
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text('No personas yet'), findsOneWidget);
    expect(find.byKey(const Key('empty-create')), findsOneWidget);
    expect(find.byKey(const Key('open-harness')), findsOneWidget);
    expect(find.byKey(const Key('open-settings')), findsOneWidget);
  });

  testWidgets('C19 rows show name, relation and limited-data badge',
      (WidgetTester tester) async {
    final FilePersonaRepository repo =
        FilePersonaRepository(directory: MemoryPersonaDirectory());
    await repo.save(fixturePersona(
      id: 'p-strong',
      displayName: '妈妈',
    ));
    await repo.save(fixturePersona(
      id: 'p-weak',
      displayName: '爸爸',
      emotionConfidence: Confidence.low,
    ));
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text('妈妈'), findsOneWidget);
    expect(find.text('爸爸'), findsOneWidget);
    expect(find.text('mother'), findsWidgets);
    expect(find.byKey(const Key('limited-material-badge')), findsOneWidget);
    expect(find.byKey(const Key('persona-row-p-weak')), findsOneWidget);
  });

  testWidgets('resume banner appears while distilling and reopens the flow',
      (WidgetTester tester) async {
    final FilePersonaRepository repo =
        FilePersonaRepository(directory: MemoryPersonaDirectory());
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        personaRepositoryProvider.overrideWithValue(repo),
        distillProvider.overrideWith((Ref ref) => _RunningDistill()),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const PersonaLibraryScreen(),
      ),
    ));
    await tester.pump();

    expect(find.byKey(const Key('distill-status-banner')), findsOneWidget);
    expect(find.textContaining('Distilling'), findsWidgets);

    await tester.tap(find.byKey(const Key('distill-status-banner')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(DistillFlowScreen), findsOneWidget);
    expect(find.byKey(const Key('distill-chunk-progress')), findsOneWidget);
  });
}

class PersonaSummaryMatchers {
  void expectBadged({
    Confidence identityConfidence = Confidence.high,
    Confidence emotionConfidence = Confidence.high,
    bool insufficient = false,
  }) {
    final bool badged = limitedMaterialBadge(_summary(
      identityConfidence: identityConfidence,
      emotionConfidence: emotionConfidence,
      insufficient: insufficient,
    ));
    expect(badged, isTrue);
  }

  void expectNotBadged() {
    expect(
      limitedMaterialBadge(_summary(
        identityConfidence: Confidence.high,
        emotionConfidence: Confidence.high,
      )),
      isFalse,
    );
  }

  PersonaSummary _summary({
    required Confidence identityConfidence,
    required Confidence emotionConfidence,
    bool insufficient = false,
  }) =>
      PersonaSummary.fromPersona(fixturePersona(
        identityConfidence: identityConfidence,
        emotionConfidence: emotionConfidence,
        notes: insufficient
            ? <String>['原材料不足：情感层证据过少']
            : const <String>[],
      ));
}
