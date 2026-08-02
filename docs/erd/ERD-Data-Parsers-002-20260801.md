# ERD-Data-Parsers-002-20260801

> 工程需求文档 - 数据解析器
>
> **版本**：v0.3
> **状态**：📝 草稿
> **作者**：Claude
> **日期**：2026-08-01
> **批准日期**：待批准
> **批准人**：待批准
> **关联 PRD**：PRD-Data-Import-002-20260801.md

---

## 📋 文档信息

| 项目 | 内容 |
|------|------|
| **ERD 编号** | 002 |
| **模块名称** | 数据解析器（Data Parsers） |
| **关联 PRD** | PRD-Data-Import-002-20260801.md |
| **关联 Spec** | SPEC-Data-Parser-002-20260801.md |
| **技术栈** | Flutter 3.38+, Dart 3.11+ |

---

## 1. 技术目标

### 1.1 核心目标
建立一个**可扩展、可测试、隐私优先**的数据导入与解析层：
- 统一的解析器接口，接入新数据源零改动主流程
- 统一的消息数据模型（`Message` / `Conversation`）
- 可组合的预处理管线（清洗 / 去重 / 排序）
- 稳定的结构化 JSON 输出，供 Persona 引擎消费

### 1.2 性能目标
按真实规模（数 GB / 10 万条以上）制定，**峰值内存与文件大小解耦**：
- 文本吞吐 ≥ 5,000 条/分钟（10 万条 ≤ 20 分钟，可后台）
- 解析峰值内存 < 300 MB，且与输入文件大小无关（5GB 文件同样成立）
- 10 万条预处理（去重 + 排序）< 30 秒
- 媒体流式拷贝，不计入解析内存预算

### 1.3 质量目标
- 解析/预处理逻辑代码覆盖率 > 80%
- `flutter analyze` 无警告
- 所有公共 API 有文档注释

---

## 2. 设计约束

### 2.1 技术约束
- **语言**：Dart 3.11+
- **框架**：Flutter 3.38+（对齐模块 001 实际工具链）
- **平台**：iOS 17+、macOS 14+
- **纯本地**：解析过程不得发起任何网络请求

### 2.2 业务约束
- 单文件解析失败必须隔离，不影响其他文件
- 地理位置提取必须在用户授权后进行
- 日志不得输出消息正文

### 2.3 依赖约束
- 新增第三方依赖须开源且许可证兼容（见 PRD 许可）
- 候选依赖：`file_picker`、`exif`、`sqlite3`、`csv`、`html`

---

## 3. 架构设计

### 3.1 模块架构图
```
┌───────────────────────────────────────────────┐
│                DataImportService               │  编排：导入源→解析→预处理→标准化→落库
├───────────────────────────────────────────────┤
│ ImportSource (平台抽象)  │     MediaStore        │
│ iOS: zip 解压进沙盒      │ 文本层/索引层恒存      │
│ macOS: security-scoped   │ 字节层按分级档拷贝/引用 │
│        bookmark 就地引用 │ (iOS isExcludedFromBackup)│
├───────────────────────────────────────────────┤
│  ParserRegistry     │      DataPreprocessor     │
│  (解析器注册与调度)  │   (清洗 / 去重 / 排序)     │
├───────────────────────────────────────────────┤
│              DataParser (接口, 流式)            │
│  WeChatParser │ IMessageParser │ WeiboParser    │
│  InstagramParser │ PhotoExifParser              │
├───────────────────────────────────────────────┤
│   Models: Message / MediaIndexEntry /           │
│           Conversation                          │
└───────────────────────────────────────────────┘
```

> 关键原则：**解析全程流式**（`Stream<ParseEvent>`：MessageEvent / MediaIndexEvent / WarningEvent），峰值内存与输入文件大小解耦；媒体索引由解析器随消息产出（`storedPath` 恒空），媒体字节层与文本层解耦，由 `MediaStore` 按分级档位单独落地并回填 `storedPath`。

