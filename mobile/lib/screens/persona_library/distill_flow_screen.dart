import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/conversation.dart';
import '../../models/distill_state.dart';
import '../../models/message.dart';
import '../../models/persona.dart';
import '../../providers/debug_providers.dart';
import '../../providers/import_providers.dart';
import '../../providers/persona_library_providers.dart';
import '../../services/persona_library/file_picker_facade.dart';
import '../../theme/app_theme.dart';
import '../settings/settings_screen.dart';

/// Create/distill flow (SPEC-009 §2.7 + §2.6): pick a source, import via the
/// reused Module 002 pipeline, distill via Module 004, then review and save.
///
/// The screen owns no import/distill state of its own — it drives
/// `importStateProvider` and `distillProvider` and renders their phases.
class DistillFlowScreen extends ConsumerStatefulWidget {
  /// Creates the flow.
  const DistillFlowScreen({super.key});

  @override
  ConsumerState<DistillFlowScreen> createState() => _DistillFlowScreenState();
}

class _DistillFlowScreenState extends ConsumerState<DistillFlowScreen> {
  DataSource _source = DataSource.wechat;
  bool _noFileSelected = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final DistillState distill = ref.read(distillProvider);
      final bool hasActiveWork = distill.phase == DistillPhase.running ||
          (distill.phase == DistillPhase.done && !distill.saved);
      if (hasActiveWork) {
        return;
      }
      ref.read(importStateProvider.notifier).reset();
      ref.read(distillProvider.notifier).reset();
    });
  }

  Future<void> _pickAndImport() async {
    setState(() => _noFileSelected = false);
    final List<String> paths = await _pick();
    if (paths.isEmpty) {
      if (mounted) {
        setState(() => _noFileSelected = true);
      }
      return;
    }
    await ref
        .read(importStateProvider.notifier)
        .importFiles(paths, source: _source);
  }

  Future<List<String>> _pick() async {
    final FilePickerFacade picker = ref.read(filePickerFacadeProvider);
    if (_isDirectorySource(_source)) {
      final String? dir = await picker.pickDirectory();
      return dir == null ? <String>[] : <String>[dir];
    }
    return picker.pickFiles(allowedExtensions: _extensionsFor(_source));
  }

  void _startDistill(Conversation conversation) {
    ref.read(distillProvider.notifier).run(
          conversation,
          runtime: ref.read(personaRuntimeProvider),
          options: ref.read(distillOptionsProvider),
        );
  }

  Future<void> _save() async {
    await ref.read(distillProvider.notifier).save();
  }

  Future<void> _confirmStop() async {
    final bool stop = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Stop distilling?'),
            content: const Text(
              'This stops building the persona and discards the progress so '
              'far. You can start again anytime.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Keep going'),
              ),
              TextButton(
                key: const Key('distill-stop-confirm'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Stop'),
              ),
            ],
          ),
        ) ??
        false;
    if (stop) {
      ref.read(distillProvider.notifier).cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ImportState>(importStateProvider, (
      ImportState? previous,
      ImportState next,
    ) {
      if (next.phase == ImportPhase.done &&
          previous?.phase != ImportPhase.done &&
          next.conversation != null) {
        _startDistill(next.conversation!);
      }
    });
    ref.listen<DistillState>(distillProvider, (
      DistillState? previous,
      DistillState next,
    ) {
      if (next.saved && !(previous?.saved ?? false)) {
        ref.read(personaLibraryProvider.notifier).refresh();
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    });

    final ImportState import = ref.watch(importStateProvider);
    final DistillState distill = ref.watch(distillProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Persona'),
        centerTitle: false,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.gutter),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _body(import, distill),
          ),
        ),
      ),
    );
  }

  Widget _body(ImportState import, DistillState distill) {
    if (distill.phase == DistillPhase.running) {
      return _DistillRunning(
        log: distill.progressLog,
        isDebugMode: ref.watch(debugModeProvider),
        isPaused: distill.paused,
        onPause: () => ref.read(distillProvider.notifier).pause(),
        onResume: () => ref.read(distillProvider.notifier).resume(),
        onStop: _confirmStop,
      );
    }
    if (distill.phase == DistillPhase.done) {
      return _DistillReview(state: distill, onSave: _save);
    }
    if (distill.phase == DistillPhase.failed) {
      return _DistillFailed(
        error: distill.error ?? DistillError.buildFailed,
        onRetry: () => ref.read(distillProvider.notifier).reset(),
        onOpenSettings: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
        ),
      );
    }
    if (import.phase == ImportPhase.parsing ||
        import.phase == ImportPhase.preprocessing) {
      return const _ImportRunning();
    }
    if (import.phase == ImportPhase.failed) {
      return _ImportFailed(
        error: import.error ?? 'Import failed.',
        onRetry: _pickAndImport,
      );
    }
    return _SourcePicker(
      source: _source,
      noFileSelected: _noFileSelected,
      onSourceChanged: (DataSource source) =>
          setState(() => _source = source),
      onPick: _pickAndImport,
    );
  }

  static bool _isDirectorySource(DataSource source) =>
      source == DataSource.imessage || source == DataSource.photo;

  static List<String>? _extensionsFor(DataSource source) => switch (source) {
        DataSource.wechat => <String>['csv', 'html', 'txt'],
        DataSource.weibo || DataSource.instagram => <String>['json'],
        _ => null,
      };
}

