import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_salah/models/user_settings.dart';
import 'package:in_salah/services/missed_prayer_service.dart';
import 'package:in_salah/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('account-scoped persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('settings are saved and loaded separately per user', () async {
      final service = SettingsService();
      final userASettings = UserSettings(
        gender: Gender.male,
        dateOfBirth: DateTime(2000, 1, 1),
        avatarPath: 'base64:user-a-avatar',
      );
      final userBSettings = UserSettings(
        gender: Gender.female,
        dateOfBirth: DateTime(2002, 2, 2),
        avatarPath: 'base64:user-b-avatar',
      );

      await service.saveSettings(userASettings, userId: 'user_a');
      await service.saveSettings(userBSettings, userId: 'user_b');

      final loadedA = await service.loadSettings(userId: 'user_a');
      final loadedB = await service.loadSettings(userId: 'user_b');

      expect(loadedA.gender, Gender.male);
      expect(loadedA.dateOfBirth, DateTime(2000, 1, 1));
      expect(loadedA.avatarPath, 'base64:user-a-avatar');
      expect(loadedB.gender, Gender.female);
      expect(loadedB.dateOfBirth, DateTime(2002, 2, 2));
      expect(loadedB.avatarPath, 'base64:user-b-avatar');
    });

    test('legacy settings migrate into the current user scope', () async {
      final service = SettingsService();
      final legacySettings = UserSettings(
        gender: Gender.male,
        dateOfBirth: DateTime(1999, 3, 3),
      );
      SharedPreferences.setMockInitialValues({
        'user_settings': jsonEncode(legacySettings.toJson()),
      });

      final loaded = await service.loadSettings(userId: 'user_a');
      final prefs = await SharedPreferences.getInstance();

      expect(loaded.gender, Gender.male);
      expect(loaded.dateOfBirth, DateTime(1999, 3, 3));
      expect(prefs.getString('user_settings_user_a'), isNotNull);
      expect(prefs.containsKey('user_settings'), isFalse);
    });

    test('prayer completion is isolated per user id', () async {
      final service = MissedPrayerService();
      final date = DateTime.now();
      final settings = UserSettings(
        gender: Gender.male,
        dateOfBirth: DateTime(DateTime.now().year - 20, 1, 1),
      );

      await service.markPrayerCompleted('Fajr', date, true, userId: 'user_a');
      await service.markPrayerCompleted('Dhuhr', date, true, userId: 'user_b');

      final dayA = await service.getDayPrayerStatuses(date, userId: 'user_a');
      final dayB = await service.getDayPrayerStatuses(date, userId: 'user_b');
      final statsA = await service.getLifetimeStats(
        settings,
        5,
        userId: 'user_a',
      );
      final statsB = await service.getLifetimeStats(
        settings,
        5,
        userId: 'user_b',
      );

      expect(dayA['Fajr'], isTrue);
      expect(dayA['Dhuhr'], isFalse);
      expect(dayB['Fajr'], isFalse);
      expect(dayB['Dhuhr'], isTrue);
      expect(statsA['completed'], 1);
      expect(statsB['completed'], 1);
    });
  });
}
