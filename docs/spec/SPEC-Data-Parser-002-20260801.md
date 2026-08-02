# SPEC-Data-Parser-002-20260801

> 技术规格文档 - 数据解析器
>
> **版本**：v0.1
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

**后置条件**（Postconditions）：
- [ ] 返回的 `messages` 已去重且按 `timestamp` 升序
- [ ] `stats.afterDedup == messages.length`
- [ ] 单文件解析失败被记录为告警而非中断（除非全部失败）

**不变性条件**（Invariants）：
- 相同输入多次调用产出等价结果（幂等、无副作用于源文件）

---

#### 接口 2：DataParser.parse

**功能**：将单个文件解析为标准消息

**签名**：
```dart
/// 解析文件为标准消息。
///
/// 参数：
/// - [filePath]：文件路径。
/// - [options]：解析选项。
///
/// 返回：Future<ParseResult>（可能部分成功，附带告警）
///
/// 抛出：
/// - [ParseException]：文件无法解析（致命）。
Future<ParseResult> parse(
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
| 字段名 | 类型 | 说明 |
|--------|------|------|
| messages | List<Message> | 解析出的消息（未全局预处理） |
| warnings | List<ParseWarning> | 非致命告警 |

**前置条件**：
- [ ] 文件存在且可读
- [ ] `canParse(filePath)` 返回 true

**后置条件**：
- [ ] 每条 `Message` 的 `source`/`timestamp`/`type` 均已填充
- [ ] 无法解析的单行进入 `warnings`，不抛异常

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
}
```

**验证规则**：
- `targetContact`：iMessage `chat.db` 场景建议提供；为空时导出全部会话
- `extractLocation`：为 true 时须已获得系统/用户授权，否则退化为 false 并告警
- `myIdentifiers`：为空时解析器按数据源默认规则判定 `isFromMe`

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
| 缺失 EXIF 的照片 | 无 `DateTimeOriginal` | 跳过该照片 + 告警 `missing_exif` |
| 未授权却要求提取 GPS | extractLocation=true | 退化为不提取 + 告警 `location_not_authorized` |

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
3. 逐文件：match → parse（隔离异常）
4. 汇总 messages + warnings
5. preprocessor.process(messages)（清洗/去重/排序）
6. 组装 Conversation + ImportStats
7. 返回
```

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
- O(n)（消息列表 + 去重集合）
- 峰值内存：< 500 MB

### 6.3 性能指标

| 指标 | 要求 | 测试方法 |
|------|------|---------|
| 1000 条解析 | < 60 秒 | 单元测试计时 |
| 10,000 条预处理 | < 5 秒 | 单元测试计时 |
| 文件选择响应 | < 1 秒 | 手动/集成测试 |
| 峰值内存 | < 500 MB | 内存分析工具 |

---

## 7. 测试规格

### 7.1 单元测试

#### 测试用例 1：微信 CSV 正常解析
```dart
test('parses WeChat CSV into messages', () async {
  final WeChatParser parser = WeChatParser();
  final ParseResult r = await parser.parse('test/fixtures/wechat_sample.csv');

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
  final ParseResult r = await parser.parse('test/fixtures/no_exif.jpg');

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
| file_picker | ^8.0.0 | 文件选择 |
| csv | ^6.0.0 | 微信 CSV |
| html | ^0.15.4 | 微信 HTML |
| sqlite3 | ^2.4.0 | iMessage chat.db |
| exif | ^3.3.0 | 照片 EXIF |

### 8.3 平台依赖
- **最低版本**：iOS 17、macOS 14
- **必需权限**：
  - iOS/macOS：文件访问（用户选择）
  - macOS：读取 `chat.db` 需完全磁盘访问或用户手动选取
  - 定位（仅在提取 GPS 时）

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
- [ ] 1000 条解析 < 60 秒
- [ ] 10,000 条预处理 < 5 秒
- [ ] 峰值内存 < 500 MB

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

---

> 本文档遵循 Lostone 项目的 Spec-Driven Development 规范。
> 参考：[Spec 编写指南](../CLAUDE.md#spec)
