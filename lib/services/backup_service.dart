import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/fillup.dart';
import '../models/vehicle.dart';
import 'local_repository.dart';
import 'preferences.dart';
import 'vehicle_photo_service.dart';

/// Scope of a durable JSON backup file.
enum BackupScope {
  fleet,
  vehicle,
}

/// Parsed durable / auto-backup JSON payload.
class BackupPayload {
  const BackupPayload({
    required this.version,
    required this.scope,
    required this.vehicles,
    required this.fillUps,
    this.settings = const {},
    this.exportedAt,
  });

  final int version;
  final BackupScope scope;
  final List<Map<String, dynamic>> vehicles;
  final List<Map<String, dynamic>> fillUps;
  final Map<String, dynamic> settings;
  final String? exportedAt;

  bool get hasPhotoPaths =>
      vehicles.any((v) => (v['photoPath'] as String?)?.isNotEmpty == true);
}

/// JSON snapshot of user data.
///
/// The auto-backup under app documents survives restarts/upgrades but not
/// uninstall. Durable export/import uses the same schema via the share sheet /
/// Files picker so users can keep a copy outside the sandbox.
class BackupService {
  static const fileName = 'gasmaster_backup.json';
  static const schemaVersion = 1;
  static const supportedVersions = {1};

  /// Override in tests to avoid path_provider.
  static Directory? documentsOverride;

