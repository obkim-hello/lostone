import 'package:flutter/material.dart' hide KeyEvent;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/evidence.dart';
import '../../models/memories.dart';
import '../../models/persona.dart';
import '../../models/persona_layers.dart';
import '../../models/persona_summary.dart';
import '../../providers/persona_library_providers.dart';
import '../../theme/app_theme.dart';
import 'persona_edit_screen.dart';
import 'persona_library_screen.dart';

/// Read-only detail for a saved persona, with a delete action (SPEC-009 §2.4).
///
/// Loads the full [Persona] body on demand and renders all five layers, tags,
/// memories, and honesty notes. Falls back to the lightweight [PersonaSummary]
/// header while the body loads or if decoding fails.
class PersonaDetailScreen extends ConsumerWidget {
  /// Creates the detail screen for [summary].
  const PersonaDetailScreen({required this.summary, super.key});

  /// The persona projection to display.
  final PersonaSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Persona> persona =
        ref.watch(personaDetailProvider(summary.id));
    return Scaffold(
      appBar: AppBar(
        title: Text(summary.displayName),
        actions: <Widget>[
          if (persona.hasValue)
            IconButton(
              key: const Key('detail-edit'),
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
              onPressed: () => _openEdit(context, persona.requireValue),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.gutter),
        children: <Widget>[
          _Header(summary: summary),
          const SizedBox(height: 20),
          ...persona.when(
            data: (Persona p) => _body(p),
            loading: () => <Widget>[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (Object error, StackTrace _) => <Widget>[
              const Text(
                'Could not load the full persona details.',
                style: TextStyle(color: AppTheme.muted),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.tonal(
            key: const Key('detail-delete'),
            onPressed: () => _confirmDelete(context, ref),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.fill,
              foregroundColor: AppTheme.danger,
            ),
            child: const Text('Delete persona'),
          ),
        ],
      ),
    );
  }

  List<Widget> _body(Persona p) {
    return <Widget>[
      if (p.notes.isNotEmpty) ...<Widget>[
        _NotesCard(notes: p.notes),
        const SizedBox(height: 16),
      ],
      _IdentitySection(persona: p),
      _HardRulesSection(rules: p.hardRules),
      _ExpressionSection(style: p.expressionStyle),
      _EmotionSection(logic: p.emotionalLogic),
      _RelationSection(behavior: p.relationalBehavior),
      _TagsSection(tags: p.tags),
      _MemoriesSection(memories: p.memories),
      const SizedBox(height: 8),
      Text(
        'Version ${p.personaVersion} · ${p.source.personMessages} of '
        '${p.source.totalMessages} messages analyzed',
        style: const TextStyle(color: AppTheme.muted, fontSize: 12),
      ),
    ];
  }

  Future<void> _openEdit(BuildContext context, Persona persona) async {
    final bool? changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => PersonaEditScreen(persona: persona),
      ),
    );
    if ((changed ?? false) && context.mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Delete persona?'),
            content: Text(
              'This permanently removes ${summary.displayName} from this device.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                key: const Key('detail-delete-confirm'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) {
      return;
    }
    await ref.read(personaLibraryProvider.notifier).delete(summary.id);
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.summary});

  final PersonaSummary summary;

  @override
  Widget build(BuildContext context) {
    final String? relation = summary.relationToUser;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Flexible(
              child: Text(
                summary.displayName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (limitedMaterialBadge(summary)) ...<Widget>[
              const SizedBox(width: 10),
              const _DetailLimitedNote(),
            ],
          ],
        ),
        if (relation != null && relation.isNotEmpty) ...<Widget>[
          const SizedBox(height: 4),
          Text(relation, style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: 12),
        Text(
          'Created ${_formatDate(summary.generatedAt)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.notes});

  final List<String> notes;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('detail-notes'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.fill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.separator),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Notes',
            style: TextStyle(
              color: AppTheme.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          for (final String note in notes)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                note,
                style: const TextStyle(color: AppTheme.ink, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
    this.confidence,
  });

  final String title;
  final List<Widget> children;
  final Confidence? confidence;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              if (confidence != null) ...<Widget>[
                const SizedBox(width: 8),
                _ConfidencePill(confidence: confidence!),
              ],
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.muted, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppTheme.ink, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Not enough material.',
      style: TextStyle(
        color: AppTheme.muted,
        fontSize: 13,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) {
      return const _Empty();
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final String label in labels)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.fill,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.separator),
            ),
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.ink, fontSize: 13),
            ),
          ),
      ],
    );
  }
}

