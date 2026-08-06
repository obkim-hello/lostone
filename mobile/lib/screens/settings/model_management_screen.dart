import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/model_descriptor.dart';
import '../../models/model_install.dart';
import '../../models/model_manager_state.dart';
import '../../providers/settings_providers.dart';
import '../../services/settings/model_manager_notifier.dart';
import '../../theme/app_theme.dart';

/// Human-readable UI text for a typed [InstallErrorKind] (ERD-010 §6.3).
String installErrorLabel(InstallErrorKind kind) {
  return switch (kind) {
    InstallErrorKind.authRequired => 'Hugging Face token required',
    InstallErrorKind.insufficientStorage => 'Not enough storage',
    InstallErrorKind.unsupportedDevice => 'May not run on this device',
    InstallErrorKind.network => 'Download failed (network)',
    InstallErrorKind.corrupted => 'File verification failed',
    InstallErrorKind.canceled => 'Canceled',
    InstallErrorKind.unknownModel => 'Unknown model',
    InstallErrorKind.unknown => 'Install failed',
  };
}

/// Manages the on-device model catalog: install, cancel, activate, delete.
class ModelManagementScreen extends ConsumerWidget {
  /// Creates the model-management screen.
  const ModelManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ModelManagerState state = ref.watch(modelManagerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Models')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: <Widget>[
          for (final ModelDescriptor descriptor in state.catalog)
            _ModelTile(descriptor: descriptor, state: state),
        ],
      ),
    );
  }
}

class _ModelTile extends ConsumerWidget {
  const _ModelTile({required this.descriptor, required this.state});

  final ModelDescriptor descriptor;
  final ModelManagerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ModelManagerNotifier notifier = ref.read(
      modelManagerProvider.notifier,
    );
    final InstallProgress? progress = state.progress[descriptor.id];
    final bool isActive = state.activeModelId == descriptor.id;
    final bool isReady = _isReady(progress) || _isInstalledReady();
    final bool isDownloading =
        progress?.state == ModelState.downloading ||
        progress?.state == ModelState.verifying;
    final InstallFailure? failure = state.lastError?.modelId == descriptor.id
        ? state.lastError
        : null;

    return Container(
      key: Key('model-tile-${descriptor.id}'),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.separator, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.gutter,
        vertical: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _ModelAvatar(descriptor: descriptor),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            descriptor.displayName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (isActive) const _ActiveChip(),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_megabytes(descriptor.sizeBytes)} MB',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isDownloading) ...<Widget>[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                key: Key('progress-${descriptor.id}'),
                value: progress?.fraction,
                minHeight: 3,
                backgroundColor: AppTheme.separator,
                color: AppTheme.accent,
              ),
            ),
          ],
          if (failure != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                installErrorLabel(failure.kind),
                key: Key('error-${descriptor.id}'),
                style: const TextStyle(
                  color: AppTheme.danger,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              if (isDownloading)
                Expanded(
                  child: _OutlinedAction(
                    actionKey: Key('cancel-${descriptor.id}'),
                    label: 'Cancel',
                    onPressed: () => notifier.cancel(descriptor.id),
                  ),
                )
              else if (!isReady)
                Expanded(
                  child: FilledButton(
                    key: Key('install-${descriptor.id}'),
                    onPressed: () => notifier.install(descriptor.id),
                    child: const Text('Install'),
                  ),
                ),
              if (isReady && !isActive) ...<Widget>[
                Expanded(
                  child: FilledButton(
                    key: Key('activate-${descriptor.id}'),
                    onPressed: () => notifier.activate(descriptor.id),
                    child: const Text('Activate'),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (isReady)
                Expanded(
                  child: _OutlinedAction(
                    actionKey: Key('delete-${descriptor.id}'),
                    label: 'Delete',
                    destructive: true,
                    onPressed: () => _confirmDelete(context, notifier),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isReady(InstallProgress? progress) =>
      progress?.state == ModelState.ready;

  bool _isInstalledReady() {
    for (final InstalledModel model in state.installed) {
      if (model.descriptor.id == descriptor.id) {
        return model.state == ModelState.ready;
      }
    }
    return false;
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ModelManagerNotifier notifier,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          key: const Key('delete-dialog'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: const Text('Delete model?'),
          content: Text('Remove ${descriptor.displayName} from this device.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed ?? false) {
      await notifier.delete(descriptor.id);
    }
  }

  int _megabytes(int bytes) => (bytes / (1024 * 1024)).round();
}

/// A rounded avatar showing the first letter of a model's display name.
class _ModelAvatar extends StatelessWidget {
  const _ModelAvatar({required this.descriptor});

  final ModelDescriptor descriptor;

  @override
  Widget build(BuildContext context) {
    final String initial = descriptor.displayName.isEmpty
        ? '?'
        : descriptor.displayName.substring(0, 1).toUpperCase();
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

/// The "Active" pill shown on the currently selected model.
class _ActiveChip extends StatelessWidget {
  const _ActiveChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('active-chip'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        'Active',
        style: TextStyle(
          color: AppTheme.accent,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// A flat outlined button used for secondary and destructive actions.
class _OutlinedAction extends StatelessWidget {
  const _OutlinedAction({
    required this.actionKey,
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  final Key actionKey;
  final String label;
  final VoidCallback onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final Color color = destructive ? AppTheme.danger : AppTheme.ink;
    return OutlinedButton(
      key: actionKey,
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: const BorderSide(color: AppTheme.separator),
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      child: Text(label),
    );
  }
}
