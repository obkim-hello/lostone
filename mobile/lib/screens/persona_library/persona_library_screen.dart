import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/distill_state.dart';
import '../../models/evidence.dart';
import '../../models/persona_library_state.dart';
import '../../models/persona_summary.dart';
import '../../providers/persona_library_providers.dart';
import '../../theme/app_theme.dart';
import '../dev/llm_harness_screen.dart';
import '../settings/settings_screen.dart';
import 'distill_flow_screen.dart';
import 'persona_detail_screen.dart';

/// Home body: the saved-persona library (SPEC-009 §2.4/§2.5).
///
/// Lists distilled personas newest-first with an honesty badge for
/// limited-material results, an empty state that invites a first distill, and
/// entries to Settings (Module 010) and the create/distill flow.
class PersonaLibraryScreen extends ConsumerWidget {
  /// Creates the library screen.
  const PersonaLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PersonaLibraryState state = ref.watch(personaLibraryProvider);
    final DistillState distill = ref.watch(distillProvider);
    final bool showDistilling = distill.phase == DistillPhase.running ||
        (distill.phase == DistillPhase.done && !distill.saved);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lostone'),
        actions: <Widget>[
          IconButton(
            key: const Key('create-persona'),
            icon: const Icon(Icons.add),
            tooltip: 'Create a persona',
            onPressed: () => _openCreate(context),
          ),
          IconButton(
            key: const Key('open-settings'),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
          if (kDebugMode)
            IconButton(
              key: const Key('open-harness'),
              icon: const Icon(Icons.science_outlined),
              tooltip: 'LLM harness (dev)',
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const LlmHarnessScreen(),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (showDistilling)
            _DistillStatusBanner(
              state: distill,
              onOpen: () => _openCreate(context),
            ),
          Expanded(
            child: switch (state.phase) {
              LibraryPhase.loading =>
                const Center(child: CircularProgressIndicator()),
              LibraryPhase.failed => _LibraryError(
                  message:
                      state.error ?? 'Could not open the persona library.',
                  onRetry: () =>
                      ref.read(personaLibraryProvider.notifier).refresh(),
                ),
              LibraryPhase.ready => state.summaries.isEmpty
                  ? _EmptyLibrary(onCreate: () => _openCreate(context))
                  : _LibraryList(
                      summaries: state.summaries,
                      skippedCount: state.skippedCount,
                    ),
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openCreate(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const DistillFlowScreen()),
    );
  }
}

class _DistillStatusBanner extends StatelessWidget {
  const _DistillStatusBanner({required this.state, required this.onOpen});

  final DistillState state;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool running = state.phase == DistillPhase.running;
    final DistillChunkProgress progress =
        distillChunkProgress(state.progressLog);
    final String label = running
        ? (state.paused
            ? 'Paused — tap to resume'
            : (progress.total > 0
                ? 'Distilling… chunk ${progress.current} of ${progress.total}'
                : 'Distilling a persona…'))
        : 'Persona ready — review & save';
    return Material(
      color: theme.colorScheme.primaryContainer,
      child: InkWell(
        key: const Key('distill-status-banner'),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.gutter,
            vertical: 12,
          ),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 18,
                height: 18,
                child: running
                    ? const CircularProgressIndicator(strokeWidth: 2)
                    : Icon(
                        Icons.check_circle,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              Text(
                'View',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryList extends ConsumerWidget {
  const _LibraryList({required this.summaries, required this.skippedCount});

  final List<PersonaSummary> summaries;
  final int skippedCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: <Widget>[
        if (skippedCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.gutter,
              8,
              AppTheme.gutter,
              8,
            ),
            child: Text(
              '$skippedCount item(s) could not be read and were skipped.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        for (final PersonaSummary summary in summaries)
          _PersonaRow(
            summary: summary,
            onOpen: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => PersonaDetailScreen(summary: summary),
              ),
            ),
            onDelete: () =>
                ref.read(personaLibraryProvider.notifier).delete(summary.id),
          ),
      ],
    );
  }
}

class _PersonaRow extends StatelessWidget {
  const _PersonaRow({
    required this.summary,
    required this.onOpen,
    required this.onDelete,
  });

  final PersonaSummary summary;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final String? relation = summary.relationToUser;
    return InkWell(
      key: Key('persona-row-${summary.id}'),
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.gutter,
          vertical: 12,
        ),
        child: Row(
          children: <Widget>[
            _Avatar(displayName: summary.displayName),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          summary.displayName,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (limitedMaterialBadge(summary)) ...<Widget>[
                        const SizedBox(width: 8),
                        const _LimitedBadge(),
                      ],
                    ],
                  ),
                  if (relation != null && relation.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      relation,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              key: Key('persona-delete-${summary.id}'),
              icon: const Icon(Icons.delete_outline, color: AppTheme.muted),
              tooltip: 'Delete',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

/// Whether [summary] should carry the limited-material honesty badge: any layer
/// flagged insufficient, or the weakest analyzed layer is `low` confidence.
bool limitedMaterialBadge(PersonaSummary summary) =>
    summary.hasInsufficientMaterial ||
    summary.lowestLayerConfidence == Confidence.low;

class _LimitedBadge extends StatelessWidget {
  const _LimitedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('limited-material-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.fill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.separator),
      ),
      child: const Text(
        'Limited data',
        style: TextStyle(
          color: AppTheme.muted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    final String initial =
        displayName.isEmpty ? '?' : displayName.characters.first;
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.fill,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.separator),
      ),
      child: Text(
        initial,
        style: const TextStyle(
          color: AppTheme.ink,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.gutter),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(
              Icons.auto_awesome_outlined,
              size: 48,
              color: AppTheme.muted,
            ),
            const SizedBox(height: 16),
            Text(
              'No personas yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Distill a chat history into a persona to remember someone.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('empty-create'),
              onPressed: onCreate,
              child: const Text('Create a persona'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryError extends StatelessWidget {
  const _LibraryError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.gutter),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('library-retry'),
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
