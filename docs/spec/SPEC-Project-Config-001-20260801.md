# SPEC-Project-Config-001-20260801

> 技术规格文档 - 项目配置
>
> **版本**：v1.0
> **状态**：草稿
> **作者**：Claude
> **日期**：2026-08-01
> **关联 ERD**：ERD-Flutter-Setup-001-20260801.md

---

## 📋 文档信息

| 项目 | 内容 |
|------|------|
| **Spec 编号** | 001 |
| **模块名称** | 项目配置（Project Config） |
| **关联 ERD** | ERD-Flutter-Setup-001-20260801.md |
| **粒度** | 模块接口（Module Interface） |
| **测试状态** | 待测试 |

---

## 1. 规格概述

### 1.1 模块职责
项目配置模块负责：
- 初始化 Flutter 应用
- 检查开发环境是否符合要求
- 加载和管理应用配置
- 提供全局状态访问接口

### 1.2 接口层级
- **层级**：模块接口（Module Interface）
- **范围**：定义项目配置模块对外的公共接口

---

## 2. 接口定义

### 2.1 主要接口

#### 接口 1：initializeApp

**功能**：初始化 Flutter 应用，准备必要的依赖和状态

**签名**：
```dart
/// 初始化 Flutter 应用
///
/// 参数：
/// - [config]：应用配置（可选，默认为开发环境配置）
///
/// 返回：Future<void>
///
/// 抛出：
/// - [InitializationError]：如果初始化失败
/// - [EnvironmentError]：如果环境检查失败
///
/// 示例：
/// ```dart
/// void main() async {
///   await initializeApp();
///   runApp(const MyApp());
/// }
/// ```
Future<void> initializeApp({
  AppConfig? config,
}) async {
  // 实现
}
```

**输入规格**：
| 参数名 | 类型 | 必填 | 默认值 | 验证规则 | 说明 |
|--------|------|------|--------|---------|------|
| config | AppConfig | 否 | AppConfig.development | 非 null | 应用配置 |

**输出规格**：
| 字段名 | 类型 | 说明 |
|--------|------|------|
| 无返回值 | void | 异步操作，无返回值 |

**前置条件**（Preconditions）：
- [ ] Flutter 绑定已初始化（`WidgetsFlutterBinding.ensureInitialized()`）
- [ ] Hive 数据库未初始化（首次调用）
- [ ] Flutter SDK 版本 >= 3.24

**后置条件**（Postconditions）：
- [ ] Hive 数据库已初始化
- [ ] Secure Storage 已就绪
- [ ] 应用配置已加载
- [ ] 全局状态已初始化

**不变性条件**（Invariants）：
- Hive 只能初始化一次（单例）

---

#### 接口 2：checkEnvironment

**功能**：检查开发环境是否符合项目要求

**签名**：
```dart
/// 检查开发环境是否符合要求
///
/// 返回：EnvironmentStatus（包含检查结果）
///
/// 示例：
/// ```dart
/// final status = await checkEnvironment();
/// if (!status.isValid) {
///   print('Environment check failed:');
///   for (final error in status.errors) {
///     print('  - $error');
///   }
/// }
/// ```
Future<EnvironmentStatus> checkEnvironment() async {
  // 实现
}
```

**输入规格**：
| 参数名 | 类型 | 必填 | 默认值 | 验证规则 | 说明 |
|--------|------|------|--------|---------|------|
| 无参数 | - | - | - | - | 无输入参数 |

**输出规格**：
| 字段名 | 类型 | 说明 |
|--------|------|------|
| isValid | bool | 环境是否有效 |
| errors | List<String> | 错误列表（如果无效） |
| warnings | List<String> | 警告列表 |

**前置条件**（Preconditions）：
- [ ] Flutter SDK 已安装
- [ ] 命令行工具可用

**后置条件**（Postconditions）：
- [ ] 返回环境检查结果
- [ ] 结果包含详细的错误信息（如果有）

---

### 2.2 辅助接口

#### 辅助接口 1：getAppConfig
**功能**：获取当前应用配置

**签名**：
```dart
/// 获取当前应用配置
///
/// 返回：AppConfig（当前配置）
AppConfig getAppConfig();
```

---

#### 辅助接口 2：setAppConfig
**功能**：设置应用配置（运行时）

**签名**：
```dart
/// 设置应用配置
///
/// 参数：
/// - [config]：新的配置
///
/// 返回：void
void setAppConfig(AppConfig config);
```

---

## 3. 数据规格

### 3.1 输入数据模型

#### 模型：AppConfig
```dart
class AppConfig {
  final String appName;      // 应用名称，非空，长度 1-50
  final String version;      // 版本号，格式：X.Y.Z
  final String environment;  // 环境：development/staging/production
  final bool isDebug;        // 是否调试模式
  
