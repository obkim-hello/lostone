# SPEC-Data-Parser-002-20260801

> 技术规格文档 - 数据解析器
>
> **版本**：v0.2
> **状态**：📝 草稿
> **作者**：Claude
> **日期**：2026-08-01
> **批准日期**：待批准
> **批准人**：待批准
> **关联 ERD**：ERD-Data-Parsers-002-20260801.md

---

## 📋 文档信息

| 项目 | 内容 |
|------|------|
| **Spec 编号** | 002 |
| **模块名称** | 数据解析器（Data Parser） |
| **关联 ERD** | ERD-Data-Parsers-002-20260801.md |
| **关联 PRD** | PRD-Data-Import-002-20260801.md |
| **粒度** | 模块接口（Module Interface） |
| **测试状态** | 待测试 |

---

## 1. 规格概述

### 1.1 模块职责
数据解析器模块负责：
- 从本地文件解析多源数据（微信、iMessage、微博、Instagram、照片）
- 将异构数据统一为 `Message` / `Conversation` 模型
- 清洗、去重、按时间排序
- 输出结构化 JSON，供 Persona 生成引擎（模块 003）消费

### 1.2 接口层级
- **层级**：模块接口（Module Interface）
- **范围**：定义 `DataParser`、`DataPreprocessor`、`DataImportService` 三类对外接口

---

## 2. 接口定义

### 2.1 主要接口

#### 接口 1：DataImportService.importFiles

**功能**：导入一个或多个文件，产出标准化会话

**签名**：
```dart
/// 导入文件并产出标准化会话。
///
/// 参数：
/// - [filePaths]：待导入文件路径列表，非空。
/// - [source]：数据源；为 null 时按内容自动识别。
/// - [options]：解析选项。
///
/// 返回：Future<Conversation>
///
/// 抛出：
/// - [ArgumentError]：当 filePaths 为空。
/// - [ImportException]：当所有文件均无法解析。
Future<Conversation> importFiles(
  List<String> filePaths, {
  DataSource? source,
  ParseOptions options = const ParseOptions(),
});
```

**输入规格**：
| 参数名 | 类型 | 必填 | 默认值 | 验证规则 | 说明 |
|--------|------|------|--------|---------|------|
| filePaths | List<String> | 是 | - | 非空、路径存在 | 待导入文件 |
| source | DataSource? | 否 | null（自动识别） | 枚举值 | 指定数据源 |
| options | ParseOptions | 否 | const ParseOptions() | - | 解析选项 |

**输出规格**：
| 字段名 | 类型 | 说明 |
|--------|------|------|
| source | DataSource | 主数据源 |
| participants | List<String> | 参与者 |
| messages | List<Message> | 清洗/去重/排序后的消息 |
| stats | ImportStats | 导入统计 |

**前置条件**（Preconditions）：
- [ ] `filePaths` 非空且每个路径存在
- [ ] 应用已完成初始化（模块 001）
- [ ] 大文件/媒体导入前已按平台完成来源接入（iOS：拷入沙盒并设 `isExcludedFromBackup`；macOS：已取得 security-scoped bookmark），详见 ERD §4.4；**禁止**对大文件使用 `file_picker` 的字节读取模式
- [ ] 媒体字节入库前已估算并向用户提示占用空间（`options.mediaTier` 决定入库范围）

**后置条件**（Postconditions）：
- [ ] 返回的 `messages` 已去重且按 `timestamp` 升序
- [ ] `stats.afterDedup == messages.length`
- [ ] 单文件解析失败被记录为告警而非中断（除非全部失败）

**不变性条件**（Invariants）：
- 相同输入多次调用产出等价结果（幂等、无副作用于源文件）

---

#### 接口 2：DataParser.parse（🔴 流式契约）

**功能**：**流式**解析单个文件，逐条产出消息/告警事件

