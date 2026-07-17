import 'package:flutter_test/flutter_test.dart';
import 'package:gasmaster/models/fillup.dart';
import 'package:gasmaster/utils/stats.dart';

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
      vehicleId: 'v1',
      odometer: odometer,
      fuelVolume: fuelVolume,
      pricePaid: 30,
      date: date ?? DateTime(2024, 6, 1),
      unitSystem: unitSystem,
      isFullTank: isFullTank,
    );

void main() {
  group('VehicleStats.fromFillUps', () {
    test('empty list returns zeroed stats', () {
      final stats = VehicleStats.fromFillUps([]);
      expect(stats.rows, isEmpty);
      expect(stats.runningAvgMpg, isNull);
      expect(stats.runningAvgLPer100, isNull);
      expect(stats.totalMiles, 0);
      expect(stats.totalFuel, 0);
      expect(stats.totalCost, 0);
      expect(stats.byMonth, isEmpty);
      expect(stats.byYear, isEmpty);
    });

    test('single fill-up has no efficiency computed', () {
      final f = _fill(id: '1', odometer: 10000, fuelVolume: 12);
      final stats = VehicleStats.fromFillUps([f]);
      expect(stats.rows.length, 1);
      expect(stats.rows.first.mpg, isNull);
      expect(stats.totalFuel, 12);
      expect(stats.totalCost, 30);
      expect(stats.totalMiles, 0);
    });

    test('computes imperial mpg between full fill-ups', () {
      final fills = [
        _fill(id: '1', odometer: 10000, fuelVolume: 10, date: DateTime(2024, 6, 1)),
        _fill(id: '2', odometer: 10300, fuelVolume: 10, date: DateTime(2024, 6, 15)),
      ];
      final stats = VehicleStats.fromFillUps(fills);
      expect(stats.rows.length, 2);
      expect(stats.rows[1].mpg, closeTo(30.0, 0.01));
      expect(stats.runningAvgMpg, closeTo(30.0, 0.01));
      expect(stats.totalMiles, closeTo(300.0, 0.01));
      expect(stats.totalFuel, closeTo(20.0, 0.01));
    });

    test('computes metric L/100km between full fill-ups', () {
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
      expect(stats.rows[1].lPer100, closeTo(8.0, 0.01));
      expect(stats.runningAvgLPer100, closeTo(8.0, 0.01));
      expect(stats.totalMiles, closeTo(500.0, 0.01));
    });

    test('skips efficiency when odometer goes backwards', () {
      final fills = [
        _fill(id: '1', odometer: 10000, fuelVolume: 10, date: DateTime(2024, 6, 1)),
        _fill(id: '2', odometer: 9900, fuelVolume: 10, date: DateTime(2024, 6, 15)),
      ];
      final stats = VehicleStats.fromFillUps(fills);
      expect(stats.rows[1].mpg, isNull);
      expect(stats.runningAvgMpg, isNull);
      expect(stats.totalMiles, 0);
    });

    test('partial fill is skipped in efficiency calc but counts fuel/cost', () {
      final fills = [
        _fill(id: '1', odometer: 10000, fuelVolume: 10, date: DateTime(2024, 6, 1)),
        _fill(
          id: '2',
          odometer: 10300,
          fuelVolume: 5,
          date: DateTime(2024, 6, 10),
          isFullTank: false,
        ),
      ];
      final stats = VehicleStats.fromFillUps(fills);
      expect(stats.rows[1].mpg, isNull);
      expect(stats.runningAvgMpg, isNull);
      expect(stats.totalFuel, closeTo(15.0, 0.01));
      expect(stats.totalMiles, closeTo(300.0, 0.01));
    });

    test('weighted average differs from simple average of per-fill values', () {
      final fills = [
        _fill(id: '1', odometer: 10000, fuelVolume: 10, date: DateTime(2024, 6, 1)),
        _fill(id: '2', odometer: 10100, fuelVolume: 5, date: DateTime(2024, 6, 10)),
        _fill(id: '3', odometer: 10300, fuelVolume: 15, date: DateTime(2024, 6, 20)),
      ];
      final stats = VehicleStats.fromFillUps(fills);

      final mpg2 = 100 / 5; // 20 mpg
      final mpg3 = 200 / 15; // ~13.33 mpg
      final simpleAvg = (mpg2 + mpg3) / 2;

      expect(stats.rows[1].mpg, closeTo(mpg2, 0.01));
      expect(stats.rows[2].mpg, closeTo(mpg3, 0.01));
      expect(stats.runningAvgMpg, closeTo(300 / 20, 0.01)); // 15 mpg weighted
      expect(stats.runningAvgMpg, isNot(closeTo(simpleAvg, 0.01)));
    });

    test('mixed full/partial sequence skips non-computable intervals', () {
      final fills = [
        _fill(id: '1', odometer: 10000, fuelVolume: 10, date: DateTime(2024, 6, 1)),
        _fill(
          id: '2',
          odometer: 10100,
          fuelVolume: 5,
          date: DateTime(2024, 6, 10),
          isFullTank: false,
        ),
        _fill(
          id: '3',
          odometer: 10200,
          fuelVolume: 10,
          date: DateTime(2024, 6, 15),
          isFullTank: false,
        ),
        _fill(id: '4', odometer: 10500, fuelVolume: 10, date: DateTime(2024, 6, 25)),
      ];
      final stats = VehicleStats.fromFillUps(fills);

      expect(stats.rows[1].mpg, isNull); // partial
      expect(stats.rows[2].mpg, isNull); // partial after partial
      expect(stats.rows[3].mpg, isNull); // full but prior partial
      expect(stats.runningAvgMpg, isNull);
      expect(stats.totalFuel, closeTo(35.0, 0.01));
      expect(stats.totalMiles, closeTo(500.0, 0.01));
    });

    test('aggregates by month and year with computable distance only', () {
      final fills = [
        _fill(id: '1', odometer: 10000, fuelVolume: 10, date: DateTime(2024, 6, 1)),
        _fill(id: '2', odometer: 10300, fuelVolume: 10, date: DateTime(2024, 6, 15)),
        _fill(
          id: '3',
          odometer: 10400,
          fuelVolume: 5,
          date: DateTime(2024, 6, 20),
          isFullTank: false,
        ),
        _fill(id: '4', odometer: 10600, fuelVolume: 10, date: DateTime(2025, 1, 10)),
      ];
      final stats = VehicleStats.fromFillUps(fills);
      expect(stats.byMonth.containsKey('2024-06'), isTrue);
      expect(stats.byMonth['2024-06']!.miles, closeTo(300, 0.01));
      expect(stats.byMonth['2024-06']!.fuel, closeTo(15, 0.01));
      expect(stats.byYear.containsKey('2024'), isTrue);
      expect(stats.byYear.containsKey('2025'), isTrue);
      expect(stats.byYear['2025']!.miles, 0); // prior partial, no computable dist
    });
  });
}
