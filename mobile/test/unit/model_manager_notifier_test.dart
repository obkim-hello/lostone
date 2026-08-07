import 'package:flutter_test/flutter_test.dart';
import 'package:lostone/models/model_descriptor.dart';
import 'package:lostone/models/model_install.dart';
import 'package:lostone/models/model_manager_state.dart';
import 'package:lostone/services/model/device_capabilities.dart';
import 'package:lostone/services/model/model_repository.dart';
import 'package:lostone/services/settings/model_manager_notifier.dart';

ModelDescriptor _desc(
  String id, {
  DeviceTier minTier = DeviceTier.simulatorCpu,
  int size = 100,
}) {
  return ModelDescriptor(
    id: id,
    displayName: id,
    format: ModelFormat.litertlm,
    family: ModelFamily.general,
    sizeBytes: size,
    capabilities: const <ModelCapability>{ModelCapability.text},
    minTier: minTier,
    sourceUrl: 'https://example.test/$id',
  );
}

InstallEvent _ev(
  String id,
  ModelState state, {
  int received = 0,
  int total = 0,
  InstallErrorKind? error,
}) {
  return InstallEvent(
    modelId: id,
    state: state,
    receivedBytes: received,
    totalBytes: total,
    error: error,
  );
}

class _FakeModelRepository implements ModelRepository {
  _FakeModelRepository({List<ModelDescriptor>? catalog})
    : _catalog = catalog ?? <ModelDescriptor>[_desc('smol-135m')];

  final List<ModelDescriptor> _catalog;
  final Map<String, List<InstallEvent>> scripted =
      <String, List<InstallEvent>>{};
  final Map<String, InstalledModel> _installed = <String, InstalledModel>{};
  final Set<String> _ready = <String>{};
  String? _active;

  DeviceTier? lastRecommendFor;
  final List<String> cancelCalls = <String>[];
  final List<String> deleteCalls = <String>[];
  bool setActiveShouldThrow = false;

