import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/reminder.dart';
import '../state/app_state.dart';

/// In-app notification banner summarizing reminders that are due-soon or
/// overdue across the fleet. Renders nothing when there's nothing to show.
///
/// When [vehicleId] is set, only that vehicle's reminders are surfaced (used on
/// the vehicle detail screen); otherwise the whole fleet (garage screen).
class RemindersBanner extends ConsumerWidget {
  final String? vehicleId;
  const RemindersBanner({super.key, this.vehicleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(dueRemindersProvider);
    final due = vehicleId == null
        ? all
        : all.where((d) => d.vehicle.id == vehicleId).toList();
    if (due.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final hasOverdue = due.any((d) => d.state == ReminderState.overdue);
    final scheme = theme.colorScheme;
    final bg = hasOverdue ? scheme.errorContainer : scheme.tertiaryContainer;
    final fg = hasOverdue ? scheme.onErrorContainer : scheme.onTertiaryContainer;

    return Card(
      color: bg,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasOverdue
                      ? Icons.warning_amber_rounded
                      : Icons.notifications_active_outlined,
                  color: fg,
                ),
                const SizedBox(width: 8),
                Text(
                  due.length == 1
                      ? '1 reminder needs attention'
                      : '${due.length} reminders need attention',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: fg, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 4),
            for (final d in due)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _DueLine(due: d, foreground: fg, showVehicle: vehicleId == null),
              ),
          ],
        ),
      ),
    );
  }
}

class _DueLine extends StatelessWidget {
  final DueReminder due;
  final Color foreground;
  final bool showVehicle;

  const _DueLine({
    required this.due,
    required this.foreground,
    required this.showVehicle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = due.reminder;
    final dateLabel =
        r.dueDate != null ? DateFormat.yMMMd().format(r.dueDate!) : '';
    final verb = due.state == ReminderState.overdue ? 'was due' : 'due';
    final who = showVehicle ? '${due.vehicle.displayName} · ' : '';
    final line = '$who${r.type.label} $verb $dateLabel';

    return InkWell(
      onTap: () => context.push('/vehicle/${due.vehicle.id}'),
      child: Row(
        children: [
          Icon(Icons.chevron_right, size: 16, color: foreground),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              line,
              style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}
