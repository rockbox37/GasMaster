import 'package:flutter_test/flutter_test.dart';
import 'package:gasmaster/models/fillup.dart';
import 'package:gasmaster/models/vehicle.dart';
import 'package:gasmaster/utils/csv_export.dart';
import 'package:gasmaster/utils/stats.dart';

Vehicle _vehicle({
  String id = 'veh-1',
  String make = 'Honda',
  String model = 'Civic',
}) =>
    Vehicle(
      id: id,
      color: 'Red',
      year: 2020,
      make: make,
      model: model,
      trim: '',
    );

FillUp _fill({
  required String id,
  required double odometer,
  required double fuelVolume,
  DateTime? date,
  bool isFullTank = true,
  String unitSystem = 'imperial',
}) =>
    FillUp(
      id: id,
      vehicleId: 'veh-1',
      odometer: odometer,
      fuelVolume: fuelVolume,
      pricePaid: 42.50,
      date: date ?? DateTime(2024, 6, 15),
      unitSystem: unitSystem,
      isFullTank: isFullTank,
    );

void main() {
  group('escapeCsvField', () {
    test('leaves plain text unchanged', () {
      expect(escapeCsvField('Honda Civic'), 'Honda Civic');
    });

    test('quotes fields with commas', () {
      expect(escapeCsvField('Honda, Civic'), '"Honda, Civic"');
    });

    test('escapes embedded double quotes', () {
      expect(escapeCsvField('Say "hello"'), '"Say ""hello"""');
    });
  });

  group('generateFillUpsCsv', () {
    test('includes header row', () {
      final csv = generateFillUpsCsv([]);
      expect(
        csv.trim(),
        'vehicle_id,vehicle_name,date,odometer,fuel_volume,price_paid,unit_system,is_full_tank,mpg,l_per_100km',
      );
    });

    test('exports fill-up rows with computed mpg', () {
      final v = _vehicle();
      final fills = [
        _fill(id: '1', odometer: 10000, fuelVolume: 10, date: DateTime(2024, 6, 1)),
        _fill(id: '2', odometer: 10300, fuelVolume: 10, date: DateTime(2024, 6, 15)),
      ];
      final stats = VehicleStats.fromFillUps(fills);
      final csv = generateFillUpsCsv([(vehicle: v, stats: stats)]);
      final lines = csv.trim().split('\n');

      expect(lines.length, 3);
      expect(lines[1], 'veh-1,2020 Honda Civic ,2024-06-01,10000.0,10.0,42.5,imperial,true,,');
      expect(lines[2], 'veh-1,2020 Honda Civic ,2024-06-15,10300.0,10.0,42.5,imperial,true,30.00,');
    });

    test('escapes commas and quotes in vehicle names', () {
      final v = _vehicle(make: 'Ford, Inc.', model: 'F-150 "Raptor"');
      final fills = [_fill(id: '1', odometer: 5000, fuelVolume: 20)];
      final stats = VehicleStats.fromFillUps(fills);
      final csv = generateFillUpsCsv([(vehicle: v, stats: stats)]);
      final lines = csv.trim().split('\n');

      expect(
        lines[1],
        'veh-1,"2020 Ford, Inc. F-150 ""Raptor"" ",2024-06-15,5000.0,20.0,42.5,imperial,true,,',
      );
    });

    test('exports metric L/100km when available', () {
      final v = _vehicle();
      final fills = [
        _fill(
          id: '1',
          odometer: 10000,
          fuelVolume: 40,
          date: DateTime(2024, 6, 1),
          unitSystem: 'metric',
        ),
        _fill(
          id: '2',
          odometer: 10500,
          fuelVolume: 40,
          date: DateTime(2024, 6, 15),
          unitSystem: 'metric',
        ),
      ];
      final stats = VehicleStats.fromFillUps(fills);
      final csv = generateFillUpsCsv([(vehicle: v, stats: stats)]);
      final lines = csv.trim().split('\n');

      expect(lines[2], endsWith(',,8.00'));
    });

    test('combines multiple vehicles for fleet export', () {
      final v1 = _vehicle(id: 'v1', make: 'Honda', model: 'Civic');
      final v2 = _vehicle(id: 'v2', make: 'Toyota', model: 'Camry');
      final stats1 = VehicleStats.fromFillUps([
        _fill(id: '1', odometer: 1000, fuelVolume: 10),
      ]);
      final stats2 = VehicleStats.fromFillUps([
        _fill(id: '2', odometer: 2000, fuelVolume: 12),
      ]);
      final csv = generateFillUpsCsv([
        (vehicle: v1, stats: stats1),
        (vehicle: v2, stats: stats2),
      ]);
      final lines = csv.trim().split('\n');

      expect(lines.length, 3);
      expect(lines[1], contains('v1,'));
      expect(lines[2], contains('v2,'));
    });
  });

  group('export filenames', () {
    test('vehicle filename includes slugged name', () {
      final name = vehicleExportFilename(_vehicle(make: 'Honda', model: 'Civic'));
      expect(name, startsWith('gasmaster_2020_honda_civic_'));
      expect(name, endsWith('.csv'));
    });

    test('fleet filename uses all_vehicles prefix', () {
      final name = fleetExportFilename();
      expect(name, startsWith('gasmaster_all_vehicles_'));
      expect(name, endsWith('.csv'));
    });
  });
}
