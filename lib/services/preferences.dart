import 'package:shared_preferences/shared_preferences.dart';

class Preferences {
  static const _unitSystemKey = 'unit_system';
  static const _communitySharingKey = 'community_sharing_enabled';
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
}
