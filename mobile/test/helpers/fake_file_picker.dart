import 'package:lostone/services/persona_library/file_picker_facade.dart';

/// Test [FilePickerFacade] returning scripted paths and recording calls.
class FakeFilePicker implements FilePickerFacade {
  /// Creates a fake; [files] is returned by [pickFiles], [directory] by
  /// [pickDirectory].
  FakeFilePicker({this.files = const <String>[], this.directory});

  /// Paths [pickFiles] returns.
  List<String> files;

  /// Path [pickDirectory] returns (`null` = cancel).
  String? directory;

  /// Recorded `allowedExtensions` per [pickFiles] call.
  final List<List<String>?> pickFilesCalls = <List<String>?>[];

  /// Number of [pickDirectory] calls.
  int pickDirectoryCalls = 0;

  @override
  Future<List<String>> pickFiles({List<String>? allowedExtensions}) async {
    pickFilesCalls.add(allowedExtensions);
    return files;
  }

  @override
  Future<String?> pickDirectory() async {
    pickDirectoryCalls++;
    return directory;
  }
}
