# SPEC-003-Persona 构建器

> 技术规格 - Persona 构建器（Persona Builder）
>
> **版本**：v1.0
> **状态**：📝 草稿
> **作者**：Claude
> **日期**：2026-08-02
> **优先级**：P0

---

## 📋 文档信息

| 项目 | 内容 |
|------|------|
| **Spec 编号** | SPEC-003 |
| **模块名称** | Persona 构建器（Persona Builder） |
| **关联 PRD** | PRD-Persona-Generation-003-20260802.md |
| **关联 ERD** | ERD-Persona-Engine-003-20260802.md |
| **依赖模块** | SPEC-Data-Parser-002（数据导入）|
| **批准日期** | 待批准 |
| **批准人** | 待批准 |

---

## 1. 接口定义

### 1.1 接口签名

```dart
/// 首次全量生成 Persona。
Future<Persona> build(
  Conversation conversation, {
  Set<String> personSenderIds = const <String>{},
  PersonaBuildOptions options = const PersonaBuildOptions(),
});

/// 增量更新已有 Persona。
Future<Persona> update(
  Persona existing,
  Conversation newConversation, {
  Set<String> personSenderIds = const <String>{},
  PersonaBuildOptions options = const PersonaBuildOptions(),
});

/// 序列化 / 反序列化。
List<int> encode(Persona persona);
Persona decode(List<int> bytes);

/// 渲染 system prompt。
String render(Persona persona, {PromptOptions options = const PromptOptions()});
```

```dart
/// 生成选项。
class PersonaBuildOptions {
  /// 创建生成选项。
  const PersonaBuildOptions({
    this.myIdentifiers = const <String>{},
    this.defaultDisplayName = '未命名',
    this.minMessagesForHigh = 200,
    this.minMessagesForMedium = 50,
    this.topN = 20,
    this.clock,
  });

  /// 代表"用户自己"的 sender 标识集合；其补集视为目标人物。
  final Set<String> myIdentifiers;

  /// 无法从消息推断目标人物名称时的 `Identity.displayName` 回退值。
  final String defaultDisplayName;

  /// 达到该目标人物消息数则层置信度可为 high。
  final int minMessagesForHigh;

  /// 达到该消息数则层置信度可为 medium。
  final int minMessagesForMedium;

  /// 各 Top-N 列表的截断长度。
  final int topN;

  /// 注入式时钟（仅用于 generatedAt 元信息）。为空时调用方须提供。
  final DateTime Function()? clock;
}
```

### 1.2 输入输出规格

**build 输入**：
| 参数 | 类型 | 必填 | 约束 |
|------|------|------|------|
| conversation | `Conversation` | 是 | 消息列表可空但对象非空 |
| personSenderIds | `Set<String>` | 否 | 为空时用 `myIdentifiers` 补集推断 |
| options | `PersonaBuildOptions` | 否 | `topN` ≥ 1；`minMessagesForHigh ≥ minMessagesForMedium ≥ 0` |

**build 输出**：`Persona`，`personaVersion == 1`，五层齐全（无 null 层），`schemaVersion == kPersonaSchemaVersion`。

**update 输入**：`existing`（非空、schema 兼容）+ `newConversation`。
**update 输出**：`Persona`，`personaVersion == existing.personaVersion + 1`，`hardRules == existing.hardRules`（引用/值不变）。

### 1.3 前置条件（Preconditions）
- `build`：`conversation != null`；`options` 阈值合法（`minMessagesForHigh ≥ minMessagesForMedium ≥ 0`，`topN ≥ 1`）。
- `update`：`existing.schemaVersion == kPersonaSchemaVersion`（否则先 `decode` 迁移）。
- 消息若非升序，实现须先归一化排序（保证确定性）。

### 1.4 后置条件（Postconditions）
- 输出 Persona 各层非 null；`memories.timeline.messageCount == source.personMessages`。
- `source.mergedMessageKeys` 含所有已并入消息的**消息键**，且无重复。
- `decode(encode(p))` 与 `p` 值相等。
- `render` 对同一 `(persona, options)` 恒等输出。

### 1.5 不变性（Invariants）
- **确定性**：相同输入（排序归一化后）→ 相同 Persona（`generatedAt` 除外）与相同 prompt。`Persona.id` 由来源签名确定性派生，故同样满足此不变式。
- **幂等**：`update(p, c)` 后再 `update(_, c')`（`c'` 与 `c` 消息**内容键**相同，即便 `Message.id` 不同）不改变统计（version 语义除外）。去重以消息键为准，`Message.id` 不参与。
- **硬规则不变**：任何分析路径都不写 `hardRules`；仅用户显式编辑可改。
- **无副作用**：不写文件、不发网络、不改输入对象。

---

## 2. 数据规格

### 2.1 数据格式（`.persona` JSON）

