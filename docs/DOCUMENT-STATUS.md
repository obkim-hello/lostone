# Lostone 文档状态追踪

> 本文档追踪所有模块的文档完整性状态，确保 PRD + ERD + Spec 三文档齐全且批准。

---

## 📊 文档完整性矩阵

| 模块编号 | 模块名称 | PRD 状态 | ERD 状态 | Spec 状态 | 三文档齐全 | 开发状态 |
|----------|---------|---------|---------|----------|-----------|----------|
| 001 | 项目初始化 | ✅ 已批准 | ✅ 已批准 | ✅ 已批准 | ✅ 是 | ✅ 已完成 |
| 002 | 数据导入 | ✅ 已批准 | ✅ 已批准 | ✅ 已批准 | ✅ 是 | 🚧 开发中 |
| 003 | Persona 生成 | ✅ 已批准 | ✅ 已批准 | ✅ 已批准 | ✅ 是 | ✅ 已完成 |
| 004 | LLM 集成（蒸馏 + 对话引擎 + Runtime 抽象层）| ✅ 已批准 | ✅ 已批准 | ✅ 已批准 | ✅ 是 | ✅ 已完成 |
| ~~005~~ | 云端 API 集成 → **已并入 004**（Runtime 抽象层统一本地/云端）| — | — | — | — | 🔀 已折叠 |
| 006 | 聊天界面（对话 + 聊天历史 SQLite，Phase 4）| 📝 草稿 | 📝 草稿 | 📝 草稿 | ⚠️ 草稿完成 | 🚫 阻塞 |
| 007 | 模型管理（提前至 Phase 3，004 本地路径前置）| ✅ 已批准 | ✅ 已批准 | ✅ 已批准 | ✅ 是 | ✅ 已完成 |
| 008 | 数据安全 | ⚪ 待创建 | ⚪ 待创建 | ⚪ 待创建 | ❌ 否 | 🚫 阻塞 |
| 009 | 人物库与蒸馏（Persona 持久化 + 库 + 蒸馏流程 + 导入 UI 入口，Phase 4，v1.1.1）| ✅ 已批准 | ✅ 已批准 | ✅ 已批准 | ✅ 三文档齐全 | 🚧 开发中 |
| 010 | 设置（模型管理 UI + 运行模式 + 云端授权，Phase 4）| ✅ v1.0.2（🔶 v1.0.3 待复批）| ✅ v1.0.2（🔶 v1.0.3 待复批）| ✅ v1.0.2（🔶 v1.0.3 待复批）| ✅ 是 | 🚧 开发中（PR #17）|

---

## 📋 模块 001 详细状态

### 文档信息
| 文档类型 | 文件名 | 状态 | 完成时间 | 批准时间 | 文件路径 |
|----------|--------|------|---------|---------|---------|
| PRD | PRD-Project-Setup-001-20260801.md | ✅ 已批准 | 2026-08-01 21:15 | 2026-08-01 21:45 | docs/prd/PRD-Project-Setup-001-20260801.md |
| ERD | ERD-Flutter-Setup-001-20260801.md | ✅ 已批准 | 2026-08-01 21:18 | 2026-08-01 21:45 | docs/erd/ERD-Flutter-Setup-001-20260801.md |
| Spec | SPEC-Project-Config-001-20260801.md | ✅ 已批准 | 2026-08-01 21:20 | 2026-08-01 21:45 | docs/spec/SPEC-Project-Config-001-20260801.md |

### 三文档齐全检查
- ✅ PRD 已创建并批准
- ✅ ERD 已创建并批准
- ✅ Spec 已创建并批准
- ✅ 编号一致（001）
- ✅ 日期一致（20260801）
- ✅ 状态：已批准
- ✅ **三文档齐全，可以开始开发**

### 开发进度
| 项目 | 状态 | 说明 |
|------|------|------|
| Flutter 项目骨架 | ✅ 已实现 | `mobile/` 目录，pubspec.yaml + analysis_options.yaml |
| 数据模型 | ✅ 已实现 | AppConfig、DependencyConfig、EnvironmentStatus |
| 初始化服务 | ✅ 已实现 | AppInitializer、initializeApp、checkEnvironment |
| 状态管理 | ✅ 已实现 | appConfigProvider、initializationProvider |
| 环境检查 | ✅ 已实现 | checkEnvironment 校验 Dart SDK 版本，不达标抛 EnvironmentError |
| 单元/Widget 测试 | ✅ 已通过 | test/unit、test/widget，20/20 通过（含初始化 happy-path） |
| flutter analyze / test 验证 | ✅ 已通过 | analyze 无 issue；test 20/20；dart format 已应用 |
| 原生 runner | ✅ 已生成 | `flutter create --org com.obkim --platforms=macos,ios,web .` 补齐 `ios/`、`macos/`、`web/`（bundle id `com.obkim.lostone`） |
| 开发运行验证 | ✅ 已通过 | iOS 模拟器运行通过（占位首页显示 app 名/环境/版本）；`flutter build web` 成功；macOS 桌面延后（down the road） |

分支：`feature/PRD-001-flutter-setup`

### ✅ 已解决：SDK 版本对齐（v1.1）
- **SDK 版本约束**：✅ 已解决。PRD-001 / ERD-001 / SPEC-001 三文档已随 v1.1 修订将 Flutter 3.24+/Dart 3.0+
  更正为 **Flutter 3.38+ / Dart 3.11+**（SPEC 环境检查阈值 >= 3.24 → >= 3.38），与 `pubspec.yaml`（`flutter >=3.38.4` / `sdk >=3.11.0`）一致。
- **原生 runner**：✅ 已执行 `flutter create --org com.obkim --platforms=macos,ios,web .`，补齐 `ios/`、`macos/`、`web/` 目录，可 `flutter run`。
- **iOS 兼容性验收（PRD-001 §8.4）**：✅ iOS 模拟器编译并运行通过。
- **macOS 兼容性验收（PRD-001 §8.4）**：⏸ **已决定延后**（不阻塞模块 001 收尾），届时如报 `xcodebuild not found` 先 `sudo xcode-select -s /Applications/Xcode.app`。

> **模块 001 收尾结论**：核心骨架实现完成，iOS/web 运行验证通过，PRD/ERD 版本已对齐并 v1.1 重新批准；
> macOS 桌面验收明确延后。模块 001 视为**已完成**（macOS 桌面为已知延后项）。

---

## 📋 模块 002 详细状态

### 文档信息
| 文档类型 | 文件名 | 状态 | 完成时间 | 批准时间 | 文件路径 |
|----------|--------|------|---------|---------|---------|
| PRD | PRD-Data-Import-002-20260801.md | ✅ 已批准 | 2026-08-01 | 2026-08-02 | docs/prd/PRD-Data-Import-002-20260801.md |
| ERD | ERD-Data-Parsers-002-20260801.md | ✅ 已批准 | 2026-08-01 | 2026-08-02 | docs/erd/ERD-Data-Parsers-002-20260801.md |
| Spec | SPEC-Data-Parser-002-20260801.md | ✅ 已批准 | 2026-08-01 | 2026-08-02 | docs/spec/SPEC-Data-Parser-002-20260801.md |

### 三文档齐全检查
- ✅ PRD 已创建并批准
- ✅ ERD 已创建并批准
- ✅ Spec 已创建并批准
- ✅ 编号一致（002）
- ✅ 日期一致（20260801）
- ✅ 状态：已批准（2026-08-02，四轮评审后）
- ✅ **三文档齐全，可以开始开发**

### 开发进度
> 模块 002 体量大（五类解析器 + 流式至 5GB + iOS/macOS 原生存储 + 导入 UI）。首个实现切片聚焦**纯 Dart、可单元测试的核心**；原生/设备相关部分分阶段推进。

| 项目 | 状态 | 说明 |
|------|------|------|
| 核心数据模型 | ✅ 已完成 | Message/MessageType/DataSource、Conversation/ImportStats、ParseEvent/MediaIndexEntry/MediaTier/ParseOptions/ParseResult/ParseWarning |
| DataParser 契约 + parseAll | ✅ 已完成 | 抽象接口 + 排空流便捷法 |
| WeChatParser（CSV/TXT/HTML 流式） | ✅ 已完成 | 多行续行、媒体占位符 type-and-keep、列名别名、missing_media、自研 HTML 分块 tokenizer |
| WeFlowParser（微信 WeFlow 导出 JSON/CSV/TXT/HTML） | ✅ 已完成 | ERD §4.3「输入（微信 WeFlow 导出）」四格式；`source==wechat`，结构签名 `canParse`，注册先于 WeChatParser；方向以 `isSend`/`is_sender`/HTML `s`/TXT `'我'` 为准；`图片消息`→image 产媒体索引（mediaPath==sourceRef）、`文件/引用消息`→text；JSON/HTML Unix 秒、CSV ISO8601 UTC、TXT 本地墙钟；BOM/HTML 实体处理；missing_media/malformed_row/empty_message/empty_file 告警、JSON 非法/CSV 缺列→ParseException。合成夹具非真实会话 |
| DataPreprocessor | ✅ 已完成 | 清洗/去重（内容复合键）/稳定升序 |
| ParserRegistry / DataImportService | ✅ 已完成 | 调度 + 单文件失败隔离（所有 Exception）+ 组装 Conversation；告警/媒体索引跨文件累积并透出；file_too_large（>200MB）拒绝 |
| InstagramParser（Meta DYI JSON） | ✅ 已完成 | `message_1.json`（participants+messages）；文本 + photos/videos/gifs/audio_files 分条 + 媒体索引；timestamp_ms→UTC；jsonDecode 错误→ParseException；missing_media |
| WeiboParser（direct_messages API v2 JSON） | ✅ 已完成 | ERD §4.3 输入契约；`created_at` 微博/Twitter 风格带时区归一 UTC + Unix 秒/毫秒；`sender_screen_name`/`sender_id` 命中 myIdentifiers 判 isFromMe；纯文本无媒体；缺时间→malformed_row、空文本→empty_message、JSON 非法/缺数组→ParseException |
| IMessageParser（chat.db 只读） | ✅ 已完成 | `sqlite3` 游标逐行流式；message⋈handle；`date`→appleDateToDateTime；is_from_me/targetContact；`text` 为空时回退解码 `attributedBody`（streamtyped，ERD §4.2）；确无正文→empty_message（设备端原生库 `sqlite3_flutter_libs` 已声明于 pubspec，`flutter pub get` 解析通过；真机绑定验证待设备） |
| PhotoExifParser（照片 EXIF） | ✅ 已完成 | `exif` 包；`DateTimeOriginal`→时间戳（含 0 年/月/日/越界拒绝），缺失→missing_exif；`extractLocation` 时显式解析 GPS IFD 换算十进制经纬度写入 metadata（含 NaN 保护，ERD §6.2 line734）；损坏/截断图片兜底 corrupt_photo 告警（RangeError 不逃逸）；照片即媒体（mediaPath==sourceRef，available 恒真）；fixture 由 Dart 直构 EXIF/TIFF 字节（无需外部工具） |
| MediaStore 分层落地（ERD §4.4） | ✅ 已完成 | `MediaTier` 门控字节拷贝（textOnly 不拷 / photoAndVoice 图+语音 / all 全部）+ `storedPath` 回填；`MediaStorageMode`（copyIntoSandbox / referenceInPlace）；源缺失→available=false 不中断；文件名冲突去重；`isExcludedFromBackup` 经注入钩子（宿主 no-op/iOS 原生），仅首次拷贝前触发一次；入参不可变。原生沙盒/bookmark 装配分阶段推进 |
| 导入状态管理（Riverpod） | ✅ 已完成 | `ImportPhase`/`ImportState`/`ImportNotifier`/`importStateProvider`（ERD §5.2）；空列表转 failed |
| Apple 时间转换 | ✅ 已完成 | `appleDateToDateTime`（1e12 阈值，秒/纳秒） |
| 单元测试 + fixtures | ✅ 已完成 | 覆盖 SPEC §7 用例 1-6、7-13 + 评审补充用例 + 合成 chat.db（含 attributedBody 单字节/0x81 扩展长度回退 + 畸形 BLOB 降级）+ Dart 直构 EXIF/TIFF fixture（含 GPS IFD）+ MediaStore 分层/去重/缺失/钩子临时目录用例 + WeiboParser 时区/Unix/isFromMe/告警用例 + WeChat 10 万条流式吞吐集成测试（ERD §7.3）+ WeFlow 四格式（JSON/CSV/TXT/HTML）结构等价合成夹具（canParse 探测/类型方向/媒体 join key/missing_media/BOM/HTML 实体/registry 路由）；`flutter test` 122/122、`flutter analyze` 0 警告 |

