import 'dart:async';

import '../../models/model_descriptor.dart';
import '../../models/model_install.dart';
import 'device_capabilities.dart';
import 'model_catalog.dart';
import 'model_installer.dart';
import 'model_store.dart';
import 'token_store.dart';

/// 模型管理门面（SPEC §2）：目录、安装、激活、句柄查询。
///
/// 边界即「拿到设备并校验、暴露 [ModelHandle]」；推理属模块 004。
/// [getActiveModelHandle] 返回 null 即触发模块 004 统计兜底（ADR-004）。
abstract class ModelRepository {
  /// 内置模型目录；给定 [recommendFor] 时按可运行性/档位排序推荐（SPEC §2.1）。
  List<ModelDescriptor> catalog({DeviceTier? recommendFor});

  /// 安装模型，流式产出进度（SPEC §2.2）。
  ///
  /// 未知 [modelId] 抛 [ArgumentError]；已就绪直接发 `ready`；进行中的同模型
  /// 复用同一下载流（去重）。受限模型经 [hfToken] 或已存 token 鉴权。
  /// 默认拒绝超档设备，[allowOverTier] 为用户显式确认后放行（E7）。
  Stream<InstallEvent> install(
    String modelId, {
    String? hfToken,
    bool allowOverTier = false,
  });

  /// 取消进行中的下载并清理半成品（SPEC §2.3）。
  Future<void> cancel(String modelId);

  /// 删除模型、回收占用；若为激活模型则激活置空。幂等（SPEC §2.4）。
  Future<void> delete(String modelId);

  /// 将就绪模型设为激活；非就绪抛 [StateError]（SPEC §2.5）。
  Future<void> setActive(String modelId);

  /// 激活模型的只读句柄；无激活/无就绪返回 null（SPEC §2.6）。
  Future<ModelHandle?> getActiveModelHandle();

  /// 已安装模型快照（SPEC §2.7）。
  List<InstalledModel> installed();

  /// 查询模型状态；未知模型返回 [ModelState.notInstalled]（SPEC §2.7）。
  ModelState stateOf(String modelId);
}

/// [ModelRepository] 默认实现：协作者注入，宿主可用内存假件测试。
class DefaultModelRepository implements ModelRepository {
  /// 创建仓库；协作者与 [clock]（默认 epoch-0 UTC，绝不回退 `DateTime.now`）注入。
  DefaultModelRepository({
    required ModelCatalog catalog,
    required ModelInstaller installer,
    required ModelStore store,
    required DeviceCapabilities device,
    required TokenStore tokenStore,
    DateTime Function()? clock,
  })  : _catalog = catalog,
        _installer = installer,
        _store = store,
        _device = device,
        _token = tokenStore,
        _clock = clock ??
            (() => DateTime.fromMillisecondsSinceEpoch(0, isUtc: true));

  final ModelCatalog _catalog;
  final ModelInstaller _installer;
  final ModelStore _store;
  final DeviceCapabilities _device;
  final TokenStore _token;
  final DateTime Function() _clock;

  final Map<String, _InstallJob> _jobs = <String, _InstallJob>{};
  final Map<String, InstalledModel> _installed = <String, InstalledModel>{};
  final Map<String, ModelState> _states = <String, ModelState>{};
  String? _activeId;

  @override
  List<ModelDescriptor> catalog({DeviceTier? recommendFor}) {
    final List<ModelDescriptor> list =
        List<ModelDescriptor>.of(_catalog.all);
    if (recommendFor == null) {
      return list;
    }
    list.sort((ModelDescriptor a, ModelDescriptor b) {
      final bool ra = tierCanRun(recommendFor, a);
      final bool rb = tierCanRun(recommendFor, b);
      if (ra != rb) {
        return ra ? -1 : 1;
      }
      return b.minTier.index.compareTo(a.minTier.index);
    });
    return list;
  }

  @override
  Stream<InstallEvent> install(
    String modelId, {
    String? hfToken,
    bool allowOverTier = false,
  }) {
    final ModelDescriptor? descriptor = _catalog.byId(modelId);
    if (descriptor == null) {
      throw ArgumentError.value(modelId, 'modelId', '模型不在目录中');
    }
    if (_states[modelId] == ModelState.ready) {
      return Stream<InstallEvent>.value(
        InstallEvent(
          modelId: modelId,
          state: ModelState.ready,
          receivedBytes: descriptor.sizeBytes,
          totalBytes: descriptor.sizeBytes,
        ),
      );
    }
    final _InstallJob? existing = _jobs[modelId];
    if (existing != null) {
      return existing.controller.stream;
    }
    final _InstallJob job =
        _InstallJob(StreamController<InstallEvent>.broadcast());
    _jobs[modelId] = job;
    scheduleMicrotask(() {
      unawaited(_pump(
        descriptor,
        job,
        hfToken: hfToken,
        allowOverTier: allowOverTier,
      ));
    });
    return job.controller.stream;
  }