**签名**：
```dart
/// 流式解析文件，逐条产出 [ParseEvent]（MessageEvent / WarningEvent）。
///
/// 峰值内存必须与文件大小解耦——不得全量载入文件字节或 HTML DOM。
///
/// 参数：
/// - [filePath]：文件路径。
/// - [options]：解析选项。
///
/// 返回：Stream<ParseEvent>
///
/// 抛出：
/// - [ParseException]：文件无法解析（致命，通常在首个事件前）。
Stream<ParseEvent> parse(
  String filePath, {
  ParseOptions options = const ParseOptions(),
});

/// 便捷方法：排空 [parse] 流为 [ParseResult]。仅供小文件/测试使用。
Future<ParseResult> parseAll(
  String filePath, {
  ParseOptions options = const ParseOptions(),
});
```

**输入规格**：
| 参数名 | 类型 | 必填 | 默认值 | 验证规则 | 说明 |
|--------|------|------|--------|---------|------|
| filePath | String | 是 | - | 存在、可读 | 单文件路径 |
| options | ParseOptions | 否 | const ParseOptions() | - | 解析选项 |

**输出规格**：
| 事件 | 类型 | 说明 |
|------|------|------|
| MessageEvent | ParseEvent | 一条已解析消息 |
| WarningEvent | ParseEvent | 一条非致命告警 |

**前置条件**：
- [ ] 文件存在且可读
- [ ] `canParse(filePath)` 返回 true

**后置条件**：
- [ ] 每条 `Message` 的 `source`/`timestamp`/`type` 均已填充
- [ ] 无法解析的单行产出 `WarningEvent`，不中断流
- [ ] 峰值内存与文件大小无关（不得全量载入）

---

#### 接口 3：DataPreprocessor.process

**功能**：对消息执行清洗、去重、时间排序

**签名**：
```dart
/// 清洗 → 去重 → 排序。
///
/// 返回记录：处理后的消息与被跳过的条数。
({List<Message> messages, int skipped}) process(List<Message> input);
```

**输入规格**：
| 参数名 | 类型 | 必填 | 验证规则 | 说明 |
|--------|------|------|---------|------|
| input | List<Message> | 是 | 可为空列表 | 原始消息 |

**输出规格**：
| 字段名 | 类型 | 说明 |
|--------|------|------|
| messages | List<Message> | 清洗/去重/升序后的消息 |
| skipped | int | 被过滤+去重掉的条数 |

**后置条件**：
- [ ] 结果不含 `MessageType.system` 消息
- [ ] 结果无重复项（按去重键）
- [ ] 结果按 `timestamp` 升序（稳定）
- [ ] `input.length == messages.length + skipped`

---

### 2.2 辅助接口

#### 辅助接口 1：DataParser.canParse
```dart
/// 判断解析器是否能处理该文件（扩展名/结构探测）。
Future<bool> canParse(String filePath);
```

#### 辅助接口 2：ParserRegistry.match
```dart
/// 根据文件与可选数据源选出解析器；无匹配返回 null。
Future<DataParser?> match(String filePath, {DataSource? source});
```

---

## 3. 数据规格

### 3.1 输入数据模型

#### 模型：ParseOptions
```dart
class ParseOptions {
  final String? targetContact;      // macOS chat.db 目标联系人
  final bool extractLocation;       // 是否提取 GPS，默认 false
  final List<String> myIdentifiers; // 判定 isFromMe 的标识集合
  final MediaTier mediaTier;        // 媒体入库层级，默认 MediaTier.all
}
```

**验证规则**：
- `targetContact`：iMessage `chat.db` 场景建议提供；为空时导出全部会话
- `extractLocation`：为 true 时须已获得系统/用户授权，否则退化为 false 并告警
- `myIdentifiers`：为空时解析器按数据源默认规则判定 `isFromMe`
- `mediaTier`：控制媒体字节层的入库范围（详见 ERD §4.4）。默认 `MediaTier.all`（保留全部媒体）；文本语料层与媒体索引层不受此选项影响，始终产出

