# PRD-CICD-Pipeline-009-20260802

> 产品需求文档 - CI/CD 流水线
>
> **版本**：v1.0
> **状态**：草稿
> **作者**：Claude
> **日期**：2026-08-02
> **优先级**：P1

---

## 📋 文档信息

| 项目 | 内容 |
|------|------|
| **PRD 编号** | 009 |
| **模块名称** | CI/CD 流水线（CI/CD Pipeline） |
| **关联 ERD** | ERD-CICD-Pipeline-009-20260802.md（待编写） |
| **关联 Spec** | SPEC-CICD-Pipeline-009-20260802.md（待编写） |
| **依赖模块** | 001（项目初始化，提供 `mobile/` 工程与测试基线） |

---

## 1. 背景与目标

### 1.1 背景
模块 001 已建立 Flutter 工程骨架、测试基线（20/20）与严格的文档驱动流程，且约定 **PR 是合并到 `main` 的唯一途径**。但 PRD-001 明确将「CI/CD 配置」列为后续 PRD（见 PRD-001 §1.3「不包含」），当前仓库存在以下缺口：

- ❌ 无任何自动化：`flutter analyze` / `dart format` / `flutter test` / 覆盖率全部依赖人工在本地或评审时验证
- ❌ `main` 分支无保护规则，绿灯 CI 与 approve 未被强制
- ❌ 项目独有的治理规则（三文档齐全、`DOCUMENT-STATUS.md` 与 `README.md` 同步、Conventional Commits）无机器校验，只能靠评审人肉记忆
- ❌ 无可复现的构建/发布路径，Phase 7（App Store / TestFlight 上线）缺乏基础设施

随着模块 002+ 进入实现阶段，人工把关不可持续且易漏。需要把 CLAUDE.md 中已写明的规范固化为**自动化闸门**。

### 1.2 目标
建立一套基于 **GitHub Actions** 的 CI/CD 流水线，实现：

- ✅ 每个 PR 自动运行 analyze / format / test / 覆盖率 / 构建冒烟，快速反馈
- ✅ 将 CLAUDE.md 的既有规范固化为强制闸门（覆盖率 > 80%、Conventional Commits、三文档治理、状态文档同步）
- ✅ `main` 分支保护：必须 PR、必须绿灯、至少 1 人 approve
- ✅ 可复现、可缓存、跑得快的工作流（CI 全流程 < 10 分钟）
- ✅ 为发布奠基：标签触发的 TestFlight / App Store 发布流水线（Phase B，随 Phase 7 落地）

### 1.3 范围

**包含**：
- **Phase A（CI，本模块核心）**
  - PR / push 触发的持续集成工作流（analyze、format、test + coverage、web 构建冒烟）
  - 覆盖率门槛闸门（> 80%）
  - Conventional Commits 校验（PR 标题 / commit message）
  - 项目治理校验脚本：三文档齐全、`DOCUMENT-STATUS.md` ↔ `README.md` 一致性
  - 依赖 / SDK 缓存以加速
  - `main` 分支保护规则配置说明
  - 依赖更新自动化（Dependabot）
- **Phase B（CD，随 Phase 7）**
  - 标签触发的 iOS 构建 + TestFlight 上传（fastlane + App Store Connect API）
  - App Store 正式发布流程
  - 版本号 / 构建号自动递增

**不包含**：
- 业务功能实现（各功能模块 PRD 各自负责）
- 云端后端服务的部署（本项目为纯客户端 + 本地存储，无服务端）
- Android 发布（当前平台仅 iOS/macOS，见 ADR-001）
- 自建 runner / 自托管基础设施（使用 GitHub 托管 runner）

---

## 2. 用户故事

### 故事 1：贡献者 - 提 PR 自动获得检查反馈 - 无需等待人工

**作为**：贡献者
**我想要**：提交 PR 后自动运行 analyze / format / test / 覆盖率
**以便于**：在评审前就拿到快速、客观的反馈，减少来回

**验收标准**：
- [ ] 给定一个 PR，当推送提交后，则 CI 自动触发并在 PR 页面显示各检查状态
- [ ] 给定 `flutter analyze` 有告警的代码，当 CI 运行后，则对应检查为失败（红）
- [ ] 给定未 `dart format` 的代码，当 CI 运行后，则 format 检查失败
- [ ] 给定测试失败或覆盖率 < 80%，当 CI 运行后，则对应检查失败

**优先级**：高

---

### 故事 2：维护者 - 分支保护强制绿灯 - 保护 main 永不损坏

**作为**：维护者
**我想要**：`main` 分支要求 PR + 绿灯 CI + 至少 1 approve 才能合并
**以便于**：`main` 始终处于可发布状态，杜绝直接推送与红灯合并

