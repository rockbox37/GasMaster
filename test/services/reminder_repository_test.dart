import 'dart:io';

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

void main() {
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'unit_system': 'imperial'});
    await Preferences.init();

    tempDir = await Directory.systemTemp.createTemp('gasmaster_reminders_');
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

  Future<String> addVehicle() => LocalRepository.addVehicle(
        color: 'Red',
        year: 2020,
        make: 'Honda',
        model: 'Civic',
        trim: '',
      );

  Vehicle stored(String id) => LocalRepository.vehicleBox.get(id)!;

  test('a new vehicle persists three default reminders', () async {
    final id = await addVehicle();
    final v = stored(id);
    expect(v.reminders, hasLength(3));
    expect(v.reminders.every((r) => r.isActive && r.dueDate == null), isTrue);
  });

  test('updateReminder mutates, clears, and toggles fields', () async {
    final id = await addVehicle();
    final due = DateTime(2026, 9, 1, kReminderHour);

    await LocalRepository.updateReminder(
      vehicleId: id,
      type: ReminderType.registration,
      dueDate: due,
      renewalPeriodMonths: 24,
      remindDaysPrior: 45,
    );
    var r = stored(id).reminderFor(ReminderType.registration);
    expect(r.dueDate, due);
    expect(r.renewalPeriodMonths, 24);
    expect(r.remindDaysPrior, 45);

    await LocalRepository.updateReminder(
      vehicleId: id,
      type: ReminderType.registration,
      doesNotApply: true,
    );
    expect(stored(id).reminderFor(ReminderType.registration).doesNotApply,
        isTrue);
    // Toggling "does not apply" must not wipe the configured due date.
    expect(stored(id).reminderFor(ReminderType.registration).dueDate, due);

    await LocalRepository.updateReminder(
      vehicleId: id,
      type: ReminderType.registration,
      clearDueDate: true,
    );
    r = stored(id).reminderFor(ReminderType.registration);
    expect(r.dueDate, isNull);
    // Other reminders remain untouched.
    expect(stored(id).reminderFor(ReminderType.emissions).dueDate, isNull);
    expect(
        stored(id).reminderFor(ReminderType.emissions).doesNotApply, isFalse);
  });

  test('renewReminder advances the due date by the renewal period', () async {
    final id = await addVehicle();
    await LocalRepository.updateReminder(
      vehicleId: id,
      type: ReminderType.inspection,
      dueDate: DateTime(2026, 1, 15, kReminderHour),
      renewalPeriodMonths: 12,
    );
    await LocalRepository.renewReminder(
      vehicleId: id,
      type: ReminderType.inspection,
    );
    expect(
      stored(id).reminderFor(ReminderType.inspection).dueDate,
      DateTime(2027, 1, 15, kReminderHour),
    );
  });

  test('backup round-trip preserves reminder configuration', () async {
    final id = await addVehicle();
    await LocalRepository.updateReminder(
      vehicleId: id,
      type: ReminderType.emissions,
      dueDate: DateTime(2026, 5, 20, kReminderHour),
      remindDaysPrior: 45,
      renewalPeriodMonths: 24,
    );
    await LocalRepository.updateReminder(
      vehicleId: id,
      type: ReminderType.inspection,
      doesNotApply: true,
    );

    final json = BackupService.encodePretty(BackupService.snapshot());
    final payload = BackupService.decode(json);
    await BackupService.importReplaceAll(payload);

    final v = stored(id);
    final emissions = v.reminderFor(ReminderType.emissions);
    expect(emissions.dueDate, DateTime(2026, 5, 20, kReminderHour));
    expect(emissions.remindDaysPrior, 45);
    expect(emissions.renewalPeriodMonths, 24);
    expect(v.reminderFor(ReminderType.inspection).doesNotApply, isTrue);
    expect(v.reminderFor(ReminderType.registration).dueDate, isNull);
  });

  test('backups without a reminders field migrate to defaults', () async {
    const oldJson =
        '{"version":1,"scope":"fleet","vehicles":[{"id":"v1","color":"Blue",'
        '"year":2019,"make":"Toyota","model":"Corolla","trim":""}],"fillUps":[]}';
    final payload = BackupService.decode(oldJson);
    await BackupService.importReplaceAll(payload);

    final v = stored('v1');
    expect(v.reminders, hasLength(3));
    expect(v.reminders.every((r) => r.isActive && r.dueDate == null), isTrue);
  });
}
