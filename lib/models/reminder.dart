import 'dart:math' as math;
import 'package:hive/hive.dart';
part 'reminder.g.dart';

/// The fixed set of reminders available on every vehicle.
enum ReminderType {
  registration,
  inspection,
  emissions,
}

extension ReminderTypeInfo on ReminderType {
  String get label => switch (this) {
        ReminderType.registration => 'Registration renewal',
        ReminderType.inspection => 'Inspection',
        ReminderType.emissions => 'Emissions test',
      };
}

/// Allowed renewal periods, in months. Surfaced as the renewal-period picklist.
const kRenewalPeriodMonths = <int>[6, 12, 24, 36, 48];

/// Allowed "remind me before" windows, in days.
const kRemindDaysPriorChoices = <int>[45, 30];

/// Human label for a renewal period expressed in months.
String renewalPeriodLabel(int months) => switch (months) {
      6 => '6 months',
      12 => '1 year',
      24 => '2 years (biennial)',
      36 => '3 years',
      48 => '4 years',
      _ => '$months months',
    };

/// Human label for a "remind me" window expressed in days.
String remindWindowLabel(int days) => '$days days prior';

/// Hour of day (local) reminders are anchored to, so notifications fire at a
/// sensible time rather than midnight.
const kReminderHour = 9;

/// A single configurable reminder attached to a [ReminderType] on a vehicle.
///
/// Not a `HiveObject` — instances live inside `Vehicle.reminders` and are
/// persisted via [VehicleReminderAdapter] (typeId 3).
@HiveType(typeId: 3)
class VehicleReminder {
  @HiveField(0)
  int typeIndex;

  /// When true the reminder is disabled and greyed out in the UI.
  @HiveField(1)
  bool doesNotApply;

  /// The next deadline. Null until the user sets one.
  @HiveField(2)
  DateTime? dueDate;

  @HiveField(3)
  int renewalPeriodMonths;

  @HiveField(4)
  int remindDaysPrior;

  VehicleReminder({
    required this.typeIndex,
    this.doesNotApply = false,
    this.dueDate,
    this.renewalPeriodMonths = 12,
    this.remindDaysPrior = 30,
  });

  ReminderType get type => ReminderType.values[typeIndex];

  bool get isActive => !doesNotApply;

  /// A reminder actively contributes notifications only when it applies and has
  /// a due date set.
  bool get isScheduled => isActive && dueDate != null;

  VehicleReminder copy() => VehicleReminder(
        typeIndex: typeIndex,
        doesNotApply: doesNotApply,
        dueDate: dueDate,
        renewalPeriodMonths: renewalPeriodMonths,
        remindDaysPrior: remindDaysPrior,
      );

  /// The three default reminders for a new vehicle, in display order.
  static List<VehicleReminder> defaults() => [
        for (final t in ReminderType.values) VehicleReminder(typeIndex: t.index),
      ];
}

/// Lifecycle state of a reminder relative to a point in time. Drives both the
/// in-app banner and the per-card status chip.
enum ReminderState {
  /// "Does not apply" is checked.
  notApplicable,

  /// Applies, but no due date has been set yet.
  notSet,

  /// Due date is in the future and the remind window has not opened.
  scheduled,

  /// Inside the remind window (dueDate − remindDaysPrior ≤ now ≤ dueDate).
  dueSoon,

  /// The due date has passed.
  overdue,
}

extension VehicleReminderSchedule on VehicleReminder {
  /// Normalizes [dueDate] to [kReminderHour] local time.
  DateTime? get anchoredDueDate {
    final d = dueDate;
    if (d == null) return null;
    return DateTime(d.year, d.month, d.day, kReminderHour);
  }

  /// When the OS notification should fire for the current due date, or null if
  /// the reminder is inactive / has no due date.
  DateTime? reminderInstant() {
    if (!isScheduled) return null;
    return anchoredDueDate!.subtract(Duration(days: remindDaysPrior));
  }

  ReminderState stateAt(DateTime now) {
    if (!isActive) return ReminderState.notApplicable;
    final due = anchoredDueDate;
    if (due == null) return ReminderState.notSet;
    if (now.isAfter(due)) return ReminderState.overdue;
    final instant = due.subtract(Duration(days: remindDaysPrior));
    if (!now.isBefore(instant)) return ReminderState.dueSoon;
    return ReminderState.scheduled;
  }

  /// True when this reminder warrants surfacing in the in-app banner.
  bool needsAttentionAt(DateTime now) {
    final s = stateAt(now);
    return s == ReminderState.dueSoon || s == ReminderState.overdue;
  }

  /// The due date advanced by one renewal period, clamping the day-of-month for
  /// short months (used by "Mark renewed").
  DateTime? nextDueDateAfterRenewal() {
    final due = dueDate;
    if (due == null) return null;
    return addMonths(due, renewalPeriodMonths);
  }
}

/// Adds [months] to [d], clamping the day into the target month.
DateTime addMonths(DateTime d, int months) {
  final total = d.month - 1 + months;
  final year = d.year + total ~/ 12;
  final month = total % 12 + 1;
  final day = math.min(d.day, _daysInMonth(year, month));
  return DateTime(year, month, day, d.hour, d.minute);
}

int _daysInMonth(int year, int month) {
  final firstOfNext = month == 12
      ? DateTime(year + 1, 1, 1)
      : DateTime(year, month + 1, 1);
  return firstOfNext.subtract(const Duration(days: 1)).day;
}