  // 验证方法
  bool validate() {
    return appName.isNotEmpty &&
           appName.length <= 50 &&
           RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version) &&
           ['development', 'staging', 'production'].contains(environment);
  }
}
```

**验证规则**：
- appName：必填，长度 1-50，不允许特殊字符
- version：必填，格式 X.Y.Z（如 0.1.0）
- environment：必填，枚举值（development/staging/production）
- isDebug：可选，默认 false

---

### 3.2 输出数据模型

#### 模型：EnvironmentStatus
```dart
class EnvironmentStatus {
  final bool isValid;            // 环境是否有效
  final List<String> errors;      // 错误列表
  final List<String> warnings;    // 警告列表
  final Map<String, String> details;  // 详细信息
  
  const EnvironmentStatus({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
    this.details = const {},
  });
}
```

---

### 3.3 数据转换规则

| 输入字段 | 转换规则 | 输出字段 |
|----------|---------|----------|
| appName | 去除首尾空格 | appName |
| version | 不转换 | version |
| environment | 转小写 | environment |

---

## 4. 边界情况

### 4.1 输入边界

| 边界情况 | 输入值 | 预期行为 |
|----------|--------|---------|
| 空 appName | `''` | 抛出 `ArgumentError` |
| 超长 appName | 长度 > 50 | 抛出 `ArgumentError` |
| 无效 version | `'invalid'` | 抛出 `ArgumentError` |
| 无效 environment | `'unknown'` | 抛出 `ArgumentError` |
| Flutter SDK 版本过低 | < 3.24 | 抛出 `EnvironmentError` |

---

### 4.2 状态边界

| 边界情况 | 当前状态 | 预期行为 |
|----------|---------|---------|
| 重复初始化 | 已初始化 | 忽略，返回成功 |
| 未初始化调用 | 未初始化 | 抛出 `StateError` |
| Hive 初始化失败 | 错误状态 | 抛出 `InitializationError` |

---

### 4.3 异常处理

#### 异常类型 1：InitializationError
**触发条件**：应用初始化失败

**异常信息**：
```dart
throw InitializationError(
  'Failed to initialize application',
  details: 'Hive initialization failed: permission denied',
);
```

**处理方式**：
- 日志记录：记录 ERROR 级别日志
- 用户提示：显示错误页面，提供重试按钮
- 恢复策略：用户可点击重试，或查看详细错误信息

---

#### 异常类型 2：EnvironmentError
**触发条件**：环境检查失败

**异常信息**：
```dart
throw EnvironmentError([
  'Flutter SDK version 3.10.0 is too low, required >= 3.24.0',
  'Xcode not found',
]);
```

**处理方式**：
- 日志记录：记录 WARNING 级别日志
- 用户提示：显示环境问题列表，提供修复建议
- 恢复策略：用户修复环境后重试

---

## 5. 行为规格

### 5.1 正常流程
```
1. 调用 initializeApp()
2. 检查前置条件（Flutter 绑定、SDK 版本）
3. 初始化 Hive 数据库
4. 初始化 Secure Storage
5. 加载应用配置
6. 设置全局状态
7. 返回成功
```

---

### 5.2 异常流程

#### 流程 1：环境检查失败
```
1. 调用 initializeApp()
2. 检查 Flutter SDK 版本 -> 失败
3. 抛出 EnvironmentError
4. 记录日志
5. 返回错误
```

---

#### 流程 2：Hive 初始化失败
```
1. 调用 initializeApp()
2. 初始化 Hive -> 失败（权限错误）
3. 抛出 InitializationError
4. 记录日志
5. 返回错误
```

---

### 5.3 并发行为
**线程安全**：否（Dart 单线程模型）

**并发控制**：
- 锁机制：不需要（单线程）
- 原子操作：`initializeApp()` 必须等待完成才能继续

**示例**：
```dart
// 正确：等待初始化完成
await initializeApp();
runApp(const MyApp());

