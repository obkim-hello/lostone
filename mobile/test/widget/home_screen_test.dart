import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lostone/providers/persona_library_providers.dart';
import 'package:lostone/screens/home_screen.dart';
import 'package:lostone/services/persona_library/persona_directory.dart';
import 'package:lostone/services/persona_library/persona_repository.dart';
import 'package:lostone/theme/app_theme.dart';

void main() {
  testWidgets('HomeScreen renders the persona library home', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          personaRepositoryProvider.overrideWithValue(
            FilePersonaRepository(directory: MemoryPersonaDirectory()),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lostone'), findsWidgets);
    expect(find.text('No personas yet'), findsOneWidget);
    expect(find.byKey(const Key('open-settings')), findsOneWidget);
  });
}