### 3.2 组件设计
| 组件名称 | 职责 | 技术实现 |
|----------|------|---------|
| `DataImportService` | 编排整个导入流程 | 异步服务、单例、流式 |
| `ImportSource` | 平台导入源抽象（iOS 沙盒解压 / macOS 书签就地引用） | 条件平台实现 |
| `MediaStore` | 媒体三层落地：文本/索引恒存，字节按分级档拷贝/引用 | 流式拷贝 + `isExcludedFromBackup` |
| `ParserRegistry` | 注册/查找/自动匹配解析器 | Map + `canParse` 探测 |
| `DataParser` | 解析单一数据源的抽象接口 | `abstract interface class` |
| `WeChatParser` | 微信 CSV/HTML 解析 | `csv` 包；HTML 大文件走自研分块 tokenizer（`html` 仅小文件回退，见 §8.1） |
| `IMessageParser` | iMessage 导出 + `chat.db` | `sqlite3` 包 |
| `PhotoExifParser` | 照片 EXIF 提取 | `exif` 包 |
| `WeiboParser` / `InstagramParser` | 社媒 JSON 解析 | `dart:convert` |
| `DataPreprocessor` | 清洗、去重、时间排序 | 纯函数管线 |
| `Message` / `Conversation` | 统一数据模型 | 不可变 Dart 类 + JSON |

### 3.3 模块依赖
```
screens/ → providers/ → services/DataImportService
                              ↓
                 ParserRegistry → DataParser 实现
                              ↓
                      DataPreprocessor
                              ↓
                 models/ (Message, Conversation)
                              ↓
                          utils/ (AppLogger)
```

### 3.4 目录规划
```
mobile/lib/
├── models/
│   ├── message.dart              # Message、MessageType、DataSource
│   ├── conversation.dart         # Conversation、ImportStats
│   └── parse_result.dart         # ParseResult、ParseOptions、ParseWarning
├── services/
│   ├── data_import_service.dart  # 编排入口
│   ├── data_preprocessor.dart    # 清洗/去重/排序
│   ├── parser_registry.dart      # 解析器注册与调度
│   └── parsers/
│       ├── data_parser.dart      # DataParser 接口
│       ├── wechat_parser.dart
│       ├── imessage_parser.dart
│       ├── photo_exif_parser.dart
│       ├── weibo_parser.dart
│       └── instagram_parser.dart
└── providers/
    └── import_providers.dart     # 导入状态
```

---

## 4. 数据结构定义

### 4.1 核心数据模型

#### 模型 1：DataSource（数据源枚举）
```dart
/// 支持的数据源类型。
enum DataSource {
  /// 微信。
  wechat,

  /// iMessage。
  imessage,

  /// 微博。
  weibo,

  /// Instagram。
  instagram,

  /// 照片元数据。
  photo,

  /// 未知/待自动识别。
  unknown,
}
```

#### 模型 2：MessageType（消息类型枚举）
```dart
/// 消息内容类型。
enum MessageType {
  /// 纯文本。
  text,

  /// 图片。
  image,

  /// 语音。
  voice,

  /// 视频。
  video,

  /// 地理位置。
  location,

  /// 系统消息（预处理阶段通常被过滤）。
  system,
}
```

#### 模型 3：Message（统一消息模型）
```dart
/// 标准化的单条消息。
///
/// 所有解析器最终都产出 [Message]，屏蔽各数据源的格式差异。
class Message {
  /// 创建一条消息。
  const Message({
    required this.id,
    required this.source,
    required this.senderId,
    required this.senderName,
    required this.isFromMe,
    required this.timestamp,
    required this.type,
    required this.content,
    this.mediaPath,
    this.metadata = const <String, dynamic>{},
  });

  /// 稳定的消息标识（引用/展示用途，**非去重键**）。
  ///
  /// 去重以内容复合键为准（见 ERD §6.1 算法1）；解析器可用
  /// `<source>-<序号>` 等生成，仅需在单次导入内可引用即可。
  final String id;

  /// 来源数据源。
  final DataSource source;

  /// 发送者标识（平台内唯一）。
  final String senderId;

  /// 发送者展示名。
  final String senderName;

  /// 是否为“我”发出。
  final bool isFromMe;

  /// 消息时间。
  final DateTime timestamp;

  /// 消息类型。
  final MessageType type;

  /// 文本内容（非文本类型可为占位/摘要）。
  final String content;

  /// 媒体文件引用路径（图片/语音/视频，可空）。
  final String? mediaPath;

  /// 额外元数据（如语音时长、经纬度）。
  final Map<String, dynamic> metadata;

  /// JSON 序列化。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'source': source.name,
        'senderId': senderId,
        'senderName': senderName,
        'isFromMe': isFromMe,
        'timestamp': timestamp.toIso8601String(),
        'type': type.name,
        'content': content,
        'mediaPath': mediaPath,
        'metadata': metadata,
      };

  /// JSON 反序列化。
  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as String,
        source: DataSource.values.byName(json['source'] as String),
        senderId: json['senderId'] as String,
        senderName: json['senderName'] as String,
        isFromMe: json['isFromMe'] as bool,
        timestamp: DateTime.parse(json['timestamp'] as String),
        type: MessageType.values.byName(json['type'] as String),
        content: json['content'] as String,
        mediaPath: json['mediaPath'] as String?,
        metadata:
            (json['metadata'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      );
}
```

