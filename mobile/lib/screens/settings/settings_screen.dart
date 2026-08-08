import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_settings.dart';
import '../../providers/settings_providers.dart';
import '../../services/llm/cloud_runtime.dart';
import '../../services/settings/settings_notifier.dart';
import '../../theme/app_theme.dart';
import 'model_management_screen.dart';

/// App settings: runtime mode, cloud authorization (key + endpoint), and an
/// entry to model management (PRD-010).
class SettingsScreen extends ConsumerStatefulWidget {
  /// Creates the settings screen.
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _cloudKeyController = TextEditingController();
  final TextEditingController _cloudEndpointController =
      TextEditingController();
  final TextEditingController _cloudModelController = TextEditingController();
  bool _endpointSeeded = false;
  bool _modelSeeded = false;
  bool _testingConnection = false;

  @override
  void dispose() {
    _cloudKeyController.dispose();
    _cloudEndpointController.dispose();
    _cloudModelController.dispose();
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

  Future<void> _testCloudConnection() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String? key = await ref.read(cloudKeyStoreProvider).read();
    if (!mounted) {
      return;
    }
    if (key == null || key.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Add a cloud API key first.')),
      );
      return;
    }
    setState(() => _testingConnection = true);
    final AppSettings settings = ref.read(appSettingsProvider);
    final CloudTransport transport = ref.read(cloudTransportProvider);
    String message;
    try {
      await transport.complete(
        CloudRequest(
          prompt: 'ping',
          model: settings.effectiveCloudModel,
          apiKey: key,
          temperature: 0.7,
          maxNewTokens: 16,
        ),
      );
      message = 'Connection OK — ${settings.cloudProvider.label} responded.';
    } on CloudHttpException catch (e) {
      message = _cloudHttpErrorText(e);
    } on Object catch (e) {
      message = 'Connection failed: $e';
    } finally {
      if (mounted) {
        setState(() => _testingConnection = false);
      }
    }
    if (!mounted) {
      return;
    }
    messenger.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 6)),
    );
  }

  static String _cloudHttpErrorText(CloudHttpException e) {
    if (e.isNetworkError) {
      return 'Could not reach the API — check the endpoint. '
          '${e.detail ?? ''}'.trim();
    }
    final int? code = e.statusCode;
    final String detail = e.detail == null ? '' : ' — ${e.detail}';
    return switch (code) {
      401 || 403 =>
        'Rejected (HTTP $code) — check your API key and permissions.$detail',
      404 =>
        'Not found (HTTP 404) — check the endpoint base URL.$detail',
      429 => 'Rate limited (HTTP 429) — try again shortly.$detail',
      null => 'Connection failed$detail',
      _ => 'Failed (HTTP $code)$detail',
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = ref.watch(appSettingsProvider);
    if (!_endpointSeeded && (settings.cloudEndpoint ?? '').isNotEmpty) {
      _cloudEndpointController.text = settings.cloudEndpoint!;
      _endpointSeeded = true;
    }
    if (!_modelSeeded && (settings.cloudModel ?? '').isNotEmpty) {
      _cloudModelController.text = settings.cloudModel!;
      _modelSeeded = true;
    }
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
                for (final RuntimeChoice choice in _visibleRuntimes)
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
          _CloudProviderPicker(
            selected: settings.cloudProvider,
            onChanged: (CloudProvider provider) =>
                _guarded(() => _notifier.setCloudProvider(provider)),
          ),
          _SecretField(
            fieldKey: const Key('cloud-key-field'),
            label: 'Cloud API key',
            isSet: _notifier.hasCloudKey,
            controller: _cloudKeyController,
            onSave: (String value) => _guarded(() async {
              await _notifier.setCloudApiKey(value);
              _cloudKeyController.clear();
              if (mounted) {
                setState(() {});
              }
            }),
            onClear: () => _guarded(() async {
              await _notifier.clearCloudApiKey();
              if (mounted) {
                setState(() {});
              }
            }),
          ),
          _PlainField(
            fieldKey: const Key('cloud-endpoint-field'),
            label: 'API endpoint',
            hint: settings.cloudProvider.defaultEndpoint,
            controller: _cloudEndpointController,
            helper: 'Base URL only (no /chat/completions). '
                'E.g. z.ai → https://api.z.ai/api/paas/v4',
            onSave: (String value) =>
                _guarded(() => _notifier.setCloudEndpoint(value)),
          ),
          _PlainField(
            fieldKey: const Key('cloud-model-field'),
            label: 'Model',
            hint: settings.cloudProvider.defaultModel,
            controller: _cloudModelController,
            onSave: (String value) =>
                _guarded(() => _notifier.setCloudModel(value)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.gutter,
              12,
              AppTheme.gutter,
              4,
            ),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('cloud-test-connection'),
                onPressed: _testingConnection ? null : _testCloudConnection,
                icon: _testingConnection
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_tethering),
                label: Text(
                  _testingConnection ? 'Testing…' : 'Test connection',
                ),
              ),
            ),
          ),
          const _SectionHeader('Models'),
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

  static const List<RuntimeChoice> _visibleRuntimes = <RuntimeChoice>[
    RuntimeChoice.local,
    RuntimeChoice.cloud,
  ];

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

/// Cloud API-format picker: a two-segment control (OpenAI / Claude) with a
/// caption naming the two supported wire formats.
class _CloudProviderPicker extends StatelessWidget {
  const _CloudProviderPicker({required this.selected, required this.onChanged});

  final CloudProvider selected;
  final ValueChanged<CloudProvider> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.gutter, 8, AppTheme.gutter, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('API format', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<CloudProvider>(
            key: const Key('cloud-provider-picker'),
            segments: <ButtonSegment<CloudProvider>>[
              for (final CloudProvider provider in CloudProvider.values)
                ButtonSegment<CloudProvider>(
                  value: provider,
                  label: Text(provider.label),
                ),
            ],
            selected: <CloudProvider>{selected},
            showSelectedIcon: false,
            onSelectionChanged: (Set<CloudProvider> selection) =>
                onChanged(selection.first),
          ),
          const SizedBox(height: 8),
          Text(
            'Supported: OpenAI-compatible Chat Completions and Anthropic '
            '(Claude) Messages. Point the endpoint at any OpenAI-compatible '
            'gateway (Azure, Groq, Together, …) with the OpenAI format.',
            style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.muted),
          ),
        ],
      ),
    );
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

/// A plain (non-secret) single-line input with an inline Save action, used for
/// values that should stay visible after entry (e.g. the cloud API endpoint).
class _PlainField extends StatelessWidget {
  const _PlainField({
    required this.fieldKey,
    required this.label,
    required this.hint,
    required this.controller,
    required this.onSave,
    this.helper,
  });

  final Key fieldKey;
  final String label;
  final String hint;
  final TextEditingController controller;
  final void Function(String value) onSave;
  final String? helper;

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
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  key: fieldKey,
                  controller: controller,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: Theme.of(context).textTheme.bodyMedium,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: AppTheme.fill,
                    hintText: hint,
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
                  onSubmitted: onSave,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => onSave(controller.text),
                child: const Text('Save'),
              ),
            ],
          ),
          if (helper != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              helper!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.muted),
            ),
          ],
        ],
      ),
    );
  }
}
