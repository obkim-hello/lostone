import 'package:file_picker/file_picker.dart';

/// Seam over the platform file/directory picker for the import step
/// (SPEC-009 §2.7). Tests inject a fake; production wraps `file_picker`.
///
/// 009 owns no import state of its own — the selected paths are handed to
/// Module 002's `ImportNotifier` unchanged.
abstract class FilePickerFacade {
  /// Picks one or more files (WeChat CSV/HTML, Weibo/Instagram JSON, …).
  ///
  /// Returns the selected paths, or `[]` on cancel. When [allowedExtensions]
  /// is non-null the picker restricts selection to those extensions.
  Future<List<String>> pickFiles({List<String>? allowedExtensions});

  /// Picks a directory with read access (iMessage `chat.db` folder,
  /// Photo-EXIF folder). Returns the path, or `null` on cancel / unsupported.
  Future<String?> pickDirectory();
}

/// Default [FilePickerFacade] wrapping `file_picker` (device only).
class DefaultFilePickerFacade implements FilePickerFacade {
  /// Creates the default facade.
  const DefaultFilePickerFacade();

  @override
  Future<List<String>> pickFiles({List<String>? allowedExtensions}) async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: allowedExtensions == null ? FileType.any : FileType.custom,
      allowedExtensions: allowedExtensions,
    );
    if (result == null) {
      return <String>[];
    }
    return <String>[
      for (final String? path in result.paths)
        if (path != null) path,
    ];
  }

  @override
  Future<String?> pickDirectory() => FilePicker.platform.getDirectoryPath();
}
