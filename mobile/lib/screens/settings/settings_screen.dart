import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_settings.dart';
import '../../providers/settings_providers.dart';
import '../../services/settings/settings_notifier.dart';
import '../../theme/app_theme.dart';
import 'model_management_screen.dart';

/// App settings: runtime mode, cloud authorization + key, HF token,
/// temperature, and an entry to model management (PRD-010).
class SettingsScreen extends ConsumerStatefulWidget {
  /// Creates the settings screen.
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _cloudKeyController = TextEditingController();
  final TextEditingController _hfTokenController = TextEditingController();

  @override
  void dispose() {
    _cloudKeyController.dispose();
    _hfTokenController.dispose();
    super.dispose();
  }

  SettingsNotifier get _notifier => ref.read(appSettingsProvider.notifier);

  Future<void> _guarded(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = ref.watch(appSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        children: <Widget>[
          const _SectionHeader('Runtime'),
          RadioGroup<RuntimeChoice>(
            groupValue: settings.runtime,
            onChanged: (RuntimeChoice? value) {
              if (value != null) {
                _guarded(() => _notifier.setRuntime(value));
              }
            },
            child: Column(
              children: <Widget>[
                for (final RuntimeChoice choice in RuntimeChoice.values)
                  RadioListTile<RuntimeChoice>(
                    key: Key('runtime-${choice.name}'),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.gutter,
                      vertical: 2,
                    ),
                    activeColor: AppTheme.accent,
                    controlAffinity: ListTileControlAffinity.trailing,
                    title: Text(
                      _runtimeLabel(choice),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    subtitle: Text(
                      _runtimeSubtitle(choice),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    value: choice,
                  ),
              ],
            ),
          ),
          const _SectionHeader('Cloud'),
          SwitchListTile(
            key: const Key('cloud-authorized'),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppTheme.gutter,
              vertical: 2,
            ),
            title: Text(
              'Authorize cloud inference',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(
              'Sends prompts to a cloud API when selected.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            value: settings.cloudAuthorized,
            onChanged: (bool value) =>
                _guarded(() => _notifier.setCloudAuthorized(value)),
          ),
          _SecretField(
            fieldKey: const Key('cloud-key-field'),
            label: 'Cloud API key',
            isSet: _notifier.hasCloudKey,
            controller: _cloudKeyController,
            onSave: (String value) async {
              await _notifier.setCloudApiKey(value);
              _cloudKeyController.clear();
              setState(() {});
            },
            onClear: () async {
              await _notifier.clearCloudApiKey();
              setState(() {});
            },
          ),
          const _SectionHeader('Downloads'),
          _SecretField(
            fieldKey: const Key('hf-token-field'),
            label: 'Hugging Face token',
            isSet: _notifier.hasHfToken,
            controller: _hfTokenController,
            onSave: (String value) async {
              await _notifier.setHfToken(value);
              _hfTokenController.clear();
              setState(() {});
            },
          ),
          const _SectionHeader('Advanced'),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.gutter,
              4,
              AppTheme.gutter,
              8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      'Chat temperature',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      settings.chatTemperature.toStringAsFixed(2),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                Slider(
                  key: const Key('temperature-slider'),
                  value: settings.chatTemperature,
                  label: settings.chatTemperature.toStringAsFixed(2),
                  divisions: 20,
                  onChanged: (double value) =>
                      _guarded(() => _notifier.setChatTemperature(value)),
                ),
              ],
            ),
          ),
          const _HairLine(),
          _NavRow(
            rowKey: const Key('open-model-management'),
            icon: Icons.memory_outlined,
            title: 'Models',
            subtitle: settings.activeModelId ?? 'No model active',
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const ModelManagementScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _runtimeLabel(RuntimeChoice choice) {
    return switch (choice) {
      RuntimeChoice.local => 'Local (on-device)',
      RuntimeChoice.cloud => 'Cloud API',
      RuntimeChoice.maxPrivacy => 'Maximum privacy',
    };
  }

  String _runtimeSubtitle(RuntimeChoice choice) {
    return switch (choice) {
      RuntimeChoice.local => 'Original text never leaves the device.',
      RuntimeChoice.cloud => 'Higher quality; requires authorization + key.',
      RuntimeChoice.maxPrivacy =>
        'Never invokes an LLM (statistical fallback).',
    };
  }
}

/// Uppercase, muted, letter-spaced section label above a group of rows.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.gutter,
        24,
        AppTheme.gutter,
        10,
      ),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.muted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// A flat, tappable navigation row with a rounded leading glyph and chevron.
class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.rowKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Key rowKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: rowKey,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.gutter,
          vertical: 14,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.fill,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.separator),
              ),
              child: Icon(icon, color: AppTheme.ink, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.muted),
          ],
        ),
      ),
    );
  }
}

/// A hairline separator matching the Instagram-style divider weight.
class _HairLine extends StatelessWidget {
  const _HairLine();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 0.5, color: AppTheme.separator);
  }
}

/// An obscured secret input with inline Save/Clear actions and a "(set)" hint.
class _SecretField extends StatelessWidget {
  const _SecretField({
    required this.fieldKey,
    required this.label,
    required this.isSet,
    required this.controller,
    required this.onSave,
    this.onClear,
  });

  final Key fieldKey;
  final String label;
  final bool isSet;
  final TextEditingController controller;
  final Future<void> Function(String value) onSave;
  final Future<void> Function()? onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.gutter,
        vertical: 4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(label, style: Theme.of(context).textTheme.titleMedium),
              if (isSet) ...<Widget>[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Set',
                    style: TextStyle(
                      color: AppTheme.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  key: fieldKey,
                  controller: controller,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  style: Theme.of(context).textTheme.bodyMedium,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: AppTheme.fill,
                    hintText: isSet
                        ? 'Enter a new value to replace'
                        : 'Enter $label',
                    hintStyle: const TextStyle(color: AppTheme.muted),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.separator),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.accent),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  if (controller.text.isNotEmpty) {
                    onSave(controller.text);
                  }
                },
                child: const Text('Save'),
              ),
              if (onClear != null && isSet) ...<Widget>[
                const SizedBox(width: 4),
                TextButton(onPressed: onClear, child: const Text('Clear')),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
