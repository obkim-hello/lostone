import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_settings.dart';
import '../../providers/settings_providers.dart';
import '../../services/settings/settings_notifier.dart';
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
                    title: Text(_runtimeLabel(choice)),
                    subtitle: Text(_runtimeSubtitle(choice)),
                    value: choice,
                  ),
              ],
            ),
          ),
          const Divider(),
          const _SectionHeader('Cloud'),
          SwitchListTile(
            key: const Key('cloud-authorized'),
            title: const Text('Authorize cloud inference'),
            subtitle: const Text('Sends prompts to a cloud API when selected.'),
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
          const Divider(),
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
          const Divider(),
          const _SectionHeader('Advanced'),
          ListTile(
            title: const Text('Chat temperature'),
            subtitle: Slider(
              key: const Key('temperature-slider'),
              value: settings.chatTemperature,
              label: settings.chatTemperature.toStringAsFixed(2),
              divisions: 20,
              onChanged: (double value) =>
                  _guarded(() => _notifier.setChatTemperature(value)),
            ),
            trailing: Text(settings.chatTemperature.toStringAsFixed(2)),
          ),
          const Divider(),
          ListTile(
            key: const Key('open-model-management'),
            leading: const Icon(Icons.memory),
            title: const Text('Models'),
            subtitle: Text(settings.activeModelId ?? 'No model active'),
            trailing: const Icon(Icons.chevron_right),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(isSet ? '$label (set)' : label),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  key: fieldKey,
                  controller: controller,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: InputDecoration(
                    hintText: isSet
                        ? 'Enter a new value to replace'
                        : 'Enter $label',
                    border: const OutlineInputBorder(),
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
                const SizedBox(width: 8),
                TextButton(onPressed: onClear, child: const Text('Clear')),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
