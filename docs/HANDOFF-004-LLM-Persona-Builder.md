# 交接单：模块 004 — LLM Persona Builder（LLM 蒸馏人格）

> **状态**：待执行。另一 Claude session 执行，本 session 仅 review。
> **范围**：仅写文档（ADR + 三文档），**不写实现代码**。三文档批准后才进入实现阶段。
> **创建**：2026-08-02

---

## 1. 背景与结论（为什么做这件事）

模块 003（纯 Dart、离线、确定性、无 LLM 的统计引擎）已实现（PR #11）。我们用一段真实微信语料（1124 条对方消息，confidence=high）做了实证对比：

- **统计引擎输出**（`/Users/qijinxu/Downloads/weflowexp 3/persona.json`）：只抓到表层词频（哈哈、不错、是的），且**捏造了情感特征**——"关心型/温柔安慰" 是对 "记得""没事" 这类词的无上下文命中；产出碎片噪音与无用的重复记忆（"提及生日 ×8"）。真人验证："does not feel like her at all"。
- **LLM 蒸馏输出**（`/Users/qijinxu/Downloads/weflowexp 3/persona_exskill.md`，参照 ex-skill 方法论）：抓到了她的签名特征（爱提问 "你呢""这在哪里"）、真实例句、生活背景（多伦多金融/wealth 组/3h 通勤/闺蜜），并诚实标注 "原材料不足"。明显更像本人。

**结论**：人格的关键信息在"词语在上下文中如何被使用"，只有 LLM 通读原始记录才能保留。统计词频无法编码性格，且会无中生有。

---

## 2. 决策（需落地为 ADR-004）

- **人格生成改为 LLM 蒸馏**（读原始消息 → 按五层模板产出 `persona.md` 风格的人格 + 真实例句）。
- **运行时：默认本地 LiteRT（隐私优先），云端 API 为显式 opt-in（质量优先）** —— 即 ADR-002 混合策略的落地。本地路径下**原始聊天不出设备**，与"100% 本地存储"不冲突；仅云端路径上传，且必须用户明确授权。
- **模块 003 统计引擎保留**，降级为**预处理 / 离线兜底**：去重、message-key 哈希、表层统计，以及"无可用模型 / 最大隐私模式"下的兜底人格。**不重写、不删除**；PR #11 按原样合并。

**目标管道**：
```
raw chat → [纯 Dart 预处理，模块 003] → [LLM 蒸馏：本地 LiteRT 或云端，模块 004] → persona.md/契约输出 → 聊天 LLM
```

---

## 3. 交付物清单（本次只交付文档）

### 3.1 ADR-004
- 写入 `CLAUDE.md` 的「架构决策记录（ADR）」章节（ADR 目前都内联在 CLAUDE.md 中，沿用该惯例）。
- 标题建议：`ADR-004：Persona 生成采用 LLM 蒸馏，统计引擎降级为预处理/离线兜底`。
- 内容：状态=已接受；背景（引用第 1 节实证结论）；决策（第 2 节）；理由；后果。
- 同时把 ADR-002 标注为本决策的上位混合策略依据（无需改写 ADR-002，只需在 ADR-004 中引用）。

### 3.2 模块 004 三文档（编号一致、日期=批准日）
放在对应目录，命名沿用现有惯例：
- `docs/prd/PRD-LLM-Persona-Builder-004-YYYYMMDD.md`（用 `docs/prd/PRD-TEMPLATE.md`）
- `docs/erd/ERD-LLM-Persona-Builder-004-YYYYMMDD.md`（用 `docs/erd/ERD-TEMPLATE.md`）
- `docs/spec/SPEC-LLM-Persona-Builder-004-YYYYMMDD.md`（用 `docs/spec/SPEC-TEMPLATE.md`）
（模块名三处必须一致；日期填批准日期，非草稿日期。）

### 3.3 状态同步（强制）
- 更新 `docs/DOCUMENT-STATUS.md`：新增模块 004 行，记录三文档状态/路径/齐全状态。
- 同步根目录 `README.md`：项目状态 + 模块文档表（PRD/ERD/Spec 链接与状态）。

---

## 4. 文档内容要点（写文档时必须覆盖）

**PRD-004 至少包含**：
- 目标：产出"读起来就像本人"的人格，取代统计人格作为送入聊天 LLM 的正式人格。
- 用户故事：用户导入聊天记录 → 选择本地/云端 → 得到可对话的人格；隐私模式默认本地。
- 功能清单：LLM 蒸馏、本地/云端可选、置信度/原材料不足的诚实标注、增量更新（对齐现有 update 语义）。
- 验收标准：见第 6 节；含"人格必须含真实例句、不得编造具体事实"。

