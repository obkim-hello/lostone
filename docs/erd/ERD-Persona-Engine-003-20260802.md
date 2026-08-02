# ERD-003-Persona 生成引擎

> 工程需求文档 - Persona 生成引擎（Persona Engine）
>
> **版本**：v1.0.3
> **状态**：📝 草稿
> **作者**：Claude
> **日期**：2026-08-02
> **优先级**：P0

---

## 📋 文档信息

| 项目 | 内容 |
|------|------|
| **ERD 编号** | ERD-003 |
| **模块名称** | Persona 生成引擎（Persona Engine） |
| **关联 PRD** | PRD-Persona-Generation-003-20260802.md |
| **关联 Spec** | SPEC-Persona-Builder-003-20260802.md |
| **依赖模块** | ERD-Data-Parsers-002（数据导入）|
| **批准日期** | 待批准 |
| **批准人** | 待批准 |

---

## 1. 技术目标与约束

### 1.1 技术目标
- 提供一条**确定性、可复现、可解释**的 Persona 生成流水线：`Conversation → Memories → 性格特征 → 五层 Persona → .persona(JSON)`。
- 纯 Dart 实现，无原生依赖、无网络、无 LLM，可完全单元测试（对齐模块 002 的可测性风格）。
- 五层 Persona 模型与 `.persona` 文件格式稳定、版本化、向后兼容，作为下游模块 004/005/006 的唯一契约。
- 支持增量更新（merge）与幂等，version 语义明确。

### 1.2 设计约束
- **技术栈**：Flutter 3.38+ / Dart 3.11+（与仓库 `pubspec.yaml` `sdk: '>=3.11.0 <4.0.0'` 一致）。
- **确定性**：相同输入（含消息顺序归一化后）→ 相同输出（含 prompt 渲染）。禁用 `DateTime.now()`/随机数进入分析结论（生成时间戳仅作元信息，由调用方注入或单独字段隔离）。
- **隔离**：本模块**不**落盘、**不**加密——只产出 `Persona` 对象与 JSON 字节；持久化/加密由存储层（模块 008）负责。
- **隐私**：日志脱敏；`.persona` 与 prompt **绝不持久化整段原文**——证据引用只存**消息键的 SHA-256 哈希**（`messageKeyHash`，见 §3.1）、计数与一条可选的截断短示例（≤ 60 字符）。哈希跨导入稳定、可支撑去重/幂等/回溯，但不可逆还原原文，`.persona` 体积不随原文线性膨胀。
- **性能**：≤ 60s / 1000 条（PRD §4.1）；单遍/受影响重算，避免多份全量拷贝。
- **中文优先**：初版语言分析以中文 + 通用 Unicode 为主，基于规则 + n-gram 统计，不引入重型 NLP 依赖；预留分词/停用词注入点。

### 1.3 依赖关系
```
模块 002（数据导入）
  └── Conversation / Message / MessageType / DataSource（输入契约）
        └── ★ 模块 003（Persona 生成引擎）★
              ├── MemoriesAnalyzer
              ├── PersonaAnalyzer
              ├── PersonaBuilder（编排 + 版本 + 增量）
              ├── Persona 模型 + .persona 序列化
              └── PromptTemplate（渲染 system prompt）
                    └── 模块 004/005（LLM Runtime，消费 prompt）
                    └── 模块 008（存储/加密，落盘 .persona）
```

---

## 2. 架构设计

### 2.1 模块架构
```
lib/
├── models/
│   ├── persona.dart              # Persona 五层聚合根 + 元信息
│   ├── persona_layers.dart       # HardRules/Identity/ExpressionStyle/EmotionalLogic/RelationalBehavior
│   ├── memories.dart             # Memories/TimelineSpan/KeyEvent/Preference
│   └── evidence.dart             # Evidence（可解释性引用）+ Confidence
├── services/
│   └── persona/
│       ├── memories_analyzer.dart    # 记忆提取
│       ├── persona_analyzer.dart     # 性格分析
│       ├── persona_builder.dart      # 编排/版本/增量
│       ├── persona_codec.dart        # toJson/fromJson + schema 迁移
│       ├── prompt_template.dart      # Persona → system prompt
│       └── text_stats.dart           # n-gram/标点/emoji 统计工具
test/
├── unit/
│   ├── persona_model_test.dart
│   ├── memories_analyzer_test.dart
│   ├── persona_analyzer_test.dart
│   ├── persona_builder_test.dart
│   ├── persona_codec_test.dart
│   └── prompt_template_test.dart
└── integration/
    └── persona_pipeline_test.dart
```

