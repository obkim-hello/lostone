# ERD-007-模型管理

> 工程需求文档 - 模型管理（端侧 LLM 模型下载 / 存储 / 切换）
>
> **版本**：v1.0.1
> **状态**：📝 草稿
> **作者**：Claude
> **日期**：2026-08-02
> **优先级**：P0

---

## 📋 文档信息

| 项目 | 内容 |
|------|------|
| **ERD 编号** | ERD-007 |
| **模块名称** | 模型管理（Model Management）|
| **关联 PRD** | PRD-Model-Management-007-20260802.md |
| **关联 Spec** | SPEC-Model-Management-007-20260802.md |
| **依赖** | `flutter_gemma` v1.5.2（LiteRT-LM/MediaPipe）、Flutter Secure Storage |
| **关联决策** | ADR-002、ADR-004、ADR-005 |

---

## 1. 技术目标与约束

### 1.1 目标
- 以**薄封装**方式提供模型下载/存储/切换/查询，把 `flutter_gemma` 的下载与文件管理隔离在本模块内。
- 向模块 004 暴露稳定的 `ModelHandle` 与 `ModelRepository` 契约，屏蔽上游 API 变更。
- 提供确定性可测的状态机与元数据管理（宿主用 mock 下载器/文件系统）。

### 1.2 约束（ADR-005）
- **端侧栈固定** `flutter_gemma` v1.5.2（LiteRtLmEngine 默认，MediaPipeEngine 备）；不自造下载器/推理绑定。
- **iOS 16.0+**；`Runner.entitlements`（扩展虚拟寻址、放宽内存、`com.apple.security.cs.disable-library-validation`）、`Info.plist` `UIFileSharingEnabled`、Podfile `use_frameworks! :linkage => :static`。
- **模拟器仅 CPU、Metal 256MB** → 大模型不可运行；宿主/模拟器仅 SmolLM 135M 冒烟。
- 模型须**落盘内存映射**，不可 assets 流式；存于 app documents 目录。
- 本模块**不接触聊天原文**、不做推理。

---

## 2. 系统架构

### 2.1 分层
```
[模块 006 设置 UI (Phase 4)]  订阅进度/触发下载
        │
[模块 007 ModelRepository]  ← 本模块对外门面
   ├─ ModelCatalog       内置目录 + 元数据 + 设备推荐
   ├─ ModelInstaller     下载/安装（封装 flutter_gemma installModel builder API）
   ├─ ModelStore         已安装列表/占用/删除/落盘位置
   ├─ ActiveModelService 激活/切换/查询 → ModelHandle
   ├─ DeviceCapabilities GPU(Metal)/内存档/引擎选择
   └─ TokenStore         HF token（Flutter Secure Storage）
        │
[flutter_gemma v1.5.2]  installModel().fromNetwork().install() / getActiveModel()
        │
[模块 004 LiteRtRuntime]  getActiveModelHandle() → 加载 → 推理
```

### 2.2 与模块 004 的边界
- **007 = 模型就绪（provisioning）**：把模型弄到设备、校验、暴露 `ModelHandle`。
- **004 = 推理（inference）**：拿 `ModelHandle` 经 `flutter_gemma` 加载并生成。
- 契约点：`ModelRepository.getActiveModelHandle() → ModelHandle?`（null=不可用，触发 004 兜底）。

---

## 3. 数据结构

### 3.1 `ModelDescriptor`（目录条目）
| 字段 | 类型 | 说明 |
|------|------|------|
| id | `String` | 稳定标识（如 `gemma3-1b-it-int4`）|
| displayName | `String` | 展示名 |
| format | `ModelFormat` | `.litertlm` / `.task` |
| sizeBytes | `int` | 下载大小 |
| capabilities | `Set<ModelCapability>` | text / vision / functionCalling / thinking |
| minTier | `DeviceTier` | 推荐最低设备档 |
| sourceUrl | `String` | 下载地址 |
| requiresToken | `bool` | 是否需 HF token |
| sha256 | `String?` | 完整性校验（可选）|

