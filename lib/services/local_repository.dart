import 'dart:async';

import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/vehicle.dart';
import '../models/fillup.dart';
import '../utils/stats.dart';

typedef RepositoryListener = void Function();

class LocalRepository {
  static const _vehicles = 'vehicles';
  static const _fillups = 'fillups';

  static final _vehicleListeners = <RepositoryListener>{};
  static final _fillupListeners = <RepositoryListener>{};

  static Future<void> bootstrap() async {
    await Hive.openBox<Vehicle>(_vehicles);
    await Hive.openBox<FillUp>(_fillups);
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

  // Vehicles
  static Future<String> addVehicle({
    required String color,
    required int year,
    required String make,
    required String model,
    required String trim,
  }) async {
    final id = const Uuid().v4();
    final v = Vehicle(id: id, color: color, year: year, make: make, model: model, trim: trim);
    await vehicleBox.put(id, v);
    _notifyVehicleListeners();
    return id;
  }

  static Future<void> deleteVehicle(String id) async {
    final toDelete = fillupBox.values.where((f) => f.vehicleId == id).map((f) => f.key).toList();
    await fillupBox.deleteAll(toDelete);
    await vehicleBox.delete(id);
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
    _notifyFillUpListeners();
  }

  static Future<void> deleteFillUp(String id) async {
    await fillupBox.delete(id);
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