### 分阶段推进（需真机 / 大样本 / 待补文档，本切片不含）
- [ ] WeiboParser 输入契约 Owner 终审（已按微博 API v2 `direct_messages` 结构在 ERD §4.3 固化并实现，待 Owner 确认真实导出格式；若官方格式变更再增补版本说明）
- [ ] IMessageParser 真机绑定验证（`sqlite3_flutter_libs` 已加入 pubspec 并解析通过；解析逻辑宿主已验证，剩真机 chat.db 读取端到端验证）
- [ ] IMessageParser 完整 `attributedBody` typedstream 解码器（保留富文本/内联附件占位；现为纯文本尽力回退，需真机导出样本验证）
- [ ] MediaStore 原生装配（iOS 沙盒目录 path_provider + `isExcludedFromBackup` 原生实现 / macOS security-scoped bookmark 持久化；分层落地核心逻辑已完成并宿主验证）
- [ ] file_picker 导入 UI（Phase 4 视觉稿统一；状态层 `import_providers` 已就绪）
- [ ] 5GB 峰值内存采样压测（< 300MB，需设备/CI 内存采样）；**10 万条吞吐 + 流式懒消费已在宿主验证**（`test/integration/wechat_streaming_perf_test.dart`，ERD §7.3 模板，≥5000 msg/min 达标）

---

## 📋 模块 003 详细状态

### 文档信息
| 文档类型 | 文件名 | 状态 | 完成时间 | 批准时间 | 文件路径 |
|----------|--------|------|---------|---------|---------|
| PRD | PRD-Persona-Generation-003-20260802.md | ✅ 已批准 | 2026-08-02 | 2026-08-02 | docs/prd/PRD-Persona-Generation-003-20260802.md |
| ERD | ERD-Persona-Engine-003-20260802.md | ✅ 已批准 | 2026-08-02 | 2026-08-02 | docs/erd/ERD-Persona-Engine-003-20260802.md |
| Spec | SPEC-Persona-Builder-003-20260802.md | ✅ 已批准 | 2026-08-02 | 2026-08-02 | docs/spec/SPEC-Persona-Builder-003-20260802.md |

### 三文档齐全检查
- ✅ PRD 已创建（草稿）
- ✅ ERD 已创建（草稿）
- ✅ Spec 已创建（草稿）
- ✅ 编号一致（003）
- ✅ 日期一致（20260802）
- ✅ 头部关联字段互指正确（PRD↔ERD↔Spec）
- ✅ 状态：已批准（2026-08-02，多轮评审至 v1.0.4）
- ✅ **三文档齐全，开发状态：已完成**（TDD 编码，测试通过）

### 范围摘要
- 模块定位：从模块 002 的 `Conversation` **确定性地**蒸馏出五层 Persona（硬规则/身份/表达风格/情感逻辑/关系行为），产出可版本化的 `.persona`（JSON）与 system prompt 渲染。
- 关键约束：纯 Dart、离线、**无 LLM/无网络**、可完全单元测试；LLM 增强留待 Phase 3 之后。
- 核心组件：MemoriesAnalyzer / PersonaAnalyzer / PersonaBuilder（编排+版本+增量）/ PersonaCodec / PromptTemplate。
- 增量更新：以**消息内容键的 SHA-256 哈希**（底层键 `source|senderId|timestamp.iso8601|content|type` 对齐模块 002 `DataPreprocessor` 去重键）去重保证幂等；`.persona` 存哈希不落原文；`revisions` 连续追加版本轨迹；硬规则永不被分析结果覆盖。
- 目标人物切分：以 `Message.isFromMe` 为主判据（依赖模块 002 可靠填充）；守卫降级门控**按分支拆分**——方向不可判定分支（`isFromMe` 全为 `false`）需 `personSenderIds` 与 `myIdentifiers` 皆未传方触发，多方会话分支（目标发送者 >1）只要 `personSenderIds` 未传即触发（`myIdentifiers` 不抑制）；触发时低置信 + `segmentationResolved=false`、不臆断并入；v1 仅正式支持 1:1 会话。

### 开发进度
| 组件 | 状态 | 说明 |
|------|------|------|
| 数据模型 | ✅ 已实现 | `evidence.dart`（Confidence/TermStat/Evidence/PersonaTag）、`persona_layers.dart`（五层）、`memories.dart`、`persona.dart`（Persona/PersonaSource/SourceRevision）；全部 `@immutable` + 值相等 |
| text_stats | ✅ 已实现 | `messageKeyHash`（SHA-256）、n-gram/标点/emoji/关键词统计、情感比率、字素簇截断；内置停用词/情感/称呼/纪念词表 |
| MemoriesAnalyzer | ✅ 已实现 | 时间线（UTC 分桶）/关键事件/偏好提取，带证据 |
| PersonaAnalyzer | ✅ 已实现 | 表达/情感/关系三层 + `deriveTags`（风格/情感/关系/偏好标签）|
| PersonaBuilder | ✅ 已实现 | `splitBySender`（两分支守卫门控）、`build`/`update`（键哈希去重幂等、增量聚合合并、revisions 连续、硬规则不覆盖、确定性 id、epoch0 时钟哨兵）|
| PersonaCodec | ✅ 已实现 | `PersonaJsonCodec` encode/decode 全字段校验（schema/version/ratio clamp/revisions 连续/哈希分隔符/label 非空/防御性截断）|
| PromptTemplate | ✅ 已实现 | `DefaultPromptTemplate` 确定性渲染，三档语气 + maxChars 截断 |
| 测试 | ✅ 已通过 | 65 用例（含集成全链路）；模块覆盖率 **95.3%**（>80%）；`flutter analyze` **0 警告** |

### 待办
- [x] 三文档评审
- [x] 三文档批准（2026-08-02；文件日期即批准日期，无需重命名）
- [x] 编写测试用例 → 实现 → 验证（TDD，全部通过）
- [ ] 存储落盘（模块 008）：`.persona` 加密持久化（本模块只产字节）
- [ ] LLM 增强（Phase 3 之后）：当前为纯规则/统计基线 → 由**模块 004** 承接

---

## 📋 模块 004 详细状态

### 文档信息
| 文档类型 | 文件名 | 状态 | 完成时间 | 批准时间 | 文件路径 |
|----------|--------|------|---------|---------|---------|
| PRD | PRD-LLM-Integration-004-20260802.md | ✅ 已批准 | 2026-08-02 | 2026-08-04 | docs/prd/PRD-LLM-Integration-004-20260802.md |
| ERD | ERD-LLM-Integration-004-20260802.md | ✅ 已批准 | 2026-08-02 | 2026-08-04 | docs/erd/ERD-LLM-Integration-004-20260802.md |
| Spec | SPEC-LLM-Integration-004-20260802.md | ✅ 已批准 | 2026-08-02 | 2026-08-04 | docs/spec/SPEC-LLM-Integration-004-20260802.md |

### 三文档齐全检查
- ✅ PRD 已批准
- ✅ ERD 已批准
- ✅ Spec 已批准
- ✅ 编号一致（004）
- ✅ 日期一致（20260802）
- ✅ 头部关联字段互指正确（PRD↔ERD↔Spec）
- ✅ 状态：**已批准**（Project Owner，2026-08-04）
- ✅ **开发状态：已完成**（PR #14 merged to `main` on 2026-08-05; host TDD suite 291 passing, `flutter analyze` clean; iOS on-device signing/install verified. Remaining: on-device persona-quality pass + T21 real-device smoke, tracked as ADR-005 validation, not blocking.）

### 范围摘要
- 模块定位（v1.1 拓宽为"LLM 集成"，两大支柱）：**(A) 蒸馏**——以 LLM 从模块 002 `Conversation` 产出忠实五层 Persona，映射进模块 003 现有 `Persona` 契约；**(B) 对话引擎（ChatEngine）**——以 `Persona` 渲染的 system prompt 驱动多轮流式对话（滑窗上下文、硬规则强制、本地/云端切换）。二者**共享 Runtime 抽象层**（本地 LiteRT 默认 + 云端 API opt-in），原「005 云端 API 集成」已并入本模块。
- 立项依据（ADR-004）：统计引擎（003）产出偏单薄/易失真（"不像本人"），LLM 蒸馏更忠实（签名特征、真实例句、诚实标注"原材料不足"）；统计引擎降级为**预处理 + 离线兜底**。端侧栈定为 **flutter_gemma / LiteRT-LM**（ADR-005）。
- 关键约束：**输出契约不变**（复用 `Persona` + `PromptTemplate.render()`，不改对外形状）、**不重写模块 003**、模型就绪归**模块 007**（经 `getActiveModelHandle()`）、默认本地/云端显式授权、诚实优先（不编造事实）、隐私（原文不出设备、`.persona` 仅存哈希 + 短示例）；对话无统计兜底（无模型明确提示）。
- 可验证性：提供**开发者调试台（dev-only harness）**在真机手动"下载模型→蒸馏→对话"评审"像不像本人"；正式聊天 UI 属模块 006。
- 测试策略变更：LLM 非确定性 → 由 byte-identical 确定性断言改为**契约/结构断言 + mock Runtime + 快照/人工评审**；质量验收须真机（模拟器仅 CPU 冒烟，ADR-005）。

