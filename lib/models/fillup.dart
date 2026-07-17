import 'package:hive/hive.dart';
part 'fillup.g.dart';

@HiveType(typeId: 2)
class FillUp extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) String vehicleId;
  @HiveField(2) double odometer; // miles or km at fill-up
  @HiveField(3) double fuelVolume; // gallons or liters
  @HiveField(4) double pricePaid; // total currency
  @HiveField(5) DateTime date;
  @HiveField(6) String unitSystem; // 'imperial' or 'metric'
  @HiveField(7) bool isFullTank; // false for partial/top-off fills

  FillUp({
    required this.id,
    required this.vehicleId,
    required this.odometer,
    required this.fuelVolume,
    required this.pricePaid,
    required this.date,
    required this.unitSystem,
    this.isFullTank = true,
  });
}
