import '../../models/model_descriptor.dart';

/// 给定设备档位是否可运行某模型（纯函数，不依赖真实设备）。
///
/// 规则：模型 `minTier` 不高于设备档即可运行。故 [DeviceTier.simulatorCpu]
/// 设备（最低档）只能运行 `minTier == simulatorCpu` 的模型（如 SmolLM）。
bool tierCanRun(DeviceTier tier, ModelDescriptor descriptor) =>
    descriptor.minTier.index <= tier.index;

/// 设备能力探测与引擎/后端选择（ERD §4.3）。
abstract class DeviceCapabilities {
  /// 设备档位。
  DeviceTier tier();

  /// 优先后端（真机默认 Metal，模拟器/无 GPU → CPU）。
  InferenceBackend preferredBackend();

  /// 依模型格式选择引擎。
  EngineKind preferredEngine(ModelFormat format);

  /// 该设备是否可运行给定模型（超档/模拟器大模型 → false）。
  bool canRun(ModelDescriptor descriptor);
}

/// 注入式设备能力（宿主测试用；生产由原生探测装配）。
class StaticDeviceCapabilities implements DeviceCapabilities {
  /// 创建注入式能力。
  const StaticDeviceCapabilities({required DeviceTier tier}) : _tier = tier;

  final DeviceTier _tier;

  @override
  DeviceTier tier() => _tier;

  @override
  InferenceBackend preferredBackend() => _tier == DeviceTier.simulatorCpu
      ? InferenceBackend.cpu
      : InferenceBackend.gpuMetal;

  @override
  EngineKind preferredEngine(ModelFormat format) => switch (format) {
        ModelFormat.litertlm => EngineKind.liteRtLm,
        ModelFormat.task => EngineKind.mediaPipe,
      };

  @override
  bool canRun(ModelDescriptor descriptor) => tierCanRun(_tier, descriptor);
}
