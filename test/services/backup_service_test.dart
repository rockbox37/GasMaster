import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gasmaster/models/fillup.dart';
import 'package:gasmaster/models/vehicle.dart';
import 'package:gasmaster/services/backup_service.dart';
import 'package:gasmaster/services/local_repository.dart';
import 'package:gasmaster/services/preferences.dart';

void main() {
  late Directory tempDir;
  late Directory docsDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'unit_system': 'imperial'});
    await Preferences.init();

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

  Future<String> seedVehicle({
    String make = 'Toyota',
    String model = 'Camry',
    String color = 'Blue',
    int year = 2020,
    String trim = 'SE',
  }) async {
    await LocalRepository.addVehicle(
      color: color,
      year: year,
      make: make,
      model: model,
      trim: trim,
    );
    return LocalRepository.allVehicles().last.id;
  }

  test('writeBackup and restoreIfNeeded round-trip data', () async {
    final vehicleId = await seedVehicle();
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
    await seedVehicle(make: 'Honda', model: 'Civic', color: 'Red', year: 2019, trim: '');
    await LocalRepository.persistNow();

    final restored = await BackupService.restoreIfNeeded();
    expect(restored, isFalse);
    expect(LocalRepository.allVehicles().length, 1);
  });

  test('snapshot includes vehicles, fill-ups, settings, and scope', () async {
    final id = await seedVehicle(
      color: 'Black',
      year: 2021,
      make: 'Ford',
      model: 'F-150',
      trim: 'XLT',
    );
    await LocalRepository.addFillUp(
      vehicleId: id,
      odometer: 5000,
      fuelVolume: 20,
      pricePaid: 70,
      date: DateTime(2024, 1, 1),
      unitSystem: 'imperial',
      isFullTank: false,
    );
    await Preferences.setUnitSystem('metric');

    final snap = BackupService.snapshot();
    expect(snap['version'], BackupService.schemaVersion);
    expect(snap['scope'], 'fleet');
    expect(snap['settings'], containsPair('unitSystem', 'metric'));
    expect((snap['vehicles'] as List).length, 1);
    expect((snap['fillUps'] as List).length, 1);
    expect((snap['fillUps'] as List).first['isFullTank'], isFalse);

    final single = BackupService.snapshot(vehicleId: id);
    expect(single['scope'], 'vehicle');
    expect((single['vehicles'] as List).length, 1);
    expect((single['vehicles'] as List).first['id'], id);
  });

  test('decode round-trips serialize and rejects bad version', () async {
    final id = await seedVehicle();
    await LocalRepository.addFillUp(
      vehicleId: id,
      odometer: 1,
      fuelVolume: 1,
      pricePaid: 1,
      date: DateTime(2024, 1, 1),
      unitSystem: 'imperial',
    );

    final json = BackupService.encodePretty(BackupService.snapshot());
    final payload = BackupService.decode(json);
    expect(payload.version, 1);
    expect(payload.scope, BackupScope.fleet);
    expect(payload.vehicles.length, 1);
    expect(payload.fillUps.length, 1);

    expect(
      () => BackupService.decode('{"version":99,"vehicles":[],"fillUps":[]}'),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => BackupService.decode('[]'),
      throwsA(isA<FormatException>()),
    );
  });

  test('importReplaceAll clears existing fleet', () async {
    final keepOutId = await seedVehicle(make: 'Old', model: 'Car');
    await LocalRepository.addFillUp(
      vehicleId: keepOutId,
      odometer: 100,
      fuelVolume: 5,
      pricePaid: 20,
      date: DateTime(2023, 1, 1),
      unitSystem: 'imperial',
    );

    const incoming = '''
{
  "version": 1,
  "scope": "fleet",
  "settings": { "unitSystem": "metric" },
  "vehicles": [
    {
      "id": "v-new",
      "color": "Silver",
      "year": 2022,
      "make": "Mazda",
      "model": "3",
      "trim": "",
      "photoPath": null
    }
  ],
  "fillUps": [
    {
      "id": "f-new",
      "vehicleId": "v-new",
      "odometer": 200,
      "fuelVolume": 10,
      "pricePaid": 35,
      "date": "2024-05-01T00:00:00.000",
      "unitSystem": "metric",
      "isFullTank": true
    }
  ]
}
''';
    final payload = BackupService.decode(incoming);
    await BackupService.importReplaceAll(payload);

    expect(LocalRepository.allVehicles().length, 1);
    expect(LocalRepository.allVehicles().first.id, 'v-new');
    expect(LocalRepository.allVehicles().first.make, 'Mazda');
    expect(LocalRepository.fillupBox.length, 1);
    expect(LocalRepository.fillUpsFor(keepOutId), isEmpty);
    expect(Preferences.unitSystem, 'metric');
  });

  test('importReplaceVehicle replaces one vehicle and leaves others', () async {
    final otherId = await seedVehicle(make: 'Keep', model: 'Me', year: 2018);
    await LocalRepository.addFillUp(
      vehicleId: otherId,
      odometer: 50,
      fuelVolume: 2,
      pricePaid: 8,
      date: DateTime(2023, 2, 1),
      unitSystem: 'imperial',
    );

    await LocalRepository.vehicleBox.put(
      'v-target',
      Vehicle(
        id: 'v-target',
        color: 'Red',
        year: 2015,
        make: 'Replace',
        model: 'Me',
        trim: '',
      ),
    );
    await LocalRepository.fillupBox.put(
      'f-old',
      FillUp(
        id: 'f-old',
        vehicleId: 'v-target',
        odometer: 10,
        fuelVolume: 1,
        pricePaid: 4,
        date: DateTime(2020, 1, 1),
        unitSystem: 'imperial',
      ),
    );

    const incoming = '''
{
  "version": 1,
  "scope": "vehicle",
  "settings": { "unitSystem": "imperial" },
  "vehicles": [
    {
      "id": "v-target",
      "color": "Green",
      "year": 2024,
      "make": "New",
      "model": "Thing",
      "trim": "Sport",
      "photoPath": "vehicle_photos/v-target.jpg"
    }
  ],
  "fillUps": [
    {
      "id": "f-new",
      "vehicleId": "v-target",
      "odometer": 999,
      "fuelVolume": 12,
      "pricePaid": 40,
      "date": "2024-06-01T00:00:00.000",
      "unitSystem": "imperial",
      "isFullTank": false
    }
  ]
}
''';
    await BackupService.importReplaceVehicle(BackupService.decode(incoming));

    expect(LocalRepository.allVehicles().length, 2);
    expect(LocalRepository.vehicleBox.get(otherId)?.make, 'Keep');
    expect(LocalRepository.fillUpsFor(otherId).length, 1);

    final replaced = LocalRepository.vehicleBox.get('v-target')!;
    expect(replaced.make, 'New');
    expect(replaced.year, 2024);
    expect(replaced.photoPath, 'vehicle_photos/v-target.jpg');
    expect(LocalRepository.fillUpsFor('v-target').length, 1);
    expect(LocalRepository.fillUpsFor('v-target').first.odometer, 999);
    expect(LocalRepository.fillupBox.get('f-old'), isNull);
  });

  test('importReplaceVehicle adds when vehicle is missing', () async {
    await seedVehicle(make: 'Other', model: 'Car');

    const incoming = '''
{
  "version": 1,
  "scope": "vehicle",
  "vehicles": [
    {
      "id": "brand-new",
      "color": "White",
      "year": 2021,
      "make": "Added",
      "model": "Car",
      "trim": ""
    }
  ],
  "fillUps": []
}
''';
    await BackupService.importReplaceVehicle(BackupService.decode(incoming));
    expect(LocalRepository.allVehicles().length, 2);
    expect(LocalRepository.vehicleBox.get('brand-new')?.make, 'Added');
  });

  test('legacy auto-backup without scope imports as fleet', () {
    const legacy = '''
{
  "version": 1,
  "exportedAt": "2024-01-01T00:00:00.000",
  "vehicles": [
    {
      "id": "legacy",
      "color": "Blue",
      "year": 2010,
      "make": "Legacy",
      "model": "Auto",
      "trim": ""
    }
  ],
  "fillUps": []
}
''';
    final payload = BackupService.decode(legacy);
    expect(payload.scope, BackupScope.fleet);
  });
}
