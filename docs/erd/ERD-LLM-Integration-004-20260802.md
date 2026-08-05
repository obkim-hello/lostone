# ERD-004-LLM 集成

> 工程需求文档 - LLM 集成（LLM 蒸馏人格 + 对话引擎，含 Runtime 抽象层）
>
> **版本**：v1.1.1
> **状态**：✅ 已批准（Project Owner，2026-08-04）
> **作者**：Claude
> **日期**：2026-08-02
> **优先级**：P0

---

## 📋 文档信息

| 项目 | 内容 |
|------|------|
| **ERD 编号** | ERD-004 |
| **模块名称** | LLM 集成（蒸馏 + 对话引擎 + Runtime 抽象层）|
| **关联 PRD** | PRD-LLM-Integration-004-20260802.md |
| **关联 Spec** | SPEC-LLM-Integration-004-20260802.md |
| **依赖模块** | 模块 002（数据导入）、模块 003（Persona 生成/契约）、模块 007（模型管理）|
| **关联决策** | ADR-002、ADR-004、ADR-005 |

---

## 1. 技术目标与约束

### 1.1 技术目标
- 定义 `LlmPersonaBuilder`：以 LLM 蒸馏产出忠实五层人格，映射为模块 003 现有 `Persona`。
- 定义 `ChatEngine`：以 `Persona` 渲染的 system prompt 驱动多轮流式对话（滑窗上下文、硬规则强制、本地/云端切换）。
- 定义 `PersonaRuntime` 抽象层：统一本地 LiteRT（经 ADR-005 flutter_gemma）与云端 API，默认本地、云端 opt-in；**蒸馏与对话共用**。
- 定义蒸馏 prompt 工程：抽取维度（analyzer）+ 五层模板（builder），产出可解析的结构化人格。
- 定义统计兜底与增量更新如何复用模块 003；定义如何经模块 007 的 `ModelHandle` 加载本地模型。
- 定义开发者调试台（dev-only harness）如何复用生产接口做真机质量评审。