### 2.2 数据流
```
Conversation
  │  (筛选目标人物消息：默认 Message.isFromMe==false 为对方；
  │   personSenderIds / myIdentifiers 覆盖/细化，见 §4.2 splitBySender)
  ▼
MemoriesAnalyzer ── Memories(timeline, keyEvents, preferences)
  │
  ▼
PersonaAnalyzer ── ExpressionStyle + EmotionalLogic + tags + Evidence/Confidence
  │
  ▼
PersonaBuilder ── 组装 Identity + HardRules(默认/沿用用户) + 上述层 + 元信息
  │            └── 增量: mergeMessages → 受影响重算 → merge → version++
  ▼
Persona ──► PersonaCodec.toJson ──► .persona (bytes)
        └──► PromptTemplate.render ──► system prompt (String)
```

---

## 3. 数据结构定义

### 3.1 核心数据模型

```dart
/// Persona 语义模型的当前 schema 版本。
///
/// 读取更高版本的 `.persona` 应报错；读取更低版本按迁移规则升级。
const int kPersonaSchemaVersion = 1;

/// 一个人格模型：五层结构 + 生成元信息。
///
/// Persona 是对话系统（模块 004/005/006）的唯一输入契约，
/// 不直接暴露原始聊天记录。
class Persona {
  /// 创建一个 Persona。
  const Persona({
    required this.id,
    required this.schemaVersion,
    required this.personaVersion,
    required this.generatedAt,
    required this.identity,
    required this.hardRules,
    required this.expressionStyle,
    required this.emotionalLogic,
    required this.relationalBehavior,
    required this.tags,
    required this.memories,
    required this.source,
  });

  /// 稳定标识。**确定性派生**：对来源签名
  /// `sortedParticipants | sortedTargetSenderIds | sortedDataSources`
  /// 取 SHA-256 得到。其中 `sortedTargetSenderIds` 是 **`splitBySender`
  /// 解析出的目标人物 senderId 去重升序集合**（默认路径 = 观察到的
  /// `isFromMe==false` 发送者集合；显式路径 = `personSenderIds`），
  /// **非**调用方传入的原始 `personSenderIds`——后者默认路径为空，会让
  /// 同一批参与者下的不同 1:1 人格 id 相撞。**刻意不含首条消息键或消息数**，
  /// 故对同一对话（参与者/目标发送者组成不变）的**消息级子集/超集**重建
  /// 仍得到相同 id（消除边界敏感）；1:1 会话下该组成天然稳定。若超集引入
  /// 全新发送者，则参与者与目标集合本就改变，属不同人格、id 变化符合预期。
  /// 增量更新时从 [existing] 原样沿用，跨版本不变。因其确定性，它不违反
  /// §确定性不变式。
  final String id;

  /// 语义 schema 版本，见 [kPersonaSchemaVersion]。
  final int schemaVersion;

  /// 内容版本，随每次（含增量）成功生成递增，首次为 1。
  final int personaVersion;

  /// 生成时间（UTC）。仅元信息，不参与任何分析结论。
  /// 由 [PersonaBuildOptions.clock] 注入；未注入时取确定性哨兵
  /// `DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)`（表示"未打时间戳"），
  /// **绝不调用 `DateTime.now()`**——保证零配置 `build()` 可用且确定性。
  final DateTime generatedAt;

  /// 第 2 层：身份。
  final Identity identity;

  /// 第 1 层：硬规则（用户可编辑禁忌，增量永不覆盖）。
  final HardRules hardRules;

  /// 第 3 层：表达风格。
  final ExpressionStyle expressionStyle;

  /// 第 4 层：情感逻辑。
  final EmotionalLogic emotionalLogic;

  /// 第 5 层：关系行为。
  final RelationalBehavior relationalBehavior;

  /// 由统计特征映射出的性格标签（每个附触发依据与置信度）。
  final List<PersonaTag> tags;

  /// 提取出的记忆（时间线/关键事件/偏好）。
  final Memories memories;

  /// 数据来源摘要（数据源、消息数、时间跨度、参与者）。
  final PersonaSource source;
}
```

```dart
/// 第 1 层 · 硬规则：显式禁忌与不可逾越的边界。
///
/// 由用户编辑；[PersonaBuilder] 增量更新时**永不覆盖**已有硬规则。
class HardRules {
  /// 创建硬规则层。
  const HardRules({
    this.forbiddenTopics = const <String>[],
    this.mustNeverClaim = const <String>[],
    this.safetyNotes = const <String>[],
  });

  /// 禁止触碰的话题。
  final List<String> forbiddenTopics;

  /// AI 绝不可声称的内容（如"我还活着"）。
  final List<String> mustNeverClaim;

  /// 其他安全/伦理约束说明。
  final List<String> safetyNotes;
}
```