**验收标准**：
- [ ] 给定 `main` 分支，当尝试直接 push 时，则被拒绝
- [ ] 给定一个 CI 未通过的 PR，当尝试合并时，则合并按钮被禁用
- [ ] 给定一个无 approve 的 PR，当尝试合并时，则被阻止

**优先级**：高

---

### 故事 3：维护者 - 治理规则被机器校验 - 三文档原则不被绕过

**作为**：维护者
**我想要**：CI 自动校验三文档齐全、`DOCUMENT-STATUS.md` 与 `README.md` 同步
**以便于**：文档驱动开发的核心约束不再依赖评审人记忆

**验收标准**：
- [ ] 给定某模块只有 PRD 而缺 ERD/Spec 却改动了该模块代码，当 CI 运行后，则治理检查失败并提示缺失文档
- [ ] 给定 `DOCUMENT-STATUS.md` 与 `README.md` 模块状态不一致，当 CI 运行后，则一致性检查失败
- [ ] 给定纯文档 PR（如本 PRD），当 CI 运行后，则治理检查不误报阻塞

**优先级**：中

---

### 故事 4：贡献者 - 提交信息规范被校验 - 保持历史清晰

**作为**：贡献者
**我想要**：Conventional Commits 格式被自动校验
**以便于**：提交历史规范、可生成变更日志

**验收标准**：
- [ ] 给定不符合 `<type>(<scope>): <subject>` 的 PR 标题/提交，当 CI 运行后，则校验失败
- [ ] 给定合规提交，当 CI 运行后，则校验通过

**优先级**：中

---

### 故事 5：发布负责人 - 标签触发构建上传 TestFlight - 可复现发布

**作为**：发布负责人
**我想要**：打一个版本标签即自动构建 iOS 包并上传 TestFlight
**以便于**：发布过程可复现、可追溯，无需本地手工打包

**验收标准**：
- [ ] 给定推送 `v*` 标签，当 CD 工作流运行后，则产出已签名的 iOS 构建并上传至 TestFlight
- [ ] 给定签名密钥缺失/失效，当 CD 运行后，则失败并给出明确错误，且不泄露密钥内容

**优先级**：低（Phase B，随 Phase 7）

---

## 3. 功能清单

### 3.1 核心功能（Phase A — CI）

#### 功能 1：持续集成工作流（CI）
**描述**：PR 与 `main` push 触发的核心 CI 工作流（GitHub Actions）。

**输入**：
- 触发事件：`pull_request`（目标 `main`）、`push`（`main`）
- 工作目录：`mobile/`
- 工具链：Flutter 3.38+ / Dart 3.11+（与 `pubspec.yaml` 一致）

**输出**：
- 各 job 的通过/失败状态，回写到 PR 的 checks
- 测试与覆盖率报告工件（artifact）

**业务规则**：
- 步骤：`flutter pub get` → `flutter analyze`（零告警）→ `dart format --output=none --set-exit-if-changed .` → `flutter test --coverage` → `flutter build web`（构建冒烟）
- Flutter 版本固定（pin），与工程约束一致；避免浮动版本导致的不可复现
- 使用缓存（pub cache、Flutter SDK）缩短耗时
- 任一步骤失败即整体失败

**优先级**：P0

---

#### 功能 2：覆盖率闸门
**描述**：解析 `flutter test --coverage` 的 `lcov.info`，低于阈值则失败。

**业务规则**：
- 阈值：行覆盖率 > 80%（对齐 CLAUDE.md 测试策略）
- 覆盖率数字在 PR 中可见（job summary 或评论/徽章）
- 阈值可通过工作流变量集中配置

**优先级**：P0

---

#### 功能 3：Conventional Commits 校验
**描述**：校验 PR 标题与/或提交信息符合 Conventional Commits。

**业务规则**：
- 允许的 type：`feat` `fix` `docs` `style` `refactor` `test` `chore`
- 至少校验 PR 标题（squash 合并时标题即最终提交信息）
- 违规给出可读的失败提示

**优先级**：P1

---

#### 功能 4：文档治理校验
**描述**：以脚本固化项目独有的文档驱动约束。

**校验项**：
1. **三文档齐全**：若 PR 改动了某模块 `mobile/` 代码，则该模块 PRD/ERD/Spec 必须存在且编号一致
2. **状态一致性**：`DOCUMENT-STATUS.md` 的模块状态与 `README.md`「模块文档」表不脱节
3. **纯文档 PR 豁免**：仅改 `docs/`、`README.md` 等的 PR 不因「代码无三文档」而失败

**业务规则**：
- 校验逻辑以独立脚本实现（便于本地复用与单测），CI 调用之
- 失败信息明确指出缺失/不一致的具体位置

**优先级**：P1

---

#### 功能 5：分支保护规则
**描述**：`main` 分支保护配置（GitHub 仓库设置 + 文档说明）。

