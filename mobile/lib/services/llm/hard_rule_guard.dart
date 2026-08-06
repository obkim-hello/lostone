import '../../models/persona_layers.dart';

/// 硬规则输出守卫（ERD-004 §5.4 步骤 5、SPEC-004 §2.4）。
///
/// `persona.hardRules` 已由 `PromptTemplate.render()` 注入 system prompt，故守卫
/// **只做输出后置校验**：不重复注入、不改写 system prompt。检测到越界（复述
/// `mustNeverClaim`、触碰 `forbiddenTopics`、自称 AI/程序）时，由 `ChatEngine`
/// 拦截未泄露的输出并改发 [safeReply]。
///
/// 为避免越界短语在流式传输中被逐 token 泄露，[lookback] 给出需回退缓冲的字符
/// 数（= 所有禁止短语的最大长度）——只要短语长度不超过该缓冲，其在拼接完整前
/// 始终滞留缓冲区，可被 [violates] 在任何字符外泄前截获。
class HardRuleGuard {
  /// 创建守卫。
  const HardRuleGuard({
    this.safeReply = '……这个话题我现在不太想聊，我们说点别的好吗。',
    this.selfIdentificationMarkers = const <String>[
      '我是AI',
      '我是 AI',
      '我是人工智能',
      '人工智能助手',
      '语言模型',
      '大模型',
      '我是程序',
      '我是机器人',
      '一个AI',
      '一个 AI',
    ],
  });

  /// 命中越界时改发的安全回复。
  final String safeReply;

  /// 自我暴露为 AI/程序的标志短语（对齐 `render()` 末句「绝不承认自己是 AI」）。
  final List<String> selfIdentificationMarkers;

  /// 汇总禁止短语：`mustNeverClaim` + `forbiddenTopics` + [selfIdentificationMarkers]。
  ///
  /// `safetyNotes` 是行为约束（已进 system prompt），不作输出屏蔽词。
  List<String> forbiddenPhrases(HardRules rules) => <String>[
        ...rules.mustNeverClaim,
        ...rules.forbiddenTopics,
        ...selfIdentificationMarkers,
      ].where((String s) => s.isNotEmpty).toList(growable: false);

  /// 需回退缓冲的字符数（所有禁止短语的最大长度）。
  int lookback(HardRules rules) {
    var maxLen = 0;
    for (final String phrase in forbiddenPhrases(rules)) {
      if (phrase.length > maxLen) {
        maxLen = phrase.length;
      }
    }
    return maxLen;
  }

  /// [text] 是否触碰任一禁止短语。
  bool violates(String text, HardRules rules) =>
      forbiddenPhrases(rules).any(text.contains);
}