```dart
/// 第 2 层 · 身份：这个人是谁。
class Identity {
  /// 创建身份层。
  const Identity({
    required this.displayName,
    this.relationToUser,
    this.aliases = const <String>[],
    this.confidence = Confidence.low,
  });

  /// 显示名称（如"妈妈"）。无可用名称时回退为
  /// [PersonaBuildOptions.defaultDisplayName]（默认"未命名"），
  /// 保证空会话下该字段仍非空。
  final String displayName;

  /// 与用户的关系（母亲/朋友/爱人…）。
  final String? relationToUser;

  /// 昵称/称呼别名（从消息中观察到）。
  final List<String> aliases;

  /// 该层的置信度。
  final Confidence confidence;
}
```

```dart
/// 第 3 层 · 表达风格：怎么说话。
class ExpressionStyle {
  /// 创建表达风格层。
  const ExpressionStyle({
    this.catchphrases = const <TermStat>[],
    this.emojiUsage = const <TermStat>[],
    this.punctuation = const <TermStat>[],
    this.avgMessageLength = 0,
    this.confidence = Confidence.low,
  });

  /// 高频口头禅/句首词（带计数）。
  final List<TermStat> catchphrases;

  /// 高频 emoji/表情（带计数）。
  final List<TermStat> emojiUsage;

  /// 标点习惯统计（如省略号、感叹号密度）。
  final List<TermStat> punctuation;

  /// 平均消息字符长度。
  final int avgMessageLength;

  /// 该层置信度。
  final Confidence confidence;
}
```

```dart
/// 第 4 层 · 情感逻辑：如何表达与回应情绪。
class EmotionalLogic {
  /// 创建情感逻辑层。
  const EmotionalLogic({
    this.positiveRatio = 0,
    this.negativeRatio = 0,
    this.comfortPatterns = const <TermStat>[],
    this.concernPatterns = const <TermStat>[],
    this.confidence = Confidence.low,
  });

  /// 正向情感词占比 [0,1]。
  final double positiveRatio;

  /// 负向情感词占比 [0,1]。
  final double negativeRatio;

  /// 安慰类话语模式（带计数）。
  final List<TermStat> comfortPatterns;

  /// 关心/叮嘱类话语模式（带计数）。
  final List<TermStat> concernPatterns;

  /// 该层置信度。
  final Confidence confidence;
}
```

```dart
/// 第 5 层 · 关系行为：与用户互动的模式。
class RelationalBehavior {
  /// 创建关系行为层。
  const RelationalBehavior({
    this.termsForUser = const <TermStat>[],
    this.initiationRatio = 0,
    this.avgResponseGapMinutes = 0,
    this.confidence = Confidence.low,
  });

  /// 对用户的称呼（带计数）。
  final List<TermStat> termsForUser;

  /// 主动发起对话的比例 [0,1]。
  final double initiationRatio;

  /// 平均回复间隔（分钟）。
  final double avgResponseGapMinutes;

  /// 该层置信度。
  final Confidence confidence;
}
```

```dart
/// 提取出的记忆集合。
class Memories {
  /// 创建记忆集合。
  const Memories({
    required this.timeline,
    this.keyEvents = const <KeyEvent>[],
    this.preferences = const <Preference>[],
  });

  /// 时间线区间与活跃度。
  final TimelineSpan timeline;

  /// 关键事件（带证据）。
  final List<KeyEvent> keyEvents;

  /// 偏好/习惯（带计数与证据）。
  final List<Preference> preferences;
}

/// 会话时间跨度与活跃度分布。
class TimelineSpan {
  /// 创建时间线区间。
  const TimelineSpan({
    required this.start,
    required this.end,
    required this.messageCount,
    this.activeHours = const <int, int>{},
  });

  /// 起始时间（UTC）。空会话（[messageCount] == 0）时为 null。
  final DateTime? start;

  /// 结束时间（UTC）。空会话（[messageCount] == 0）时为 null。
  final DateTime? end;

  /// 目标人物消息总数。
  final int messageCount;

  /// 活跃时段直方图：小时(0-23) → 消息数。
  ///
  /// 小时按 [Message.timestamp] 归一到 UTC 后取 `hour` 分桶
  /// （保证确定性，见 §5.1）。
  final Map<int, int> activeHours;
}

/// 一个被标记的关键事件。
class KeyEvent {
  /// 创建关键事件。
  const KeyEvent({
    required this.at,
    required this.summary,
    required this.evidence,
  });

  /// 事件时间（UTC）。
  final DateTime at;

  /// 事件摘要（模板拼装，非 LLM）。
  final String summary;

  /// 支撑该事件的证据。
  final Evidence evidence;
}

/// 一项偏好/习惯。
class Preference {
  /// 创建偏好项。
  const Preference({
    required this.term,
    required this.count,
    required this.evidence,
  });

  /// 偏好词/短语。
  final String term;

  /// 出现次数。
  final int count;

  /// 支撑证据。
  final Evidence evidence;
}
```

