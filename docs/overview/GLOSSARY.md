# Lostone 术语表

> 本文档定义 Lostone 项目中使用的所有特定术语、技术术语和业务术语，确保团队成员和贡献者对概念有统一的理解。

---

## 📖 使用说明

- **项目特定术语**：Lostone 项目中独创或重新定义的术语
- **技术术语**：技术栈、框架、工具相关的专业术语
- **业务术语**：产品设计、用户体验相关的业务概念

---

## 🎯 项目特定术语

### Lost One
**定义**：用户创建的逝去亲人/朋友/爱人的 AI Persona 实例。

**示例**：
> "我创建了一个 Lost One 来纪念我的奶奶。"

**相关术语**：Persona、AI Persona

---

### Persona
**定义**：从聊天记录等数据中提取并构建的人物性格模型，包含五层结构。

**五层结构**：
1. **硬规则（Hard Rules）**：不会说的话、绝对禁忌
2. **身份（Identity）**：姓名、关系、时间段、角色定位
3. **表达风格（Expression Style）**：口头禅、常用表情、标点习惯
4. **情感逻辑（Emotional Logic）**：情感表达方式、依恋类型、吵架模式
5. **关系行为（Relational Behavior）**：日常仪式、共同回忆、偏好习惯

**来源**：借鉴自 ex-skill 项目

**文件格式**：`.persona` (JSON 格式)

**相关术语**：Lost One、Memories

---

### Memories（共同记忆）
**定义**：从聊天记录中提取的关系时间线、关键事件、偏好习惯等共同经历。

**内容**：
- 关系时间线（相识、重要事件）
- 日常仪式（每天的问候、周末活动）
- 偏好习惯（喜欢去哪吃饭、爱看的电影）

**作用**：为 AI 提供上下文，让对话更真实

**相关术语**：Persona

---

### Persona 生成
**定义**：从聊天记录等数据中自动创建 Persona 的过程。

**流程**：
```
数据导入 → 数据预处理 → 记忆提取 → 性格分析 → Persona Builder → .persona 文件
```

**相关术语**：Persona Builder、增量更新

---

### Persona Builder
**定义**：负责生成和更新 Persona 的引擎模块。

**功能**：
- 整合五层数据
- 版本管理
- 增量更新
- 对话纠正

**相关术语**：Persona 生成

---

### 增量更新
**定义**：追加新的聊天记录到现有 Persona，不覆盖已有结论。

**示例**：
> 用户导入了去年的聊天记录生成了 Persona，现在又导入了今年的记录，系统会 merge 进现有 Persona，而不是重新生成。

**相关术语**：Persona 生成

---

### 对话纠正
**定义**：用户指出 AI 回复不符合 Persona 特征，系统记录并调整。

**示例**：
> 用户说"她不会这样，她应该是 xxx"，系统会写入 Correction 层，立即生效。

**相关术语**：Persona、Correction 层

---

### Correction 层
**定义**：Persona 中的一个特殊层，记录用户手动纠正的内容。

**优先级**：高于自动生成的其他层

**相关术语**：对话纠正

---

### 混合模型策略
**定义**：同时支持本地模型和云端 API，用户可以自由选择和切换。

**本地模型**：
- 优点：隐私保护、完全离线、无成本
- 缺点：性能受限、质量略低

**云端 API**：
- 优点：高质量、快速响应、多功能
- 缺点：需要网络、有成本、隐私考量

**相关术语**：本地模型、云端 API

---

### 模型市场
**定义**：应用内的本地模型下载和管理界面。

**功能**：
- 浏览开源模型（Gemma 4、Llama 3.2 等）
- 查看模型大小、性能指标
- 一键下载和切换
- 性能基准测试

**相关术语**：本地模型

---

## 💻 技术术语

### Flutter
**定义**：Google 开发的跨平台 UI 框架。

**用途**：Lostone 的移动端开发框架

**官网**：https://flutter.dev

---

### LiteRT
**定义**：Google AI Edge 提供的轻量级 AI 模型推理引擎。

**用途**：在移动设备上运行大型语言模型

