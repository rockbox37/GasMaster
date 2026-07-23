import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vehicle.dart';
import '../models/fillup.dart';
import '../models/reminder.dart';
import '../services/local_repository.dart';
import '../services/preferences.dart';
import '../utils/stats.dart';

final vehiclesProvider =
    NotifierProvider<VehiclesNotifier, List<Vehicle>>(VehiclesNotifier.new);

class VehiclesNotifier extends Notifier<List<Vehicle>> {
  @override
  List<Vehicle> build() {
    void listener() => state = LocalRepository.allVehicles();
    LocalRepository.addVehicleListener(listener);
    ref.onDispose(() => LocalRepository.removeVehicleListener(listener));
    return LocalRepository.allVehicles();
  }
}

class CommunitySharingNotifier extends Notifier<bool> {
  @override
  bool build() => Preferences.communitySharingEnabled;

  Future<void> set(bool enabled) async {
    state = enabled;
    await Preferences.setCommunitySharingEnabled(enabled);
  }
}

final fillUpsProvider = NotifierProvider.family<FillUpsNotifier, List<FillUp>, String>(
  FillUpsNotifier.new,
);

class FillUpsNotifier extends FamilyNotifier<List<FillUp>, String> {
  @override
  List<FillUp> build(String vehicleId) {
    void listener() => state = LocalRepository.fillUpsFor(vehicleId);
    LocalRepository.addFillUpListener(listener);
    ref.onDispose(() => LocalRepository.removeFillUpListener(listener));
    return LocalRepository.fillUpsFor(vehicleId);
  }
}

/// A reminder that currently needs the user's attention (in its remind window
/// or overdue), paired with its owning vehicle.
class DueReminder {
  const DueReminder({
    required this.vehicle,
    required this.reminder,
    required this.state,
  });

  final Vehicle vehicle;
  final VehicleReminder reminder;
  final ReminderState state;
}

/// All reminders across the fleet that are due-soon or overdue right now.
/// Drives the in-app notification banner.
final dueRemindersProvider = Provider<List<DueReminder>>((ref) {
  final vehicles = ref.watch(vehiclesProvider);
  final now = DateTime.now();
  final out = <DueReminder>[];
  for (final v in vehicles) {
    for (final r in v.reminders) {
      final s = r.stateAt(now);
      if (s == ReminderState.dueSoon || s == ReminderState.overdue) {
        out.add(DueReminder(vehicle: v, reminder: r, state: s));
      }
    }
  }
  return out;
});

final statsProvider = Provider.family<VehicleStats, String>((ref, vehicleId) {
  ref.watch(fillUpsProvider(vehicleId));
  return LocalRepository.vehicleStats(vehicleId);
});

final unitSystemProvider =
    NotifierProvider<UnitSystemNotifier, String>(UnitSystemNotifier.new);
final communitySharingProvider =
    NotifierProvider<CommunitySharingNotifier, bool>(
  CommunitySharingNotifier.new,
);

class UnitSystemNotifier extends Notifier<String> {
  @override
  String build() => Preferences.unitSystem;

  Future<void> set(String unit) async {
    state = unit;
    await Preferences.setUnitSystem(unit);
  }
}