```dart
/// 词/短语统计项。
class TermStat {
  /// 创建统计项。
  const TermStat({required this.term, required this.count});

  /// 词或短语。
  final String term;

  /// 出现次数。
  final int count;
}

/// 可解释性证据：把结论回溯到真实消息，**不持久化原文**。
///
/// 只存**消息键哈希**、计数与一条可选短示例（隐私约束，见 §1.2/§8.1）。
///
/// 消息键哈希 = `sha256Hex(source|senderId|timestamp.iso8601|content|type)`，
/// 底层消息键与模块 002 `DataPreprocessor` 去重键逐字段一致，故哈希跨导入
/// 稳定且可用于去重/幂等/回溯；但不可逆，`.persona` 不再写入逐条原文。
/// 不使用 `Message.id`（后者仅单次导入内可引用、跨导入不稳定）。
class Evidence {
  /// 创建证据。
  const Evidence({
    this.messageKeyHashes = const <String>[],
    this.sampleExcerpt,
    this.occurrences = 0,
  });

  /// 支撑该结论的消息键哈希列表（SHA-256 十六进制，可截断）。
  final List<String> messageKeyHashes;

  /// 一条短示例（脱敏/截断，≤ 60 字符）。用于 UI 可读性，
  /// 是唯一允许出现的原文片段，长度受限。**encode 端强制按字符截断至
  /// 60**（`characters` 包按字素簇计，避免截断多字节/emoji）；decode 端
  /// 对超长值同样截断（防御性，见 SPEC §2.2），保证 `.persona` 不因该字段
  /// 泄漏超额原文。
  final String? sampleExcerpt;

  /// 命中总次数。
  final int occurrences;
}

/// 性格标签：由统计特征映射出的有限标签。
class PersonaTag {
  /// 创建标签。
  const PersonaTag({
    required this.label,
    required this.evidence,
    this.confidence = Confidence.low,
  });

  /// 标签文本（如"话痨"/"爱用表情"/"报喜不报忧"）。
  final String label;

  /// 触发该标签的依据。
  final Evidence evidence;

  /// 该标签的置信度。
  final Confidence confidence;
}

/// 结论置信度。
enum Confidence {
  /// 素材不足或信号弱。
  low,

  /// 中等样本量。
  medium,

  /// 样本充足、信号明确。
  high,
}

/// 数据来源摘要（PRD 中称 `sourceSummary`，即本类；JSON key 为 `source`）。
class PersonaSource {
  /// 创建来源摘要。
  const PersonaSource({
    required this.sources,
    required this.totalMessages,
    required this.personMessages,
    required this.mergedMessageKeyHashes,
    this.revisions = const <SourceRevision>[],
    this.segmentationResolved = true,
  });

  /// 涉及的数据源集合。
  final Set<DataSource> sources;

  /// 会话总消息数。
  final int totalMessages;

  /// 目标人物消息数。
  final int personMessages;

  /// 已并入的**消息键哈希**集合（增量去重基石，定义见 [Evidence]）。
  ///
  /// 底层键与模块 002 `DataPreprocessor` 去重键一致；用 `Message.id` 会因其
  /// 跨导入不稳定/不唯一而导致漏并或重复计数。存哈希而非原键——不落原文。
  final Set<String> mergedMessageKeyHashes;

  /// 版本修订轨迹（可追溯历史，满足 PRD 用户故事 2「不静默丢弃」）。
  ///
  /// **连续、完整、无裁剪**：`build` 写入首条（`personaVersion==1`），此后每次
  /// `update` 追加一条，故 `revisions` 恒为 `[v1, v2, …, vN]`（`personaVersion`
  /// 连续递增，末条 `== Persona.personaVersion`，`revisions.length == N`）。
  /// **大小随更新次数线性增长、与消息量无关**，不含原文，体积/隐私风险可忽略，
  /// 因此 v1 **不做裁剪**（若未来更新次数极多需限长，另行在 schema 迁移中定义）。
  final List<SourceRevision> revisions;

  /// 目标人物切分是否可靠（见 §4.2 splitBySender 守卫）。
  ///
  /// `true`（默认）：切分依据充分（显式 `personSenderIds`，或 `isFromMe`
  /// 能区分双方）。`false`：**方向/组成不可判定**——未传
  /// `personSenderIds`/`myIdentifiers`，且 `isFromMe` 全同（某些 parser
  /// 无法判定方向时默认全 `false`）或会话为多方（>1 目标发送者，v1 仅正式
  /// 支持 1:1）。此时引擎**不臆断把全体并入人格**，各层与 identity 的
  /// `confidence` 强制 `low`，并以本字段向下游/UI 显式暴露该降级，供提示用户
  /// 手动指定 `personSenderIds`。
  final bool segmentationResolved;
}

/// 一次生成/合并的版本快照（审计用，无原文）。
class SourceRevision {
  /// 创建修订快照。
  const SourceRevision({
    required this.personaVersion,
    required this.personMessages,
    required this.totalMessages,
  });

  /// 该修订对应的 [Persona.personaVersion]。
  final int personaVersion;

  /// 该修订时目标人物累计消息数。
  final int personMessages;

  /// 该修订时会话累计总消息数。
  final int totalMessages;
}
```

