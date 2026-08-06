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
}
