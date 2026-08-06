# Lostone 开发路线图

> 本文档记录 Lostone 项目的详细开发计划、里程碑和进度追踪。

---

## 项目总览

**项目名称**：Lostone  
**启动日期**：2026年8月  
**当前阶段**：Phase 1 - 数据输入与解析（模块 002 开发中）；Phase 2 - Persona 生成引擎（模块 003 ✅ 已完成）；Phase 3 - LLM 集成（模块 007 模型管理[提前] + 模块 004 LLM 集成 ✅ 已完成，PR #14 merged 2026-08-05）；Phase 4 - UI 实现（模块 006 聊天界面 + 009 人物库与蒸馏 + 010 设置，9 文档草稿完成，待批准）  
**预计首个版本发布**：2026年11月（12周后）

---

## 阶段概览

| 阶段 | 名称 | 时间 | 状态 | 核心交付物 |
|------|------|------|------|-----------|
| Phase 0 | 项目初始化 | 第 1 周 | ✅ 完成 | 项目骨架、文档体系 |
| Phase 1 | 数据输入与解析 | 第 2-3 周 | 🟡 进行中 | 数据解析器、导入流程 |
| Phase 2 | Persona 生成引擎 | 第 4-5 周 | ✅ 完成（模块 003） | Persona Builder、五层模型 |
| Phase 3 | LLM 集成 | 第 6-7 周 | ✅ 完成（模块 007 + 004，PR #14） | 模型管理[提前]、LLM 蒸馏 + 对话引擎、flutter_gemma/LiteRT + 云端 Runtime |
| Phase 4 | UI 实现 | 第 8-9 周 | 🟡 进行中（模块 006/009/010 文档草稿） | 聊天界面 + SQLite 聊天历史、人物库与蒸馏、设置（模型管理 UI） |
| Phase 5 | 数据持久化与安全 | 第 10 周 | ⚪ 未开始 | 加密存储、生物识别 |
| Phase 6 | 测试与优化 | 第 11 周 | ⚪ 未开始 | 全面测试、性能优化 |
| Phase 7 | 发布准备 | 第 12 周 | ⚪ 未开始 | App Store 上线 |

**状态标识**：✅ 完成 | 🟡 进行中 | ⚪ 未开始 | ❌ 阻塞

---

## Phase 0: 项目初始化（第 1 周）

**目标**：搭建项目骨架，确立技术架构和文档体系

### 任务清单

#### 文档体系搭建
- [x] 创建项目总览文档
  - [x] README.md - 项目介绍
  - [x] VISION.md - 愿景与目标
  - [ ] ROADMAP.md - 开发路线图（本文档）
  - [ ] GLOSSARY.md - 术语表
- [ ] 创建架构设计文档
  - [ ] ARCHITECTURE.md - 系统架构
  - [ ] DATA-FLOW.md - 数据流设计
- [ ] 创建贡献指南
  - [ ] CONTRIBUTING.md - 贡献指南
  - [ ] CODE_OF_CONDUCT.md - 行为准则

#### PRD 文档编写
- [ ] PRD-TEMPLATE.md - PRD 模板
- [ ] PRD-001-Project-Setup.md - 项目初始化
- [ ] PRD-002-Data-Import.md - 数据导入模块

#### ERD 文档编写
- [ ] ERD-TEMPLATE.md - ERD 模板
- [ ] ERD-001-Flutter-Setup.md - Flutter 项目配置
- [ ] ERD-002-Data-Parsers.md - 数据解析器规格

#### Spec 文档编写
- [ ] SPEC-TEMPLATE.md - Spec 模板

#### 技术准备
- [ ] 创建 GitHub 仓库
- [ ] 配置开源许可（CC BY-NC 4.0）
- [ ] 配置开发环境
  - [ ] Flutter SDK 3.24+
  - [ ] iOS 开发者账号
  - [ ] Xcode 15+
- [ ] 初始化 Flutter 项目
- [ ] 配置项目结构

