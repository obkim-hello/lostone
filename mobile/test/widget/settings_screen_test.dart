import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lostone/models/model_descriptor.dart';
import 'package:lostone/models/model_install.dart';
import 'package:lostone/providers/settings_providers.dart';
import 'package:lostone/screens/settings/model_management_screen.dart';
import 'package:lostone/screens/settings/settings_screen.dart';
import 'package:lostone/services/model/device_capabilities.dart';
import 'package:lostone/services/model/model_repository.dart';
import 'package:lostone/services/model/token_store.dart';
import 'package:lostone/services/settings/secure_key_store.dart';
import 'package:lostone/services/settings/settings_repository.dart';

ModelDescriptor _desc(
  String id, {
  DeviceTier minTier = DeviceTier.simulatorCpu,
}) {
  return ModelDescriptor(
    id: id,
    displayName: id,
    format: ModelFormat.litertlm,
    family: ModelFamily.general,
    sizeBytes: 100 * 1024 * 1024,
    capabilities: const <ModelCapability>{ModelCapability.text},
    minTier: minTier,
    sourceUrl: 'https://example.test/$id',
  );
}

class _FakeRepo implements ModelRepository {
  _FakeRepo({required this.catalogList});

  final List<ModelDescriptor> catalogList;
  final Map<String, List<InstallEvent>> scripted =
      <String, List<InstallEvent>>{};
  final Map<String, InstalledModel> _installed = <String, InstalledModel>{};
  final Set<String> _ready = <String>{};
  String? _active;

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
  List<ModelDescriptor> catalog({DeviceTier? recommendFor}) =>
      List<ModelDescriptor>.of(catalogList);

  @override
  Stream<InstallEvent> install(
    String modelId, {
    String? hfToken,
    bool allowOverTier = false,
  }) async* {
    for (final InstallEvent e in scripted[modelId] ?? <InstallEvent>[]) {
      if (e.state == ModelState.ready) {
        seedReady(modelId);
      }
      yield e;
    }
  }

  @override
  Future<void> cancel(String modelId) async {}

  @override
  Future<void> delete(String modelId) async {
    _installed.remove(modelId);
    _ready.remove(modelId);
    if (_active == modelId) {
      _active = null;
    }
  }

  @override
  Future<void> setActive(String modelId) async {
    if (!_ready.contains(modelId)) {
      throw StateError('not ready');
    }
    _active = modelId;
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
    return _installed[modelId]?.state ?? ModelState.notInstalled;
  }
}

List<Override> _overrides(_FakeRepo repo) {
  return <Override>[
    settingsRepositoryProvider.overrideWithValue(InMemorySettingsRepository()),
    cloudKeyStoreProvider.overrideWithValue(InMemorySecureKeyStore()),
    hfTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
    deviceCapabilitiesProvider.overrideWithValue(
      const StaticDeviceCapabilities(tier: DeviceTier.simulatorCpu),
    ),
    modelRepositoryProvider.overrideWithValue(repo),
  ];
}

