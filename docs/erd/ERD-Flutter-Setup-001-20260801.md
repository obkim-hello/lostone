# ERD-Flutter-Setup-001-20260801

> 工程需求文档 - Flutter 项目配置
>
> **版本**：v1.1
> **状态**：已批准
> **作者**：Claude
> **日期**：2026-08-01
> **批准日期**：2026-08-02（v1.1 版本修订）
> **批准人**：Project Owner
> **关联 PRD**：PRD-Project-Setup-001-20260801.md

---

## 📋 文档信息

| 项目 | 内容 |
|------|------|
| **ERD 编号** | 001 |
| **模块名称** | Flutter 项目配置（Flutter Setup） |
| **关联 PRD** | PRD-Project-Setup-001-20260801.md |
| **关联 Spec** | SPEC-Project-Config-001-20260801.md |
| **技术栈** | Flutter 3.38+, Dart 3.11+ |

---

## 1. 技术目标

### 1.1 核心目标
建立一个**标准化、可维护、高性能**的 Flutter 项目骨架，包含：
- 清晰的目录结构
- 统一的代码规范
- 完善的测试框架
- 完整的文档体系

### 1.2 性能目标
- 项目初始化时间：< 30 秒
- 代码分析时间：< 10 秒（全项目）
- 编译时间：< 60 秒（首次）、< 10 秒（热重载）

### 1.3 质量目标
- 代码覆盖率：> 80%（业务逻辑）
- 代码分析：无任何警告
- 文档完整性：所有公共 API 有文档注释

---

## 2. 设计约束

### 2.1 技术约束
- **语言**：Dart 3.11+
- **框架**：Flutter 3.38+
- **平台**：iOS 17+, macOS 14+
- **最低配置**：
  - CPU：Apple M1 或同等性能
  - 内存：8 GB RAM
  - 存储：10 GB 可用空间

### 2.2 业务约束
- 必须支持离线运行（无网络依赖）
- 必须支持生物识别保护
- 所有依赖必须开源

### 2.3 时间约束
- 开发周期：1 周
- 截止日期：2026-08-07

---

## 3. 架构设计

### 3.1 模块架构图
```
┌─────────────────────────────────┐
│         Presentation            │  UI 层（screens, widgets）
│            Layer                │
├─────────────────────────────────┤
│         Business Logic          │  业务逻辑层（services, providers）
│            Layer                │
├─────────────────────────────────┤
│            Data                 │  数据层（models, repositories）
│            Layer                │
└─────────────────────────────────┘
```

### 3.2 组件设计
| 组件名称 | 职责 | 技术实现 |
|----------|------|---------|
| `main.dart` | 应用入口 | runApp() |
| `app.dart` | App 配置 | MaterialApp |
| `providers/` | 状态管理 | Riverpod StateNotifierProvider |
| `services/` | 业务逻辑 | 异步函数、单例模式 |
| `models/` | 数据模型 | Dart 类、JSON 序列化 |
| `screens/` | UI 页面 | StatelessWidget / StatefulWidget |
| `widgets/` | 可复用组件 | StatelessWidget |
| `utils/` | 工具函数 | 静态方法、扩展函数 |

### 3.3 模块依赖
```
screens/ → providers/ → services/ → models/
    ↓           ↓           ↓
widgets/   widgets/    widgets/
                ↓
              utils/
```

---

## 4. 数据结构定义

### 4.1 核心数据模型

#### 模型 1：AppConfig（应用配置）
```dart
/// 应用配置模型
/// 
/// 存储应用的全局配置信息
class AppConfig {
  /// 应用名称
  final String appName;
  
  /// 应用版本
  final String version;
  
  /// 环境（development/staging/production）
  final String environment;
  
  /// 是否启用调试模式
  final bool isDebug;
  
  const AppConfig({
    required this.appName,
    required this.version,
    required this.environment,
    this.isDebug = false,
  });
  
  /// JSON 序列化
  Map<String, dynamic> toJson() => {
    'appName': appName,
    'version': version,
    'environment': environment,
    'isDebug': isDebug,
  };
  
  /// JSON 反序列化
  factory AppConfig.fromJson(Map<String, dynamic> json) => AppConfig(
    appName: json['appName'] as String,
    version: json['version'] as String,
    environment: json['environment'] as String,
    isDebug: json['isDebug'] as bool? ?? false,
  );
  
  /// 默认配置
  static const AppConfig development = AppConfig(
    appName: 'Lostone',
    version: '0.1.0',
    environment: 'development',
    isDebug: true,
  );
  
  static const AppConfig production = AppConfig(
    appName: 'Lostone',
    version: '0.1.0',
    environment: 'production',
    isDebug: false,
  );
}
```