**规则**：
- 禁止直接 push，必须经 PR
- 必须通过 required status checks（CI 全绿）
- 至少 1 个 approve
- 要求分支与 `main` 保持最新（可选）

**优先级**：P0（配置项，随 CI checks 就绪后启用）

---

### 3.2 辅助功能

#### 功能 A：依赖与 SDK 缓存
**描述**：缓存 pub 依赖与 Flutter SDK，缩短 CI 耗时。
**优先级**：P1

#### 功能 B：Dependabot 依赖更新
**描述**：对 `pub`（Flutter 依赖）与 `github-actions`（工作流 action 版本）启用自动更新 PR。
**优先级**：P2

#### 功能 C：iOS 构建冒烟（不签名）
**描述**：在 macOS runner 上执行 `flutter build ios --no-codesign` 作为编译层面的冒烟，早于正式 CD 捕获原生构建问题。
**说明**：macOS runner 分钟数消耗较高，可设为仅 `main` 或按需触发。
**优先级**：P2

---

### 3.3 发布功能（Phase B — CD，随 Phase 7）

#### 功能 D：TestFlight 发布流水线
**描述**：`v*` 标签触发，macOS runner 上用 fastlane 构建、签名、上传 TestFlight。
**依赖**：Apple Developer 账号、App Store Connect API Key、签名证书/描述文件。
**优先级**：P2（阻塞于 Apple Developer 账号具备）

#### 功能 E：App Store 正式发布 + 版本自动递增
**描述**：从 TestFlight 晋级正式发布；构建号/版本号自动管理。
**优先级**：P2

---

## 4. 非功能性需求

### 4.1 性能要求
- **CI 全流程时长**：< 10 分钟（含缓存命中）
- **快速反馈**：analyze / format 等轻量检查尽早失败（fail-fast）
- **缓存命中率**：pub 依赖缓存命中时 `pub get` < 30 秒

### 4.2 安全要求
- 所有密钥（App Store Connect API Key、签名证书、私钥）存于 **GitHub Encrypted Secrets**，绝不入库
- 日志中不打印密钥或完整凭证（对齐 CLAUDE.md 安全要求）
- 第三方 Action 固定到具体版本（tag 或 commit SHA），降低供应链风险
- 来自 fork 的 PR 默认无 secrets 访问权限；CD 仅在受信任上下文运行

### 4.3 可用性要求
- 工作流失败信息清晰、可定位到具体检查与文件
- 本地可复现：CI 执行的检查与 CLAUDE.md「常用命令」一致，开发者本地能跑同样命令
- CI 稳定性：非代码原因的偶发失败（flaky）率 < 2%

### 4.4 兼容性要求
- **Flutter 版本**：3.38+（与 `pubspec.yaml` 一致）
- **Dart 版本**：3.11+
- **CI runner**：`ubuntu-latest`（analyze/test/web），`macos-latest`（iOS 构建 / CD）
- **Xcode 版本**：runner 预装且满足 iOS 构建要求（15+）

---

## 5. 数据要求

### 5.1 配置输入
| 数据项 | 类型 | 必填 | 来源 | 验证规则 |
|--------|------|------|------|----------|
| Flutter 版本 | String | 是 | 工作流配置 | 与 pubspec 约束一致（3.38+） |
| 覆盖率阈值 | Number | 是 | 工作流变量 | 默认 80 |
| 触发分支/事件 | Config | 是 | 工作流配置 | `pull_request`→main、`push`→main、`v*` tag |

### 5.2 机密数据（Phase B）
| Secret 名 | 用途 | 说明 |
|-----------|------|------|
| `APP_STORE_CONNECT_API_KEY` | App Store Connect 鉴权 | .p8 内容，Base64 |
| `APP_STORE_CONNECT_KEY_ID` | API Key ID | - |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID | - |
| `IOS_DIST_CERT_P12` | 分发证书 | Base64，配 `IOS_DIST_CERT_PASSWORD` |
| `IOS_PROVISIONING_PROFILE` | 描述文件 | Base64 |

> 以上 Secret 仅在 Phase B 引入，全部经 GitHub Encrypted Secrets 注入，不落盘、不打日志。

### 5.3 产物
- 测试/覆盖率报告（artifact，保留期默认）
- Phase B：iOS `.ipa` 构建产物（上传 TestFlight，不长期留存于 Actions）

---

## 6. 界面要求

不适用（本模块为 CI/CD 配置与脚本）。反馈载体为 GitHub PR 的 checks、job summary 与状态徽章。

---

## 7. 接口依赖

### 7.1 对外接口
不适用。