**ERD-004 至少包含**：
- **输出契约不变**：复用现有 `Persona` 模型与 `PromptTemplate.render()`（`mobile/lib/services/persona/prompt_template.dart`）。LLM 蒸馏结果需能映射到现有五层结构（HardRules/Identity/ExpressionStyle/EmotionalLogic/RelationalBehavior + Memories + tags），使其在现有管道中即插即用。
- Runtime 抽象层：本地 LiteRT 与云端 API 统一接口（对齐 ADR-002）。
- 提示词工程：蒸馏的 prompt 方法论（参考 ex-skill 的 `persona_analyzer.md` 抽取维度 + `persona_builder.md` 五层模板与"你会怎么说"例句要求）。
- 隐私与安全：本地路径不出设备；云端需显式授权 + 不记录敏感信息；沿用 message-key 哈希做去重/溯源。
- 测试策略：确定性无法保证（LLM 有随机性），改为**基于契约/结构的断言 + 快照人工评审**，而非 byte-identical。

**SPEC-004 至少包含**：
- 输入输出规格（原始 `Conversation` → `Persona` / `persona.md`）。
- 前置/后置条件、边界（空语料、语料不足→"原材料不足"、非文本消息、超长语料分块）。
- 测试用例（含"不得编造事实"的反例校验）。
- 性能：对齐 CLAUDE.md「Persona 生成性能 < 60 秒（1000 条消息）」等指标，本地/云端分别给目标。

---

## 5. 硬约束（执行者必须遵守）

1. **本次只写文档，不写实现代码**（三文档齐全并批准是写码前置条件）。
2. **不提交任何代码注释**（全局规则；若最终写代码阶段也适用）。
3. **输出契约不变**：不改 `Persona` 模型对外形状与 `PromptTemplate` 契约，保证与模块 003 管道兼容。
4. **不重写/不删除模块 003** 统计引擎；它是预处理与离线兜底。
5. 遵守 `CLAUDE.md` 文档驱动流程、命名规范、三文档编号一致、状态实时更新。
6. 提交走 PR（合并 main 的唯一途径）；分支名建议 `feature/PRD-004-llm-persona-builder`。

---

## 6. 验收清单（review 时按此核对）

- [ ] ADR-004 已写入 CLAUDE.md，引用 ADR-002 与第 1 节实证结论。
- [ ] PRD/ERD/SPEC-004 三文档齐全、编号一致、模块名一致、日期为批准日。
- [ ] ERD 明确复用现有 `Persona` + `PromptTemplate` 契约，并给出五层映射方案。
- [ ] 隐私：本地默认、云端 opt-in、本地不出设备三点在 PRD/ERD 均有明确表述。
- [ ] 统计引擎（003）作为预处理/兜底的定位在文档中写清，未被删改。
- [ ] `docs/DOCUMENT-STATUS.md` 已更新（模块 004 行 + 齐全状态）。
- [ ] 根目录 `README.md` 已同步（项目状态 + 模块文档表）。
- [ ] 测试策略明确从"确定性 byte-identical"改为"契约断言 + 快照评审"。

---

## 7. 参考文件（执行者必读）

**实证对比产物（同一语料两种方法）**：
- 统计引擎输出：`/Users/qijinxu/Downloads/weflowexp 3/persona.json`、`persona_run.log`
- LLM 蒸馏输出：`/Users/qijinxu/Downloads/weflowexp 3/persona_exskill.md`

**ex-skill 方法论（LLM 蒸馏的模板与抽取维度）**：
- `.claude/skills/create-ex/prompts/persona_analyzer.md`（抽取维度、标签翻译规则）
- `.claude/skills/create-ex/prompts/persona_builder.md`（五层模板、Layer 0 具体规则而非形容词、Layer 2 "你会怎么说" 例句）
- `.claude/skills/create-ex/exes/example_xiaomei/persona.md`（完整范例）
- `.claude/skills/create-ex/exes/j1a-he/persona.md`（本项目语料生成的范例）

**现有代码（契约与五层结构，务必对齐）**：
- `mobile/lib/models/persona.dart`、`mobile/lib/models/persona_layers.dart`
- `mobile/lib/services/persona/prompt_template.dart`（`PromptTemplate.render()` 是送入下游 LLM 的唯一契约）
- `mobile/lib/services/persona/persona_builder.dart`、`persona_analyzer.dart`、`memories_analyzer.dart`、`text_stats.dart`、`persona_codec.dart`

**流程与模板**：
- `CLAUDE.md`（文档驱动流程、ADR 章节、命名/提交/PR 规范）
- `docs/prd/PRD-TEMPLATE.md`、`docs/erd/ERD-TEMPLATE.md`、`docs/spec/SPEC-TEMPLATE.md`
- `docs/DOCUMENT-STATUS.md`、根目录 `README.md`

---

## 8. 交回本 session（reviewer）

执行者完成后，请把以下交给本 session review：ADR-004 diff、三文档路径、DOCUMENT-STATUS.md 与 README.md 的 diff。本 session 按第 6 节验收清单逐项核对，不代写。