class _ConfidencePill extends StatelessWidget {
  const _ConfidencePill({required this.confidence});

  final Confidence confidence;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.fill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.separator),
      ),
      child: Text(
        '${_confidenceLabel(confidence)} confidence',
        style: const TextStyle(
          color: AppTheme.muted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _IdentitySection extends StatelessWidget {
  const _IdentitySection({required this.persona});

  final Persona persona;

  @override
  Widget build(BuildContext context) {
    final Identity id = persona.identity;
    return _Section(
      title: 'IDENTITY',
      confidence: id.confidence,
      children: <Widget>[
        _KeyValue(label: 'Name', value: id.displayName),
        if (id.relationToUser != null && id.relationToUser!.isNotEmpty)
          _KeyValue(label: 'Relation', value: id.relationToUser!),
        const SizedBox(height: 4),
        const Text(
          'Also called',
          style: TextStyle(color: AppTheme.muted, fontSize: 13),
        ),
        const SizedBox(height: 6),
        _Chips(labels: id.aliases),
      ],
    );
  }
}

class _HardRulesSection extends StatelessWidget {
  const _HardRulesSection({required this.rules});

  final HardRules rules;

  @override
  Widget build(BuildContext context) {
    if (rules.forbiddenTopics.isEmpty &&
        rules.mustNeverClaim.isEmpty &&
        rules.safetyNotes.isEmpty) {
      return const SizedBox.shrink();
    }
    return _Section(
      title: 'BOUNDARIES',
      children: <Widget>[
        if (rules.forbiddenTopics.isNotEmpty) ...<Widget>[
          const Text(
            'Avoid topics',
            style: TextStyle(color: AppTheme.muted, fontSize: 13),
          ),
          const SizedBox(height: 6),
          _Chips(labels: rules.forbiddenTopics),
          const SizedBox(height: 10),
        ],
        if (rules.mustNeverClaim.isNotEmpty) ...<Widget>[
          const Text(
            'Never claim',
            style: TextStyle(color: AppTheme.muted, fontSize: 13),
          ),
          const SizedBox(height: 6),
          _Chips(labels: rules.mustNeverClaim),
          const SizedBox(height: 10),
        ],
        if (rules.safetyNotes.isNotEmpty) ...<Widget>[
          const Text(
            'Safety notes',
            style: TextStyle(color: AppTheme.muted, fontSize: 13),
          ),
          const SizedBox(height: 6),
          _Chips(labels: rules.safetyNotes),
        ],
      ],
    );
  }
}

class _ExpressionSection extends StatelessWidget {
  const _ExpressionSection({required this.style});

  final ExpressionStyle style;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'HOW THEY TALK',
      confidence: style.confidence,
      children: <Widget>[
        const Text(
          'Catchphrases',
          style: TextStyle(color: AppTheme.muted, fontSize: 13),
        ),
        const SizedBox(height: 6),
        _Chips(labels: _terms(style.catchphrases)),
        if (style.emojiUsage.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          const Text(
            'Emoji',
            style: TextStyle(color: AppTheme.muted, fontSize: 13),
          ),
          const SizedBox(height: 6),
          _Chips(labels: _terms(style.emojiUsage)),
        ],
        if (style.punctuation.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          const Text(
            'Punctuation',
            style: TextStyle(color: AppTheme.muted, fontSize: 13),
          ),
          const SizedBox(height: 6),
          _Chips(labels: _terms(style.punctuation)),
        ],
        const SizedBox(height: 10),
        _KeyValue(
          label: 'Avg message length',
          value: '${style.avgMessageLength} chars',
        ),
      ],
    );
  }
}

class _EmotionSection extends StatelessWidget {
  const _EmotionSection({required this.logic});

