import 'package:flutter_test/flutter_test.dart';
import 'package:gasmaster/models/fillup.dart';
import 'package:gasmaster/models/vehicle.dart';
import 'package:gasmaster/utils/community_aggregate.dart';
import 'package:gasmaster/utils/stats.dart';

Vehicle _vehicle({
  int year = 2020,
  String make = ' Honda ',
  String model = '  Civic  ',
}) =>
    Vehicle(
      id: 'private-vehicle-id',
      color: 'Red',
      year: year,
      make: make,
      model: model,
      trim: 'Private Trim',
    );

FillUp _fill({
  required String id,
  required double odometer,
  required double fuelVolume,
  required String unitSystem,
  DateTime? date,
}) =>
    FillUp(
      id: id,
      vehicleId: 'private-vehicle-id',
      odometer: odometer,
      fuelVolume: fuelVolume,
      pricePaid: 42.50,
      date: date ?? DateTime(2024, 6, 1),
      unitSystem: unitSystem,
    );

void main() {
  test('normalizes imperial efficiency to weighted L/100 km', () {
    final vehicle = _vehicle();
    final stats = VehicleStats.fromFillUps([
      _fill(
        id: 'private-fill-1',
        odometer: 10000,
        fuelVolume: 10,
        unitSystem: 'imperial',
        date: DateTime(2024, 6, 1),
      ),
      _fill(
        id: 'private-fill-2',
        odometer: 10300,
        fuelVolume: 10,
        unitSystem: 'imperial',
        date: DateTime(2024, 6, 15),
      ),
    ]);

    final aggregate = CommunityAggregate.fromStats(
      vehicle: vehicle,
      stats: stats,
    )!;

    expect(aggregate.year, 2020);
    expect(aggregate.make, 'honda');
    expect(aggregate.model, 'civic');
    expect(aggregate.sampleCount, 1);
    expect(aggregate.averageLPer100Km, closeTo(7.840486, 0.0001));

    final alternateCasing = CommunityAggregate.fromStats(
      vehicle: _vehicle(make: 'HONDA', model: 'CIVIC'),
      stats: stats,
    )!;
    expect(alternateCasing.make, aggregate.make);
    expect(alternateCasing.model, aggregate.model);
  });

  test('keeps metric efficiency in canonical units', () {
    final stats = VehicleStats.fromFillUps([
      _fill(
        id: 'fill-1',
        odometer: 10000,
        fuelVolume: 40,
        unitSystem: 'metric',
        date: DateTime(2024, 6, 1),
      ),
      _fill(
        id: 'fill-2',
        odometer: 10500,
        fuelVolume: 40,
        unitSystem: 'metric',
        date: DateTime(2024, 6, 15),
      ),
    ]);

    final aggregate = CommunityAggregate.fromStats(
      vehicle: _vehicle(make: 'Toyota', model: 'Camry'),
      stats: stats,
    )!;

    expect(aggregate.averageLPer100Km, closeTo(8, 0.001));
    expect(aggregate.sampleCount, 1);
  });

  test('returns null when no interval is computable', () {
    final stats = VehicleStats.fromFillUps([
      _fill(
        id: 'only-fill',
        odometer: 10000,
        fuelVolume: 40,
        unitSystem: 'metric',
      ),
    ]);

    expect(
      CommunityAggregate.fromStats(vehicle: _vehicle(), stats: stats),
      isNull,
    );
  });

  test('serializes only approved aggregate fields', () {
    const aggregate = CommunityAggregate(
      year: 2020,
      make: 'Honda',
      model: 'Civic',
      averageLPer100Km: 8.25,
      sampleCount: 4,
    );

    final payload = aggregate.toJson();

    expect(
      payload,
      {
        'year': 2020,
        'make': 'Honda',
        'model': 'Civic',
        'averageLPer100Km': 8.25,
        'sampleCount': 4,
      },
    );
    expect(payload.keys, isNot(contains('id')));
    expect(payload.keys, isNot(contains('date')));
    expect(payload.keys, isNot(contains('pricePaid')));
    expect(payload.keys, isNot(contains('photoPath')));
  });
}
