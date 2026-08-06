import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lostone/models/model_descriptor.dart';
import 'package:lostone/models/model_install.dart';
import 'package:lostone/services/model/device_capabilities.dart';
import 'package:lostone/services/model/model_catalog.dart';
import 'package:lostone/services/model/model_installer.dart';
import 'package:lostone/services/model/model_repository.dart';
import 'package:lostone/services/model/model_store.dart';
import 'package:lostone/services/model/token_store.dart';

/// 脚本化的安装器测试替身：按尝试次数产出事件序列，可注入失败/续传/挂起。
class MockInstaller implements ModelInstaller {
  MockInstaller(this._plan);

  final List<InstallEvent> Function(ModelDescriptor descriptor, int attempt)
      _plan;
  final Map<String, int> _attempts = <String, int>{};
  final Map<String, StreamController<InstallEvent>> _controllers =
      <String, StreamController<InstallEvent>>{};

  int installCallCount = 0;

  @override
  Stream<InstallEvent> install(ModelDescriptor descriptor, {String? hfToken}) {
    installCallCount++;
    final int attempt = (_attempts[descriptor.id] ?? 0) + 1;
    _attempts[descriptor.id] = attempt;
    final List<InstallEvent> events = _plan(descriptor, attempt);
    final StreamController<InstallEvent> controller =
        StreamController<InstallEvent>();
    _controllers[descriptor.id] = controller;
    controller.onListen = () async {
      for (final InstallEvent event in events) {
        if (controller.isClosed) {
          return;
        }
        await Future<void>.delayed(Duration.zero);
        if (controller.isClosed) {
          return;
        }
        controller.add(event);
      }
      final bool terminal = events.isNotEmpty &&
          (events.last.state == ModelState.ready ||
              events.last.state == ModelState.failed);
      if (terminal && !controller.isClosed) {
        await controller.close();
      }
    };
    return controller.stream;
  }

  @override
  Future<void> cancel(String modelId) async {
    final StreamController<InstallEvent>? controller = _controllers[modelId];
    if (controller != null && !controller.isClosed) {
      await controller.close();
    }
  }
}

InstallEvent _downloading(String id, int received, int total) => InstallEvent(
      modelId: id,
      state: ModelState.downloading,
      receivedBytes: received,
      totalBytes: total,
    );

InstallEvent _verifying(String id, int total) => InstallEvent(
      modelId: id,
      state: ModelState.verifying,
      receivedBytes: total,
      totalBytes: total,
    );

InstallEvent _ready(String id, int total) => InstallEvent(
      modelId: id,
      state: ModelState.ready,
      receivedBytes: total,
      totalBytes: total,
    );

InstallEvent _failed(String id, InstallErrorKind kind) => InstallEvent(
      modelId: id,
      state: ModelState.failed,
      error: kind,
    );

List<InstallEvent> _happy(ModelDescriptor d) {
  final int total = d.sizeBytes;
  return <InstallEvent>[
    _downloading(d.id, total ~/ 2, total),
    _downloading(d.id, total, total),
    _verifying(d.id, total),
    _ready(d.id, total),
  ];
}

DefaultModelRepository _repo({
  MockInstaller? installer,
  ModelStore? store,
  DeviceTier tier = DeviceTier.highEnd,
  TokenStore? tokenStore,
}) {
  return DefaultModelRepository(
    catalog: const ModelCatalog(),
    installer: installer ?? MockInstaller((ModelDescriptor d, int a) => _happy(d)),
    store: store ?? InMemoryModelStore(),
    device: StaticDeviceCapabilities(tier: tier),
    tokenStore: tokenStore ?? InMemoryTokenStore(),
  );
}

