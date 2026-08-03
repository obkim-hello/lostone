# SPEC-004-LLM Persona Builder

> 技术规格 - LLM Persona Builder（LLM 蒸馏人格，含 Runtime 抽象层）
>
> **版本**：v1.0
> **状态**：📝 草稿
> **作者**：Claude
> **日期**：2026-08-02
> **优先级**：P0

---

## 📋 文档信息

| 项目 | 内容 |
|------|------|
| **Spec 编号** | SPEC-004 |
| **模块名称** | LLM Persona Builder |
| **关联 PRD** | PRD-LLM-Persona-Builder-004-20260802.md |
| **关联 ERD** | ERD-LLM-Persona-Builder-004-20260802.md |
| **依赖模块** | 模块 002（数据导入）、模块 003（Persona 生成/契约）|
| **关联决策** | ADR-002、ADR-004 |

---

## 1. 范围

规定 `LlmPersonaBuilder` 与 `PersonaRuntime` 的输入输出契约、前后置条件、边界处理、测试用例与性能要求。**不涉及**聊天界面（006）、模型管理（007）、数据加密（008），也不改动模块 003 的 `Persona`/`PromptTemplate` 对外契约。

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

### 2.3 `PersonaRuntime.generate`
**输入**：`prompt: String`、`temperature: double`。
**输出**：`Future<RuntimeResult>{text, source, truncated, error?}`。
- 云端未授权 → `error == RuntimeError.unauthorized`，不发起请求。
- 本地不可用/失败 → 交由 Builder 触发兜底（§5）。

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

---

## 7. 性能要求

| 指标 | 目标 |
|------|------|
| 本地蒸馏（1000 条）| 基线对齐 CLAUDE.md ≤ 60s；受设备/模型影响分档，超时反馈进度 |
| 本地首 token | < 2s（iPhone 15+）|
| 本地推理速度 | > 5 tokens/s（iPhone 15+）|
| 本地内存峰值 | < 2GB |
| 云端端到端 | 分钟级，含分块与进度反馈 |
| 兜底（统计）| 对齐模块 003 性能指标 |

---

## 8. 依赖与契约引用
- 输入：模块 002 `Conversation`。
- 复用：模块 003 `Persona`/`persona_layers`/`PersonaJsonCodec`/`PromptTemplate`/预处理/`splitBySender`/统计兜底。
- Runtime：LiteRT（本地）、云端 API（opt-in）；Key 经 Flutter Secure Storage。

---

## 9. 变更记录
| 日期 | 版本 | 变更内容 | 作者 |
|------|------|---------|------|
| 2026-08-02 | v1.0（草稿）| 初始草稿（依据 HANDOFF-004、ERD-004、模块 003 契约）| Claude |

---

> 本文档遵循 Lostone 项目的文档驱动开发规范。当前为**草稿**，待三文档评审批准后方可进入实现阶段。