### 1.2 关键约束
- **输出契约不变**：`Persona`（`mobile/lib/models/persona.dart`）与 `PromptTemplate.render()`（`mobile/lib/services/persona/prompt_template.dart`）对外形状不改；蒸馏结果必须映射进现有五层；对话 system prompt 只经现有 `render()`。
- **不重写模块 003**：统计引擎按原样保留，仅被本模块只读复用（预处理/切分/兜底/编解码/渲染）。
- **模型就绪归模块 007**：本模块不自造下载器；经 `ModelRepository.getActiveModelHandle()` 拿 `ModelHandle`，用其 `filePath`/`engine`/`backend` 加载。
  - ⚠️ **前置契约缺口：见 [DD-001](../overview/DESIGN-DEBT.md#dd-001)**。`flutter_gemma` v1.5.2 自管落盘、**不暴露 `filePath`**，推理经 `getActiveModel()` 拿模型对象。本模块设计 `LiteRtRuntime` 时**必须先定夺** `ModelHandle` 契约（改句柄语义 / `filePath` 置空 + 走 `getActiveModel()`），否则会误用一个无法生产兑现的 `filePath`。按 ADR-005，`LiteRtRuntime` 本就用 `getActiveModel/createChat/generate`，多半不需要 `filePath`。
- **隐私**：默认本地、原文不出设备；云端显式授权；`.persona` 只存消息键哈希、不落原文；日志脱敏。
- **无 byte 确定性**：LLM 有随机性 → 测试改为契约/结构断言 + mock Runtime + 快照/人工评审（见 §6）。
- **端侧栈固定 flutter_gemma / LiteRT-LM**（ADR-005）：本地蒸馏与对话经 `flutter_gemma` 的 `getActiveModel/createChat/generate`，运行于 iOS 16+/macOS；质量验收须真机（模拟器仅 CPU 冒烟）。

---

## 2. 系统架构

### 2.1 分层与数据流
```
raw chat
  → [模块 002] 解析/标准化 → Conversation
  → [模块 003] 预处理（去重、message-key 哈希、splitBySender、表层统计）
  → [模块 004] ── 支柱 A：蒸馏（离线一次性）──
        LlmPersonaBuilder
        ├─ PromptComposer   构造蒸馏 prompt（ex-skill analyzer 维度 + builder 五层模板）
        ├─ PersonaRuntime   推理（LiteRtRuntime | CloudRuntime | —）
        │     └─ 无模型/最大隐私 → StatisticalFallback（模块 003）
        ├─ DistillationParser  解析模型输出为中间结构 DistilledPersona
        └─ PersonaMapper    DistilledPersona → 模块 003 Persona（五层 + tags + memories）
  → [模块 003] PersonaJsonCodec 写 .persona / PromptTemplate 渲染 systemPrompt
  → [模块 004] ── 支柱 B：对话（在线交互）──
        ChatEngine
        ├─ PromptTemplate.render(persona)  → system prompt（现有契约，不新增）
        ├─ ContextWindow   滑动窗口（system + 最近 N 轮 + 新消息，超窗裁剪）
        ├─ HardRuleGuard   聊天时硬规则注入 + 输出后置校验/拦截
        └─ PersonaRuntime  流式生成 → Stream<ChatDelta>（与支柱 A 共用同一 Runtime）
  → [模块 006] 聊天 UI（消费 ChatEngine 流）；开发期用 dev 调试台

  ── 共用底座 ──
  PersonaRuntime.LiteRtRuntime → [flutter_gemma / LiteRT-LM]（ADR-005）
      └─ 模型经 [模块 007] ModelRepository.getActiveModelHandle() → ModelHandle 加载
```

### 2.2 与模块 003 的关系
- 模块 003 = **确定性预处理 + 离线兜底 + 输出契约宿主**。
- 模块 004 = **LLM 蒸馏正式人格 + Runtime 抽象**，产物落回模块 003 契约。
- 两者产出的 `Persona` 结构一致，下游（006/008）无差别消费。

---

## 3. 数据结构定义

### 3.1 运行选项 `LlmBuildOptions`
| 字段 | 类型 | 默认 | 说明 |
|------|------|------|------|
| mode | `PersonaRuntimeMode` | `local` | `local` / `cloud` / `maxPrivacy`（统计兜底）|
| modelId | `String?` | null | 本地模型标识（模块 007 提供）|
| temperature | `double` | 0.2 | 低温度以抑制幻觉 |
| maxChunkMessages | `int` | 由 ERD §7 | 超长语料分块阈值 |
| cloudAuthorized | `bool` | false | 云端每次调用授权门控 |
| personSenderIds | `Set<String>` | {} | 复用模块 003 切分语义 |

### 3.2 运行模式 `PersonaRuntimeMode`
`local`（默认，本地 LiteRT）｜`cloud`（显式 opt-in）｜`maxPrivacy`（无模型，纯统计兜底）。

### 3.3 中间结构 `DistilledPersona`（模块内部，不落盘、不对外）
LLM 输出解析后的分层中间态，字段与 ex-skill 五层对应，随后由 `PersonaMapper` 映射为对外 `Persona`。仅内存态，避免引入第二种持久化契约。

| 字段 | 对应 ex-skill | 映射目标（模块 003）|
|------|---------------|---------------------|
| coreRules | Layer 0 核心性格 | `HardRules`（仅建议，不覆盖用户设置）|
| identity | Layer 1 身份 | `Identity`（displayName/relationToUser/aliases）|
| expression | Layer 2 表达风格（口头禅/高频词/例句）| `ExpressionStyle`（catchphrases/emojiUsage/punctuation）|
| emotion | Layer 3 情感逻辑 | `EmotionalLogic`（comfortPatterns/concernPatterns/ratio）|
| relation | Layer 4 关系行为 | `RelationalBehavior`（termsForUser/initiationRatio）|
| boundaries | Layer 5 边界与雷区 | `HardRules.forbiddenTopics` + `tags` |
| exemplars | "你会怎么说"例句 | `Memories.keyEvents` / 承载于 tags 依据 + 短示例 |
| preferences | 偏好/常提及 | `Memories.preferences` |
| tags | 性格标签 | `Persona.tags`（`PersonaTag` + `Evidence`）|
| insufficientLayers | "原材料不足"标注 | 对应层 `confidence: low` + note |

> **契约适配原则**：优先用现有字段承载；`Persona`/`PromptTemplate` 对外形状不变。若真实例句需要更强承载，见 §4.3 契约兼容策略。

### 3.4 Runtime 结果 `RuntimeResult`
| 字段 | 类型 | 说明 |
|------|------|------|
| text | `String` | 模型原始文本响应 |
| source | `RuntimeSource` | `liteRt` / `cloud` / `fallback` |
| truncated | `bool` | 是否因上下文/长度截断 |
| error | `RuntimeError?` | 分类错误（无模型/网络/未授权/超限）|

### 3.5 对话结构（ChatEngine）

**`ChatTurn`**（一轮消息）
| 字段 | 类型 | 说明 |
|------|------|------|
| role | `ChatRole` | `user` / `persona` |
| text | `String` | 消息内容 |
| at | `DateTime` | UTC 时间戳 |

**`ChatOptions`**
| 字段 | 类型 | 默认 | 说明 |
|------|------|------|------|
| mode | `PersonaRuntimeMode` | `local` | 复用 §3.2；对话无统计兜底 |
| temperature | `double` | 0.7 | 对话温度高于蒸馏（0.2），更自然 |
| maxNewTokens | `int` | 由模型能力 | 单次回复上限 |
| maxContextTurns | `int` | 由 `capabilities` 自适应 | 滑窗保留的最近轮数 |
| cloudAuthorized | `bool` | false | 云端对话授权门控 |

**`ChatDelta`**（流式增量）
| 字段 | 类型 | 说明 |
|------|------|------|
| textDelta | `String` | 本次增量 token 文本 |
| done | `bool` | 是否结束 |
| error | `RuntimeError?` | 分类错误（无模型/超限/未授权/取消）|

**`ChatSession`**（内存态，不落盘于本模块；持久化归模块 006/008）：`{persona, List<ChatTurn> history}`。

---

## 4. 接口设计

### 4.1 Runtime 抽象
```dart
enum RuntimeSource { liteRt, cloud, fallback }

abstract class PersonaRuntime {
  /// 模型是否就绪（本地：已下载；云端：已配置且已授权）。
  Future<bool> isAvailable();

  /// 声明上下文长度 / 能力上限，供分块决策。
  RuntimeCapabilities get capabilities;

  /// 一次性生成（蒸馏用）。云端实现须在内部校验授权；本地实现不发起网络。
  Future<RuntimeResult> generate(String prompt, {double temperature});

  /// 流式生成（对话用）。逐 token 产出；支持取消（关闭订阅）。
  Stream<String> generateStream(
    String prompt, {
    double temperature,
    int? maxNewTokens,
  });
}
```
- `LiteRtRuntime implements PersonaRuntime`（默认，封装 `flutter_gemma` 的 `getActiveModel/createChat/generate`，ADR-005）。
- `CloudRuntime implements PersonaRuntime`（opt-in，需 `cloudAuthorized`）。
- `FallbackRuntime`：不推理，触发统计兜底路径（返回 `source: fallback`）；**仅蒸馏可兜底，对话不可**。
- 测试用 `MockRuntime`：注入固定响应/固定 token 序列，实现确定性断言（含流式）。
- 模型加载：`LiteRtRuntime` 启动时经 `ModelRepository.getActiveModelHandle()` 取 `ModelHandle`，按其 `engine`（liteRtLm/mediaPipe）与 `backend`（gpuMetal/cpu）初始化 `flutter_gemma`。

### 4.2 Builder 接口
```dart
abstract class LlmPersonaBuilder {
  Future<Persona> build(
    Conversation conversation, {
    LlmBuildOptions options,
    PersonaRuntime runtime,
  });

  Future<Persona> update(
    Persona existing,
    Conversation newMessages, {
    LlmBuildOptions options,
    PersonaRuntime runtime,
  });
}
```
- 签名与语义对齐模块 003 `PersonaBuilder`，仅多注入 `runtime`。
- `update` 复用模块 003 去重/版本/`revisions`/硬规则不覆盖语义；LLM 仅重蒸馏受影响素材（SPEC 细化合并规则）。

### 4.2.5 ChatEngine 接口（对话引擎）
```dart
abstract class ChatEngine {
  /// 单轮对话：Persona + 历史 + 用户消息 → 流式回复。
  /// system prompt 只经现有 PromptTemplate.render(persona)。
  Stream<ChatDelta> chat(
    Persona persona,
    List<ChatTurn> history,
    String userMessage, {
    ChatOptions options,
    PersonaRuntime runtime,
  });
}
```
- **上下文组装**：`PromptTemplate.render(persona)`（system）+ 滑窗后的 `history` + `userMessage`；超 `capabilities.contextTokens` 时按 `maxContextTurns` 裁剪最旧轮次（保留 system + 新消息），记录裁剪、不静默丢失。
- **硬规则强制（HardRuleGuard）**：`persona.hardRules`（forbiddenTopics/mustNeverClaim/safetyNotes）注入 system prompt；对流式输出做后置校验，越界（如自称真人、触碰禁忌）→ 拦截/改写/安全兜底回复。
- **Runtime**：调用 `runtime.generateStream()`；默认本地无网络，云端需 `cloudAuthorized`。
- **无兜底**：无模型/最大隐私 → 发 `ChatDelta{error: modelUnavailable}`，不静默失败（统计法无法对话）。
- **取消**：调用方取消订阅即停止生成。
- 测试用 `MockRuntime` 注入固定 token 流做确定性断言（滑窗、硬规则、错误分类、取消）。

### 4.3 契约兼容策略（`Persona`/`PromptTemplate` 不破坏）
- 首选：真实例句/签名特征以现有字段承载——`TermStat`（catchphrases/termsForUser/comfort/concern）、`Memories.keyEvents`（例句摘要）、`Evidence`（消息键哈希 + ≤60 字素簇短示例）。
- 若确需新增承载字段：只加**可选字段**、保持 `PersonaJsonCodec` 往返与 `kPersonaSchemaVersion` 前向兼容（旧读新按未知忽略/新读旧按默认），并在 SPEC 记录；**不改现有字段语义、不改 `PromptTemplate` 输入形状**。
- `PromptTemplate.render()` 保持只读 `Persona` 字段；本模块不引入新的 render 契约。

### 4.4 提示词工程（PromptComposer）
- **Analyzer 阶段**（对齐 `persona_analyzer.md`）：抽取维度 = 表达风格 / 情感逻辑 / 关系行为 / 边界雷区；要求"有原文依据的结论引用原话、素材不足标注`（原材料不足）`"。
- **Builder 阶段**（对齐 `persona_builder.md`）：五层模板；Layer 0 用**具体行为规则**而非形容词；Layer 2 必含"你会怎么说"**真实例句**。
- **硬约束注入 prompt**：仅使用原文出现的事实；不得编造人名/地点/事件；低温度。
- 输出格式：约定可解析的分层结构（供 `DistillationParser`）；解析失败有重试/降级策略（SPEC §4）。

### 4.5 隐私与安全
- 本地路径：`LiteRtRuntime` 无网络；原文仅在内存与本地推理中。
- 云端路径：`CloudRuntime.generate` 前校验 `cloudAuthorized`；未授权抛 `RuntimeError.unauthorized`；API Key 经 Flutter Secure Storage。
- 溯源：沿用模块 003 message-key 哈希；`Evidence` 只存哈希 + 短示例；`.persona` 不落原文。
- 日志：不打印原文、prompt 全文、完整 Key。

---

## 5. 关键流程

### 5.1 生成（build）
1. 模块 003 预处理 + `splitBySender` → 目标人物消息。
2. 依 `mode`/可用性选择 Runtime；不可用 → 兜底。
3. 超长语料按 `capabilities` 分块 → 分块 analyzer → 汇总 builder。
4. `DistillationParser` 解析 → `DistilledPersona`。
5. `PersonaMapper` → `Persona`（五层 + tags + memories + `PersonaSource`，`personaVersion=1`）。
6. 素材不足层置 `confidence: low` + note。

### 5.2 兜底
无模型 / `maxPrivacy` / Runtime 连续失败 → 调用模块 003 统计 `PersonaBuilder.build`，产物标注统计来源/低置信。

### 5.3 增量（update）
1. 复用模块 003：按消息键哈希去重，全同 → 幂等（仅 version/revisions 语义）。
2. 有新素材 → 对新增/受影响素材重蒸馏 → 与既有 `Persona` 合并（SPEC 定义合并规则：聚合类字段合并、硬规则不覆盖、`revisions` 连续追加）。

### 5.4 对话（chat）
1. 校验模式/可用性：无模型或 `maxPrivacy` → `ChatDelta{error: modelUnavailable}`，结束。
2. `PromptTemplate.render(persona)` → system prompt；`HardRuleGuard` 追加硬规则约束。
3. 滑窗：`system + 最近 maxContextTurns 轮 + userMessage`；超 `capabilities.contextTokens` 则裁剪最旧轮，记录裁剪数。
4. `runtime.generateStream(prompt)` → 逐 token 发 `ChatDelta{textDelta}`。
5. 输出后置校验（HardRuleGuard）：越界则拦截/改写/安全兜底。
6. 结束发 `ChatDelta{done: true}`；订阅取消则中止生成。

---

## 6. 测试策略

### 6.1 单元测试（确定性部分，覆盖率 > 80%）
- `MockRuntime` 注入固定响应：断言 `DistillationParser` 解析、`PersonaMapper` 映射、契约往返（`PersonaJsonCodec`）、`PromptTemplate` 渲染。
- 隐私门控：云端未授权抛错、本地无网络；兜底路径产出合法 `Persona`。
- 增量语义：去重幂等、version 递增、硬规则不覆盖、`revisions` 连续。
- **ChatEngine**（`MockRuntime` 注入固定 token 流）：滑窗裁剪（超窗保留 system + 最近 N 轮）、硬规则注入 + 越界拦截、流式增量顺序/结束、错误分类（无模型/未授权/超限）、取消中止、system prompt 仅经 `PromptTemplate.render`。

### 6.1.5 真机/冒烟（ADR-005）
- 宿主/模拟器 CPU：SmolLM 135M 冒烟（能加载、能产出 token）。
- 真机 iPhone(iOS16+)：Gemma 3 1B 经 flutter_gemma 加载 + 蒸馏 + 对话；采样首 token/流式延迟/内存。

### 6.2 契约/结构断言（替代 byte-identical）
- 固定 prompt + 固定 mock 响应 → **结构快照**（层齐全、无 null 层、`schemaVersion` 正确、Evidence 为哈希）。
- 反例："不得编造事实"——原文不含某实体的合成语料，断言产物结构/关键词不出现该实体。

### 6.3 人工"像不像"评审
- 真实模型（本地/云端）对合成或授权语料生成 → ≥ 3 人主观评分；与模块 003 统计输出并列对比。

---

## 7. 性能指标
- 本地蒸馏：分档目标（低端设备/高端设备），基线对齐 CLAUDE.md「Persona 生成 ≤ 60s/1000 条」；首 token < 2s、> 5 tokens/s @ iPhone 15+。
- **本地对话**：首 token < 2s、流式增量延迟 < 500ms、> 5 tokens/s（真机；iOS Metal 具体吞吐以真机基线为准，不预设未实测数值，ADR-005）。
- 本地推理内存峰值 < 2GB。
- 云端：端到端分钟级（蒸馏）/秒级（对话），含分块与进度反馈。
- 分块：`maxChunkMessages` 依模型上下文长度自适应，保证不超上限、可汇总；对话滑窗依 `capabilities.contextTokens`。

---

## 8. 安全与合规
- 默认本地、云端显式授权、Key 加密、日志脱敏（对齐 CLAUDE.md 安全要求）。
- 原文不出设备（本地）；`.persona` 仅哈希 + 短示例。
- 开源可审计（CC BY-NC 4.0）。

---

## 9. 依赖与技术选型
| 依赖 | 用途 | 备注 |
|------|------|------|
| `flutter_gemma` v1.5.2（LiteRT-LM/MediaPipe）| 本地蒸馏 + 对话推理 | ADR-005；经 `LiteRtRuntime` 封装；模型由模块 007 提供 |
| 模块 007（模型管理）| `getActiveModelHandle()` → `ModelHandle` | 本地模型就绪（前置依赖）|
| 云端 API（OpenAI/Anthropic/Gemini）| opt-in 高质量蒸馏/对话 | 需授权 + Key 加密 |
| 模块 003（`crypto`/`characters` 等）| 预处理/契约/兜底 | 只读复用 |
| Flutter Secure Storage | 云端 Key | 对齐安全要求 |

---

## 10. 变更记录
| 日期 | 版本 | 变更内容 | 作者 |
|------|------|---------|------|
| 2026-08-02 | v1.0（草稿）| 初始草稿（依据 HANDOFF-004、ADR-004、模块 003 契约）| Claude |
| 2026-08-02 | v1.1（草稿）| 更名"LLM 集成"；新增 ChatEngine（数据结构 §3.5、接口 §4.2.5、流程 §5.4、测试 §6.1）+ 流式 Runtime；接入 flutter_gemma/模块 007（ADR-005）；文件重命名 | Claude |
| 2026-08-04 | v1.1.1（草稿）| PR #13 评审修订：删除 §7 未实测的 iOS Metal 吞吐数字（改为真机基线为准）；flutter_gemma 锁版本 v1.5.0→v1.5.2 | Claude |
| 2026-08-04 | v1.1.1（已批准）| ✅ Project Owner 批准三文档，进入 TDD 实现；DD-001（ModelHandle.filePath）随本模块设计定夺 | Project Owner |

---

> 本文档遵循 Lostone 项目的文档驱动开发规范。状态：✅ 已批准（Project Owner，2026-08-04），进入实现阶段。
