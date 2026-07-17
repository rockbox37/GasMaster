import 'package:hive/hive.dart';
part 'vehicle.g.dart';

@HiveType(typeId: 1)
class Vehicle extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) String color;
  @HiveField(2) int year;
  @HiveField(3) String make;
  @HiveField(4) String model;
  @HiveField(5) String trim;

  Vehicle({
    required this.id,
    required this.color,
    required this.year,
    required this.make,
    required this.model,
    required this.trim,
  });

  String get displayName => '$year $make $model ${trim.isNotEmpty ? "($trim)" : ""}';
}