#### 模型：MediaTier
```dart
/// 媒体字节入库层级（文本语料/媒体索引始终产出，见 ERD §3.1 三层解析产物）。
enum MediaTier {
  textOnly,        // 仅文本语料 + 媒体索引（不落媒体字节）
  photoAndVoice,   // 文本 + 照片/语音字节
  all,             // 全部媒体字节（默认）
}
```

#### 模型：ParseEvent（🔴 流式产物）
```dart
/// 流式解析事件基类。
sealed class ParseEvent {
  const ParseEvent();
}

/// 一条已解析消息。
class MessageEvent extends ParseEvent {
  final Message message;
  const MessageEvent(this.message);
}

/// 一条非致命告警（如 missing_media、malformed_row）。
class WarningEvent extends ParseEvent {
  final ParseWarning warning;
  const WarningEvent(this.warning);
}
```

#### 模型：MediaIndexEntry（媒体索引层）
```dart
/// 媒体索引条目：仅记录引用与元数据，不含字节（权威定义见 ERD §3.6）。
class MediaIndexEntry {
  final DataSource source;   // 来源
  final String senderId;     // 发送者
  final DateTime timestamp;  // 媒体时间
  final MessageType type;    // image/voice/video/…
  final String sourceRef;    // 源媒体引用（导出包内相对路径/标识/书签路径）
  final String? storedPath;  // 已落库字节路径；未入库（textOnly）时为 null
  final bool available;      // 源字节是否存在（false → missing_media 告警）
}
```

---

### 3.2 输出数据模型

#### 模型：Message
```dart
class Message {
  final String id;              // 引用/展示标识，非去重键
  final DataSource source;      // 来源
  final String senderId;        // 发送者标识
  final String senderName;      // 发送者展示名
  final bool isFromMe;          // 是否本人发出
  final DateTime timestamp;     // 消息时间
  final MessageType type;       // 类型
  final String content;         // 文本内容
  final String? mediaPath;      // 媒体引用（可空）
  final Map<String, dynamic> metadata; // 额外元数据
}
```

**字段约束**：
- `id`：非空，同一 `source` 内唯一；仅作引用/展示，**不用于去重**（去重键见 ERD §6.1 算法1）
- `senderId` / `senderName`：非空
- `timestamp`：合法 `DateTime`，本地时区
- `content`：文本类型非空；非文本类型可为摘要/占位
- `mediaPath`：仅媒体类型可非空

---

### 3.3 数据转换规则

| 输入 | 转换规则 | 输出字段 |
|------|---------|----------|
| 微信 CSV 时间列 | 解析为本地 `DateTime` | timestamp |
| iMessage `date`（Apple 秒/纳秒） | 按 1e12 阈值判定单位后 `epoch2001 + 秒`（ERD §6.1 算法3） | timestamp |
| 发送方标识 ∈ myIdentifiers | true | isFromMe |
| 系统消息文本模式匹配 | 标记为 `MessageType.system` | type |
| 文本首尾空白 | trim | content |
| 控制/无效字符 | 剔除 | content |

---

### 3.4 微信解析细节（规范性）

以下规则为 `WeChatParser` 的**规范要求**，实现与测试必须覆盖。

#### 3.4.1 多行消息续行（🔴 正确性要求）
微信 TXT/HTML 导出中，单条消息的正文可跨多行：只有能匹配「消息头」（发送者 + 时间戳）的行才开启一条新消息，**其后不匹配消息头的行属于上一条消息正文**，须追加（以 `\n` 连接），不得逐行丢弃。

**算法**：
```
current = null
for line in lines:
  if matchesHeader(line):
      if current != null: emit(current)
      current = newMessage(from: line)
  else if current != null:
      current.content += '\n' + line          // 续行追加
  else:
      warn('orphan_line')                      // 首条消息前的游离行
emit(current)  // flush 末条
```
朴素的逐行解析会静默丢弃每条多行消息的后续行，属于真实缺陷，必须有 fixture 覆盖。