内置目录（v1）：`smollm-135m`（冒烟/CPU）、`gemma3-1b-it-int4`（0.5GB，设备默认）、`gemma4-e2b`（2.4GB，高质量）。

### 3.2 `InstalledModel`
`{descriptor, filePath, installedBytes, state: ModelState, installedAt}`。

### 3.3 `ModelState`（状态机）
`notInstalled → downloading(progress) → verifying → ready`；`failed(error)`、`paused`、`deleting`。仅 `ready` 可被激活。

### 3.4 `ModelHandle`（对外契约，供模块 004）
| 字段 | 类型 | 说明 |
|------|------|------|
| id | `String` | 模型标识 |
| filePath | `String` | 落盘绝对路径（内存映射用）|
| format | `ModelFormat` | 引擎选择依据 |
| capabilities | `Set<ModelCapability>` | 能力 |
| backend | `InferenceBackend` | `gpu(metal)` / `cpu` |
| engine | `EngineKind` | `liteRtLm` / `mediaPipe` |

> ⚠️ **契约缺口：见 [DD-001](../overview/DESIGN-DEBT.md#dd-001)**。`flutter_gemma` v1.5.2 自管模型落盘并不暴露原始文件路径（推理经 `getActiveModel()` 拿模型对象而非 `filePath`）。本表 `filePath` 字段在生产路径下无法诚实兑现，**定于模块 004 设计时定夺**（改句柄语义 / 置空 + 走 `getActiveModel()`）。当前宿主实现用合成路径通过测试。

### 3.5 `DeviceTier` / `InferenceBackend`
`DeviceTier`：`simulatorCpu` / `lowEnd` / `midEnd` / `highEnd`。`InferenceBackend`：`gpuMetal` / `cpu`。

### 3.6 `InstallEvent`（进度流）
`{modelId, state, receivedBytes, totalBytes, error?}`；`Stream<InstallEvent>` 供 UI 订阅。

---

## 4. 接口设计

### 4.1 对外门面
```dart
abstract class ModelRepository {
  List<ModelDescriptor> catalog({DeviceTier? recommendFor});
  Future<List<InstalledModel>> installed();

  Stream<InstallEvent> install(String modelId, {String? hfToken});
  Future<void> cancel(String modelId);
  Future<void> delete(String modelId);

  Future<void> setActive(String modelId);      // 仅 ready 可激活
  Future<ModelHandle?> getActiveModelHandle();  // null = 无就绪模型（模块 004 兜底）
  ModelState stateOf(String modelId);
}
```

### 4.2 安装器（封装 flutter_gemma）
```dart
abstract class ModelInstaller {
  Stream<InstallEvent> install(ModelDescriptor d, {String? hfToken});
  Future<void> cancel(String modelId);
}
// 默认实现 FlutterGemmaInstaller：
//   FlutterGemma.installModel(modelType: ...).fromNetwork(d.sourceUrl).install()
//   进度经 installModel().withProgress(...) 回调 → InstallEvent
// 测试用 MockInstaller：注入进度/失败序列，确定性断言状态机。
```

### 4.3 存储与能力
```dart
abstract class ModelStore {              // 落盘位置/占用/删除；注入排除备份钩子(模块008)
  Future<String> pathFor(String modelId);
  Future<int> usedBytes();
  Future<void> remove(String modelId);
}
// ⚠️ 契约缺口：见 DD-002（../overview/DESIGN-DEBT.md#dd-002）。
//    空间预检所需的「可用磁盘余量」无 dart:io / 插件 API；生产 ModelStore
//    尚不能诚实实现 freeBytes()，仅 InMemoryModelStore 供宿主测试。
abstract class DeviceCapabilities {      // GPU/内存探测 + 引擎/后端选择
  DeviceTier tier();
  InferenceBackend preferredBackend();
  EngineKind preferredEngine(ModelFormat f);
  bool canRun(ModelDescriptor d);        // 超档/模拟器大模型 → false
}
```

### 4.4 依赖注入
所有外部副作用（`flutter_gemma`、文件系统、Secure Storage、能力探测）经接口注入，宿主测试全部可 mock；生产装配在 provider 层（Riverpod）。

---

## 5. 关键流程

### 5.1 下载→就绪
1. 校验 `modelId ∈ catalog`、设备 `canRun`（否则告警/需二次确认，故事 3）。
2. `requiresToken` 则取 `TokenStore` 的 HF token。
3. `ModelInstaller.install` 流式下载（断点续传）→ 发 `downloading` 进度。
4. 完成 → `verifying`（大小/可加载/可选 sha256）→ `ready`；失败 → `failed` + 清理半成品。

### 5.2 激活/消费
1. `setActive(modelId)`（仅 `ready`）。
2. 模块 004 `getActiveModelHandle()` → `ModelHandle`（含 path/backend/engine）。
3. 无 ready/未激活 → 返回 null → 模块 004 回退统计兜底（ADR-004）。

### 5.3 删除/切换
删除释放空间、更新状态；若删除激活模型 → 激活置空。切换即时改激活指针。

---

## 6. 测试策略
- **单元/契约（宿主，覆盖率 > 80%）**：`MockInstaller` + 内存文件系统 → 状态机全迁移（含 cancel/failed/resume）、进度事件、校验、删除、激活切换、`getActiveModelHandle` 契约（含 null）、`DeviceCapabilities.canRun` 分支（模拟器大模型=false）。
- **冒烟（宿主/模拟器 CPU）**：SmolLM 135M 真实"下载→ready→加载"最小链路。
- **真机（分阶段）**：iPhone(iOS16+) 下载 Gemma 3 1B、Metal 加载、加载耗时采样（配合模块 004 推理）。

---

## 7. 性能指标
- 模型加载 < 3s（分档：135M/1B/E2B 不同，真机 Metal 基线；对齐 CLAUDE.md）。
- 进度回调延迟 < 500ms；下载可断点续传。
- 元数据/状态查询 O(1)~O(n)，n=已安装模型数（小）。

---

## 8. 安全与合规
- 不接触聊天原文；仅下载用户发起的模型。
- HF token 经 Flutter Secure Storage；日志脱敏（无完整 token）。
- 模型文件位于 app 私有目录；加密/排除 iCloud 备份的钩子交模块 008（本模块预留注入点）。
- 下载来源受信任（目录内置 URL）；可选 sha256 校验防篡改/损坏。

---

## 9. 依赖与技术选型
| 依赖 | 用途 | 备注 |
|------|------|------|
| `flutter_gemma` v1.5.2 | 下载/存储/加载/推理底座 | ADR-005；锁版本、封装隔离 |
| Flutter Secure Storage | HF token | 受限模型 |
| path_provider | app 目录定位 | 落盘位置 |
| Hive/JSON（轻量）| 目录激活状态元数据 | 模块内自管 |

---

## 10. iOS/macOS 平台装配（ADR-005）
- iOS 16.0+；`Runner.entitlements`：扩展虚拟寻址 + 放宽内存上限 + `com.apple.security.cs.disable-library-validation`。
- `Info.plist`：`UIFileSharingEnabled`。
- Podfile：`use_frameworks! :linkage => :static`；GPU 需 OpenCL/Metal 配置。
- macOS Apple Silicon 同栈；模拟器 CPU + 仅冒烟模型。
- **平台装配 + 真机验证为分阶段项**（需设备），核心状态机/契约宿主先行 TDD。

---

## 11. 变更记录
| 日期 | 版本 | 变更 | 作者 |
|------|------|------|------|
| 2026-08-02 | v1.0（草稿）| 初始草稿（依据 ADR-005、PRD-007、模块 004 契约需求）| Claude |
| 2026-08-04 | v1.0.1（草稿）| PR #13 评审修订：封装对象由 legacy `ModelFileManager` 改为 builder API `installModel().fromNetwork().install()`；flutter_gemma 锁版本 v1.5.0→v1.5.2 | Claude |

---

> 本文档遵循 Lostone 文档驱动开发规范。当前为**草稿**，待三文档评审批准后方可进入实现阶段。