### 待办
- [x] 三文档评审
- [x] 三文档批准（批准后方可编码）
- [x] 编写测试用例（mock Runtime）→ 实现 → 验证
- [x] Runtime 抽象层实现（LiteRtRuntime[flutter_gemma] — 切片 4c / CloudRuntime — 切片 4b；统计兜底经 `DefaultLlmPersonaBuilder` 内置，ADR-004）
- [x] ChatEngine 实现（滑窗上下文 / 流式 / 硬规则强制 / 本地云端切换）— 切片 3（宿主 TDD T14–T20）
- [x] 开发者调试台（dev-only）— 切片 5（`LlmHarnessScreen`：安装 SmolLM→激活→蒸馏→对话，真机人工评审）
- [x] 与模块 007（模型管理，前置依赖）对接；模块 006（聊天界面）留待其自身开发
- [ ] On-device quality validation (distill → chat → judge "像不像本人") + T21 real-device smoke — ADR-005, non-blocking

---

## 📋 模块 007 详细状态

### 文档信息
| 文档类型 | 文件名 | 状态 | 完成时间 | 批准时间 | 文件路径 |
|----------|--------|------|---------|---------|---------|
| PRD | PRD-Model-Management-007-20260802.md | ✅ 已批准 | 2026-08-02 | 2026-08-04 | docs/prd/PRD-Model-Management-007-20260802.md |
| ERD | ERD-Model-Management-007-20260802.md | ✅ 已批准 | 2026-08-02 | 2026-08-04 | docs/erd/ERD-Model-Management-007-20260802.md |
| Spec | SPEC-Model-Management-007-20260802.md | ✅ 已批准 | 2026-08-02 | 2026-08-04 | docs/spec/SPEC-Model-Management-007-20260802.md |

### 三文档齐全检查
- ✅ PRD 已批准
- ✅ ERD 已批准
- ✅ Spec 已批准
- ✅ 编号一致（007）
- ✅ 日期一致（20260802）
- ✅ 头部关联字段互指正确（PRD↔ERD↔Spec）
- ✅ 状态：**已批准**（Project Owner，2026-08-04）
- ✅ **开发状态：已完成**（PR #14 merged to `main` on 2026-08-05; host TDD suite green, `flutter analyze` clean; `ModelHandle.filePath` contract with module 004 settled per DD-001. Remaining: staged real-device download validation, non-blocking.）

### 范围摘要
- 模块定位：端侧 LLM 模型的**下载 / 存储 / 切换 / 查询**，以**薄封装**隔离 `flutter_gemma` 模型安装 builder API（`installModel().fromNetwork().install()`；旧 `ModelFileManager` 为 legacy facade，ADR-005，不自造下载器）；向模块 004 暴露稳定的 `ModelHandle` / `ModelRepository.getActiveModelHandle()` 契约。
- 提前依据：**从 Phase 4 提前至 Phase 3**，作为模块 004 本地默认路径的**前置依赖**——没有就绪模型，004 的本地蒸馏/对话无法真机验证。
- 包含：ModelCatalog（SmolLM 135M / Gemma 3 1B / Gemma 4 E2B）、下载状态机 + 断点续传 + 进度流、存储/占用/删除、激活/切换、设备能力探测（Metal/内存档、引擎选择）、HF token（Secure Storage）。
- 不包含：推理/对话/蒸馏（模块 004）、模型管理**正式 UI**（Phase 4 / 模块 006 设置）、云端 API Key、加密/排除备份（模块 008，预留注入点）。
- 关键约束（ADR-005）：iOS 16+/entitlements/静态链接；模拟器仅 CPU（大模型不可运行）→ 质量验收须真机；模型落盘内存映射；社区包锁版本。
- 测试策略：宿主 mock 下载器 + 内存文件系统做状态机/契约断言（>80%）；SmolLM 135M 冒烟；真机 Gemma 3 1B 分阶段。

### 待办
- [x] 三文档评审
- [x] 三文档批准（批准后方可编码）
- [x] 编写测试用例（mock 下载/文件系统）→ 实现 → 验证
- [x] `ModelRepository` / `ModelInstaller`（flutter_gemma 封装）/ `ModelStore` / `DeviceCapabilities` 实现
- [x] iOS 平台装配（entitlements / Info.plist / Podfile 静态链接）
- [x] 与模块 004（消费 `ModelHandle`）对接
- [ ] Staged real-device download validation (SmolLM smoke → Gemma 3 1B) — non-blocking

---

## 📋 模块 006 详细状态

### 文档信息
| 文档类型 | 文件名 | 状态 | 完成时间 | 批准时间 | 文件路径 |
|----------|--------|------|---------|---------|---------|
| PRD | PRD-Chat-Interface-006-20260805.md | 📝 草稿 | 2026-08-05 | — | docs/prd/PRD-Chat-Interface-006-20260805.md |
| ERD | ERD-Chat-Interface-006-20260805.md | 📝 草稿 | 2026-08-05 | — | docs/erd/ERD-Chat-Interface-006-20260805.md |
| Spec | SPEC-Chat-Interface-006-20260805.md | 📝 草稿 | 2026-08-05 | — | docs/spec/SPEC-Chat-Interface-006-20260805.md |

### 三文档齐全检查
- ✅ PRD 已创建（草稿）
- ✅ ERD 已创建（草稿）
- ✅ Spec 已创建（草稿）
- ✅ 编号一致（006）
- ✅ 日期一致（20260805）
- ✅ 头部关联字段互指正确（PRD↔ERD↔Spec）
- ⚠️ 状态：草稿，**待评审批准**
- 🚫 **开发状态：阻塞**（待三文档批准 + 依赖模块 009 `PersonaRepository`）

### 范围摘要
- 模块定位（Phase 4）：正式**聊天界面**——`ChatScreen` 消费模块 004 `ChatEngine`（流式对话 / 硬规则强制 / 本地云端切换）与模块 007 `getActiveModelHandle()`，以模块 009 `PersonaRepository` 载入 `Persona`；**新增 SQLite 聊天历史**（`ChatHistoryRepository`，本模块独有）持久化多会话消息。
- 关键组件：`ChatScreen` 组件树、`ChatSessionNotifier`（会话状态 + 流式增量 + 错误映射）、`ChatHistoryRepository`（SQLite，`sqflite_common_ffi` 宿主接缝，008 加密 `DatabaseFactory` 注入点）。
- 关键约束：system prompt **仅**由 `PromptTemplate.render()` 产生（对齐 004 SPEC §2.4，对话无统计兜底）；每类 `RuntimeError`/守卫拦截映射为 `ChatStatus` 错误态；无模型/最大隐私/未授权明确提示不静默。
- 依赖：004（ChatEngine/Runtime）、007（激活模型）、009（`PersonaRepository` 载入 Persona）、003（`Persona` 契约）；008 加密为预留注入点。

### 待办
- [ ] 三文档评审
- [ ] 三文档批准（批准后方可编码）
- [ ] 编写测试用例（C1–C34）→ 实现 → 验证
- [ ] `ChatHistoryRepository` SQLite 落地（宿主 `sqflite_common_ffi`）
- [ ] `ChatScreen` + `ChatSessionNotifier`（流式 / 错误映射）
- [ ] 与模块 009（`PersonaRepository`）对接

---

## 📋 模块 009 详细状态

### 文档信息
| 文档类型 | 文件名 | 状态 | 完成时间 | 批准时间 | 文件路径 |
|----------|--------|------|---------|---------|---------|
| PRD | PRD-Persona-Library-009-20260805.md | ✅ 已批准 (v1.1.1) | 2026-08-05 | 2026-08-07 | docs/prd/PRD-Persona-Library-009-20260805.md |
| ERD | ERD-Persona-Library-009-20260805.md | ✅ 已批准 (v1.1.1) | 2026-08-05 | 2026-08-07 | docs/erd/ERD-Persona-Library-009-20260805.md |
| Spec | SPEC-Persona-Library-009-20260805.md | ✅ 已批准 (v1.1.1) | 2026-08-05 | 2026-08-07 | docs/spec/SPEC-Persona-Library-009-20260805.md |

### 三文档齐全检查
- ✅ PRD 已批准（v1.1.1，2026-08-07）
- ✅ ERD 已批准（v1.1.1，2026-08-07）
- ✅ Spec 已批准（v1.1.1，2026-08-07）
- ✅ 编号一致（009）
- ✅ 日期一致（20260805）
- ✅ 头部关联字段互指正确（PRD↔ERD↔Spec）
- ✅ 状态：**三文档已批准**（Project Owner，2026-08-07）
- 🚧 **开发状态：开发中**（三文档批准，解除阻塞，进入 TDD 编码）

### 范围摘要
- 模块定位（Phase 4）：**Persona 持久化 + 人物库 + 蒸馏流程 + 导入入口 UI**——填补当前"仅内存 `PersonaJsonCodec`、无落盘"的缺口，并**填补 Phase-4 导入 UI 缺口**（模块 002 交付了解析/数据层但推迟了导入界面，无模块认领；今日生产环境无法导入真实聊天记录，仅 `kDebugMode` harness 用硬编码样例）。新增 `PersonaRepository`（由注入的 `PersonaCodec` + `PersonaDirectory`〔宿主用 `MemoryPersonaDirectory`〕+ `PersonaBytesTransform`〔008 加密接缝〕组合）；人物库屏（列表/删除/打开）；蒸馏流程屏（**导入步骤 → 蒸馏**，驱动模块 004 `LlmPersonaBuilder`）。
- 关键组件：`PersonaRepository`（读时派生 `PersonaSummary`）、`PersonaLibraryNotifier`、`DistillNotifier`；新增 `PersonaStoreException`；**新增 `FilePickerFacade` 接缝**（默认 `file_picker`，宿主用 `FakeFilePicker`），复用模块 002 `ImportNotifier` 驱动导入（不新增导入状态类型）。
- 关键约束：不重写模块 002/003/004（只读复用 `Persona` 契约、`LlmPersonaBuilder`、以及 002 的解析器/`DataImportService`/`ImportNotifier`——009 仅新增**驱动它们的导入 UI**，不改任何解析器、不新增数据源）；持久化默认明文，008 经 `PersonaBytesTransform` 注入加密；`PersonaRepository` 为模块 006 的 Persona 载入来源（共享契约）。
- 依赖：003（`Persona`/`PersonaCodec`）、004（`LlmPersonaBuilder` 蒸馏）、002（`Conversation` 输入 + `ImportNotifier`/`importStateProvider`/`DataImportService` 导入数据层，复用不改）、007（模型就绪）；008 加密为预留注入点。新增 `file_picker` 依赖（ERD-002 原仅列为候选）。

