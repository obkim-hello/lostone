import '../../models/model_descriptor.dart';
import '../../models/model_install.dart';

/// 模型安装器：封装底层下载/校验，产出 [InstallEvent] 流（ERD §4.2）。
///
/// 生产实现 `FlutterGemmaInstaller` 封装 `flutter_gemma` 的
/// `installModel().fromNetwork().withProgress(...).install()`；测试用
/// `MockInstaller` 注入进度/失败序列，确定性断言状态机。
abstract class ModelInstaller {
  /// 安装给定模型；流式产出 `downloading* → verifying → ready`，或以
  /// `failed(kind)` 事件终止。受限模型经 [hfToken] 鉴权。
  Stream<InstallEvent> install(ModelDescriptor descriptor, {String? hfToken});

  /// 取消进行中的下载（若有）。
  Future<void> cancel(String modelId);

  /// Whether the underlying store reports [descriptor] as fully installed.
  ///
  /// Reflects real on-disk truth (survives restarts), not this session's
  /// in-memory record, so callers can decide install-vs-delete UI correctly.
  Future<bool> isInstalled(ModelDescriptor descriptor);

  /// Removes [descriptor]'s files from the underlying store. Idempotent:
  /// deleting a model that is not installed is a no-op.
  Future<void> delete(ModelDescriptor descriptor);

  /// Marks [descriptor] as the single active model in the underlying store,
  /// replacing any previously active one. Only one model is ever active; the
  /// model must already be installed. Throws if activation fails.
  Future<void> activate(ModelDescriptor descriptor);

  /// Clears the active model so none is active; installed files are kept.
  /// Idempotent: a no-op when nothing is active.
  Future<void> deactivate();
}