void main() {
  const ModelDescriptor smol = ModelCatalog.smolLm135m;
  const ModelDescriptor gemma3 = ModelCatalog.gemma3_1b;
  const ModelDescriptor gemma4 = ModelCatalog.gemma4E2b;

  group('T1 目录', () {
    test('目录非空且含三档默认模型', () {
      final DefaultModelRepository repo = _repo();
      final List<ModelDescriptor> list = repo.catalog();
      final Set<String> ids = list.map((ModelDescriptor d) => d.id).toSet();
      expect(ids, containsAll(<String>[smol.id, gemma3.id, gemma4.id]));
    });
  });

  group('T2 推荐排序', () {
    test('highEnd 优先 E2B', () {
      final DefaultModelRepository repo = _repo();
      final List<ModelDescriptor> list =
          repo.catalog(recommendFor: DeviceTier.highEnd);
      expect(list.first.id, gemma4.id);
    });

    test('simulatorCpu 仅 SmolLM 可运行（排首位）', () {
      final DefaultModelRepository repo = _repo();
      final List<ModelDescriptor> list =
          repo.catalog(recommendFor: DeviceTier.simulatorCpu);
      expect(list.first.id, smol.id);
      final Iterable<ModelDescriptor> runnable = list.where(
        (ModelDescriptor d) => tierCanRun(DeviceTier.simulatorCpu, d),
      );
      expect(runnable.map((ModelDescriptor d) => d.id), <String>[smol.id]);
    });
  });

  group('T3 下载状态机（happy path）', () {
    test('事件序列 downloading*→verifying→ready，末态 ready', () async {
      final DefaultModelRepository repo = _repo();
      final List<InstallEvent> events = await repo.install(smol.id).toList();
      final List<ModelState> states =
          events.map((InstallEvent e) => e.state).toList();
      expect(states.first, ModelState.downloading);
      expect(states, contains(ModelState.verifying));
      expect(states.last, ModelState.ready);
      expect(repo.stateOf(smol.id), ModelState.ready);
    });
  });

  group('T4 进度单调递增', () {
    test('receivedBytes 非递减且末值==totalBytes', () async {
      final DefaultModelRepository repo = _repo();
      final List<InstallEvent> events = await repo.install(smol.id).toList();
      final List<InstallEvent> progress = events
          .where((InstallEvent e) => e.state == ModelState.downloading)
          .toList();
      for (int i = 1; i < progress.length; i++) {
        expect(
          progress[i].receivedBytes >= progress[i - 1].receivedBytes,
          isTrue,
        );
      }
      expect(progress.last.receivedBytes, progress.last.totalBytes);
    });
  });

  group('T5 取消清理', () {
    test('cancel 后末态 notInstalled，无残留文件', () async {
      final MockInstaller installer = MockInstaller(
        (ModelDescriptor d, int a) => <InstallEvent>[
          _downloading(d.id, d.sizeBytes ~/ 3, d.sizeBytes),
        ],
      );
      final InMemoryModelStore store = InMemoryModelStore();
      final DefaultModelRepository repo =
          _repo(installer: installer, store: store);

      final Completer<void> sawDownloading = Completer<void>();
      final List<InstallEvent> events = <InstallEvent>[];
      final StreamSubscription<InstallEvent> sub =
          repo.install(smol.id).listen((InstallEvent e) {
        events.add(e);
        if (e.state == ModelState.downloading && !sawDownloading.isCompleted) {
          sawDownloading.complete();
        }
      });
      await sawDownloading.future;
      await repo.cancel(smol.id);
      await sub.cancel();

      expect(repo.stateOf(smol.id), ModelState.notInstalled);
      expect(await store.exists(smol.id), isFalse);
      expect(events.last.state, ModelState.notInstalled);
    });
  });

  group('T6 下载失败清理', () {
    test('注入网络错误 → failed，无半成品', () async {
      final MockInstaller installer = MockInstaller(
        (ModelDescriptor d, int a) => <InstallEvent>[
          _downloading(d.id, d.sizeBytes ~/ 3, d.sizeBytes),
          _failed(d.id, InstallErrorKind.network),
        ],
      );
      final InMemoryModelStore store = InMemoryModelStore();
      final DefaultModelRepository repo =
          _repo(installer: installer, store: store);

      final List<InstallEvent> events = await repo.install(smol.id).toList();
      expect(events.last.state, ModelState.failed);
      expect(events.last.error, InstallErrorKind.network);
      expect(repo.stateOf(smol.id), ModelState.failed);
      expect(await store.exists(smol.id), isFalse);
    });
  });

  group('T7 断点续传', () {
    test('中断后再 install 从断点继续，最终 ready', () async {
      final MockInstaller installer = MockInstaller(
        (ModelDescriptor d, int attempt) => attempt == 1
            ? <InstallEvent>[
                _downloading(d.id, d.sizeBytes ~/ 3, d.sizeBytes),
                _failed(d.id, InstallErrorKind.network),
              ]
            : <InstallEvent>[
                _downloading(d.id, d.sizeBytes ~/ 3 * 2, d.sizeBytes),
                _downloading(d.id, d.sizeBytes, d.sizeBytes),
                _verifying(d.id, d.sizeBytes),
                _ready(d.id, d.sizeBytes),
              ],
      );
      final DefaultModelRepository repo = _repo(installer: installer);

      final List<InstallEvent> first = await repo.install(smol.id).toList();
      expect(first.last.state, ModelState.failed);

      final List<InstallEvent> second = await repo.install(smol.id).toList();
      expect(second.last.state, ModelState.ready);
      expect(repo.stateOf(smol.id), ModelState.ready);
      expect(installer.installCallCount, 2);
    });
  });

  group('T8 校验失败', () {
    test('sha256/大小不符 → failed(corrupted)，文件删除', () async {
      final MockInstaller installer = MockInstaller(
        (ModelDescriptor d, int a) => <InstallEvent>[
          _downloading(d.id, d.sizeBytes, d.sizeBytes),
          _verifying(d.id, d.sizeBytes),
          _failed(d.id, InstallErrorKind.corrupted),
        ],
      );
      final InMemoryModelStore store = InMemoryModelStore();
      final DefaultModelRepository repo =
          _repo(installer: installer, store: store);

      final List<InstallEvent> events = await repo.install(smol.id).toList();
      expect(events.last.state, ModelState.failed);
      expect(events.last.error, InstallErrorKind.corrupted);
      expect(await store.exists(smol.id), isFalse);
    });
  });

  group('T9 空间不足预检', () {
    test('failed(insufficientStorage)，不触发下载', () async {
      final MockInstaller installer =
          MockInstaller((ModelDescriptor d, int a) => _happy(d));
      final InMemoryModelStore store =
          InMemoryModelStore(freeBytesBudget: 1024);
      final DefaultModelRepository repo =
          _repo(installer: installer, store: store);

      final List<InstallEvent> events = await repo.install(smol.id).toList();
      expect(events.last.state, ModelState.failed);
      expect(events.last.error, InstallErrorKind.insufficientStorage);
      expect(installer.installCallCount, 0);
    });
  });

  group('T10 受限模型缺 token', () {
    test('failed(authRequired)，不触发下载', () async {
      final MockInstaller installer =
          MockInstaller((ModelDescriptor d, int a) => _happy(d));
      final DefaultModelRepository repo = _repo(installer: installer);

      final List<InstallEvent> events = await repo.install(gemma3.id).toList();
      expect(events.last.state, ModelState.failed);
      expect(events.last.error, InstallErrorKind.authRequired);
      expect(installer.installCallCount, 0);
    });

    test('提供 hfToken 后可下载', () async {
      final DefaultModelRepository repo = _repo();
      final List<InstallEvent> events =
          await repo.install(gemma3.id, hfToken: 'hf_x').toList();
      expect(events.last.state, ModelState.ready);
    });
  });

  group('E1 未知模型', () {
    test('install 未知 id 抛 ArgumentError', () {
      final DefaultModelRepository repo = _repo();
      expect(() => repo.install('no-such-model'), throwsArgumentError);
    });
  });

  group('T11 setActive 仅 ready', () {
    test('非 ready → StateError；ready → 成功', () async {
      final DefaultModelRepository repo = _repo();
      expect(() => repo.setActive(smol.id), throwsStateError);
      await repo.install(smol.id).toList();
      await repo.setActive(smol.id);
      expect(repo.stateOf(smol.id), ModelState.ready);
    });
  });

  group('T12 getActiveModelHandle 契约', () {
    test('无激活 → null；激活后字段完整', () async {
      final DefaultModelRepository repo = _repo();
      expect(await repo.getActiveModelHandle(), isNull);

      await repo.install(smol.id).toList();
      await repo.setActive(smol.id);
      final ModelHandle? handle = await repo.getActiveModelHandle();
      expect(handle, isNotNull);
      expect(handle!.id, smol.id);
      expect(handle.filePath, isNotNull);
      expect(handle.filePath!.isNotEmpty, isTrue);
      expect(handle.format, ModelFormat.litertlm);
      expect(handle.engine, EngineKind.liteRtLm);
      expect(handle.backend, InferenceBackend.gpuMetal);
    });
  });

  group('T13 删除激活模型', () {
    test('删除后 getActiveModelHandle==null', () async {
      final DefaultModelRepository repo = _repo();
      await repo.install(smol.id).toList();
      await repo.setActive(smol.id);
      expect(await repo.getActiveModelHandle(), isNotNull);

      await repo.delete(smol.id);
      expect(await repo.getActiveModelHandle(), isNull);
      expect(repo.stateOf(smol.id), ModelState.notInstalled);
      expect(repo.installed(), isEmpty);
    });
  });

  group('T14 引擎/后端选择', () {
    test('litertlm→liteRtLm；模拟器→cpu，真机→gpuMetal', () {
      const StaticDeviceCapabilities sim =
          StaticDeviceCapabilities(tier: DeviceTier.simulatorCpu);
      const StaticDeviceCapabilities device =
          StaticDeviceCapabilities(tier: DeviceTier.highEnd);
      expect(sim.preferredEngine(ModelFormat.litertlm), EngineKind.liteRtLm);
      expect(sim.preferredEngine(ModelFormat.task), EngineKind.mediaPipe);
      expect(sim.preferredBackend(), InferenceBackend.cpu);
      expect(device.preferredBackend(), InferenceBackend.gpuMetal);
    });
  });

  group('T15 canRun 分支', () {
    test('模拟器大模型 false；高端设备 E2B true', () {
      const StaticDeviceCapabilities sim =
          StaticDeviceCapabilities(tier: DeviceTier.simulatorCpu);
      const StaticDeviceCapabilities device =
          StaticDeviceCapabilities(tier: DeviceTier.highEnd);
      expect(sim.canRun(gemma4), isFalse);
      expect(sim.canRun(smol), isTrue);
      expect(device.canRun(gemma4), isTrue);
    });
  });

  group('E7 超档设备装大模型', () {
    test('默认拒绝 → failed(unsupportedDevice)；allowOverTier 放行', () async {
      final DefaultModelRepository repo = _repo(
        tier: DeviceTier.simulatorCpu,
        tokenStore: InMemoryTokenStore(initial: 'hf_x'),
      );
      final List<InstallEvent> denied =
          await repo.install(gemma4.id).toList();
      expect(denied.last.state, ModelState.failed);
      expect(denied.last.error, InstallErrorKind.unsupportedDevice);

      final List<InstallEvent> allowed =
          await repo.install(gemma4.id, allowOverTier: true).toList();
      expect(allowed.last.state, ModelState.ready);
    });
  });

  group('T16 重复 install 幂等', () {
    test('已 ready 再 install → 直接 ready，无重复下载', () async {
      final MockInstaller installer =
          MockInstaller((ModelDescriptor d, int a) => _happy(d));
      final DefaultModelRepository repo = _repo(installer: installer);

      await repo.install(smol.id).toList();
      expect(installer.installCallCount, 1);

      final List<InstallEvent> again = await repo.install(smol.id).toList();
      expect(again.single.state, ModelState.ready);
      expect(installer.installCallCount, 1);
    });
  });

  group('T17 并发 install 去重', () {
    test('同模型并发 → 复用同一下载流，仅下载一次', () async {
      final MockInstaller installer =
          MockInstaller((ModelDescriptor d, int a) => _happy(d));
      final DefaultModelRepository repo = _repo(installer: installer);

      final Future<List<InstallEvent>> first = repo.install(smol.id).toList();
      final Future<List<InstallEvent>> second = repo.install(smol.id).toList();
      final List<List<InstallEvent>> results =
          await Future.wait(<Future<List<InstallEvent>>>[first, second]);

      expect(results[0].last.state, ModelState.ready);
      expect(results[1].last.state, ModelState.ready);
      expect(installer.installCallCount, 1);
    });
  });
}