### 3.2 数据关系
- `Persona` 1—1 各层；1—* `PersonaTag`；1—1 `Memories`；1—1 `PersonaSource`；`PersonaSource` 1—* `SourceRevision`。
- `KeyEvent`/`Preference`/`PersonaTag`/各证据 → `Evidence`（引用**消息键哈希**，非 `Message.id`、非原键）。
- **消息键（唯一去重依据）**：`source|senderId|timestamp.iso8601|content|type`，与模块 002 `DataPreprocessor._dedupKey`（`data_preprocessor.dart`）逐字段一致。持久化时对其取 **SHA-256**（`messageKeyHash`），既保跨导入稳定去重，又不落原文。`Message.id` 不参与去重/合并——它仅在单次导入内可引用、跨导入既不唯一也不稳定（见 `message.dart` 对 `id` 的定义）。
- 增量更新的幂等由 `PersonaSource.mergedMessageKeyHashes` 保证（按消息键哈希去重）。
- `.persona` JSON 顶层含 `schemaVersion` + `personaVersion`；读取时先校验 `schemaVersion`。

---

## 4. 接口设计

### 4.1 对外接口（API）

```dart
/// 记忆提取器：从会话中提取时间线/关键事件/偏好。
abstract class MemoriesAnalyzer {
  /// 分析目标人物消息，返回记忆集合。
  ///
  /// [personMessages] 必须已按时间升序、去重。
  Memories analyze(List<Message> personMessages);
}

/// 性格分析器：统计语言风格与情感模式。
abstract class PersonaAnalyzer {
  /// 生成表达风格层。
  ExpressionStyle analyzeExpression(List<Message> personMessages);

  /// 生成情感逻辑层。
  EmotionalLogic analyzeEmotion(List<Message> personMessages);

  /// 生成关系行为层（需用户消息做对照）。
  RelationalBehavior analyzeRelation(
    List<Message> personMessages,
    List<Message> userMessages,
  );

  /// 由统计特征映射出标签集合。
  ///
  /// 同时消费四路信号，以覆盖风格类 + 情感类 + **关系类**（来自
  /// [relation]，如"黏人""报备型"）+ **偏好类**（来自 [memories] 的
  /// preferences，如"爱做饭"）标签，避免与关系行为层脱节。
  List<PersonaTag> deriveTags(
    ExpressionStyle style,
    EmotionalLogic emotion,
    RelationalBehavior relation,
    Memories memories,
  );
}

/// Persona 构建器：编排全流程、管理版本与增量。
abstract class PersonaBuilder {
  /// 首次全量生成。
  ///
  /// 目标人物切分优先级见 [splitBySender]：默认以 `Message.isFromMe==false`
  /// 判定对方；[personSenderIds] / [PersonaBuildOptions.myIdentifiers]
  /// 提供覆盖/细化。三者皆空时退化为纯 `isFromMe` 判定。
  Future<Persona> build(
    Conversation conversation, {
    Set<String> personSenderIds,
    PersonaBuildOptions options,
  });

  /// 增量更新：把 [newConversation] 并入 [existing]。
  ///
  /// 幂等：重复并入相同消息不改变统计结果，硬规则永不覆盖。
  Future<Persona> update(
    Persona existing,
    Conversation newConversation, {
    Set<String> personSenderIds,
    PersonaBuildOptions options,
  });
}

/// `.persona` 编解码器。
abstract class PersonaCodec {
  /// 序列化为 JSON 字节（UTF-8）。
  List<int> encode(Persona persona);

  /// 从 JSON 字节反序列化。
  ///
  /// 抛出 [PersonaSchemaException]：schema 版本不兼容且无迁移路径。
  /// 抛出 [FormatException]：JSON 结构非法。
  Persona decode(List<int> bytes);
}

/// Prompt 模板渲染器。
abstract class PromptTemplate {
  /// 把 Persona 渲染为确定性的 system prompt。
  String render(Persona persona, {PromptOptions options});
}

/// Prompt 渲染选项。
class PromptOptions {
  /// 创建渲染选项。
  const PromptOptions({
    this.tone = PromptTone.warm,
    this.maxChars = 2000,
  });

  /// 语气档位。
  final PromptTone tone;

  /// 输出长度上限（字符）。
  final int maxChars;
}

/// Prompt 语气档位。
enum PromptTone {
  /// 简洁。
  concise,

  /// 温暖（默认）。
  warm,

  /// 详尽。
  detailed,
}

/// `.persona` schema 版本不兼容（高于当前且无迁移路径）时抛出。
class PersonaSchemaException implements Exception {
  /// 创建异常。
  const PersonaSchemaException(this.message);

  /// 错误说明。
  final String message;
}
```

