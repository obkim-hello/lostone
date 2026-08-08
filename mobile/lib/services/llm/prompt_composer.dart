import '../../models/message.dart';

/// 构造蒸馏 prompt（ERD-004 §4.4）。
///
/// 对齐 ex-skill 的 analyzer + builder 方法论：抽取表达风格/情感逻辑/关系行为/
/// 边界雷区，产出**可解析的 JSON**（键与 `DistillationParser` 约定一致）。
/// 硬约束：仅用原文出现的事实、不得编造、素材不足的维度归入 `insufficientLayers`。
///
/// 超长语料按 [LlmBuildOptions.maxChunkMessages] 分块，每块一个 prompt；调用方
/// 逐块生成后合并（SPEC-004 §5.4/T10，不静默截断）。
class PromptComposer {
  /// 创建 composer。
  const PromptComposer();

  /// 把目标人物文本消息分块为若干蒸馏 prompt。
  ///
  /// [textMessages] 应为**仅文本**的目标人物消息（非文本已在上游剔除，T11）。
  /// 返回至少一个 prompt；空语料返回单个「空语料」prompt（调用方通常已走骨架
  /// 分支，不会到这里）。
  List<String> compose(
    List<Message> textMessages, {
    int maxChunkMessages = 400,
  }) {
    final int chunkSize = maxChunkMessages < 1 ? 1 : maxChunkMessages;
    if (textMessages.length <= chunkSize) {
      return <String>[_promptFor(textMessages, 1, 1)];
    }
    final List<String> prompts = <String>[];
    final int chunks = (textMessages.length / chunkSize).ceil();
    for (int i = 0; i < textMessages.length; i += chunkSize) {
      final int end =
          (i + chunkSize) < textMessages.length ? i + chunkSize : textMessages.length;
      prompts.add(_promptFor(
        textMessages.sublist(i, end),
        prompts.length + 1,
        chunks,
      ));
    }
    return prompts;
  }

  /// 修复重提示：在原 [prompt] 上追加「只输出 JSON」的强约束。
  ///
  /// 用于模型上一轮返回散文/非法 JSON 时的重试（SPEC-004 §5.8）：强调仅输出单个
  /// JSON 对象、首字符 `{`、无前言/围栏，尽量把文本回答矫正回可解析结构。
  String repairPrompt(String prompt) => '''
$prompt

【重要·格式修复】上一次的回答不是合法 JSON。请**只输出一个 JSON 对象**：不要任何解释、前言、思考过程或 ``` markdown 代码围栏；第一个字符必须是 `{`，最后一个字符必须是 `}`。''';

  String _promptFor(List<Message> messages, int chunkIndex, int chunkTotal) {
    final StringBuffer corpus = StringBuffer();
    for (int i = 0; i < messages.length; i++) {
      corpus.writeln('${i + 1}. ${messages[i].content}');
    }
    final String chunkNote =
        chunkTotal > 1 ? '（本批为第 $chunkIndex/$chunkTotal 批）' : '';
    return '''
你是一名忠实的人物语言画像分析师。仅依据下面这个人**真实说过的话**，蒸馏其语言人格$chunkNote。

【硬约束】
- 只使用原文中真实出现的事实、词句；**严禁编造**人名、地点、事件或未出现的口头禅。
- catchphrases / emojis / punctuation / comfortPatterns / concernPatterns / termsForUser / preferences / exemplars 必须是原文中**逐字出现**过的词或句子。
- 某个维度素材不足（支撑 < 2 条）时，把该维度键名（identity/expression/emotion/relation 之一）加入 insufficientLayers，并把该维度内容留空——不要用先验补全。
- exemplars 为「你会怎么说」的**真实例句**（原文中的整句）。

【输出】仅输出一个 JSON 对象，键如下（缺省用空数组/省略）：
{
  "identity": {"displayName": "", "relationToUser": "", "aliases": []},
  "coreRules": {"forbiddenTopics": [], "mustNeverClaim": [], "safetyNotes": []},
  "expression": {"catchphrases": [], "emojis": [], "punctuation": [], "avgMessageLength": 0},
  "emotion": {"positiveRatio": 0.0, "negativeRatio": 0.0, "comfortPatterns": [], "concernPatterns": []},
  "relation": {"termsForUser": [], "initiationRatio": 0.0, "avgResponseGapMinutes": 0.0},
  "exemplars": [],
  "preferences": [],
  "tags": [],
  "insufficientLayers": []
}

【原文】
$corpus''';
  }
}