#### 模型 3.5：MediaTier（媒体分级档位）
```dart
/// 媒体字节层的导入档位（文本与索引层始终保存）。
enum MediaTier {
  /// 仅文本 + 媒体索引（路径），不拷贝任何媒体字节。
  textOnly,

  /// 仅拷贝照片与语音字节。
  photoAndVoice,

  /// 拷贝全部媒体字节（默认）。
  all,
}
```

#### 模型 3.6：MediaIndexEntry（媒体索引）
```dart
/// 媒体索引条目：每个图片/视频/语音一条，**只存引用不存字节**。
class MediaIndexEntry {
  /// 创建一条媒体索引。
  const MediaIndexEntry({
    required this.source,
    required this.senderId,
    required this.timestamp,
    required this.type,
    required this.sourceRef,
    this.storedPath,
    this.available = true,
  });

  /// 来源数据源。
  final DataSource source;

  /// 发送者标识。
  final String senderId;

  /// 媒体时间。
  final DateTime timestamp;

  /// 媒体类型（image/voice/video/…）。
  final MessageType type;

  /// 源媒体引用（导出包内相对路径/标识，或书签可解析路径）。
  final String sourceRef;

  /// 已落库字节路径（沙盒内）；未入库（如 `MediaTier.textOnly`）时为 null。
  final String? storedPath;

  /// 源字节是否存在（缺失/被移动时为 false → `missing_media` 告警）。
  final bool available;
}
```

> **Message 与 MediaIndexEntry 的关系（单一真相来源）**：每条媒体类 `Message`（`type ∈ {image,voice,video,location}`）恰好对应一条 `MediaIndexEntry`。二者以 `(source, senderId, timestamp, type)` 关联。字段归属明确、互不重复：
> - `Message.mediaPath` **等于** `MediaIndexEntry.sourceRef`（解析器产出的源引用），是消息在对话语料中的媒体占位引用；
> - 解析后落地的沙盒字节路径**只存在于** `MediaIndexEntry.storedPath`（由 `MediaStore` 填充），**不回写 `Message`**；
> - `Message` 属文本语料层（对话上下文），`MediaIndexEntry` 属媒体索引层（字节解析/浏览）。实现不得在两处各自维护一份可变的路径状态。

#### 模型 4：Conversation（会话）
```dart
/// 一次导入产出的标准化会话。
class Conversation {
  /// 创建一个会话。
  const Conversation({
    required this.source,
    required this.participants,
    required this.messages,
    required this.stats,
  });

  /// 主要数据源。
  final DataSource source;

  /// 参与者展示名列表（由预处理后消息的 `senderName` 去重收集，
  /// 按首次出现顺序排列）。
  final List<String> participants;

  /// 已清洗、去重、排序后的消息。
  final List<Message> messages;

  /// 导入统计。
  final ImportStats stats;

  /// JSON 序列化。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'source': source.name,
        'participants': participants,
        'messages': messages.map((Message m) => m.toJson()).toList(),
        'stats': stats.toJson(),
      };
}
```