### 待办
- [x] 三文档评审（v1.1.1，含导入 UI 范围扩展）
- [x] 三文档批准（批准后方可编码）
- [ ] 编写测试用例（C1–C25，含导入步骤 C22–C25）→ 实现 → 验证
- [ ] `PersonaRepository` + `PersonaDirectory`（宿主内存实现）落地
- [ ] 人物库屏 + 蒸馏流程屏（`PersonaLibraryNotifier`/`DistillNotifier`）
- [ ] 导入步骤：`FilePickerFacade`（`pickFiles`/`pickDirectory`，`file_picker: ^8.0.0`）+ 复用 002 `ImportNotifier`；目录源（iMessage db / Photo-EXIF）iOS security-scoped 访问（ERD-002 §676）；`file_picker` 加入 `pubspec.yaml`
- [ ] 与模块 006（Persona 载入）/ 004（蒸馏）/ 002（导入数据层）对接

---

## 📋 模块 010 详细状态

### 文档信息
| 文档类型 | 文件名 | 状态 | 完成时间 | 批准时间 | 文件路径 |
|----------|--------|------|---------|---------|---------|
| PRD | PRD-Settings-010-20260805.md | ✅ 已批准 v1.0.2 · 🔶 v1.0.3 待复批 | 2026-08-06 | 2026-08-05（v1.0.2）| docs/prd/PRD-Settings-010-20260805.md |
| ERD | ERD-Settings-010-20260805.md | ✅ 已批准 v1.0.2 · 🔶 v1.0.3 待复批 | 2026-08-06 | 2026-08-05（v1.0.2）| docs/erd/ERD-Settings-010-20260805.md |
| Spec | SPEC-Settings-010-20260805.md | ✅ 已批准 v1.0.2 · 🔶 v1.0.3 待复批 | 2026-08-06 | 2026-08-05（v1.0.2）| docs/spec/SPEC-Settings-010-20260805.md |

> 🔶 **v1.0.3 = 编码后文档-代码对账（2026-08-06，作者 Claude，未经 Owner 复批）**：新增 `cloudEndpoint`/`setCloudEndpoint`、`ModelManagerNotifier.deactivate`、v1-UI 说明、`allowOverTier` 无条件等增量（PR #17 评审 Major 2）。契约在 v1.0.2 批准后有所增长，**待 Project Owner 对 v1.0.3 增量复批**后方可将状态整体转"已批准 v1.0.3"。

### 三文档齐全检查
- ✅ PRD 已批准（v1.0.2）· 🔶 v1.0.3 增量待复批
- ✅ ERD 已批准（v1.0.2）· 🔶 v1.0.3 增量待复批
- ✅ Spec 已批准（v1.0.2）· 🔶 v1.0.3 增量待复批
- ✅ 编号一致（010）
- ✅ 日期一致（20260805）
- ✅ 头部关联字段互指正确（PRD↔ERD↔Spec）
- ✅ 状态：**已批准**（2026-08-05，Project Owner）
- 🚧 **开发状态：开发中**（TDD 进行）

### 范围摘要
- 模块定位（Phase 4）：**设置界面**——模块 007 的**模型管理正式 UI**（目录/下载进度/激活/删除，取代 004 dev-only harness）+ 运行模式选择（本地/云端 `RuntimeChoice`）+ 云端 API Key 授权。新增 `AppSettings`/`RuntimeChoice`/`SettingsRepository`/`SecureKeyStore`。
- 关键组件：`SettingsNotifier`（运行模式 / 温度 / 隐私档）+ `ModelManagerNotifier`（消费 007 `ModelRepository` 安装事件流）；非敏感设置经 Hive，密钥经 Flutter Secure Storage。
- 关键约束：honors 真实 `InstallErrorKind` 枚举成员；不自造下载器（薄 UI on 007）；标记 DD-002（`freeBytes()` 生产不可实现）+ `InMemoryModelStore`→磁盘落地缺口，待 007 补齐。
- 依赖：007（`ModelRepository` 模型管理）、004（`PersonaRuntimeMode`/云端授权门控）；008 加密为密钥存储承接。

### 待办
- [x] 三文档评审
- [x] 三文档批准（2026-08-05，Project Owner）
- [x] `SettingsRepository`（Hive）+ `SecureKeyStore`（Secure Storage）落地
- [x] 设置屏 + `ModelManagerNotifier`（消费 007 安装事件流）+ 模型管理 UI 落地
- [x] 与模块 007（模型管理）/ 004（运行模式）对接
- [ ] 编写测试用例 → 实现 → 验证（TDD 进行中，核心已覆盖；下列 v1 延后项待补）
- [ ] HF token 输入字段（v1 从设置屏延后）
- [ ] 温度（Advanced）滑块（v1 延后）
- [ ] 超档安装二次确认对话框（v1 恒传 `allowOverTier: true`，确认流延后）
- [ ] 真机 UAT（安装 Gemma 3 1B → 激活 → 006/009 读取模式/授权）

---

## 📝 状态标识说明

### 文档状态
- ⚪ **待创建**：文档尚未创建
- 📝 **草稿**：文档正在编写中
- 🔍 **评审中**：文档已提交评审
- ✅ **已批准**：文档已批准通过
- ❌ **需修改**：文档需要修改后重新评审

### 三文档齐全
- ✅ **是**：PRD + ERD + Spec 三者齐全且批准
- ⚠️ **草稿完成**：三文档已创建但未评审批准
- ❌ **否**：缺少文档或未全部批准

### 开发状态
- 🚫 **阻塞**：文档不齐全，禁止开发
- ✅ **可开发**：三文档齐全，可以开始开发
- 🚧 **开发中**：正在实现代码
- ✅ **已完成**：开发完成并通过测试

---

## 🔄 文档生命周期

```
创建草稿 → 提交评审 → 评审反馈 → 修改完善 → 批准通过
    ↓         ↓         ↓         ↓         ↓
  📝 草稿   🔍 评审中  ❌ 需修改  🔍 评审中  ✅ 已批准
```

---

## ✅ 开发前置条件检查清单

在开始任何模块的开发前，必须确认：

### 文档完整性
- [ ] PRD 文档已创建
- [ ] ERD 文档已创建
- [ ] Spec 文档已创建
- [ ] 三文档编号一致（如 PRD-002、ERD-002、SPEC-002）

### 文档质量
- [ ] PRD 包含：背景、用户故事、功能清单、验收标准
- [ ] ERD 包含：技术目标、数据结构、接口设计、测试策略
- [ ] Spec 包含：接口定义、输入输出规格、测试用例

### 文档审批
- [ ] PRD 状态为"已批准"
- [ ] ERD 状态为"已批准"
- [ ] Spec 状态为"已批准"

### 文档关联
- [ ] PRD 关联了对应的 ERD 和 Spec
- [ ] ERD 关联了对应的 PRD 和 Spec
- [ ] Spec 关联了对应的 PRD 和 ERD

---

## 🚫 阻塞示例

### 示例 1：仅 PRD 批准
```
模块：002-数据导入
PRD：✅ 已批准
ERD：⚪ 待创建
Spec：⚪ 待创建
三文档齐全：❌ 否
开发状态：🚫 阻塞（缺少 ERD 和 Spec）
```

**解决方案**：编写 ERD-002 和 SPEC-002，通过评审后才能开发。

---

### 示例 2：三文档创建但未批准
```
模块：003-Persona 生成
PRD：🔍 评审中
ERD：📝 草稿
Spec：⚪ 待创建
三文档齐全：❌ 否
开发状态：🚫 阻塞（文档未全部批准）
```

**解决方案**：等待 PRD 评审通过，完成 ERD 编写和评审，创建并通过 Spec 评审。

---

## 📈 当前优先级

根据 ROADMAP.md 的开发计划，优先级顺序：

1. **模块 001**：项目初始化（Phase 0）
2. **模块 002**：数据导入（Phase 1）
3. **模块 003**：Persona 生成（Phase 2）
4. **模块 007**：模型管理（Phase 3，**提前**——004 本地路径前置依赖）
5. **模块 004**：LLM 集成（蒸馏 + 对话引擎 + Runtime 抽象层，已并入原「云端 API 集成」）（Phase 3）
6. **模块 006**：聊天界面（对话 + 聊天历史 SQLite）（Phase 4）
7. **模块 009**：人物库与蒸馏（Persona 持久化 + 库 + 蒸馏流程）（Phase 4）
8. **模块 010**：设置（模型管理 UI + 运行模式 + 云端授权）（Phase 4）
9. **模块 008**：数据安全（Phase 5）

---

## 🔗 相关文档

- [文档模板](prd/PRD-TEMPLATE.md)
- [项目配置](../CLAUDE.md)
- [开发路线图](overview/ROADMAP.md)

---

## 📅 更新记录

