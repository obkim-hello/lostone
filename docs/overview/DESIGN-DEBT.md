# 设计债务登记表（Design Debt Registry）

> 本文件登记**已知但尚未解决的设计缺口**——代码当前能编译/通过宿主测试，但契约与真实底座（如第三方 SDK）之间存在未定夺的假设。若不显式登记，后续开工相关模块时极易遗漏，变成"能跑但埋雷、出 bug 又找不到源头"的问题。
>
> **规则**：
> - 每条缺口给一个稳定编号 `DD-NNN`，记录：症状、为什么是隐患、何时/何地解决、关联文档。
> - 缺口被真正解决后，状态改为 `已解决` 并注明解决的提交/PR，不删除（保留追溯）。
> - 相关模块的 ERD/SPEC 应在对应契约处以 `⚠️ 契约缺口：见 DD-NNN` 反向链接到本表。

---

## DD-001 — `flutter_gemma` 自管存储与「激活模型」，`ModelHandle.filePath` 契约悬空

- **状态**：🟢 已定夺（2026-08-04，模块 004 设计时选定**选项 A**；代码落地随 `LiteRtRuntime`（设备 slice）一并进行，宿主抽象层不依赖 `filePath`）
- **发现**：2026-08-04，模块 007 设备/原生 slice 实现时读 `flutter_gemma` v1.5.2 源码。
- **关联**：ERD/SPEC-Model-Management-007 §3.4（`ModelHandle.filePath`）、§4.3（`ModelStore`）；ERD-LLM-Integration-004 §4.1（`LiteRtRuntime`）；ADR-005。

> **✅ 定夺（2026-08-04，模块 004 设计）**：采用**选项 A** —— `ModelHandle.filePath` 改为**可选**（`String?`，语义：仅当"我们自管下载"时有值，插件路径下为 `null`）；模块 004 的 `PersonaRuntime` 抽象层**完全不依赖** `filePath`，`LiteRtRuntime` 经 `flutter_gemma` 的 `getActiveModel()/createChat()/generate()` 加载与推理（ADR-005），只读 `ModelHandle` 的 `id/format/capabilities/backend/engine`。
> - **落地时机**：`ModelHandle.filePath: required String → String?` 的代码改动与 `LiteRtRuntime` 一同落在**模块 004 设备/原生 slice**（届时同步 007 的 `ModelHandle`/`DefaultModelRepository`/007 测试）。
> - **当前状态**：模块 004 宿主抽象层（`PersonaRuntime`/`MockRuntime`/`ChatEngine`/`LlmPersonaBuilder`）**不触碰 `filePath`**，故此定夺不阻塞宿主 TDD；007 现有宿主实现的合成 `filePath` 暂保留、不影响。

**症状**：
007 的对外契约假设**由我们**管理模型落盘，`getActiveModelHandle()` 返回一个「存在的、可内存映射的绝对文件路径」`filePath`，供模块 004 加载。但 `flutter_gemma` v1.5.2 的真实行为是：
- `FlutterGemma.installModel()...install()` 把模型下载到**插件私有位置**，并**自动置为 active**；
- 推理经 `FlutterGemma.getActiveModel()` 拿到一个**模型对象**，插件**不暴露原始文件路径**；
- 判断/管理经 `isModelInstalled(id)` / `uninstallModel(id)` / `listInstalledModels()`。

**为什么是隐患**：
按 ADR-005，模块 004 的 `LiteRtRuntime` 本就用 `getActiveModel/createChat/generate` 推理，**并不需要** `filePath`。但 007 的 SPEC §3「`filePath` 必为存在的可内存映射文件绝对路径」是一个**无法被生产实现诚实兑现**的承诺——生产版 `ModelRepository` 若硬造一个 `filePath` 就是编造。当前**宿主实现（`DefaultModelRepository` + `InMemoryModelStore`）用合成路径通过了测试**，掩盖了这个缺口。

