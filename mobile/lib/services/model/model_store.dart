/// 模型落盘位置/占用/删除（ERD §4.3）。
///
/// 生产实现落 app 私有 documents 目录；宿主测试用 [InMemoryModelStore]。
/// 加密/排除 iCloud 备份的钩子交模块 008（本接口预留注入点）。
abstract class ModelStore {
  /// 给定模型的落盘绝对路径（纯函数，可在下载前得知）。
  String pathFor(String modelId);

  /// 是否已落盘就绪。
  Future<bool> exists(String modelId);

  /// 记录一个已完成落盘的模型（就绪时由仓库调用）。
  Future<void> put(String modelId, int bytes);

  /// 删除模型文件、回收占用（清理半成品/删除模型）。幂等。
  Future<void> remove(String modelId);

  /// 当前已占用字节。
  Future<int> usedBytes();

  /// 可用磁盘字节（下载前预检用）。
  Future<int> freeBytes();
}

/// 内存态模型存储（宿主测试用；不触碰真实文件系统）。
class InMemoryModelStore implements ModelStore {
  /// 创建内存存储；[freeBytesBudget] 模拟可用磁盘。
  InMemoryModelStore({int freeBytesBudget = 1 << 40, String root = '/models'})
      : _free = freeBytesBudget,
        _root = root;

  final Map<String, int> _present = <String, int>{};
  final String _root;
  int _free;

  @override
  String pathFor(String modelId) => '$_root/$modelId.model';

  @override
  Future<bool> exists(String modelId) async => _present.containsKey(modelId);

  @override
  Future<void> put(String modelId, int bytes) async {
    if (!_present.containsKey(modelId)) {
      _free -= bytes;
    }
    _present[modelId] = bytes;
  }

  @override
  Future<void> remove(String modelId) async {
    final int? bytes = _present.remove(modelId);
    if (bytes != null) {
      _free += bytes;
    }
  }

  @override
  Future<int> usedBytes() async =>
      _present.values.fold<int>(0, (int a, int b) => a + b);

  @override
  Future<int> freeBytes() async => _free;
}
