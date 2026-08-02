# Lostone

> **"从此以后，你的手机里不止有聊天记录，还有一个她/他。"**

**Lostone**（失去的人）是一款让用户能够创建逝去的亲人/朋友/爱人的 AI Persona（人格），并通过历史聊天数据重建他们的话语风格和性格特征，让用户能够与这些"失去的人"继续对话的应用。

将回忆蒸馏成 AI Persona，不是为了挽回，是为了记住。

---

[![License](https://img.shields.io/badge/License-CC%20BY--NC%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by-nc/4.0/)
[![Flutter](https://img.shields.io/badge/Flutter-3.38%2B-02569B.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.11%2B-0175C2.svg)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20macOS-lightgrey.svg)](https://www.apple.com)

---

## ✨ 核心特性

- 🎭 **Persona 创建系统**：从聊天记录自动生成五层人格模型
- 💬 **智能对话**：混合模型策略，本地 + 云端，隐私与性能兼顾
- 🔐 **隐私优先**：100% 本地存储，完全离线可用
- 🎨 **优雅体验**：Material Design 3，现代简洁的界面设计
- 📖 **开源透明**：CC BY-NC 4.0 许可，代码完全开放

---

## 📚 项目状态

**当前阶段**：Phase 1 - 数据导入（文档评审中）

**已完成**：
- ✅ 项目文档体系建立
- ✅ 文档模板（PRD/ERD/Spec）
- ✅ 模块 001（项目初始化）——**已完成**（三文档 v1.1 已批准、骨架 + 测试 20/20、iOS/web 运行验证通过；macOS 桌面延后）
- ✅ 模块 001 原生 runner（`ios/`、`macos/`、`web/`），可 `flutter run`
- ✅ Git 仓库和 GitHub 设置

**进行中**：
- 🚧 模块 002（数据导入）——三文档已批准（v1.0）；核心切片**已完成**（模型 + WeChatParser CSV/TXT/HTML 流式 + InstagramParser + IMessageParser（chat.db 只读）+ 预处理 + 导入编排 + Apple 时间转换 + Riverpod 导入状态层，测试 64/64、analyze 0 警告，两轮代理评审并修复 SPEC 合规缺口）；照片 EXIF 解析器、原生存储、导入 UI、大样本压测分阶段推进

**查看详细进度**：[开发路线图](docs/overview/ROADMAP.md) · [文档状态](docs/DOCUMENT-STATUS.md)

---

## 📖 快速开始

### 面向用户

**安装方式**（即将上线）：
- **iOS**：App Store 下载
- **macOS**：Mac App Store 下载

### 面向开发者

**前置要求**：
- Flutter SDK 3.38+
- Dart SDK 3.11+
- Xcode 15+（iOS/macOS 开发）

**克隆仓库**：
```bash
git clone https://github.com/obkim-hello/lostone.git
cd lostone
```

**运行应用（开发模式）**：
```bash
cd mobile
flutter pub get          # 安装依赖

flutter devices          # 查看可用设备
flutter run -d chrome    # 在 Chrome 中运行（无需 Xcode，最快验证）
flutter run -d ios        # 在 iOS 模拟器运行（需完整 Xcode，见下）
flutter run -d macos     # 在 macOS 桌面运行（延后，见下）
```

**在 iOS 模拟器运行（已验证）**：
```bash
cd mobile
open -a Simulator                      # 启动 iOS 模拟器
flutter devices                        # 确认模拟器已列出（如 "iPhone 15 (mobile)"）
flutter run -d ios                     # 首次运行会自动执行 pod install，稍慢
# 或指定具体设备：flutter run -d "iPhone 15"
```
> 首次运行 Flutter 会自动 `pod install`（因 `flutter_secure_storage` 等含原生依赖），
> 由此产生的 `ios/Pods/`、`Podfile.lock` 均已 gitignore，无需提交。
> 运行成功后首页应显示 **Lostone / environment: development / version: 0.1.0**。

**验证工程健康**：
```bash
cd mobile
flutter analyze          # 静态分析，应为 No issues found
flutter test             # 单元 + Widget 测试，应 20/20 通过
```

> **iOS/macOS 构建前置**：设备/模拟器构建需要完整 Xcode（非仅 Command Line Tools）。
> 若报 `xcrun: error: unable to find utility "xcodebuild"`，执行：
> ```bash
> sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
> ```
> **macOS 桌面运行**：延后处理（down the road）；届时同样需完整 Xcode。

**查看文档**：
```bash
# 项目总览
open docs/overview/README.md

# 开发规范
open CLAUDE.md

# 文档状态追踪
open docs/DOCUMENT-STATUS.md
```

---

## 📂 项目结构

```
lostone/
├── CLAUDE.md                 # 项目配置和开发规范
├── LICENSE                   # CC BY-NC 4.0 许可证
│
├── docs/                     # 📚 文档中心
│   ├── overview/             # 项目总览（README、VISION、ROADMAP、GLOSSARY）
│   ├── prd/                  # 产品需求文档（PRD）
│   ├── erd/                  # 工程需求文档（ERD）
│   ├── spec/                 # 技术规格（Spec）
│   ├── architecture/         # 架构设计
│   ├── testing/              # 测试文档
│   ├── release/              # 发布文档
│   └── DOCUMENT-STATUS.md    # 文档状态追踪
│
└── mobile/                   # Flutter 应用
    ├── lib/                  # 应用源码（models/services/providers/screens/...）
    ├── test/                 # 单元 + Widget 测试
    ├── ios/ · macos/ · web/  # 各平台 runner
    └── pubspec.yaml          # 依赖声明
```

**详细说明**：查看 [docs/.claude.md](docs/.claude.md)

---

## 📋 文档体系

### 核心文档

| 文档 | 说明 |
|------|------|
| [README.md](docs/overview/README.md) | 项目详细介绍 |
| [VISION.md](docs/overview/VISION.md) | 愿景与长期目标 |
| [ROADMAP.md](docs/overview/ROADMAP.md) | 开发路线图 |
| [GLOSSARY.md](docs/overview/GLOSSARY.md) | 术语定义 |
| [CLAUDE.md](CLAUDE.md) | 项目配置和开发规范 |

### 模块文档

| 模块 | PRD | ERD | Spec | 状态 |
|------|-----|-----|------|------|
| 001 - 项目初始化 | [PRD](docs/prd/PRD-Project-Setup-001-20260801.md) | [ERD](docs/erd/ERD-Flutter-Setup-001-20260801.md) | [Spec](docs/spec/SPEC-Project-Config-001-20260801.md) | ✅ 已完成（v1.1） |
| 002 - 数据导入 | [PRD](docs/prd/PRD-Data-Import-002-20260801.md) | [ERD](docs/erd/ERD-Data-Parsers-002-20260801.md) | [Spec](docs/spec/SPEC-Data-Parser-002-20260801.md) | ✅ 已批准 · 🚧 开发中 |
| ... | ... | ... | ... | ... |

**查看完整状态**：[DOCUMENT-STATUS.md](docs/DOCUMENT-STATUS.md)

---

## 🛠️ 技术栈

| 类别 | 技术选型 |
|------|---------|
| **框架** | Flutter 3.38+ |
| **语言** | Dart 3.11+ |
| **本地 AI** | Google AI Edge LiteRT |
| **支持模型** | Gemma 4, Llama 3.2, Qwen 2.5, Phi-3 |
| **云端 API** | OpenAI, Anthropic, Google Gemini |
| **状态管理** | Riverpod |
| **本地数据库** | Hive + SQLite |
| **安全存储** | Flutter Secure Storage |
| **UI 设计** | Material Design 3 |

---

## 🤝 贡献指南

我们欢迎所有形式的贡献！

### 贡献方式

1. **Fork** 本仓库
2. **创建特性分支** (`git checkout -b feature/AmazingFeature`)
3. **编写文档**（遵循文档驱动开发规范）
4. **提交变更** (`git commit -m 'feat: Add some AmazingFeature'`)
5. **推送到分支** (`git push origin feature/AmazingFeature`)
6. **开启 Pull Request**

### 贡献须知

- 所有贡献者需同意 **CC BY-NC 4.0** 许可
- 遵循 [文档驱动开发](CLAUDE.md) 规范
- PRD + ERD + Spec 三文档齐全才能开始开发
- 提交前请确保通过所有测试

**详细指南**：查看 [CLAUDE.md](CLAUDE.md)

---

## 📄 许可证

本项目采用 **CC BY-NC 4.0**（知识共享-署名-非商业使用）许可证。

### ✅ 允许
- 分享、复制、修改（需署名）
- 用于个人、教育、研究目的

### ❌ 禁止
- 商业使用、销售
- 去除版权声明

**商业使用**：如需商业授权，请联系项目维护者。

**许可证全文**：查看 [LICENSE](LICENSE)

---

## 🙏 致谢

### 参考项目
- [ex-skill](https://github.com/perkfly/ex-skill) - Persona 五层结构设计灵感
- [Google AI Edge Gallery](https://github.com/google-ai-edge/gallery) - 本地模型管理和 UI 设计参考

### 技术支持
- Google AI Edge 团队
- Flutter 社区
- 所有贡献者

---

## 📧 联系方式

- **项目主页**：https://github.com/obkim-hello/lostone
- **问题反馈**：[GitHub Issues](https://github.com/obkim-hello/lostone/issues)
- **功能建议**：[GitHub Discussions](https://github.com/obkim-hello/lostone/discussions)

---

> 💡 **Made with ❤️ for those we've lost, but never forget.**
>
> 将回忆蒸馏成 AI Persona，不是为了挽回，是为了记住。

---

**[📖 查看完整文档](docs/overview/README.md)** | **[📋 查看开发路线图](docs/overview/ROADMAP.md)** | **[🤝 贡献指南](CLAUDE.md)**