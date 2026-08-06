# SPEC-004-LLM 集成

> 技术规格 - LLM 集成（LLM 蒸馏人格 + 对话引擎，含 Runtime 抽象层）
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
| **Spec 编号** | SPEC-004 |
| **模块名称** | LLM 集成（蒸馏 + 对话引擎 + Runtime 抽象层）|
| **关联 PRD** | PRD-LLM-Integration-004-20260802.md |
| **关联 ERD** | ERD-LLM-Integration-004-20260802.md |
| **依赖模块** | 模块 002（数据导入）、模块 003（Persona 生成/契约）、模块 007（模型管理）|
| **关联决策** | ADR-002、ADR-004、ADR-005 |

---

## 1. 范围

规定 `LlmPersonaBuilder`、`ChatEngine` 与 `PersonaRuntime` 的输入输出契约、前后置条件、边界处理、测试用例与性能要求。**不涉及**正式聊天界面（006）、模型管理实现（007）、数据加密（008），也不改动模块 003 的 `Persona`/`PromptTemplate` 对外契约。本模块经模块 007 的 `getActiveModelHandle()` 消费已就绪模型（经 flutter_gemma 加载，ADR-005）。

---

## 2. 输入输出规格

### 2.1 `LlmPersonaBuilder.build`
**输入**
| 参数 | 类型 | 约束 |
|------|------|------|
| conversation | `Conversation` | 模块 002 产物；可空（空则走边界 §5.1）|
| options | `LlmBuildOptions` | 见 ERD §3.1；默认 `mode=local, temperature=0.2` |
| runtime | `PersonaRuntime` | 注入；测试可注入 `MockRuntime` |

**输出**：`Future<Persona>`（模块 003 契约）
- 五层齐全、无 null 层；`schemaVersion == kPersonaSchemaVersion`；`personaVersion == 1`（首次）。
- `id` = 模块 003 确定性派生（来源签名 SHA-256），与统计引擎对同一来源一致。
- `source.mergedMessageKeyHashes` 覆盖已消费素材；`source` 记录来源/消息数/`revisions[v1]`。
- 素材不足层 `confidence == Confidence.low` 且附 note；`generatedAt` 为 UTC。

### 2.2 `LlmPersonaBuilder.update`
**输入**：`existing: Persona`、`newMessages: Conversation`、`options`、`runtime`。
**输出**：`Future<Persona>`
- `id` 沿用 `existing.id`；`personaVersion == existing.personaVersion + 1`（有实质新增时）。
- `revisions` 连续追加一条（恒为 `[v1..vN]`）；`hardRules` **永不被覆盖**。
- 无新素材（键哈希全命中）→ 幂等：仅版本/修订语义，五层内容不变。

### 2.3 `PersonaRuntime.generate` / `generateStream`
**输入**：`prompt: String`、`temperature: double`（`generateStream` 另含 `maxNewTokens?`）。
**输出**：`generate` → `Future<RuntimeResult>{text, source, truncated, error?}`；`generateStream` → `Stream<String>`（逐 token）。
- 云端未授权 → `error == RuntimeError.unauthorized` / 流首帧错误，不发起请求。
- 本地不可用/失败 → 蒸馏交由 Builder 触发兜底（§5）；对话无兜底（§2.4）。
- `LiteRtRuntime` 经 `getActiveModelHandle()` 加载 flutter_gemma 模型；无 handle → 不可用。

### 2.4 `ChatEngine.chat`
**输入**
| 参数 | 类型 | 约束 |
|------|------|------|
| persona | `Persona` | 合法五层（模块 003/004 产物）|
| history | `List<ChatTurn>` | 可空（首轮为空）|
| userMessage | `String` | 非空（空则边界 §5.10）|
| options | `ChatOptions` | 见 ERD §3.5；默认 `mode=local, temperature=0.7` |
| runtime | `PersonaRuntime` | 注入；测试注入 `MockRuntime` |

**输出**：`Stream<ChatDelta>{textDelta, done, error?}`
- system prompt **仅**由 `PromptTemplate.render(persona)` 产生（契约不变）。
- 历史超上下文 → 滑窗保留 `system + 最近 maxContextTurns 轮 + userMessage`，裁剪最旧轮，记录裁剪数（不静默）。
- `persona.hardRules` 注入 system prompt 且对输出后置校验；越界（自称真人/禁忌话题）→ 拦截/改写/安全回复。
- 逐 token 发 `textDelta`；结束发 `done: true`；订阅取消 → 立即停止生成。
- 无模型 / `maxPrivacy` / 云端未授权 → 发 `error`（`modelUnavailable`/`unauthorized`），**不兜底、不静默失败**。