class _SourcePicker extends StatelessWidget {
  const _SourcePicker({
    required this.source,
    required this.noFileSelected,
    required this.onSourceChanged,
    required this.onPick,
  });

  final DataSource source;
  final bool noFileSelected;
  final ValueChanged<DataSource> onSourceChanged;
  final VoidCallback onPick;

  static const List<DataSource> _sources = <DataSource>[
    DataSource.wechat,
    DataSource.weibo,
    DataSource.instagram,
    DataSource.imessage,
    DataSource.photo,
  ];

  @override
  Widget build(BuildContext context) {
    final bool isDir =
        source == DataSource.imessage || source == DataSource.photo;
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Select Data Source',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose where to import logs to build your persona.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            itemCount: _sources.length,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(height: 8),
            itemBuilder: (BuildContext context, int index) {
              final DataSource s = _sources[index];
              final bool isSelected = source == s;
              return Card(
                key: Key('source-${s.name}'),
                elevation: isSelected ? 1 : 0,
                color: isSelected
                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
                    : theme.colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : AppTheme.separator,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onSourceChanged(s),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: <Widget>[
                        CircleAvatar(
                          backgroundColor: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surfaceContainerHighest,
                          child: Icon(
                            _iconFor(s),
                            size: 20,
                            color: isSelected
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                _label(s),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _subtitleFor(s),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (noFileSelected) ...<Widget>[
          Container(
            key: const Key('no-file-selected'),
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppTheme.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.info_outline, size: 18, color: AppTheme.danger),
                const SizedBox(width: 8),
                Text(
                  'No file or directory was selected.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.danger,
                  ),
                ),
              ],
            ),
          ),
        ],
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            key: const Key('pick-source'),
            onPressed: onPick,
            icon: Icon(isDir ? Icons.folder_open : Icons.upload_file),
            label: Text(
              isDir ? 'Choose Folder' : 'Choose File',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  static String _label(DataSource source) => switch (source) {
        DataSource.wechat => 'WeChat',
        DataSource.imessage => 'iMessage',
        DataSource.weibo => 'Weibo',
        DataSource.instagram => 'Instagram',
        DataSource.photo => 'Photos',
        DataSource.unknown => 'Auto',
      };

  static String _subtitleFor(DataSource source) => switch (source) {
        DataSource.wechat => 'Import chat exports (.csv, .html, .txt)',
        DataSource.imessage => 'Import from local iMessage archive',
        DataSource.weibo => 'Import post & comment history (.json)',
        DataSource.instagram => 'Import downloaded profile data (.json)',
        DataSource.photo => 'Scan directory containing photo metadata',
        DataSource.unknown => 'Automatically detect format',
      };

  static IconData _iconFor(DataSource source) => switch (source) {
        DataSource.wechat => Icons.chat_bubble_outline,
        DataSource.imessage => Icons.message_outlined,
        DataSource.weibo => Icons.language,
        DataSource.instagram => Icons.camera_alt_outlined,
        DataSource.photo => Icons.photo_library_outlined,
        DataSource.unknown => Icons.extension_outlined,
      };
}

class _ImportRunning extends StatelessWidget {
  const _ImportRunning();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 24),
          Text(
            'Importing…',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Parsing and preparing data for distillation.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportFailed extends StatelessWidget {
  const _ImportFailed({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(Icons.error_outline, size: 56, color: AppTheme.danger),
          const SizedBox(height: 16),
          Text(
            'Import Failed',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              error,
              key: const Key('import-error'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const Key('import-retry'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

/// Chunk progress parsed from the builder's progress log.
///
/// [total] is 0 until the builder announces how many chunks the corpus split
/// into; [current] is 0 until the first chunk starts.
@immutable
class DistillChunkProgress {
  /// Creates a progress snapshot.
  const DistillChunkProgress({required this.current, required this.total});

  /// The 1-based chunk currently being distilled (0 before the first).
  final int current;

  /// Total number of chunks (0 while unknown).
  final int total;
}

final RegExp _chunkLine = RegExp(r'蒸馏第 (\d+)/(\d+) 块');
final RegExp _chunkCount = RegExp(r'蒸馏分块数：(\d+)');

/// Derives [DistillChunkProgress] from Module 004's `onLog` [log] lines.
///
/// Reads the "蒸馏分块数：N" total and the latest "蒸馏第 X/N 块…" position so the
/// UI can show "Chunk X of N" without Module 004 exposing a structured API.
DistillChunkProgress distillChunkProgress(List<String> log) {
  int current = 0;
  int total = 0;
  for (final String line in log) {
    final Match? chunk = _chunkLine.firstMatch(line);
    if (chunk != null) {
      current = int.parse(chunk.group(1)!);
      total = int.parse(chunk.group(2)!);
      continue;
    }
    final Match? count = _chunkCount.firstMatch(line);
    if (count != null) {
      total = int.parse(count.group(1)!);
    }
  }
  return DistillChunkProgress(current: current, total: total);
}

class _DistillRunning extends StatefulWidget {
  const _DistillRunning({
    required this.log,
    this.isDebugMode = false,
    this.isPaused = false,
    this.onPause,
    this.onResume,
    this.onStop,
  });

  final List<String> log;
  final bool isDebugMode;
  final bool isPaused;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onStop;

  @override
  State<_DistillRunning> createState() => _DistillRunningState();
}

class _DistillRunningState extends State<_DistillRunning> {
  bool _showLogs = false;

  @override
  void initState() {
    super.initState();
    _showLogs = widget.isDebugMode;
  }

  @override
  Widget build(BuildContext context) {
    final DistillChunkProgress progress = distillChunkProgress(widget.log);
    final ThemeData theme = Theme.of(context);

    final double? percentValue = (progress.total > 0 && progress.current > 0)
        ? (progress.current / progress.total).clamp(0.0, 1.0)
        : null;
    final int percentText =
        percentValue != null ? (percentValue * 100).toInt() : 0;
    final String stageText = widget.isPaused
        ? 'Paused'
        : _getStageDescription(widget.log, progress);

    return Column(
      children: <Widget>[
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: CircularProgressIndicator(
                          value: percentValue,
                          strokeWidth: 8,
                          strokeCap: StrokeCap.round,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            percentValue != null ? '$percentText%' : '…',
                            style: theme.textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          if (progress.total > 0)
                            Text(
                              '${progress.current} / ${progress.total}',
                              key: const Key('distill-chunk-progress'),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),
                  Text(
                    stageText,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Extracting personality traits & conversation patterns',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (widget.onPause != null ||
                      widget.onResume != null ||
                      widget.onStop != null) ...<Widget>[
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        if (widget.isPaused && widget.onResume != null)
                          FilledButton.icon(
                            key: const Key('distill-resume'),
                            onPressed: widget.onResume,
                            icon: const Icon(Icons.play_arrow, size: 20),
                            label: const Text('Resume'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          )
                        else if (!widget.isPaused && widget.onPause != null)
                          OutlinedButton.icon(
                            key: const Key('distill-pause'),
                            onPressed: widget.onPause,
                            icon: const Icon(Icons.pause, size: 20),
                            label: const Text('Pause'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        if (widget.onStop != null) ...<Widget>[
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            key: const Key('distill-stop'),
                            onPressed: widget.onStop,
                            icon: const Icon(
                              Icons.stop_circle_outlined,
                              size: 20,
                            ),
                            label: const Text('Stop'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme.colorScheme.error,
                              side: BorderSide(color: theme.colorScheme.error),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (widget.isDebugMode) ...<Widget>[
          const Divider(height: 1),
          Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: _showLogs,
              onExpansionChanged: (bool val) => setState(() => _showLogs = val),
              title: Text(
                'Debug Console Logs',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: Icon(
                _showLogs
                    ? Icons.keyboard_arrow_down
                    : Icons.keyboard_arrow_right,
                size: 18,
              ),
              children: <Widget>[
                Container(
                  key: const Key('distill-log'),
                  height: 140,
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    reverse: true,
                    child: Text(
                      widget.log.isEmpty ? 'Starting…' : widget.log.join('\n'),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Colors.greenAccent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  static String _getStageDescription(
    List<String> log,
    DistillChunkProgress progress,
  ) {
    if (log.isEmpty) {
      return 'Initializing runtime…';
    }
    if (progress.current > 0 && progress.total > 0) {
      return 'Distilling chunk ${progress.current} of ${progress.total}…';
    }
    if (progress.total > 0) {
      return 'Preparing ${progress.total} chunk(s)…';
    }
    return 'Processing conversation logs…';
  }
}

class _DistillReview extends StatelessWidget {
  const _DistillReview({required this.state, required this.onSave});

  final DistillState state;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    final Persona? persona = state.persona;
    final String name = persona?.identity.displayName ?? '';
    final List<String> notes = persona?.notes ?? const <String>[];
    final ThemeData theme = Theme.of(context);

    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            children: <Widget>[
              Text(
                'Review',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                key: const Key('distill-review-card'),
                elevation: 0,
                color: theme.colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppTheme.separator),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              name,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (state.usedFallback) ...<Widget>[
                        const SizedBox(height: 12),
                        Container(
                          key: const Key('fallback-badge'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amber),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(Icons.warning_amber_rounded,
                                  size: 14, color: Colors.amber),
                              SizedBox(width: 4),
                              Text(
                                'Built on limited data',
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (notes.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 16),
                        Text(
                          'Notes',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final String note in notes)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const Text('• '),
                                Expanded(
                                  child: Text(
                                    note,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              if (state.usedFallback && state.progressLog.isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                Text(
                  'Details',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  key: const Key('distill-fallback-log'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.fill,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.separator),
                  ),
                  child: Text(
                    state.progressLog.join('\n'),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: AppTheme.muted,
                    ),
                  ),
                ),
              ],
              if (state.saveError != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  'Could not save: ${state.saveError}',
                  key: const Key('save-error'),
                  style: const TextStyle(color: AppTheme.danger, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            key: const Key('distill-save'),
            onPressed: () => onSave(),
            icon: const Icon(Icons.save),
            label: const Text(
              'Save persona',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}

class _DistillFailed extends StatelessWidget {
  const _DistillFailed({
    required this.error,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final DistillError error;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (error == DistillError.noModel) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(Icons.memory_outlined, size: 56, color: AppTheme.muted),
            const SizedBox(height: 16),
            Text(
              'No model is ready',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Set up an on-device model, or authorize a cloud API in '
              'Settings, to distill a persona.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('distill-open-settings'),
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings),
              label: const Text('Open Settings'),
            ),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(Icons.error_outline, size: 56, color: AppTheme.danger),
          const SizedBox(height: 16),
          Text(
            'Distillation failed',
            key: const Key('distill-error'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const Key('distill-retry'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
