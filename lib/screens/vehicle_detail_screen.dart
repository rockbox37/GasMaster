import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/vehicle.dart';
import '../services/local_repository.dart';
import '../state/app_state.dart';
import '../utils/backup_ui.dart';
import '../utils/csv_export.dart';
import '../utils/stats.dart';
import '../widgets/gasmaster_brand.dart';
import '../widgets/vehicle_photo_picker.dart';

class VehicleDetailScreen extends ConsumerWidget {
  final String vehicleId;
  const VehicleDetailScreen({super.key, required this.vehicleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(vehiclesProvider);
    Vehicle? v;
    for (final candidate in vehicles) {
      if (candidate.id == vehicleId) {
        v = candidate;
        break;
      }
    }
    v ??= LocalRepository.vehicleBox.get(vehicleId);
    final stats = ref.watch(statsProvider(vehicleId));

    if (v == null) {
      return Scaffold(
        appBar: AppBar(
          title: const GasMasterAppBarTitle(subtitle: 'Vehicle not found'),
          centerTitle: false,
        ),
        body: const Center(child: Text('Vehicle not found')),
      );
    }

    final isMetric = stats.runningAvgLPer100 != null;
    final hasFillUps = stats.rows.isNotEmpty;
    final vehicle = v;

    return Scaffold(
      appBar: AppBar(
        title: GasMasterAppBarTitle(subtitle: vehicle.displayName),
        centerTitle: false,
        titleSpacing: 8,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () => _exportCsv(context, vehicle, stats),
            tooltip: 'Export CSV',
          ),
          if (hasFillUps)
            IconButton(
              icon: const Icon(Icons.ios_share),
              onPressed: () => _shareStats(context, vehicle.displayName, stats, isMetric),
              tooltip: 'Share summary',
            ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (value) {
              if (value == 'export-backup') {
                exportVehicleBackup(context, vehicle);
              } else if (value == 'delete') {
                _deleteVehicle(context, vehicleId);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'export-backup',
                child: Text('Export backup'),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text('Delete vehicle'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/vehicle/$vehicleId/fillup/add'),
        label: const Text('Add Fill-up'),
        icon: const Icon(Icons.local_gas_station),
      ),
      body: hasFillUps
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _VehiclePhotoSection(vehicle: vehicle),
                const SizedBox(height: 16),
                _StatHeader(stats: stats, vehicleName: vehicle.displayName),
                const SizedBox(height: 16),
                _ConsumptionChart(stats: stats),
                const SizedBox(height: 16),
                Text('Fill-ups', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                ...stats.rows.map((r) => _FillUpTile(
                      vehicleId: vehicleId,
                      row: r,
                    )),
                const SizedBox(height: 24),
                Text('Aggregates', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                _AggList(stats: stats, isMetric: isMetric),
              ],
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _VehiclePhotoSection(vehicle: vehicle),
                const SizedBox(height: 24),
                _EmptyFillUps(
                  onAdd: () => context.push('/vehicle/$vehicleId/fillup/add'),
                ),
              ],
            ),
    );
  }

  Future<void> _deleteVehicle(BuildContext context, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete vehicle?'),
        content: const Text('This will remove the vehicle and all fill-ups.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await LocalRepository.deleteVehicle(id);
      if (context.mounted) context.go('/');
    }
  }

  Future<void> _exportCsv(BuildContext context, Vehicle v, VehicleStats stats) async {
    if (stats.rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to export')),
      );
      return;
    }
    final csv = generateFillUpsCsv([(vehicle: v, stats: stats)]);
    await shareCsv(csv, vehicleExportFilename(v));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export ready')),
      );
    }
  }