### 关键交付物
- ✅ 完整的文档体系结构
- 🟡 项目总览文档（4/4）
- ⚪ 核心 PRD 和 ERD 文档
- ⚪ Flutter 项目骨架

### 当前进度：60%

---

## Phase 1: 数据输入与解析（第 2-3 周）

**目标**：实现多源数据导入和解析

### 关键任务

#### Week 2: 文件选择与基础解析
- [ ] 实现文件选择器（支持 CSV、JSON、TXT）
- [ ] 开发数据预处理模块
  - [ ] 数据清洗（去除无效字符）
  - [ ] 去重逻辑
  - [ ] 时间排序
- [ ] 开发微信聊天记录解析器
  - [ ] 支持 CSV 格式
  - [ ] 支持 HTML 格式
  - [ ] 提取文本、图片、语音消息

#### Week 3: 扩展解析器
- [ ] 开发 iMessage 解析器
  - [ ] iOS 导出文件解析
  - [ ] macOS chat.db 解析
- [ ] 开发照片 EXIF 元数据提取
  - [ ] 提取拍摄时间
  - [ ] 提取地理位置（可选）
  - [ ] 生成时间线
- [ ] 开发社交媒体解析器
  - [ ] 微博 JSON 解析
  - [ ] Instagram JSON 解析
- [ ] 数据格式标准化

### 关键文件
- `mobile/lib/services/data_parser.dart`
- `persona-engine/src/parsers/wechat_parser.dart`
- `persona-engine/src/parsers/imessage_parser.dart`
- `persona-engine/src/parsers/photo_analyzer.dart`

### 验证标准
- [ ] 成功导入真实微信聊天记录（1000+ 条）
- [ ] 成功导入 iMessage 数据
- [ ] 输出结构化 JSON 格式
- [ ] 单元测试覆盖率 > 80%

### 交付物
- ⚪ 数据导入 UI 流程
- ⚪ 5+ 种数据源解析器
- ⚪ 数据格式规范文档

### 后续批次候选解析器（待排期，非 002 范围）
> 详见 PRD-Data-Import-002 §1.4 决策 2 的取舍依据。
- ⚪ **Android 短信（SMS Backup XML/CSV）** — 格式稳定、实现成本低、覆盖高，建议**下一批优先**
- ⚪ 豆瓣、小红书（社媒扩展）
- ⚪ PDF / 纯文本粘贴导入

---

## Phase 2: Persona 生成引擎（第 4-5 周）

**目标**：实现从聊天记录生成 Persona

> **文档状态（2026-08-02）**：模块 003 三文档已批准（v1.0.4），**TDD 实现完成（PR #11）**，开发状态 ✅ 已完成。
> - PRD：[PRD-Persona-Generation-003-20260802.md](../prd/PRD-Persona-Generation-003-20260802.md)
> - ERD：[ERD-Persona-Engine-003-20260802.md](../erd/ERD-Persona-Engine-003-20260802.md)
> - Spec：[SPEC-Persona-Builder-003-20260802.md](../spec/SPEC-Persona-Builder-003-20260802.md)
>
> **范围定案**：模块 003 为纯 Dart、离线、**无 LLM/无网络**的确定性五层 Persona 生成引擎（统计/规则法），输入锚定模块 002 `Conversation`。实测其产出偏单薄/易失真，**LLM 增强由 Phase 3 的模块 004 承接**（见 ADR-004）；模块 003 降级为预处理 + 离线兜底。

### 关键任务

#### Week 4: Persona 数据结构与分析器
- [ ] 设计 Persona 五层数据结构
  - [ ] Layer 1: 硬规则
  - [ ] Layer 2: 身份
  - [ ] Layer 3: 表达风格
  - [ ] Layer 4: 情感逻辑
  - [ ] Layer 5: 关系行为
- [ ] 实现记忆提取分析器
  - [ ] 时间线构建
  - [ ] 关键事件识别
  - [ ] 偏好习惯提取