  static Future<File> _backupFile() async {
    final dir = documentsOverride ?? await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, fileName));
  }

  /// Builds a snapshot map. When [vehicleId] is set, only that vehicle and its
  /// fill-ups are included (`scope: vehicle`); otherwise the full fleet.
  static Map<String, dynamic> snapshot({String? vehicleId}) {
    final allVehicles = LocalRepository.allVehicles();
    final vehicles = (vehicleId == null
            ? allVehicles
            : allVehicles.where((v) => v.id == vehicleId))
        .map(_vehicleToJson)
        .toList();

    final fillUps = LocalRepository.fillupBox.values
        .where((f) => vehicleId == null || f.vehicleId == vehicleId)
        .map(_fillUpToJson)
        .toList();

    return {
      'version': schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'scope': vehicleId == null ? BackupScope.fleet.name : BackupScope.vehicle.name,
      'settings': {
        'unitSystem': Preferences.unitSystem,
      },
      'vehicles': vehicles,
      'fillUps': fillUps,
    };
  }

  static Map<String, dynamic> _vehicleToJson(Vehicle v) => {
        'id': v.id,
        'color': v.color,
        'year': v.year,
        'make': v.make,
        'model': v.model,
        'trim': v.trim,
        'photoPath': v.photoPath,
      };

  static Map<String, dynamic> _fillUpToJson(FillUp f) => {
        'id': f.id,
        'vehicleId': f.vehicleId,
        'odometer': f.odometer,
        'fuelVolume': f.fuelVolume,
        'pricePaid': f.pricePaid,
        'date': f.date.toIso8601String(),
        'unitSystem': f.unitSystem,
        'isFullTank': f.isFullTank,
      };

  static String encodePretty(Map<String, dynamic> data) =>
      const JsonEncoder.withIndent('  ').convert(data);

  /// Parses and validates backup JSON. Throws [FormatException] on bad input.
  static BackupPayload decode(String raw) {
    if (raw.trim().isEmpty) {
      throw const FormatException('Backup file is empty.');
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Backup must be a JSON object.');
    }
    final data = Map<String, dynamic>.from(decoded);

    final versionRaw = data['version'];
    final version = versionRaw is num ? versionRaw.toInt() : null;
    if (version == null || !supportedVersions.contains(version)) {
      throw FormatException(
        'Unsupported backup version: ${versionRaw ?? 'missing'}.',
      );
    }

    final vehicles = (data['vehicles'] as List<dynamic>? ?? const [])
        .map((e) {
          if (e is! Map) {
            throw const FormatException('Invalid vehicle entry.');
          }
          return Map<String, dynamic>.from(e);
        })
        .toList();
    final fillUps = (data['fillUps'] as List<dynamic>? ?? const [])
        .map((e) {
          if (e is! Map) {
            throw const FormatException('Invalid fill-up entry.');
          }
          return Map<String, dynamic>.from(e);
        })
        .toList();

    for (final v in vehicles) {
      if (v['id'] is! String || (v['id'] as String).isEmpty) {
        throw const FormatException('Vehicle is missing an id.');
      }
      if (v['year'] is! num) {
        throw const FormatException('Vehicle is missing a year.');
      }
    }
    for (final f in fillUps) {
      if (f['id'] is! String || f['vehicleId'] is! String) {
        throw const FormatException('Fill-up is missing id or vehicleId.');
      }
      if (f['odometer'] is! num ||
          f['fuelVolume'] is! num ||
          f['pricePaid'] is! num ||
          f['date'] is! String) {
        throw const FormatException('Fill-up has invalid numeric or date fields.');
      }
    }

    final scopeName = data['scope'] as String?;
    final BackupScope scope;
    if (scopeName == BackupScope.vehicle.name) {
      if (vehicles.length != 1) {
        throw const FormatException(
          'Single-vehicle backup must contain exactly one vehicle.',
        );
      }
      final id = vehicles.first['id'] as String;
      final orphan = fillUps.any((f) => f['vehicleId'] != id);
      if (orphan) {
        throw const FormatException(
          'Single-vehicle backup has fill-ups for another vehicle.',
        );
      }
      scope = BackupScope.vehicle;
    } else {
      // Missing or "fleet" — treat as full-fleet replace (incl. auto-backup).
      scope = BackupScope.fleet;
    }

    final settingsRaw = data['settings'];
    final settings = settingsRaw is Map
        ? Map<String, dynamic>.from(settingsRaw)
        : <String, dynamic>{};

    return BackupPayload(
      version: version,
      scope: scope,
      vehicles: vehicles,
      fillUps: fillUps,
      settings: settings,
      exportedAt: data['exportedAt'] as String?,
    );
  }

  static Vehicle _vehicleFromJson(Map<String, dynamic> m) => Vehicle(
        id: m['id'] as String,
        color: m['color'] as String? ?? '',
        year: (m['year'] as num).toInt(),
        make: m['make'] as String? ?? '',
        model: m['model'] as String? ?? '',
        trim: m['trim'] as String? ?? '',
        photoPath: m['photoPath'] as String?,
      );

  static FillUp _fillUpFromJson(Map<String, dynamic> m) => FillUp(
        id: m['id'] as String,
        vehicleId: m['vehicleId'] as String,
        odometer: (m['odometer'] as num).toDouble(),
        fuelVolume: (m['fuelVolume'] as num).toDouble(),
        pricePaid: (m['pricePaid'] as num).toDouble(),
        date: DateTime.parse(m['date'] as String),
        unitSystem: m['unitSystem'] as String? ?? 'imperial',
        isFullTank: m['isFullTank'] as bool? ?? true,
      );

  static Future<void> _applySettings(Map<String, dynamic> settings) async {
    final unit = settings['unitSystem'];
    if (unit is String && (unit == 'imperial' || unit == 'metric')) {
      await Preferences.setUnitSystem(unit);
    }
  }

  /// Replaces the entire fleet with [payload] (vehicles, fill-ups, settings).
  static Future<void> importReplaceAll(BackupPayload payload) async {
    if (payload.vehicles.isEmpty) {
      throw const FormatException('Backup contains no vehicles.');
    }
    for (final v in LocalRepository.vehicleBox.values.toList()) {
      await VehiclePhotoService.deletePhoto(v.photoPath);
    }
    await LocalRepository.fillupBox.clear();
    await LocalRepository.vehicleBox.clear();

    for (final m in payload.vehicles) {
      final v = _vehicleFromJson(m);
      await LocalRepository.vehicleBox.put(v.id, v);
    }
    for (final m in payload.fillUps) {
      final f = _fillUpFromJson(m);
      await LocalRepository.fillupBox.put(f.id, f);
    }

    await _applySettings(payload.settings);
    await LocalRepository.persistNow();
    LocalRepository.notifyAllListeners();
  }

  /// Replaces (or adds) the single vehicle in [payload] and its fill-ups.
  static Future<void> importReplaceVehicle(BackupPayload payload) async {
    if (payload.scope != BackupScope.vehicle || payload.vehicles.length != 1) {
      throw const FormatException('Not a single-vehicle backup.');
    }

    final vehicleMap = payload.vehicles.first;
    final id = vehicleMap['id'] as String;

    if (LocalRepository.vehicleBox.containsKey(id)) {
      await LocalRepository.deleteVehicle(id);
    }

    final v = _vehicleFromJson(vehicleMap);
    await LocalRepository.vehicleBox.put(v.id, v);
    for (final m in payload.fillUps) {
      final f = _fillUpFromJson(m);
      await LocalRepository.fillupBox.put(f.id, f);
    }

    await _applySettings(payload.settings);
    await LocalRepository.persistNow();
    LocalRepository.notifyAllListeners();
  }

  static Future<void> importPayload(BackupPayload payload) async {
    if (payload.scope == BackupScope.vehicle) {
      await importReplaceVehicle(payload);
    } else {
      await importReplaceAll(payload);
    }
  }

  static String fleetBackupFilename() {
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return 'gasmaster_backup_$date.json';
  }

  static String vehicleBackupFilename(Vehicle vehicle) {
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    var slug = vehicle.displayName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    slug = slug.replaceAll(RegExp(r'_+'), '_');
    slug = slug.replaceAll(RegExp(r'^_|_$'), '');
    return 'gasmaster_${slug}_$date.json';
  }

  /// Writes JSON to a temp file and opens the platform share sheet (Files, etc.).
  static Future<void> shareBackupJson(
    String json,
    String filename, {
    Rect? sharePositionOrigin,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(json);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json', name: filename)],
      subject: filename,
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  /// Picks a `.json` backup via the system document picker. Returns null if cancelled.
  static Future<BackupPayload?> pickAndDecodeBackup() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.single;
    String raw;
    if (file.bytes != null) {
      raw = utf8.decode(file.bytes!);
    } else if (file.path != null) {
      raw = await File(file.path!).readAsString();
    } else {
      throw const FormatException('Could not read the selected backup file.');
    }
    return decode(raw);
  }

  static Future<void> writeBackup() async {
    try {
      final file = await _backupFile();
      // Auto-backup is always the full fleet (no scope filter).
      final json = encodePretty(snapshot());
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

  /// Restores from auto-backup into empty Hive boxes. Returns true if data loaded.
  static Future<bool> restoreIfNeeded() async {
    if (LocalRepository.vehicleBox.isNotEmpty || LocalRepository.fillupBox.isNotEmpty) {
      return false;
    }
    final file = await _backupFile();
    if (!await file.exists()) return false;

    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return false;

    final payload = decode(raw);
    for (final m in payload.vehicles) {
      final v = _vehicleFromJson(m);
      await LocalRepository.vehicleBox.put(v.id, v);
    }
    for (final m in payload.fillUps) {
      final f = _fillUpFromJson(m);
      await LocalRepository.fillupBox.put(f.id, f);
    }
    await _applySettings(payload.settings);

    await LocalRepository.vehicleBox.flush();
    await LocalRepository.fillupBox.flush();
    return payload.vehicles.isNotEmpty || payload.fillUps.isNotEmpty;
  }
}
