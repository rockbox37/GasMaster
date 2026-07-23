import 'package:flutter_test/flutter_test.dart';
import 'package:gasmaster/models/reminder.dart';
import 'package:gasmaster/models/vehicle.dart';

void main() {
  Vehicle vehicle({List<VehicleReminder>? reminders}) => Vehicle(
        id: '1',
        color: '',
        year: 2020,
        make: 'Honda',
        model: 'Civic',
        trim: '',
        reminders: reminders,
      );

  group('defaults & migration', () {
    test('defaults() returns one active, unset reminder per type in order', () {
      final d = VehicleReminder.defaults();
      expect(d.map((r) => r.type), ReminderType.values);
      expect(d.every((r) => r.isActive && r.dueDate == null), isTrue);
    });

    test('a new vehicle gets three default reminders', () {
      final v = vehicle();
      expect(v.reminders, hasLength(3));
      expect(v.reminderFor(ReminderType.emissions).type, ReminderType.emissions);
    });

    test('ensureReminders backfills missing types and keeps existing data', () {
      // Only inspection is provided (as would happen for old/partial data).
      final v = vehicle(reminders: [
        VehicleReminder(
          typeIndex: ReminderType.inspection.index,
          doesNotApply: true,
        ),
      ]);
      expect(v.reminders, hasLength(3));
      expect(v.reminders.map((r) => r.type), ReminderType.values);
      expect(v.reminderFor(ReminderType.inspection).doesNotApply, isTrue);
      expect(v.reminderFor(ReminderType.registration).doesNotApply, isFalse);
    });
  });

  group('stateAt', () {
    final now = DateTime(2026, 1, 1);
    VehicleReminder r({DateTime? due, bool na = false, int remind = 30}) =>
        VehicleReminder(
          typeIndex: 0,
          doesNotApply: na,
          dueDate: due,
          remindDaysPrior: remind,
        );

    test('notApplicable overrides everything', () {
      expect(r(na: true, due: now).stateAt(now), ReminderState.notApplicable);
    });

    test('notSet when active without a due date', () {
      expect(r().stateAt(now), ReminderState.notSet);
    });

    test('scheduled before the remind window opens', () {
      expect(r(due: DateTime(2026, 3, 1)).stateAt(now), ReminderState.scheduled);
    });

    test('dueSoon inside the remind window', () {
      expect(r(due: DateTime(2026, 1, 20)).stateAt(now), ReminderState.dueSoon);
    });

    test('overdue once the due date has passed', () {
      expect(r(due: DateTime(2025, 12, 1)).stateAt(now), ReminderState.overdue);
    });

    test('remind window width is honored (45 vs 30 days)', () {
      final due = DateTime(2026, 2, 10); // 40 days out
      expect(r(due: due, remind: 30).stateAt(now), ReminderState.scheduled);
      expect(r(due: due, remind: 45).stateAt(now), ReminderState.dueSoon);
    });
  });

  group('reminderInstant', () {
    test('null unless active with a due date', () {
      expect(VehicleReminder(typeIndex: 0).reminderInstant(), isNull);
      expect(
        VehicleReminder(
          typeIndex: 0,
          doesNotApply: true,
          dueDate: DateTime(2026, 5, 1),
        ).reminderInstant(),
        isNull,
      );
    });

    test('is the anchored due date minus the remind window', () {
      final r = VehicleReminder(
        typeIndex: 0,
        dueDate: DateTime(2026, 5, 1),
        remindDaysPrior: 45,
      );
      expect(
        r.reminderInstant(),
        DateTime(2026, 5, 1, kReminderHour).subtract(const Duration(days: 45)),
      );
    });
  });

  group('addMonths & renewal', () {
    test('adds within the year', () {
      expect(addMonths(DateTime(2026, 1, 15), 6), DateTime(2026, 7, 15));
    });

    test('rolls over the year boundary', () {
      expect(addMonths(DateTime(2026, 10, 10), 4), DateTime(2027, 2, 10));
    });

    test('clamps the day for short target months', () {
      expect(addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
    });

    test('nextDueDateAfterRenewal advances by the renewal period', () {
      final r = VehicleReminder(
        typeIndex: 0,
        dueDate: DateTime(2026, 3, 1),
        renewalPeriodMonths: 24,
      );
      expect(r.nextDueDateAfterRenewal(), DateTime(2028, 3, 1));
    });
  });

  test('labels match the picklist copy', () {
    expect(renewalPeriodLabel(6), '6 months');
    expect(renewalPeriodLabel(12), '1 year');
    expect(renewalPeriodLabel(24), '2 years (biennial)');
    expect(renewalPeriodLabel(36), '3 years');
    expect(renewalPeriodLabel(48), '4 years');
    expect(remindWindowLabel(45), '45 days prior');
    expect(remindWindowLabel(30), '30 days prior');
  });
}
