import 'package:intl/intl.dart';
import '../models/fillup.dart';

class FillUpWithComputed {
  final FillUp f;
  final double? mpg;     // null when interval not computable
  final double? lPer100; // computed if metric
  FillUpWithComputed(this.f, {this.mpg, this.lPer100});
}

class VehicleStats {
  final List<FillUpWithComputed> rows;
  final double? runningAvgMpg;
  final double? runningAvgLPer100;
  final double totalMiles;
  final double totalFuel;
  final double totalCost;
  final Map<String, MonthAggregate> byMonth; // yyyy-MM
  final Map<String, YearAggregate> byYear;   // yyyy

  VehicleStats({
    required this.rows,
    required this.runningAvgMpg,
    required this.runningAvgLPer100,
    required this.totalMiles,
    required this.totalFuel,
    required this.totalCost,
    required this.byMonth,
    required this.byYear,
  });

  factory VehicleStats.fromFillUps(List<FillUp> fs) {
    if (fs.isEmpty) {
      return VehicleStats(
        rows: [], runningAvgMpg: null, runningAvgLPer100: null,
        totalMiles: 0, totalFuel: 0, totalCost: 0,
        byMonth: {}, byYear: {}
      );
    }
    final sorted = [...fs]..sort((a,b)=> a.date.compareTo(b.date));

    final rows = <FillUpWithComputed>[];
    double totalMiles = 0, totalFuel = 0, totalCost = 0;
    double efficiencyDist = 0, efficiencyFuel = 0;

    for (int i=0; i<sorted.length; i++) {
      final curr = sorted[i];
      totalFuel += curr.fuelVolume;
      totalCost += curr.pricePaid;

      if (i == 0) {
        rows.add(FillUpWithComputed(curr));
        continue;
      }
      final prev = sorted[i-1];
      final double milesDelta = (curr.odometer - prev.odometer)
          .clamp(0, double.infinity)
          .toDouble();
      totalMiles += milesDelta;

      final computable = milesDelta > 0
          && curr.fuelVolume > 0
          && prev.isFullTank
          && curr.isFullTank;

      if (computable) {
        efficiencyDist += milesDelta;
        efficiencyFuel += curr.fuelVolume;
      }

      if (curr.unitSystem == 'imperial') {
        final double? mpg = computable ? (milesDelta / curr.fuelVolume) : null;
        rows.add(FillUpWithComputed(curr, mpg: mpg));
      } else {
        final double? l100 = computable
            ? (curr.fuelVolume / milesDelta) * 100.0
            : null;
        rows.add(FillUpWithComputed(curr, lPer100: l100));
      }
    }

    final byMonth = <String, MonthAggregate>{};
    final byYear = <String, YearAggregate>{};
    for (int i=1; i<sorted.length; i++) {
      final curr = sorted[i];
      final prev = sorted[i-1];
      final dist = (curr.odometer - prev.odometer).clamp(0, double.infinity);
      final computable = dist > 0
          && curr.fuelVolume > 0
          && prev.isFullTank
          && curr.isFullTank;

      final ym = DateFormat('yyyy-MM').format(curr.date);
      final y = DateFormat('yyyy').format(curr.date);
      byMonth.putIfAbsent(ym, ()=> MonthAggregate()).accumulate(
        computable ? dist.toDouble() : 0,
        curr.fuelVolume,
        curr.pricePaid,
      );
      byYear.putIfAbsent(y, ()=> YearAggregate()).accumulate(
        computable ? dist.toDouble() : 0,
        curr.fuelVolume,
        curr.pricePaid,
      );
    }

    final isMetric = sorted.last.unitSystem == 'metric';
    double? runningAvgMpg;
    double? runningAvgLPer100;
    if (efficiencyDist > 0 && efficiencyFuel > 0) {
      if (isMetric) {
        runningAvgLPer100 = (efficiencyFuel / efficiencyDist) * 100.0;
      } else {
        runningAvgMpg = efficiencyDist / efficiencyFuel;
      }
    }

    return VehicleStats(
      rows: rows,
      runningAvgMpg: runningAvgMpg,
      runningAvgLPer100: runningAvgLPer100,
      totalMiles: totalMiles,
      totalFuel: totalFuel,
      totalCost: totalCost,
      byMonth: byMonth,
      byYear: byYear,
    );
  }
}

class MonthAggregate {
  double miles = 0;
  double fuel = 0;
  double cost = 0;
  void accumulate(double m, double f, double c) { miles += m; fuel += f; cost += c; }
}
class YearAggregate extends MonthAggregate {}
