import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/vehicle.dart';
import 'stats.dart';

const _headers = [
  'vehicle_id',
  'vehicle_name',
  'date',
  'odometer',
  'fuel_volume',
  'price_paid',
  'unit_system',
  'is_full_tank',
  'mpg',
  'l_per_100km',
];

/// Escapes a single CSV field per RFC 4180.
String escapeCsvField(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n') || value.contains('\r')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

String formatCsvRow(List<String> fields) => fields.map(escapeCsvField).join(',');

/// Generates CSV text for one or more vehicles and their fill-up rows.
String generateFillUpsCsv(List<({Vehicle vehicle, VehicleStats stats})> entries) {
  final buf = StringBuffer()..writeln(formatCsvRow(_headers));
  final dateFmt = DateFormat('yyyy-MM-dd');

  for (final entry in entries) {
    final v = entry.vehicle;
    for (final row in entry.stats.rows) {
      final f = row.f;
      buf.writeln(formatCsvRow([
        v.id,
        v.displayName,
        dateFmt.format(f.date),
        f.odometer.toString(),
        f.fuelVolume.toString(),
        f.pricePaid.toString(),
        f.unitSystem,
        f.isFullTank.toString(),
        row.mpg?.toStringAsFixed(2) ?? '',
        row.lPer100?.toStringAsFixed(2) ?? '',
      ]));
    }
  }

  return buf.toString();
}

String vehicleExportFilename(Vehicle vehicle) {
  final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final slug = _filenameSlug(vehicle.displayName);
  return 'gasmaster_${slug}_$date.csv';
}

String fleetExportFilename() {
  final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
  return 'gasmaster_all_vehicles_$date.csv';
}

String _filenameSlug(String name) {
  var slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  slug = slug.replaceAll(RegExp(r'_+'), '_');
  return slug.replaceAll(RegExp(r'^_|_$'), '');
}

/// Writes [csv] to a temp file and opens the platform share sheet.
Future<void> shareCsv(String csv, String filename) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsString(csv);
  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'text/csv', name: filename)],
    subject: filename,
  );
}
