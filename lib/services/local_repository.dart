import 'dart:async';

import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/vehicle.dart';
import '../models/fillup.dart';
import '../models/reminder.dart';
import '../utils/stats.dart';
import 'backup_service.dart';
import 'vehicle_photo_service.dart';

typedef RepositoryListener = void Function();

class LocalRepository {
  static const _vehicles = 'vehicles';
  static const _fillups = 'fillups';

  static final _vehicleListeners = <RepositoryListener>{};
  static final _fillupListeners = <RepositoryListener>{};

  static Future<void>? _backupInFlight;
  static Timer? _backupDebounce;

  static Future<void> bootstrap() async {
    await Hive.openBox<Vehicle>(_vehicles);
    await Hive.openBox<FillUp>(_fillups);
    await BackupService.restoreIfNeeded();
  }

  static Box<Vehicle> get vehicleBox => Hive.box<Vehicle>(_vehicles);
  static Box<FillUp> get fillupBox => Hive.box<FillUp>(_fillups);

  static void addVehicleListener(RepositoryListener listener) {
    _vehicleListeners.add(listener);
  }

  static void removeVehicleListener(RepositoryListener listener) {
    _vehicleListeners.remove(listener);
  }

  static void addFillUpListener(RepositoryListener listener) {
    _fillupListeners.add(listener);
  }

  static void removeFillUpListener(RepositoryListener listener) {
    _fillupListeners.remove(listener);
  }

  static void _notifyVehicleListeners() {
    scheduleMicrotask(() {
      for (final listener in List<RepositoryListener>.from(_vehicleListeners)) {
        listener();
      }
    });
  }

  static void _notifyFillUpListeners() {
    scheduleMicrotask(() {
      for (final listener in List<RepositoryListener>.from(_fillupListeners)) {
        listener();
      }
    });
  }

  /// Notifies vehicle and fill-up listeners (e.g. after a durable import).
  static void notifyAllListeners() {
    _notifyVehicleListeners();
    _notifyFillUpListeners();
  }

  static Future<void> _persistVehicles() async {
    await vehicleBox.flush();
    _scheduleBackup();
  }

  static Future<void> _persistFillUps() async {
    await fillupBox.flush();
    _scheduleBackup();
  }

  /// Debounced JSON backup so rapid edits don't thrash disk.
  static void _scheduleBackup() {
    _backupDebounce?.cancel();
    _backupDebounce = Timer(const Duration(milliseconds: 300), () {
      persistNow();
    });
  }

  /// Flush Hive and write the JSON backup immediately.
  static Future<void> persistNow() async {
    _backupDebounce?.cancel();
    if (Hive.isBoxOpen(_vehicles)) await vehicleBox.flush();
    if (Hive.isBoxOpen(_fillups)) await fillupBox.flush();
    _backupInFlight = BackupService.writeBackup();
    await _backupInFlight;
  }

  // Vehicles
  static Future<String> addVehicle({
    required String color,
    required int year,
    required String make,
    required String model,
    required String trim,
    String? photoPath,
  }) async {
    final id = const Uuid().v4();
    final v = Vehicle(
      id: id,
      color: color,
      year: year,
      make: make,
      model: model,
      trim: trim,
      photoPath: photoPath,
    );
    await vehicleBox.put(id, v);
    await _persistVehicles();
    _notifyVehicleListeners();
    return id;
  }

  static Future<ImageOptimizationResult?> setVehiclePhoto({
    required String vehicleId,
    required ImageOptimizationResult optimized,
  }) async {
    final v = vehicleBox.get(vehicleId);
    if (v == null) return null;
    final saved = await VehiclePhotoService.saveOptimizedBytes(
      vehicleId: vehicleId,
      result: optimized,
    );
    v.photoPath = saved.relativePath;
    await v.save();
    await _persistVehicles();
    _notifyVehicleListeners();
    return saved.result;
  }

