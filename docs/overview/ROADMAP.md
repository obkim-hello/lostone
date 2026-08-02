# Lostone 开发路线图

> 本文档记录 Lostone 项目的详细开发计划、里程碑和进度追踪。

---

## 项目总览

**项目名称**：Lostone  
**启动日期**：2026年8月  
**当前阶段**：Phase 1 - 数据输入与解析（模块 002 开发中）；Phase 2 - Persona 生成引擎（模块 003 三文档草稿已就绪，待批准）  
**预计首个版本发布**：2026年11月（12周后）

---

## 阶段概览

| 阶段 | 名称 | 时间 | 状态 | 核心交付物 |
|------|------|------|------|-----------|
| Phase 0 | 项目初始化 | 第 1 周 | ✅ 完成 | 项目骨架、文档体系 |
| Phase 1 | 数据输入与解析 | 第 2-3 周 | 🟡 进行中 | 数据解析器、导入流程 |
| Phase 2 | Persona 生成引擎 | 第 4-5 周 | 🟡 进行中（文档草稿） | Persona Builder、五层模型 |
| Phase 3 | 混合模型集成 | 第 6-7 周 | ⚪ 未开始 | LiteRT 集成、云端 API |
| Phase 4 | UI 实现 | 第 8-9 周 | ⚪ 未开始 | Material Design UI |
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

> **文档状态（2026-08-02）**：模块 003 三文档草稿已就绪并交叉引用，**待评审批准**（开发状态 🚫 阻塞）。
> - PRD：[PRD-Persona-Generation-003-20260802.md](../prd/PRD-Persona-Generation-003-20260802.md)
> - ERD：[ERD-Persona-Engine-003-20260802.md](../erd/ERD-Persona-Engine-003-20260802.md)
> - Spec：[SPEC-Persona-Builder-003-20260802.md](../spec/SPEC-Persona-Builder-003-20260802.md)
>
> **范围定案**：模块 003 为纯 Dart、离线、**无 LLM/无网络**的确定性五层 Persona 生成引擎（统计/规则法），输入锚定模块 002 `Conversation`；LLM 增强留待 Phase 3 之后。下方任务清单据此细化。

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

### 关键任务

#### Week 6: 本地模型集成
- [ ] 集成 Google AI Edge LiteRT
- [ ] 实现模型下载管理器
  - [ ] 从 Hugging Face 下载
  - [ ] 断点续传支持
  - [ ] 下载进度显示
- [ ] 支持多模型切换
  - [ ] Gemma 4 (2B/4B/12B)
  - [ ] Llama 3.2 (1B/3B)
  - [ ] Qwen 2.5 (3B/7B)
  - [ ] Phi-3 (mini/small)
- [ ] Metal GPU 加速配置

#### Week 7: 云端 API 集成与对话引擎
- [ ] 云端 API 客户端
  - [ ] OpenAI API 客户端
  - [ ] Anthropic API 客户端
  - [ ] Google Gemini API 客户端
- [ ] API Key 安全存储
  - [ ] Flutter Secure Storage 集成
  - [ ] 加密存储 API Key
- [ ] 成本追踪系统
  - [ ] Token 使用量统计
  - [ ] 预估费用计算
  - [ ] 月度使用报告
- [ ] 对话引擎
  - [ ] Prompt 模板系统
  - [ ] 上下文管理（滑动窗口）
  - [ ] 流式响应
  - [ ] 统一接口（本地/云端）

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
- ⚪ LiteRT 集成
- ⚪ 云端 API 客户端
- ⚪ 对话引擎
- ⚪ 成本追踪系统

---

## Phase 4: UI 实现（第 8-9 周）

**目标**：实现 Material Design 3 UI

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
  - [ ] 模型管理
    - [ ] 本地模型库（下载、删除、切换）
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

### 2026-08-02
- 同步实际进度：Phase 0 标记完成；Phase 1（数据导入/模块 002）转「进行中」；Phase 2（Persona 生成引擎/模块 003）三文档草稿就绪，标记「进行中（文档草稿）」，待批准
- Phase 2 补充模块 003 三文档链接与范围定案（纯 Dart、离线、无 LLM 的确定性五层引擎）

### 2026-08-01
- 创建 ROADMAP.md
- 定义 7 个开发阶段
- 设置 6 个里程碑
- 规划风险应对措施

---

> 本路线图会根据实际进度动态调整，每周更新一次。