- [ ] 设计 Persona 文件格式（JSON）

#### Week 5: 性格分析与 Persona Builder
- [ ] 实现性格分析器
  - [ ] 语言风格提取（口头禅、标点习惯）
  - [ ] 情感模式识别（依恋类型、吵架模式）
  - [ ] 标签生成（性格标签、恋爱模式）
- [ ] 实现 Persona Builder
  - [ ] 整合五层数据
  - [ ] 版本管理
  - [ ] 增量更新逻辑
- [ ] 实现 Prompt 模板系统

### 关键文件
- `persona-engine/src/analyzers/memories_analyzer.dart`
- `persona-engine/src/analyzers/persona_analyzer.dart`
- `persona-engine/src/builders/persona_builder.dart`
- `persona-engine/templates/`

### 验证标准
- [ ] 使用真实数据生成 Persona
- [ ] 人工检查生成质量（至少 3 人评审）
- [ ] Persona 文件可序列化和反序列化
- [ ] 支持版本回滚

### 交付物
- ⚪ Persona 数据模型
- ⚪ 记忆提取分析器
- ⚪ 性格分析器
- ⚪ Persona Builder

---

## Phase 3: 混合模型集成（第 6-7 周）

**目标**：实现本地模型 + 云端 API 混合推理

> **文档状态（2026-08-05 更新）**：Phase 3 含**两个模块**，三文档均**已批准**并 **✅ 已完成**（PR #14 merged to `main` 2026-08-05；host TDD 291 passing、`flutter analyze` clean、iOS on-device install verified；ADR-005 on-device quality validation pending, non-blocking）。原「模块 005 云端 API 集成」**已折叠并入模块 004** 的 Runtime 抽象层。
> - **模块 007（模型管理，提前至 Phase 3）**——作为模块 004 本地默认路径的**前置依赖**（无就绪模型则 004 无法真机验证）；薄封装 flutter_gemma 模型安装 builder API `installModel().fromNetwork().install()`（旧 `ModelFileManager` 为 legacy facade，ADR-005）：
>   - PRD：[PRD-Model-Management-007-20260802.md](../prd/PRD-Model-Management-007-20260802.md)
>   - ERD：[ERD-Model-Management-007-20260802.md](../erd/ERD-Model-Management-007-20260802.md)
>   - Spec：[SPEC-Model-Management-007-20260802.md](../spec/SPEC-Model-Management-007-20260802.md)
> - **模块 004（LLM 集成：蒸馏 + 对话引擎 + Runtime 抽象层，v1.1）**：
>   - PRD：[PRD-LLM-Integration-004-20260802.md](../prd/PRD-LLM-Integration-004-20260802.md)
>   - ERD：[ERD-LLM-Integration-004-20260802.md](../erd/ERD-LLM-Integration-004-20260802.md)
>   - Spec：[SPEC-LLM-Integration-004-20260802.md](../spec/SPEC-LLM-Integration-004-20260802.md)
>
> **范围定案（ADR-004 + ADR-005）**：模块 004 两大支柱——(A) **LLM 蒸馏**产出忠实五层人格，映射进模块 003 现有 `Persona` 契约（**输出契约不变**、不重写 003）；(B) **对话引擎 ChatEngine**——以 `Persona` 的 system prompt 驱动多轮流式对话（滑窗上下文、硬规则强制、本地/云端切换）。端侧栈定为 **flutter_gemma/LiteRT-LM**（ADR-005），模型就绪由模块 007 提供；默认本地、云端 opt-in；统计引擎（003）降级为预处理 + 离线兜底；测试由 byte-identical 改为契约/结构断言 + mock Runtime + 快照/人工评审 + 真机冒烟。开发者调试台（dev-only）供真机质量评审，正式聊天 UI 属模块 006。

### 关键任务

