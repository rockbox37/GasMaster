import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gasmaster/models/fillup.dart';
import 'package:gasmaster/models/reminder.dart';
import 'package:gasmaster/models/vehicle.dart';
import 'package:gasmaster/services/backup_service.dart';
import 'package:gasmaster/services/local_repository.dart';
import 'package:gasmaster/services/preferences.dart';
import 'package:gasmaster/services/vehicle_photo_service.dart';
import 'package:gasmaster/state/app_state.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'unit_system': 'imperial'});
    await Preferences.init();

    tempDir = await Directory.systemTemp.createTemp('gasmaster_repository_');
    final docsDir = Directory('${tempDir.path}/docs')..createSync();
    BackupService.documentsOverride = docsDir;
    VehiclePhotoService.documentsOverride = docsDir;

    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(VehicleAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(FillUpAdapter());
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(VehicleReminderAdapter());
    }
    await LocalRepository.bootstrap();
    await Hive.box<Vehicle>('vehicles').clear();
    await Hive.box<FillUp>('fillups').clear();
  });

  tearDown(() async {
    await LocalRepository.persistNow();
    BackupService.documentsOverride = null;
    VehiclePhotoService.documentsOverride = null;
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<String> addVehicle({
    String make = 'Honda',
    String model = 'Civic',
    int year = 2020,
  }) {
    return LocalRepository.addVehicle(
      color: 'Red',
      year: year,
      make: make,
      model: model,
      trim: '',
    );
  }

  Future<void> addFillUp({
    required String vehicleId,
    required double odometer,
    required double fuelVolume,
    DateTime? date,
  }) {
    return LocalRepository.addFillUp(
      vehicleId: vehicleId,
      odometer: odometer,
      fuelVolume: fuelVolume,
      pricePaid: 30,
      date: date ?? DateTime(2024, 6, 1),
      unitSystem: 'imperial',
    );
  }

  Future<void> flushProviderNotifications() async {
    await Future<void>.delayed(Duration.zero);
  }

  test('fill-up CRUD synchronizes family and derived stats providers',
      () async {
    final vehicleId = await addVehicle();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(fillUpsProvider(vehicleId)), isEmpty);
    expect(container.read(statsProvider(vehicleId)).totalFuel, 0);

    await addFillUp(
      vehicleId: vehicleId,
      odometer: 10000,
      fuelVolume: 10,
    );
    await flushProviderNotifications();

    final created = container.read(fillUpsProvider(vehicleId)).single;
    expect(created.odometer, 10000);
    expect(container.read(statsProvider(vehicleId)).totalFuel, 10);

    await LocalRepository.updateFillUp(
      id: created.id,
      odometer: 10300,
      fuelVolume: 12,
      pricePaid: 36,
      date: DateTime(2024, 6, 15),
      unitSystem: 'imperial',
      isFullTank: false,
    );
    await flushProviderNotifications();

    final updated = container.read(fillUpsProvider(vehicleId)).single;
    expect(updated.odometer, 10300);
    expect(updated.fuelVolume, 12);
    expect(updated.pricePaid, 36);
    expect(updated.isFullTank, isFalse);
    expect(container.read(statsProvider(vehicleId)).totalFuel, 12);

    await LocalRepository.deleteFillUp(created.id);
    await flushProviderNotifications();

    expect(container.read(fillUpsProvider(vehicleId)), isEmpty);
    expect(container.read(statsProvider(vehicleId)).totalFuel, 0);
  });

  test(
      'vehicle deletion cascades fill-ups and photo files but preserves other vehicles',
      () async {
    final targetId = await addVehicle(make: 'Target');
    final otherId = await addVehicle(make: 'Other', year: 2021);
    await addFillUp(vehicleId: targetId, odometer: 100, fuelVolume: 5);
    await addFillUp(vehicleId: otherId, odometer: 200, fuelVolume: 6);

    final photo = ImageOptimizationResult(
      bytes: Uint8List.fromList([1, 2, 3, 4]),
      originalBytes: 4,
      optimizedBytes: 4,
      maxEdge: VehiclePhotoService.maxEdge,
      quality: VehiclePhotoService.jpegQuality,
    );
    await LocalRepository.setVehiclePhoto(
      vehicleId: targetId,
      optimized: photo,
    );
    final photoPath = await VehiclePhotoService.absolutePath(
      VehiclePhotoService.relativePathFor(targetId),
    );
    expect(await File(photoPath).exists(), isTrue);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(vehiclesProvider), hasLength(2));
    expect(container.read(fillUpsProvider(targetId)), hasLength(1));

    await LocalRepository.deleteVehicle(targetId);
    await flushProviderNotifications();

    expect(LocalRepository.vehicleBox.get(targetId), isNull);
    expect(LocalRepository.fillUpsFor(targetId), isEmpty);
    expect(LocalRepository.vehicleBox.get(otherId)?.make, 'Other');
    expect(LocalRepository.fillUpsFor(otherId), hasLength(1));
    expect(await File(photoPath).exists(), isFalse);
    expect(container.read(vehiclesProvider), hasLength(1));
    expect(container.read(vehiclesProvider).single.id, otherId);
    expect(container.read(fillUpsProvider(targetId)), isEmpty);
  });

  test('setVehiclePhoto and clearVehiclePhoto persist and remove the file',
      () async {
    final vehicleId = await addVehicle();
    final photo = ImageOptimizationResult(
      bytes: Uint8List.fromList([9, 8, 7]),
      originalBytes: 3,
      optimizedBytes: 3,
      maxEdge: VehiclePhotoService.maxEdge,
      quality: VehiclePhotoService.jpegQuality,
    );

    final saved = await LocalRepository.setVehiclePhoto(
      vehicleId: vehicleId,
      optimized: photo,
    );
    expect(saved, same(photo));
    expect(
      LocalRepository.vehicleBox.get(vehicleId)?.photoPath,
      VehiclePhotoService.relativePathFor(vehicleId),
    );

    final file = File(
      await VehiclePhotoService.absolutePath(
        VehiclePhotoService.relativePathFor(vehicleId),
      ),
    );
    expect(await file.readAsBytes(), photo.bytes);

    await LocalRepository.clearVehiclePhoto(vehicleId);

    expect(LocalRepository.vehicleBox.get(vehicleId)?.photoPath, isNull);
    expect(await file.exists(), isFalse);
  });
}
