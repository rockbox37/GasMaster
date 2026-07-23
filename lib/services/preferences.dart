import 'package:shared_preferences/shared_preferences.dart';

class Preferences {
  static const _unitSystemKey = 'unit_system';
  static const _communitySharingKey = 'community_sharing_enabled';
  static const _notifPromptedKey = 'notif_permission_requested';
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static String get unitSystem => _prefs?.getString(_unitSystemKey) ?? 'imperial';

  static Future<void> setUnitSystem(String unit) async {
    await _prefs?.setString(_unitSystemKey, unit);
  }

  static bool get communitySharingEnabled =>
      _prefs?.getBool(_communitySharingKey) ?? false;

  static Future<void> setCommunitySharingEnabled(bool enabled) async {
    await _prefs?.setBool(_communitySharingKey, enabled);
  }

  /// Whether we've already shown the OS notification permission prompt, so we
  /// only ask once (the OS itself only shows its dialog once anyway).
  static bool get notificationPermissionRequested =>
      _prefs?.getBool(_notifPromptedKey) ?? false;

  static Future<void> setNotificationPermissionRequested(bool value) async {
    await _prefs?.setBool(_notifPromptedKey, value);
  }
}