#### Week 6: 模型管理（模块 007）+ 本地推理底座
- [ ] 集成 **flutter_gemma**（LiteRT-LM/MediaPipe，ADR-005）
- [ ] 模型下载管理器（薄封装 `installModel().fromNetwork().install()` builder API，模块 007）
  - [ ] 从 Hugging Face 下载（HF token 经 Secure Storage）
  - [ ] 断点续传 + 进度流（`Stream<InstallEvent>`）
  - [ ] 校验 + 落盘（app documents，内存映射）
- [ ] ModelCatalog + 多模型切换（`ModelHandle` / `getActiveModelHandle()`）
  - [ ] SmolLM 135M（冒烟/CPU）
  - [ ] Gemma 3 1B（0.5GB，设备默认）
  - [ ] Gemma 4 E2B（2.4GB，高质量可选）
- [ ] 设备能力探测（Metal/内存档、引擎选择）+ iOS 装配（entitlements/静态链接）

#### Week 7: LLM 集成（模块 004）——蒸馏 + 对话引擎 + Runtime
- [ ] Runtime 抽象层（LiteRtRuntime[flutter_gemma] / CloudRuntime / FallbackRuntime + MockRuntime）
- [ ] LLM 蒸馏（PromptComposer analyzer/builder → DistilledPersona → PersonaMapper → `Persona`）
- [ ] 云端 API 客户端（OpenAI/Anthropic/Gemini，opt-in）+ API Key 安全存储（Secure Storage）
- [ ] 对话引擎（ChatEngine）
  - [ ] system prompt 经现有 `PromptTemplate.render()`（契约不变）
  - [ ] 上下文管理（滑动窗口）
  - [ ] 流式响应（`Stream<ChatDelta>`）+ 取消/错误分类
  - [ ] 聊天时硬规则强制（HardRuleGuard）
  - [ ] 统一接口（本地/云端）
- [ ] 隐私门控 + 统计兜底（仅蒸馏）+ 增量更新（复用模块 003 语义）
- [ ] 开发者调试台（dev-only）真机质量评审

### 关键文件
- `mobile/lib/services/model_manager.dart`
- `mobile/lib/services/cloud_api_service.dart`
- `mobile/lib/services/chat_engine.dart`
- `mobile/lib/models/ai_model.dart`

### 验证标准
- [ ] 本地模型加载速度 < 3 秒
- [ ] 本地模型推理速度 > 5 tokens/s（iPhone 15+）
- [ ] 云端 API 响应时间 < 2 秒
- [ ] 本地 ↔ 云端无缝切换
- [ ] 成本追踪误差 < 5%

### 交付物
- ⚪ 模型管理（模块 007：下载/存储/切换，flutter_gemma 封装）
- ⚪ flutter_gemma/LiteRT 集成（本地推理底座）
- ⚪ 云端 API 客户端
- ⚪ LLM 蒸馏（模块 004 支柱 A）
- ⚪ 对话引擎 ChatEngine（模块 004 支柱 B）
- ⚪ 成本追踪系统

---

## Phase 4: UI 实现（第 8-9 周）

**目标**：实现 Material Design 3 UI