  @override
  Future<void> cancel(String modelId) async {
    final _InstallJob? job = _jobs[modelId];
    if (job == null) {
      return;
    }
    job.canceled = true;
    await _installer.cancel(modelId);
    await job.sub?.cancel();
    if (!job.done.isCompleted) {
      job.done.complete();
    }
    await job.finished;
  }

  @override
  Future<void> delete(String modelId) async {
    await _store.remove(modelId);
    _installed.remove(modelId);
    _states[modelId] = ModelState.notInstalled;
    if (_activeId == modelId) {
      _activeId = null;
    }
  }

  @override
  Future<void> setActive(String modelId) async {
    if (_states[modelId] != ModelState.ready) {
      throw StateError('模型 $modelId 未就绪，无法激活');
    }
    _activeId = modelId;
  }

  @override
  Future<ModelHandle?> getActiveModelHandle() async {
    final String? id = _activeId;
    if (id == null) {
      return null;
    }
    final InstalledModel? model = _installed[id];
    if (model == null || model.state != ModelState.ready) {
      return null;
    }
    return ModelHandle(
      id: model.descriptor.id,
      filePath: model.filePath,
      format: model.descriptor.format,
      capabilities: model.descriptor.capabilities,
      backend: _device.preferredBackend(),
      engine: _device.preferredEngine(model.descriptor.format),
    );
  }

  @override
  List<InstalledModel> installed() =>
      List<InstalledModel>.of(_installed.values);

  @override
  ModelState stateOf(String modelId) =>
      _states[modelId] ?? ModelState.notInstalled;

  Future<void> _pump(
    ModelDescriptor descriptor,
    _InstallJob job, {
    String? hfToken,
    required bool allowOverTier,
  }) async {
    final String modelId = descriptor.id;
    ModelState finalState = ModelState.notInstalled;
    int lastTotal = 0;

    void emit(InstallEvent event) {
      _states[modelId] = event.state;
      if (!job.controller.isClosed) {
        job.controller.add(event);
      }
    }

    InstallEvent failure(InstallErrorKind kind) => InstallEvent(
          modelId: modelId,
          state: ModelState.failed,
          error: kind,
        );

    try {
      if (!_device.canRun(descriptor) && !allowOverTier) {
        finalState = ModelState.failed;
        emit(failure(InstallErrorKind.unsupportedDevice));
        return;
      }
      final String? token = hfToken ?? await _token.read();
      if (job.canceled) {
        return;
      }
      if (descriptor.requiresToken && (token == null || token.isEmpty)) {
        finalState = ModelState.failed;
        emit(failure(InstallErrorKind.authRequired));
        return;
      }
      final int free = await _store.freeBytes();
      if (job.canceled) {
        return;
      }
      if (free < descriptor.sizeBytes) {
        finalState = ModelState.failed;
        emit(failure(InstallErrorKind.insufficientStorage));
        return;
      }

      job.sub = _installer.install(descriptor, hfToken: token).listen(
        (InstallEvent event) {
          if (event.totalBytes != 0) {
            lastTotal = event.totalBytes;
          }
          finalState = event.state;
          emit(event);
        },
        onError: (Object error) {
          finalState = ModelState.failed;
          emit(failure(InstallErrorKind.network));
          if (!job.done.isCompleted) {
            job.done.complete();
          }
        },
        onDone: () {
          if (!job.done.isCompleted) {
            job.done.complete();
          }
        },
        cancelOnError: true,
      );
      await job.done.future;
    } finally {
      if (job.canceled) {
        await _store.remove(modelId);
        finalState = ModelState.notInstalled;
        emit(InstallEvent(modelId: modelId, state: ModelState.notInstalled));
      } else if (finalState == ModelState.ready) {
        final int bytes = lastTotal != 0 ? lastTotal : descriptor.sizeBytes;
        await _store.put(modelId, bytes);
        _installed[modelId] = InstalledModel(
          descriptor: descriptor,
          filePath: _store.pathFor(modelId),
          installedBytes: bytes,
          state: ModelState.ready,
          installedAt: _clock().toUtc(),
        );
      } else if (finalState == ModelState.failed) {
        await _store.remove(modelId);
      }
      _states[modelId] = finalState;
      await job.sub?.cancel();
      _jobs.remove(modelId);
      if (!job.controller.isClosed) {
        await job.controller.close();
      }
      job.markFinished();
    }
  }
}

class _InstallJob {
  _InstallJob(this.controller);

  final StreamController<InstallEvent> controller;
  final Completer<void> done = Completer<void>();
  final Completer<void> _finished = Completer<void>();
  StreamSubscription<InstallEvent>? sub;
  bool canceled = false;

  Future<void> get finished => _finished.future;

  void markFinished() {
    if (!_finished.isCompleted) {
      _finished.complete();
    }
  }
}
