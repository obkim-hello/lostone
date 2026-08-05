import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/conversation.dart';
import '../../models/message.dart';
import '../../models/persona.dart';
import '../../services/llm/chat_engine.dart';
import '../../services/llm/chat_types.dart';
import '../../services/llm/flutter_gemma_engine.dart';
import '../../services/llm/lite_rt_runtime.dart';
import '../../services/llm/llm_persona_builder.dart';
import '../../services/model/device_capabilities.dart';
import '../../services/model/flutter_gemma_installer.dart';
import '../../services/model/gemma_bootstrap.dart';
import '../../services/model/model_catalog.dart';
import '../../services/model/model_repository.dart';
import '../../services/model/model_store.dart';
import '../../services/model/secure_token_store.dart';
import '../../models/model_descriptor.dart';
import '../../models/model_install.dart';
import '../../services/persona/prompt_template.dart';

/// 开发期端侧 LLM 冒烟联调屏（**仅 debug**，不入生产流程）。
///
/// 目的：在真机上把「安装模型 → 激活 → 蒸馏 → 对话」串起来做人工「像不像」评审
/// （ADR-005：质量验收必须真机）。默认走 [ModelCatalog.smolLm135m]（免 token 冒烟）；
/// 全程本地 [LiteRtRuntime]，原文不出设备。UI 层不做单测——由宿主契约测试覆盖底层。
class LlmHarnessScreen extends StatefulWidget {
  /// 创建联调屏。
  const LlmHarnessScreen({super.key});

  @override
  State<LlmHarnessScreen> createState() => _LlmHarnessScreenState();
}

class _LlmHarnessScreenState extends State<LlmHarnessScreen> {
  static const ModelDescriptor _model = ModelCatalog.smolLm135m;

  final ModelRepository _repo = DefaultModelRepository(
    catalog: const ModelCatalog(),
    installer: FlutterGemmaInstaller(),
    store: InMemoryModelStore(),
    device: const StaticDeviceCapabilities(tier: DeviceTier.highEnd),
    tokenStore: SecureTokenStore(),
  );

  late final LiteRtRuntime _runtime = LiteRtRuntime(
    engine: const FlutterGemmaEngine(),
    activeHandle: _repo.getActiveModelHandle,
  );

  final DefaultChatEngine _chat = const DefaultChatEngine();
  final TextEditingController _input = TextEditingController();
  final ScrollController _logScroll = ScrollController();

  final List<String> _log = <String>[];
  final List<ChatTurn> _history = <ChatTurn>[];

  bool _gemmaReady = false;
  bool _busy = false;
  String _stage = '未开始';
  Persona? _persona;
  String _reply = '';
  StreamSubscription<InstallEvent>? _installSub;
  StreamSubscription<ChatDelta>? _chatSub;

  @override
  void initState() {
    super.initState();
    _ensureGemma();
  }

  @override
  void dispose() {
    _installSub?.cancel();
    _chatSub?.cancel();
    _input.dispose();
    _logScroll.dispose();
    super.dispose();
  }

  Future<void> _ensureGemma() async {
    try {
      await initGemmaRuntime();
      _addLog('flutter_gemma 引擎已注册');
      setState(() => _gemmaReady = true);
    } on Object catch (e) {
      _addLog('引擎注册失败：$e');
    }
  }

