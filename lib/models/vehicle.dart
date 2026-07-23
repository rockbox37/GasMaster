import 'package:hive/hive.dart';
import 'reminder.dart';
part 'vehicle.g.dart';

@HiveType(typeId: 1)
class Vehicle extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) String color;
  @HiveField(2) int year;
  @HiveField(3) String make;
  @HiveField(4) String model;
  @HiveField(5) String trim;
  /// Relative path under app documents, e.g. `vehicle_photos/{id}.jpg`.
  @HiveField(6) String? photoPath;
  /// One [VehicleReminder] per [ReminderType]; see [ensureReminders].
  @HiveField(7) List<VehicleReminder> reminders;

  Vehicle({
    required this.id,
    required this.color,
    required this.year,
    required this.make,
    required this.model,
    required this.trim,
    this.photoPath,
    List<VehicleReminder>? reminders,
  }) : reminders = reminders ?? VehicleReminder.defaults() {
    ensureReminders();
  }

  String get displayName {
    final base = '$year $make $model';
    return trim.isNotEmpty ? '$base ($trim)' : base;
  }

  /// Guarantees exactly one reminder per [ReminderType], in enum order.
  /// Backfills any missing types for vehicles stored before reminders existed.
  void ensureReminders() {
    final byType = {for (final r in reminders) r.type: r};
    reminders = [
      for (final t in ReminderType.values)
        byType[t] ?? VehicleReminder(typeIndex: t.index),
    ];
  }

  VehicleReminder reminderFor(ReminderType type) {
    ensureReminders();
    return reminders.firstWhere((r) => r.type == type);
  }
}
