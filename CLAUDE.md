# Lostone 项目配置

> 本文件为 Claude Code 提供项目特定的开发指南、工作流程和规范，确保可持续、高质量的代码开发。

---

## 项目概述

**Lostone** 是一款让用户能够创建逝去的亲人/朋友/爱人的 AI Persona（人格）的应用。通过历史聊天数据重建他们的话语风格和性格特征，让用户能够与这些"失去的人"继续对话。

**核心价值**：将回忆蒸馏成 AI Persona，不是为了挽回，是为了记住。

---

## 开发方法论

### 文档驱动开发（Document-Driven Development）

**核心原则**：
1. **文档优先**：先写文档，后写代码
2. **Spec-Driven**：先写技术规格，再写实现
3. **测试驱动**：先写测试用例，再写功能代码
4. **三文档齐全**：PRD + ERD + Spec 必须齐全且批准后才能开始开发
5. **状态实时更新**：每完成一个文档，必须立即更新 DOCUMENT-STATUS.md

**🔴 重要规则：三文档齐全原则**

**任何模块的开发必须满足以下条件**：
- ✅ PRD 已编写并**批准**
- ✅ ERD 已编写并**批准**
- ✅ Spec 已编写并**批准**
- ✅ 三个文档编号一致（如 PRD-Project-Setup-001-20260801.md、ERD-Flutter-Setup-001-20260801.md、SPEC-Project-Config-001-20260801.md）
- ✅ 文档日期为批准日期

**禁止行为**：
- ❌ 仅有 PRD 就开始开发
- ❌ 仅有 ERD 就开始开发
- ❌ 文档未批准就开始开发
- ❌ 文档编号不一致

**工作流程**：
```
需求分析 → 编写 PRD/ERD/Spec → 三文档评审 → 三文档批准 → 编写测试 → 实现代码 → 验证通过
                                    ↓
                            （必须三者齐全）
```

**检查清单**：
- [ ] PRD 已编写并评审通过
- [ ] ERD 已编写并评审通过
- [ ] Spec 已编写并评审通过
- [ ] 三文档编号一致
- [ ] 三文档状态均为"已批准"
- [ ] **DOCUMENT-STATUS.md 已更新** 🔴
- [ ] **根目录 README.md 已同步**（项目状态 + 模块文档表）🔴
- [ ] 测试用例已定义
- [ ] 代码实现完成
- [ ] 所有测试通过
- [ ] 文档已更新

**🔴 文档状态更新规则**：
每次完成文档编写后，必须立即更新 `docs/DOCUMENT-STATUS.md`，记录：
- 文档状态（待创建/草稿/评审中/已批准/需修改）
- 完成时间
- 文件路径
- 三文档齐全状态

**🔴 根目录 README.md 同步规则**：
每次模块文档状态变更（新建/评审/批准）或阶段（Phase）进展时，必须同步更新根目录 `README.md`：
- 「📚 项目状态」：当前阶段、已完成/进行中清单
- 「📋 文档体系 → 模块文档」表：各模块 PRD/ERD/Spec 链接与状态
- 技术栈/前置要求中的版本须与实际工具链一致（当前 Flutter 3.38+/Dart 3.11+）

`docs/DOCUMENT-STATUS.md` 是权威追踪表，`README.md` 是其对外摘要；两者不得脱节。

---

## 文档体系

### PRD（产品需求文档）
- **粒度**：模块级别（每个功能模块一个 PRD）
- **命名**：`PRD-{模块名}-{编号}-{YYYYMMDD}.md`
- **示例**：`PRD-Project-Setup-001-20260801.md`
- **模板**：使用 `PRD-TEMPLATE.md`
- **必须包含**：
  1. 背景和目标
  2. 用户故事
  3. 功能清单
  4. 验收标准
  5. 优先级和依赖

### ERD（工程需求文档）
- **粒度**：模块级别
- **命名**：`ERD-{模块名}-{编号}-{YYYYMMDD}.md`
- **示例**：`ERD-Flutter-Setup-001-20260801.md`
- **模板**：使用 `ERD-TEMPLATE.md`
- **必须包含**：
  1. 技术目标和约束
  2. 数据结构定义
  3. 接口设计
  4. 测试策略
  5. 性能指标

