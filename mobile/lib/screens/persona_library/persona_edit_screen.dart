import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/persona.dart';
import '../../models/persona_layers.dart';
import '../../providers/persona_library_providers.dart';
import '../../theme/app_theme.dart';

/// Prefix for the audit note appended whenever a persona is hand-edited.
const String kManualEditNotePrefix = 'Manually edited on ';

/// Manual editor for a saved persona's identity and notes (SPEC-009 §2.4).
///
/// Only user-authored metadata is editable — display name, relation, aliases,
/// and free-form notes. The distilled layers, tags, and memories stay
/// read-only. Saving bumps [Persona.personaVersion], appends a matching
/// [SourceRevision] to keep the revision trail continuous, and records a
/// dated "manually edited" note. Returns `true` to the caller on save.
class PersonaEditScreen extends ConsumerStatefulWidget {
  /// Creates the editor for [persona].
  const PersonaEditScreen({required this.persona, super.key});

  /// The full persona being edited.
  final Persona persona;

  @override
  ConsumerState<PersonaEditScreen> createState() => _PersonaEditScreenState();
}

class _PersonaEditScreenState extends ConsumerState<PersonaEditScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _relationController;
  late final TextEditingController _aliasesController;
  late final TextEditingController _notesController;
  String? _nameError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final Identity identity = widget.persona.identity;
    _nameController = TextEditingController(text: identity.displayName);
    _relationController =
        TextEditingController(text: identity.relationToUser ?? '');
    _aliasesController =
        TextEditingController(text: identity.aliases.join('\n'));
    _notesController = TextEditingController(text: _editableNotes().join('\n'));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _relationController.dispose();
    _aliasesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  List<String> _editableNotes() => widget.persona.notes
      .where((String note) => !note.startsWith(kManualEditNotePrefix))
      .toList();

  List<String> _lines(String raw) => raw
      .split('\n')
      .map((String line) => line.trim())
      .where((String line) => line.isNotEmpty)
      .toList();

  Future<void> _save() async {
    final String name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'A display name is required.');
      return;
    }
    setState(() {
      _nameError = null;
      _saving = true;
    });

    final Persona persona = widget.persona;
    final String relation = _relationController.text.trim();
    final Identity identity = Identity(
      displayName: name,
      relationToUser: relation.isEmpty ? null : relation,
      aliases: _lines(_aliasesController.text),
      confidence: persona.identity.confidence,
    );
    final int nextVersion = persona.personaVersion + 1;
    final PersonaSource source = persona.source.copyWith(
      revisions: <SourceRevision>[
        ...persona.source.revisions,
        SourceRevision(
          personaVersion: nextVersion,
          personMessages: persona.source.personMessages,
          totalMessages: persona.source.totalMessages,
        ),
      ],
    );
    final Persona updated = persona.copyWith(
      identity: identity,
      personaVersion: nextVersion,
      source: source,
      notes: <String>[
        ..._lines(_notesController.text),
        '$kManualEditNotePrefix${_today()}',
      ],
    );

    try {
      await ref.read(personaRepositoryProvider).save(updated);
    } on Object catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Could not save your changes.')),
        );
      return;
    }

    ref.invalidate(personaDetailProvider(persona.id));
    await ref.read(personaLibraryProvider.notifier).refresh();
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  static String _today() {
    final DateTime now = DateTime.now();
    final String month = now.month.toString().padLeft(2, '0');
    final String day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit persona'),
        actions: <Widget>[
          TextButton(
            key: const Key('edit-save'),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.gutter),
        children: <Widget>[
          TextField(
            key: const Key('edit-name'),
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Display name',
              errorText: _nameError,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('edit-relation'),
            controller: _relationController,
            decoration: const InputDecoration(
              labelText: 'Relation to you',
              hintText: 'mother, friend, partner…',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('edit-aliases'),
            controller: _aliasesController,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Also called',
              helperText: 'One alias per line.',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('edit-notes'),
            controller: _notesController,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Notes',
              helperText: 'One note per line.',
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Everything else is distilled from the chat history and stays '
            'read-only. Saving records a new version and a dated edit note.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