#### 模型 2：DependencyConfig（依赖配置）
```dart
/// 依赖包配置
class DependencyConfig {
  /// 包名
  final String name;
  
  /// 版本约束
  final String version;
  
  /// 是否为开发依赖
  final bool isDevDependency;
  
  const DependencyConfig({
    required this.name,
    required this.version,
    this.isDevDependency = false,
  });
}
```

---

### 4.2 数据库设计

本项目不使用数据库（项目初始化阶段）。

---

### 4.3 数据存储格式

#### 本地存储
- **格式**：YAML（配置文件）、Dart（代码文件）
- **位置**：项目根目录和 `lib/` 目录
- **加密**：不适用（公开配置）

#### 配置文件格式

**pubspec.yaml**（项目配置）：
```yaml
name: lostone
description: Lostone - AI Persona App
version: 0.1.0+1

environment:
  sdk: '>=3.11.0 <4.0.0'
  flutter: '>=3.38.4'

dependencies:
  flutter:
    sdk: flutter
  
  # State Management
  flutter_riverpod: ^2.4.0
  
  # Local Storage
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  
  # Security
  flutter_secure_storage: ^9.0.0
  
  # UI
  cupertino_icons: ^1.0.6

dev_dependencies:
  flutter_test:
    sdk: flutter
  
  # Linter
  flutter_lints: ^3.0.0
  
  # Testing
  mockito: ^5.4.0
  build_runner: ^2.4.0

flutter:
  uses-material-design: true
  
  assets:
    - assets/prompts/
```

**analysis_options.yaml**（代码规范）：
```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    # Error rules
    - avoid_relative_lib_imports
    - avoid_types_as_parameter_names
    - no_duplicate_case_values
    - no_return_on_null
    
    # Style rules
    - always_declare_return_types
    - always_put_control_body_on_new_line
    - avoid_bool_literals_in_conditional_expressions
    - avoid_catches_without_on_clauses
    - avoid_catching_errors
    - avoid_double_quotes
    - avoid_equals_and_hash_code_on_mutable_classes
    - avoid_escaping_inner_quotes
    - avoid_field_initializers_in_const_classes
    - avoid_final_parameters
    - avoid_function_literals_in_foreach_calls
    - avoid_implements_value_type
    - avoid_init_to_null
    - avoid_multiple_declarations_per_line
    
    # Documentation
    - public_member_api_docs
    
analyzer:
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
  errors:
    invalid_annotation_target: ignore
```

---

## 5. 接口设计

### 5.1 公共接口

#### 接口 1：initializeApp（初始化应用）
```dart
/// 初始化 Flutter 应用
///
/// 参数：
/// - [config]：应用配置（可选）
///
/// 返回：Future<void>
///
/// 抛出：
/// - [FlutterError]：如果初始化失败
///
/// 示例：
/// ```dart
/// await initializeApp();
/// runApp(const MyApp());
/// ```
Future<void> initializeApp({
  AppConfig? config,
}) async {
  // 确保 Flutter 绑定初始化
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化 Hive
  await Hive.initFlutter();
  
  // 初始化 Secure Storage
  await FlutterSecureStorage().readAll();
  
  // 设置配置
  if (config != null) {
    // 存储配置
  }
}
```

---

#### 接口 2：checkEnvironment（检查环境）
```dart
/// 检查开发环境是否符合要求
///
/// 返回：EnvironmentStatus
///
/// 示例：
/// ```dart
/// final status = await checkEnvironment();
/// if (!status.isValid) {
///   print('Environment check failed: ${status.errors}');
/// }
/// ```
Future<EnvironmentStatus> checkEnvironment() async {
  // 检查 Flutter SDK 版本
  // 检查 Dart SDK 版本
  // 检查 Xcode 版本（iOS）
  // 检查依赖包是否安装
}
```

---

### 5.2 类接口

#### 类 1：AppInitializer（应用初始化器）
```dart
/// 应用初始化管理器
///
/// 负责管理应用的初始化流程
///
/// 示例：
/// ```dart
/// final initializer = AppInitializer();
/// await initializer.initialize();
/// ```
class AppInitializer {
  /// 单例实例
  static final AppInitializer _instance = AppInitializer._internal();
  
  factory AppInitializer() => _instance;
  