| 日期 | 时间 | 更新内容 | 更新人 |
|------|------|---------|--------|
| 2026-08-01 | 21:15 | 创建文档状态追踪表 | Claude |
| 2026-08-01 | 21:20 | 完成模块 001 三文档草稿，更新状态为"草稿" | Claude |
| 2026-08-01 | 21:45 | ✅ 批准模块 001 三文档，状态更新为"已批准"，三文档齐全 | Project Owner |
| 2026-08-01 | 22:30 | 创建模块 002（数据导入）三文档草稿，状态为"草稿"，待评审批准 | Claude |
| 2026-08-01 | 23:40 | 模块 002 第三轮评审（规模/存储）：三文档同步更新——流式解析（Stream<ParseEvent>）、三层解析产物、iOS 沙盒/macOS bookmark 存储模型、MediaTier 分层、性能指标改为吞吐/内存解耦。仍为草稿，待批准 | Claude |
| 2026-08-02 | 04:10 | 模块 002 第四轮评审（流式一致性）：ERD/Spec 同步——HTML 流式定案自研分块 tokenizer（package:html 无 SAX）、新增 MediaIndexEvent 明确媒体索引产出所有权与 storedPath 下游回填、补 Message↔MediaIndexEntry 单一真相来源关系、missing_media fixture 改 HTML。ERD/Spec 升至 v0.3，仍为草稿，待批准 | Claude |
| 2026-08-02 | 04:30 | 模块 002 评审 nit：明确唯一 join key 为 mediaPath==sourceRef，四元组降级为描述性字段、禁止用作关联键（突发连发冲突）。仍为草稿，待批准 | Claude |
| 2026-08-02 | — | 模块 001 收尾：PRD/ERD/Spec v1.1 对齐工具链版本（Flutter 3.38+/Dart 3.11+，Spec 环境检查阈值 >= 3.24 → >= 3.38）、iOS §8.4 验收通过、macOS 桌面明确延后；模块 001 开发状态更新为"已完成" | Claude |
| 2026-08-02 | — | ✅ 批准模块 002 三文档（v1.0，四轮评审后），开发状态转"开发中"；首个实现切片聚焦纯 Dart 核心（模型/WeChat 解析/预处理/导入编排/Apple 时间），原生解析器与存储/UI 分阶段推进 | Project Owner |
| 2026-08-02 | — | 模块 002 纯 Dart 核心切片实现完成：models（Message/Conversation/parse_result）+ WeChatParser（CSV/TXT/HTML 流式）+ DataPreprocessor + ParserRegistry + DataImportService + appleDateToDateTime；单测覆盖 SPEC §7 用例 1-5/7-13，`flutter test` 42/42、`flutter analyze` 0 警告、核心切片行覆盖 ≈94%。原生解析器/存储/UI 仍分阶段推进 | Claude |
| 2026-08-02 | — | 模块 002 切片扩展：新增导入状态层 `import_providers`（Riverpod，ERD §5.2）+ InstagramParser（Meta DYI JSON）；代理评审对照 SPEC §edge-cases/§5.1-5.2 修复 4 项合规缺口（乱码行 allowMalformed+malformed_row、单文件隔离扩至所有 Exception、告警/媒体索引透出 Conversation、空列表转 failed），并补 file_too_large。`flutter test` 58/58、`flutter analyze` 0 警告。Weibo 待补输入格式文档 | Claude |
| 2026-08-02 | — | 模块 002 新增 IMessageParser（ERD §4.2/§6.2）：只读 chat.db（`sqlite3` 游标流式）、message⋈handle、Apple 时间归一、is_from_me/targetContact、附件空文本告警；合成 chat.db fixture 纯宿主 TDD。`flutter test` 64/64、`flutter analyze` 0 警告。剩余分阶段项：PhotoExif（需二进制 jpg）、Weibo（待文档）、MediaStore/UI/大样本压测（需真机）、iMessage 设备端 sqlite3_flutter_libs 打包 | Claude |
| 2026-08-02 | — | 第二轮代理评审修复：IMessageParser 增 `attributedBody` 尽力回退（iOS14+/macOS11+ 正文常存该 BLOB，否则真机导出多被误判 empty_message；同步扩写 ERD §4.2）；InstagramParser jsonDecode 错误→ParseException、并支持 videos/gifs/audio_files。`flutter test` 65/65、`flutter analyze` 0 警告 | Claude |
| 2026-08-02 | — | 第三轮代理评审修复：补充 attributedBody 0x81 扩展长度前缀（>127 字节正文）与畸形 BLOB 降级为 empty_message 的测试用例。`flutter test` 67/67、`flutter analyze` 0 警告 | Claude |
| 2026-08-02 | — | 新增 PhotoExifParser（ERD §6.2 line734 / SPEC 用例6）：`exif` 包提取 DateTimeOriginal，缺失→missing_exif；extractLocation 时显式解析 GPS IFD 换算十进制经纬度入 metadata；fixture 以 Dart 直构 EXIF/TIFF 字节（含 GPS IFD），破除"需二进制样本"阻塞。`flutter test` 74/74、`flutter analyze` 0 警告 | Claude |
| 2026-08-02 | — | 第四轮代理评审修复（Critical）：损坏/截断图片令底层 exif 抛 RangeError（Error 非 Exception）会逃逸 DataImportService 的 on Exception 捕获而中断整批导入——PhotoExifParser 兜底捕获降级为 corrupt_photo 告警；另加 0 月/日越界拒绝、GPS NaN 保护；新增崩溃隔离用例。`flutter test` 76/76、`flutter analyze` 0 警告 | Claude |
| 2026-08-02 | — | 新增 MediaStore 分层落地（ERD §4.4）：`MediaTier` 门控字节拷贝 + `storedPath` 回填；copyIntoSandbox/referenceInPlace 双模式；源缺失→available=false 不中断整批；文件名冲突去重；`isExcludedFromBackup` 注入钩子（宿主 no-op/iOS 原生）仅首次拷贝前触发一次；入参不可变——将原"MediaStore 原生落地"阻塞项收窄至仅剩 path_provider/原生 bookmark 装配。`flutter test` 86/86、`flutter analyze` 0 警告 | Claude |
| 2026-08-02 | — | 新增 WeiboParser（ERD §3.4 file scope 最后一项）：ERD §4.3 固化微博 API v2 `direct_messages` 输入契约（非臆造，锚定真实结构）；实现 created_at 时区归一 UTC + Unix 秒/毫秒、sender→isFromMe、告警降级；注册进 registry（与 Instagram 结构互斥）。原"WeiboParser 待补文档"阻塞项转为 Owner 终审。`flutter test` 95/95、`flutter analyze` 0 警告 | Claude |
| 2026-08-02 | — | 落地 ERD §7.3 吞吐压测宿主版（WeChat 流式）：生成 10 万条 CSV，经事件流懒消费断言全解析、0 告警、≥5000 msg/min（实测 ~6s）。验证 openRead+LineSplitter 流式路径不全量载入。5GB 峰值内存采样仍需设备/CI。`flutter test` 96/96、`flutter analyze` 0 警告 | Claude |
| 2026-08-02 | — | iMessage 设备端打包推进：pubspec 加入 `sqlite3_flutter_libs ^0.5.24`（解析为 0.5.42），`flutter pub get` 通过；ERD §4.3 依赖表同步。原生 SQLite 库随 iOS/macOS 打包，剩真机 chat.db 端到端验证。`flutter test` 96/96、`flutter analyze` 0 警告 | Claude |
| 2026-08-02 | — | 新增 WeFlowParser：支持真实微信第三方导出工具 WeFlow 的四种格式（JSON/CSV/TXT/HTML）。ERD §3.2/§3.4/§4.3/§6.2 固化输入契约（锚定 WeFlow 1.0.3 真实结构，测试用结构等价合成夹具，不含真实会话）；`source==wechat`，结构签名 canParse，注册先于通用 WeChatParser，非 WeFlow 文件回落。方向以导出标志为准；图片产媒体索引（单一 join key），文件/引用归 text；四格式时间语义分别处理；BOM/HTML 实体反转义。新增 16 用例（canParse/类型方向/媒体缺失/BOM/实体/registry 路由 + 代理评审修复：CSV 引号内嵌换行行缓冲、TXT `[文件]`/裸文件名不误判为图片、JSON canParse 结构化校验）。`flutter test` 112/112、`flutter analyze` 0 警告 | Claude |
| 2026-08-02 | — | 提交 WeFlow 10 万条性能基准（`weflow_bench_test.dart`，四格式各 10 万条+5000 媒体，JSON ~2519k/HTML ~1982k/CSV ~1763k/TXT ~1147k msg/min，远超 ERD §7.3 基线）| Claude |
| 2026-08-02 | — | PR #9 评审收口（ERD v1.1）：`WeChatParser`（通用非 WeFlow 兜底）修复三处真实缺陷——CSV 引号内嵌换行按 record 累积不丢数据、`createtime` epoch 兼容不再整表丢弃、产 0 条消息必告警杜绝静默失败；`WeFlowParser` JSON 探测改整份文档结构判定（键顺序无关）、HTML 探测只读头部、空媒体 src 记 `missing_media`、文件/引用归 text 保留 `metadata['weflow_kind']`；新增 10 用例（WeChat 内嵌换行/epoch/静默失败 + WeFlow JSON 尾部键探测/kind metadata/五类告警码覆盖）。`flutter test` 122/122、`flutter analyze` 0 警告 | Claude |
| 2026-08-02 | — | 创建模块 003（Persona 生成）三文档草稿（PRD-Persona-Generation / ERD-Persona-Engine / SPEC-Persona-Builder，编号 003、日期 20260802、互相交叉引用）：定位为纯 Dart、离线、无 LLM 的确定性五层 Persona 生成引擎（记忆提取/性格分析/Builder 版本+增量/`.persona` 序列化/Prompt 渲染），输入契约锚定模块 002 `Conversation/Message`。矩阵行 003 → 📝草稿/📝草稿/📝草稿、⚠️草稿完成、🚫阻塞；同步 README 与 ROADMAP（Phase 2 文档就绪、待批准）。**未改任何源码/pubspec**，待评审批准后方可编码 | Claude |
| 2026-08-02 | — | 模块 003 草稿代理评审 + 修订（三文档升 v1.0.1，仍草稿）：修复 3 处阻塞项——(B1) 增量去重/幂等/证据键从 `Message.id` 改为**消息内容键**（对齐模块 002 `DataPreprocessor` 去重键，`Message.id` 跨导入不唯一/不稳定）；(B2) 定义 `PersonaTag` 并纳入 `Persona.tags` 与 `.persona` JSON；(B3) 空会话下 `TimelineSpan.start/end` 可空、`displayName` 回退 `defaultDisplayName`；及 (M1) `Persona.id` 确定性派生、UTC 分桶、ratio ε 容差、阈值前后置统一、幂等单测夹具修正等 nit。评审确认交叉引用/状态/五层命名/模块 002 类型均一致 | Claude |
| 2026-08-02 | — | 模块 003 PR #10 Owner 评审修订（三文档升 v1.0.2，仍草稿）：处理 3 🔴 + 1 🟡 + 3 minor——(🔴1 隐私) 证据/去重键持久化改存 **SHA-256 哈希**（`messageKeys`→`messageKeyHashes`、`mergedMessageKeys`→`mergedMessageKeyHashes`，加 `package:crypto`），`.persona` 不再落逐条原文、体积不膨胀，兑现文档自身隐私承诺；(🔴2 clock) 缺 `clock` 不再抛 `ArgumentError`，改取 epoch 0 哨兵、零配置 `build()` 可用（消解 Spec §3.2↔§6.1 自相矛盾）；(🔴3 切分) 目标人物切分以 `Message.isFromMe` 为主判据、`personSenderIds`/`myIdentifiers` 覆盖，默认路径不再污染人格；(🟡4 历史) 新增 `PersonaSource.revisions` 版本轨迹落实 PRD 用户故事 2；(minor) `Persona.id` 派生去首条消息/消息数消除边界敏感、`deriveTags` 增 `relation`/`memories` 覆盖关系/偏好标签、统一 `sourceSummary`↔`PersonaSource` 命名 | Claude |
| 2026-08-02 | — | 模块 003 PR #10 Owner 复审修订（三文档升 v1.0.3，仍草稿）：处理复审 2 🟡 + 3 minor（不阻塞设计批准、编码前解决）——(🟡A) `revisions` 统一为**连续 `[v1..vN]`**（`build` 写 v1、每 `update` 追加、末条==顶层、不裁剪），消除示例↔"每次追加"↔校验矛盾；(🟡B) 显式声明默认切分依赖模块 002 可靠填充 `isFromMe`，`splitBySender` 新增**方向/组成不可判定守卫**（返回 `resolved`）+ `PersonaSource.segmentationResolved`——不可判定/多方且无显式指定时降 `low`、不臆断并入；(minor C) `sampleExcerpt` 加长度校验（encode 端字素簇截断 60、decode 端防御性截断，+`package:characters`）；(minor D) 明确 `id` 的 `sortedTargetSenderIds`=切分后观察到的目标发送者集（非原始入参），界定超集稳定性范围；(minor E) 声明 v1 仅正式支持 1:1、群聊多人格拆分不在范围（多方走守卫）| Claude |
| 2026-08-02 | — | 模块 003 PR #10 Owner 复审修订（三文档升 v1.0.4，仍草稿）：处理 1 🟡——**守卫门控自相矛盾且多方分支存在漏洞**。拆分门控：方向不可判定分支（`isFromMe` 全为 `false`）门控 = `personSenderIds` **且** `myIdentifiers` 皆未传（`myIdentifiers` 确能解决方向、可抑制）；多方会话分支（目标发送者 >1）门控 = **仅** `personSenderIds` 未传——`myIdentifiers` 只判"谁是我"、无法在多个对方中指目标，**不得抑制**多方守卫。ERD §3.1/§4.2/§5.1/§5.2、SPEC §1.4/§3.1/§4.1/§6.1(+2 用例)/§6.2、PRD 功能1/§1.3 措辞统一 | Claude |
| 2026-08-02 | — | ✅ 批准模块 003 三文档（v1.0.4，多轮评审后）：PRD/ERD/SPEC 状态转"已批准"、批准日期 2026-08-02、批准人 Project Owner（文件日期即批准日期，无需重命名）。矩阵行 003 → ✅/✅/✅、三文档齐全、开发状态转"开发中"，解除阻塞，进入 TDD 编码 | Project Owner |
| 2026-08-02 | df40c4e | ✅ 模块 003 TDD 实现完成（PR #11）：五层模型 + text_stats/MemoriesAnalyzer/PersonaAnalyzer/PersonaBuilder/PersonaCodec/PromptTemplate 全部落地；65 用例通过、模块覆盖率 95.3%、`flutter analyze` 0 警告。矩阵行 003 开发状态 → ✅ 已完成 | Claude |
| 2026-08-02 | — | 创建模块 004（LLM Persona Builder，含 Runtime 抽象层）三文档草稿（PRD-LLM-Persona-Builder / ERD 同名 / SPEC 同名，编号 004、日期 20260802、互相交叉引用）：立项依据 ADR-004——统计引擎（003）产出偏单薄/易失真，改以 **LLM 蒸馏**产出忠实五层人格并映射进模块 003 现有 `Persona` 契约（**输出契约不变**、不重写 003）；含 **Runtime 抽象层**（本地 LiteRT 默认 + 云端 API opt-in），原「005 云端 API 集成」**已折叠并入 004**；默认本地/云端显式授权/诚实优先（不编造事实、标注"原材料不足"）/隐私（原文不出设备、`.persona` 仅哈希 + 短示例）；测试策略由 byte-identical 改为**契约/结构断言 + mock Runtime + 快照/人工评审**。矩阵行 004 → 📝/📝/📝、⚠️草稿完成、🚫阻塞；行 005 标 🔀 已折叠；同步 CLAUDE.md（ADR-004）、README、ROADMAP。**未改任何源码/pubspec**，待评审批准后方可编码 | Claude |
| 2026-08-02 | — | 新增 ADR-005（CLAUDE.md）：端侧 LLM 栈定为 **flutter_gemma v1.5.0（LiteRT-LM/MediaPipe 引擎）**——Google LiteRT-LM 官方 Flutter 通道，内置模型下载器/多引擎/流式/GPU；模块 007 薄封装其下载、模块 004 封装其 getActiveModel/createChat/generate；模型分档 SmolLM 135M（冒烟）/ Gemma 3 1B（设备默认 0.5GB）/ Gemma 4 E2B（2.4GB）；iOS 16+/entitlements/静态链接、模拟器仅 CPU（大模型不可运行）→ 质量验收须真机 | Claude |
| 2026-08-02 | — | **模块 007（模型管理）提前至 Phase 3** 并创建三文档草稿（PRD/ERD/SPEC-Model-Management-007，编号 007、日期 20260802、互相交叉引用）：作为模块 004 本地默认路径的**前置依赖**（无就绪模型则 004 无法真机验证）；以薄封装隔离 flutter_gemma `ModelFileManager`（不自造下载器），暴露 `ModelHandle`/`getActiveModelHandle()` 契约；含 ModelCatalog/下载状态机+断点续传/存储/激活切换/设备能力探测/HF token；不含推理（004）与正式 UI（Phase 4）。矩阵行 007 → 📝/📝/📝、⚠️草稿完成、🚫阻塞；优先级列表 007 置于 004 之前；同步 README、ROADMAP。**未改任何源码/pubspec**，待评审批准后方可编码 | Claude |
| 2026-08-02 | — | **模块 004 拓宽为"LLM 集成"**并三文档改版 v1.1（文件 PRD/ERD/SPEC-LLM-Persona-Builder → **LLM-Integration**，`git mv` 重命名）：在蒸馏之外**新增对话引擎 ChatEngine**（以 `Persona` 的 system prompt 驱动多轮流式对话——滑窗上下文、聊天时硬规则强制、本地/云端切换、取消/错误分类；对话**无统计兜底**，无模型明确提示）；接入 **flutter_gemma/模块 007**（ADR-005）为本地推理底座与前置依赖；新增**开发者调试台（dev-only harness）**供真机质量评审；PRD 加故事 6 + 功能 2.5/C、ERD 加 §3.5/§4.2.5/§5.4/§6.1 对话设计 + 流式 Runtime、SPEC 加 §2.4 + 边界 5.10–5.15 + 用例 T14–T21 + 对话性能。矩阵/详情/优先级同步。**未改任何源码/pubspec**，仍草稿待批准 | Claude |
| 2026-08-04 | — | **PR #13 Owner 评审修订**（四项阻塞项）：(🔴1) 删除编造的"Gemma 4 E2B iOS Metal 实测 ~56 tok/s"（ADR-005/ERD-004 §7/SPEC-004 §7）→ 改为「> 5 tokens/s，iOS Metal 具体吞吐以真机基线为准，不预设未实测数值」；(🔴2) 模块 007 封装对象由 legacy `ModelFileManager` 改为**现代 builder API** `installModel().fromNetwork().install()`（旧类降为 legacy facade，核实 v1.5.x 公开 API）；(🔴3) `flutter_gemma` 为 **MIT** 已核实属实（LICENSE：Copyright 2024 Sasha Denisov），保留；(🔴4) PRD-004 版本头 v1.0→v1.1、§7 编号 7.2→7.1。另非阻塞：锁版本 v1.5.0→**v1.5.2**（已核实当前版）。004 三文档升 v1.1.1、007 三文档升 v1.0.1，均仍草稿。范围扩张（ChatEngine/模块 007/ADR-005）待 Owner 明确认可 | Claude |