#### 模型 5：ImportStats（导入统计）
```dart
/// 导入结果统计。
class ImportStats {
  /// 创建统计信息。
  const ImportStats({
    required this.totalParsed,
    required this.afterDedup,
    required this.skipped,
    required this.earliest,
    required this.latest,
  });

  /// 解析出的原始条数。
  final int totalParsed;

  /// 清洗与去重后的最终条数（等于 `Conversation.messages.length`）。
  ///
  /// 注意：`skipped` 同时包含系统消息过滤与去重两部分，故本字段是
  /// “清洗+去重后”的结果，不仅是去重。
  final int afterDedup;

  /// 被跳过/过滤的条数。
  final int skipped;

  /// 最早消息时间（可空）。
  final DateTime? earliest;

  /// 最晚消息时间（可空）。
  final DateTime? latest;

  /// JSON 序列化。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'totalParsed': totalParsed,
        'afterDedup': afterDedup,
        'skipped': skipped,
        'earliest': earliest?.toIso8601String(),
        'latest': latest?.toIso8601String(),
      };
}
```

#### 模型 6：ParseResult / ParseOptions / ParseWarning
```dart
/// 流式解析事件。解析以事件流产出，峰值内存与文件大小解耦。
sealed class ParseEvent {
  const ParseEvent();
}

/// 一条已解析消息。
class MessageEvent extends ParseEvent {
  /// 创建消息事件。
  const MessageEvent(this.message);

  /// 消息本体。
  final Message message;
}

/// 一条媒体索引（每个媒体消息随之产出一条）。
///
/// 解析器产出时 `storedPath` 恒为 null（解析器不落字节）；`available`
/// 反映解析器在导出包中能否定位到具体文件引用。字节落地与 `storedPath`
/// 的填充由下游 [MediaStore] 按 [ParseOptions.mediaTier] 完成。
class MediaIndexEvent extends ParseEvent {
  /// 创建媒体索引事件。
  const MediaIndexEvent(this.entry);

  /// 索引条目本体。
  final MediaIndexEntry entry;
}

/// 一条非致命告警。
class WarningEvent extends ParseEvent {
  /// 创建告警事件。
  const WarningEvent(this.warning);

  /// 告警本体。
  final ParseWarning warning;
}

/// 排空事件流后的聚合结果（供小文件/测试便捷使用）。
///
/// 注意：仅在数据量可控时使用；大文件应直接消费 [ParseEvent] 流。
class ParseResult {
  /// 创建解析结果。
  const ParseResult({
    required this.messages,
    this.mediaIndex = const <MediaIndexEntry>[],
    this.warnings = const <ParseWarning>[],
  });

  /// 解析出的消息（未经全局预处理）。
  final List<Message> messages;

  /// 媒体索引层（只存引用，不含字节），由排空 [MediaIndexEvent] 聚合而来。
  /// 解析器产出时每条 `storedPath` 恒为 null；字节落地与 `storedPath` 填充由
  /// 下游 [MediaStore] 按 [ParseOptions.mediaTier] 完成，不在 [ParseResult] 内。
  final List<MediaIndexEntry> mediaIndex;

  /// 解析过程中的告警。
  final List<ParseWarning> warnings;
}

/// 解析选项。
class ParseOptions {
  /// 创建解析选项。
  const ParseOptions({
    this.targetContact,
    this.extractLocation = false,
    this.myIdentifiers = const <String>[],
    this.mediaTier = MediaTier.all,
  });

  /// 目标联系人（macOS chat.db 等场景）。
  final String? targetContact;

  /// 是否提取地理位置（需授权）。
  final bool extractLocation;

  /// 用于判定 isFromMe 的“我”的标识集合。
  final List<String> myIdentifiers;

  /// 媒体字节层导入档位，默认 [MediaTier.all]（owner 决策）。
  final MediaTier mediaTier;
}

/// 一条解析告警（非致命）。
class ParseWarning {
  /// 创建一条告警。
  const ParseWarning(this.code, this.message, {this.line});

  /// 告警码（如 `missing_exif`、`malformed_row`）。
  final String code;

  /// 人类可读的描述。
  final String message;

  /// 触发告警的行号/位置（可空）。
  final int? line;
}
```

---

### 4.2 数据库设计

本模块**读取** iMessage 的 `chat.db`（SQLite），但**不创建自有数据库**。中间产物以 JSON 落盘。相关只读表：

| 表 | 关键字段 | 用途 |
|----|---------|------|
| `message` | `ROWID`, `text`, `date`, `is_from_me`, `handle_id` | 消息正文/时间/方向 |
| `handle` | `ROWID`, `id` | 联系人标识 |
| `chat` | `ROWID`, `chat_identifier` | 会话标识 |
| `chat_message_join` | `chat_id`, `message_id` | 会话-消息关联 |

