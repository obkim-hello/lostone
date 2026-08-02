import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/message.dart';
import '../models/parse_result.dart';

/// 媒体字节落地策略（平台相关）。
enum MediaStorageMode {
  /// iOS：媒体字节拷入沙盒目录（默认）。
  copyIntoSandbox,

  /// macOS：就地引用（security-scoped bookmark），不拷贝字节。
  referenceInPlace,
}

/// 媒体字节层落地器（ERD §4.4）。
///
/// 文本语料层与媒体索引层始终保存；本类只处理**媒体字节层**：按
/// [MediaTier] 与 [MediaStorageMode] 决定是否将字节拷入沙盒，并回填
/// [MediaIndexEntry.storedPath]。文本/索引不受影响，入参列表不被修改。
///
/// - [MediaTier.textOnly]：不拷任何字节，`storedPath` 恒 null。
/// - [MediaTier.photoAndVoice]：仅拷图片与语音。
/// - [MediaTier.all]：拷全部媒体字节。
/// - [MediaStorageMode.referenceInPlace]（macOS）：任何档位都不拷贝，
///   `storedPath` 恒 null，字节经 `sourceRef` 就地引用。
///
/// 源不存在（被移动/删除）时该条 `available` 置 false（对应 `missing_media`），
/// `storedPath` 保持 null，绝不因单条失败中断整批。
///
/// 平台相关的 `isExcludedFromBackup` 经 [excludeFromBackup] 注入：iOS 生产
/// 传入原生实现，宿主/测试默认 no-op，仅在首次实际拷贝前对目录调用一次。
/// 源引用经 [resolveSource] 解析为绝对路径（Instagram 相对 json 目录、
/// 照片为绝对路径等）。
class MediaStore {
  /// 创建媒体落地器。
  MediaStore({
    required this.destinationDir,
    required this.resolveSource,
    this.mode = MediaStorageMode.copyIntoSandbox,
    Future<void> Function(Directory dir)? excludeFromBackup,
  }) : excludeFromBackup = excludeFromBackup ?? _noopExclude;

  /// 沙盒内媒体目录（copyIntoSandbox 模式下字节落地处）。
  final Directory destinationDir;

  /// 将 [MediaIndexEntry.sourceRef] 解析为可读的绝对源路径。
  final String Function(MediaIndexEntry entry) resolveSource;

  /// 落地模式（平台相关）。
  final MediaStorageMode mode;

  /// 目录级 `isExcludedFromBackup` 注入钩子（iOS 原生实现 / 宿主 no-op）。
  final Future<void> Function(Directory dir) excludeFromBackup;

  /// 按档位落地一批媒体索引，回填 `storedPath`，返回新列表（不修改入参）。
  Future<List<MediaIndexEntry>> landAll(
    List<MediaIndexEntry> entries, {
    required MediaTier tier,
  }) async {
    final List<MediaIndexEntry> result = <MediaIndexEntry>[];
    final Set<String> usedNames = <String>{};
    bool prepared = false;
    for (final MediaIndexEntry entry in entries) {
      if (mode == MediaStorageMode.referenceInPlace ||
          !_tierIncludes(tier, entry.type) ||
          !entry.available) {
        result.add(entry);
        continue;
      }
      final File source = File(resolveSource(entry));
      if (!source.existsSync()) {
        result.add(_withAvailability(entry, available: false));
        continue;
      }
      if (!prepared) {
        await destinationDir.create(recursive: true);
        await excludeFromBackup(destinationDir);
        prepared = true;
      }
      final String storedPath =
          p.join(destinationDir.path, _uniqueName(entry.sourceRef, usedNames));
      await source.copy(storedPath);
      result.add(_withStoredPath(entry, storedPath));
    }
    return result;
  }
}

bool _tierIncludes(MediaTier tier, MessageType type) {
  switch (tier) {
    case MediaTier.textOnly:
      return false;
    case MediaTier.photoAndVoice:
      return type == MessageType.image || type == MessageType.voice;
    case MediaTier.all:
      return type == MessageType.image ||
          type == MessageType.voice ||
          type == MessageType.video;
  }
}

String _uniqueName(String sourceRef, Set<String> used) {
  final String base = p.basename(sourceRef);
  if (used.add(base)) {
    return base;
  }
  final String stem = p.basenameWithoutExtension(base);
  final String ext = p.extension(base);
  int n = 1;
  while (true) {
    final String candidate = '$stem-$n$ext';
    if (used.add(candidate)) {
      return candidate;
    }
    n++;
  }
}

MediaIndexEntry _withStoredPath(MediaIndexEntry e, String storedPath) =>
    MediaIndexEntry(
      source: e.source,
      senderId: e.senderId,
      timestamp: e.timestamp,
      type: e.type,
      sourceRef: e.sourceRef,
      storedPath: storedPath,
      available: e.available,
    );

MediaIndexEntry _withAvailability(MediaIndexEntry e, {required bool available}) =>
    MediaIndexEntry(
      source: e.source,
      senderId: e.senderId,
      timestamp: e.timestamp,
      type: e.type,
      sourceRef: e.sourceRef,
      storedPath: e.storedPath,
      available: available,
    );

Future<void> _noopExclude(Directory dir) async {}
