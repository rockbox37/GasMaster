import '../models/vehicle.dart';
import 'stats.dart';

/// Privacy-safe, transport-neutral data for a future community comparison.
///
/// This contains no vehicle ID, fill-up dates, costs, photos, or raw records.
/// Efficiency is normalized to L/100 km so imperial and metric vehicles can be
/// compared without sharing the user's preferred unit system.
class CommunityAggregate {
  static const _litersPerGallon = 3.785411784;
  static const _kilometersPerMile = 1.609344;

  final int year;
  final String make;
  final String model;
  final double averageLPer100Km;
  final int sampleCount;

  const CommunityAggregate({
    required this.year,
    required this.make,
    required this.model,
    required this.averageLPer100Km,
    required this.sampleCount,
  });

  /// Builds a weighted aggregate from computable full-tank intervals.
  ///
  /// Returns null when there are no valid efficiency intervals. The source
  /// [VehicleStats] is already derived from local fill-ups; this method only
  /// converts each computed interval into canonical distance and fuel units.
  static CommunityAggregate? fromStats({
    required Vehicle vehicle,
    required VehicleStats stats,
  }) {
    var distanceKm = 0.0;
    var fuelLiters = 0.0;
    var sampleCount = 0;

    for (final row in stats.rows) {
      final fuelVolume = row.f.fuelVolume;
      if (fuelVolume <= 0) continue;

      final mpg = row.mpg;
      if (mpg != null && mpg > 0) {
        fuelLiters += fuelVolume * _litersPerGallon;
        distanceKm += mpg * fuelVolume * _kilometersPerMile;
        sampleCount++;
        continue;
      }

      final lPer100 = row.lPer100;
      if (lPer100 != null && lPer100 > 0) {
        fuelLiters += fuelVolume;
        distanceKm += (fuelVolume / lPer100) * 100;
        sampleCount++;
      }
    }

    if (sampleCount == 0 || distanceKm <= 0 || fuelLiters <= 0) {
      return null;
    }

    return CommunityAggregate(
      year: vehicle.year,
      make: _normalizeLabel(vehicle.make),
      model: _normalizeLabel(vehicle.model),
      averageLPer100Km: (fuelLiters / distanceKm) * 100,
      sampleCount: sampleCount,
    );
  }

  /// Serializes only the fields approved for future community comparison.
  Map<String, dynamic> toJson() => {
        'year': year,
        'make': make,
        'model': model,
        'averageLPer100Km': averageLPer100Km,
        'sampleCount': sampleCount,
      };

  static String _normalizeLabel(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');
}
