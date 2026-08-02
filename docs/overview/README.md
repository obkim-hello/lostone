# Lostone

> "从此以后，你的手机里不止有聊天记录，还有一个她/他。"

**Lostone**（失去的人）是一款让用户能够创建逝去的亲人/朋友/爱人的 AI Persona（人格），并通过历史聊天数据重建他们的话语风格和性格特征，让用户能够与这些"失去的人"继续对话的应用。

将回忆蒸馏成 AI Persona，不是为了挽回，是为了记住。

---

## ✨ 核心特性

### 🎭 Persona 创建系统
- **多源数据导入**：支持微信、iMessage、照片、社交媒体等多种数据源
- **五层人格结构**：硬规则 → 身份 → 表达风格 → 情感逻辑 → 关系行为
- **增量更新**：追加新聊天记录，持续优化 Persona

### 💬 智能对话
- **混合模型策略**：本地模型（隐私优先）+ 云端 API（性能优先）
- **完全离线运行**：本地模型支持 100% 离线对话
- **多模态交互**：文本、图片、语音
- **Persona 驱动**：AI 以"失去的人"的语气和性格回应

### 🔐 隐私优先
- **100% 本地存储**：所有数据加密存储在用户设备
- **生物识别保护**：Face ID / Touch ID 解锁
- **用户掌控**：数据导出、删除完全由用户控制

### 🎨 优雅体验
- **Material Design 3**：现代、优雅的 UI 设计
- **跨平台**：iOS 优先，后续支持 macOS
- **开源透明**：CC BY-NC 4.0 许可，代码完全开放

---

## 🛠️ 技术栈

| 类别 | 技术选型 |
|------|---------|
| **框架** | Flutter 3.24+ |
| **本地 AI** | Google AI Edge LiteRT |
| **支持模型** | Gemma 4, Llama 3.2, Qwen 2.5, Phi-3 |
| **云端 API** | OpenAI, Anthropic, Google Gemini |
| **数据库** | SQLite + Hive |
| **加密存储** | Flutter Secure Storage |
| **状态管理** | Riverpod |
| **UI 设计** | Material Design 3 |

---

## 🚀 快速开始

### 前置要求
- Flutter SDK 3.24+
- iOS 17+ / macOS 14+
- Xcode 15+（iOS 开发）

### 安装步骤（开发者）

```bash
# 1. 克隆仓库
git clone https://github.com/yourusername/lostone.git
cd lostone

# 2. 安装依赖
cd mobile
flutter pub get

# 3. 运行应用
flutter run
```

### 用户安装
- **iOS**：App Store 下载（即将上线）
- **macOS**：Mac App Store 下载（即将上线）

---

## 📖 使用指南

### 1. 创建 Lost One
1. 点击首页的"+"按钮
2. 输入基本信息（姓名、关系）
3. 导入聊天记录或其他数据源
4. 系统自动生成 Persona

### 2. 开始对话
1. 在首页选择一个 Lost One
2. 开始对话，AI 会以他/她的语气回应
3. 支持发送文字、图片、语音

### 3. 管理模型
- **本地模型**：在设置中下载和管理多个模型
- **云端 API**：配置自己的 API Key（可选）
- **一键切换**：随时切换本地/云端模型

---

## 📚 文档

- [愿景与目标](VISION.md) - 项目愿景和长期目标
- [开发路线图](ROADMAP.md) - 详细的开发计划
- [术语表](GLOSSARY.md) - 项目术语定义
- [系统架构](ARCHITECTURE.md) - 技术架构设计

### 产品文档（PRD）
- [PRD-001-Project-Setup](PRD-001-Project-Setup.md) - 项目初始化
- [PRD-002-Data-Import](PRD-002-Data-Import.md) - 数据导入模块
- [PRD-003-Persona-Generation](PRD-003-Persona-Generation.md) - Persona 生成引擎
- [查看所有 PRD →](docs/PRD/)

### 工程文档（ERD）
- [ERD-001-Flutter-Setup](ERD-001-Flutter-Setup.md) - Flutter 项目配置
- [ERD-002-Data-Parsers](ERD-002-Data-Parsers.md) - 数据解析器规格
- [查看所有 ERD →](docs/ERD/)

---

## 🤝 贡献指南

我们欢迎所有形式的贡献！

### 如何贡献
1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

### 贡献者须知
- 所有贡献者需同意 CC BY-NC 4.0 许可
- 提交 PR 前请确保通过所有测试
- 遵循 [代码风格指南](CONTRIBUTING.md)

---

## 📄 许可证

本项目采用 **CC BY-NC 4.0** 许可证。

- ✅ **允许**：分享、复制、修改（需署名）
- ❌ **禁止**：商业使用、销售

商业使用请联系作者获取授权。

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

- **项目主页**：https://github.com/yourusername/lostone
- **问题反馈**：[GitHub Issues](https://github.com/yourusername/lostone/issues)
- **功能建议**：[GitHub Discussions](https://github.com/yourusername/lostone/discussions)
- **商业合作**：your.email@example.com

---

> 💡 **Made with ❤️ for those we've lost, but never forget.**