**特点**：
- 优化设备端推理
- 支持 Metal (iOS/macOS) 加速
- 量化模型支持

**官网**：https://ai.google.dev/edge/litert

---

### Metal
**定义**：Apple 开发的图形和计算 API。

**用途**：加速 iOS/macOS 上的 AI 模型推理

---

### Spec-Driven Development
**定义**：先编写技术规格（Spec），再编写实现代码的开发方法。

**流程**：
```
需求分析 → 编写 Spec → 编写测试用例 → 实现代码 → 验证通过
```

**优点**：
- 明确接口定义
- 减少返工
- 提高代码质量

**相关术语**：PRD、ERD、Spec

---

### PRD (Product Requirement Document)
**定义**：产品需求文档，从产品视角描述功能需求。

**结构**：
1. 背景
2. 目标
3. 用户故事
4. 功能清单
5. 验收标准
6. 优先级
7. 依赖关系

**相关术语**：ERD、Spec

---

### ERD (Engineering Requirement Document)
**定义**：工程需求文档，从工程视角描述技术实现。

**结构**：
1. 技术目标
2. 设计约束
3. 数据结构
4. 接口设计
5. 实现细节
6. 测试策略
7. 性能指标

**相关术语**：PRD、Spec

---

### Spec (Technical Specification)
**定义**：技术规格文档，模块接口级别的详细定义。

**内容**：
- 输入输出规格
- 前置条件
- 后置条件
- 边界情况
- 测试用例
- 性能要求

**相关术语**：Spec-Driven Development

---

### Riverpod
**定义**：Flutter 的状态管理库。

**用途**：Lostone 的状态管理方案

**特点**：
- 类型安全
- 易于测试
- 响应式

**官网**：https://riverpod.dev

---

### Hive
**定义**：Flutter 的轻量级键值存储库。

**用途**：存储应用设置、缓存等

**特点**：
- 快速
- 无需原生依赖
- 支持加密

---

### Flutter Secure Storage
**定义**：Flutter 的安全存储库。

**用途**：加密存储 API Key、用户凭证等敏感数据

**特点**：
- 使用 Keychain (iOS) / KeyStore (Android)
- AES 加密

---

### Hugging Face
**定义**：开源 AI 模型和数据集社区平台。

**用途**：下载开源本地模型

**官网**：https://huggingface.co

---

### Token
**定义**：文本的最小单位，AI 模型处理文本时使用的单位。

**说明**：
- 英文：1 token ≈ 4 characters
- 中文：1 token ≈ 1-2 characters

**用途**：计算 API 使用成本

---

### 流式响应
**定义**：AI 模型逐步生成文本并实时返回，而非等待完整生成。

**优点**：
- 减少等待时间
- 更自然的交互体验

---

### 量化模型
**定义**：通过降低参数精度来减小模型大小和提升推理速度。

**常见量化级别**：
- FP16 (16-bit)
- INT8 (8-bit)
- INT4 (4-bit)

**示例**：Gemma 4B 量化版 ≈ 2-3GB

---

## 🧠 业务术语

### 依恋类型
**定义**：心理学中的依恋理论，描述个体在亲密关系中的行为模式。

**四种类型**：
1. **安全型（Secure）**：信任、舒适、易于亲近
2. **焦虑型（Anxious）**：担心被抛弃、需要频繁确认
3. **回避型（Avoidant）**：保持距离、害怕依赖
4. **混乱型（Disorganized）**：矛盾、不稳定

**用途**：Persona 情感逻辑层的一部分

---

### 吵架模式
**定义**：个体在冲突中的典型反应方式。

**常见模式**：
- **冷战派**：不说话、回避
- **爆发派**：情绪激烈表达
- **讲道理派**：理性分析、逻辑优先
- **先道歉型**：主动和解
- **死不认错**：固执、不妥协

**用途**：Persona 情感逻辑层的一部分

---

### 爱的表达方式
**定义**：Gary Chapman 提出的"爱的五种语言"。

