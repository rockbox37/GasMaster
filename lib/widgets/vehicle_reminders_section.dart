import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/reminder.dart';
import '../models/vehicle.dart';
import '../services/local_repository.dart';
import '../services/preferences.dart';
import '../services/reminder_notification_service.dart';

/// The "Reminders" section shown on the vehicle detail screen: one card per
/// [ReminderType] with a "does not apply" toggle, due date, renewal period, and
/// remind-before window.
class VehicleRemindersSection extends StatelessWidget {
  final Vehicle vehicle;
  const VehicleRemindersSection({super.key, required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Reminders', style: theme.textTheme.titleLarge),
            const SizedBox(width: 8),
            Icon(Icons.notifications_active_outlined,
                size: 20, color: theme.colorScheme.primary),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Get notified before registration, inspection, and emissions deadlines.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        for (final type in ReminderType.values)
          _ReminderCard(
            vehicleId: vehicle.id,
            reminder: vehicle.reminderFor(type),
          ),
      ],
    );
  }
}

class _ReminderCard extends ConsumerWidget {
  final String vehicleId;
  final VehicleReminder reminder;

  const _ReminderCard({required this.vehicleId, required this.reminder});

  IconData get _icon => switch (reminder.type) {
        ReminderType.registration => Icons.assignment_outlined,
        ReminderType.inspection => Icons.fact_check_outlined,
        ReminderType.emissions => Icons.eco_outlined,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final applies = reminder.isActive;
    final state = reminder.stateAt(DateTime.now());

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_icon,
                    color: applies
                        ? theme.colorScheme.primary
                        : theme.disabledColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    reminder.type.label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: applies ? null : theme.disabledColor,
                    ),
                  ),
                ),
                if (applies) _StatusChip(state: state),
              ],
            ),
            // Always interactive so a disabled reminder can be re-enabled.
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              value: !applies,
              title: const Text('Does not apply'),
              onChanged: (checked) {
                LocalRepository.updateReminder(
                  vehicleId: vehicleId,
                  type: reminder.type,
                  doesNotApply: checked ?? false,
                );
              },
            ),
            // Config controls: greyed out and non-interactive when N/A.
            IgnorePointer(
              ignoring: !applies,
              child: Opacity(
                opacity: applies ? 1 : 0.4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DueDateRow(
                      reminder: reminder,
                      onPick: () => _pickDueDate(context),
                      onClear: reminder.dueDate == null
                          ? null
                          : () => LocalRepository.updateReminder(
                                vehicleId: vehicleId,
                                type: reminder.type,
                                clearDueDate: true,
                              ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _PeriodDropdown(
                            value: reminder.renewalPeriodMonths,
                            onChanged: (m) => LocalRepository.updateReminder(
                              vehicleId: vehicleId,
                              type: reminder.type,
                              renewalPeriodMonths: m,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _RemindDropdown(
                            value: reminder.remindDaysPrior,
                            onChanged: (d) => LocalRepository.updateReminder(
                              vehicleId: vehicleId,
                              type: reminder.type,
                              remindDaysPrior: d,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (state == ReminderState.overdue) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          icon: const Icon(Icons.event_repeat, size: 18),
                          label: Text(
                            'Renew (+${renewalPeriodLabel(reminder.renewalPeriodMonths)})',
                          ),
                          onPressed: () => LocalRepository.renewReminder(
                            vehicleId: vehicleId,
                            type: reminder.type,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDueDate(BuildContext context) async {
    final now = DateTime.now();
    final initial = reminder.dueDate ?? now.add(const Duration(days: 30));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
      helpText: 'Select ${reminder.type.label.toLowerCase()} due date',
    );
    if (picked == null) return;
    await LocalRepository.updateReminder(
      vehicleId: vehicleId,
      type: reminder.type,
      dueDate: DateTime(picked.year, picked.month, picked.day, kReminderHour),
    );
    if (context.mounted) {
      await maybePromptForNotificationPermission(context);
    }
  }
}

/// Shows an in-app rationale then the OS permission prompt, once per install.
/// Safe to call from anywhere; no-ops if already asked.
Future<void> maybePromptForNotificationPermission(BuildContext context) async {
  if (Preferences.notificationPermissionRequested) return;
  await Preferences.setNotificationPermissionRequested(true);
  if (!context.mounted) return;

  final proceed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Allow notifications?'),
      content: const Text(
        'GasMaster can notify you before a reminder is due — both inside the '
        'app and on your device (with a badge on the app icon where '
        'supported). You can change this later in system settings.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Allow'),
        ),
      ],
    ),
  );
  if (proceed != true) return;

  final granted =
      await ReminderNotificationService.instance.requestPermission();
  if (!granted && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Notifications are off. In-app reminders still work; enable OS '
          'notifications in system settings anytime.',
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final ReminderState state;
  const _StatusChip({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (String label, Color bg, Color fg) = switch (state) {
      ReminderState.overdue => (
          'Overdue',
          theme.colorScheme.errorContainer,
          theme.colorScheme.onErrorContainer,
        ),
      ReminderState.dueSoon => (
          'Due soon',
          theme.colorScheme.tertiaryContainer,
          theme.colorScheme.onTertiaryContainer,
        ),
      ReminderState.scheduled => (
          'Scheduled',
          theme.colorScheme.secondaryContainer,
          theme.colorScheme.onSecondaryContainer,
        ),
      ReminderState.notSet => (
          'No due date',
          theme.colorScheme.surfaceContainerHighest,
          theme.colorScheme.onSurfaceVariant,
        ),
      ReminderState.notApplicable => ('', Colors.transparent, Colors.transparent),
    };
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall
            ?.copyWith(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _DueDateRow extends StatelessWidget {
  final VehicleReminder reminder;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  const _DueDateRow({
    required this.reminder,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final due = reminder.dueDate;
    final label = due == null
        ? 'Set due date'
        : DateFormat.yMMMMd().format(due);
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(Icons.event, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Due date', style: theme.textTheme.labelMedium),
                  Text(
                    label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: due == null
                          ? theme.colorScheme.onSurfaceVariant
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            if (onClear != null)
              IconButton(
                icon: const Icon(Icons.clear, size: 18),
                tooltip: 'Clear due date',
                onPressed: onClear,
              ),
            const Icon(Icons.edit_calendar_outlined, size: 18),
          ],
        ),
      ),
    );
  }
}

class _PeriodDropdown extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _PeriodDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    // Tolerate a stored value outside the standard set.
    final items = {...kRenewalPeriodMonths, value}.toList()..sort();
    return DropdownButtonFormField<int>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Renewal period',
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        for (final m in items)
          DropdownMenuItem(value: m, child: Text(renewalPeriodLabel(m))),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _RemindDropdown extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _RemindDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final items = {...kRemindDaysPriorChoices, value}.toList()
      ..sort((a, b) => b.compareTo(a));
    return DropdownButtonFormField<int>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Remind me',
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        for (final d in items)
          DropdownMenuItem(value: d, child: Text(remindWindowLabel(d))),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