---

## 3. 前置条件

- 模块 002/003 可用；模块 003 预处理、`splitBySender`、`PersonaJsonCodec`、`PromptTemplate` 可只读调用。
- `mode==cloud` 时 `cloudAuthorized==true` 且 Key 已配置（Flutter Secure Storage）。
- `mode==local` 时对应模型已就绪（模块 007）；否则按边界降级。

---

## 4. 后置条件

- 返回值恒为**合法** `Persona`（契约完整），任何路径（LLM/兜底）皆然。
- `.persona` 持久化仅含消息键哈希与短示例，**不含原文**；日志无原文/无完整 Key/无 prompt 全文。
- LLM 输出解析失败且重试耗尽 → 走统计兜底，不抛未捕获异常给上层。
- 云端路径未授权时不产生任何网络调用。

---

## 5. 边界情况处理

| 编号 | 场景 | 处理 |
|------|------|------|
| 5.1 | 空会话 / 目标人物零消息 | 返回骨架 `Persona`：`identity.displayName` 回退默认，各层空 + `confidence.low`，不调用 LLM |
| 5.2 | 素材不足（某维度支撑 < 2 条）| 该层标 `原材料不足` note + `confidence.low`；**禁止**用模型先验补全 |
| 5.3 | 非文本消息（图片/语音/文件）| 计入总数、排除出蒸馏文本语料；不臆测其内容 |
| 5.4 | 超长语料（超模型上下文）| 按 `capabilities` 分块 → 分块 analyzer → 汇总 builder；`log` 记录分块数，不静默截断 |
| 5.5 | 切分不可判定 | 复用模块 003：`segmentationResolved=false`，各层 + identity 置 `confidence.low`，不臆断合并 |
| 5.6 | 本地模型缺失 / `maxPrivacy` | 统计兜底（模块 003），产物标注统计来源/低置信 |
| 5.7 | 云端未授权 / 网络失败 | 未授权：`RuntimeError.unauthorized`；失败可重试后降级兜底 |
| 5.8 | 模型输出不可解析 | 有限次重试（更严格格式指令）→ 仍失败则兜底 |
| 5.9 | 模型试图编造事实 | prompt 硬约束 + 解析后校验：结论须可追溯原文素材，否则丢弃该结论（见 §6 反例）|
| 5.10 | 空 `userMessage` | 不调用 runtime，发 `error(emptyInput)` 或 no-op；不产生空回复 |
| 5.11 | 对话历史超上下文窗口 | 滑窗裁剪最旧轮，保留 system + 最近 `maxContextTurns` + 新消息；记录裁剪数，不丢人格 |
| 5.12 | 对话时无模型 / `maxPrivacy` | 发 `ChatDelta{error: modelUnavailable}`；**不统计兜底**（统计法无法对话），提示先下载/激活模型（模块 007）|
| 5.13 | 对话时硬规则越界 | 输出后置校验：自称真人/触碰 `forbiddenTopics`/危险建议 → 拦截并改写为安全回复 |
| 5.14 | 生成中用户取消 | 取消订阅 → 立即停止生成，已发增量保留，不抛未捕获异常 |
| 5.15 | 对话云端未授权/网络失败 | 未授权 → `error(unauthorized)`，无网络调用；失败 → `error(network)`，不静默 |

---

## 6. 测试用例

> LLM 非确定性 → 确定性断言一律经 `MockRuntime` 注入固定响应；真实模型仅用于人工"像不像"评审。

