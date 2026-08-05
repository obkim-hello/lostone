import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';

/// 端侧 LLM 栈启动装配（ADR-005）。
///
/// 须在 `runApp` 前调用一次，注册 LiteRT-LM 引擎。`flutter_gemma` 的引擎完全
/// opt-in：不注册则首次 `getActiveModel/createModel` 抛清晰的 StateError。
///
/// 示例：
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await initGemmaRuntime();
///   runApp(const MyApp());
/// }
/// ```
Future<void> initGemmaRuntime() {
  return FlutterGemma.initialize(
    inferenceEngines: const <LiteRtLmEngine>[LiteRtLmEngine()],
  );
}
