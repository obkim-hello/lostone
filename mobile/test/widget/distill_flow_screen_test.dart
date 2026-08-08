import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lostone/models/conversation.dart';
import 'package:lostone/models/message.dart';
import 'package:lostone/models/parse_result.dart';
import 'package:lostone/models/persona.dart';
import 'package:lostone/providers/debug_providers.dart';
import 'package:lostone/providers/import_providers.dart';
import 'package:lostone/providers/persona_library_providers.dart';
import 'package:lostone/services/llm/llm_persona_builder.dart';
import 'package:lostone/services/llm/mock_runtime.dart';
import 'package:lostone/services/llm/persona_runtime.dart';
import 'package:lostone/services/model/token_store.dart';
import 'package:lostone/services/settings/secure_key_store.dart';
import 'package:lostone/services/settings/settings_repository.dart';
import 'package:lostone/providers/settings_providers.dart';
import 'package:lostone/services/persona_library/distill_notifier.dart';
import 'package:lostone/services/persona_library/persona_directory.dart';
import 'package:lostone/services/persona_library/persona_repository.dart';
import 'package:lostone/screens/persona_library/distill_flow_screen.dart';
import 'package:lostone/screens/settings/settings_screen.dart';
import 'package:lostone/theme/app_theme.dart';

import '../helpers/fake_file_picker.dart';
import '../helpers/persona_fixtures.dart';

class _FakeBuilder implements LlmPersonaBuilder {
  _FakeBuilder({
    required this.onLog,
    this.result,
    this.throwError = false,
    this.gate,
    this.logs = const <String>[],
  });

  final void Function(String) onLog;
  final Persona? result;
  final bool throwError;
  final Future<void>? gate;
  final List<String> logs;

  @override
  Future<Persona> build(
    Conversation conversation, {
    required PersonaRuntime runtime,
    LlmBuildOptions options = const LlmBuildOptions(),
  }) async {
    for (final String line in logs) {
      onLog(line);
    }
    if (gate != null) {
      await gate;
    }
    if (throwError) {
      throw StateError('boom');
    }
    return result!;
  }

  @override
  Future<Persona> update(
    Persona existing,
    Conversation newConversation, {
    required PersonaRuntime runtime,
    LlmBuildOptions options = const LlmBuildOptions(),
  }) =>
      throw UnimplementedError();
}

class _FakeImportNotifier extends ImportNotifier {
  _FakeImportNotifier({this.result});

  final ImportState? result;
  final List<List<String>> importCalls = <List<String>>[];
  DataSource? lastSource;

  @override
  Future<void> importFiles(
    List<String> filePaths, {
    DataSource? source,
    ParseOptions options = const ParseOptions(),
  }) async {
    importCalls.add(filePaths);
    lastSource = source;
    if (result != null) {
      state = result!;
    }
  }
}

class _RecordingDistillNotifier extends DistillNotifier {
  _RecordingDistillNotifier()
      : super(
          repository:
              FilePersonaRepository(directory: MemoryPersonaDirectory()),
        );

  final List<Conversation> runCalls = <Conversation>[];
  final List<LlmBuildOptions> optionsCalls = <LlmBuildOptions>[];

  @override
  Future<void> run(
    Conversation conversation, {
    required PersonaRuntime runtime,
    LlmBuildOptions options = const LlmBuildOptions(),
  }) async {
    runCalls.add(conversation);
    optionsCalls.add(options);
  }
}

Conversation _conversation() {
  final Message message = Message(
    id: 'm1',
    source: DataSource.wechat,
    senderId: 'mom',
    senderName: '妈妈',
    isFromMe: false,
    timestamp: DateTime.utc(2024, 1, 1, 20),
    type: MessageType.text,
    content: '早点睡',
  );
  return Conversation(
    source: DataSource.wechat,
    participants: const <String>['mom', 'me'],
    messages: <Message>[message],
    stats: ImportStats(
      totalParsed: 1,
      afterDedup: 1,
      skipped: 0,
      earliest: message.timestamp,
      latest: message.timestamp,
    ),
  );
}

