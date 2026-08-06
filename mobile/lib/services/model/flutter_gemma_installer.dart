import 'dart:async';

import 'package:flutter_gemma/flutter_gemma.dart' as gemma;

import '../../models/model_descriptor.dart';
import '../../models/model_install.dart';
import '../../utils/app_logger.dart';
import 'model_installer.dart';

/// 生产安装器：封装 `flutter_gemma` v1.5.2 的 builder API（ADR-005）。
///
/// 将插件的 `installModel().fromNetwork().withProgress().withCancelToken()
/// .install()` 适配为本模块的 [InstallEvent] 流。进度回调为 0–100 百分比，
/// 据 [ModelDescriptor.sizeBytes] 折算 `receivedBytes`（近似，非精确字节）。
///
/// 注意：`flutter_gemma` 自管模型落盘与「激活模型」，`install()` 成功后会自动
/// 置为 active。故本安装器只负责「下载 + 进度 + 取消 + 错误归一」，落盘位置由
/// 插件掌握。使用前须在应用启动调用 `FlutterGemma.initialize(...)`（见
/// `gemma_bootstrap.dart`）。
///
/// 完整性校验由 `flutter_gemma` 在下载内部完成，本层不持有文件路径、不自算
/// 哈希，故**不**发 [ModelState.verifying]（下载成功即 [ModelState.ready]），
/// 以免宣称未实际执行的校验。[ModelState.verifying]/[InstallErrorKind.corrupted]
/// 仍是状态机的合法出口，供自管下载的安装器上报、由仓库统一处理。
class FlutterGemmaInstaller implements ModelInstaller {
  /// 创建安装器。
  FlutterGemmaInstaller();

  final Map<String, gemma.CancelToken> _tokens = <String, gemma.CancelToken>{};

  @override
  Stream<InstallEvent> install(ModelDescriptor descriptor, {String? hfToken}) {
    final StreamController<InstallEvent> controller =
        StreamController<InstallEvent>();
    final gemma.CancelToken cancelToken = gemma.CancelToken();
    _tokens[descriptor.id] = cancelToken;
    final String id = descriptor.id;
    final int total = descriptor.sizeBytes;

    void emit(ModelState state, {int received = 0, InstallErrorKind? error}) {
      if (!controller.isClosed) {
        controller.add(InstallEvent(
          modelId: id,
          state: state,
          receivedBytes: received,
          totalBytes: total,
          error: error,
        ));
      }
    }

    controller.onListen = () async {
      try {
        emit(ModelState.downloading);
        await gemma.FlutterGemma.installModel(
          modelType: _modelType(descriptor.family),
          fileType: _fileType(descriptor.format),
        )
            .fromNetwork(descriptor.sourceUrl, token: hfToken)
            .withProgress((int percent) {
          emit(
            ModelState.downloading,
            received: (total * percent / 100).round(),
          );
        })
            .withCancelToken(cancelToken)
            .install();
        emit(ModelState.ready, received: total);
      } on gemma.DownloadCancelledException {
        emit(ModelState.failed, error: InstallErrorKind.canceled);
      } on gemma.DownloadException catch (e) {
        AppLogger.error('FlutterGemmaInstaller', 'download failed for $id: $e');
        emit(ModelState.failed, error: _mapError(e.error));
      } on Object catch (e, s) {
        AppLogger.error('FlutterGemmaInstaller', 'install failed for $id: $e\n$s');
        emit(ModelState.failed, error: InstallErrorKind.unknown);
      } finally {
        _tokens.remove(id);
        if (!controller.isClosed) {
          await controller.close();
        }
      }
    };
    return controller.stream;
  }

  @override
  Future<void> cancel(String modelId) async {
    _tokens[modelId]?.cancel('用户取消');
  }

  @override
  Future<bool> isInstalled(ModelDescriptor descriptor) async {
    try {
      return await gemma.FlutterGemma.isModelInstalled(_pluginId(descriptor));
    } on Object catch (e) {
      AppLogger.error(
        'FlutterGemmaInstaller',
        'isInstalled failed for ${descriptor.id}: $e',
      );
      return false;
    }
  }

  @override
  Future<void> delete(ModelDescriptor descriptor) async {
    try {
      await gemma.FlutterGemma.uninstallModel(_pluginId(descriptor));
    } on Object catch (e) {
      AppLogger.error(
        'FlutterGemmaInstaller',
        'delete failed for ${descriptor.id}: $e',
      );
    }
  }

  @override
  Future<void> activate(ModelDescriptor descriptor) async {
    try {
      await gemma.FlutterGemma.installModel(
        modelType: _modelType(descriptor.family),
        fileType: _fileType(descriptor.format),
      ).fromNetwork(descriptor.sourceUrl).install();
    } on Object catch (e, s) {
      AppLogger.error(
        'FlutterGemmaInstaller',
        'activate failed for ${descriptor.id}: $e\n$s',
      );
      rethrow;
    }
  }

  @override
  Future<void> deactivate() async {
    try {
      await gemma.FlutterGemma.clearActiveInferenceIdentity();
    } on Object catch (e) {
      AppLogger.error('FlutterGemmaInstaller', 'deactivate failed: $e');
    }
  }

  /// The id `flutter_gemma` stores a network model under: for a
  /// `ModelSource.network(url)` the plugin uses `url`'s last path segment as
  /// the model filename (see `InferenceModelFile.fromSource`).
  String _pluginId(ModelDescriptor descriptor) =>
      Uri.parse(descriptor.sourceUrl).pathSegments.last;

  gemma.ModelType _modelType(ModelFamily family) => switch (family) {
        ModelFamily.gemmaIt => gemma.ModelType.gemmaIt,
        ModelFamily.gemma4 => gemma.ModelType.gemma4,
        ModelFamily.general => gemma.ModelType.general,
      };

  gemma.ModelFileType _fileType(ModelFormat format) => switch (format) {
        ModelFormat.litertlm => gemma.ModelFileType.litertlm,
        ModelFormat.task => gemma.ModelFileType.task,
      };

  InstallErrorKind _mapError(gemma.DownloadError error) => switch (error) {
        gemma.UnauthorizedError() ||
        gemma.ForbiddenError() =>
          InstallErrorKind.authRequired,
        gemma.NotFoundError() => InstallErrorKind.unknownModel,
        gemma.CanceledError() => InstallErrorKind.canceled,
        gemma.NetworkError() ||
        gemma.RateLimitedError() ||
        gemma.ServerError() =>
          InstallErrorKind.network,
        gemma.UnknownError() => InstallErrorKind.unknown,
      };
}