### 4.2 内部接口
- `text_stats.dart`：`List<TermStat> topNgrams(...)`、`List<TermStat> punctuationStats(...)`、`List<TermStat> emojiStats(...)`、`double sentimentRatio(...)`（基于内置词表，可注入）。
- `String messageKeyHash(Message m)`：先拼装消息键 `source|senderId|timestamp.iso8601|content|type`（对齐模块 002 去重键），再取 SHA-256 十六进制（`package:crypto`）。
- 目标人物筛选：`(List<Message> person, List<Message> user, bool resolved) splitBySender(Conversation, Set<String> personIds, Set<String> myIdentifiers)`。
  **切分优先级（逐条消息，确定性）**：
  1. `isUser = m.isFromMe || myIdentifiers.contains(m.senderId)`——`Message.isFromMe` 为**主判据**；
  2. 若 `personIds` 非空：`isTarget = personIds.contains(m.senderId)`（显式覆盖，与 `isUser` 冲突时以 `personIds` 为准）；否则 `isTarget = !isUser`（`isFromMe==false` 即对方）。
  这样默认路径不再把"补集=全体发送者"误并入人格，避免用户自己的消息污染逝者人格。

  **⚠️ 对模块 002 的依赖**：默认路径（无 `personIds`/`myIdentifiers`）的正确性**依赖模块 002 可靠填充 `Message.isFromMe`**。ERD-Data-Parsers-002 须保证各 parser 尽力判定消息方向；无法判定时不得静默全部置 `false`（否则会把用户消息误并入人格）。此契约在此显式声明，并由下述守卫兜底。

  **方向/组成不可判定守卫（返回 `resolved` 标志）**：当**未传** `personIds` 与 `myIdentifiers`，且满足以下任一时，判定 `resolved=false`：
  - **方向不可判定**：会话内 `isFromMe` 全同（通常全 `false`，即 parser 未能判定方向）；
  - **多方会话**：解析出的目标发送者 >1 个（v1 仅正式支持 1:1，群聊不做多人格拆分）。

  `resolved=false` 时仍返回结构完整的 Persona（沿零配置、不抛异常原则），但由 `build` 把各层与 identity 的 `confidence` 强制 `low`、置 `PersonaSource.segmentationResolved=false`，**不臆断把全体并入人格**，供 UI 提示用户显式指定 `personSenderIds` 后重建。`resolved=true` 时按上述优先级正常切分。

---

## 5. 实现细节

### 5.1 关键算法

**记忆提取（MemoriesAnalyzer）**
- 时间线：一遍扫描求 min/max 时间、按 `hour` 累加活跃度直方图、计数。
- 关键事件启发式：滑窗频次骤变（较基线 ×N）、超长消息、纪念性关键词命中；每个事件保留证据消息键**哈希**。
- 偏好：对目标人物文本做 n-gram（默认 bigram/trigram，中文按字/词，英文按空白）统计 Top-K，去停用词。

**性格分析（PersonaAnalyzer）**
- 口头禅：句首 token 与高频短语统计；标点：正则统计 `…`/`!`/`?`/重复标点密度；emoji：Unicode emoji + 常见颜文字表。
- 情感：正/负情感词表命中密度 → 比率；安慰/关心模式：关键词/句式规则。
- 标签：阈值规则映射，四路信号联合（表达风格 + 情感逻辑 + 关系行为 + 偏好），如 `avgMessageLength > X → 话痨`、`initiationRatio 高 → 黏人`、`concernPatterns 密集 → 报备型`；每标签附触发依据（`PersonaTag.evidence`，存哈希）。

**目标人物切分（splitBySender）**
- 主判据 `Message.isFromMe`；`personSenderIds`/`myIdentifiers` 覆盖/细化（优先级见 §4.2）。默认（三者除 isFromMe 外皆空）以 `isFromMe==false` 为对方，杜绝把用户消息计入人格。
- 依赖模块 002 可靠填充 `isFromMe`；不可判定（`isFromMe` 全同）或多方会话（>1 目标发送者）且无显式指定时，触发守卫：`resolved=false`、各层置信度降 `low`、`segmentationResolved=false`（见 §4.2）。
- `sortedTargetSenderIds`（用于 `id` 派生，见 §3.1）取**切分后实际观察到的目标发送者 senderId** 去重升序集合，非调用方原始入参。