  Future<void> _shareStats(BuildContext context, String name, VehicleStats s, bool metric) async {
    final avg = metric
        ? '${s.runningAvgLPer100?.toStringAsFixed(2) ?? "-"} L/100km'
        : '${s.runningAvgMpg?.toStringAsFixed(2) ?? "-"} mpg';
    final distUnit = metric ? 'km' : 'mi';
    final fuelUnit = metric ? 'L' : 'gal';

    final msg = StringBuffer()
      ..writeln('GasMaster — $name')
      ..writeln('Average: $avg')
      ..writeln(
        'Totals: ${s.totalMiles.toStringAsFixed(1)} $distUnit, '
        '${s.totalFuel.toStringAsFixed(2)} $fuelUnit, '
        '\$${s.totalCost.toStringAsFixed(2)}',
      );

    if (s.totalMiles > 0) {
      final costPerDist = s.totalCost / s.totalMiles;
      msg.writeln('Cost: \$${costPerDist.toStringAsFixed(3)} per $distUnit');
    }

    await Share.share(msg.toString(), subject: 'GasMaster — $name');
  }
}

class _VehiclePhotoSection extends StatelessWidget {
  final Vehicle vehicle;
  const _VehiclePhotoSection({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    return VehiclePhotoPicker(
      key: ValueKey('photo-${vehicle.id}-${vehicle.photoPath}'),
      existingRelativePath: vehicle.photoPath,
      onOptimized: (result) async {
        await LocalRepository.setVehiclePhoto(
          vehicleId: vehicle.id,
          optimized: result,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Photo saved · ${result.savingsSummary}')),
          );
        }
      },
      onRemoved: () async {
        await LocalRepository.clearVehiclePhoto(vehicle.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo removed')),
          );
        }
      },
    );
  }
}

class _FillUpTile extends StatelessWidget {
  final String vehicleId;
  final FillUpWithComputed row;

  const _FillUpTile({
    required this.vehicleId,
    required this.row,
  });

  @override
  Widget build(BuildContext context) {
    final f = row.f;
    final n = DateFormat.yMMMd().format(f.date);
    final mpg = row.mpg != null ? '${row.mpg!.toStringAsFixed(2)} mpg' : '';
    final l100 = row.lPer100 != null ? '${row.lPer100!.toStringAsFixed(2)} L/100km' : '';
    final efficiency = mpg.isNotEmpty ? mpg : l100.isNotEmpty ? l100 : '';
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey(f.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete fill-up?'),
            content: const Text('This entry will be permanently removed.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
            ],
          ),
        );
        return ok == true;
      },
      onDismissed: (_) {
        LocalRepository.deleteFillUp(f.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fill-up deleted')),
        );
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Theme.of(context).colorScheme.error,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Card(
        child: ListTile(
          title: Row(
            children: [
              Expanded(
                child: Text(
                  '${f.odometer.toStringAsFixed(1)} ${f.unitSystem == 'metric' ? 'km' : 'mi'}  •  '
                  '${f.fuelVolume} ${f.unitSystem == 'metric' ? 'L' : 'gal'}',
                ),
              ),
              if (!f.isFullTank)
                Chip(
                  label: const Text('Partial'),
                  visualDensity: VisualDensity.compact,
                  labelStyle: theme.textTheme.labelSmall,
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
          subtitle: Text(
            '$n  •  \$${f.pricePaid.toStringAsFixed(2)}${efficiency.isNotEmpty ? "  •  $efficiency" : ""}',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/vehicle/$vehicleId/fillup/${f.id}/edit'),
        ),
      ),
    );
  }
}

class _EmptyFillUps extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyFillUps({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_gas_station_outlined,
              size: 72, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
          const SizedBox(height: 24),
          Text('No fill-ups yet', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Log your first fill-up to start tracking fuel economy.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.local_gas_station),
            label: const Text('Add Fill-up'),
          ),
        ],
      ),
    );
  }
}

class _StatHeader extends StatelessWidget {
  final VehicleStats stats;
  final String vehicleName;
  const _StatHeader({required this.stats, required this.vehicleName});

