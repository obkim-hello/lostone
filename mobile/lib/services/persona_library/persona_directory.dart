import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Filesystem seam over the persona directory (ERD-009 §5.2).
///
/// Resolves, enumerates, and reads/writes/deletes `${id}.persona` files. The
/// device default is [PathProviderPersonaDirectory]; host tests use
/// [MemoryPersonaDirectory].
abstract class PersonaDirectory {
  /// Ids that currently have a `.persona` file.
  Future<List<String>> listIds();

  /// Reads the bytes of `${id}.persona`, or `null` if it is absent.
  Future<List<int>?> readBytes(String id);

  /// Writes (overwrites) `${id}.persona` with [bytes].
  Future<void> writeBytes(String id, List<int> bytes);

  /// Removes `${id}.persona`. No-op if the file is absent.
  Future<void> delete(String id);
}

/// In-memory [PersonaDirectory] for host tests (no disk, no path_provider).
class MemoryPersonaDirectory implements PersonaDirectory {
  /// Creates an empty in-memory directory.
  MemoryPersonaDirectory();

  final Map<String, List<int>> _files = <String, List<int>>{};

  @override
  Future<List<String>> listIds() async => _files.keys.toList();

  @override
  Future<List<int>?> readBytes(String id) async {
    final List<int>? bytes = _files[id];
    return bytes == null ? null : List<int>.of(bytes);
  }

  @override
  Future<void> writeBytes(String id, List<int> bytes) async {
    _files[id] = List<int>.of(bytes);
  }

  @override
  Future<void> delete(String id) async {
    _files.remove(id);
  }
}

/// Device [PersonaDirectory]: one `${id}.persona` file under the app documents
/// directory (`getApplicationDocumentsDirectory()`).
class PathProviderPersonaDirectory implements PersonaDirectory {
  /// Creates the device-backed directory.
  PathProviderPersonaDirectory();

  static const String _extension = '.persona';

  Directory? _resolved;

  Future<Directory> _dir() async {
    final Directory? cached = _resolved;
    if (cached != null) {
      return cached;
    }
    final Directory docs = await getApplicationDocumentsDirectory();
    final Directory dir = Directory(p.join(docs.path, 'personas'));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    _resolved = dir;
    return dir;
  }

  File _fileFor(Directory dir, String id) =>
      File(p.join(dir.path, '$id$_extension'));

  @override
  Future<List<String>> listIds() async {
    final Directory dir = await _dir();
    final List<String> ids = <String>[];
    await for (final FileSystemEntity entity in dir.list()) {
      if (entity is File && entity.path.endsWith(_extension)) {
        ids.add(p.basenameWithoutExtension(entity.path));
      }
    }
    return ids;
  }

  @override
  Future<List<int>?> readBytes(String id) async {
    final File file = _fileFor(await _dir(), id);
    if (!file.existsSync()) {
      return null;
    }
    return file.readAsBytes();
  }

  @override
  Future<void> writeBytes(String id, List<int> bytes) async {
    final File file = _fileFor(await _dir(), id);
    await file.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<void> delete(String id) async {
    final File file = _fileFor(await _dir(), id);
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