### Spec（技术规格）
- **粒度**：模块接口级别（明确输入输出和边界情况）
- **命名**：`SPEC-{模块名}-{编号}-{YYYYMMDD}.md`
- **示例**：`SPEC-Project-Config-001-20260801.md`
- **模板**：使用 `SPEC-TEMPLATE.md`
- **必须包含**：
  1. 输入输出规格
  2. 前置条件和后置条件
  3. 边界情况处理
  4. 测试用例
  5. 性能要求

---

## 技术栈

### 核心框架
- **Flutter** 3.24+：跨平台移动应用框架
- **Dart** 3.0+：编程语言

### AI/ML
- **LiteRT**：Google AI Edge 轻量级推理引擎
- **支持模型**：Gemma 4, Llama 3.2, Qwen 2.5, Phi-3
- **云端 API**：OpenAI, Anthropic, Google Gemini

### 数据存储
- **SQLite**：关系型数据（聊天记录、Persona 元数据）
- **Hive**：键值存储（应用设置、缓存）
- **Flutter Secure Storage**：敏感数据加密

### 状态管理
- **Riverpod**：响应式状态管理

### UI 设计
- **Material Design 3**：现代、优雅的 UI

---

## 代码规范

### Dart/Flutter 代码风格

**基本规则**：
- 遵循 [Effective Dart](https://dart.dev/guides/language/effective-dart) 规范
- 使用 `flutter analyze` 进行静态分析
- 使用 `dart format` 格式化代码

**命名约定**：
```dart
// 文件名：snake_case
// my_widget.dart

// 类名：PascalCase
class MyWidget extends StatelessWidget {}

// 变量和函数：camelCase
final String userName;
void loadData() {}

// 常量：lowerCamelCase（Dart 风格）
const Duration defaultTimeout = Duration(seconds: 30);

// 私有成员：前缀 _
class _PrivateClass {
  String _privateField;
}
```

**目录结构**：
```
mobile/lib/
├── main.dart
├── app.dart
├── models/          # 数据模型
├── services/        # 业务逻辑
├── providers/       # 状态管理
├── screens/         # UI 页面
├── widgets/         # 可复用组件
└── utils/           # 工具函数
```

**注释规范**：
```dart
/// 文档注释：用于公共 API
/// 
/// 示例：
/// ```dart
/// final persona = PersonaBuilder().build();
/// ```
class PersonaBuilder {}

// 代码注释：用于复杂逻辑解释
// 使用 TODO、FIXME、HACK 标记
// TODO: 实现增量更新逻辑
// FIXME: 修复内存泄漏问题
// HACK: 临时解决方案，需要重构
```

### 文档注释要求

**所有公共 API 必须有文档注释**：
```dart
/// 从聊天记录生成 Persona。
/// 
/// 参数：
/// - [messages]：聊天消息列表
/// - [options]：生成选项（可选）
/// 
/// 返回：生成的 Persona 对象
/// 
/// 抛出：
/// - [ArgumentError]：如果 messages 为空
/// 
/// 示例：
/// ```dart
/// final persona = await PersonaBuilder().buildFromMessages(messages);
/// print(persona.identity.name);
/// ```
Future<Persona> buildFromMessages(
  List<Message> messages, {
  PersonaOptions? options,
}) async {
  // 实现
}
```

---

## 测试策略

### 测试金字塔

**单元测试（Unit Tests）**：
- 覆盖率目标：> 80%
- 测试所有业务逻辑和数据转换
- 使用 `test` 包
- 文件位置：`test/unit/`

**Widget 测试**：
- 测试 UI 组件交互
- 使用 `flutter_test` 包
- 文件位置：`test/widget/`

**集成测试**：
- 测试完整用户流程
- 使用 `integration_test` 包
- 文件位置：`test/integration/`

### 测试驱动开发（TDD）

**流程**：
```
编写测试用例 → 运行测试（失败）→ 编写最小实现 → 运行测试（通过）→ 重构
```

**示例**：
```dart
// 1. 编写测试
test('Persona 应该包含五层结构', () {
  final persona = PersonaBuilder().build();
  
  expect(persona.hardRules, isNotNull);
  expect(persona.identity, isNotNull);
  expect(persona.expressionStyle, isNotNull);
  expect(persona.emotionalLogic, isNotNull);
  expect(persona.relationalBehavior, isNotNull);
});

// 2. 运行测试（失败）
// 3. 编写最小实现
// 4. 运行测试（通过）
// 5. 重构优化
```

### 测试命名规范

```dart
// 格式：test('{描述}', () { ... });
test('PersonBuilder 应该从聊天记录生成 Persona', () {});

// 分组：group('{模块名}', () { ... });
group('PersonaBuilder', () {
  test('应该处理空消息列表', () {});
  test('应该提取表达风格', () {});
});
```

---

## Git 工作流程

### 分支策略

**主要分支**：
- `main`：稳定版本，随时可发布
- `develop`：开发分支，集成最新功能
- `feature/*`：功能分支
- `bugfix/*`：修复分支
- `docs/*`：文档分支

**分支命名**：
```
feature/PRD-002-data-import
bugfix/fix-persona-generation
docs/update-readme
```

### Commit 规范

**格式**：
```
<type>(<scope>): <subject>

<body>

<footer>
```

**Type 类型**：
- `feat`：新功能
- `fix`：Bug 修复
- `docs`：文档更新
- `style`：代码格式（不影响功能）
- `refactor`：重构（不新增功能或修复 Bug）
- `test`：添加或修改测试
- `chore`：构建过程或辅助工具变动

**示例**：
```
feat(data-import): 实现微信聊天记录解析器

- 支持 CSV 和 HTML 格式
- 提取文本、图片、语音消息
- 添加数据清洗和去重逻辑

Closes #123
```

**提交信息要求**：
- 必须遵循 Conventional Commits 规范
- 每个 commit 只做一件事
- commit message 要清晰描述变更

### Pull Request 规范

**🔴 PR 是合并到 main 的唯一途径**

**PR 标题**：
```
[PRD-002] 实现数据导入模块
```

**PR 描述模板**：
```markdown
## 关联文档
- PRD：PRD-002-Data-Import.md
- ERD：ERD-002-Data-Parsers.md
- Spec：SPEC-001-Persona-Builder.md

## 变更内容
- 实现微信聊天记录解析器
- 实现 iMessage 解析器
- 添加数据预处理模块

## 测试
- [ ] 单元测试已添加
- [ ] 所有测试通过
- [ ] 代码覆盖率 > 80%

## 检查清单
- [ ] 代码遵循 Effective Dart 规范
- [ ] 公共 API 有文档注释
- [ ] 无 `flutter analyze` 警告
- [ ] 相关文档已更新
- [ ] DOCUMENT-STATUS.md 已更新
```

**PR 审查要求**：
- 至少 1 人 approve
- 通过所有自动化测试（后续配置）
- 无冲突
- 符合代码规范

---

## 架构决策记录（ADR）

### ADR-001：选择 Flutter 作为移动端框架

**状态**：已接受

**背景**：
需要开发跨平台移动应用（iOS + macOS），未来可能扩展到 Android。

**决策**：
选择 Flutter 作为移动端框架。

**理由**：
1. 跨平台能力：一套代码支持 iOS、macOS、Android
2. 性能优异：接近原生性能
3. Material Design 内置支持
4. 丰富的 AI/ML 插件生态（LiteRT 官方支持）
5. 热重载加速开发

**后果**：
- 需要学习 Dart 语言
- 相比原生，某些平台特定功能可能需要插件

---

### ADR-002：采用混合模型策略

**状态**：已接受

**背景**：
用户对隐私和性能有不同需求，单一模型策略无法满足所有场景。

**决策**：
采用混合模型策略：本地模型（隐私优先）+ 云端 API（性能优先）。

**理由**：
1. 本地模型：完全离线、隐私保护、无成本
2. 云端 API：高质量、快速响应、多功能
3. 用户自由选择，灵活适配不同场景

**后果**：
- 需要设计统一的 LLM 接口（Runtime 抽象层）
- 需要管理云端 API 的成本和安全性

---

### ADR-003：使用 Protocol Buffers 作为 Persona 文件格式

**状态**：提议中

**背景**：
Persona 文件需要高效序列化和跨平台兼容。

**决策**：
考虑使用 Protocol Buffers 替代 JSON 作为 Persona 文件格式。

**理由**：
1. 更小的文件大小（比 JSON 小 3-10 倍）
2. 更快的序列化/反序列化速度
3. 强类型定义，减少错误
4. 跨语言兼容（Dart、Kotlin、Swift）

**后果**：
- 需要 `.proto` 文件定义
- 需要生成 Dart 代码
- 可读性不如 JSON（需要工具查看）

---

## 常用命令

### Flutter 开发
```bash
# 获取依赖
flutter pub get

# 运行应用
flutter run

# 运行测试
flutter test

# 代码分析
flutter analyze

# 代码格式化
dart format .

# 构建发布版本
flutter build ios --release
```

### Git 操作
```bash
# 创建功能分支
git checkout -b feature/PRD-002-data-import

# 提交变更
git add .
git commit -m "feat(data-import): 实现微信解析器"

# 推送到远程
git push origin feature/PRD-002-data-import

# 创建 PR
gh pr create --title "[PRD-002] 实现数据导入模块"
```

### 文档生成
```bash
# 生成 Dart 文档
dart doc .

# 检查文档完整性
# TODO: 添加文档检查脚本
```

---

## 性能指标

### 启动性能
- 冷启动时间：< 2 秒
- 热启动时间：< 1 秒

### AI 推理性能
- 本地模型加载时间：< 3 秒
- 首 token 响应时间：< 2 秒
- 推理速度：> 5 tokens/s（iPhone 15+）
- 内存占用：< 2GB

### Persona 生成性能
- 生成时间：< 60 秒（1000 条消息）

### 云端 API 性能
- 响应时间：< 2 秒（GPT-4o/Claude Sonnet）
- 流式输出延迟：< 500ms

---

## 安全要求

### 数据安全
- 所有用户数据加密存储（AES-256）
- API Key 使用 Flutter Secure Storage 加密
- 生物识别保护（Face ID / Touch ID）
- 后台自动锁定应用

### 隐私保护
- 100% 本地存储，不上传用户数据
- 云端 API 需要用户明确授权
- 开源代码，社区可审计

### 代码安全
- 不在日志中输出敏感信息
- 不在调试信息中显示完整 API Key
- 使用环境变量存储敏感配置
- 定期更新依赖，修复安全漏洞

---

## 贡献指南

### 贡献流程
1. Fork 仓库
2. 创建功能分支
3. 编写 PRD/ERD/Spec（如果是新功能）
4. 编写测试用例
5. 实现功能代码
6. 提交 PR
7. 代码审查通过
8. 合并到主分支

### 代码审查标准
- [ ] PRD/ERD 已评审通过
- [ ] 测试覆盖率 > 80%
- [ ] 无 `flutter analyze` 警告
- [ ] 公共 API 有文档注释
- [ ] 性能指标达标
- [ ] 安全审查通过

---

## 许可证

本项目采用 **CC BY-NC 4.0** 许可证。

- ✅ 允许：分享、复制、修改（需署名）
- ❌ 禁止：商业使用、销售

所有贡献者需同意此许可。

---

## 联系方式

- **项目主页**：https://github.com/yourusername/lostone
- **问题反馈**：GitHub Issues
- **功能建议**：GitHub Discussions

---

## 更新日志

### 2026-08-01
- 创建 CLAUDE.md
- 定义文档驱动开发流程
- 规范代码风格和测试策略
- 记录架构决策

---

> 本文件会根据项目发展持续更新。如有建议，请提交 Issue 或 PR。