```json
{
  "schemaVersion": 1,
  "personaVersion": 3,
  "id": "persona-8f3a...",
  "generatedAt": "2026-08-02T10:00:00.000Z",
  "identity": {
    "displayName": "妈妈",
    "relationToUser": "mother",
    "aliases": ["老妈"],
    "confidence": "high"
  },
  "hardRules": {
    "forbiddenTopics": [],
    "mustNeverClaim": ["我还活着"],
    "safetyNotes": []
  },
  "expressionStyle": {
    "catchphrases": [{"term": "早点睡", "count": 42}],
    "emojiUsage": [{"term": "😊", "count": 88}],
    "punctuation": [{"term": "…", "count": 120}],
    "avgMessageLength": 14,
    "confidence": "high"
  },
  "emotionalLogic": {
    "positiveRatio": 0.62,
    "negativeRatio": 0.08,
    "comfortPatterns": [{"term": "没事的", "count": 15}],
    "concernPatterns": [{"term": "吃饭了吗", "count": 37}],
    "confidence": "medium"
  },
  "relationalBehavior": {
    "termsForUser": [{"term": "宝贝", "count": 51}],
    "initiationRatio": 0.55,
    "avgResponseGapMinutes": 12.3,
    "confidence": "medium"
  },
  "tags": [
    {"label": "报喜不报忧", "confidence": "medium", "evidence": {"messageKeys": ["wechat|mom|2023-05-20T09:00:00.000Z|没事的|text"], "occurrences": 8}}
  ],
  "memories": {
    "timeline": {
      "start": "2023-01-01T00:00:00.000Z",
      "end": "2025-12-31T00:00:00.000Z",
      "messageCount": 1240,
      "activeHours": {"20": 210, "21": 305}
    },
    "keyEvents": [
      {"at": "2023-05-20T00:00:00.000Z", "summary": "称呼变化", "evidence": {"messageKeys": ["wechat|mom|2023-05-20T00:00:00.000Z|宝贝你长大了|text"], "occurrences": 1}}
    ],
    "preferences": [
      {"term": "喝汤", "count": 23, "evidence": {"messageKeys": ["wechat|mom|2023-03-01T12:00:00.000Z|记得喝汤|text"], "occurrences": 23}}
    ]
  },
  "source": {
    "sources": ["wechat"],
    "totalMessages": 2600,
    "personMessages": 1240,
    "mergedMessageKeys": ["wechat|mom|2023-01-01T08:00:00.000Z|早上好|text"]
  }
}
```

### 2.2 数据验证规则
| 字段 | 规则 | 失败处理 |
|------|------|---------|
| schemaVersion | 整数，≤ `kPersonaSchemaVersion` | 高于当前 → `PersonaSchemaException` |
| personaVersion | 整数 ≥ 1 | 非法 → `FormatException` |
| confidence | ∈ {low,medium,high} | 未知 → `FormatException` |
| ratio 字段 | double ∈ [0,1] | 见 §4.3 clamp/损坏判定 |
| timeline.start/end | ISO-8601 UTC 或 null（空会话）| 非 null 且不可解析 → `FormatException` |
| 时间字段（其余）| ISO-8601 UTC | 不可解析 → `FormatException` |
| tags[].label | 非空字符串 | 空 → `FormatException` |

### 2.3 数据约束
- Top-N 列表长度 ≤ `options.topN`。
- `mergedMessageKeys` 唯一（消息键去重，见 §1.5）。
- `Evidence.sampleExcerpt` 若存在须截断（≤ 60 字符，脱敏）。
- 空会话时 `timeline.start == null && timeline.end == null && timeline.messageCount == 0`。

---

## 3. 边界情况

### 3.1 边界条件清单
| 场景 | 输入 | 期望行为 |
|------|------|---------|
| 空会话 | `messages == []` | 返回五层齐全、`tags==[]`、全 `low`、`personMessages==0`、`timeline.start/end==null` 的 Persona；`displayName == options.defaultDisplayName`；不抛异常 |
| 无目标人物消息 | 全是 `myIdentifiers` | 同上；`RelationalBehavior` 仅有用户侧对照，风格层为空 |
| 单条消息 | 1 条目标消息 | `low` 置信度；统计不崩溃 |
| 内容重复 | 消息键相同、`Message.id` 不同 | 按消息键去重后按唯一集统计（幂等）；`Message.id` 不影响结果 |
| 超长消息 | 单条极长文本 | 参与统计但不 OOM（分块）|
| 纯 emoji/标点 | 无文字 | emoji/标点层有值，catchphrases 空 |
| 中英混合 | 混合语言 | 分别按字/空白切分统计 |
| 增量：无新增 | 相同会话再传入 | version+1，统计不变（幂等）|
| 增量：硬规则已设 | 用户设过 hardRules | 保持不变 |