### 7.2 依赖接口 / 服务
| 依赖 | 用途 |
|------|------|
| GitHub Actions | CI/CD 执行环境 |
| GitHub Branch Protection API/设置 | main 分支保护 |
| Flutter/Dart SDK | analyze / format / test / build |
| App Store Connect API（Phase B） | TestFlight / App Store 上传 |
| fastlane（Phase B） | iOS 构建与发布编排 |

---

## 8. 验收标准

### 8.1 功能验收（Phase A）
- [ ] PR 触发 CI，PR 页面显示 analyze / format / test / coverage / web-build 各检查状态
- [ ] analyze 有告警 / 未 format / 测试失败 / 覆盖率 < 80% 时对应检查失败
- [ ] Conventional Commits 校验对违规标题/提交失败、对合规通过
- [ ] 文档治理校验：缺三文档的代码 PR 失败；纯文档 PR 不误报
- [ ] `main` 分支保护生效（禁止直接 push、要求绿灯 + approve）

### 8.2 性能验收
- [ ] CI 全流程（缓存命中）< 10 分钟
- [ ] 缓存命中时 `pub get` < 30 秒

### 8.3 安全验收
- [ ] 无任何密钥入库；日志无凭证泄露
- [ ] 第三方 Action 均 pin 到具体版本/SHA
- [ ] fork PR 无法访问 secrets

### 8.4 发布验收（Phase B，随 Phase 7）
- [ ] `v*` 标签触发构建并成功上传 TestFlight
- [ ] 签名失败时报错清晰且不泄露密钥

---

## 9. 测试策略

### 9.1 工作流自验证
- 以一个「故意破坏」的临时 PR 验证各闸门确实会失败（analyze 告警、未 format、测试挂、覆盖率不足、非规范提交、缺文档）
- 以一个合规 PR 验证全绿

### 9.2 治理脚本单元测试
- 对三文档齐全 / 状态一致性校验脚本编写单元测试（覆盖：缺文档、编号不一致、纯文档 PR 豁免、状态脱节等分支）

### 9.3 Phase B 发布演练
- 在 TestFlight 内测轨道做一次端到端发布演练，验证签名、上传、版本号递增

---

## 10. 风险与应对

| 风险 | 影响 | 概率 | 应对措施 | 责任人 |
|------|------|------|---------|--------|
| macOS runner 分钟数消耗高/成本 | 中 | 中 | iOS 构建仅 main 或按需；Phase B 前不常态化 | 维护者 |
| Flutter 版本浮动导致不可复现 | 中 | 中 | 工作流 pin 具体 Flutter 版本，与 pubspec 对齐 | 维护者 |
| 签名密钥泄露 | 高 | 低 | 全部走 Encrypted Secrets、pin action、日志脱敏、fork 无 secrets | 维护者 |
| 测试 flaky 阻塞合并 | 中 | 中 | 隔离/修复 flaky 用例，必要时重试策略 | 开发者 |
| 治理脚本误报阻塞 | 中 | 中 | 纯文档豁免、清晰报错、可本地复现调试 | 开发者 |
| Apple Developer 账号未就绪 | 中 | 高 | Phase B 明确阻塞于账号具备，不影响 Phase A 上线 | 维护者 |

---

## 11. 里程碑计划

| 里程碑 | 交付物 | 负责人 |
|--------|--------|--------|
| M1: 三文档评审通过 | PRD/ERD/Spec-009 | Claude |
| M2: CI 工作流上线 | analyze/format/test/coverage/web-build 工作流 | 开发者 |
| M3: 治理与提交校验上线 | 治理脚本 + Conventional Commits 校验 + 分支保护 | 开发者 |
| M4: CI 验收通过 | 破坏性 PR 与合规 PR 双向验证通过 | 开发者 |
| M5（Phase B）: TestFlight 流水线 | 标签触发发布，随 Phase 7 | 发布负责人 |

---

## 12. 附录

### 12.1 参考资料
- [GitHub Actions 文档](https://docs.github.com/actions)
- [Flutter CI/CD 指南](https://docs.flutter.dev/deployment/cd)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [fastlane](https://docs.fastlane.tools/)
- CLAUDE.md（测试策略、Git 工作流、安全要求、文档治理规则）

### 12.2 术语表
- **CI**：持续集成，代码变更自动构建与测试
- **CD**：持续交付/部署，自动化发布到分发渠道
- **Runner**：GitHub Actions 的执行环境
- **Secret**：GitHub 加密存储的敏感配置
- **TestFlight**：Apple 的 iOS 应用内测分发平台

### 12.3 变更记录
| 日期 | 版本 | 变更内容 | 作者 |
|------|------|---------|------|
| 2026-08-02 | v1.0 | 初始版本（草稿） | Claude |

---

> 本文档遵循 Lostone 项目的文档驱动开发规范。
> 参考：[PRD 编写指南](../CLAUDE.md#prd)
