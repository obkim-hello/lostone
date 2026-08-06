import '../../models/persona.dart';
import '../../models/persona_layers.dart';
import '../persona/prompt_template.dart';
import 'chat_types.dart';
import 'hard_rule_guard.dart';
import 'llm_persona_builder.dart';
import 'persona_runtime.dart';

/// 与 Persona 对话的引擎（ERD-004 §4.2.5、§5.4；SPEC-004 §2.4）。
///
/// 与蒸馏不同，对话**无统计兜底**——无模型 / `maxPrivacy` / 云端未授权时直接
/// 发 [ChatDelta.failure]，绝不静默失败或降级。
abstract class ChatEngine {
  /// 流式对话：产出增量文本帧，正常以 [ChatDelta.finish] 收尾，异常以
  /// [ChatDelta.failure] 收尾（终止，不再有后续帧）。
  Stream<ChatDelta> chat(
    Persona persona,
    List<ChatTurn> history,
    String userMessage, {
    required PersonaRuntime runtime,
    ChatOptions options,
  });
}

/// 滑窗结果：保留的历史轮次与被裁剪的轮数。
typedef _Window = (List<ChatTurn> kept, int trimmed);

/// 默认对话引擎。system prompt **仅**由 [PromptTemplate.render] 产生（契约不变）。
class DefaultChatEngine implements ChatEngine {
  /// 创建对话引擎。
  const DefaultChatEngine({
    this.template = const DefaultPromptTemplate(),
    this.guard = const HardRuleGuard(),
    void Function(String message)? onLog,
  }) : _log = onLog ?? _noop;

  /// system prompt 渲染器（复用模块 003 契约）。
  final PromptTemplate template;

  /// 硬规则输出守卫。
  final HardRuleGuard guard;

  final void Function(String message) _log;

  static void _noop(String _) {}

  @override
  Stream<ChatDelta> chat(
    Persona persona,
    List<ChatTurn> history,
    String userMessage, {
    required PersonaRuntime runtime,
    ChatOptions options = const ChatOptions(),
  }) async* {
    if (userMessage.trim().isEmpty) {
      yield const ChatDelta.failure(RuntimeError.emptyInput);
      return;
    }

    if (options.mode == PersonaRuntimeMode.maxPrivacy) {
      yield const ChatDelta.failure(RuntimeError.modelUnavailable);
      return;
    }

    if (options.mode == PersonaRuntimeMode.cloud && !options.cloudAuthorized) {
      yield const ChatDelta.failure(RuntimeError.unauthorized);
      return;
    }

    if (!await runtime.isAvailable()) {
      yield const ChatDelta.failure(RuntimeError.modelUnavailable);
      return;
    }

    final String system = template.render(persona);
    final _Window window = _slideWindow(history, options.maxContextTurns);
    if (window.$2 > 0) {
      _log('对话滑窗裁剪最旧 ${window.$2} 轮，保留 ${window.$1.length} 轮');
    }
    final String prompt = _composePrompt(persona, system, window.$1, userMessage);

    final HardRules rules = persona.hardRules;
    final int lookback = guard.lookback(rules);
    var accumulated = '';
    var emitted = 0;
    var violated = false;

    try {
      await for (final String token in runtime.generateStream(
        prompt,
        temperature: options.temperature,
        maxNewTokens: options.maxNewTokens,
      )) {
        accumulated += token;
        if (guard.violates(accumulated, rules)) {
          violated = true;
          break;
        }
        final int safeUpto = accumulated.length - lookback;
        if (safeUpto > emitted) {
          final String chunk = accumulated.substring(emitted, safeUpto);
          emitted = safeUpto;
          yield ChatDelta.append(chunk);
        }
      }
    } on RuntimeException catch (e) {
      yield ChatDelta.failure(e.error);
      return;
    }

    if (violated) {
      yield ChatDelta.append(guard.safeReply);
      yield const ChatDelta.finish();
      return;
    }

    if (accumulated.length > emitted) {
      yield ChatDelta.append(accumulated.substring(emitted));
    }
    yield const ChatDelta.finish();
  }

  _Window _slideWindow(List<ChatTurn> history, int maxTurns) {
    final int cap = maxTurns < 0 ? 0 : maxTurns;
    if (history.length <= cap) {
      return (history, 0);
    }
    final int trimmed = history.length - cap;
    return (history.sublist(trimmed), trimmed);
  }

  String _composePrompt(
    Persona persona,
    String system,
    List<ChatTurn> turns,
    String userMessage,
  ) {
    final String personaLabel = persona.identity.displayName.isEmpty
        ? '我'
        : persona.identity.displayName;
    final StringBuffer b = StringBuffer(system)..write('\n\n');
    for (final ChatTurn turn in turns) {
      final String who = turn.role == ChatRole.user ? '对方' : personaLabel;
      b.write('$who：${turn.text}\n');
    }
    b
      ..write('对方：$userMessage\n')
      ..write('$personaLabel：');
    return b.toString();
  }
}