> **文档状态（2026-08-05）**：Phase 4 UI **拆分为三个模块**，9 份三文档草稿已完成，均**待评审批准**（开发状态 🚫 阻塞）。聊天历史存储定为 **SQLite**。
> - **模块 006（聊天界面：对话 + 聊天历史）**——`ChatScreen` 消费模块 004 `ChatEngine` + 模块 007 激活模型 + 模块 009 `PersonaRepository`；新增 SQLite `ChatHistoryRepository`（本模块独有）：
>   - PRD：[PRD-Chat-Interface-006-20260805.md](../prd/PRD-Chat-Interface-006-20260805.md)
>   - ERD：[ERD-Chat-Interface-006-20260805.md](../erd/ERD-Chat-Interface-006-20260805.md)
>   - Spec：[SPEC-Chat-Interface-006-20260805.md](../spec/SPEC-Chat-Interface-006-20260805.md)
> - **模块 009（人物库与蒸馏）**——新增 `PersonaRepository`（Persona 持久化，填补"仅内存无落盘"缺口）+ 人物库屏 + 蒸馏流程屏驱动模块 004 `LlmPersonaBuilder`：
>   - PRD：[PRD-Persona-Library-009-20260805.md](../prd/PRD-Persona-Library-009-20260805.md)
>   - ERD：[ERD-Persona-Library-009-20260805.md](../erd/ERD-Persona-Library-009-20260805.md)
>   - Spec：[SPEC-Persona-Library-009-20260805.md](../spec/SPEC-Persona-Library-009-20260805.md)
> - **模块 010（设置）**——模块 007 模型管理正式 UI（取代 004 dev harness）+ 运行模式（`RuntimeChoice`）+ 云端授权：
>   - PRD：[PRD-Settings-010-20260805.md](../prd/PRD-Settings-010-20260805.md)
>   - ERD：[ERD-Settings-010-20260805.md](../erd/ERD-Settings-010-20260805.md)
>   - Spec：[SPEC-Settings-010-20260805.md](../spec/SPEC-Settings-010-20260805.md)
>
> **范围定案**：不重写模块 003/004/007（只读复用其契约）；持久化默认明文，模块 008 经注入接缝（`PersonaBytesTransform` / `DatabaseFactory` / `SecureKeyStore`）承接加密；system prompt 仍**仅**由 `PromptTemplate.render()` 产生（对话无统计兜底，对齐 004 SPEC §2.4）。

### 关键任务

#### Week 8: 核心页面
- [ ] 首页：Lost Ones 列表
  - [ ] 卡片式布局
  - [ ] 快速入口
  - [ ] 搜索和筛选
- [ ] Persona 创建向导
  - [ ] 步骤 1：基本信息（姓名、关系）
  - [ ] 步骤 2：数据导入
  - [ ] 步骤 3：性格标签选择
  - [ ] 步骤 4：预览与保存
- [ ] 聊天界面
  - [ ] 消息列表（气泡式布局）
  - [ ] 输入框（支持多行）
  - [ ] 多模态按钮（图片、语音）
  - [ ] 模型切换按钮

#### Week 9: 设置与细节
- [ ] 设置页
  - [ ] 模型管理 **UI**（消费模块 007 的 `ModelRepository` + `Stream<InstallEvent>`；下载/存储/切换逻辑已在 Phase 3 模块 007 落地）
    - [ ] 本地模型库界面（下载进度、删除、切换）
    - [ ] 云端 API 配置（输入 API Key）
    - [ ] 性能对比和推荐
  - [ ] 数据备份与导出
  - [ ] 隐私设置
  - [ ] 关于与开源许可
- [ ] UI 细节优化
  - [ ] 动画和过渡
  - [ ] 加载状态
  - [ ] 错误处理
  - [ ] 空状态设计

### 设计参考
- Google AI Edge Gallery 的 Material Design 3
- 柔和色调、圆角卡片、流畅动画

### 验证标准
- [ ] 所有页面可交互
- [ ] 响应式布局（iPhone + iPad）
- [ ] 无障碍访问支持
- [ ] 流畅度 > 60 FPS

### 交付物
- ⚪ 完整的 UI 界面
- ⚪ 响应式布局
- ⚪ 流畅的动画

---

## Phase 5: 数据持久化与安全（第 10 周）

**目标**：实现本地数据加密存储

### 关键任务
- [ ] SQLite 数据库设计
  - [ ] 聊天记录表
  - [ ] Persona 元数据表
  - [ ] 模型配置表
- [ ] Flutter Secure Storage 集成
  - [ ] API Key 加密存储
  - [ ] 用户凭证加密
- [ ] Face ID / Touch ID 解锁
  - [ ] 生物识别集成
  - [ ] 后台自动锁定
- [ ] 数据导出与备份功能
  - [ ] 导出为 JSON
  - [ ] iCloud 备份（可选）

