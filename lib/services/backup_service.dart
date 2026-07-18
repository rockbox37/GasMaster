import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/fillup.dart';
import '../models/vehicle.dart';
import 'local_repository.dart';

/// JSON snapshot of all user data, stored in the app documents directory.
///
/// Survives normal app restarts and upgrades. Restored automatically if Hive
/// boxes are empty but a backup file exists (e.g. after a corrupt open).
class BackupService {
  static const _fileName = 'gasmaster_backup.json';
  static const _version = 1;

  /// Override in tests to avoid path_provider.
  static Directory? documentsOverride;

  static Future<File> _backupFile() async {
    final dir = documentsOverride ?? await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _fileName));
  }

  static Map<String, dynamic> snapshot() {
    final vehicles = LocalRepository.allVehicles()
        .map((v) => {
              'id': v.id,
              'color': v.color,
              'year': v.year,
              'make': v.make,
              'model': v.model,
              'trim': v.trim,
              'photoPath': v.photoPath,
            })
        .toList();

    final fillUps = LocalRepository.fillupBox.values
        .map((f) => {
              'id': f.id,
              'vehicleId': f.vehicleId,
              'odometer': f.odometer,
              'fuelVolume': f.fuelVolume,
              'pricePaid': f.pricePaid,
              'date': f.date.toIso8601String(),
              'unitSystem': f.unitSystem,
              'isFullTank': f.isFullTank,
            })
        .toList();

    return {
      'version': _version,
      'exportedAt': DateTime.now().toIso8601String(),
      'vehicles': vehicles,
      'fillUps': fillUps,
    };
  }

  static Future<void> writeBackup() async {
    try {
      final file = await _backupFile();
      final json = const JsonEncoder.withIndent('  ').convert(snapshot());
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(json, flush: true);
      if (await file.exists()) {
        await file.delete();
      }
      await tmp.rename(file.path);
    } catch (_) {
      // Never fail a user save because backup I/O failed.
    }
  }

  static Future<bool> backupExists() async {
    final file = await _backupFile();
    return file.exists();
  }

  /// Restores from backup into empty Hive boxes. Returns true if data was loaded.
  static Future<bool> restoreIfNeeded() async {
    if (LocalRepository.vehicleBox.isNotEmpty || LocalRepository.fillupBox.isNotEmpty) {
      return false;
    }
    final file = await _backupFile();
    if (!await file.exists()) return false;

    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return false;

    final Map<String, dynamic> data =
        Map<String, dynamic>.from(jsonDecode(raw) as Map);
    final vehicles = (data['vehicles'] as List<dynamic>? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final fillUps = (data['fillUps'] as List<dynamic>? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    for (final m in vehicles) {
      final v = Vehicle(
        id: m['id'] as String,
        color: m['color'] as String? ?? '',
        year: (m['year'] as num).toInt(),
        make: m['make'] as String? ?? '',
        model: m['model'] as String? ?? '',
        trim: m['trim'] as String? ?? '',
        photoPath: m['photoPath'] as String?,
      );
      await LocalRepository.vehicleBox.put(v.id, v);
    }

    for (final m in fillUps) {
      final f = FillUp(
        id: m['id'] as String,
        vehicleId: m['vehicleId'] as String,
        odometer: (m['odometer'] as num).toDouble(),
        fuelVolume: (m['fuelVolume'] as num).toDouble(),
        pricePaid: (m['pricePaid'] as num).toDouble(),
        date: DateTime.parse(m['date'] as String),
        unitSystem: m['unitSystem'] as String? ?? 'imperial',
        isFullTank: m['isFullTank'] as bool? ?? true,
      );
      await LocalRepository.fillupBox.put(f.id, f);
    }

    await LocalRepository.vehicleBox.flush();
    await LocalRepository.fillupBox.flush();
    return vehicles.isNotEmpty || fillUps.isNotEmpty;
  }
}