Widget _app(List<Override> overrides) => ProviderScope(
      overrides: <Override>[
        personaRuntimeProvider.overrideWithValue(MockRuntime(response: 'ok')),
        settingsRepositoryProvider
            .overrideWithValue(InMemorySettingsRepository()),
        cloudKeyStoreProvider.overrideWithValue(InMemorySecureKeyStore()),
        hfTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        ...overrides,
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const DistillFlowScreen(),
      ),
    );

void main() {
  group('distillChunkProgress', () {
    test('reads total from count line and current from chunk line', () {
      final DistillChunkProgress p = distillChunkProgress(<String>[
        '蒸馏分块数：3',
        '蒸馏第 1/3 块…',
        '蒸馏第 2/3 块…',
      ]);
      expect(p.total, 3);
      expect(p.current, 2);
    });

    test('total known before first chunk, current still 0', () {
      final DistillChunkProgress p =
          distillChunkProgress(<String>['蒸馏分块数：5']);
      expect(p.total, 5);
      expect(p.current, 0);
    });

    test('empty log → zeroes', () {
      final DistillChunkProgress p = distillChunkProgress(const <String>[]);
      expect(p.total, 0);
      expect(p.current, 0);
    });
  });

  testWidgets('C22 import cancel/empty → "No file selected", no import',
      (WidgetTester tester) async {
    final FakeFilePicker picker = FakeFilePicker(files: const <String>[]);
    final _FakeImportNotifier import = _FakeImportNotifier();
    await tester.pumpWidget(_app(<Override>[
      filePickerFacadeProvider.overrideWithValue(picker),
      importStateProvider.overrideWith((Ref ref) => import),
      distillProvider.overrideWith((Ref ref) => _RecordingDistillNotifier()),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pick-source')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('no-file-selected')), findsOneWidget);
    expect(import.importCalls, isEmpty);
    expect(find.byKey(const Key('distill-review-card')), findsNothing);
  });

  testWidgets('C23 import parse failure → error + retry, nothing distilled',
      (WidgetTester tester) async {
    final FakeFilePicker picker =
        FakeFilePicker(files: const <String>['/tmp/chat.csv']);
    final _FakeImportNotifier import = _FakeImportNotifier(
      result: const ImportState(
        phase: ImportPhase.failed,
        error: 'bad file',
      ),
    );
    await tester.pumpWidget(_app(<Override>[
      filePickerFacadeProvider.overrideWithValue(picker),
      importStateProvider.overrideWith((Ref ref) => import),
      distillProvider.overrideWith((Ref ref) => _RecordingDistillNotifier()),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pick-source')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('import-error')), findsOneWidget);
    expect(find.byKey(const Key('import-retry')), findsOneWidget);
    expect(find.byKey(const Key('distill-review-card')), findsNothing);
  });

  testWidgets('C24 import success → conversation handed to DistillNotifier.run',
      (WidgetTester tester) async {
    final FakeFilePicker picker =
        FakeFilePicker(files: const <String>['/tmp/chat.csv']);
    final Conversation conversation = _conversation();
    final _FakeImportNotifier import = _FakeImportNotifier(
      result: ImportState(
        phase: ImportPhase.done,
        conversation: conversation,
      ),
    );
    final _RecordingDistillNotifier distill = _RecordingDistillNotifier();
    await tester.pumpWidget(_app(<Override>[
      filePickerFacadeProvider.overrideWithValue(picker),
      importStateProvider.overrideWith((Ref ref) => import),
      distillProvider.overrideWith((Ref ref) => distill),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pick-source')));
    await tester.pumpAndSettle();

    expect(import.importCalls, <List<String>>[<String>['/tmp/chat.csv']]);
    expect(distill.runCalls, hasLength(1));
    expect(distill.runCalls.single, same(conversation));
    expect(
      distill.optionsCalls.single.maxChunkMessages,
      distillChunkMessages,
    );
  });

  testWidgets('C25 directory source → importFiles([dir], source: imessage)',
      (WidgetTester tester) async {
    final FakeFilePicker picker = FakeFilePicker(directory: '/tmp/chatdb');
    final _FakeImportNotifier import = _FakeImportNotifier(
      result: ImportState(
        phase: ImportPhase.done,
        conversation: _conversation(),
      ),
    );
    await tester.pumpWidget(_app(<Override>[
      filePickerFacadeProvider.overrideWithValue(picker),
      importStateProvider.overrideWith((Ref ref) => import),
      distillProvider.overrideWith((Ref ref) => _RecordingDistillNotifier()),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('source-imessage')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pick-source')));
    await tester.pumpAndSettle();

    expect(picker.pickDirectoryCalls, 1);
    expect(import.importCalls, <List<String>>[<String>['/tmp/chatdb']]);
    expect(import.lastSource, DataSource.imessage);
  });

  testWidgets('C25 directory source cancel (null) → no import',
      (WidgetTester tester) async {
    final FakeFilePicker picker = FakeFilePicker();
    final _FakeImportNotifier import = _FakeImportNotifier();
    await tester.pumpWidget(_app(<Override>[
      filePickerFacadeProvider.overrideWithValue(picker),
      importStateProvider.overrideWith((Ref ref) => import),
      distillProvider.overrideWith((Ref ref) => _RecordingDistillNotifier()),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('source-photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pick-source')));
    await tester.pumpAndSettle();

    expect(picker.pickDirectoryCalls, 1);
    expect(import.importCalls, isEmpty);
    expect(find.byKey(const Key('no-file-selected')), findsOneWidget);
  });

  testWidgets('C20 distill running shows progress + log',
      (WidgetTester tester) async {
    final Completer<void> gate = Completer<void>();
    final DistillNotifier distill = DistillNotifier(
      repository: FilePersonaRepository(directory: MemoryPersonaDirectory()),
      builderFactory: (void Function(String) onLog) => _FakeBuilder(
        onLog: onLog,
        gate: gate.future,
        result: fixturePersona(),
        logs: const <String>['蒸馏分块数：2', '蒸馏第 1/2 块…'],
      ),
    );
    await tester.pumpWidget(_app(<Override>[
      distillProvider.overrideWith((Ref ref) => distill),
    ]));
    await tester.pumpAndSettle();

    unawaited(distill.run(_conversation(), runtime: MockRuntime(response: 'ok')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Distilling chunk 1 of 2…'), findsOneWidget);
    expect(find.byKey(const Key('distill-chunk-progress')), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.byKey(const Key('distill-log')), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('C20 debug mode reveals the raw console log',
      (WidgetTester tester) async {
    final Completer<void> gate = Completer<void>();
    final DistillNotifier distill = DistillNotifier(
      repository: FilePersonaRepository(directory: MemoryPersonaDirectory()),
      builderFactory: (void Function(String) onLog) => _FakeBuilder(
        onLog: onLog,
        gate: gate.future,
        result: fixturePersona(),
        logs: const <String>['蒸馏分块数：2', '蒸馏第 1/2 块…'],
      ),
    );
    await tester.pumpWidget(_app(<Override>[
      distillProvider.overrideWith((Ref ref) => distill),
      debugModeProvider.overrideWith((Ref ref) => true),
    ]));
    await tester.pumpAndSettle();

    unawaited(distill.run(_conversation(), runtime: MockRuntime(response: 'ok')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('distill-log')), findsOneWidget);
    expect(find.textContaining('蒸馏分块数：2'), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('C20 running exposes pause/resume and stop controls',
      (WidgetTester tester) async {
    final Completer<void> gate = Completer<void>();
    final DistillNotifier distill = DistillNotifier(
      repository: FilePersonaRepository(directory: MemoryPersonaDirectory()),
      builderFactory: (void Function(String) onLog) => _FakeBuilder(
        onLog: onLog,
        gate: gate.future,
        result: fixturePersona(),
        logs: const <String>['蒸馏分块数：2', '蒸馏第 1/2 块…'],
      ),
    );
    await tester.pumpWidget(_app(<Override>[
      distillProvider.overrideWith((Ref ref) => distill),
    ]));
    await tester.pumpAndSettle();

    unawaited(distill.run(_conversation(), runtime: MockRuntime(response: 'ok')));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('distill-pause')), findsOneWidget);
    expect(find.byKey(const Key('distill-stop')), findsOneWidget);
    expect(find.byKey(const Key('distill-resume')), findsNothing);

    await tester.tap(find.byKey(const Key('distill-pause')));
    await tester.pump();
    expect(find.byKey(const Key('distill-resume')), findsOneWidget);
    expect(find.byKey(const Key('distill-pause')), findsNothing);
    expect(find.text('Paused'), findsOneWidget);

    await tester.tap(find.byKey(const Key('distill-resume')));
    await tester.pump();
    expect(find.byKey(const Key('distill-pause')), findsOneWidget);

    await tester.tap(find.byKey(const Key('distill-stop')));
    await tester.pumpAndSettle();
    expect(find.text('Stop distilling?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('distill-stop-confirm')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pick-source')), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('reopening the flow with a run in progress does not reset it',
      (WidgetTester tester) async {
    final Completer<void> gate = Completer<void>();
    final DistillNotifier distill = DistillNotifier(
      repository: FilePersonaRepository(directory: MemoryPersonaDirectory()),
      builderFactory: (void Function(String) onLog) => _FakeBuilder(
        onLog: onLog,
        gate: gate.future,
        result: fixturePersona(),
        logs: const <String>['蒸馏分块数：2', '蒸馏第 1/2 块…'],
      ),
    );
    unawaited(distill.run(_conversation(), runtime: MockRuntime(response: 'ok')));

    await tester.pumpWidget(_app(<Override>[
      distillProvider.overrideWith((Ref ref) => distill),
    ]));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('distill-chunk-progress')), findsOneWidget);
    expect(find.byKey(const Key('pick-source')), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('C20 distill done shows review card + notes + save',
      (WidgetTester tester) async {
    final DistillNotifier distill = DistillNotifier(
      repository: FilePersonaRepository(directory: MemoryPersonaDirectory()),
      builderFactory: (void Function(String) onLog) => _FakeBuilder(
        onLog: onLog,
        result: fixturePersona(
          displayName: '奶奶',
          notes: <String>['统计兜底：最大隐私模式，未调用 LLM'],
        ),
        logs: const <String>['蒸馏第 1/1 块…', '蒸馏生成失败：RuntimeError.inferenceFailed'],
      ),
    );
    await tester.pumpWidget(_app(<Override>[
      distillProvider.overrideWith((Ref ref) => distill),
    ]));
    await tester.pumpAndSettle();

    await distill.run(_conversation(), runtime: MockRuntime(response: 'ok'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('distill-review-card')), findsOneWidget);
    expect(find.text('奶奶'), findsOneWidget);
    expect(find.byKey(const Key('fallback-badge')), findsOneWidget);
    expect(find.byKey(const Key('distill-save')), findsOneWidget);
    expect(find.textContaining('统计兜底'), findsOneWidget);
    expect(find.byKey(const Key('distill-fallback-log')), findsOneWidget);
    expect(find.textContaining('蒸馏生成失败'), findsOneWidget);
  });

  testWidgets('C20 distill no-model prompt routes to settings (010)',
      (WidgetTester tester) async {
    final DistillNotifier distill = DistillNotifier(
      repository: FilePersonaRepository(directory: MemoryPersonaDirectory()),
      builderFactory: (void Function(String) onLog) =>
          _FakeBuilder(onLog: onLog, result: fixturePersona()),
    );
    await tester.pumpWidget(_app(<Override>[
      distillProvider.overrideWith((Ref ref) => distill),
    ]));
    await tester.pumpAndSettle();

    await distill.run(_conversation(), runtime: MockRuntime(available: false));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('distill-open-settings')), findsOneWidget);
    await tester.tap(find.byKey(const Key('distill-open-settings')));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('C20 distill build failure shows error + retry',
      (WidgetTester tester) async {
    final DistillNotifier distill = DistillNotifier(
      repository: FilePersonaRepository(directory: MemoryPersonaDirectory()),
      builderFactory: (void Function(String) onLog) =>
          _FakeBuilder(onLog: onLog, throwError: true),
    );
    await tester.pumpWidget(_app(<Override>[
      distillProvider.overrideWith((Ref ref) => distill),
    ]));
    await tester.pumpAndSettle();

    await distill.run(_conversation(), runtime: MockRuntime(response: 'ok'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('distill-error')), findsOneWidget);
    expect(find.byKey(const Key('distill-retry')), findsOneWidget);
  });
}