// 错误：不等待初始化
initializeApp(); // 错误！没有 await
runApp(const MyApp()); // 可能初始化未完成
```

---

## 6. 性能规格

### 6.1 时间复杂度
- **最佳情况**：O(1)（已初始化，直接返回）
- **平均情况**：O(n)，n 为依赖项数量
- **最坏情况**：O(n)（首次初始化）

---

### 6.2 空间复杂度
- **内存占用**：O(1)（固定大小的配置对象）
- **峰值内存**：< 50 MB（初始化时）

---

### 6.3 性能指标

| 指标 | 要求 | 测试方法 |
|------|------|---------|
| 初始化时间 | < 3 秒 | 单元测试计时 |
| 环境检查时间 | < 1 秒 | 单元测试计时 |
| 内存占用 | < 50 MB | 内存分析工具 |

---

## 7. 测试规格

### 7.1 单元测试

#### 测试用例 1：正常初始化
```dart
test('should initialize successfully with default config', () async {
  // Given
  // 无需准备（默认配置）
  
  // When
  await initializeApp();
  
  // Then
  expect(Hive.isBoxOpen('lostone'), isTrue);
});
```

---

#### 测试用例 2：自定义配置
```dart
test('should initialize with custom config', () async {
  // Given
  final config = AppConfig.production;
  
  // When
  await initializeApp(config: config);
  
  // Then
  final loadedConfig = getAppConfig();
  expect(loadedConfig.environment, equals('production'));
});
```

---

#### 测试用例 3：无效配置
```dart
test('should throw ArgumentError for invalid config', () {
  // Given
  final invalidConfig = AppConfig(
    appName: '',  // 空名称
    version: 'invalid',  // 无效版本
    environment: 'unknown',  // 无效环境
  );
  
  // When & Then
  expect(
    () => initializeApp(config: invalidConfig),
    throwsArgumentError,
  );
});
```

---

#### 测试用例 4：环境检查
```dart
test('should check environment correctly', () async {
  // Given
  // Flutter SDK 已安装
  
  // When
  final status = await checkEnvironment();
  
  // Then
  expect(status.isValid, isTrue);
  expect(status.errors, isEmpty);
});
```

---

### 7.2 测试覆盖率

| 代码类型 | 覆盖率目标 | 实际覆盖率 |
|----------|-----------|-----------|
| 行覆盖率 | > 90% | % |
| 分支覆盖率 | > 90% | % |
| 函数覆盖率 | 100% | % |

---

### 7.3 测试数据

#### 数据集 1：有效配置
```dart
final validConfigs = [
  AppConfig.development,
  AppConfig.production,
  AppConfig(appName: 'TestApp', version: '1.0.0', environment: 'staging'),
];
```

#### 数据集 2：无效配置
```dart
final invalidConfigs = [
  AppConfig(appName: '', version: '0.1.0', environment: 'development'),  // 空名称
  AppConfig(appName: 'App', version: 'invalid', environment: 'development'),  // 无效版本
  AppConfig(appName: 'App', version: '0.1.0', environment: 'unknown'),  // 无效环境
];
```

---

## 8. 依赖规格

### 8.1 内部依赖
| 模块 | 接口 | 用途 |
|------|------|------|
| 无 | - | - |

---

### 8.2 外部依赖
| 库 | 版本 | 用途 |
|------|------|------|
| flutter | >=3.24.0 | UI 框架 |
| hive_flutter | ^1.1.0 | 本地数据库 |
| flutter_secure_storage | ^9.0.0 | 安全存储 |

---

### 8.3 平台依赖
- **最低版本**：iOS 17, macOS 14
- **必需权限**：
  - iOS：Keychain Sharing（Secure Storage）
  - macOS：Keychain Access

---

## 9. 实现约束

### 9.1 设计约束
- 必须使用单例模式（AppInitializer）
- 不可使用全局变量（使用 Riverpod）
- 必须遵循 Effective Dart 规范

### 9.2 实现约束
- 单个函数不超过 50 行
- 单个类不超过 200 行
- 嵌套层级不超过 3 层

---

## 10. 文档要求

### 10.1 代码注释
**必须注释的内容**：
- 所有公共接口（initializeApp、checkEnvironment）
- 所有参数和返回值
- 所有异常
- 所有复杂逻辑

**注释格式**：
```dart
/// 初始化 Flutter 应用
///
/// 此函数负责初始化应用的所有依赖：
/// - Hive 数据库
/// - Secure Storage
/// - 应用配置
///
/// 参数：
/// - [config]：应用配置（可选，默认为开发环境）
///
/// 返回：Future<void>
///
/// 抛出：
/// - [InitializationError]：如果初始化失败
/// - [EnvironmentError]：如果环境检查失败
///
/// 示例：
/// ```dart
/// void main() async {
///   await initializeApp();
///   runApp(const MyApp());
/// }
/// ```
Future<void> initializeApp({AppConfig? config}) async {
  // 实现
}
```

---

### 10.2 使用示例

#### 示例 1：基本使用
```dart
// main.dart
void main() async {
  // 确保 Flutter 绑定初始化
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化应用
  await initializeApp();
  
  // 运行应用
  runApp(const MyApp());
}
```

---

#### 示例 2：自定义配置
```dart
// 使用生产配置
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await initializeApp(
    config: AppConfig.production,
  );
  
  runApp(const MyApp());
}
```

---

#### 示例 3：环境检查
```dart
// 检查环境后再初始化
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 检查环境
  final status = await checkEnvironment();
  
  if (!status.isValid) {
    // 显示错误页面
    runApp(EnvironmentErrorApp(errors: status.errors));
    return;
  }
  
  // 环境有效，初始化应用
  await initializeApp();
  runApp(const MyApp());
}
```

---

## 11. 验收标准

### 11.1 功能验收
- [ ] initializeApp 接口按规格实现
- [ ] checkEnvironment 接口按规格实现
- [ ] 所有边界情况正确处理
- [ ] 所有异常正确抛出

### 11.2 性能验收
- [ ] 初始化时间 < 3 秒
- [ ] 环境检查时间 < 1 秒
- [ ] 内存占用 < 50 MB

### 11.3 测试验收
- [ ] 单元测试覆盖率 > 90%
- [ ] 所有测试用例通过
- [ ] 无测试警告

### 11.4 文档验收
- [ ] 所有公共接口有文档注释
- [ ] 使用示例完整且可运行
- [ ] 代码符合编码规范

---

## 12. 变更记录

| 日期 | 版本 | 变更内容 | 作者 |
|------|------|---------|------|
| 2026-08-01 | v1.0 | 初始版本 | Claude |

---

> 本文档遵循 Lostone 项目的 Spec-Driven Development 规范。
> 参考：[Spec 编写指南](../CLAUDE.md#spec)