> `date` 为 Apple 绝对时间（自 2001-01-01 UTC 起的纳秒），需转换为标准 `DateTime`。

---

### 4.3 数据存储格式

#### 输出 JSON（供模块 003）
```json
{
  "source": "wechat",
  "participants": ["我", "妈妈"],
  "stats": {
    "totalParsed": 1200,
    "afterDedup": 1180,
    "skipped": 20,
    "earliest": "2019-03-01T08:12:00.000",
    "latest": "2024-11-20T22:05:00.000"
  },
  "messages": [
    {
      "id": "wechat-0001",
      "source": "wechat",
      "senderId": "mom",
      "senderName": "妈妈",
      "isFromMe": false,
      "timestamp": "2019-03-01T08:12:00.000",
      "type": "text",
      "content": "记得吃早饭",
      "mediaPath": null,
      "metadata": {}
    }
  ]
}
```

#### 新增依赖（拟）
```yaml
dependencies:
  file_picker: ^8.0.0     # 目录/文件选择
  archive: ^3.6.0         # zip 流式解压（iOS 导入）
  csv: ^6.0.0             # 微信 CSV
  html: ^0.15.4           # 仅小文件/well-formed 片段回退；大文件走自研分块 tokenizer（见 §8.1）
  sqlite3: ^2.4.0         # iMessage chat.db
  exif: ^3.3.0            # 照片 EXIF
  path: ^1.9.0            # 路径处理
  path_provider: ^2.1.0   # 沙盒目录
```
> 具体版本在实现期以 `flutter pub get` 解析结果为准，并在实现 PR 中固定。

---

### 4.4 存储模型（分平台）

真实导出可达数 GB，"落在哪、拷不拷、进不进备份"是核心问题。三层分别处理：

| 层 | iOS | macOS |
|----|-----|-------|
| 文本语料 | 沙盒内 SQLite/JSON（恒存） | 应用支持目录 SQLite/JSON（恒存） |
| 媒体索引 | 沙盒内（恒存，仅路径） | 应用支持目录（恒存，仅路径） |
| 媒体字节 | **拷入沙盒**，目录标记 `isExcludedFromBackup` | **就地引用**（security-scoped bookmark），不拷贝 |

**iOS 导入路径**：
- 通过 `CFBundleDocumentTypes` 注册可打开的文件类型（zip 等），支持「用其他应用打开 / AirDrop」。
- 收到 zip 后**流式解压**进沙盒（`archive` 流式 API），边解压边解析，不一次性载入。
- 媒体字节按 `MediaTier` 拷入沙盒；媒体目录设置 `isExcludedFromBackup = true`，避免撑爆 iCloud 备份、规避 App Review。

**macOS 导入路径**：
- `file_picker` **选目录**（而非选文件），获取 security-scoped bookmark 持久化访问权限。
- 媒体字节就地引用，`MediaIndexEntry.sourceRef` 保存书签可解析的相对/绝对路径（`storedPath` 保持 null，不拷贝）；访问时 `startAccessingSecurityScopedResource`。

**通用**：
- **禁止**用 `file_picker` 的文件选择模式导入大文件——iOS 会把选中文件整份拷进临时目录（等于拷 5GB）；一律走 zip（iOS）或目录（macOS）路径。

---

## 5. 接口设计

### 5.1 核心接口

#### 接口 1：DataParser（解析器抽象）
```dart
/// 数据源解析器的统一接口。
///
/// 每个数据源实现一个 [DataParser]；[ParserRegistry] 负责调度。
abstract interface class DataParser {
  /// 本解析器对应的数据源。
  DataSource get source;

  /// 快速判断是否能解析给定文件（基于扩展名/魔数/结构探测）。
  Future<bool> canParse(String filePath);

  /// **流式**解析文件，逐条产出 [ParseEvent]：
  /// [MessageEvent]（消息）、[MediaIndexEvent]（媒体索引）、[WarningEvent]（告警）。
  ///
  /// 每条媒体类消息同时产出一个 [MediaIndexEvent]（`storedPath` 恒为 null）；
  /// 字节落地由下游 [MediaStore] 负责。峰值内存必须与文件大小解耦
  /// （不得全量载入 DOM/字节）。
  ///
  /// 抛出：
  /// - [ParseException]：当文件无法解析（致命，通常在首个事件前）。
  Stream<ParseEvent> parse(
    String filePath, {
    ParseOptions options = const ParseOptions(),
  });

  /// 便捷方法：排空 [parse] 流为 [ParseResult]。仅供小文件/测试使用。
  Future<ParseResult> parseAll(
    String filePath, {
    ParseOptions options = const ParseOptions(),
  });
}
```

