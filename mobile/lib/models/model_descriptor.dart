import 'package:flutter/foundation.dart';

/// 端侧模型文件格式（决定推理引擎选择）。
enum ModelFormat {
  /// LiteRT-LM 跨端格式（`.litertlm`）。
  litertlm,

  /// MediaPipe 格式（`.task`）。
  task,
}

/// 模型能力位。
enum ModelCapability {
  /// 文本生成。
  text,

  /// 视觉/多模态输入。
  vision,

  /// 函数调用。
  functionCalling,

  /// 思维链/推理增强。
  thinking,
}

/// 设备能力档位（决定可运行哪些模型与后端）。
enum DeviceTier {
  /// 模拟器/宿主，仅 CPU（Metal 分配上限极低）。
  simulatorCpu,

  /// 低端真机。
  lowEnd,

  /// 中端真机。
  midEnd,

  /// 高端真机。
  highEnd,
}

/// 推理后端。
enum InferenceBackend {
  /// iOS Metal GPU。
  gpuMetal,

  /// CPU。
  cpu,
}

/// 推理引擎种类。
enum EngineKind {
  /// LiteRT-LM 引擎（默认）。
  liteRtLm,

  /// MediaPipe 引擎（备选）。
  mediaPipe,
}

/// 模型架构族（提示/分词/加载差异）；映射到 `flutter_gemma` 的 `ModelType`。
///
/// 保持与插件解耦：本层仅描述模型属性，映射在安装器/运行时完成。
enum ModelFamily {
  /// Gemma 3 / 3n 指令模型（`ModelType.gemmaIt`）。
  gemmaIt,

  /// Gemma 4 模型（`ModelType.gemma4`）。
  gemma4,

  /// 通用族：SmolLM、视觉/推理等（`ModelType.general`）。
  general,
}

/// 模型目录条目：一个可下载模型的元数据（ERD §3.1）。
@immutable
class ModelDescriptor {
  /// 创建目录条目。
  const ModelDescriptor({
    required this.id,
    required this.displayName,
    required this.format,
    required this.family,
    required this.sizeBytes,
    required this.capabilities,
    required this.minTier,
    required this.sourceUrl,
    this.requiresToken = false,
    this.description = '',
  });

  /// 稳定标识（如 `gemma3-1b-it-int4`）。
  final String id;

  /// 展示名。
  final String displayName;

  /// 模型文件格式。
  final ModelFormat format;

  /// 架构族（映射到引擎 `ModelType`）。
  final ModelFamily family;

  /// 下载大小（字节）。
  final int sizeBytes;

  /// 能力集合。
  final Set<ModelCapability> capabilities;

  /// 推荐运行的最低设备档。
  final DeviceTier minTier;

  /// 下载地址。
  final String sourceUrl;

  /// 是否需要 Hugging Face token。
  final bool requiresToken;

  /// Plain-language, user-facing summary of what this model is good for and its
  /// trade-offs (size vs. quality). Empty when no copy is provided.
  final String description;

  @override
  bool operator ==(Object other) =>
      other is ModelDescriptor &&
      other.id == id &&
      other.displayName == displayName &&
      other.format == format &&
      other.family == family &&
      other.sizeBytes == sizeBytes &&
      setEquals(other.capabilities, capabilities) &&
      other.minTier == minTier &&
      other.sourceUrl == sourceUrl &&
      other.requiresToken == requiresToken &&
      other.description == description;

  @override
  int get hashCode => Object.hash(
    id,
    displayName,
    format,
    family,
    sizeBytes,
    Object.hashAllUnordered(capabilities),
    minTier,
    sourceUrl,
    requiresToken,
    description,
  );
}