### 3.2 异常处理
| 异常情况 | 处理方式 | 错误码/类型 |
|---------|---------|------------|
| JSON 结构非法 | 抛出，不返回半成品 | `FormatException` |
| schema 版本过高 | 抛出 | `PersonaSchemaException` |
| options 阈值非法 | 抛出 | `ArgumentError` |
| clock 缺失且需时间戳 | 抛出 | `ArgumentError` |

---

## 4. 行为规格

### 4.1 正常流程
```
build(conversation):
  1. splitBySender → (personMessages, userMessages)
  2. timestamp 统一归一到 UTC；按 timestamp 升序稳定排序 personMessages
  3. 计算各消息键 → source.mergedMessageKeys（去重）
  4. MemoriesAnalyzer.analyze(personMessages) → memories（空集时 timeline.start/end=null）
  5. PersonaAnalyzer: expression / emotion / relation
  6. deriveTags → tags；identity/风格置信度按阈值判定；
     displayName 取自消息推断，缺失回退 options.defaultDisplayName
  7. id = 确定性哈希(来源签名)；组装 Persona(version=1, hardRules=默认空, tags, source)
  8. 返回
```

### 4.2 异常流程
- 任一分析步骤对**空子集**返回该层的空+low 结果，不中断整体流程。
- `decode` 遇非法数据立即抛出，不产出部分 Persona。

### 4.3 状态转换
```
（无）── build ──► Persona v1
Persona vN ── update(新消息) ──► Persona v(N+1)
Persona ── encode ──► bytes ── decode ──► Persona（值相等）
```
- ratio 越界策略（读入 `decode` 时）：以浮点误差容差 `ε = 1e-6` 判定——落在 `[-ε, 0)` 或 `(1, 1+ε]` 视为浮点误差，clamp 到 `[0,1]`；超出 `[-ε, 1+ε]`（如 `1.2`、`-0.3`）一律视为损坏 → `FormatException`。

---

## 5. 性能规格

### 5.1 时间复杂度
- 全量：O(N·L)（N=消息数，L=平均长度），单遍聚合。
- 增量：O(ΔN·L + K)（ΔN=新增消息，K=Top-N 重排）。

### 5.2 空间复杂度
- O(N·L) 语料 + O(词表大小) 统计表；不保留多份全量拷贝。

### 5.3 性能测试要求
| 测试场景 | 数据规模 | 性能目标 |
|---------|---------|---------|
| 全量生成 | 1000 条 | ≤ 60s（宿主机）|
| 全量生成 | 10000 条 | 线性可外推（基准记录）|
| 增量更新 | +200 条 / 基线 5000 | 显著 < 全量重算 |

---

## 6. 测试规格

### 6.1 测试用例

> 所有 fixtures 均为**合成数据**。严禁使用真实导出数据（隐私约束）。

```dart
group('PersonaBuilder.build', () {
  test('返回五层齐全且无 null 层', () async {
    final Persona p = await builder.build(_synthConversation());
    expect(p.hardRules, isNotNull);
    expect(p.identity, isNotNull);
    expect(p.expressionStyle, isNotNull);
    expect(p.emotionalLogic, isNotNull);
    expect(p.relationalBehavior, isNotNull);
    expect(p.personaVersion, 1);
  });

  test('空会话返回 low 置信度且不抛异常', () async {
    final Persona p = await builder.build(_emptyConversation());
    expect(p.source.personMessages, 0);
    expect(p.identity.confidence, Confidence.low);
  });

  test('口头禅按出现次数统计并截断到 topN', () async {
    final Persona p = await builder.build(_repeatedPhraseConversation());
    expect(p.expressionStyle.catchphrases.length, lessThanOrEqualTo(20));
    expect(p.expressionStyle.catchphrases.first.count, greaterThan(1));
  });
});

group('PersonaBuilder.update', () {
  test('按消息键去重幂等：内容相同但 Message.id 不同不改变统计', () async {
    final Persona v1 = await builder.build(_conv());
    final Persona v2 = await builder.update(v1, _sameContentDifferentIds());
    expect(v2.personaVersion, 2);
    expect(v2.source.personMessages, v1.source.personMessages);
    expect(v2.source.mergedMessageKeys, v1.source.mergedMessageKeys);
    expect(v2.id, v1.id);
  });

  test('硬规则永不被覆盖', () async {
    final Persona v1 = _withHardRules(await builder.build(_conv()));
    final Persona v2 = await builder.update(v1, _moreMessages());
    expect(v2.hardRules.mustNeverClaim, v1.hardRules.mustNeverClaim);
  });
});

group('PersonaCodec', () {
  test('encode/decode 往返值相等（含 tags 与消息键证据）', () {
    final Persona p = _samplePersona();
    expect(codec.decode(codec.encode(p)), p);
  });

  test('空会话 Persona 往返：timeline.start/end 为 null', () {
    final Persona p = _emptyPersona();
    final Persona r = codec.decode(codec.encode(p));
    expect(r.memories.timeline.start, isNull);
    expect(r.memories.timeline.end, isNull);
    expect(r.tags, isEmpty);
  });

  test('非法 JSON 抛 FormatException', () {
    expect(() => codec.decode(utf8.encode('{bad')), throwsFormatException);
  });

  test('schema 版本过高抛 PersonaSchemaException', () {
    final List<int> future = _futureSchemaBytes();
    expect(() => codec.decode(future), throwsA(isA<PersonaSchemaException>()));
  });
});

group('PromptTemplate', () {
  test('同输入同输出（确定性）', () {
    final Persona p = _samplePersona();
    expect(template.render(p), template.render(p));
  });
});
```