**解决方向（待 004 设计确认，勿臆断）**：
- 选项 A：改 `ModelHandle` 去掉硬性 `filePath`，改为「插件持有句柄」语义（如仅保留 `id`/`format`/`capabilities`/`backend`/`engine`），004 经 `getActiveModel()` 加载；
- 选项 B：保留 `filePath` 但明确其仅在「我们自管下载」的路径下有效，插件路径下置空并由 004 走 `getActiveModel()`。
- 无论哪种：**生产版 `ModelRepository`** 应把 installed/active 状态委托给插件（`isModelInstalled`/`uninstallModel`/active spec），而非维护平行状态机；`DefaultModelRepository` 保留为**宿主测试参考实现 + 兜底簿记**。

---

## DD-002 — 磁盘余量预检（`ModelStore.freeBytes`）无宿主/`dart:io` API

- **状态**：🟡 待解决（随 DD-001 的生产 repository 一并定）
- **发现**：2026-08-04，同上。
- **关联**：SPEC-Model-Management-007 §2.2 / 边界 E2（空间不足预检）、ERD-007 §4.3。

**症状**：
E2「下载前预检磁盘空间不足 → `failed(insufficientStorage)`」在宿主用 `InMemoryModelStore(freeBytesBudget)` 可测，但**生产实现无从下手**：`dart:io` 不提供可用磁盘空间查询，`flutter_gemma`/`path_provider` 也不暴露。

**为什么是隐患**：
生产版若略过预检，E2 在真机上形同虚设（下载到磁盘写满才失败，体验差且可能留半成品）。

**解决方向**：
需引入磁盘空间查询能力（如 `disk_space_plus` 之类插件或平台通道），或依赖 `flutter_gemma` 下载器自身的空间/错误处理并把其错误归一到 `insufficientStorage`。定于生产 repository 接线时评估。

---

## DD-003 — 「原材料不足」层级 note 的承载字段（模块 003 `Persona` 加可选 `notes`）

- **状态**：🟢 已定夺（2026-08-04，模块 004 Slice 2 实现时）
- **发现**：2026-08-04，实现 `PersonaMapper` 时。
- **关联**：SPEC-LLM-Integration-004 §5.2 / T4（素材不足层 note）、ERD-004 §3.3（`insufficientLayers`）/§4.3（契约兼容：只加可选字段）；ADR-004（模块 003 只读复用）。

**症状**：
SPEC-004 §5.2 与 T4 要求「素材不足的层标 `原材料不足` note + `confidence.low`」。但模块 003 的层模型（`ExpressionStyle`/`EmotionalLogic`/`RelationalBehavior`/`Identity`）**均无 note 字段**，仅有 `confidence`。现有唯一的「说明类」字符串字段是 `HardRules.safetyNotes`。

**为什么是隐患**：
若把 note 塞进 `HardRules.safetyNotes`：(1) `PromptTemplate.render()` 会把它渲染进对话 system prompt（「约束：原材料不足…」），污染人格；(2) 增量 `update` 语义是「`hardRules` 永不覆盖」，会导致后续素材补足后旧的「原材料不足」note 永久残留（真 bug）。二者都不可接受。

> **✅ 定夺（2026-08-04）**：按 ERD-004 §4.3 的既定逃生舱「只加**可选**字段、保持 `PersonaJsonCodec` 往返与 `kPersonaSchemaVersion` 前向兼容」，在模块 003 `Persona` 上新增**可选** `List<String> notes`（默认 `const []`）：
> - 每次 `build`/`update` **重新计算**（不套用「永不覆盖」），故不会残留；
> - `PromptTemplate.render()` **不读取** `notes`，不进 system prompt，零渲染泄漏；
> - `PersonaJsonCodec` 编/解码 `notes`（缺省 → `[]`），旧 `.persona` 前向兼容；模块 003 既有 round-trip 测试（`decode(encode(p)) == p`，非 byte-identical）不受影响。
> - note 文案自述层名（如 `原材料不足：情感逻辑`），满足 T4「对应层含 note」。
> - **改动面**：仅 `mobile/lib/models/persona.dart`（字段 + `==`/`hashCode`）与 `mobile/lib/services/persona/persona_codec.dart`（encode/decode）；不改层模型、不改 `render()`、不改统计引擎逻辑。此为 ERD-004 §4.3 预授权的加性扩展，不违反 ADR-004「模块 003 不重写」。

---

## 已解决

（暂无）