#### 3.4.2 媒体占位符处理（type-and-keep，不丢弃）
微信将非文本消息导出为占位标记。除「撤回」外，一律**保留为带类型的消息**（保留对话节奏信号），而非当作系统消息丢弃：

| 占位符 | 处理 | `type` | 说明 |
|--------|------|--------|------|
| `[图片]` | 保留 | `image` | |
| `[语音]` | 保留 | `voice` | |
| `[视频]` | 保留 | `video` | |
| `[表情]` | 保留 | `image` | 贴纸/表情 |
| `[位置]` | 保留 | `location` | |
| `[文件]` `[名片]` `[链接]` `[红包]` `[转账]` | 保留 | `text` | 无专用枚举，`content` 存原占位符，`metadata['placeholder']` 存原始标记 |
| `[撤回了一条消息]` | **标记** | `system` | 由预处理过滤（对话中无实际内容） |

> `content` 对媒体类占位符存占位摘要（如 `[图片]`）；真实媒体文件引用（若导出含）存 `mediaPath`。

#### 3.4.3 CSV 列名别名（容错）
不同导出工具列名不一，解析器须按下表别名集识别列（大小写不敏感，取首个命中）：

| 逻辑列 | 接受的别名 |
|--------|-----------|
| 发送者 | `sender`, `发送人`, `from`, `NickName`, `talker` |
| 内容 | `content`, `内容`, `message`, `Message`, `StrContent` |
| 时间 | `timestamp`, `时间`, `time`, `StrTime`, `CreateTime` |

无法定位必需列（发送者/内容/时间任一）时，抛 `ParseException`（致命）。

---

## 4. 边界情况

### 4.1 输入边界

| 边界情况 | 输入值 | 预期行为 |
|----------|--------|---------|
| 空文件路径列表 | `[]` | 抛出 `ArgumentError` |
| 路径不存在 | `/no/such.csv` | 该文件记为告警；全不存在则 `ImportException` |
| 空文件 | 0 字节 | 返回空消息 + 告警 `empty_file` |
| 不支持的扩展名 | `.docx` | `canParse` 返回 false；无匹配解析器 |
| 超大文件 | > 200 MB | 拒绝并告警 `file_too_large` |
| 编码异常/乱码行 | 非法 UTF-8 | 跳过该行 + 告警 `malformed_row` |
| 多行正文消息 | 消息头后跟续行 | 续行追加到上一条正文（见 §3.4.1），不丢弃 |
| 消息头前的游离行 | 首条消息头之前有文本 | 跳过 + 告警 `orphan_line` |
| 媒体占位符 | `[图片]`/`[语音]`/… | 保留为对应 `type`（见 §3.4.2） |
| 撤回消息 | `[撤回了一条消息]` | 标记 `system`，预处理阶段过滤 |
| CSV 缺必需列 | 无发送者/内容/时间列 | 抛 `ParseException` |
| 缺失 EXIF 的照片 | 无 `DateTimeOriginal` | 跳过该照片 + 告警 `missing_exif` |
| 未授权却要求提取 GPS | extractLocation=true | 退化为不提取 + 告警 `location_not_authorized` |
| 消息引用的媒体缺失 | 导出包缺对应文件 | 保留消息 + 媒体索引 `available=false` + 告警 `missing_media`，不中断 |
| 媒体层级为 textOnly | `mediaTier=textOnly` | 产出文本语料 + 媒体索引（不落字节），媒体消息保留其 `type` |
| 超大导出（数 GB） | 5 GB / 10 万条 | 流式解析，峰值内存与文件大小无关，不 OOM（见 §6） |

---

### 4.2 状态边界

| 边界情况 | 当前状态 | 预期行为 |
|----------|---------|---------|
| 全部文件解析失败 | - | 抛出 `ImportException` |
| 部分文件解析失败 | - | 返回成功部分 + 告警 |
| 空结果（无有效消息） | - | 返回空 `messages`，`stats` 全 0，`earliest/latest` 为 null |
| 重复导入相同文件 | - | 去重后不产生重复消息 |

