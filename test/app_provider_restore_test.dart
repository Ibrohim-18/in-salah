import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:in_salah/models/prayer.dart';
import 'package:in_salah/models/user_settings.dart';
import 'package:in_salah/providers/app_provider.dart';
import 'package:in_salah/services/insforge_service.dart';
import 'package:in_salah/services/missed_prayer_service.dart';
import 'package:in_salah/services/prayer_time_service.dart';
import 'package:in_salah/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppProvider cloud restore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'hydrates missing local settings from cloud and persists them locally',
      () async {
        final provider = AppProvider(
          settingsService: SettingsService(),
          prayerTimeService: _FakePrayerTimeService(),
          missedPrayerService: _FakeMissedPrayerService(),
          notificationInit: () async {},
          notificationCancelAll: () async {},
          schedulePrayerReminders: (requests) async {},
          initialUser: InsforgeUser(
            id: 'user_123',
            email: 'user@example.com',
            emailVerified: true,
          ),
          authStateChanges: const Stream<InsforgeUser?>.empty(),
          fetchUserProfileSettings: (_) async => UserSettings(
            gender: Gender.female,
            dateOfBirth: DateTime(1998, 4, 4),
            avatarPath: 'base64:remote-avatar',
            calculationMethod: 'umm_al_qura',
            madhab: 'hanafi',
          ),
          fetchMissedPrayers: (_) async => const [],
        );

        await provider.init();

        final prefs = await SharedPreferences.getInstance();
        final stored = UserSettings.fromJson(
          jsonDecode(prefs.getString('user_settings_user_123')!)
              as Map<String, dynamic>,
        );

        expect(provider.error, isEmpty);
        expect(provider.settings.gender, Gender.female);
        expect(provider.settings.dateOfBirth, DateTime(1998, 4, 4));
        expect(provider.settings.avatarPath, 'base64:remote-avatar');
        expect(provider.settings.calculationMethod, 'umm_al_qura');
        expect(provider.settings.madhab, 'hanafi');
        expect(stored.avatarPath, 'base64:remote-avatar');
        expect(stored.calculationMethod, 'umm_al_qura');
        expect(stored.madhab, 'hanafi');
      },
    );

    test('pulls missed prayers from cloud on login', () async {
      final fetchedUserIds = <String>[];
      final missedService = MissedPrayerService();

      final provider = AppProvider(
        settingsService: SettingsService(),
        prayerTimeService: _FakePrayerTimeService(),
        missedPrayerService: missedService,
        notificationInit: () async {},
        notificationCancelAll: () async {},
        schedulePrayerReminders: (requests) async {},
        initialUser: InsforgeUser(
          id: 'user_sync',
          email: 'sync@example.com',
          emailVerified: true,
        ),
        authStateChanges: const Stream<InsforgeUser?>.empty(),
        fetchUserProfileSettings: (_) async => null,
        fetchMissedPrayers: (userId) async {
          fetchedUserIds.add(userId);
          return [
            {
              'prayer_name': 'Fajr',
              'prayer_date': '2026-04-10',
              'is_completed': true,
            },
          ];
        },
      );

      await provider.init();

      expect(fetchedUserIds, ['user_sync']);
      expect(
        await missedService.isPrayerCompleted(
          'Fajr',
          DateTime(2026, 4, 10),
          userId: 'user_sync',
        ),
        isTrue,
      );
    });
  });
}

class _FakePrayerTimeService extends PrayerTimeService {
  @override
  Future<List<Prayer>> getPrayers([DateTime? date]) async {
    final targetDate = date ?? DateTime.now();
    return [
      Prayer(
        name: 'Fajr',
        nameArabic: 'الفجر',
        time: DateTime(targetDate.year, targetDate.month, targetDate.day, 5),
        iqamaTime: DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          5,
          15,
        ),
      ),
    ];
  }

  @override
  Future<List<Prayer>> getPrayersForDate(
    DateTime targetDate, {
    UserSettings? settings,
    Position? position,
  }) async {
    return getPrayers(targetDate);
  }
}

class _FakeMissedPrayerService extends MissedPrayerService {
  @override
  Future<Map<String, bool>> getDayPrayerStatuses(
    DateTime date, {
    String? userId,
  }) async {
    return {'Fajr': false};
  }

  @override
  Future<Map<String, int>> getLifetimeStats(
    UserSettings settings,
    int pastPrayersToday, {
    String? userId,
  }) async {
    return {'total': 1, 'completed': 0, 'missed': 1};
  }
}