### 6.2 测试数据（fixtures）
| 名称 | 用途 |
|------|------|
| `_synthConversation()` | 含目标人物+用户消息、中英 emoji 混合 |
| `_emptyConversation()` | 空消息列表 |
| `_repeatedPhraseConversation()` | 高频口头禅，验证计数/截断 |
| `_sameContentDifferentIds()` | 与 `_conv()` 内容键相同但 `Message.id` 不同，验证键去重幂等 |
| `_samplePersona()` | 往返序列化基准（含 tags 与消息键证据）|
| `_emptyPersona()` | 空会话 Persona（timeline.start/end 为 null）|
| `_futureSchemaBytes()` | `schemaVersion` 大于当前 |

### 6.3 覆盖率要求
- 语句覆盖率：> 80%。
- 分支覆盖：所有 §3.1 边界与 §3.2 异常路径。

---

## 7. 依赖规格

### 7.1 外部依赖
| 依赖 | 版本 | 用途 |
|------|------|------|
| Dart SDK | >=3.11.0 <4.0.0 | 语言与 `dart:convert` |
| Flutter | 3.38+ | 宿主运行时（引擎层无 UI 依赖）|

> 不引入第三方 NLP/网络依赖。情感/停用词表内置于 `text_stats`。

### 7.2 内部依赖
| 模块 | 接口 | 用途 |
|------|------|------|
| 002 数据导入 | `Conversation`/`Message`/`MessageType`/`DataSource` | 输入契约 |
| 008 存储（未来）| 加密落盘 | 持久化 `.persona`（本模块只产字节）|

---

## 8. 验收标准

### 8.1 功能验收
- [ ] `build` 产出五层齐全、version=1 的 Persona。
- [ ] `update` 去重幂等、version 递增、硬规则不变。
- [ ] `encode/decode` 往返无损；坏数据/高 schema 正确抛错。
- [ ] `render` 确定性、仅含 Persona 字段。
- [ ] 所有结论可回溯 `Evidence`。

### 8.2 性能验收
- [ ] 1000 条 ≤ 60s；增量显著快于全量。

### 8.3 质量验收
- [ ] 单测覆盖率 > 80%；`flutter analyze` 0 警告。
- [ ] 仅使用合成 fixtures，无真实数据。

---

## 9. 附录

### 9.1 示例代码
```dart
final PersonaBuilder builder = DefaultPersonaBuilder();
final Persona persona = await builder.build(
  conversation,
  options: PersonaBuildOptions(
    myIdentifiers: <String>{'me'},
    clock: () => DateTime.utc(2026, 8, 2),
  ),
);
final List<int> bytes = PersonaJsonCodec().encode(persona);
final String systemPrompt = DefaultPromptTemplate().render(persona);
```

### 9.2 参考资料
- PRD-Persona-Generation-003-20260802.md
- ERD-Persona-Engine-003-20260802.md
- GLOSSARY（五层结构 / `.persona` / 增量更新）
- SPEC-Data-Parser-002（Conversation/Message 契约）

### 9.3 变更记录
| 日期 | 版本 | 变更内容 | 作者 |
|------|------|---------|------|
| 2026-08-02 | v1.0（草稿）| 初始草稿 | Claude |
| 2026-08-02 | v1.0.1（草稿）| 代理评审修订：去重/幂等/证据全改用消息键（非 `Message.id`），`.persona` JSON 补 `tags`、`mergedMessageKeys`、`messageKeys`；空会话 `timeline.start/end` 可空、`displayName` 回退 `defaultDisplayName`、`tags==[]`；`PersonaBuildOptions` 加 `defaultDisplayName`；ratio 越界改 ε 容差 clamp/损坏判定；阈值前后置条件统一（`topN≥1`、`min*≥0`）；幂等单测改用"内容键相同/id 不同"夹具、新增空会话往返用例 | Claude |

---

> 本文档为**草稿**，开发状态**阻塞**，需三文档评审批准后方可编码。所有测试数据仅限合成，严禁使用真实导出数据。
