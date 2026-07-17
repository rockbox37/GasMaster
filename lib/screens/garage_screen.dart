import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/vehicle.dart';
import '../services/local_repository.dart';
import '../state/app_state.dart';
import '../utils/csv_export.dart';
import '../utils/stats.dart';
import '../utils/vehicle_color.dart';

class GarageScreen extends ConsumerWidget {
  const GarageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(vehiclesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('GasMaster'),
        centerTitle: false,
        actions: [
          if (vehicles.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.file_download_outlined),
              onPressed: () => _exportFleet(context),
              tooltip: 'Export all vehicles',
            ),
        ],
      ),
      floatingActionButton: vehicles.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push('/vehicle/add'),
              label: const Text('Add Vehicle'),
              icon: const Icon(Icons.add),
            ),
      body: vehicles.isEmpty
          ? _EmptyGarage(onAdd: () => context.push('/vehicle/add'))
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: vehicles.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
              itemBuilder: (_, i) {
                final v = vehicles[i];
                final stats = LocalRepository.vehicleStats(v.id);
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: parseVehicleColor(v.color),
                    child: const Icon(Icons.directions_car, color: Colors.white, size: 20),
                  ),
                  title: Text(v.displayName, style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(_vehicleSubtitle(stats)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/vehicle/${v.id}'),
                );
              },
            ),
    );
  }

  Future<void> _exportFleet(BuildContext context) async {
    final entries = <({Vehicle vehicle, VehicleStats stats})>[];
    for (final v in LocalRepository.allVehicles()) {
      final stats = LocalRepository.vehicleStats(v.id);
      if (stats.rows.isNotEmpty) {
        entries.add((vehicle: v, stats: stats));
      }
    }
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to export')),
      );
      return;
    }
    final csv = generateFillUpsCsv(entries);
    await shareCsv(csv, fleetExportFilename());
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export ready')),
      );
    }
  }

  String _vehicleSubtitle(VehicleStats stats) {
    if (stats.rows.isEmpty) return 'No fill-ups yet';
    final count = stats.rows.length;
    final countLabel = '$count fill-up${count == 1 ? '' : 's'}';
    if (stats.runningAvgMpg != null) {
      return '${stats.runningAvgMpg!.toStringAsFixed(1)} mpg avg · $countLabel';
    }
    if (stats.runningAvgLPer100 != null) {
      return '${stats.runningAvgLPer100!.toStringAsFixed(1)} L/100km avg · $countLabel';
    }
    return countLabel;
  }
}

class _EmptyGarage extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyGarage({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.garage_outlined, size: 72, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 24),
            Text('No vehicles yet', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Add your first vehicle to start tracking fuel economy.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add Vehicle'),
            ),
          ],
        ),
      ),
    );
  }
}