  @override
  Widget build(BuildContext context) {
    final isMetric = stats.runningAvgLPer100 != null;
    final distUnit = isMetric ? 'km' : 'mi';
    final costPerDist = stats.totalMiles > 0 ? stats.totalCost / stats.totalMiles : null;
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Summary', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              vehicleName,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              softWrap: true,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _StatTile(
                  label: 'Running avg',
                  value: isMetric
                      ? '${stats.runningAvgLPer100?.toStringAsFixed(1) ?? "—"} L/100km'
                      : '${stats.runningAvgMpg?.toStringAsFixed(1) ?? "—"} mpg',
                  icon: Icons.speed,
                ),
                _StatTile(
                  label: 'Total distance',
                  value: '${stats.totalMiles.toStringAsFixed(0)} $distUnit',
                  icon: Icons.route,
                ),
                _StatTile(
                  label: 'Total fuel',
                  value: '${stats.totalFuel.toStringAsFixed(1)} ${isMetric ? "L" : "gal"}',
                  icon: Icons.local_gas_station,
                ),
                _StatTile(
                  label: 'Total cost',
                  value: '\$${stats.totalCost.toStringAsFixed(2)}',
                  icon: Icons.payments_outlined,
                ),
                if (costPerDist != null)
                  _StatTile(
                    label: 'Cost per $distUnit',
                    value: '\$${costPerDist.toStringAsFixed(3)}',
                    icon: Icons.attach_money,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatTile({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(height: 4),
          Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ConsumptionChart extends StatelessWidget {
  final VehicleStats stats;
  const _ConsumptionChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    final isMetric = stats.runningAvgLPer100 != null;
    final points = <FlSpot>[];
    final dates = <DateTime>[];
    for (var i = 0; i < stats.rows.length; i++) {
      final r = stats.rows[i];
      final y = isMetric ? r.lPer100 : r.mpg;
      if (y != null && y > 0) {
        points.add(FlSpot(points.length.toDouble(), y));
        dates.add(r.f.date);
      }
    }
    if (points.isEmpty) return const SizedBox();

    final yLabel = isMetric ? 'L/100km' : 'mpg';
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Efficiency over time', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: 1,
                        getTitlesWidget: (v, m) {
                          final i = v.toInt();
                          if (i < 0 || i >= dates.length) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              DateFormat('M/d').format(dates[i]),
                              style: theme.textTheme.labelSmall,
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (v, m) => Text(
                          v.toInt().toString(),
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                    ),
                  ),
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
                      barWidth: 3,
                      color: theme.colorScheme.primary,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      ),
                      spots: points,
                    ),
                  ],
                ),
              ),
            ),
            Text(yLabel, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _AggList extends StatelessWidget {
  final VehicleStats stats;
  final bool isMetric;
  const _AggList({required this.stats, required this.isMetric});

  @override
  Widget build(BuildContext context) {
    final monthKeys = stats.byMonth.keys.toList()..sort();
    final yearKeys = stats.byYear.keys.toList()..sort();
    final distLabel = isMetric ? 'km' : 'mi';

    Widget row(String label, double miles, double fuel, double cost) => ListTile(
          title: Text(label),
          subtitle: Text(
            'Distance: ${miles.toStringAsFixed(1)} $distLabel  •  '
            'Fuel: ${fuel.toStringAsFixed(2)}  •  Cost: \$${cost.toStringAsFixed(2)}',
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('By Month', style: Theme.of(context).textTheme.titleMedium),
        ...monthKeys.map((k) {
          final a = stats.byMonth[k]!;
          return Card(child: row(k, a.miles, a.fuel, a.cost));
        }),
        const SizedBox(height: 12),
        Text('By Year', style: Theme.of(context).textTheme.titleMedium),
        ...yearKeys.map((k) {
          final a = stats.byYear[k]!;
          return Card(child: row(k, a.miles, a.fuel, a.cost));
        }),
      ],
    );
  }
}
