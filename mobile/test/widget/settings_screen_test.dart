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
  ModelFamily family = ModelFamily.gemma4,
}) {
  return ModelDescriptor(
    id: id,
    displayName: id,
    format: ModelFormat.litertlm,
    family: family,
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
    return _installed[modelId]?.state ?? ModelState.notInstalled;
  }

  @override
  Future<void> syncInstalled() async {}
}

class _ThrowingSecureKeyStore implements SecureKeyStore {
  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String key) async => throw StateError('keychain locked');

  @override
  Future<void> clear() async => throw StateError('keychain locked');
}

List<Override> _overrides(_FakeRepo repo, {SecureKeyStore? cloudKeyStore}) {
  return <Override>[
    settingsRepositoryProvider.overrideWithValue(InMemorySettingsRepository()),
    cloudKeyStoreProvider.overrideWithValue(
      cloudKeyStore ?? InMemorySecureKeyStore(),
    ),
    hfTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
    deviceCapabilitiesProvider.overrideWithValue(
      const StaticDeviceCapabilities(tier: DeviceTier.simulatorCpu),
    ),
    modelRepositoryProvider.overrideWithValue(repo),
  ];
}

Future<void> _pump(
  WidgetTester tester,
  Widget screen,
  _FakeRepo repo, {
  SecureKeyStore? cloudKeyStore,
}) async {
  tester.view.physicalSize = const Size(1000, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(repo, cloudKeyStore: cloudKeyStore),
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('C25 SettingsScreen states', () {
    testWidgets(
      'renders local/cloud runtimes, obscured key, plain endpoint field',
      (WidgetTester tester) async {
        final _FakeRepo repo = _FakeRepo(catalogList: <ModelDescriptor>[]);
        await _pump(tester, const SettingsScreen(), repo);

        expect(find.byKey(const Key('runtime-local')), findsOneWidget);
        expect(find.byKey(const Key('runtime-cloud')), findsOneWidget);
        expect(find.byKey(const Key('runtime-maxPrivacy')), findsNothing);

        final TextField cloudField = tester.widget<TextField>(
          find.byKey(const Key('cloud-key-field')),
        );
        final TextField endpointField = tester.widget<TextField>(
          find.byKey(const Key('cloud-endpoint-field')),
        );
        expect(cloudField.obscureText, isTrue);
        expect(endpointField.obscureText, isFalse);

        expect(find.byKey(const Key('hf-token-field')), findsNothing);
        expect(find.byKey(const Key('temperature-slider')), findsNothing);
        expect(find.byKey(const Key('open-model-management')), findsOneWidget);
      },
    );

    testWidgets('switching runtime persists selection', (
      WidgetTester tester,
    ) async {
      final _FakeRepo repo = _FakeRepo(catalogList: <ModelDescriptor>[]);
      await _pump(tester, const SettingsScreen(), repo);

      await tester.tap(find.byKey(const Key('runtime-cloud')));
      await tester.pumpAndSettle();

      final RadioListTile<Object> tile = tester.widget<RadioListTile<Object>>(
        find.byKey(const Key('runtime-cloud')),
      );
      expect(tile.value.toString(), contains('cloud'));
    });

    testWidgets('saving cloud endpoint persists to settings', (
      WidgetTester tester,
    ) async {
      final _FakeRepo repo = _FakeRepo(catalogList: <ModelDescriptor>[]);
      await _pump(tester, const SettingsScreen(), repo);

      await tester.enterText(
        find.byKey(const Key('cloud-endpoint-field')),
        'https://api.example.test/v1',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsScreen)),
      );
      expect(
        container.read(appSettingsProvider).cloudEndpoint,
        'https://api.example.test/v1',
      );
    });

    testWidgets('a failed cloud-key save surfaces a SnackBar', (
      WidgetTester tester,
    ) async {
      final _FakeRepo repo = _FakeRepo(catalogList: <ModelDescriptor>[]);
      await _pump(
        tester,
        const SettingsScreen(),
        repo,
        cloudKeyStore: _ThrowingSecureKeyStore(),
      );

      await tester.enterText(
        find.byKey(const Key('cloud-key-field')),
        'sk-secret',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save').first);
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not save'), findsOneWidget);
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

    testWidgets('unsupported-device failure shows Cloud AI hint, not proactively', (
      WidgetTester tester,
    ) async {
      final _FakeRepo repo = _FakeRepo(
        catalogList: <ModelDescriptor>[
          _desc('gemma-e2b', minTier: DeviceTier.highEnd),
        ],
      );
      await _pump(tester, const ModelManagementScreen(), repo);

      expect(find.byKey(const Key('unsupported-gemma-e2b')), findsNothing);

      repo.scripted['gemma-e2b'] = <InstallEvent>[
        const InstallEvent(
          modelId: 'gemma-e2b',
          state: ModelState.failed,
          error: InstallErrorKind.unsupportedDevice,
        ),
      ];
      await tester.tap(find.byKey(const Key('install-gemma-e2b')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('unsupported-gemma-e2b')), findsOneWidget);
      expect(find.text('Use Cloud AI'), findsOneWidget);
    });

    testWidgets('not-installed model shows a Download button', (
      WidgetTester tester,
    ) async {
      final _FakeRepo repo = _FakeRepo(
        catalogList: <ModelDescriptor>[_desc('gemma-e2b')],
      );
      await _pump(tester, const ModelManagementScreen(), repo);

      expect(find.byKey(const Key('install-gemma-e2b')), findsOneWidget);
      expect(find.text('Download'), findsOneWidget);
      expect(find.byKey(const Key('activate-gemma-e2b')), findsNothing);
      expect(find.byKey(const Key('deactivate-gemma-e2b')), findsNothing);
    });

    testWidgets('installed non-active shows Activate + Delete, no Deactivate', (
      WidgetTester tester,
    ) async {
      final _FakeRepo repo = _FakeRepo(
        catalogList: <ModelDescriptor>[_desc('gemma-e2b')],
      )..seedReady('gemma-e2b');
      await _pump(tester, const ModelManagementScreen(), repo);

      expect(find.byKey(const Key('activate-gemma-e2b')), findsOneWidget);
      expect(find.byKey(const Key('delete-gemma-e2b')), findsOneWidget);
      expect(find.byKey(const Key('deactivate-gemma-e2b')), findsNothing);
      expect(find.byKey(const Key('install-gemma-e2b')), findsNothing);
    });

    testWidgets('active model shows Deactivate + Delete; deactivate clears it', (
      WidgetTester tester,
    ) async {
      final _FakeRepo repo = _FakeRepo(
        catalogList: <ModelDescriptor>[_desc('gemma-e2b')],
      )..seedReady('gemma-e2b');
      await _pump(tester, const ModelManagementScreen(), repo);

      await tester.tap(find.byKey(const Key('activate-gemma-e2b')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('deactivate-gemma-e2b')), findsOneWidget);
      expect(find.byKey(const Key('delete-gemma-e2b')), findsOneWidget);
      expect(find.byKey(const Key('activate-gemma-e2b')), findsNothing);
      expect(find.byKey(const Key('active-chip')), findsOneWidget);

      await tester.tap(find.byKey(const Key('deactivate-gemma-e2b')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('activate-gemma-e2b')), findsOneWidget);
      expect(find.byKey(const Key('deactivate-gemma-e2b')), findsNothing);
      expect(find.byKey(const Key('active-chip')), findsNothing);
    });

    testWidgets('activating one model replaces the previously active one', (
      WidgetTester tester,
    ) async {
      final _FakeRepo repo = _FakeRepo(
        catalogList: <ModelDescriptor>[_desc('gemma-e2b'), _desc('gemma-1b')],
      )
        ..seedReady('gemma-e2b')
        ..seedReady('gemma-1b');
      await _pump(tester, const ModelManagementScreen(), repo);

      await tester.tap(find.byKey(const Key('activate-gemma-e2b')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('deactivate-gemma-e2b')), findsOneWidget);
      expect(find.byKey(const Key('activate-gemma-1b')), findsOneWidget);

      await tester.tap(find.byKey(const Key('activate-gemma-1b')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('deactivate-gemma-1b')), findsOneWidget);
      expect(find.byKey(const Key('activate-gemma-e2b')), findsOneWidget);
      expect(find.byKey(const Key('deactivate-gemma-e2b')), findsNothing);
    });

    testWidgets('deleting a just-installed active model resets to Download', (
      WidgetTester tester,
    ) async {
      final _FakeRepo repo = _FakeRepo(
        catalogList: <ModelDescriptor>[_desc('gemma-e2b')],
      );
      repo.scripted['gemma-e2b'] = <InstallEvent>[
        const InstallEvent(
          modelId: 'gemma-e2b',
          state: ModelState.ready,
          receivedBytes: 100,
          totalBytes: 100,
        ),
      ];
      await _pump(tester, const ModelManagementScreen(), repo);

      await tester.tap(find.byKey(const Key('install-gemma-e2b')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('activate-gemma-e2b')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('deactivate-gemma-e2b')), findsOneWidget);

      await tester.tap(find.byKey(const Key('delete-gemma-e2b')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('install-gemma-e2b')), findsOneWidget);
      expect(find.byKey(const Key('deactivate-gemma-e2b')), findsNothing);
      expect(find.byKey(const Key('delete-gemma-e2b')), findsNothing);
      expect(find.byKey(const Key('active-chip')), findsNothing);
    });

    testWidgets('installed model outside the visible catalog stays deletable', (
      WidgetTester tester,
    ) async {
      final _FakeRepo repo = _FakeRepo(
        catalogList: <ModelDescriptor>[
          _desc('legacy-general', family: ModelFamily.general),
        ],
      )..seedReady('legacy-general');
      await _pump(tester, const ModelManagementScreen(), repo);

      expect(
        find.byKey(const Key('model-tile-legacy-general')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('delete-legacy-general')), findsOneWidget);
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