#### 接口 2：DataPreprocessor（预处理）
```dart
/// 消息预处理管线：清洗 → 去重 → 排序。
class DataPreprocessor {
  /// 执行完整预处理并返回结果与统计。
  ({List<Message> messages, int skipped}) process(List<Message> input);
}
```

#### 接口 3：DataImportService（编排入口）
```dart
/// 数据导入编排服务。
class DataImportService {
  /// 导入一个或多个文件并产出标准化会话。
  ///
  /// 单文件解析失败会被隔离为告警，不中断整体流程。
  Future<Conversation> importFiles(
    List<String> filePaths, {
    DataSource? source,
    ParseOptions options = const ParseOptions(),
  });
}
```

### 5.2 状态管理
```dart
/// 导入阶段。
enum ImportPhase { idle, picking, parsing, preprocessing, done, failed }

/// 导入状态。
final importStateProvider =
    StateNotifierProvider<ImportNotifier, ImportState>((Ref ref) {
  return ImportNotifier();
});
```

### 5.3 API 端点
不适用（客户端本地模块，无网络端点）。

---

## 6. 实现细节

### 6.1 关键算法

#### 算法 1：去重
**目的**：去除跨文件/重复导入产生的完全重复消息

**去重键（唯一权威定义）**：`hash(source | senderId | timestamp.iso | content | type)`。
`Message.id` **不参与去重**——它只是引用标识，不同解析器/多次导入可能给相同内容分配不同 id，故不能用作去重依据。

**步骤**：
```
1. 初始化空 Set<String> seen 与结果列表
2. 遍历消息：计算 key
3. 若 key ∈ seen → skipped++；否则加入 seen 与结果
4. 返回结果与 skipped 计数
```
**复杂度**：时间 O(n)，空间 O(n)

#### 算法 2：时间排序
- 按 `timestamp` 升序稳定排序；`timestamp` 相等时保持解析顺序。
- 复杂度：O(n log n)

#### 算法 3：Apple 时间转换（iMessage）
`chat.db` 的 `message.date` 有两种单位：macOS 10.13 之前为**秒**，之后为**纳秒**（均自 2001-01-01 UTC 起）。
以数量级判定单位（确定性阈值）：秒格式约 10^8~10^9，纳秒格式约 10^17~10^18，取 `1e12` 为分界，二者相差远超阈值，未来数十年内不会歧义。
```
const int kAppleNanoThreshold = 1000000000000; // 1e12
epoch2001 = DateTime.utc(2001, 1, 1)
seconds = date.abs() >= kAppleNanoThreshold ? date ~/ 1000000000 : date
result = epoch2001.add(Duration(seconds: seconds)) // 以 UTC 计算，展示层再 toLocal()
```

### 6.2 解析流程
```
importFiles(paths)
  → for each path (隔离 try/catch)：
        parser = registry.match(path, source)
        result = parser.parse(path, options)
        累积 messages + warnings
  → preprocessor.process(allMessages)
  → 组装 Conversation + ImportStats
```

**解析器特定要求（规范细节见 SPEC §3.4）**：
- **WeChatParser**：必须支持多行正文续行（消息头之后的非头行追加到上一条），媒体占位符按类型保留（`[图片]→image`、`[语音]→voice` 等，`[撤回了一条消息]→system`），CSV 列名按别名集容错。
- **PhotoExifParser**：`exif` 包默认只取 `DateTimeOriginal`；`extractLocation=true` 时须**显式解析 GPS IFD**（`GPSLatitude`/`GPSLongitude` + 参考方向）并换算十进制经纬度写入 `metadata`。此处无参考实现可抄，实现者须自行接线并测试。

### 6.3 错误处理