  void seedReady(String id) {
    _ready.add(id);
    _installed[id] = InstalledModel(
      descriptor: _desc(id),
      filePath: '/tmp/$id',
      installedBytes: 100,
      state: ModelState.ready,
      installedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  @override
  List<ModelDescriptor> catalog({DeviceTier? recommendFor}) {
    lastRecommendFor = recommendFor;
    return List<ModelDescriptor>.of(_catalog);
  }

  @override
  Stream<InstallEvent> install(
    String modelId, {
    String? hfToken,
    bool allowOverTier = false,
  }) async* {
    for (final InstallEvent event in scripted[modelId] ?? <InstallEvent>[]) {
      if (event.state == ModelState.ready) {
        seedReady(modelId);
      }
      yield event;
    }
  }

  @override
  Future<void> cancel(String modelId) async => cancelCalls.add(modelId);

  @override
  Future<void> delete(String modelId) async {
    deleteCalls.add(modelId);
    _installed.remove(modelId);
    _ready.remove(modelId);
    if (_active == modelId) {
      _active = null;
    }
  }

  @override
  Future<void> setActive(String modelId) async {
    if (setActiveShouldThrow || !_ready.contains(modelId)) {
      throw StateError('model not ready: $modelId');
    }
    _active = modelId;
  }

  @override
  Future<void> deactivate() async {
    _active = null;
  }

  @override
  Future<ModelHandle?> getActiveModelHandle() async {
    final String? id = _active;
    if (id == null) {
      return null;
    }
    return ModelHandle(
      id: id,
      format: ModelFormat.litertlm,
      capabilities: const <ModelCapability>{ModelCapability.text},
      backend: InferenceBackend.cpu,
      engine: EngineKind.liteRtLm,
    );
  }

  @override
  List<InstalledModel> installed() =>
      List<InstalledModel>.of(_installed.values);

  @override
  ModelState stateOf(String modelId) {
    if (_ready.contains(modelId)) {
      return ModelState.ready;
    }
    if (_installed.containsKey(modelId)) {
      return _installed[modelId]!.state;
    }
    return ModelState.notInstalled;
  }

  @override
  Future<void> syncInstalled() async {}
}

ModelManagerNotifier _build(
  _FakeModelRepository repo, {
  DeviceTier tier = DeviceTier.simulatorCpu,
  void Function(String? id)? onActiveChanged,
}) {
  return ModelManagerNotifier(
    repository: repo,
    device: StaticDeviceCapabilities(tier: tier),
    onActiveChanged: onActiveChanged,
  );
}

void main() {
  group('C8 install progress fold', () {
    test('downloading 25/50/100 → ready, no verifying', () async {
      final _FakeModelRepository repo = _FakeModelRepository();
      repo.scripted['smol-135m'] = <InstallEvent>[
        _ev('smol-135m', ModelState.downloading, received: 25, total: 100),
        _ev('smol-135m', ModelState.downloading, received: 50, total: 100),
        _ev('smol-135m', ModelState.downloading, received: 100, total: 100),
        _ev('smol-135m', ModelState.ready, received: 100, total: 100),
      ];
      final ModelManagerNotifier notifier = _build(repo);

      await notifier.install('smol-135m');

      final InstallProgress progress = notifier.state.progress['smol-135m']!;
      expect(progress.state, ModelState.ready);
      expect(progress.fraction, 1.0);
      expect(notifier.state.lastError, isNull);
      expect(
        notifier.state.installed.map((InstalledModel m) => m.descriptor.id),
        contains('smol-135m'),
      );
    });

    test('tolerates an optional verifying frame', () async {
      final _FakeModelRepository repo = _FakeModelRepository();
      repo.scripted['smol-135m'] = <InstallEvent>[
        _ev('smol-135m', ModelState.downloading, received: 50, total: 100),
        _ev('smol-135m', ModelState.verifying, received: 100, total: 100),
        _ev('smol-135m', ModelState.ready, received: 100, total: 100),
      ];
      final ModelManagerNotifier notifier = _build(repo);

      await notifier.install('smol-135m');

      expect(notifier.state.progress['smol-135m']!.state, ModelState.ready);
      expect(notifier.state.lastError, isNull);
    });
  });

  group('typed install failures surface distinctly (C9–C14)', () {
    Future<InstallFailure?> run(InstallErrorKind kind) async {
      final _FakeModelRepository repo = _FakeModelRepository();
      repo.scripted['smol-135m'] = <InstallEvent>[
        _ev('smol-135m', ModelState.downloading, received: 10, total: 100),
        _ev('smol-135m', ModelState.failed, error: kind),
      ];
      final ModelManagerNotifier notifier = _build(repo);
      await notifier.install('smol-135m');
      return notifier.state.lastError;
    }

    test('C9 authRequired', () async {
      expect(
        (await run(InstallErrorKind.authRequired))!.kind,
        InstallErrorKind.authRequired,
      );
    });

    test('C10 insufficientStorage', () async {
      expect(
        (await run(InstallErrorKind.insufficientStorage))!.kind,
        InstallErrorKind.insufficientStorage,
      );
    });

    test('C11 unsupportedDevice (no confirm)', () async {
      final InstallFailure? failure = await run(
        InstallErrorKind.unsupportedDevice,
      );
      expect(failure!.kind, InstallErrorKind.unsupportedDevice);
    });

    test('C13 network', () async {
      expect(
        (await run(InstallErrorKind.network))!.kind,
        InstallErrorKind.network,
      );
    });

    test('C14 corrupted (defensive)', () async {
      expect(
        (await run(InstallErrorKind.corrupted))!.kind,
        InstallErrorKind.corrupted,
      );
    });

    test('failed install does not clear lastError via refresh', () async {
      final _FakeModelRepository repo = _FakeModelRepository();
      repo.scripted['smol-135m'] = <InstallEvent>[
        _ev('smol-135m', ModelState.failed, error: InstallErrorKind.network),
      ];
      final ModelManagerNotifier notifier = _build(repo);

      await notifier.install('smol-135m');

      expect(notifier.state.lastError, isNotNull);
      expect(notifier.state.progress['smol-135m']!.state, ModelState.failed);
    });
  });

  group('C12 install over-tier confirmed proceeds to ready', () {
    test('allowOverTier:true reaches ready', () async {
      final _FakeModelRepository repo = _FakeModelRepository();
      repo.scripted['gemma-e2b'] = <InstallEvent>[
        _ev('gemma-e2b', ModelState.downloading, received: 50, total: 100),
        _ev('gemma-e2b', ModelState.ready, received: 100, total: 100),
      ];
      final ModelManagerNotifier notifier = _build(repo);

      await notifier.install('gemma-e2b', allowOverTier: true);

      expect(notifier.state.progress['gemma-e2b']!.state, ModelState.ready);
      expect(notifier.state.lastError, isNull);
    });
  });

  group('C15 cancel mid-install clears progress', () {
    test('cancel removes the progress entry and calls repository', () async {
      final _FakeModelRepository repo = _FakeModelRepository();
      repo.scripted['smol-135m'] = <InstallEvent>[
        _ev('smol-135m', ModelState.downloading, received: 25, total: 100),
        _ev('smol-135m', ModelState.downloading, received: 50, total: 100),
      ];
      final ModelManagerNotifier notifier = _build(repo);
      await notifier.install('smol-135m');
      expect(notifier.state.progress.containsKey('smol-135m'), isTrue);

      await notifier.cancel('smol-135m');

      expect(repo.cancelCalls, contains('smol-135m'));
      expect(notifier.state.progress.containsKey('smol-135m'), isFalse);
    });
  });

  group('C16 activate ready model', () {
    test('sets active, mirrors id, fires onActiveChanged', () async {
      final _FakeModelRepository repo = _FakeModelRepository()
        ..seedReady('smol-135m');
      String? mirrored;
      final ModelManagerNotifier notifier = _build(
        repo,
        onActiveChanged: (String? id) => mirrored = id,
      );

      await notifier.activate('smol-135m');

      expect(notifier.state.activeModelId, 'smol-135m');
      expect(mirrored, 'smol-135m');
      expect(notifier.state.lastError, isNull);
    });
  });

  group('deactivate clears active model', () {
    test('clears active, mirrors null, fires onActiveChanged(null)', () async {
      final _FakeModelRepository repo = _FakeModelRepository()
        ..seedReady('smol-135m');
      final List<String?> changes = <String?>[];
      final ModelManagerNotifier notifier = _build(
        repo,
        onActiveChanged: changes.add,
      );
      await notifier.activate('smol-135m');
      expect(notifier.state.activeModelId, 'smol-135m');

      await notifier.deactivate();

      expect(notifier.state.activeModelId, isNull);
      expect(changes.last, isNull);
    });
  });

  group('C17 activate non-ready model', () {
    test('StateError caught → lastError, active unchanged', () async {
      final _FakeModelRepository repo = _FakeModelRepository();
      String? mirrored = 'sentinel';
      final ModelManagerNotifier notifier = _build(
        repo,
        onActiveChanged: (String? id) => mirrored = id,
      );

      await notifier.activate('smol-135m');

      expect(notifier.state.activeModelId, isNull);
      expect(notifier.state.lastError, isNotNull);
      expect(notifier.state.lastError!.modelId, 'smol-135m');
      expect(mirrored, 'sentinel');
    });
  });

  group('C18 delete active model', () {
    test('clears active and notifies onActiveChanged(null)', () async {
      final _FakeModelRepository repo = _FakeModelRepository()
        ..seedReady('smol-135m');
      final List<String?> changes = <String?>[];
      final ModelManagerNotifier notifier = _build(
        repo,
        onActiveChanged: changes.add,
      );
      await notifier.activate('smol-135m');
      expect(notifier.state.activeModelId, 'smol-135m');

      await notifier.delete('smol-135m');

      expect(notifier.state.activeModelId, isNull);
      expect(repo.deleteCalls, contains('smol-135m'));
      expect(changes.last, isNull);
    });
  });

  group('C19 delete non-active is idempotent', () {
    test('active unchanged; deleting absent id is a no-op', () async {
      final _FakeModelRepository repo = _FakeModelRepository()
        ..seedReady('smol-135m')
        ..seedReady('other');
      final List<String?> changes = <String?>[];
      final ModelManagerNotifier notifier = _build(
        repo,
        onActiveChanged: changes.add,
      );
      await notifier.activate('smol-135m');
      changes.clear();

      await notifier.delete('other');
      expect(notifier.state.activeModelId, 'smol-135m');
      expect(changes, isEmpty);

      await notifier.delete('absent-id');
      expect(notifier.state.activeModelId, 'smol-135m');
      expect(changes, isEmpty);
    });
  });

  group('C22 recommendation ordering', () {
    test('refresh passes device tier to catalog and stores result', () async {
      final _FakeModelRepository repo = _FakeModelRepository(
        catalog: <ModelDescriptor>[
          _desc('smol-135m'),
          _desc('gemma-1b', minTier: DeviceTier.midEnd),
          _desc('gemma-e2b', minTier: DeviceTier.highEnd),
        ],
      );
      final ModelManagerNotifier notifier = _build(
        repo,
        tier: DeviceTier.simulatorCpu,
      );

      await notifier.refresh();

      expect(repo.lastRecommendFor, DeviceTier.simulatorCpu);
      expect(notifier.state.catalog.first.id, 'smol-135m');
      expect(notifier.state.catalog.length, 3);
    });
  });
}