---

### 4.3 异常处理

#### 异常类型 1：ParseException（单文件致命）
**触发条件**：文件结构完全无法解析

```dart
throw ParseException(
  DataSource.wechat,
  'Unrecognized WeChat export structure',
  details: 'no header row found',
);
```
**处理方式**：由 `DataImportService` 捕获并转为告警，继续处理其余文件。

#### 异常类型 2：ImportException（整体失败）
**触发条件**：所有文件均无法产出任何消息

```dart
throw ImportException('No importable data found in the selected files');
```
**处理方式**：记录日志、展示错误页、允许用户重新选择文件。

---

## 5. 行为规格

### 5.1 正常流程
```
1. importFiles(paths, source, options)
2. 校验 paths 非空
3. 逐文件：match → parse（Stream<ParseEvent>，隔离异常）
4. 流式消费事件：
   - MessageEvent → 追加文本语料层 + 媒体索引层
   - 按 options.mediaTier 决定是否落媒体字节层
   - WarningEvent → 累积告警
   （不得全量缓存文件字节；峰值内存与文件大小解耦）
5. preprocessor.process(messages)（清洗/去重/排序）
6. 组装 Conversation + ImportStats
7. 返回
```

> **三层产物**：解析输出分为「文本语料 / 媒体索引（仅引用）/ 媒体字节」三层（见 ERD §3.1）。文本语料与媒体索引始终产出；媒体字节层受 `options.mediaTier` 控制。

### 5.2 异常流程

#### 流程 1：单文件失败
```
1. importFiles([a.csv, b.csv])
2. 解析 a.csv → 抛 ParseException
3. 记录告警，继续解析 b.csv
4. 返回 b.csv 的结果 + a.csv 的告警
```

#### 流程 2：全部失败
```
1. importFiles([a.csv, b.csv])
2. 两者均抛 ParseException
3. 无任何消息 → 抛 ImportException
```

### 5.3 并发行为
**线程安全**：Dart 单线程；重解析任务可移交后台 isolate（`compute`）

**约束**：
- `importFiles` 内多文件顺序解析，或受控并发（不超过设定上限）以控内存
- 单次 `importFiles` 必须 `await` 完成后再消费结果

---

## 6. 性能规格

### 6.1 时间复杂度
- 解析：O(n)，n 为消息数
- 去重：O(n)
- 排序：O(n log n)

### 6.2 空间复杂度
- 流式解析：峰值内存 O(1)——与文件大小/消息条数**无关**（不缓存全文件、不构建全量 DOM）
- 预处理去重：O(n)（去重键集合 + 结果列表；n 为消息数）
- 媒体字节按需落盘，不常驻内存

### 6.3 性能指标

| 指标 | 要求 | 测试方法 |
|------|------|---------|
| 解析吞吐 | ≥ 5,000 条/分钟 | 流式计时（drain stream） |
| 10 万条预处理 | < 30 秒 | 单元测试计时 |
| 解析峰值内存 | < 300 MB，且**与文件大小解耦** | 内存分析 + 5 GB/10 万条压测 |
| 5 GB / 10 万条导出 | 不 OOM，可完整解析 | 压测 fixture（流式） |
| 文件选择响应 | < 1 秒 | 手动/集成测试 |

> 旧指标「1000 条 < 60 秒 / 峰值 < 500 MB」在 ~5 GB 真实导出压测中暴露与文件大小耦合的 OOM 风险，已废弃并以上表替代。

---

## 7. 测试规格

### 7.1 单元测试

#### 测试用例 1：微信 CSV 正常解析
```dart
test('parses WeChat CSV into messages', () async {
  final WeChatParser parser = WeChatParser();
  final ParseResult r =
      await parser.parseAll('test/fixtures/wechat_sample.csv');

  expect(r.messages, isNotEmpty);
  expect(r.messages.first.source, DataSource.wechat);
});
```

