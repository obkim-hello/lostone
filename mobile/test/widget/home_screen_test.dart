import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lostone/models/app_config.dart';
import 'package:lostone/providers/app_providers.dart';
import 'package:lostone/screens/home_screen.dart';

void main() {
  testWidgets('HomeScreen should render the app name and environment',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appConfigProvider.overrideWith(
            (Ref ref) => AppConfig.production,
          ),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    expect(find.text('Lostone'), findsWidgets);
    expect(find.text('environment: production'), findsOneWidget);
    expect(find.text('version: 0.1.0'), findsOneWidget);
  });
}