  /// Updates a single reminder on a vehicle. Only non-null parameters are
  /// applied; pass [clearDueDate] to unset an existing due date.
  static Future<void> updateReminder({
    required String vehicleId,
    required ReminderType type,
    bool? doesNotApply,
    DateTime? dueDate,
    bool clearDueDate = false,
    int? renewalPeriodMonths,
    int? remindDaysPrior,
  }) async {
    final v = vehicleBox.get(vehicleId);
    if (v == null) return;
    final r = v.reminderFor(type);
    if (doesNotApply != null) r.doesNotApply = doesNotApply;
    if (clearDueDate) {
      r.dueDate = null;
    } else if (dueDate != null) {
      r.dueDate = dueDate;
    }
    if (renewalPeriodMonths != null) r.renewalPeriodMonths = renewalPeriodMonths;
    if (remindDaysPrior != null) r.remindDaysPrior = remindDaysPrior;
    await v.save();
    await _persistVehicles();
    _notifyVehicleListeners();
  }

  /// Advances a reminder's due date by one renewal period (e.g. after the user
  /// completes the renewal). No-op if the reminder has no due date.
  static Future<void> renewReminder({
    required String vehicleId,
    required ReminderType type,
  }) async {
    final v = vehicleBox.get(vehicleId);
    if (v == null) return;
    final r = v.reminderFor(type);
    final next = r.nextDueDateAfterRenewal();
    if (next == null) return;
    r.dueDate = next;
    await v.save();
    await _persistVehicles();
    _notifyVehicleListeners();
  }

  static Future<void> clearVehiclePhoto(String vehicleId) async {
    final v = vehicleBox.get(vehicleId);
    if (v == null) return;
    await VehiclePhotoService.deletePhoto(v.photoPath);
    v.photoPath = null;
    await v.save();
    await _persistVehicles();
    _notifyVehicleListeners();
  }

  static Future<void> deleteVehicle(String id) async {
    final existing = vehicleBox.get(id);
    await VehiclePhotoService.deletePhoto(existing?.photoPath);
    final toDelete = fillupBox.values.where((f) => f.vehicleId == id).map((f) => f.key).toList();
    await fillupBox.deleteAll(toDelete);
    await vehicleBox.delete(id);
    await _persistVehicles();
    await _persistFillUps();
    _notifyVehicleListeners();
    _notifyFillUpListeners();
  }

  // Fill-ups
  static Future<void> addFillUp({
    required String vehicleId,
    required double odometer,
    required double fuelVolume,
    required double pricePaid,
    required DateTime date,
    required String unitSystem,
    bool isFullTank = true,
  }) async {
    final id = const Uuid().v4();
    final f = FillUp(
      id: id,
      vehicleId: vehicleId,
      odometer: odometer,
      fuelVolume: fuelVolume,
      pricePaid: pricePaid,
      date: date,
      unitSystem: unitSystem,
      isFullTank: isFullTank,
    );
    await fillupBox.put(id, f);
    await _persistFillUps();
    _notifyFillUpListeners();
  }

  static FillUp? getFillUp(String id) => fillupBox.get(id);

  static Future<void> updateFillUp({
    required String id,
    required double odometer,
    required double fuelVolume,
    required double pricePaid,
    required DateTime date,
    required String unitSystem,
    required bool isFullTank,
  }) async {
    final existing = fillupBox.get(id);
    if (existing == null) return;
    existing
      ..odometer = odometer
      ..fuelVolume = fuelVolume
      ..pricePaid = pricePaid
      ..date = date
      ..unitSystem = unitSystem
      ..isFullTank = isFullTank;
    await existing.save();
    await _persistFillUps();
    _notifyFillUpListeners();
  }

  static Future<void> deleteFillUp(String id) async {
    await fillupBox.delete(id);
    await _persistFillUps();
    _notifyFillUpListeners();
  }

  // Queries
  static List<Vehicle> allVehicles() => vehicleBox.values.toList()
    ..sort((a, b) => a.year.compareTo(b.year));

  static List<FillUp> fillUpsFor(String vehicleId) => fillupBox.values
      .where((f) => f.vehicleId == vehicleId)
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  static VehicleStats vehicleStats(String vehicleId) {
    final fs = fillUpsFor(vehicleId);
    return VehicleStats.fromFillUps(fs);
  }
}
