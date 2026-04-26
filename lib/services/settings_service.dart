import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_settings.dart';
import 'insforge_service.dart';

class SettingsService {
  static const String _legacyKeySettings = 'user_settings';
  static const String _keySettingsPrefix = 'user_settings_';
  static const String _guestScope = 'guest';

  String _scopeId([String? userId]) {
    return userId ?? InsforgeService.instance.currentUser?.id ?? _guestScope;
  }

  String _settingsKey([String? userId]) =>
      '$_keySettingsPrefix${_scopeId(userId)}';

  Future<bool> hasSettings({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_settingsKey(userId)) ||
        prefs.containsKey(_legacyKeySettings);
  }

  Future<UserSettings> loadSettings({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final scopedKey = _settingsKey(userId);
    final jsonStr = prefs.getString(scopedKey);
    if (jsonStr == null) {
      final legacyJson = prefs.getString(_legacyKeySettings);
      if (legacyJson == null) return UserSettings();

      await prefs.setString(scopedKey, legacyJson);
      await prefs.remove(_legacyKeySettings);
      return UserSettings.fromJson(jsonDecode(legacyJson));
    }

    return UserSettings.fromJson(jsonDecode(jsonStr));
  }

  Future<void> saveSettings(UserSettings settings, {String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey(userId), jsonEncode(settings.toJson()));
    if (prefs.containsKey(_legacyKeySettings)) {
      await prefs.remove(_legacyKeySettings);
    }
  }

  Future<int> getIqamaTime(String prayerName, {String? userId}) async {
    final settings = await loadSettings(userId: userId);
    return settings.iqamaTimes[prayerName] ?? 10;
  }

  Future<void> updateIqamaTime(
    String prayerName,
    int minutes, {
    String? userId,
  }) async {
    final settings = await loadSettings(userId: userId);
    final updated = Map<String, int>.from(settings.iqamaTimes);
    updated[prayerName] = minutes;
    await saveSettings(settings.copyWith(iqamaTimes: updated), userId: userId);
  }
}
