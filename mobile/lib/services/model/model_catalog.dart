import '../../models/model_descriptor.dart';

/// 内置模型目录（ERD §3.1 v1）。
///
/// 三档：[smolLm135m]（宿主/模拟器 CPU 冒烟）、[gemma3_1b]（设备默认，0.5GB）、
/// [gemma4E2b]（高质量，2.4GB）。
class ModelCatalog {
  /// 创建目录（默认内置三档，可注入自定义条目用于测试）。
  const ModelCatalog({List<ModelDescriptor>? entries}) : _entries = entries;

  final List<ModelDescriptor>? _entries;

  /// SmolLM2 135M：宿主/模拟器 CPU 冒烟档（免 token 的 `.litertlm`）。
  static const ModelDescriptor smolLm135m = ModelDescriptor(
    id: 'smollm2-135m',
    displayName: 'SmolLM2 135M',
    format: ModelFormat.litertlm,
    family: ModelFamily.general,
    sizeBytes: 142819328,
    capabilities: <ModelCapability>{ModelCapability.text},
    minTier: DeviceTier.simulatorCpu,
    sourceUrl:
        'https://huggingface.co/litert-community/SmolLM2-135M-Instruct/resolve/main/SmolLM2_135M_Instruct.litertlm',
  );

  /// Gemma 3 1B（int4）：设备默认档，0.5GB。
  static const ModelDescriptor gemma3_1b = ModelDescriptor(
    id: 'gemma3-1b-it-int4',
    displayName: 'Gemma 3 1B (int4)',
    format: ModelFormat.litertlm,
    family: ModelFamily.gemmaIt,
    sizeBytes: 512 * 1024 * 1024,
    capabilities: <ModelCapability>{ModelCapability.text},
    minTier: DeviceTier.lowEnd,
    sourceUrl:
        'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/gemma3-1b-it-int4.litertlm',
    requiresToken: true,
  );

  /// Gemma 4 E2B：高质量多模态档，2.4GB。
  static const ModelDescriptor gemma4E2b = ModelDescriptor(
    id: 'gemma4-e2b',
    displayName: 'Gemma 4 E2B',
    format: ModelFormat.litertlm,
    family: ModelFamily.gemma4,
    sizeBytes: 2472 * 1024 * 1024,
    capabilities: <ModelCapability>{
      ModelCapability.text,
      ModelCapability.vision,
    },
    minTier: DeviceTier.highEnd,
    sourceUrl:
        'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm',
  );

  /// 全部条目（默认三档，稳定顺序）。
  List<ModelDescriptor> get all =>
      _entries ??
      const <ModelDescriptor>[smolLm135m, gemma3_1b, gemma4E2b];

  /// 按 id 查询；不存在返回 null。
  ModelDescriptor? byId(String id) {
    for (final ModelDescriptor d in all) {
      if (d.id == id) {
        return d;
      }
    }
    return null;
  }
}