**五种方式**：
1. **言语肯定（Words of Affirmation）**：赞美、鼓励
2. **服务行为（Acts of Service）**：帮忙做事
3. **送礼物（Receiving Gifts）**：物质表达
4. **肢体接触（Physical Touch）**：拥抱、牵手
5. **高质量陪伴（Quality Time）**：共度时光

**用途**：Persona 情感逻辑层的一部分

---

### 硬规则
**定义**：Persona 中绝对不会违反的规则。

**示例**：
- 不会说的话（如脏话、特定词汇）
- 绝对禁忌（如某些话题）
- 敏感话题回避

**用途**：Persona 第一层，最高优先级

---

### 表达风格
**定义**：个体的语言使用习惯和特征。

**包含**：
- 口头禅（如"哈哈"、"其实"）
- 常用表情（如😊、"笑死"）
- 标点习惯（如喜欢用！！！）
- 语气词（如"嘛"、"呢"）

**用途**：Persona 第三层

---

### 数字遗产
**定义**：个人去世后留下的数字内容和账户。

**包括**：
- 社交媒体账户
- 聊天记录
- 照片和视频
- 电子邮件
- 数字资产

**Lostone 的定位**：帮助用户管理和延续数字遗产中的情感价值

---

### 情感连接
**定义**：人与人之间的情感纽带和依赖关系。

**在 Lostone 中**：
- 通过 AI Persona 延续情感连接
- 不是替代真实关系，而是保存记忆

---

### 隐私优先设计
**定义**：以隐私保护为首要设计原则的产品开发方法。

**核心原则**：
- 数据最小化
- 本地优先
- 用户掌控
- 透明可控

**Lostone 的实践**：
- 100% 本地存储
- 开源代码审计
- 无需注册账号
- 数据导出自由

---

## 🔤 缩写和简写

| 缩写 | 全称 | 说明 |
|------|------|------|
| AI | Artificial Intelligence | 人工智能 |
| API | Application Programming Interface | 应用程序接口 |
| ASR | Automatic Speech Recognition | 自动语音识别 |
| ERD | Engineering Requirement Document | 工程需求文档 |
| EXIF | Exchangeable Image File Format | 可交换图像文件格式 |
| FPS | Frames Per Second | 每秒帧数 |
| JSON | JavaScript Object Notation | 轻量级数据交换格式 |
| LLM | Large Language Model | 大型语言模型 |
| MVP | Minimum Viable Product | 最小可行产品 |
| PRD | Product Requirement Document | 产品需求文档 |
| QA | Quality Assurance | 质量保证 |
| UI | User Interface | 用户界面 |
| UX | User Experience | 用户体验 |

---

## 🌐 多语言术语对照

| 中文 | 英文 | 说明 |
|------|------|------|
| 失去的人 | Lost One | 项目名称 |
| 人格 | Persona | AI 角色模型 |
| 共同记忆 | Memories | 关系经历 |
| 硬规则 | Hard Rules | 绝对禁忌 |
| 身份 | Identity | 角色定位 |
| 表达风格 | Expression Style | 语言习惯 |
| 情感逻辑 | Emotional Logic | 情感模式 |
| 关系行为 | Relational Behavior | 关系习惯 |
| 增量更新 | Incremental Update | 追加数据 |
| 对话纠正 | Conversation Correction | 手动调整 |

---

## 📚 参考资源

### 心理学概念
- [依恋理论](https://zh.wikipedia.org/wiki/依恋理论)
- [爱的五种语言](https://www.5lovelanguages.com/)

### 技术文档
- [Flutter 官方文档](https://docs.flutter.dev)
- [Google AI Edge](https://ai.google.dev/edge)
- [LiteRT 文档](https://ai.google.dev/edge/litert)

### 参考项目
- [ex-skill](https://github.com/perkfly/ex-skill) - Persona 五层结构来源
- [Google AI Edge Gallery](https://github.com/google-ai-edge/gallery) - 模型管理参考

---

## 🔄 更新日志

### 2026-08-01
- 创建 GLOSSARY.md
- 定义项目特定术语
- 添加技术术语和业务术语
- 提供多语言对照表

---

> 本术语表会随着项目发展持续更新。如有新术语，请及时添加。