#### 错误类型
```dart
/// 解析致命错误。
class ParseException implements Exception {
  /// 创建解析异常。
  ParseException(this.source, this.message, {this.details});

  /// 出错的数据源。
  final DataSource source;

  /// 错误摘要。
  final String message;

  /// 可选详情。
  final String? details;

  @override
  String toString() =>
      'ParseException(${source.name}): $message${details != null ? ' - $details' : ''}';
}

/// 整体导入失败（所有文件均未产出任何消息时由 [DataImportService] 抛出）。
class ImportException implements Exception {
  /// 创建一个导入异常。
  ImportException(this.message);

  /// 错误摘要。
  final String message;

  @override
  String toString() => 'ImportException: $message';
}
```

#### 处理策略
| 错误类型 | 处理方式 | 用户提示 |
|----------|---------|---------|
| `ParseException`（单文件） | 隔离为告警，继续其他文件 | "某文件解析失败，已跳过" |
| `ImportException`（全部文件失败） | 抛出并展示错误页 | "没有可导入的数据" |
| `missing_exif`（告警） | 记录告警并跳过该条 | 结果页显示告警数 |
| `missing_media`（告警） | 媒体字节缺失/被移动：保留索引条目 `available=false`，不报致命 | 结果页显示缺失媒体数 |
| 权限不足（chat.db / 书签） | 明确提示授权步骤 | "需要访问权限" |

### 6.4 日志策略
- 使用模块 001 的 `AppLogger`
- 仅记录条数、耗时、告警码；**不记录消息正文**
- 示例：`[INFO] [WeChatParser] parsed 1200 rows, 3 warnings in 4.2s`

---

## 7. 测试策略

### 7.1 单元测试
**测试框架**：`flutter_test`

**测试重点**：
- 各解析器：正常样例、缺字段、乱码、空文件、格式错误行
- `DataPreprocessor`：系统消息过滤、去重、排序稳定性
- 模型：`Message`/`Conversation` JSON 往返
- Apple 时间转换、isFromMe 判定

**覆盖率目标**：> 80%

**测试用例（示例）**：
```dart
group('DataPreprocessor', () {
  test('should drop duplicate messages', () {
    final DataPreprocessor pre = DataPreprocessor();
    final result = pre.process(<Message>[m1, m1, m2]);
    expect(result.messages.length, 2);
    expect(result.skipped, 1);
  });

  test('should sort messages ascending by timestamp', () {
    final DataPreprocessor pre = DataPreprocessor();
    final result = pre.process(<Message>[late, early]);
    expect(result.messages.first.timestamp.isBefore(result.messages.last.timestamp), isTrue);
  });
});
```

### 7.2 集成测试
- 端到端：`importFiles([fixtureCsv])` → 断言条数、时间跨度、participants、输出 JSON schema
- 使用脱敏 fixtures：`test/fixtures/wechat_sample.csv`、`imessage_sample.db` 等

### 7.3 性能测试
```dart
test('parse memory stays bounded regardless of file size', () async {
  // 消费 5GB 级 fixture 的事件流，断言不 OOM 且吞吐达标。
  int count = 0;
  final Stopwatch sw = Stopwatch()..start();
  await for (final ParseEvent e in WeChatParser().parse(fixtureHuge)) {
    if (e is MessageEvent) count++;
  }
  sw.stop();
  final double perMin = count / sw.elapsed.inSeconds * 60;
  expect(perMin, greaterThanOrEqualTo(5000));
});
```
> 峰值内存以设备/CI 内存采样验证 < 300 MB，且对 100MB 与 5GB 输入无显著差异（内存与文件大小解耦）。

---

## 8. 性能优化

### 8.1 性能瓶颈分析
| 瓶颈 | 原因 | 优化方案 |
|------|------|---------|
| 大文件全量载入（OOM） | 一次性读入内存 | **强制流式/分块解析**（`Stream<List<int>>`），峰值内存与文件大小解耦 |
| HTML DOM 全量构建（OOM） | `package:html` 构建整棵 DOM | **自研分块 tokenizer**（见下方「HTML 流式方案（已定）」）；`package:html` 仅用于小文件/well-formed 片段回退 |
| 去重哈希开销 | 字符串拼接 | 预分配、复用 StringBuffer |
| 大批量排序阻塞 UI | 主 isolate 计算 | 大数据集移至 `compute`/isolate |

