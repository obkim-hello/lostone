import '../../models/model_descriptor.dart';

/// 内置模型目录（ERD §3.1 v1）。
///
/// 冒烟/兜底档：[smolLm135m]（宿主/模拟器 CPU 冒烟，不面向用户）、[gemma3_1b]
/// （0.5GB，低端兜底，不面向用户）；面向用户的对话档：[gemma4E2b]（2.4GB，均衡）
/// 与 [gemma4E4b]（3.66GB，最高质量）。用户目录的取舍在 UI 层完成（模块 010），
/// 本目录保留全部条目供开发冒烟（ADR-005）与安装/推荐逻辑复用。
class ModelCatalog {
  /// 创建目录（默认内置全部条目，可注入自定义条目用于测试）。
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
    description:
        'Tiny developer test model. For smoke tests only — not meant for real '
        'conversations.',
  );

  /// Gemma 3 1B（int4）：低端兜底档，0.5GB。
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
    description:
        'Smallest download. Fast and light, but replies are simpler — best for '
        'older phones or a quick try.',
  );

  /// Gemma 4 E2B：均衡对话档，2.4GB（面向用户默认推荐）。
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
    description:
        'Balanced choice. Good quality with a moderate download — recommended '
        'for most recent phones.',
  );

  /// Gemma 4 E4B：最高质量对话档，3.66GB（面向用户可选）。
  static const ModelDescriptor gemma4E4b = ModelDescriptor(
    id: 'gemma4-e4b',
    displayName: 'Gemma 4 E4B',
    format: ModelFormat.litertlm,
    family: ModelFamily.gemma4,
    sizeBytes: 3748 * 1024 * 1024,
    capabilities: <ModelCapability>{
      ModelCapability.text,
      ModelCapability.vision,
    },
    minTier: DeviceTier.highEnd,
    sourceUrl:
        'https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/resolve/main/gemma-4-E4B-it.litertlm',
    description:
        'Highest quality, most human-like replies. Large download and needs a '
        'newer, powerful phone.',
  );

  /// 全部条目（稳定顺序：冒烟/兜底档 → 面向用户的对话档）。
  List<ModelDescriptor> get all =>
      _entries ??
      const <ModelDescriptor>[smolLm135m, gemma3_1b, gemma4E2b, gemma4E4b];

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