  void _addLog(String line) {
    setState(() => _log.add(line));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScroll.hasClients) {
        _logScroll.jumpTo(_logScroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _install() async {
    setState(() {
      _busy = true;
      _stage = '安装中';
    });
    _addLog('开始安装 ${_model.displayName}（${_mb(_model.sizeBytes)} MB）');
    final Completer<void> done = Completer<void>();
    _installSub = _repo.install(_model.id).listen(
      (InstallEvent e) {
        final int pct = e.totalBytes == 0
            ? 0
            : (e.receivedBytes * 100 / e.totalBytes).round();
        _addLog('  ${e.state.name} $pct%${e.error == null ? '' : ' · ${e.error!.name}'}');
      },
      onDone: () async {
        if (_repo.stateOf(_model.id) == ModelState.ready) {
          await _repo.setActive(_model.id);
          _addLog('已激活 ${_model.id}');
          setState(() => _stage = '模型就绪');
        } else {
          setState(() => _stage = '安装失败');
        }
        if (!done.isCompleted) {
          done.complete();
        }
      },
      onError: (Object err) {
        _addLog('安装错误：$err');
        if (!done.isCompleted) {
          done.complete();
        }
      },
    );
    await done.future;
    setState(() => _busy = false);
  }

  Future<void> _distill() async {
    setState(() {
      _busy = true;
      _stage = '蒸馏中';
      _persona = null;
    });
    _addLog('开始蒸馏示例语料');
    final DefaultLlmPersonaBuilder builder =
        DefaultLlmPersonaBuilder(onLog: _addLog);
    try {
      final Persona persona = await builder.build(
        _sampleConversation(),
        runtime: _runtime,
        options: const LlmBuildOptions(
          personSenderIds: <String>{'grandma'},
          myIdentifiers: <String>{'me'},
          defaultDisplayName: '奶奶',
        ),
      );
      setState(() {
        _persona = persona;
        _stage = '蒸馏完成';
      });
      _addLog('蒸馏完成：${persona.identity.displayName}'
          '${persona.notes.isEmpty ? '' : ' · ${persona.notes.join('；')}'}');
    } on Object catch (e) {
      _addLog('蒸馏异常：$e');
      setState(() => _stage = '蒸馏失败');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final Persona? persona = _persona;
    final String text = _input.text.trim();
    if (persona == null || text.isEmpty) {
      return;
    }
    _input.clear();
    setState(() {
      _busy = true;
      _reply = '';
      _stage = '对话中';
      _history.add(ChatTurn(
        role: ChatRole.user,
        text: text,
        at: DateTime.now().toUtc(),
      ));
    });

    final Completer<void> done = Completer<void>();
    _chatSub = _chat
        .chat(persona, _history, text, runtime: _runtime,
            options: const ChatOptions())
        .listen(
      (ChatDelta d) {
        if (d.isError) {
          _addLog('对话错误：${d.error!.name}');
        } else if (d.textDelta.isNotEmpty) {
          setState(() => _reply += d.textDelta);
        }
        if (d.done && !done.isCompleted) {
          done.complete();
        }
      },
      onError: (Object err) {
        _addLog('对话流异常：$err');
        if (!done.isCompleted) {
          done.complete();
        }
      },
      onDone: () {
        if (!done.isCompleted) {
          done.complete();
        }
      },
    );
    await done.future;
    if (_reply.isNotEmpty) {
      _history.add(ChatTurn(
        role: ChatRole.persona,
        text: _reply,
        at: DateTime.now().toUtc(),
      ));
    }
    setState(() {
      _busy = false;
      _stage = '就绪';
    });
  }

  Conversation _sampleConversation() {
    DateTime at(int h, int m) => DateTime.utc(2024, 3, 12, h, m);
    final List<Message> messages = <Message>[
      _msg('m1', 'grandma', '奶奶', false, at(20, 1), '吃饭了没呀？别老是不按点吃。'),
      _msg('m2', 'me', '我', true, at(20, 2), '刚吃完，奶奶你呢'),
      _msg('m3', 'grandma', '奶奶', false, at(20, 3), '我吃过啦，你要照顾好自己，天冷加衣裳。'),
      _msg('m4', 'me', '我', true, at(20, 4), '知道啦，最近有点累'),
      _msg('m5', 'grandma', '奶奶', false, at(20, 5), '傻孩子，累就歇歇，钱够不够花，不够跟奶奶说。'),
      _msg('m6', 'grandma', '奶奶', false, at(20, 6), '早点睡，别熬夜，身体最要紧。'),
      _msg('m7', 'me', '我', true, at(20, 7), '好，奶奶你也早点休息'),
      _msg('m8', 'grandma', '奶奶', false, at(20, 8), '哎，乖，奶奶等你回来吃我做的红烧肉。'),
    ];
    return Conversation(
      source: DataSource.wechat,
      participants: const <String>['奶奶', '我'],
      messages: messages,
      stats: ImportStats(
        totalParsed: messages.length,
        afterDedup: messages.length,
        skipped: 0,
        earliest: messages.first.timestamp,
        latest: messages.last.timestamp,
      ),
    );
  }

  Message _msg(
    String id,
    String senderId,
    String senderName,
    bool isFromMe,
    DateTime at,
    String content,
  ) =>
      Message(
        id: id,
        source: DataSource.wechat,
        senderId: senderId,
        senderName: senderName,
        isFromMe: isFromMe,
        timestamp: at,
        type: MessageType.text,
        content: content,
      );

  String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(0);

  @override
  Widget build(BuildContext context) {
    final Persona? persona = _persona;
    return Scaffold(
      appBar: AppBar(title: const Text('LLM 联调（dev）')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('阶段：$_stage', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton(
                  onPressed:
                      _gemmaReady && !_busy ? _install : null,
                  child: Text('安装 ${_model.displayName}'),
                ),
                FilledButton.tonal(
                  onPressed:
                      !_busy && (_stage == '模型就绪' || _persona != null)
                          ? _distill
                          : null,
                  child: const Text('蒸馏示例 Persona'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (persona != null) ...<Widget>[
              Text('System Prompt（喂给模型）',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Expanded(
                flex: 2,
                child: _mono(const DefaultPromptTemplate().render(persona)),
              ),
              const SizedBox(height: 8),
              _ChatBox(reply: _reply, history: _history),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _input,
                      enabled: !_busy,
                      decoration: const InputDecoration(
                        hintText: '对奶奶说点什么…',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _busy ? null : _send,
                    child: const Text('发送'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Text('日志', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Expanded(
              flex: 3,
              child: _mono(_log.join('\n'), controller: _logScroll),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mono(String text, {ScrollController? controller}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: SingleChildScrollView(
          controller: controller,
          child: SelectableText(
            text,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      );
}

class _ChatBox extends StatelessWidget {
  const _ChatBox({required this.reply, required this.history});

  final String reply;
  final List<ChatTurn> history;

  @override
  Widget build(BuildContext context) {
    final String last = history.isNotEmpty && history.last.role == ChatRole.user
        ? '我：${history.last.text}'
        : '';
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (last.isNotEmpty) Text(last),
          if (reply.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            SelectableText('奶奶：$reply'),
          ],
        ],
      ),
    );
  }
}
