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

void main() {
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('gasmaster_garage_menu_');
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

  testWidgets('empty garage More menu offers Import backup', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: GarageScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('More'));
    await tester.pump();

    expect(find.text('Import backup'), findsOneWidget);
    expect(find.text('Export backup'), findsNothing);
    expect(find.text('Fuel-Saving Tips'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
  });
}
