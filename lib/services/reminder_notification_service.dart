import 'dart:io' show Platform;

import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/reminder.dart';
import '../models/vehicle.dart';

/// Bridges vehicle reminders to OS-level local notifications and the app-icon
/// badge.
///
/// All platform calls are guarded: on web/desktop or when a plugin is
/// unavailable the methods degrade to no-ops rather than throwing, so the rest
/// of the app never has to care whether notifications are supported.
class ReminderNotificationService {
  ReminderNotificationService._();
  static final ReminderNotificationService instance =
      ReminderNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _tzReady = false;

  static const String _channelId = 'vehicle_reminders';
  static const String _channelName = 'Vehicle reminders';
  static const String _channelDescription =
      'Registration, inspection, and emissions reminders';

  bool get _supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  Future<void> init() async {
    if (_initialized || !_supported) return;
    await _ensureTimeZone();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    // We request permissions explicitly (see [requestPermission]) rather than
    // at initialization, so the prompt is tied to a user action.
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(
        android: android,
        iOS: darwin,
        macOS: darwin,
      ),
    );
    _initialized = true;
  }

  Future<void> _ensureTimeZone() async {
    if (_tzReady) return;
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // Leave tz.local at its default (UTC) if the zone can't be resolved.
    }
    _tzReady = true;
  }

  /// Prompts the user to allow notifications. Returns true when granted (or
  /// best-effort true on Android where the result may be null on older APIs).
  Future<bool> requestPermission() async {
    if (!_supported) return false;
    try {
      await init();
      if (Platform.isIOS || Platform.isMacOS) {
        final granted = await _plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true);
        return granted ?? false;
      }
      if (Platform.isAndroid) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final granted = await android?.requestNotificationsPermission();
        return granted ?? true;
      }
    } catch (e) {
      debugPrint('ReminderNotificationService.requestPermission failed: $e');
    }
    return false;
  }

  /// Whether OS notifications are currently permitted, if the platform can
  /// report it. Returns null when unknown.
  Future<bool?> hasPermission() async {
    if (!_supported) return false;
    try {
      await init();
      if (Platform.isAndroid) {
        return _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.areNotificationsEnabled();
      }
    } catch (_) {}
    return null;
  }

  /// Cancels every scheduled reminder and reschedules from [vehicles], then
  /// refreshes the app-icon badge with the count needing attention.
  ///
  /// [now] is injectable for testing; production passes the real clock.
  Future<void> syncAll(List<Vehicle> vehicles, {DateTime? now}) async {
    if (!_supported) return;
    final clock = now ?? DateTime.now();
    try {
      await init();
      await _plugin.cancelAll();
      var attention = 0;
      for (final v in vehicles) {
        for (final r in v.reminders) {
          if (r.needsAttentionAt(clock)) attention++;
          final instant = r.reminderInstant();
          if (instant != null && instant.isAfter(clock)) {
            await _schedule(v, r, instant);
          }
        }
      }
      await _updateBadge(attention);
    } catch (e, st) {
      debugPrint('ReminderNotificationService.syncAll failed: $e\n$st');
    }
  }

  Future<void> _schedule(
      Vehicle vehicle, VehicleReminder reminder, DateTime instant) async {
    final due = reminder.anchoredDueDate!;
    final title = '${reminder.type.label} — ${vehicle.displayName}';
    final dueLabel = DateFormat.yMMMd().format(due);
    final body = 'Due $dueLabel '
        '(${reminder.remindDaysPrior} days away).';
    await _plugin.zonedSchedule(
      _notificationId(vehicle.id, reminder.type),
      title,
      body,
      tz.TZDateTime.from(instant, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> _updateBadge(int count) async {
    try {
      if (await AppBadgePlus.isSupported()) {
        await AppBadgePlus.updateBadge(count);
      }
    } catch (_) {
      // Badges are best-effort; launcher support varies.
    }
  }

  /// Stable notification id per (vehicle, reminder type). Kept deterministic so
  /// a resync targets the same slot; [syncAll] also cancels all first.
  int _notificationId(String vehicleId, ReminderType type) {
    final base = (vehicleId.hashCode & 0x7fffffff) % 200000000;
    return base * 10 + type.index;
  }
}