#### HTML 流式方案（已定）
> 评审指出：`package:html` 是 **DOM-only**，无 SAX/流式 API；`XmlEventReader` 属 `package:xml` 且微信导出的 HTML 往往并非 well-formed XML，Dart 生态没有等价于 Python `html.parser` 的流式解析器。因此**不能依赖 `package:html` 处理大文件**。
>
> **定案**：微信 HTML 导出为高度规整的重复块结构（每条消息一个块），大文件走**自研分块 tokenizer**——以 `Stream<List<int>>` 按字节/行读入，用块起止标记切分出单条消息块，逐块 emit，不构建 DOM。`package:html` 仅保留用于小文件或对单个已切出的 well-formed 片段做字段抽取（可选回退）。
>
> **实现前置**：编码期先做一个 spike 用真实微信 HTML 导出验证块边界正则/标记的稳定性，并据此在实现 PR 固定最终方案；`pubspec` 依赖表中的 `html` 仅标注为小文件/回退用途，不作为大文件流式解析的依据。

### 8.2 优化措施
- const 构造 + 不可变模型，减少拷贝
- 使用 `compute` 在后台 isolate 执行重解析
- 预处理只遍历必要次数（清洗+去重可单次遍历）

---

## 9. 安全考虑

### 9.1 数据安全
- 全程本地；解析中不发起网络请求
- 中间 JSON 落在应用私有沙盒目录
- 长期加密由模块 008 负责

### 9.2 代码安全
- 输入验证：扩展名、大小、编码探测
- 异常隔离：单文件失败不影响整体
- 日志脱敏：不输出正文/联系人明文

---

## 10. 部署方案

### 10.1 依赖管理
在实现 PR 中向 `pubspec.yaml` 添加第 4.3 节依赖，并提交更新后的 `pubspec.lock`。

### 10.2 平台配置
- iOS/macOS：文件访问权限说明（Info.plist）
- macOS：读取 `chat.db` 需完全磁盘访问或用户手动选择文件（沙盒）

---

## 11. 技术债务

### 11.1 已知债务
| 债务描述 | 影响 | 计划偿还时间 |
|----------|------|-------------|
| 输出为 JSON 而非 Protobuf | 文件偏大 | 见 ADR-003，Persona 文件格式定案后迁移 |
| 语音/图片仅存引用不识别 | 语料信息有限 | 后续模块按需增强 |

### 11.2 避免策略
- 统一模型与接口，降低后续替换成本
- 解析器版本化，隔离格式变更影响

---

## 12. 监控与维护
- 关键日志：每文件解析条数、耗时、告警码
- 回归：以 fixtures 为基准的解析回归测试

---

## 13. 参考资料
- [file_picker](https://pub.dev/packages/file_picker)
- [sqlite3](https://pub.dev/packages/sqlite3)
- [exif](https://pub.dev/packages/exif)
- ADR-003：使用 Protocol Buffers 作为 Persona 文件格式（提议中）

---

## 14. 变更记录
| 日期 | 版本 | 变更内容 | 作者 |
|------|------|---------|------|
| 2026-08-01 | v0.1 | 初始草稿 | Claude |
| 2026-08-01 | v0.2 | 第三轮评审（规模/存储）：`DataParser.parse` 改为 `Stream<ParseEvent>` + `parseAll` 便捷法；新增 ParseEvent/MediaTier/MediaIndexEntry 模型与三层解析产物；`ParseResult` 增加 `mediaIndex`；新增 §4.4 分平台存储模型（iOS 沙盒拷贝+isExcludedFromBackup / macOS security-scoped bookmark）；性能目标改为吞吐/内存解耦；补 archive/path_provider 依赖 | Claude |
| 2026-08-01 | v0.3 | 第四轮评审（流式一致性）：HTML 流式定案为自研分块 tokenizer（`package:html` 仅小文件回退，因其 DOM-only 无 SAX）；新增 `MediaIndexEvent` 明确媒体索引由解析器产出、`storedPath` 由下游 `MediaStore` 回填；补 Message↔MediaIndexEntry 单一真相来源关系（`mediaPath == sourceRef`，`storedPath` 仅存于索引）；`missing_media` fixture 由 CSV 改为 HTML（CSV 仅占位符无文件引用） | Claude |

---

> 本文档遵循 Lostone 项目的文档驱动开发规范。
> 参考：[ERD 编写指南](../CLAUDE.md#erd)
