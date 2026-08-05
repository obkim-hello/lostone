# SPEC-007-模型管理

> 技术规格 - 模型管理（接口级输入输出、边界与测试用例）
>
> **版本**：v1.0.1
> **状态**：✅ 已批准（Project Owner，2026-08-04）
> **作者**：Claude
> **日期**：2026-08-02
> **优先级**：P0

---

## 📋 文档信息

| 项目 | 内容 |
|------|------|
| **Spec 编号** | SPEC-007 |
| **模块名称** | 模型管理（Model Management）|
| **关联 PRD** | PRD-Model-Management-007-20260802.md |
| **关联 ERD** | ERD-Model-Management-007-20260802.md |
| **关联决策** | ADR-002、ADR-004、ADR-005 |

---

## 1. 范围

规定 `ModelRepository` 门面及其协作者（`ModelInstaller`/`ModelStore`/`DeviceCapabilities`/`TokenStore`）的输入输出、前后置条件、边界与测试用例。**不含**推理/聊天（模块 004）、模型管理 UI（Phase 4）、加密（模块 008）。

---

## 2. 接口规格

### 2.1 `catalog({DeviceTier? recommendFor}) → List<ModelDescriptor>`
- **输入**：可选设备档。
- **输出**：内置目录；给定 `recommendFor` 时按 `canRun` 与 `minTier` 排序/标注推荐。
- **前置**：无。**后置**：返回非空（至少含 SmolLM/Gemma3-1B/Gemma4-E2B）；不产生副作用。

### 2.2 `install(String modelId, {String? hfToken}) → Stream<InstallEvent>`
- **输入**：目录内 `modelId`；受限模型需 `hfToken`（或已存于 `TokenStore`）。
- **输出**：进度事件流 `downloading → verifying → ready`（或 `failed`）。
- **前置**：`modelId ∈ catalog`；磁盘空间充足；（大模型）`canRun` 或用户已确认。
- **后置**：成功后 `stateOf==ready` 且文件落盘；失败清理半成品且 `stateOf==failed`。

### 2.3 `cancel(String modelId) → Future<void>`
- **前置**：该模型处于 `downloading`。**后置**：停止下载、清理半成品、`stateOf==notInstalled`。

### 2.4 `delete(String modelId) → Future<void>`
- **前置**：`installed` 含该模型。**后置**：文件删除、占用回收；若为激活模型则激活置空。幂等（不存在时 no-op）。

### 2.5 `setActive(String modelId) → Future<void>`
- **前置**：`stateOf==ready`。**后置**：该模型成为激活模型。
- **异常**：非 ready → `StateError`。

### 2.6 `getActiveModelHandle() → Future<ModelHandle?>`
- **输出**：激活模型的 `ModelHandle`（path/format/capabilities/backend/engine）；无激活/无 ready → `null`。
- **后置**：不加载模型、不推理；纯元数据 + 路径 + 引擎决策。

### 2.7 `installed() / stateOf(modelId)`
- `installed()`：已安装模型快照。`stateOf`：查询状态；未知模型 → `notInstalled`。

---

## 3. `ModelHandle` 契约（供模块 004）
- `filePath` 必为存在的可内存映射文件绝对路径。
- `backend` 依 `DeviceCapabilities.preferredBackend()`：真机默认 `gpuMetal`，模拟器/无 GPU → `cpu`。
- `engine` 依 `preferredEngine(format)`：`.litertlm`→`liteRtLm`；`.task`→`mediaPipe`。
- 模块 004 只读消费，不得改写。

---

## 4. 边界情况

| 编号 | 场景 | 处理 |
|------|------|------|
| E1 | `modelId` 不在目录 | `install` 立即发 `failed(unknownModel)`；`ArgumentError` |
| E2 | 磁盘空间不足 | 下载前预检 → `failed(insufficientStorage)`，不产生半成品 |
| E3 | 网络中断 | `failed(network)`；保留断点，`install` 再调可续传 |
| E4 | 受限模型缺 token | `failed(authRequired)`；提示配置 HF token |
| E5 | 下载中途 `cancel` | 停止 + 清理 → `notInstalled` |
| E6 | 校验失败（大小/sha256/不可加载）| 删除文件 → `failed(corrupted)` |
| E7 | 模拟器/超档设备装大模型 | `canRun==false`；默认拒绝并告警，需显式确认才继续 |
| E8 | 删除激活模型 | 激活置空；`getActiveModelHandle` 返回 null → 模块 004 兜底 |
| E9 | 重复 `install` 已 ready 模型 | no-op，直接发 `ready` |
| E10 | 无任何 ready 模型 | `getActiveModelHandle==null`（模块 004 走统计兜底，ADR-004）|
| E11 | 并发 `install` 同一模型 | 二次调用复用进行中的下载流，不重复下载 |

