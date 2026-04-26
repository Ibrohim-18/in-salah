import 'package:flutter_test/flutter_test.dart';
import 'package:in_salah/models/user_settings.dart';
import 'package:in_salah/services/missed_prayer_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MissedPrayerService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = MissedPrayerService();
  });

  group('MissedPrayerService Tests', () {
    test('calculateObligationStartYear returns correct year for male', () {
      final dob = DateTime(2000, 1, 1);
      final settings = UserSettings(
        gender: Gender.male,
        dateOfBirth: dob,
      );
      
      expect(service.calculateObligationStartYear(settings), 2012);
    });

    test('calculateObligationStartYear returns correct year for female', () {
      final dob = DateTime(2000, 1, 1);
      final settings = UserSettings(
        gender: Gender.female,
        dateOfBirth: dob,
      );
      
      expect(service.calculateObligationStartYear(settings), 2009);
    });

    test('calculateTotalMissedPrayers calculates correct count for current year', () {
      final now = DateTime.now();
      final startYear = now.year;
      final dob = DateTime(startYear - 12, 1, 1);
      final settings = UserSettings(
        gender: Gender.male,
        dateOfBirth: dob,
      );

      final todayStart = DateTime(now.year, now.month, now.day);
      final startDate = DateTime(startYear, 1, 1);
      final totalDays = todayStart.difference(startDate).inDays;
      final expected = (totalDays * 5) + 3;
      
      final result = service.calculateTotalMissedPrayers(settings, 3);
      expect(result, expected);
    });

    test('calculateTotalMissedPrayers returns 0 if setup not complete', () {
      final settings = UserSettings(gender: null, dateOfBirth: null);
      expect(service.calculateTotalMissedPrayers(settings, 5), 0);
    });
  });

  group('restoreFromCloud', () {
    test('writes cloud records into scoped SharedPreferences', () async {
      final applied = await service.restoreFromCloud('user_xyz', [
        {
          'prayer_name': 'Fajr',
          'prayer_date': '2026-04-10',
          'is_completed': true,
        },
        {
          'prayer_name': 'Isha',
          'prayer_date': '2026-04-10',
          'is_completed': false,
        },
      ]);

      expect(applied, 1);
      expect(
        await service.isPrayerCompleted(
          'Fajr',
          DateTime(2026, 4, 10),
          userId: 'user_xyz',
        ),
        isTrue,
      );
      expect(
        await service.isPrayerCompleted(
          'Isha',
          DateTime(2026, 4, 10),
          userId: 'user_xyz',
        ),
        isFalse,
      );
    });

    test('invalidates lifetime cache when any record was applied', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('lifetime_completed_count_user_xyz', 42);

      await service.restoreFromCloud('user_xyz', [
        {
          'prayer_name': 'Fajr',
          'prayer_date': '2026-04-10',
          'is_completed': true,
        },
      ]);

      expect(prefs.containsKey('lifetime_completed_count_user_xyz'), isFalse);
    });

    test('keeps lifetime cache when no record actually changed state', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('lifetime_completed_count_user_xyz', 42);

      final applied = await service.restoreFromCloud('user_xyz', [
        {
          'prayer_name': 'Fajr',
          'prayer_date': '2026-04-10',
          'is_completed': false,
        },
      ]);

      expect(applied, 0);
      expect(prefs.getInt('lifetime_completed_count_user_xyz'), 42);
    });

    test('ignores malformed records', () async {
      final applied = await service.restoreFromCloud('user_xyz', [
        {'prayer_name': null, 'prayer_date': '2026-04-10'},
        {'prayer_name': 'Fajr', 'prayer_date': 'not-a-date'},
      ]);
      expect(applied, 0);
    });
  });
}