| 2026-08-04 | — | **新增设计债务登记表** `docs/overview/DESIGN-DEBT.md`，登记模块 007 设备/原生 slice 发现的两处契约缺口（不改契约、待模块 004 设计时定夺）：**DD-001** `flutter_gemma` v1.5.2 自管落盘且不暴露 `filePath`（推理经 `getActiveModel()`），ERD/SPEC-007 §3.4 `ModelHandle.filePath` 生产不可诚实兑现——当前宿主实现用合成路径通过测试；**DD-002** `dart:io`/插件均无可用磁盘余量 API，生产 `ModelStore.freeBytes()`（E2 空间预检）暂无法实现，仅 `InMemoryModelStore` 供宿主测试。已在 ERD-007 §3.4/§4.3 与 ERD-004 §1.2（`LiteRtRuntime` 消费点）以 `⚠️ 契约缺口：见 DD-00x` 反向链接。**未改源码/契约** | Claude |

| 2026-08-04 | — | ✅ **批准模块 004（LLM 集成）与模块 007（模型管理）三文档**（Project Owner）：PRD/ERD/SPEC 状态转"已批准"、批准日期 2026-08-04；范围扩张（ChatEngine / 模块 007 前置 / ADR-005 / 004 并入原 005）经 Owner 明确认可。矩阵行 004 → ✅/✅/✅、开发状态"开发中"（进入 TDD）；行 007 → ✅/✅/✅、开发状态"开发中"（宿主核心 + 设备 slice 已落地）。DD-001（`ModelHandle.filePath`）随 004 设计定夺 | Project Owner |

