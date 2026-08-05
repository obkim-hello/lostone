# Lostone 文档状态追踪

> 本文档追踪所有模块的文档完整性状态，确保 PRD + ERD + Spec 三文档齐全且批准。

---

## 📊 文档完整性矩阵

| 模块编号 | 模块名称 | PRD 状态 | ERD 状态 | Spec 状态 | 三文档齐全 | 开发状态 |
|----------|---------|---------|---------|----------|-----------|----------|
| 001 | 项目初始化 | ✅ 已批准 | ✅ 已批准 | ✅ 已批准 | ✅ 是 | ✅ 已完成 |
| 002 | 数据导入 | ✅ 已批准 | ✅ 已批准 | ✅ 已批准 | ✅ 是 | 🚧 开发中 |
| 003 | Persona 生成 | ✅ 已批准 | ✅ 已批准 | ✅ 已批准 | ✅ 是 | ✅ 已完成 |
| 004 | LLM 集成（蒸馏 + 对话引擎 + Runtime 抽象层）| ✅ 已批准 | ✅ 已批准 | ✅ 已批准 | ✅ 是 | 🚧 开发中 |
| ~~005~~ | 云端 API 集成 → **已并入 004**（Runtime 抽象层统一本地/云端）| — | — | — | — | 🔀 已折叠 |
| 006 | 聊天界面 | ⚪ 待创建 | ⚪ 待创建 | ⚪ 待创建 | ❌ 否 | 🚫 阻塞 |
| 007 | 模型管理（提前至 Phase 3，004 本地路径前置）| ✅ 已批准 | ✅ 已批准 | ✅ 已批准 | ✅ 是 | 🚧 开发中 |
| 008 | 数据安全 | ⚪ 待创建 | ⚪ 待创建 | ⚪ 待创建 | ❌ 否 | 🚫 阻塞 |

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
- 🚧 **开发状态：开发中（TDD，DD-001 契约随设计定夺）**

### 范围摘要
- 模块定位（v1.1 拓宽为"LLM 集成"，两大支柱）：**(A) 蒸馏**——以 LLM 从模块 002 `Conversation` 产出忠实五层 Persona，映射进模块 003 现有 `Persona` 契约；**(B) 对话引擎（ChatEngine）**——以 `Persona` 渲染的 system prompt 驱动多轮流式对话（滑窗上下文、硬规则强制、本地/云端切换）。二者**共享 Runtime 抽象层**（本地 LiteRT 默认 + 云端 API opt-in），原「005 云端 API 集成」已并入本模块。
- 立项依据（ADR-004）：统计引擎（003）产出偏单薄/易失真（"不像本人"），LLM 蒸馏更忠实（签名特征、真实例句、诚实标注"原材料不足"）；统计引擎降级为**预处理 + 离线兜底**。端侧栈定为 **flutter_gemma / LiteRT-LM**（ADR-005）。
- 关键约束：**输出契约不变**（复用 `Persona` + `PromptTemplate.render()`，不改对外形状）、**不重写模块 003**、模型就绪归**模块 007**（经 `getActiveModelHandle()`）、默认本地/云端显式授权、诚实优先（不编造事实）、隐私（原文不出设备、`.persona` 仅存哈希 + 短示例）；对话无统计兜底（无模型明确提示）。
- 可验证性：提供**开发者调试台（dev-only harness）**在真机手动"下载模型→蒸馏→对话"评审"像不像本人"；正式聊天 UI 属模块 006。
- 测试策略变更：LLM 非确定性 → 由 byte-identical 确定性断言改为**契约/结构断言 + mock Runtime + 快照/人工评审**；质量验收须真机（模拟器仅 CPU 冒烟，ADR-005）。

### 待办
- [ ] 三文档评审
- [ ] 三文档批准（批准后方可编码）
- [ ] 编写测试用例（mock Runtime）→ 实现 → 验证
- [ ] Runtime 抽象层实现（LiteRtRuntime[flutter_gemma] / CloudRuntime / FallbackRuntime）
- [x] ChatEngine 实现（滑窗上下文 / 流式 / 硬规则强制 / 本地云端切换）— 切片 3（宿主 TDD T14–T20）
- [ ] 开发者调试台（dev-only）真机质量评审
- [ ] 与模块 007（模型管理，前置依赖）、006（聊天界面）对接

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
- 🚧 **开发状态：开发中**（宿主核心 + 设备/原生 slice 已落地；`ModelHandle.filePath` 契约见 DD-001 待 004 定夺）

### 范围摘要
- 模块定位：端侧 LLM 模型的**下载 / 存储 / 切换 / 查询**，以**薄封装**隔离 `flutter_gemma` 模型安装 builder API（`installModel().fromNetwork().install()`；旧 `ModelFileManager` 为 legacy facade，ADR-005，不自造下载器）；向模块 004 暴露稳定的 `ModelHandle` / `ModelRepository.getActiveModelHandle()` 契约。
- 提前依据：**从 Phase 4 提前至 Phase 3**，作为模块 004 本地默认路径的**前置依赖**——没有就绪模型，004 的本地蒸馏/对话无法真机验证。
- 包含：ModelCatalog（SmolLM 135M / Gemma 3 1B / Gemma 4 E2B）、下载状态机 + 断点续传 + 进度流、存储/占用/删除、激活/切换、设备能力探测（Metal/内存档、引擎选择）、HF token（Secure Storage）。
- 不包含：推理/对话/蒸馏（模块 004）、模型管理**正式 UI**（Phase 4 / 模块 006 设置）、云端 API Key、加密/排除备份（模块 008，预留注入点）。
- 关键约束（ADR-005）：iOS 16+/entitlements/静态链接；模拟器仅 CPU（大模型不可运行）→ 质量验收须真机；模型落盘内存映射；社区包锁版本。
- 测试策略：宿主 mock 下载器 + 内存文件系统做状态机/契约断言（>80%）；SmolLM 135M 冒烟；真机 Gemma 3 1B 分阶段。

### 待办
- [ ] 三文档评审
- [ ] 三文档批准（批准后方可编码）
- [ ] 编写测试用例（mock 下载/文件系统）→ 实现 → 验证
- [ ] `ModelRepository` / `ModelInstaller`（flutter_gemma 封装）/ `ModelStore` / `DeviceCapabilities` 实现
- [ ] iOS 平台装配（entitlements / Info.plist / Podfile 静态链接）+ 真机验证（分阶段）
- [ ] 与模块 004（消费 `ModelHandle`）对接

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
6. **模块 006**：聊天界面（Phase 4）
7. **模块 008**：数据安全（Phase 5）

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

---

> 本文档会实时更新，反映最新的文档状态。每次文档状态变更后必须更新此表。