**增量更新（PersonaBuilder.update）**
- 计算 `new` 每条消息的**消息键哈希**（`messageKeyHash`）；哈希已在 `existing.source.mergedMessageKeyHashes` 中则跳过（幂等），否则纳入。
- 仅当有真正新增消息时重算受影响统计并 merge（计数累加、时间线并集、Top-N 重排）；`mergedMessageKeyHashes = existing ∪ new_hashes`。
- 硬规则：直接沿用 `existing.hardRules`，绝不用分析结果覆盖。
- `id`：沿用 `existing.id`（跨版本不变；其派生签名亦不含消息数/首条消息，见 §3.1）。
- `revisions`：追加一条 `SourceRevision(personaVersion, personMessages, totalMessages)` 快照，保持 `[v1..vN]` 连续（`build` 已写入 v1，见 §3.1）。
- 时间归一：所有 `timestamp` 统一转 UTC 后再做时间线/活跃时段分桶，保证确定性。
- `personaVersion += 1`；`generatedAt` 由 `options.clock` 提供，未注入时取确定性哨兵 `epoch 0 (UTC)`——纯分析路径绝不调用 `DateTime.now()`。

### 5.2 边界与错误
- 空会话 / 无目标人物消息：返回结构完整但各层 `Confidence.low` 的 Persona，`personMessages == 0`；不抛异常、不编造。
- 方向/组成不可判定（`isFromMe` 全同且无显式指定，或多方会话）：不抛异常；各层 `Confidence.low`、`segmentationResolved=false`，不臆断并入（见 §4.2 守卫）。
- schema 版本高于当前：`decode` 抛 `PersonaSchemaException`。
- JSON 非法：抛 `FormatException`（不静默返回半成品）。

### 5.3 技术选型
| 技术点 | 选型 | 理由 |
|--------|------|------|
| 序列化 | `dart:convert` JSON | 无依赖、可读、与 GLOSSARY `.persona` 一致；Protobuf 见 ADR-003（暂不采用）|
| 消息键哈希 | `package:crypto` SHA-256 | Dart 官方维护、纯本地无网络；用于证据/去重键的不可逆持久化，替代落原文 |
| 情感/停用词 | 内置轻量词表 + 可注入 | 避免重型 NLP 依赖，保持确定性与可测 |
| n-gram | 自实现 `text_stats` | 完全可控、可测、无外部依赖 |
| 时钟 | 注入式 `DateTime Function()?` | 保证分析确定性、可测（禁 `DateTime.now()` 进结论）；缺省取 epoch 0 哨兵，零配置可用 |

---

## 6. 测试策略

### 6.1 单元测试（目标 > 80%）
- `persona_model_test`：五层默认值、无 null 层。
- `memories_analyzer_test`：时间线 min/max/直方图、关键事件命中、n-gram 偏好、空输入。
- `persona_analyzer_test`：口头禅/标点/emoji 计数、情感比率、标签阈值、证据回溯。
- `persona_codec_test`：`decode(encode(p))` 值相等（往返无损）；坏 JSON→FormatException；高 schema→PersonaSchemaException。
- `persona_builder_test`：首次生成 version=1；增量去重幂等；硬规则不被覆盖；version 递增。
- `prompt_template_test`：同输入同输出；仅含 Persona 字段内容。

### 6.2 集成测试
- `persona_pipeline_test`：合成 `Conversation`（含目标人物+用户消息）→ build → update（追加）→ 断言 merge、version、置信度提升。

### 6.3 测试数据
- **仅使用合成 fixture**。严禁使用任何真实导出数据（隐私约束，见 PRD §4.2 与项目安全要求）。合成会话覆盖：中英文混合、emoji、多标点、超短/超长消息、无目标人物、重复消息（幂等）。

---

## 7. 性能与优化

### 7.1 性能指标
| 指标 | 目标值 | 测量方法 |
|------|--------|---------|
| 全量生成 | ≤ 60s / 1000 条 | 集成基准（宿主机）|
| 增量更新 | 显著 < 同规模全量 | 对比基准 |
| 内存峰值 | ~O(语料规模) | 避免多份全量拷贝 |

### 7.2 优化策略
- 单遍统计聚合，尽量流式/迭代，不重复遍历。
- 增量只重算受影响部分；Top-N 用有界堆/计数表。
- 大文本分块处理，避免一次性巨型中间结构。

---

## 8. 安全考虑