---

## 5. 测试用例

| 编号 | 名称 | 类型 | 断言要点 |
|------|------|------|----------|
| T1 | 目录非空且含默认模型 | 单元 | `catalog` 含 SmolLM/Gemma3-1B/Gemma4-E2B |
| T2 | 推荐排序 | 单元 | `recommendFor: highEnd` 优先 E2B；`simulatorCpu` 仅 SmolLM 可运行 |
| T3 | 下载状态机（happy path）| 单元(mock) | 事件序列 `downloading*→verifying→ready`，末态 ready |
| T4 | 进度单调递增 | 单元(mock) | `receivedBytes` 非递减，末值==`totalBytes` |
| T5 | 取消清理 | 单元(mock) | `cancel` 后末态 notInstalled，无残留文件 |
| T6 | 下载失败清理 | 单元(mock) | 注入网络错误 → `failed`，无半成品 |
| T7 | 断点续传 | 单元(mock) | 中断后再 `install` 从断点继续，最终 ready |
| T8 | 校验失败 | 单元(mock) | 大小/sha256 不符 → `failed(corrupted)`，文件删除 |
| T9 | 空间不足预检 | 单元(mock) | `failed(insufficientStorage)`，不下载 |
| T10 | 受限模型缺 token | 单元(mock) | `failed(authRequired)` |
| T11 | setActive 仅 ready | 单元 | 非 ready → `StateError`；ready → 成功 |
| T12 | getActiveModelHandle 契约 | 单元 | 返回 handle 字段完整；无 ready → null |
| T13 | 删除激活模型 | 单元 | 删除后 `getActiveModelHandle==null` |
| T14 | 引擎/后端选择 | 单元 | `.litertlm→liteRtLm`；模拟器→cpu，真机→gpuMetal |
| T15 | canRun 分支 | 单元 | 模拟器大模型 false；高端设备 E2B true |
| T16 | 重复 install 幂等 | 单元 | 已 ready 再 install → 直接 ready，无重复下载 |
| T17 | 并发 install 去重 | 单元 | 同模型并发 → 复用同一下载流 |
| T18 | SmolLM 冒烟 | 冒烟(宿主/CPU) | 真实下载→ready→可加载最小链路 |
| T19 | 真机 Gemma3-1B | 真机(分阶段) | iPhone 下载 + Metal 加载 < 3s（配合模块 004）|

**覆盖率目标**：宿主单元/契约 > 80%（T1–T17）。T18 冒烟、T19 真机为分阶段项。

---

## 6. 性能要求
- 模型加载 < 3s（真机 Metal 基线，分档 135M/1B/E2B；对齐 CLAUDE.md）。
- 进度回调延迟 < 500ms；下载支持断点续传。
- 目录/状态查询即时（内存元数据）。

---

## 7. 安全要求
- 不接触聊天原文；HF token 经 Flutter Secure Storage，日志脱敏。
- 模型落 app 私有目录；加密/排除备份钩子交模块 008（预留注入点）。
- 校验下载完整性（大小 + 可选 sha256）防损坏/篡改。

---

## 8. 变更记录
| 日期 | 版本 | 变更 | 作者 |
|------|------|------|------|
| 2026-08-02 | v1.0（草稿）| 初始草稿（依据 PRD-007、ERD-007、ADR-005）| Claude |
| 2026-08-04 | v1.0.1（草稿）| PR #13 评审修订：flutter_gemma 锁版本 v1.5.0→v1.5.2；封装对齐 builder API（legacy `ModelFileManager` facade）| Claude |
| 2026-08-04 | v1.0.1（已批准）| ✅ Project Owner 批准三文档；宿主核心 + 设备 slice 已落地；DD-002 记于设计债务登记表 | Project Owner |

---

> 本文档遵循 Lostone 文档驱动开发规范。状态：✅ 已批准（Project Owner，2026-08-04），进入实现阶段。