### 验证标准
- [ ] 数据加密存储验证
- [ ] 生物识别解锁测试
- [ ] 数据导出完整性验证
- [ ] 渗透测试通过

---

## Phase 6: 测试与优化（第 11 周）

**目标**：全面测试，优化性能

### 关键任务
- [ ] 单元测试
  - [ ] Persona 生成逻辑
  - [ ] 数据解析器
  - [ ] 对话引擎
- [ ] Widget 测试
  - [ ] UI 组件测试
  - [ ] 交互流程测试
- [ ] 集成测试
  - [ ] 完整用户流程
  - [ ] 数据导入 → Persona 生成 → 对话
- [ ] 性能优化
  - [ ] 模型加载速度优化
  - [ ] 推理速度优化
  - [ ] 内存占用优化
- [ ] 真实用户测试
  - [ ] 邀请 5-10 人内测
  - [ ] 收集反馈
  - [ ] Bug 修复

### 验证标准
- [ ] 单元测试覆盖率 > 80%
- [ ] 所有集成测试通过
- [ ] 性能指标达标
- [ ] 用户满意度 > 4.0/5.0

---

## Phase 7: 发布准备（第 12 周）

**目标**：准备 App Store 发布

### 关键任务
- [ ] App Icon 设计
- [ ] App Store 截图与描述
  - [ ] 5 张截图（不同页面）
  - [ ] 应用描述文案
  - [ ] 关键词优化
- [ ] 隐私政策与用户协议
  - [ ] PRIVACY-POLICY.md
  - [ ] TERMS-OF-SERVICE.md
- [ ] TestFlight 内测
  - [ ] 发布到 TestFlight
  - [ ] 邀请内测用户
  - [ ] 收集反馈和崩溃日志
- [ ] Bug 修复
  - [ ] 修复关键 Bug
  - [ ] 优化性能
- [ ] 文档完善
  - [ ] README 更新
  - [ ] CHANGELOG.md 编写
  - [ ] RELEASE-NOTES.md 编写

### 验证标准
- [ ] App Store 审核通过
- [ ] 无严重 Bug
- [ ] 文档完整
- [ ] 隐私合规

---

## 里程碑追踪

### Milestone 1: 文档体系完成
**目标日期**：2026年8月第1周末  
**状态**：🟡 进行中  
**关键指标**：
- [ ] 4 个总览文档完成
- [ ] PRD 和 ERD 模板完成
- [ ] 至少 2 个核心 PRD 完成

### Milestone 2: 数据解析 MVP
**目标日期**：2026年8月第3周末  
**状态**：⚪ 未开始  
**关键指标**：
- [ ] 微信聊天记录解析成功
- [ ] iMessage 解析成功
- [ ] 数据格式标准化

### Milestone 3: Persona 生成 MVP
**目标日期**：2026年9月第5周末  
**状态**：⚪ 未开始  
**关键指标**：
- [ ] Persona 五层模型实现
- [ ] 使用真实数据生成 Persona
- [ ] 人工评审通过

### Milestone 4: 对话 MVP
**目标日期**：2026年9月第7周末  
**状态**：⚪ 未开始  
**关键指标**：
- [ ] 本地模型集成成功
- [ ] 云端 API 集成成功
- [ ] 对话流畅度达标

### Milestone 5: Beta 发布
**目标日期**：2026年10月第11周末  
**状态**：⚪ 未开始  
**关键指标**：
- [ ] TestFlight 发布
- [ ] 10+ 内测用户
- [ ] 无严重 Bug

### Milestone 6: 正式发布
**目标日期**：2026年11月第12周末  
**状态**：⚪ 未开始  
**关键指标**：
- [ ] App Store 上线
- [ ] 首批 100+ 用户
- [ ] App Store 评分 > 4.0

---

## 风险与应对