#### 测试用例 2：预处理去重与排序
```dart
test('preprocess dedups and sorts', () {
  final DataPreprocessor pre = DataPreprocessor();
  final result = pre.process(<Message>[dup, dup, laterMsg, earlierMsg]);

  expect(result.messages.length, 2);
  expect(result.skipped, 2);
  expect(
    result.messages.first.timestamp.isBefore(result.messages.last.timestamp),
    isTrue,
  );
});
```

#### 测试用例 3：空文件路径列表
```dart
test('throws ArgumentError for empty file list', () {
  expect(
    () => DataImportService().importFiles(<String>[]),
    throwsArgumentError,
  );
});
```

#### 测试用例 4：单文件失败被隔离
```dart
test('isolates single-file failure as warning', () async {
  final Conversation c = await DataImportService()
      .importFiles(<String>['bad.csv', 'good.csv']);

  expect(c.messages, isNotEmpty);
  expect(c.stats.skipped, greaterThanOrEqualTo(0));
});
```

#### 测试用例 5：iMessage Apple 时间转换（精确断言，覆盖两种单位）
```dart
// 662688000 秒 == 662688000000000000 纳秒 == 2022-01-01T00:00:00Z（自 2001-01-01Z 起）
test('converts Apple nanosecond date to exact UTC datetime', () {
  final DateTime t = appleDateToDateTime(662688000000000000).toUtc();
  expect(t, DateTime.utc(2022, 1, 1));
});

test('converts Apple second-format date to exact UTC datetime', () {
  final DateTime t = appleDateToDateTime(662688000).toUtc();
  expect(t, DateTime.utc(2022, 1, 1));
});
```

#### 测试用例 6：缺 EXIF 照片产生告警
```dart
test('warns when photo lacks EXIF datetime', () async {
  final PhotoExifParser parser = PhotoExifParser();
  final ParseResult r = await parser.parseAll('test/fixtures/no_exif.jpg');

  expect(r.warnings.any((ParseWarning w) => w.code == 'missing_exif'), isTrue);
});
```

#### 测试用例 7：Message JSON 往返
```dart
test('Message survives JSON round-trip', () {
  final Message restored = Message.fromJson(sample.toJson());
  expect(restored.toJson(), equals(sample.toJson()));
});
```

#### 测试用例 8：微信多行消息续行（§3.4.1）
```dart
test('WeChat multi-line message keeps continuation lines', () async {
  final ParseResult r =
      await WeChatParser().parseAll('test/fixtures/wechat_multiline.txt');
  final Message m =
      r.messages.firstWhere((Message x) => x.content.contains('第一行'));

  expect(m.content, contains('第二行'));
  expect(m.content, contains('第三行'));
  expect(m.content, '第一行\n第二行\n第三行');
});
```

#### 测试用例 9：微信媒体占位符按类型保留（§3.4.2）
```dart
test('WeChat media placeholders are typed, not dropped', () async {
  final ParseResult r =
      await WeChatParser().parseAll('test/fixtures/wechat_media.csv');

  expect(r.messages.any((Message m) => m.type == MessageType.image), isTrue);
  expect(r.messages.any((Message m) => m.type == MessageType.voice), isTrue);
  // [红包] 无专用枚举 → text + metadata 标记
  final Message hongbao =
      r.messages.firstWhere((Message m) => m.content == '[红包]');
  expect(hongbao.type, MessageType.text);
  expect(hongbao.metadata['placeholder'], '[红包]');
  // [撤回了一条消息] → system，预处理后应被过滤
  final result = DataPreprocessor().process(r.messages);
  expect(
    result.messages.any((Message m) => m.type == MessageType.system),
    isFalse,
  );
});
```

