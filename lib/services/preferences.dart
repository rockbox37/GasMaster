import 'package:shared_preferences/shared_preferences.dart';

class Preferences {
  static const _unitSystemKey = 'unit_system';
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static String get unitSystem => _prefs?.getString(_unitSystemKey) ?? 'imperial';

  static Future<void> setUnitSystem(String unit) async {
    await _prefs?.setString(_unitSystemKey, unit);
  }
}
