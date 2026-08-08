import 'package:flutter_test/flutter_test.dart';
import 'package:lostone/models/conversation.dart';
import 'package:lostone/models/distill_state.dart';
import 'package:lostone/models/persona.dart';
import 'package:lostone/services/llm/llm_persona_builder.dart';
import 'package:lostone/services/llm/mock_runtime.dart';
import 'package:lostone/services/llm/persona_runtime.dart';
import 'package:lostone/services/persona_library/distill_notifier.dart';
import 'package:lostone/services/persona_library/persona_directory.dart';
import 'package:lostone/services/persona_library/persona_repository.dart';

import '../helpers/persona_fixtures.dart';

class _FakeBuilder implements LlmPersonaBuilder {
  _FakeBuilder({
    required this.onLog,
    this.result,
    this.throwError = false,
    this.logs = const <String>[],
  });

  final void Function(String) onLog;
  final Persona? result;
  final bool throwError;
  final List<String> logs;

  bool buildCalled = false;

  @override
  Future<Persona> build(
    Conversation conversation, {
    required PersonaRuntime runtime,
    LlmBuildOptions options = const LlmBuildOptions(),
  }) async {
    buildCalled = true;
    for (final String line in logs) {
      onLog(line);
    }
    if (throwError) {
      throw StateError('build blew up');
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

class _SteppedBuilder implements LlmPersonaBuilder {
  _SteppedBuilder({
    required this.onLog,
    required this.result,
    this.chunks = 4,
  });

  static const Duration _stepDelay = Duration(milliseconds: 5);

  final void Function(String) onLog;
  final Persona result;
  final int chunks;

  int completedChunks = 0;

  @override
  Future<Persona> build(
    Conversation conversation, {
    required PersonaRuntime runtime,
    LlmBuildOptions options = const LlmBuildOptions(),
  }) async {
    onLog('蒸馏分块数：$chunks');
    for (int i = 0; i < chunks; i++) {
      if (options.beforeChunk != null) {
        await options.beforeChunk!();
      }
      onLog('蒸馏第 ${i + 1}/$chunks 块…');
      completedChunks++;
      await Future<void>.delayed(_stepDelay);
    }
    return result;
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

class _ThrowingSaveRepo implements PersonaRepository {
  @override
  Future<void> save(Persona persona) async =>
      throw const PersonaStoreException('disk full');

  @override
  Future<void> delete(String personaId) => throw UnimplementedError();

  @override
  Future<Persona> load(String personaId) => throw UnimplementedError();

  @override
  Future<PersonaListResult> list() => throw UnimplementedError();
}

void main() {
  final MockRuntime runtime = MockRuntime(response: 'ok');

  test('C13 happy path: idle→running→done→save', () async {
    final MemoryPersonaDirectory dir = MemoryPersonaDirectory();
    final FilePersonaRepository repo = FilePersonaRepository(directory: dir);
    final Persona persona = fixturePersona(id: 'persona-happy');
    bool ranRunning = false;

    final DistillNotifier notifier = DistillNotifier(
      repository: repo,
      builderFactory: (void Function(String) onLog) => _FakeBuilder(
        onLog: onLog,
        result: persona,
        logs: const <String>['蒸馏分块数：1'],
      ),
    );
    notifier.addListener((DistillState s) {
      if (s.phase == DistillPhase.running) {
        ranRunning = true;
      }
    });

    await notifier.run(emptyConversation(), runtime: runtime);
    expect(ranRunning, isTrue);
    expect(notifier.state.phase, DistillPhase.done);
    expect(notifier.state.persona, persona);
    expect(notifier.state.progressLog, contains('蒸馏分块数：1'));
    expect(notifier.state.usedFallback, isFalse);

    await notifier.save();
    expect(notifier.state.saved, isTrue);
    expect((await repo.list()).summaries.single.id, 'persona-happy');
  });

  test('C14 fallback notes → done(usedFallback=true) 且可保存', () async {
    final MemoryPersonaDirectory dir = MemoryPersonaDirectory();
    final FilePersonaRepository repo = FilePersonaRepository(directory: dir);
    final Persona persona = fixturePersona(
      id: 'persona-fb',
      notes: <String>['统计兜底：最大隐私模式，未调用 LLM'],
    );
    final DistillNotifier notifier = DistillNotifier(
      repository: repo,
      builderFactory: (void Function(String) onLog) =>
          _FakeBuilder(onLog: onLog, result: persona),
    );

    await notifier.run(emptyConversation(), runtime: runtime);
    expect(notifier.state.phase, DistillPhase.done);
    expect(notifier.state.usedFallback, isTrue);

    await notifier.save();
    expect(notifier.state.saved, isTrue);
  });

  test('C15 runtime 不可用 → failed(noModel)，builder 从不调用', () async {
    _FakeBuilder? built;
    final DistillNotifier notifier = DistillNotifier(
      repository: FilePersonaRepository(directory: MemoryPersonaDirectory()),
      builderFactory: (void Function(String) onLog) {
        built = _FakeBuilder(onLog: onLog, result: fixturePersona());
        return built!;
      },
    );

    await notifier.run(
      emptyConversation(),
      runtime: MockRuntime(available: false),
    );
    expect(notifier.state.phase, DistillPhase.failed);
    expect(notifier.state.error, DistillError.noModel);
    expect(built, isNull);
  });

  test('C16 build 抛错 → failed(buildFailed)，未保存；reset 回 idle', () async {
    final DistillNotifier notifier = DistillNotifier(
      repository: FilePersonaRepository(directory: MemoryPersonaDirectory()),
      builderFactory: (void Function(String) onLog) =>
          _FakeBuilder(onLog: onLog, throwError: true),
    );

    await notifier.run(emptyConversation(), runtime: runtime);
    expect(notifier.state.phase, DistillPhase.failed);
    expect(notifier.state.error, DistillError.buildFailed);
    expect(notifier.state.persona, isNull);
    expect(notifier.state.saved, isFalse);

    notifier.reset();
    expect(notifier.state.phase, DistillPhase.idle);
  });

  test('C17 空会话 + 真实 builder + MockRuntime → done(有效、可保存)', () async {
    final MemoryPersonaDirectory dir = MemoryPersonaDirectory();
    final FilePersonaRepository repo = FilePersonaRepository(directory: dir);
    final DistillNotifier notifier = DistillNotifier(
      repository: repo,
    );

    await notifier.run(
      emptyConversation(),
      runtime: MockRuntime(response: 'ok'),
    );
    expect(notifier.state.phase, DistillPhase.done);
    final Persona? persona = notifier.state.persona;
    expect(persona, isNotNull);
    expect(persona!.identity.displayName, isNotEmpty);
    expect(persona.schemaVersion, kPersonaSchemaVersion);

    await notifier.save();
    expect(notifier.state.saved, isTrue);
    expect((await repo.list()).summaries, hasLength(1));
  });

  test('cancel mid-run → idle; the aborted build never clobbers state',
      () async {
    final DistillNotifier notifier = DistillNotifier(
      repository: FilePersonaRepository(directory: MemoryPersonaDirectory()),
      builderFactory: (void Function(String) onLog) => _SteppedBuilder(
        onLog: onLog,
        result: fixturePersona(id: 'p-cancel'),
        chunks: 100,
      ),
    );

    final Future<void> running = notifier.run(
      emptyConversation(),
      runtime: runtime,
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(notifier.state.phase, DistillPhase.running);

    notifier.cancel();
    expect(notifier.state.phase, DistillPhase.idle);

    await running;
    expect(notifier.state.phase, DistillPhase.idle);
    expect(notifier.state.persona, isNull);
  });

  test('cancel is a no-op unless running', () async {
    final DistillNotifier notifier = DistillNotifier(
      repository: FilePersonaRepository(directory: MemoryPersonaDirectory()),
      builderFactory: (void Function(String) onLog) =>
          _FakeBuilder(onLog: onLog, result: fixturePersona()),
    );

    notifier.cancel();
    expect(notifier.state.phase, DistillPhase.idle);

    await notifier.run(emptyConversation(), runtime: runtime);
    expect(notifier.state.phase, DistillPhase.done);
    notifier.cancel();
    expect(notifier.state.phase, DistillPhase.done);
  });

  test('pause parks the build at a chunk boundary; resume finishes it',
      () async {
    final List<_SteppedBuilder> builders = <_SteppedBuilder>[];
    final DistillNotifier notifier = DistillNotifier(
      repository: FilePersonaRepository(directory: MemoryPersonaDirectory()),
      builderFactory: (void Function(String) onLog) {
        final _SteppedBuilder b = _SteppedBuilder(
          onLog: onLog,
          result: fixturePersona(id: 'p-pause'),
          chunks: 8,
        );
        builders.add(b);
        return b;
      },
    );

    final Future<void> running = notifier.run(
      emptyConversation(),
      runtime: runtime,
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    notifier.pause();
    expect(notifier.state.paused, isTrue);
    expect(notifier.state.phase, DistillPhase.running);

    await Future<void>.delayed(const Duration(milliseconds: 20));
    final int parked = builders.single.completedChunks;
    expect(parked, lessThan(8));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(builders.single.completedChunks, parked);

    notifier.resume();
    expect(notifier.state.paused, isFalse);

    await running;
    expect(notifier.state.phase, DistillPhase.done);
    expect(builders.single.completedChunks, 8);
  });

  test('cancel while paused unwinds the build to idle', () async {
    final DistillNotifier notifier = DistillNotifier(
      repository: FilePersonaRepository(directory: MemoryPersonaDirectory()),
      builderFactory: (void Function(String) onLog) => _SteppedBuilder(
        onLog: onLog,
        result: fixturePersona(id: 'p-pause-cancel'),
        chunks: 100,
      ),
    );

    final Future<void> running = notifier.run(
      emptyConversation(),
      runtime: runtime,
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    notifier.pause();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    notifier.cancel();
    expect(notifier.state.phase, DistillPhase.idle);
    expect(notifier.state.paused, isFalse);

    await running;
    expect(notifier.state.phase, DistillPhase.idle);
    expect(notifier.state.persona, isNull);
  });

  test('C18 保存失败 → saveError 置位且保留 persona 供重试', () async {
    final Persona persona = fixturePersona(id: 'persona-savefail');
    final DistillNotifier notifier = DistillNotifier(
      repository: _ThrowingSaveRepo(),
      builderFactory: (void Function(String) onLog) =>
          _FakeBuilder(onLog: onLog, result: persona),
    );

    await notifier.run(emptyConversation(), runtime: runtime);
    expect(notifier.state.phase, DistillPhase.done);

    await notifier.save();
    expect(notifier.state.phase, DistillPhase.done);
    expect(notifier.state.saveError, isNotNull);
    expect(notifier.state.saved, isFalse);
    expect(notifier.state.persona, persona);
  });
}
