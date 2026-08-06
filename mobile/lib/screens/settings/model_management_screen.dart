import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/model_descriptor.dart';
import '../../models/model_install.dart';
import '../../models/model_manager_state.dart';
import '../../providers/settings_providers.dart';
import '../../services/settings/model_manager_notifier.dart';

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

    return Card(
      key: Key('model-tile-${descriptor.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
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
                if (isActive)
                  const Chip(key: Key('active-chip'), label: Text('Active')),
              ],
            ),
            Text('${_megabytes(descriptor.sizeBytes)} MB'),
            if (isDownloading) ...<Widget>[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                key: Key('progress-${descriptor.id}'),
                value: progress?.fraction,
              ),
            ],
            if (failure != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  installErrorLabel(failure.kind),
                  key: Key('error-${descriptor.id}'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: <Widget>[
                if (isDownloading)
                  TextButton(
                    key: Key('cancel-${descriptor.id}'),
                    onPressed: () => notifier.cancel(descriptor.id),
                    child: const Text('Cancel'),
                  )
                else if (!isReady)
                  FilledButton(
                    key: Key('install-${descriptor.id}'),
                    onPressed: () => notifier.install(descriptor.id),
                    child: const Text('Install'),
                  ),
                if (isReady && !isActive)
                  FilledButton.tonal(
                    key: Key('activate-${descriptor.id}'),
                    onPressed: () => notifier.activate(descriptor.id),
                    child: const Text('Activate'),
                  ),
                if (isReady)
                  TextButton(
                    key: Key('delete-${descriptor.id}'),
                    onPressed: () => _confirmDelete(context, notifier),
                    child: const Text('Delete'),
                  ),
              ],
            ),
          ],
        ),
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
          title: const Text('Delete model?'),
          content: Text('Remove ${descriptor.displayName} from this device.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
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
