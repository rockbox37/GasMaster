import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vehicle.dart';
import '../models/fillup.dart';
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
