import 'package:flutter/foundation.dart';

import 'model_descriptor.dart';

/// 模型安装状态（ERD §3.3 状态机）。
///
/// 迁移：`notInstalled → downloading → verifying → ready`；
/// 分支：`failed`、`paused`、`deleting`。仅 [ready] 可被激活。
enum ModelState {
  /// 未安装。
  notInstalled,

  /// 下载中。
  downloading,

  /// 下载完成、校验中。
  verifying,

  /// 就绪，可激活/加载。
  ready,

  /// 失败（伴随 [InstallErrorKind]）。
  failed,

  /// 暂停（保留断点）。
  paused,

  /// 删除中。
  deleting,
}

/// 安装失败原因（对应 SPEC §4 边界 E1–E6）。
enum InstallErrorKind {
  /// 模型不在目录（E1）。
  unknownModel,

  /// 磁盘空间不足（E2）。
  insufficientStorage,

  /// 网络中断（E3）。
  network,

  /// 受限模型缺少 token（E4）。
  authRequired,

  /// 完整性校验失败（E6）。
  corrupted,

  /// 设备不支持（超档/模拟器大模型，E7）。
  unsupportedDevice,

  /// 被取消（E5）。
  canceled,

  /// 未分类错误。
  unknown,
}

/// 下载/安装进度事件（ERD §3.6），供 UI 订阅。
@immutable
class InstallEvent {
  /// 创建进度事件。
  const InstallEvent({
    required this.modelId,
    required this.state,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.error,
  });

  /// 目标模型标识。
  final String modelId;

  /// 当前状态。
  final ModelState state;

  /// 已接收字节。
  final int receivedBytes;

  /// 总字节（未知时为 0）。
  final int totalBytes;

  /// 失败原因（仅 [ModelState.failed] 时非空）。
  final InstallErrorKind? error;

  @override
  bool operator ==(Object other) =>
      other is InstallEvent &&
      other.modelId == modelId &&
      other.state == state &&
      other.receivedBytes == receivedBytes &&
      other.totalBytes == totalBytes &&
      other.error == error;

  @override
  int get hashCode =>
      Object.hash(modelId, state, receivedBytes, totalBytes, error);
}

/// 已安装模型记录（ERD §3.2）。
@immutable
class InstalledModel {
  /// 创建记录。
  const InstalledModel({
    required this.descriptor,
    required this.filePath,
    required this.installedBytes,
    required this.state,
    required this.installedAt,
  });

  /// 目录条目。
  final ModelDescriptor descriptor;

  /// 落盘绝对路径。
  final String filePath;

  /// 已落盘字节。
  final int installedBytes;

  /// 当前状态。
  final ModelState state;

  /// 安装完成时间（UTC）。
  final DateTime installedAt;

  /// 返回一个仅替换状态的副本。
  InstalledModel withState(ModelState value) => InstalledModel(
        descriptor: descriptor,
        filePath: filePath,
        installedBytes: installedBytes,
        state: value,
        installedAt: installedAt,
      );

  @override
  bool operator ==(Object other) =>
      other is InstalledModel &&
      other.descriptor == descriptor &&
      other.filePath == filePath &&
      other.installedBytes == installedBytes &&
      other.state == state &&
      other.installedAt == installedAt;

  @override
  int get hashCode => Object.hash(
        descriptor,
        filePath,
        installedBytes,
        state,
        installedAt,
      );
}

/// 对外契约句柄（ERD §3.4 / SPEC §3），供模块 004 只读消费。
///
/// 模块 004 据此加载并推理，**不得改写**本对象。
@immutable
class ModelHandle {
  /// 创建句柄。
  const ModelHandle({
    required this.id,
    required this.filePath,
    required this.format,
    required this.capabilities,
    required this.backend,
    required this.engine,
  });

  /// 模型标识。
  final String id;

  /// 落盘绝对路径（内存映射加载用）。
  final String filePath;

  /// 模型格式（引擎选择依据）。
  final ModelFormat format;

  /// 能力集合。
  final Set<ModelCapability> capabilities;

  /// 推理后端。
  final InferenceBackend backend;

  /// 推理引擎。
  final EngineKind engine;

  @override
  bool operator ==(Object other) =>
      other is ModelHandle &&
      other.id == id &&
      other.filePath == filePath &&
      other.format == format &&
      setEquals(other.capabilities, capabilities) &&
      other.backend == backend &&
      other.engine == engine;

  @override
  int get hashCode => Object.hash(
        id,
        filePath,
        format,
        Object.hashAllUnordered(capabilities),
        backend,
        engine,
      );
}
