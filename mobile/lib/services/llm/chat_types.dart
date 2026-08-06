import 'package:flutter/foundation.dart';

import '../../models/persona.dart';
import 'llm_persona_builder.dart';
import 'persona_runtime.dart';

/// 对话中一条消息的角色（ERD-004 §3.5）。
enum ChatRole {
  /// 用户（对方）。
  user,

  /// Persona（被扮演的人）。
  persona,
}

/// 一轮对话消息（ERD-004 §3.5）。
@immutable
class ChatTurn {
  /// 创建一轮消息。
  const ChatTurn({
    required this.role,
    required this.text,
    required this.at,
  });

  /// 角色。
  final ChatRole role;

  /// 消息内容。
  final String text;

  /// UTC 时间戳。
  final DateTime at;

  @override
  bool operator ==(Object other) =>
      other is ChatTurn &&
      other.role == role &&
      other.text == text &&
      other.at == at;

  @override
  int get hashCode => Object.hash(role, text, at);
}

/// 对话选项（ERD-004 §3.5）。对话**无统计兜底**（统计法无法对话）。
@immutable
class ChatOptions {
  /// 创建对话选项。
  const ChatOptions({
    this.mode = PersonaRuntimeMode.local,
    this.temperature = 0.7,
    this.maxNewTokens,
    this.maxContextTurns = 10,
    this.cloudAuthorized = false,
  });

  /// 运行模式（复用 §3.2）。
  final PersonaRuntimeMode mode;

  /// 采样温度（对话高于蒸馏，更自然）。
  final double temperature;

  /// 单次回复 token 上限（空则由模型能力决定）。
  final int? maxNewTokens;

  /// 滑窗保留的最近轮数。
  final int maxContextTurns;

  /// 云端对话授权门控。
  final bool cloudAuthorized;
}

/// 流式增量（ERD-004 §3.5）。
@immutable
class ChatDelta {
  /// 创建增量。
  const ChatDelta({
    this.textDelta = '',
    this.done = false,
    this.error,
  });

  /// 文本增量帧。
  const ChatDelta.append(this.textDelta)
      : done = false,
        error = null;

  /// 结束帧。
  const ChatDelta.finish()
      : textDelta = '',
        done = true,
        error = null;

  /// 错误帧（分类错误，终止流；不兜底）。
  const ChatDelta.failure(RuntimeError this.error)
      : textDelta = '',
        done = false;

  /// 本次增量 token 文本。
  final String textDelta;

  /// 是否结束。
  final bool done;

  /// 分类错误；`null` 表示非错误帧。
  final RuntimeError? error;

  /// 是否为错误帧。
  bool get isError => error != null;

  @override
  bool operator ==(Object other) =>
      other is ChatDelta &&
      other.textDelta == textDelta &&
      other.done == done &&
      other.error == error;

  @override
  int get hashCode => Object.hash(textDelta, done, error);
}

/// 对话会话（内存态；持久化归模块 006/008，本模块不落盘）。
@immutable
class ChatSession {
  /// 创建会话。
  const ChatSession({required this.persona, this.history = const <ChatTurn>[]});

  /// 以某 Persona 开启空会话。
  const ChatSession.start(Persona persona)
      : this(persona: persona, history: const <ChatTurn>[]);

  /// 当前 Persona。
  final Persona persona;

  /// 历史消息（时间升序）。
  final List<ChatTurn> history;

  /// 返回追加一轮后的新会话（不可变）。
  ChatSession append(ChatTurn turn) => ChatSession(
        persona: persona,
        history: <ChatTurn>[...history, turn],
      );
}
