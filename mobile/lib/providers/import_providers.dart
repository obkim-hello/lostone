import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/conversation.dart';
import '../models/message.dart';
import '../models/parse_result.dart';
import '../services/data_import_service.dart';

/// 数据导入的阶段（见 ERD §5.2）。
enum ImportPhase {
  /// 空闲，尚未开始导入。
  idle,

  /// 正在选择文件（由 UI 层驱动）。
  picking,

  /// 正在解析文件。
  parsing,

  /// 正在预处理（去重、清洗、排序）。
  preprocessing,

  /// 导入完成。
  done,

  /// 导入失败。
  failed,
}

/// 数据导入的不可变状态。
class ImportState {
  /// 创建一个导入状态。
  ///
  /// 参数：
  /// - [phase]：当前阶段，默认为 [ImportPhase.idle]。
  /// - [conversation]：导入成功后产出的会话。
  /// - [error]：失败时的错误描述。
  const ImportState({
    this.phase = ImportPhase.idle,
    this.conversation,
    this.error,
  });

  /// 当前阶段。
  final ImportPhase phase;

  /// 导入成功时产出的标准化会话，其余阶段为 null。
  final Conversation? conversation;

  /// 失败时的错误描述，其余阶段为 null。
  final String? error;

  /// 是否处于终态（[ImportPhase.done] 或 [ImportPhase.failed]）。
  bool get isTerminal =>
      phase == ImportPhase.done || phase == ImportPhase.failed;
}

/// 驱动 [ImportState] 的状态管理器（见 ERD §5.2）。
class ImportNotifier extends StateNotifier<ImportState> {
  /// 创建一个导入状态管理器。
  ///
  /// 参数：
  /// - [service]：注入的导入服务，便于测试；默认使用 [DataImportService]。
  ImportNotifier({DataImportService? service})
      : _service = service ?? DataImportService(),
        super(const ImportState());

  final DataImportService _service;

  /// 导入一个或多个文件并更新状态。
  ///
  /// 参数：
  /// - [filePaths]：待导入的文件路径列表。
  /// - [source]：可选的数据源过滤。
  /// - [options]：解析选项。
  ///
  /// 成功时状态转为 [ImportPhase.done] 并携带会话；
  /// 失败时转为 [ImportPhase.failed] 并携带错误描述。
  Future<void> importFiles(
    List<String> filePaths, {
    DataSource? source,
    ParseOptions options = const ParseOptions(),
  }) async {
    state = const ImportState(phase: ImportPhase.parsing);
    try {
      final Conversation conversation = await _service.importFiles(
        filePaths,
        source: source,
        options: options,
      );
      state = ImportState(
        phase: ImportPhase.done,
        conversation: conversation,
      );
    } on Exception catch (e) {
      state = ImportState(phase: ImportPhase.failed, error: e.toString());
    }
  }

  /// 重置为初始空闲状态。
  void reset() {
    state = const ImportState();
  }
}

/// 数据导入状态的全局 Provider（见 ERD §5.2）。
final StateNotifierProvider<ImportNotifier, ImportState> importStateProvider =
    StateNotifierProvider<ImportNotifier, ImportState>((Ref ref) {
  return ImportNotifier();
});