| 编号 | 用例 | 断言 |
|------|------|------|
| T1 | build 正常语料（mock 响应）| 五层齐全、无 null、`schemaVersion/personaVersion=1`、`id` 与模块 003 一致 |
| T2 | 契约往返 | `PersonaJsonCodec` 编解码后相等；`PromptTemplate.render` 不抛错、含关键风格 |
| T3 | 空会话（5.1）| 返回骨架 Persona、未调用 runtime、各层 low |
| T4 | 素材不足（5.2）| 对应层含 `原材料不足` note + low |
| T5 | **不得编造事实**（5.9）| 合成语料**不含**实体 X；mock 响应**注入** X → 产物经校验后**不出现** X（无原文支撑的结论被丢弃）|
| T6 | 云端未授权（5.7）| `generate` 返回 `unauthorized`、无网络调用、Builder 走兜底 |
| T7 | 兜底路径（5.6）| `maxPrivacy` → 产物合法且标注统计来源/低置信 |
| T8 | 增量幂等（2.2）| 键哈希全命中 → 五层不变、仅版本/修订语义 |
| T9 | 增量硬规则不覆盖 | `update` 后 `existing.hardRules` 保留 |
| T10 | 分块（5.4）| 超长语料分块数 > 1、汇总产物合法、`log` 记录分块 |
| T11 | 非文本消息（5.3）| 计入 `totalMessages`、不进入蒸馏语料 |
| T12 | 隐私持久化 | `.persona` 不含原文、仅哈希 + 短示例 |
| T13 | 结构快照 | 固定 prompt + 固定 mock → 结构快照稳定（层齐全、Evidence 为哈希）|
| T14 | chat 正常流（mock token 流）| `chat` 逐 `ChatDelta{textDelta}` 顺序输出、末帧 `done`；system prompt == `PromptTemplate.render(persona)` |
| T15 | chat 滑窗（5.11）| 超窗历史 → 保留 system + 最近 `maxContextTurns` 轮 + 新消息；裁剪数被记录 |
| T16 | chat 硬规则强制（5.13）| mock 注入越界回复 → 被拦截/改写；`mustNeverClaim` 不出现 |
| T17 | chat 无模型（5.12）| `maxPrivacy`/无 handle → `error(modelUnavailable)`、无兜底、无网络 |
| T18 | chat 取消（5.14）| 取消订阅后无更多增量、无异常 |
| T19 | chat 云端未授权（5.15）| `error(unauthorized)`、无网络调用 |
| T20 | chat 空消息（5.10）| `error(emptyInput)`/no-op，不调用 runtime |
| T21 | SmolLM 冒烟（真机/CPU）| 真实模型经 flutter_gemma 加载 + 蒸馏 + 单轮对话产出 token（分阶段）|

---

## 7. 性能要求

| 指标 | 目标 |
|------|------|
| 本地蒸馏（1000 条）| 基线对齐 CLAUDE.md ≤ 60s；受设备/模型影响分档，超时反馈进度 |
| 本地对话首 token | < 2s（iPhone 15+，真机）|
| 本地对话流式增量延迟 | < 500ms |
| 本地推理速度 | > 5 tokens/s（iPhone 15+；iOS Metal 具体吞吐以真机基线为准，不预设未实测数值）|
| 本地内存峰值 | < 2GB |
| 云端端到端 | 蒸馏分钟级 / 对话秒级，含进度反馈 |
| 兜底（统计，仅蒸馏）| 对齐模块 003 性能指标 |

---

## 8. 依赖与契约引用
- 输入：模块 002 `Conversation`。
- 复用：模块 003 `Persona`/`persona_layers`/`PersonaJsonCodec`/`PromptTemplate`/预处理/`splitBySender`/统计兜底。
- 模型：模块 007 `ModelRepository.getActiveModelHandle()` → `ModelHandle`；经 `flutter_gemma`（LiteRT-LM/MediaPipe，ADR-005）加载。
- Runtime：LiteRT（本地）、云端 API（opt-in）；Key 经 Flutter Secure Storage。

---

## 9. 变更记录
| 日期 | 版本 | 变更内容 | 作者 |
|------|------|---------|------|
| 2026-08-02 | v1.0（草稿）| 初始草稿（依据 HANDOFF-004、ERD-004、模块 003 契约）| Claude |
| 2026-08-02 | v1.1（草稿）| 更名"LLM 集成"；新增 `ChatEngine.chat` I/O（§2.4）+ 流式 Runtime + 对话边界（§5.10–5.15）+ 对话用例（T14–T21）+ 对话性能；接入模块 007/flutter_gemma（ADR-005）；文件重命名 | Claude |
| 2026-08-04 | v1.1.1（草稿）| PR #13 评审修订：删除 §7 未实测的 iOS Metal 吞吐数字（改为真机基线为准）；flutter_gemma 锁版本 v1.5.0→v1.5.2 | Claude |
| 2026-08-04 | v1.1.1（已批准）| ✅ Project Owner 批准三文档，进入 TDD 实现；DD-001（ModelHandle.filePath）随本模块设计定夺 | Project Owner |

---

> 本文档遵循 Lostone 项目的文档驱动开发规范。状态：✅ 已批准（Project Owner，2026-08-04），进入实现阶段。