### 8.1 安全要求
- 无网络、无外传（可在无网络环境验证）。
- 日志脱敏：不打印消息原文、称呼、地址等；仅打印计数/类别。
- `.persona` 与 prompt 仅含 Persona 字段；`Evidence` 只存**消息键哈希**/计数/短示例，**不落逐条原文**，`sampleExcerpt` 是唯一原文片段且须截断（≤ 60 字符）。`.persona` 体积因此保持在数十~数百 KB 量级，不随聊天量线性膨胀。
- 落盘与加密由存储层（模块 008）负责；本模块产物为明文，调用方须交由加密存储。
- **绝不使用真实导出数据做测试/示例**——仅合成 fixture。

### 8.2 隐私合规
- 与 ADR-002（隐私优先）/项目隐私要求一致：100% 本地、用户可删除、开源可审计。

---

## 9. 部署与运维

> 引擎层随 App 内嵌，无独立部署。产物（`.persona`）由存储层管理，可导出/删除（Phase 4 UI）。

---

## 10. 附录

### 10.1 参考资料
- PRD-Persona-Generation-003-20260802.md
- SPEC-Persona-Builder-003-20260802.md
- GLOSSARY（五层结构 / `.persona` / 增量更新）
- ERD-Data-Parsers-002（Conversation/Message 输入契约）
- CLAUDE.md（Dart 规范、性能指标、隐私要求）

### 10.2 技术债务
- 中文分词初版为规则/n-gram，语义准确度有限；后续可评估引入可选分词器。
- LLM 增强（用模型润色人格描述）留待模块 004/005 之后。
- Protobuf 化 `.persona`（ADR-003）留待评估。

### 10.3 变更记录
| 日期 | 版本 | 变更内容 | 作者 |
|------|------|---------|------|
| 2026-08-02 | v1.0（草稿）| 初始草稿 | Claude |
| 2026-08-02 | v1.0.1（草稿）| 代理评审修订：(B1) 去重/合并键改为消息内容键（`source\|senderId\|timestamp\|content\|type`，对齐模块 002，非 `Message.id`），`PersonaSource.mergedMessageIds`→`mergedMessageKeys`、`Evidence.messageIds`→`messageKeys`；(B2) 定义 `PersonaTag` 并加入 `Persona.tags`；(B3) 空会话下 `TimelineSpan.start/end` 改可空、`displayName` 回退 `defaultDisplayName`；(M1) `Persona.id` 明确确定性派生；补 `PromptOptions`/`PromptTone`/`PersonaSchemaException` 定义；活跃时段按 UTC 分桶 | Claude |
| 2026-08-02 | v1.0.2（草稿）| PR #10 Owner 评审修订：(🔴1 隐私) 证据/去重键**持久化改存 SHA-256 哈希**（`Evidence.messageKeys`→`messageKeyHashes`、`PersonaSource.mergedMessageKeys`→`mergedMessageKeyHashes`，新增 `package:crypto` + `messageKeyHash()`），`.persona` 不再落逐条原文、体积不膨胀，兑现 §1.2/§8.1 承诺；(🔴3 切分) `splitBySender` 以 `Message.isFromMe` 为主判据、`personSenderIds`/`myIdentifiers` 覆盖，默认路径不再污染人格；(🟡4 历史) 新增 `SourceRevision` + `PersonaSource.revisions` 版本轨迹（有界、无原文），落实 PRD 用户故事 2；(minor) `Persona.id` 派生签名去除首条消息键/消息数（消除边界敏感）、`generatedAt` clock 缺省取 epoch 0 哨兵（不抛错、零配置可用）、`deriveTags` 增 `relation`/`memories` 入参覆盖关系/偏好标签、`PersonaSource` 标注即 PRD `sourceSummary` | Claude |
| 2026-08-02 | v1.0.3（草稿）| PR #10 Owner 复审修订：(🟡A) `revisions` 定义为**连续 `[v1..vN]`**（`build` 写 v1、每 `update` 追加，末条==`personaVersion`、不裁剪），消除示例↔"每次追加"↔校验矛盾；(🟡B) 显式声明对模块 002 可靠填充 `isFromMe` 的依赖，`splitBySender` 新增**方向/组成不可判定守卫**（返回 `resolved`）——不可判定/多方且无显式指定时降 `low` 置信、`segmentationResolved=false`、不臆断并入；(minor C) `sampleExcerpt` encode 端强制按字素簇截断至 60、decode 端防御性截断；(minor D) 明确 `id` 的 `sortedTargetSenderIds`=切分后**观察到的目标发送者集合**（非原始入参），界定超集稳定性范围；(minor E) 声明 v1 仅正式支持 1:1，多方会话并入守卫 | Claude |

---

> 本文档为**草稿**，开发状态**阻塞**，需三文档评审批准后方可编码。技术栈须与仓库实际工具链保持一致。