  final EmotionalLogic logic;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'EMOTIONAL TONE',
      confidence: logic.confidence,
      children: <Widget>[
        _KeyValue(label: 'Positive', value: _percent(logic.positiveRatio)),
        _KeyValue(label: 'Negative', value: _percent(logic.negativeRatio)),
        const SizedBox(height: 8),
        const Text(
          'Comforting',
          style: TextStyle(color: AppTheme.muted, fontSize: 13),
        ),
        const SizedBox(height: 6),
        _Chips(labels: _terms(logic.comfortPatterns)),
        const SizedBox(height: 10),
        const Text(
          'Caring / reminders',
          style: TextStyle(color: AppTheme.muted, fontSize: 13),
        ),
        const SizedBox(height: 6),
        _Chips(labels: _terms(logic.concernPatterns)),
      ],
    );
  }
}

class _RelationSection extends StatelessWidget {
  const _RelationSection({required this.behavior});

  final RelationalBehavior behavior;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'RELATIONSHIP',
      confidence: behavior.confidence,
      children: <Widget>[
        const Text(
          'Calls you',
          style: TextStyle(color: AppTheme.muted, fontSize: 13),
        ),
        const SizedBox(height: 6),
        _Chips(labels: _terms(behavior.termsForUser)),
        const SizedBox(height: 10),
        _KeyValue(
          label: 'Starts conversations',
          value: _percent(behavior.initiationRatio),
        ),
        _KeyValue(
          label: 'Avg reply gap',
          value: '${behavior.avgResponseGapMinutes.toStringAsFixed(1)} min',
        ),
      ],
    );
  }
}

class _TagsSection extends StatelessWidget {
  const _TagsSection({required this.tags});

  final List<PersonaTag> tags;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }
    return _Section(
      title: 'PERSONALITY',
      children: <Widget>[
        _Chips(labels: tags.map((PersonaTag t) => t.label).toList()),
      ],
    );
  }
}

class _MemoriesSection extends StatelessWidget {
  const _MemoriesSection({required this.memories});

  final Memories memories;

  @override
  Widget build(BuildContext context) {
    final TimelineSpan timeline = memories.timeline;
    final bool hasSpan = timeline.start != null && timeline.end != null;
    return _Section(
      title: 'MEMORIES',
      children: <Widget>[
        if (hasSpan)
          _KeyValue(
            label: 'Chat span',
            value: '${_formatDate(timeline.start!)} → '
                '${_formatDate(timeline.end!)}',
          ),
        _KeyValue(label: 'Messages', value: '${timeline.messageCount}'),
        if (memories.preferences.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          const Text(
            'Often mentions',
            style: TextStyle(color: AppTheme.muted, fontSize: 13),
          ),
          const SizedBox(height: 6),
          _Chips(
            labels: memories.preferences
                .map((Preference p) => p.term)
                .toList(),
          ),
        ],
        if (memories.keyEvents.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          const Text(
            'Key moments',
            style: TextStyle(color: AppTheme.muted, fontSize: 13),
          ),
          const SizedBox(height: 6),
          for (final KeyEvent event in memories.keyEvents)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${_formatDate(event.at)} · ${event.summary}',
                style: const TextStyle(color: AppTheme.ink, fontSize: 13),
              ),
            ),
        ],
      ],
    );
  }
}

class _DetailLimitedNote extends StatelessWidget {
  const _DetailLimitedNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.fill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.separator),
      ),
      child: const Text(
        'Built on limited data',
        style: TextStyle(
          color: AppTheme.muted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

List<String> _terms(List<TermStat> stats) =>
    stats.map((TermStat t) => '${t.term} · ${t.count}').toList();

String _percent(double ratio) => '${(ratio * 100).round()}%';

String _confidenceLabel(Confidence c) => switch (c) {
      Confidence.low => 'Low',
      Confidence.medium => 'Medium',
      Confidence.high => 'High',
    };

String _formatDate(DateTime date) {
  final DateTime local = date.toLocal();
  final String month = local.month.toString().padLeft(2, '0');
  final String day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}