### 高风险项
| 风险 | 影响 | 概率 | 应对措施 | 状态 |
|------|------|------|---------|------|
| 模型大小影响下载转化率 | 高 | 中 | 提供小模型推荐，后台下载 | ⚪ 监控中 |
| Persona 质量不达标 | 高 | 中 | 手动调整功能，增量更新 | ⚪ 监控中 |
| App Store 审核延迟 | 中 | 低 | 提前准备合规文档 | ⚪ 监控中 |

### 中风险项
| 风险 | 影响 | 概率 | 应对措施 | 状态 |
|------|------|------|---------|------|
| 云端 API 成本超预期 | 中 | 中 | 实时追踪，设置预算上限 | ⚪ 监控中 |
| 用户隐私担忧 | 中 | 低 | 100% 本地，开源透明 | ⚪ 监控中 |
| 性能优化耗时 | 中 | 中 | 预留缓冲时间 | ⚪ 监控中 |

---

## 资源需求

### 人力资源
- **主力开发**：1 人（全职）
- **兼职支持**：UI 设计、测试（兼职）
- **外部顾问**：心理学专家（按需）

### 技术资源
- **开发设备**：MacBook Pro + iPhone 15+
- **云服务**：GitHub、Hugging Face（免费）
- **测试设备**：iPhone 15、iPhone 14、iPad

### 预算估算
- **开发工具**：$0（开源工具）
- **云服务**：$0（免费额度）
- **测试设备**：已有
- **营销推广**：$500（可选）
- ** contingency**：$500
- **总计**：约 $1000

---

## 更新日志

### 2026-08-05
- Phase 3（模块 007 模型管理 + 模块 004 LLM 集成）✅ 完成（PR #14 merged to `main`；host TDD 291 passing、analyze clean、iOS on-device install verified；ADR-005 on-device quality validation pending, non-blocking）
- **Phase 4 UI 拆分为三个模块**并出 9 份三文档草稿（待批准）：模块 006 聊天界面（对话 + **SQLite 聊天历史** `ChatHistoryRepository`）、模块 009 人物库与蒸馏（新增 `PersonaRepository` 持久化 + 库 + 蒸馏流程）、模块 010 设置（模型管理正式 UI + 运行模式 + 云端授权）；Phase 4 转「进行中（文档草稿）」。聊天历史存储定为 SQLite；不重写 003/004/007，008 经注入接缝承接加密

### 2026-08-02
- 同步实际进度：Phase 0 标记完成；Phase 1（数据导入/模块 002）转「进行中」；Phase 2（Persona 生成引擎/模块 003）三文档草稿就绪，标记「进行中（文档草稿）」，待批准
- Phase 2 补充模块 003 三文档链接与范围定案（纯 Dart、离线、无 LLM 的确定性五层引擎）
- 模块 003 三文档批准（v1.0.4）+ TDD 实现完成（PR #11），Phase 2 标记 ✅ 完成
- 新增模块 004（LLM Persona Builder，含 Runtime 抽象层）三文档草稿并归入 Phase 3；原模块 005（云端 API 集成）折叠并入 004；Phase 3 转「进行中（文档草稿）」，待批准（依据 ADR-004）
- 新增 ADR-005（端侧栈 flutter_gemma/LiteRT-LM）；**模块 007（模型管理）提前至 Phase 3** 并出三文档草稿（004 本地路径前置依赖，薄封装 flutter_gemma `ModelFileManager`）
- **模块 004 拓宽为「LLM 集成」**（文件重命名 LLM-Persona-Builder → LLM-Integration，三文档升 v1.1）：在蒸馏之外新增**对话引擎 ChatEngine**（滑窗上下文/流式/硬规则强制/本地云端切换）+ 开发者调试台（dev-only）；接入 flutter_gemma/模块 007；Phase 3 Week 6/7 任务清单重排为「模型管理 + 本地底座」→「LLM 集成」

### 2026-08-01
- 创建 ROADMAP.md
- 定义 7 个开发阶段
- 设置 6 个里程碑
- 规划风险应对措施

---

> 本路线图会根据实际进度动态调整，每周更新一次。