  AppInitializer._internal();
  
  /// 初始化应用
  Future<void> initialize() async {
    await _initializeHive();
    await _initializeSecureStorage();
    await _loadAppConfig();
  }
  
  Future<void> _initializeHive() async {
    // 实现
  }
  
  Future<void> _initializeSecureStorage() async {
    // 实现
  }
  
  Future<void> _loadAppConfig() async {
    // 实现
  }
}
```

---

### 5.3 API 端点（如有）

不适用（本项目为客户端应用，不提供 API 端点）。

---

## 6. 实现细节

### 6.1 关键算法

#### 算法 1：项目初始化流程
**目的**：确保项目结构符合规范

**输入**：
- 项目名称
- 目标平台（iOS/macOS）

**输出**：
- 标准化的项目结构

**步骤**：
```
1. 执行 flutter create --org com.lostone --platforms ios,macos
2. 创建自定义目录结构（lib/models, lib/services 等）
3. 添加配置文件（analysis_options.yaml）
4. 安装依赖包（flutter pub get）
5. 运行代码检查（flutter analyze）
```

**复杂度**：
- 时间复杂度：O(n)，n 为文件数量
- 空间复杂度：O(n)

**示例代码**：
```bash
flutter create --org com.lostone --platforms ios,macos lostone
cd lostone
flutter pub add flutter_riverpod hive hive_flutter flutter_secure_storage
flutter pub add dev:flutter_lints mockito build_runner
```

---

### 6.2 状态管理
**状态管理方案**：Riverpod

**状态定义**：
```dart
/// 应用配置状态
final appConfigProvider = StateProvider<AppConfig>((ref) {
  return AppConfig.development;
});

/// 初始化状态
final initializationProvider = StateNotifierProvider<InitializationNotifier, InitializationState>((ref) {
  return InitializationNotifier();
});
```

**状态流转**：
```
用户打开应用 → AppInitializer.initialize()
    → 更新 initializationProvider（loading）
    → 初始化完成
    → 更新 initializationProvider（success）
    → UI 重建显示主页面
```

---

### 6.3 错误处理

#### 错误类型
```dart
/// 初始化错误
class InitializationError implements Exception {
  final String message;
  final String? details;
  
  InitializationError(this.message, {this.details});
  
  @override
  String toString() => 'InitializationError: $message${details != null ? ' - $details' : ''}';
}

/// 环境检查错误
class EnvironmentError implements Exception {
  final List<String> errors;
  
  EnvironmentError(this.errors);
  
  @override
  String toString() => 'EnvironmentError:\n${errors.map((e) => '  - $e').join('\n')}';
}
```

#### 处理策略
| 错误类型 | 处理方式 | 用户提示 |
|----------|---------|---------|
| InitializationError | 记录日志、显示错误页面 | "应用初始化失败，请重启" |
| EnvironmentError | 显示环境问题详情 | "环境检查失败：[具体错误]" |

---

### 6.4 日志策略
```dart
// 日志级别
enum LogLevel {
  debug,   // 开发调试
  info,    // 关键信息
  warning, // 警告
  error,   // 错误
}

// 日志格式
// [2026-08-01 21:15:30] [INFO] [AppInitializer] Application initialized successfully
```

---

## 7. 测试策略

### 7.1 单元测试
**测试框架**：`flutter_test`

**测试重点**：
- AppConfig JSON 序列化/反序列化
- AppInitializer 初始化流程
- 环境检查逻辑

**覆盖率目标**：> 80%（业务逻辑）

**测试用例**：
```dart
group('AppConfig', () {
  test('should serialize to JSON correctly', () {
    // Given
    final config = AppConfig.development;
    
    // When
    final json = config.toJson();
    
    // Then
    expect(json['appName'], equals('Lostone'));
    expect(json['environment'], equals('development'));
  });
  
  test('should deserialize from JSON correctly', () {
    // Given
    final json = {
      'appName': 'Lostone',
      'version': '0.1.0',
      'environment': 'production',
      'isDebug': false,
    };
    
    // When
    final config = AppConfig.fromJson(json);
    
    // Then
    expect(config.appName, equals('Lostone'));
    expect(config.environment, equals('production'));
  });
});
```

---

### 7.2 集成测试
**测试场景**：
- 场景 1：全新环境初始化项目
- 场景 2：运行代码分析通过
- 场景 3：编译 iOS 应用成功

**测试代码**：
```dart
testWidgets('app should initialize successfully', (WidgetTester tester) async {
  // Given
  await tester.pumpWidget(const MyApp());
  
  // When
  await tester.pumpAndSettle();
  
  // Then
  expect(find.text('Lostone'), findsOneWidget);
});
```

---

### 7.3 性能测试
**测试指标**：
- 项目初始化时间：< 30 秒
- 编译时间：< 60 秒（首次）
- 内存占用：< 100 MB（空项目）

**测试方法**：
```bash
# 测试初始化时间
time flutter create test_project