| 2026-08-04 | — | **模块 004 定夺 DD-001（选项 A）**：`ModelHandle.filePath` → 可选，`PersonaRuntime` 抽象层不依赖 `filePath`，`LiteRtRuntime` 经 flutter_gemma `getActiveModel()` 加载（代码改动随设备 slice 落地）；更新设计债务登记表 DD-001 状态为🟢已定夺 | Claude |
| 2026-08-04 | — | **模块 004 TDD 切片 1（Runtime 抽象层）**：`lib/services/llm/persona_runtime.dart`（`PersonaRuntime` 抽象 + `RuntimeSource`/`RuntimeError`/`RuntimeResult`/`RuntimeCapabilities`/`RuntimeException`，ERD-004 §3.4/§4.1）+ `mock_runtime.dart`（`MockRuntime`：固定响应/token 流、prompt 记录、错误注入短路不发起调用、取消即停）。宿主 TDD 12 用例（含 SPEC T18 取消语义），`flutter test` 225/225、`flutter analyze` 0 警告。抽象层不触碰 `filePath`（DD-001） | Claude |
| 2026-08-04 | — | **模块 004 TDD 切片 2a（蒸馏解析 + 映射）**：`lib/services/llm/distilled_persona.dart`（`DistilledPersona` 中间态 + `DistillationParser`：容忍散文/```json 围栏、字段从宽、整体不可解析抛 `DistillationFormatException`，SPEC §5.8）+ `persona_mapper.dart`（`PersonaMapper`：**原文接地**丢弃无支撑结论并据真实消息键哈希造 `Evidence`→落实 T5/§5.9；素材不足层置 low + `notes`→T4/§5.2；`hardRulesOverride` 永不覆盖）。**DD-003 定夺**：模块 003 `Persona` 加**可选** `notes`（`render` 不读、`PersonaJsonCodec` 往返，ERD-004 §4.3 预授权）。宿主 TDD +18 用例（parser 8 + mapper 10，覆盖 T2/T4/T5/T12/T13 映射级），`flutter test` 243/243、`flutter analyze` 0 警告（余 1 项为既有 test print） | Claude |
| 2026-08-04 | — | **模块 004 TDD 切片 2b（build 编排 + 兜底）**：`lib/services/llm/prompt_composer.dart`（`PromptComposer`：analyzer+builder 合一蒸馏 prompt，硬约束「仅用原文/不编造/素材不足归 `insufficientLayers`」，超长语料按 `maxChunkMessages` 分块）+ `fallback_runtime.dart`（`FallbackRuntime`：不推理，`generate` 恒 `modelUnavailable`/`source: fallback`，对话流经错误通道抛异常）+ `llm_persona_builder.dart`（`PersonaRuntimeMode`/`LlmBuildOptions`/`LlmPersonaBuilder` 抽象 + `DefaultLlmPersonaBuilder.build`：切分去重→分块 prompt→注入式 runtime 生成→解析→原文接地映射；空语料/`maxPrivacy`/云端未授权/生成解析失败→模块 003 统计兜底并 `notes` 标注；id 与统计引擎一致；分块数经 `onLog` 暴露不静默截断；非文本计入 `totalMessages` 不入蒸馏语料）。**update（T8/T9）留待切片 2c**（抽象暂只含 build，不发抛异常桩）。宿主 TDD +9 用例（MockRuntime，覆盖 T1/T3/T5/T6/T7/T10/T11 及解析失败兜底），`flutter test` 252/252、`flutter analyze` 0 警告（余 1 项为既有 test print） | Claude |
| 2026-08-04 | — | **模块 004 TDD 切片 2c（增量 update + 结构合并）**：`llm_persona_builder.dart` 补 `LlmPersonaBuilder.update` + `DefaultLlmPersonaBuilder.update`：`schemaVersion` 不符抛 `PersonaSchemaException`；键哈希去重求实质新增，全命中→幂等（仅版本/修订，五层不变，T8）；有新增→仅对新素材重蒸馏得增量 Persona 再与既有**结构合并**（词表计数累加 topN、比率按量加权、记忆/时间线/证据合并、别名并集、标签按标签并合），`hardRules` **永不覆盖**（T9），合并后按合并后列表重算逐层置信与 `notes`。因 `.persona` 只存哈希不可复现旧原文，旧结论经证据/计数保留而非重蒸馏。合并助手为模块 003 逻辑的忠实复刻（不改动模块 003）。宿主 TDD +4 用例（T8/T9 + 实质新增合并 + schema 守卫），`flutter test` 256/256、`flutter analyze` 0 警告（余 1 项为既有 test print） | Claude |
| 2026-08-04 | — | **模块 004 TDD 切片 3（ChatEngine 对话引擎）**：`lib/services/llm/chat_types.dart`（`ChatRole`/`ChatTurn`/`ChatOptions`/`ChatDelta`/`ChatSession`，ERD-004 §3.5）+ `hard_rule_guard.dart`（`HardRuleGuard`：**仅输出后置校验**，因 `render()` 已注入 hardRules；`lookback` 回退缓冲使越界短语在拼接完整前滞留、外泄前截获；屏蔽 `mustNeverClaim`+`forbiddenTopics`+自称 AI 标志）+ `chat_engine.dart`（`ChatEngine` 抽象 + `DefaultChatEngine`：system prompt **仅**由 `PromptTemplate.render` 产生；滑窗保留最近 `maxContextTurns` 轮并 `onLog` 记录裁剪数；`generateStream` 流式增量；越界拦截改发安全回复；空消息→`emptyInput`、`maxPrivacy`/无模型→`modelUnavailable`、云端未授权→`unauthorized`，**均无兜底无网络调用**；取消订阅即停无异常）。**对话无统计兜底**（对齐 SPEC §2.4）。宿主 TDD +9 用例（T14–T20，MockRuntime），`flutter test` 265/265、`flutter analyze` 0 警告（余 1 项为既有 test print） | Claude |
| 2026-08-04 | — | **模块 004 TDD 切片 4a（DD-001 落地：`ModelHandle.filePath` 可选化）**：`ModelHandle.filePath: required String → String?`（DD-001 选项 A——仅自管下载时有值，`flutter_gemma` 插件路径下为 `null`，`LiteRtRuntime` 经 `getActiveModel()` 加载不依赖此字段）；同步 007 `DefaultModelRepository`（构造仍填合成路径，`String→String?` 赋值兼容）与 T12 测试（断言改 null 安全）；DESIGN-DEBT DD-001 状态转「已定夺并落地」。`flutter test`（007）21/21、`flutter analyze` 0 警告（余 1 项既有 test print） | Claude |
| 2026-08-04 | — | **模块 004 TDD 切片 4b（CloudRuntime 云端运行时）**：`lib/services/llm/cloud_runtime.dart`（`CloudRuntime implements PersonaRuntime`，opt-in）：授权门控——未授权 / 无密钥 → `generate` 返回 `unauthorized`、`generateStream` 抛 `unauthorized`，**绝不调用 transport、绝不发网络**；`CloudTransport` 可注入接缝（provider HTTP 线缆属集成/设备工作，与门控+错误分类解耦）；HTTP 失败经 `CloudHttpException`（statusCode/isNetworkError）归一为分类 `RuntimeError`（401/403→unauthorized、429→rateLimited、其余/网络→network）；`generateStream` 用 `await for` 拦截并重映射上游流错误（非 `yield*`）。宿主 TDD +13 用例（假 transport，覆盖门控/成功/错误分类/流中途错误），`flutter test` 278、`flutter analyze` 0 警告 | Claude |
| 2026-08-04 | — | **模块 004 TDD 切片 4c（LiteRtRuntime 本地运行时 + flutter_gemma 接缝）**：`lib/services/llm/lite_rt_runtime.dart`（`GemmaEngine` 接缝 + `LiteRtRuntime implements PersonaRuntime`：可用性以 007 契约为准——经注入的 `getActiveModelHandle` 判定，无激活句柄即不可用（DD-001：不依赖 `filePath`）；推理委派引擎，原生层异常经 `await for` 归一为 `modelUnavailable`，不静默失败；全程无网络）+ `flutter_gemma_engine.dart`（`FlutterGemmaEngine` 具体实现，**设备/原生**：`FlutterGemma.hasActiveModel/getActiveModel().createSession()` + `getResponse(Async)`，对齐 v1.5.2 现代门面，宿主/模拟器不可验质量 ADR-005）。宿主 TDD +9 用例（假 `GemmaEngine`，覆盖可用性/generate/stream/异常归一），`flutter test` 287/287、`flutter analyze` 0 警告（余 1 项既有 test print）。**T21（SmolLM 真机冒烟）+ 云端 provider HTTP transport 具体实现留待真机/集成** | Claude |
| 2026-08-04 | — | **模块 004 TDD 切片 5（开发者调试台 dev-only）**：`lib/screens/dev/llm_harness_screen.dart`（`LlmHarnessScreen`：真机把「安装 [SmolLM 135M 免 token] → `setActive` → 蒸馏示例语料 → 多轮流式对话」串成人工「像不像」评审台，ADR-005 质量验收必须真机）——装配真实 `DefaultModelRepository`（`FlutterGemmaInstaller`/`SecureTokenStore`/`InMemoryModelStore`）+ 本地 `LiteRtRuntime(FlutterGemmaEngine, activeHandle: getActiveModelHandle)`，全程本地原文不出设备；展示 `DefaultPromptTemplate.render()` 的 system prompt 与流式增量；`initGemmaRuntime()` 由屏内惰性注册（不动 `main` 启动路径）。`HomeScreen` 加 `kDebugMode` 入口按钮。**UI 层不入宿主单测**（设备 slice，底层已由切片 3/4 契约测试覆盖）；`flutter analyze` 0 警告、`flutter test` 287/287 不变。T21 真机冒烟待运行 | Claude |
| 2026-08-04 | — | **切片 5 冒烟修复**：真机/模拟器安装 SmolLM 报 `failed·network`，日志实为 **HTTP 404**——目录 `smolLm135m` 指向的 `litert-community/SmolLM-135M-Instruct/…SmolLM-135M-Instruct.litertlm` 该仓库**无 `.litertlm`**（仅 `.task/.tflite`）。改指免 token 且确有 `.litertlm` 的 `litert-community/SmolLM2-135M-Instruct/…SmolLM2_135M_Instruct.litertlm`（id `smollm2-135m`、136MB、格式仍 litertlm 走已注册的 LiteRT-LM 引擎，无需 MediaPipe 插件）。另修 `FlutterGemmaInstaller._mapError` 掩盖真因的缺陷：`NotFoundError`→`unknownModel`（原并入 network 误导排查）、补全 `RateLimited/Server→network`、`Unknown→unknown`（sealed 全覆盖）。`flutter analyze` 0 警告、`flutter test` 287/287 | Claude |
| 2026-08-04 | — | **T21 冒烟通过（iOS 模拟器）**：SmolLM2-135M `.litertlm` 下载→激活→LiteRT-LM 引擎初始化（~3s）→生成全链路跑通；实测 TTFT ~0.5–0.8s、解码 ~26–37 tok/s（>5 tok/s 达标；模拟器 `backend=gpu`，135M < 256MB Metal 上限故可跑，1B/E2B 仍须真机，符合 ADR-005）。**蒸馏因 135M 无法产出结构化格式，解析两次失败→诚实回落模块 003 统计兜底**（ADR-004 预期行为）：本冒烟验证「安装/激活/推理/流式/守卫」管道，**非蒸馏质量**；质量验收仍待真机 Gemma 3 1B。真机（物理设备）冒烟与云端 provider HTTP transport 仍待办 | Claude |
| 2026-08-04 | — | **调试台增强（为真机蒸馏质量评审）**：`LlmHarnessScreen` 加**模型选择器**（SmolLM2 135M / Gemma 3 1B / Gemma 4 E2B）+ **HF token 输入框**（受限模型显示，经 `install(hfToken:)` 直传，未存盘），使真机可下载大模型做「像不像」评审（135M 只能触发统计兜底，非质量档）。另修两处调试台缺陷：`_send` 曾把本轮用户消息**既加入 history 又作为 userMessage 传入** → prompt 出现「对方：X / 对方：X」重复，改为传入加入前的 history 快照；对话回复剥除泄漏的控制 token（`<end_of_turn>` 等，SmolLM2 general 模板产物）。UI 层仍不入宿主单测；`flutter analyze` 0 警告 | Claude |
| 2026-08-04 | — | **目录 URL 修正（经 HF API 核对真实文件）**：`gemma3_1b` 原指 `Gemma3-1B-IT_multi-prefill-seq_q4_ekv2048.litertlm`（仓库**无此文件**，实为 ekv4096）→ 改指通用跨端 `gemma3-1b-it-int4.litertlm`（`litert-community/Gemma3-1B-IT`，`gated: auto` 故仍 `requiresToken`）。`gemma4E2b` 原指不存在的 `litert-community/Gemma-4-E2B-it` → 改指真实 `litert-community/gemma-4-E2B-it-litert-lm/…/gemma-4-E2B-it.litertlm`（`gated: False`，**去掉 `requiresToken`**，免 token）。SoC 专用变体（`_qualcomm_*`/`_intel_*`/`_Google_Tensor_G5`/`-web`）不适用 iOS，一律选通用文件。调试台 `_choices` 补入 E2B（免 token，最省事的高质量档）。`flutter analyze` 0 警告、模型管理单测 21/21 | Claude |
| 2026-08-05 | — | **PR #14 merged to `main`**: review-comment fixes + install-stream dedup race fix (`model_repository.dart` `_pump` finally now removes the job before closing the broadcast controller); `persona_mapper` grounding tightened; `RuntimeError.inferenceFailed` normalization; `lite_rt_runtime` error mapping. Host TDD suite **291 passing**, `flutter analyze` clean. iOS SPM platform bumped to 16.0 via `AppFrameworkInfo.plist` `MinimumOSVersion`; on-device signing/install verified on a physical iPhone with the paid Apple Developer team (signing/bundle-ID churn kept local, off the PR). | Claude |
| 2026-08-05 | — | **Modules 004 & 007 closed out**: DOCUMENT-STATUS matrix + detail status set to ✅ 已完成, checklists reconciled. Root `README.md` module table synced. Only non-blocking follow-up remaining is ADR-005 on-device persona-quality validation (distill → chat → judge "像不像本人" on Gemma 3 1B) + T21 physical-device smoke. | Claude |
| 2026-08-05 | — | **Phase 4 UI split into 3 modules — 9 draft docs created** (PRD/ERD/Spec ×3, 编号 006/009/010, 日期 20260805, 交叉引用互指): **006 聊天界面**（`ChatScreen` on 004 `ChatEngine` + 新增 SQLite `ChatHistoryRepository` 聊天历史；system prompt 仅 `PromptTemplate.render()`，对话无统计兜底；`sqflite_common_ffi` 宿主接缝 + 008 加密 `DatabaseFactory` 注入点；C1–C34）；**009 人物库与蒸馏**（新增 `PersonaRepository` = `PersonaCodec`+`PersonaDirectory`〔`MemoryPersonaDirectory` 宿主〕+`PersonaBytesTransform`〔008 接缝〕填补"仅内存无落盘"缺口 + 人物库屏 + 蒸馏流程屏驱动 004 `LlmPersonaBuilder`；`PersonaSummary` 读时派生；新增 `PersonaStoreException`；C1–C21）；**010 设置**（007 模型管理正式 UI 取代 dev harness + 运行模式 `RuntimeChoice` + 云端授权；`AppSettings`/`SettingsRepository`〔Hive〕/`SecureKeyStore`〔Secure Storage〕；honors 真实 `InstallErrorKind`；标记 DD-002 + `InMemoryModelStore`→磁盘缺口）。聊天历史存储定为 **SQLite**。矩阵行 006 → 📝/📝/📝，新增行 009/010；一致性核验通过（9 文件齐、交叉引用无缺失、共享契约命名一致：`PersonaRepository` 006↔009、`ChatHistoryRepository` 006 独有、`AppSettings`/`RuntimeChoice` 010 独有）。**未改任何源码/pubspec**，全部待评审批准后方可编码 | Claude |
| 2026-08-05 | — | **PR #16 评审修订（Phase 4 九文档同升 v1.0.1，仍草稿）**：处理 1 Major + 2 Minor + 1 nit——(Major，模块 010) 安装状态与 **post-#14 真实流程**对齐：`flutter_gemma` 安装器实际只发 `downloading → ready` / `failed(canceled|network|unknownModel|authRequired|insufficientStorage|unsupportedDevice|unknown)`，**从不发 `ModelState.verifying` / `InstallErrorKind.corrupted`**（PR #14 移除了从未真正执行的 sha256 校验）；PRD-010 加"Install states — honesty note"、目标 4/F2/F9/进度控件/验收项均标注 `corrupted` 为 defensive-only，ERD-010 错误映射行 + SPEC-010 安装生命周期/E15/C8/C14 全部重述为 `downloading → ready`（`verifying`/`corrupted` 仅防御性处理、不作为预期步骤宣传）；**根因（模块 007 PRD/ERD/SPEC 与 `model_install.dart` 枚举 docstring 的旧 sha256/verifying 措辞）以 dated 勘误 blockquote 就地标注**（不重写已批准正文、待后续单独 reconcile）。(Minor 1) ERD-006 新增 **§3.4 Settings→`ChatOptions`/runtime 绑定接缝**（runtime→mode + PersonaRuntime 选择、cloudAuthorized、temperature、fail-safe 默认）。(Minor 2) ERD-010 新增 **`cloudKeyStoreProvider` 云端 API-key 读路径规格**，由 006 §3.4 与 009 蒸馏接缝共同消费（缺 key → 006 `RuntimeError.unauthorized` / 009 回落统计兜底；`maxPrivacy` 永不读 key）。(nit) ERD-006 "Depends on" 补列模块 010。**未改任何源码/pubspec**，仍草稿待批准 | Claude |
| 2026-08-05 | — | ✅ **批准模块 010（设置）三文档**（Project Owner）：PRD/ERD/SPEC 状态转"已批准"、批准日期 2026-08-05、三文档升 v1.0.2。矩阵行 010 → ✅/✅/✅、三文档齐全、开发状态转"开发中"，解除阻塞，进入 TDD 编码（分支 `feature/PRD-010-settings`）。010 依赖 007/004 均已完成，可独立开发；006/009 仍草稿待批准 | Project Owner |
| 2026-08-06 | PR #17 | **PR #17 评审修订（模块 010 实现 + 文档对账）**：处理 Owner 评审 2 Major + minors/test-gaps——(Major 1，代码) 密钥写入错误不再被静默吞掉：`settings_screen.dart` 的密钥 Save/Clear 改经 `_guarded` 包裹并 await（与非密钥 setter 一致，兑现 E17/C24"不吞错"不变量）；`appSettingsProvider` 补 `onSaveError`（记日志）并对 `loadInitial()` 加 `catchError`，keychain/Hive 读写失败不再逃逸至未处理 async zone。(Major 2，流程) **本条记录 v1.0.3 = 编码后文档-代码对账，非新批准**；追踪表（矩阵行 010 + 详细状态表）与 README 同步为"✅ v1.0.2 · 🔶 v1.0.3 待复批"，避免追踪表滞后于其所追踪文档；v1.0.3 增量（`cloudEndpoint`/`deactivate`/`allowOverTier` 等）**待 Owner 复批**。(minors) SPEC-010 §2.3/C2"四字段"→"五字段"；补测试缺口 G1（`copyWith` 保留非空字段分支）/G2（安装流原始错误→`failed(unknown)`）/G3（密钥写入失败不吞错，UI 层 SnackBar）。全套测试通过、`flutter analyze` 干净（仅遗留无关 `avoid_print`）| Claude |
| 2026-08-07 | docs/PRD-009-import-ui | **模块 009 范围扩展 → 导入 UI 入口（三文档同升 v1.1.0，仍草稿）**：发现 **Phase-4 导入 UI 缺口**——模块 002 交付了完整解析/数据层（WeChat/iMessage/Weibo/Instagram/EXIF 解析器、`Conversation`、`DataImportService`、`ImportNotifier`/`importStateProvider`）但**明确推迟了导入界面**至"Phase-4 UI 模块"，而 006/009/010 均未认领；今日 `importFiles(...)` 仅测试可达、生产唯一端到端路径是 `kDebugMode` `LlmHarnessScreen` 硬编码样例——**生产环境无法导入真实聊天记录**。经确认由**模块 009 认领导入 UI**（蒸馏/创建流程的入口）。PRD/ERD/SPEC-009 v1.1.0：新增 Story 6 + F10 + `FilePickerFacade` 接缝（默认 `file_picker`，宿主 `FakeFilePicker`）复用 002 `ImportNotifier`（不新增导入状态类型/不改任何解析器）；边界 E15–E18、测试 C22–C24（C21 改真机真实导入）；新增 `file_picker` 依赖（ERD-002 原仅候选）。**PR #18 自评修订**：`FilePickerFacade` 拆为 `pickFiles()` / `pickDirectory()`（目录源 iMessage db / Photo-EXIF 需 iOS security-scoped 访问，ERD-002 §676）；`file_picker` 固定 `^8.0.0`；软化 iOS entitlement 表述 + 补 §11 持久 bookmark 技术债；新增测试 C25。**未改任何源码/pubspec**，仍草稿待评审批准（分支 `docs/PRD-009-import-ui`）| Claude |
| 2026-08-07 | docs/approve-009 | ✅ **批准模块 009（人物库与蒸馏，含导入 UI 入口）三文档**（Project Owner）：PRD/ERD/SPEC 状态转"已批准"、批准日期 2026-08-07、三文档同升 v1.1.1。矩阵行 009 → ✅/✅/✅、三文档齐全、开发状态转"开发中"，解除阻塞，进入 TDD 编码。009 依赖 002/003/004/007 均已完成，可独立开发 | Project Owner |

---

> 本文档会实时更新，反映最新的文档状态。每次文档状态变更后必须更新此表。