import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gasmaster/models/fillup.dart';
import 'package:gasmaster/models/vehicle.dart';
import 'package:gasmaster/screens/garage_screen.dart';
import 'package:gasmaster/services/backup_service.dart';
import 'package:gasmaster/services/local_repository.dart';
import 'package:gasmaster/services/preferences.dart';
import 'package:gasmaster/state/app_state.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('gasmaster_test_');
    BackupService.documentsOverride = Directory('${tempDir.path}/docs')..createSync();
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(VehicleAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(FillUpAdapter());
    await LocalRepository.bootstrap();
    await Preferences.init();
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

  testWidgets('shows empty garage state', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: GarageScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('No vehicles yet'), findsOneWidget);
    expect(find.text('Add Vehicle'), findsOneWidget);
  });

  test('vehiclesProvider reflects hive changes', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(vehiclesProvider), isEmpty);

    await LocalRepository.addVehicle(
      color: 'Red',
      year: 2019,
      make: 'Honda',
      model: 'Civic',
      trim: '',
    );
    await Future<void>.delayed(Duration.zero);

    expect(container.read(vehiclesProvider).length, 1);
    expect(container.read(vehiclesProvider).first.make, 'Honda');
  });
}