# 测试编译时间
time flutter build ios --debug

# 测试代码分析时间
time flutter analyze
```

---

## 8. 性能优化

### 8.1 性能瓶颈分析
| 瓶颈 | 原因 | 优化方案 |
|------|------|---------|
| 首次编译慢 | 需要下载依赖和编译 Flutter 引擎 | 使用 `flutter precache` 预下载 |
| 热重载慢 | Dart VM 重置 | 减少全局变量、优化状态管理 |

### 8.2 优化措施
- **算法优化**：使用高效的数据结构（Hive 代替 SharedPreferences）
- **数据结构优化**：避免深拷贝、使用 const 构造函数
- **缓存策略**：缓存常用配置、使用单例模式
- **异步处理**：初始化使用异步、避免阻塞 UI

---

## 9. 安全考虑

### 9.1 数据安全
- 加密存储：使用 Flutter Secure Storage 存储敏感配置
- 敏感数据处理：不硬编码密钥、使用环境变量

### 9.2 代码安全
- 输入验证：配置文件验证格式和版本
- 异常处理：捕获所有异常、避免应用崩溃
- 日志安全：生产环境不输出调试日志

---

## 10. 部署方案

### 10.1 环境配置
```dart
// 开发环境
const bool kDebugMode = bool.fromEnvironment('dart.vm.product') == false;

// 生产环境
const bool kReleaseMode = bool.fromEnvironment('dart.vm.product');

// 环境 API
class Environment {
  static const bool isDebug = kDebugMode;
  static const bool isRelease = kReleaseMode;
}
```

### 10.2 依赖管理
**关键依赖**：
```yaml
dependencies:
  flutter: sdk: flutter
  flutter_riverpod: ^2.4.0    # 状态管理
  hive: ^2.2.3                 # 本地数据库
  hive_flutter: ^1.1.0
  flutter_secure_storage: ^9.0.0  # 安全存储

dev_dependencies:
  flutter_test: sdk: flutter
  flutter_lints: ^3.0.0        # 代码规范
  mockito: ^5.4.0              # Mock 测试
  build_runner: ^2.4.0         # 代码生成
```

### 10.3 构建配置
```bash
# 开发构建
flutter build ios --debug

# 生产构建
flutter build ios --release

# macOS 构建
flutter build macos --release
```

---

## 11. 技术债务

### 11.1 已知债务
| 债务描述 | 影响 | 计划偿还时间 |
|----------|------|-------------|
| 暂无技术债务 | - | - |

### 11.2 避免策略
- 代码审查：所有代码变更需要审查
- 重构计划：定期重构、避免过度设计
- 文档更新：及时更新文档、保持同步

---

## 12. 监控与维护

### 12.1 监控指标
- 错误率：0%（配置阶段）
- 性能指标：初始化时间 < 30s

### 12.2 日志分析
- 关键日志：初始化成功/失败
- 异常日志：环境检查失败、依赖安装失败

---

## 13. 参考资料

### 13.1 技术文档
- [Flutter 官方文档](https://docs.flutter.dev)
- [Riverpod 文档](https://riverpod.dev)
- [Hive 文档](https://docs.hivedb.dev)

### 13.2 最佳实践
- [Effective Dart](https://dart.dev/guides/language/effective-dart)
- [Flutter 架构指南](https://docs.flutter.dev/architecture)

### 13.3 相关 ADR
- ADR-001：选择 Flutter 作为移动端框架
- ADR-002：采用混合模型策略

---

## 14. 变更记录

| 日期 | 版本 | 变更内容 | 作者 |
|------|------|---------|------|
| 2026-08-01 | v1.0 | 初始版本 | Claude |
| 2026-08-02 | v1.1 | 对齐实际工具链版本：§2.1 及内嵌 pubspec 由 Flutter 3.24/Dart 3.0 更正为 Flutter 3.38.4+/Dart 3.11+ | Claude |

---

> 本文档遵循 Lostone 项目的文档驱动开发规范。
> 参考：[ERD 编写指南](../CLAUDE.md#erd)