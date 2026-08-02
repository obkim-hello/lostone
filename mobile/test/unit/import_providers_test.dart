import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lostone/models/message.dart';
import 'package:lostone/models/parse_result.dart';
import 'package:lostone/providers/import_providers.dart';

const String _fixtures = 'test/fixtures';

void main() {
  group('importStateProvider', () {
    test('starts idle', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final ImportState state = container.read(importStateProvider);
      expect(state.phase, ImportPhase.idle);
      expect(state.conversation, isNull);
      expect(state.error, isNull);
      expect(state.isTerminal, isFalse);
    });

    test('transitions to done with a conversation on success', () async {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(importStateProvider.notifier).importFiles(
        <String>['$_fixtures/wechat_sample.csv'],
        source: DataSource.wechat,
        options: const ParseOptions(myIdentifiers: <String>['我']),
      );

      final ImportState state = container.read(importStateProvider);
      expect(state.phase, ImportPhase.done);
      expect(state.isTerminal, isTrue);
      expect(state.conversation, isNotNull);
      expect(state.conversation!.messages, isNotEmpty);
      expect(state.error, isNull);
    });

    test('transitions to failed when all files fail', () async {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(importStateProvider.notifier).importFiles(
        <String>['$_fixtures/wechat_missing_col.csv'],
      );

      final ImportState state = container.read(importStateProvider);
      expect(state.phase, ImportPhase.failed);
      expect(state.isTerminal, isTrue);
      expect(state.conversation, isNull);
      expect(state.error, isNotNull);
    });

    test('reset returns to idle', () async {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final ImportNotifier notifier =
          container.read(importStateProvider.notifier);
      await notifier.importFiles(<String>['$_fixtures/wechat_sample.csv']);
      notifier.reset();

      expect(container.read(importStateProvider).phase, ImportPhase.idle);
    });
  });
}