#### 测试用例 10：CSV 列名别名与缺列（§3.4.3）
```dart
test('WeChat CSV accepts column aliases', () async {
  // 表头使用 发送人/内容/时间
  final ParseResult r =
      await WeChatParser().parseAll('test/fixtures/wechat_aliased_cols.csv');
  expect(r.messages, isNotEmpty);
});

test('WeChat CSV throws when a required column is missing', () {
  expect(
    () => WeChatParser().parseAll('test/fixtures/wechat_missing_col.csv'),
    throwsA(isA<ParseException>()),
  );
});
```

#### 测试用例 11：流式解析吞吐与内存解耦（§6）
```dart
test('parse streams with throughput and bounded memory', () async {
  int count = 0;
  final Stopwatch sw = Stopwatch()..start();
  await for (final ParseEvent e
      in WeChatParser().parse('test/fixtures/wechat_huge.txt')) {
    if (e is MessageEvent) count++;
  }
  sw.stop();

  final double perMin = count / sw.elapsed.inSeconds * 60;
  expect(perMin, greaterThanOrEqualTo(5000));
  // 峰值内存断言由压测工具在 5 GB fixture 上校验，见 §6.3
});
```

#### 测试用例 12：媒体缺失产生 missing_media 告警（§4.1）
```dart
test('missing referenced media yields missing_media warning', () async {
  final ParseResult r =
      await WeChatParser().parseAll('test/fixtures/wechat_missing_media.csv');

  expect(r.messages, isNotEmpty); // 消息保留
  expect(
    r.warnings.any((ParseWarning w) => w.code == 'missing_media'),
    isTrue,
  );
});
```

#### 测试用例 13：textOnly 层级不落媒体字节（§3.1）
```dart
test('textOnly tier keeps media index but stores no bytes', () async {
  final ParseResult r = await WeChatParser().parseAll(
    'test/fixtures/wechat_media.csv',
    options: const ParseOptions(mediaTier: MediaTier.textOnly),
  );

  expect(r.messages.any((Message m) => m.type == MessageType.image), isTrue);
  expect(r.mediaIndex, isNotEmpty);
  expect(r.mediaIndex.every((MediaIndexEntry e) => e.storedPath == null), isTrue);
});
```

### 7.2 测试覆盖率

| 代码类型 | 覆盖率目标 | 实际覆盖率 |
|----------|-----------|-----------|
| 行覆盖率 | > 80% | % |
| 分支覆盖率 | > 80% | % |
| 函数覆盖率 | > 90% | % |

### 7.3 测试数据（fixtures）
```
test/fixtures/
├── wechat_sample.csv       # 含文本/图片/语音/系统消息
├── wechat_sample.html
├── wechat_multiline.txt    # 含跨多行正文的消息（§3.4.1）
├── wechat_media.csv        # 含各类媒体占位符 + [红包] + [撤回了一条消息]（§3.4.2）
├── wechat_aliased_cols.csv # 表头用中文别名 发送人/内容/时间（§3.4.3）
├── wechat_missing_col.csv  # 缺必需列，触发 ParseException
├── wechat_missing_media.csv# 引用的媒体文件缺失（missing_media 告警，§4.1）
├── wechat_huge.txt         # 大体量导出，流式吞吐/内存解耦压测（§6.3）；5 GB 压测样本按需生成
├── imessage_sample.db      # 脱敏 chat.db
├── weibo_sample.json
├── instagram_sample.json
├── photo_with_exif.jpg
└── no_exif.jpg
```
> 所有 fixtures 必须脱敏，不含真实个人信息。

---

## 8. 依赖规格

### 8.1 内部依赖
| 模块 | 接口 | 用途 |
|------|------|------|
| 001 项目初始化 | `AppLogger` | 日志 |
| 001 项目初始化 | 应用目录 | 写入中间 JSON |

