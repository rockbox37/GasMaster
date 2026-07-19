import 'package:flutter/material.dart';

import '../models/vehicle.dart';
import '../services/backup_service.dart';

/// Photos are not packaged in v1 durable JSON backups.
const kBackupPhotosDeferredNote =
    'Vehicle photos are not included in backup files yet. '
    'After import, photo thumbnails may be missing until you re-add them.';

bool _hasPhotoPaths(List<dynamic> vehicles) => vehicles.any((v) {
      if (v is! Map) return false;
      final path = v['photoPath'];
      return path is String && path.isNotEmpty;
    });

Future<void> exportFleetBackup(BuildContext context) async {
  final data = BackupService.snapshot();
  final list = data['vehicles'] as List;
  if (list.isEmpty) {
    _snack(context, 'Nothing to export');
    return;
  }

  final hasPhotos = _hasPhotoPaths(list);
  if (hasPhotos && context.mounted) {
    final proceed = await _confirm(
      context,
      title: 'Export fleet backup?',
      body: 'A JSON file will open in the share sheet so you can save it to '
          'Files or elsewhere.\n\n$kBackupPhotosDeferredNote',
      confirmLabel: 'Export',
    );
    if (proceed != true) return;
  }

  final json = BackupService.encodePretty(data);
  await BackupService.shareBackupJson(json, BackupService.fleetBackupFilename());
  if (context.mounted) {
    _snack(
      context,
      hasPhotos ? 'Backup ready — photos not included' : 'Backup ready',
    );
  }
}

Future<void> exportVehicleBackup(BuildContext context, Vehicle vehicle) async {
  final data = BackupService.snapshot(vehicleId: vehicle.id);
  final list = data['vehicles'] as List;
  if (list.isEmpty) {
    _snack(context, 'Nothing to export');
    return;
  }

  final hasPhotos = _hasPhotoPaths(list);
  if (hasPhotos && context.mounted) {
    final proceed = await _confirm(
      context,
      title: 'Export vehicle backup?',
      body: 'A JSON file will open in the share sheet so you can save it to '
          'Files or elsewhere.\n\n$kBackupPhotosDeferredNote',
      confirmLabel: 'Export',
    );
    if (proceed != true) return;
  }

  final json = BackupService.encodePretty(data);
  await BackupService.shareBackupJson(
    json,
    BackupService.vehicleBackupFilename(vehicle),
  );
  if (context.mounted) {
    _snack(
      context,
      hasPhotos ? 'Backup ready — photos not included' : 'Backup ready',
    );
  }
}

Future<void> importBackupFlow(
  BuildContext context, {
  VoidCallback? onImported,
}) async {
  try {
    final payload = await BackupService.pickAndDecodeBackup();
    if (payload == null) return;
    if (!context.mounted) return;

    if (payload.vehicles.isEmpty) {
      _snack(context, 'Backup contains no vehicles');
      return;
    }

    final photoNote =
        payload.hasPhotoPaths ? '\n\n$kBackupPhotosDeferredNote' : '';

    final bool? ok;
    if (payload.scope == BackupScope.vehicle) {
      final name = _vehicleLabel(payload.vehicles.first);
      ok = await _confirm(
        context,
        title: 'Replace this vehicle?',
        body: 'Importing will replace “$name” (or add it if missing) and '
            'its fill-ups. Other vehicles are left unchanged.$photoNote',
        confirmLabel: 'Replace vehicle',
      );
    } else {
      ok = await _confirm(
        context,
        title: 'Replace all garage data?',
        body: 'Importing will delete every vehicle and fill-up on this device, '
            'then restore from the backup file.$photoNote',
        confirmLabel: 'Replace all',
      );
    }
    if (ok != true || !context.mounted) return;

    await BackupService.importPayload(payload);
    onImported?.call();
    if (context.mounted) {
      _snack(
        context,
        payload.scope == BackupScope.vehicle
            ? 'Vehicle restored from backup'
            : 'Garage restored from backup',
      );
    }
  } on FormatException catch (e) {
    if (context.mounted) {
      _snack(context, e.message);
    }
  } catch (_) {
    if (context.mounted) {
      _snack(context, 'Could not import backup');
    }
  }
}

String _vehicleLabel(Map<String, dynamic> m) {
  final year = m['year'];
  final make = m['make'] as String? ?? '';
  final model = m['model'] as String? ?? '';
  final trim = m['trim'] as String? ?? '';
  final base = '$year $make $model'.trim();
  return trim.isNotEmpty ? '$base ($trim)' : base;
}

Future<bool?> _confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}
