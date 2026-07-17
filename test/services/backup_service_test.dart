import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:gasmaster/models/fillup.dart';
import 'package:gasmaster/models/vehicle.dart';
import 'package:gasmaster/services/backup_service.dart';
import 'package:gasmaster/services/local_repository.dart';

void main() {
  late Directory tempDir;
  late Directory docsDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('gasmaster_backup_');
    docsDir = Directory('${tempDir.path}/docs')..createSync();
    BackupService.documentsOverride = docsDir;

    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(VehicleAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(FillUpAdapter());
    await LocalRepository.bootstrap();
    await Hive.box<Vehicle>('vehicles').clear();
    await Hive.box<FillUp>('fillups').clear();
  });

  tearDown(() async {
    BackupService.documentsOverride = null;
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('writeBackup and restoreIfNeeded round-trip data', () async {
    await LocalRepository.addVehicle(
      color: 'Blue',
      year: 2020,
      make: 'Toyota',
      model: 'Camry',
      trim: 'SE',
    );
    final vehicleId = LocalRepository.allVehicles().first.id;
    await LocalRepository.addFillUp(
      vehicleId: vehicleId,
      odometer: 10000,
      fuelVolume: 12,
      pricePaid: 40,
      date: DateTime(2024, 6, 1),
      unitSystem: 'imperial',
      isFullTank: true,
    );

    await LocalRepository.persistNow();
    expect(await BackupService.backupExists(), isTrue);

    await Hive.box<Vehicle>('vehicles').clear();
    await Hive.box<FillUp>('fillups').clear();
    expect(LocalRepository.allVehicles(), isEmpty);

    final restored = await BackupService.restoreIfNeeded();
    expect(restored, isTrue);
    expect(LocalRepository.allVehicles().length, 1);
    expect(LocalRepository.allVehicles().first.make, 'Toyota');
    expect(LocalRepository.fillUpsFor(vehicleId).length, 1);
    expect(LocalRepository.fillUpsFor(vehicleId).first.odometer, 10000);
  });

  test('restoreIfNeeded is a no-op when Hive already has data', () async {
    await LocalRepository.addVehicle(
      color: 'Red',
      year: 2019,
      make: 'Honda',
      model: 'Civic',
      trim: '',
    );
    await LocalRepository.persistNow();

    final restored = await BackupService.restoreIfNeeded();
    expect(restored, isFalse);
    expect(LocalRepository.allVehicles().length, 1);
  });

  test('snapshot includes vehicles and fill-ups', () async {
    await LocalRepository.addVehicle(
      color: 'Black',
      year: 2021,
      make: 'Ford',
      model: 'F-150',
      trim: 'XLT',
    );
    final id = LocalRepository.allVehicles().first.id;
    await LocalRepository.addFillUp(
      vehicleId: id,
      odometer: 5000,
      fuelVolume: 20,
      pricePaid: 70,
      date: DateTime(2024, 1, 1),
      unitSystem: 'imperial',
      isFullTank: false,
    );

    final snap = BackupService.snapshot();
    expect(snap['version'], 1);
    expect((snap['vehicles'] as List).length, 1);
    expect((snap['fillUps'] as List).length, 1);
    expect((snap['fillUps'] as List).first['isFullTank'], isFalse);
  });
}