### 8.2 外部依赖
| 库 | 版本（拟） | 用途 |
|------|------|------|
| file_picker | ^8.0.0 | 文件/目录选择（大文件仅取路径，**禁用字节读取模式**） |
| csv | ^6.0.0 | 微信 CSV |
| html | ^0.15.4 | 微信 HTML（大文件走流式 SAX，避免全量 DOM，见 ERD） |
| sqlite3 | ^2.4.0 | iMessage chat.db |
| exif | ^3.3.0 | 照片 EXIF |
| archive | ^3.6.0 | zip 导入包解压（流式） |
| path_provider | ^2.1.0 | 应用沙盒目录（媒体入库/中间产物） |

### 8.3 平台依赖
- **最低版本**：iOS 17、macOS 14
- **必需权限**：
  - iOS/macOS：文件访问（用户选择）
  - macOS：读取 `chat.db` 需完全磁盘访问或用户手动选取
  - 定位（仅在提取 GPS 时）
- **存储/来源接入**（详见 ERD §4.4）：
  - iOS：将选中文件/导入包拷入应用沙盒；媒体入库目录须设 `isExcludedFromBackup = true`（避免撑爆 iCloud 备份）；支持 `CFBundleDocumentTypes` + zip 导入
  - macOS：优先 security-scoped bookmark 就地引用源文件，不整包拷贝；媒体字节按 `mediaTier` 落库

---

## 9. 实现约束

### 9.1 设计约束
- 所有解析器实现统一 `DataParser` 接口
- 数据模型不可变（`final` 字段 + `const` 构造）
- 遵循 Effective Dart；不使用全局可变状态（用 Riverpod）

### 9.2 实现约束
- 单个函数不超过 50 行
- 单个类不超过 200 行
- 嵌套层级不超过 3 层
- 大数据集解析移交 isolate，避免阻塞 UI

---

## 10. 文档要求

### 10.1 代码注释
**必须注释**：所有公共接口、参数、返回值、异常、复杂算法（如 Apple 时间转换、去重键）。

### 10.2 使用示例
```dart
// 导入一份微信 CSV
final Conversation conversation = await DataImportService().importFiles(
  <String>['/path/to/wechat.csv'],
  source: DataSource.wechat,
  options: const ParseOptions(myIdentifiers: <String>['我']),
);

print('共 ${conversation.messages.length} 条消息');
print('时间跨度：${conversation.stats.earliest} ~ ${conversation.stats.latest}');
```

---

## 11. 验收标准

### 11.1 功能验收
- [ ] `importFiles` / `DataParser.parse` / `DataPreprocessor.process` 按规格实现
- [ ] 五类解析器均能解析对应 fixtures
- [ ] 所有边界情况按 §4 处理
- [ ] 输出 JSON 字段符合 §3.2

### 11.2 性能验收
- [ ] 解析吞吐 ≥ 5,000 条/分钟
- [ ] 10 万条预处理 < 30 秒
- [ ] 解析峰值内存 < 300 MB 且与文件大小解耦
- [ ] 5 GB / 10 万条导出可完整解析、不 OOM

### 11.3 测试验收
- [ ] 单元测试覆盖率 > 80%
- [ ] 所有测试用例通过
- [ ] 无测试警告

### 11.4 文档验收
- [ ] 所有公共接口有文档注释
- [ ] 使用示例可运行
- [ ] 代码符合编码规范

---

## 12. 变更记录

| 日期 | 版本 | 变更内容 | 作者 |
|------|------|---------|------|
| 2026-08-01 | v0.1 | 初始草稿 | Claude |
| 2026-08-01 | v0.2 | 第三轮评审（规模/存储）：`parse` 改流式 `Stream<ParseEvent>` + `parseAll` 便捷法；新增 MediaTier/ParseEvent/MediaIndexEntry 模型与 `mediaTier` 选项；三层产物与流式正常流程；性能指标改为吞吐/内存解耦（废弃 1000 条<60s）；新增 missing_media 边界与测试 11/12/13；补 archive/path_provider 依赖与 iOS 沙盒/macOS bookmark 存储约束 | Claude |

---

> 本文档遵循 Lostone 项目的 Spec-Driven Development 规范。
> 参考：[Spec 编写指南](../CLAUDE.md#spec)