Future<void> _pump(WidgetTester tester, Widget screen, _FakeRepo repo) async {
  tester.view.physicalSize = const Size(1000, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(repo),
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('C25 SettingsScreen states', () {
    testWidgets('renders runtime choices, obscured secret fields, slider', (
      WidgetTester tester,
    ) async {
      final _FakeRepo repo = _FakeRepo(catalogList: <ModelDescriptor>[]);
      await _pump(tester, const SettingsScreen(), repo);

      expect(find.byKey(const Key('runtime-local')), findsOneWidget);
      expect(find.byKey(const Key('runtime-cloud')), findsOneWidget);
      expect(find.byKey(const Key('runtime-maxPrivacy')), findsOneWidget);

      final TextField cloudField = tester.widget<TextField>(
        find.byKey(const Key('cloud-key-field')),
      );
      final TextField hfField = tester.widget<TextField>(
        find.byKey(const Key('hf-token-field')),
      );
      expect(cloudField.obscureText, isTrue);
      expect(hfField.obscureText, isTrue);

      expect(find.byKey(const Key('temperature-slider')), findsOneWidget);
      expect(find.byKey(const Key('open-model-management')), findsOneWidget);
    });

    testWidgets('switching runtime persists selection', (
      WidgetTester tester,
    ) async {
      final _FakeRepo repo = _FakeRepo(catalogList: <ModelDescriptor>[]);
      await _pump(tester, const SettingsScreen(), repo);

      await tester.tap(find.byKey(const Key('runtime-maxPrivacy')));
      await tester.pumpAndSettle();

      final RadioListTile<Object> tile = tester.widget<RadioListTile<Object>>(
        find.byKey(const Key('runtime-maxPrivacy')),
      );
      expect(tile.value.toString(), contains('maxPrivacy'));
    });
  });

  group('C25 ModelManagementScreen states', () {
    testWidgets('catalog renders recommended-first', (
      WidgetTester tester,
    ) async {
      final _FakeRepo repo = _FakeRepo(
        catalogList: <ModelDescriptor>[
          _desc('smol-135m'),
          _desc('gemma-1b', minTier: DeviceTier.midEnd),
          _desc('gemma-e2b', minTier: DeviceTier.highEnd),
        ],
      );
      await _pump(tester, const ModelManagementScreen(), repo);

      expect(find.byKey(const Key('model-tile-smol-135m')), findsOneWidget);
      expect(find.byKey(const Key('model-tile-gemma-1b')), findsOneWidget);
      expect(find.byKey(const Key('model-tile-gemma-e2b')), findsOneWidget);

      final Offset first = tester.getTopLeft(
        find.byKey(const Key('model-tile-smol-135m')),
      );
      final Offset second = tester.getTopLeft(
        find.byKey(const Key('model-tile-gemma-e2b')),
      );
      expect(first.dy, lessThan(second.dy));
    });

    testWidgets('typed error row shows after a failed install', (
      WidgetTester tester,
    ) async {
      final _FakeRepo repo = _FakeRepo(
        catalogList: <ModelDescriptor>[_desc('smol-135m')],
      );
      repo.scripted['smol-135m'] = <InstallEvent>[
        const InstallEvent(
          modelId: 'smol-135m',
          state: ModelState.failed,
          error: InstallErrorKind.network,
        ),
      ];
      await _pump(tester, const ModelManagementScreen(), repo);

      await tester.tap(find.byKey(const Key('install-smol-135m')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('error-smol-135m')), findsOneWidget);
      expect(find.text('Download failed (network)'), findsOneWidget);
    });

    testWidgets('progress bar shows while downloading', (
      WidgetTester tester,
    ) async {
      final _FakeRepo repo = _FakeRepo(
        catalogList: <ModelDescriptor>[_desc('smol-135m')],
      );
      repo.scripted['smol-135m'] = <InstallEvent>[
        const InstallEvent(
          modelId: 'smol-135m',
          state: ModelState.downloading,
          receivedBytes: 50,
          totalBytes: 100,
        ),
      ];
      await _pump(tester, const ModelManagementScreen(), repo);

      await tester.tap(find.byKey(const Key('install-smol-135m')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('progress-smol-135m')), findsOneWidget);
      expect(find.byKey(const Key('cancel-smol-135m')), findsOneWidget);
    });

    testWidgets('confirm-delete dialog appears for a ready model', (
      WidgetTester tester,
    ) async {
      final _FakeRepo repo = _FakeRepo(
        catalogList: <ModelDescriptor>[_desc('smol-135m')],
      )..seedReady('smol-135m');
      await _pump(tester, const ModelManagementScreen(), repo);

      await tester.tap(find.byKey(const Key('delete-smol-135m')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('delete-dialog')), findsOneWidget);
    });
  });

  group('installErrorLabel maps every kind distinctly', () {
    test('all InstallErrorKind values map to non-empty distinct labels', () {
      final Set<String> labels = <String>{};
      for (final InstallErrorKind kind in InstallErrorKind.values) {
        final String label = installErrorLabel(kind);
        expect(label, isNotEmpty);
        labels.add(label);
      }
      expect(labels.length, InstallErrorKind.values.length);
    });
  });
}
