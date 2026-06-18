import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_settings.dart';
import 'insforge_service.dart';

class MissedPrayerService {
  static const String _keyPrefix = 'missed_prayer_';
  static const String _keyLifetimeCompletedPrefix = 'lifetime_completed_count_';
  static const String _guestScope = 'guest';

  String _scopeId([String? userId]) {
    return userId ?? InsforgeService.instance.currentUser?.id ?? _guestScope;
  }

  int calculateObligationStartYear(UserSettings settings) {
    if (settings.dateOfBirth == null) return DateTime.now().year;
    return settings.dateOfBirth!.year + settings.obligationStartAge;
  }

  int calculateTotalMissedPrayers(UserSettings settings, int pastPrayersToday) {
    if (!settings.isSetupComplete) return 0;

    final now = DateTime.now();
    final startYear = calculateObligationStartYear(settings);
    final startDate = DateTime(startYear, 1, 1);
    final todayStart = DateTime(now.year, now.month, now.day);

    if (startDate.isAfter(todayStart)) return 0;

    final totalDays = todayStart.difference(startDate).inDays;

    return (totalDays * 5) + pastPrayersToday;
  }

  String _getKey(String prayerName, DateTime date, {String? userId}) {
    return '$_keyPrefix${_scopeId(userId)}_${prayerName}_${date.year}_${date.month}_${date.day}';
  }

  String _getLifetimeKey({String? userId}) {
    return '$_keyLifetimeCompletedPrefix${_scopeId(userId)}';
  }

  Future<bool> isPrayerCompleted(
    String prayerName,
    DateTime date, {
    String? userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_getKey(prayerName, date, userId: userId)) ?? false;
  }

  Future<void> markPrayerCompleted(
    String prayerName,
    DateTime date,
    bool completed, {
    String? userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getKey(prayerName, date, userId: userId);
    final previous = prefs.getBool(key) ?? false;

    if (previous != completed) {
      await prefs.setBool(key, completed);

      // Update lifetime cache if it exists
      final lifetimeKey = _getLifetimeKey(userId: userId);
      final currentTotal = prefs.getInt(lifetimeKey);
      if (currentTotal != null) {
        await prefs.setInt(
          lifetimeKey,
          (currentTotal + (completed ? 1 : -1)).clamp(0, 999999),
        );
      }

      // Cloud Sync to InsForge
      final currentUser = InsforgeService.instance.currentUser;
      if (currentUser != null && currentUser.id.isNotEmpty) {
        final dateStr =
            "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
        unawaited(
          InsforgeService.instance.upsertRecord('missed_prayers_log', {
            'user_id': currentUser.id,
            'prayer_name': prayerName,
            'prayer_date': dateStr,
            'is_completed': completed,
            'updated_at': DateTime.now().toIso8601String(),
          }),
        );
      }
    }
  }

  /// Marks every prayer of every non-future day in [year]/[month] as
  /// [completed] in one pass. For the current month, today only marks prayers
  /// whose time has already passed ([pastPrayersToday]); future days are
  /// skipped entirely. Invalidates the lifetime cache so totals recompute.
  Future<void> setAllPrayersForMonth(
    int year,
    int month, {
    required bool completed,
    required int pastPrayersToday,
    String? userId,
  }) async {
    final now = DateTime.now();
    // Nothing to do for months that lie entirely in the future.
    if (DateTime(year, month, 1).isAfter(DateTime(now.year, now.month, 1))) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final prayerNames = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    final currentUser = InsforgeService.instance.currentUser;
    final cloudRecords = <Map<String, dynamic>>[];
    bool changedAny = false;

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      // Stop once we reach days that haven't happened yet.
      if (date.isAfter(DateTime(now.year, now.month, now.day))) break;

      final isToday = year == now.year && month == now.month && day == now.day;
      final allowedCount = isToday ? pastPrayersToday : prayerNames.length;

      for (int i = 0; i < prayerNames.length; i++) {
        // When marking done, never tick a prayer whose time hasn't come.
        final target = completed && i < allowedCount;
        final key = _getKey(prayerNames[i], date, userId: userId);
        final previous = prefs.getBool(key) ?? false;
        if (previous == target) continue;

        await prefs.setBool(key, target);
        changedAny = true;

        if (currentUser != null && currentUser.id.isNotEmpty) {
          final dateStr =
              "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
          cloudRecords.add({
            'user_id': currentUser.id,
            'prayer_name': prayerNames[i],
            'prayer_date': dateStr,
            'is_completed': target,
            'updated_at': DateTime.now().toIso8601String(),
          });
        }
      }
    }

    if (changedAny) {
      // Force a fresh recount on the next lifetime-stats read.
      await prefs.remove(_getLifetimeKey(userId: userId));
    }

    // One awaited, chunked bulk upsert instead of hundreds of concurrent
    // fire-and-forget requests — those overwhelmed the network and dropped
    // most writes, leaving months only partially synced to the cloud.
    if (cloudRecords.isNotEmpty) {
      await InsforgeService.instance.bulkUpsertRecords(
        'missed_prayers_log',
        cloudRecords,
      );
    }
  }

  Future<int> restoreFromCloud(
    String userId,
    List<Map<String, dynamic>> records,
  ) async {
    if (userId.isEmpty) return 0;
    final prefs = await SharedPreferences.getInstance();
    int applied = 0;

    for (final record in records) {
      final prayerName = record['prayer_name'] as String?;
      final dateStr = record['prayer_date'] as String?;
      if (prayerName == null || dateStr == null) continue;

      final date = DateTime.tryParse(dateStr);
      if (date == null) continue;

      final completed = record['is_completed'] == true;
      // Only ever ADD completions from the cloud. Never clear a prayer the
      // user already ticked locally: the cloud can lag behind (a dropped sync
      // leaves a stale/false row), and overwriting local with that silently
      // un-ticked the user's prayers on the next login.
      if (!completed) continue;

      final key = _getKey(prayerName, date, userId: userId);
      if (!(prefs.getBool(key) ?? false)) {
        await prefs.setBool(key, true);
        applied++;
      }
    }

    if (applied > 0) {
      await prefs.remove(_getLifetimeKey(userId: userId));
    }
    return applied;
  }

  /// Re-uploads every locally-ticked prayer that the cloud is missing (or has
  /// stored as `false`) for [userId]. [cloudRecords] is the same payload
  /// passed to [restoreFromCloud], used to avoid re-pushing rows the cloud
  /// already has completed.
  ///
  /// Marks are written to the cloud fire-and-forget in [markPrayerCompleted],
  /// so a single dropped network write silently leaves a completion local-only.
  /// On the next login on another device — or after a reinstall — the cloud is
  /// the source of truth, so those un-synced ticks vanished. Healing the cloud
  /// from local on every restore makes both sides converge to the union of all
  /// completed prayers. Returns how many rows were pushed.
  Future<int> pushLocalCompletionsToCloud(
    String userId,
    List<Map<String, dynamic>> cloudRecords,
  ) async {
    if (userId.isEmpty) return 0;
    final prefs = await SharedPreferences.getInstance();

    // Local keys the cloud already has marked completed — nothing to push.
    final cloudCompleted = <String>{};
    for (final record in cloudRecords) {
      if (record['is_completed'] != true) continue;
      final prayerName = record['prayer_name'] as String?;
      final dateStr = record['prayer_date'] as String?;
      if (prayerName == null || dateStr == null) continue;
      final date = DateTime.tryParse(dateStr);
      if (date == null) continue;
      cloudCompleted.add(_getKey(prayerName, date, userId: userId));
    }

    final prefix = '$_keyPrefix${_scopeId(userId)}_';
    final pushRecords = <Map<String, dynamic>>[];
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      if (!(prefs.getBool(key) ?? false)) continue;
      if (cloudCompleted.contains(key)) continue;

      final parsed = _parseLocalKey(key, prefix);
      if (parsed == null) continue;
      final (prayerName, date) = parsed;
      final dateStr =
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      pushRecords.add({
        'user_id': userId,
        'prayer_name': prayerName,
        'prayer_date': dateStr,
        'is_completed': true,
        'updated_at': DateTime.now().toIso8601String(),
      });
    }

    if (pushRecords.isEmpty) return 0;
    await InsforgeService.instance.bulkUpsertRecords(
      'missed_prayers_log',
      pushRecords,
    );
    return pushRecords.length;
  }

  /// Parses a local completion key back into its prayer name and date.
  /// [prefix] is `${_keyPrefix}${scope}_`, leaving `PrayerName_year_month_day`.
  (String, DateTime)? _parseLocalKey(String key, String prefix) {
    final parts = key.substring(prefix.length).split('_');
    if (parts.length != 4) return null;
    final year = int.tryParse(parts[1]);
    final month = int.tryParse(parts[2]);
    final day = int.tryParse(parts[3]);
    if (year == null || month == null || day == null) return null;
    return (parts[0], DateTime(year, month, day));
  }

  Future<Map<String, int>> getLifetimeStats(
    UserSettings settings,
    int pastPrayersToday, {
    String? userId,
  }) async {
    if (!settings.isSetupComplete) {
      return {'total': 0, 'completed': 0, 'missed': 0};
    }

    final now = DateTime.now();
    final startYear = calculateObligationStartYear(settings);
    final prefs = await SharedPreferences.getInstance();
    final prayerNames = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

    final lifetimeKey = _getLifetimeKey(userId: userId);
    int completedCount = prefs.getInt(lifetimeKey) ?? -1;

    if (completedCount == -1) {
      completedCount = 0;
      for (int year = startYear; year <= now.year; year++) {
        final endMonth = year == now.year ? now.month : 12;
        for (int month = 1; month <= endMonth; month++) {
          final daysInMonth = DateTime(year, month + 1, 0).day;
          final dayLimit = (year == now.year && month == now.month)
              ? now.day
              : daysInMonth;

          for (int day = 1; day <= dayLimit; day++) {
            final isToday =
                (year == now.year && month == now.month && day == now.day);
            final limitForDay = isToday ? pastPrayersToday : 5;
            final date = DateTime(year, month, day);

            for (int i = 0; i < prayerNames.length; i++) {
              if (i >= limitForDay) continue;
              if (prefs.getBool(
                    _getKey(prayerNames[i], date, userId: userId),
                  ) ??
                  false) {
                completedCount++;
              }
            }
          }
        }
      }
      await prefs.setInt(lifetimeKey, completedCount);
    }

    final totalObligatory = calculateTotalMissedPrayers(
      settings,
      pastPrayersToday,
    );
    final missed = (totalObligatory - completedCount).clamp(0, totalObligatory);
    return {
      'total': totalObligatory,
      'completed': completedCount,
      'missed': missed,
    };
  }

  Future<int> getMissedCount(
    UserSettings settings,
    int pastPrayersToday, {
    String? userId,
  }) async {
    final stats = await getLifetimeStats(
      settings,
      pastPrayersToday,
      userId: userId,
    );
    return stats['missed'] ?? 0;
  }

  Future<Map<String, bool>> getDayPrayerStatuses(
    DateTime date, {
    String? userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final prayerNames = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    final result = <String, bool>{};

    for (final prayerName in prayerNames) {
      result[prayerName] =
          prefs.getBool(_getKey(prayerName, date, userId: userId)) ?? false;
    }

    return result;
  }

  Future<Map<int, int>> getMonthDayCompletions(
    int year,
    int month, {
    String? userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final prayerNames = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final result = <int, int>{};

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      int count = 0;
      for (final prayerName in prayerNames) {
        if (prefs.getBool(_getKey(prayerName, date, userId: userId)) ?? false) {
          count++;
        }
      }
      result[day] = count;
    }

    return result;
  }

  Future<void> markDayPrayersCompleted(
    DateTime date,
    bool completed, {
    int? limitCount,
    String? userId,
  }) async {
    final prayerNames = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    final effectiveLimit = limitCount ?? prayerNames.length;
    for (int i = 0; i < prayerNames.length && i < effectiveLimit; i++) {
      await markPrayerCompleted(prayerNames[i], date, completed, userId: userId);
    }
  }

  Future<Map<String, int>> getMonthStats(
    int year,
    int month,
    int pastPrayersToday, {
    String? userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final prayerNames = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final now = DateTime.now();
    final isCurrentMonth = year == now.year && month == now.month;
    final dayLimit = isCurrentMonth ? now.day : daysInMonth;

    int completedCount = 0;
    final prayerCompleted = <String, int>{};
    for (final p in prayerNames) {
      prayerCompleted[p] = 0;
    }

    for (int day = 1; day <= dayLimit; day++) {
      final isToday = (day == now.day && isCurrentMonth);
      final limitForDay = isToday ? pastPrayersToday : 5;
      final date = DateTime(year, month, day);

      for (int i = 0; i < prayerNames.length; i++) {
        if (i >= limitForDay) continue;
        final prayerName = prayerNames[i];
        if (prefs.getBool(_getKey(prayerName, date, userId: userId)) ?? false) {
          completedCount++;
          prayerCompleted[prayerName] = (prayerCompleted[prayerName] ?? 0) + 1;
        }
      }
    }

    int totalPossible = 0;
    if (isCurrentMonth) {
      totalPossible = (now.day - 1) * 5 + pastPrayersToday;
    } else if (DateTime(year, month).isBefore(DateTime(now.year, now.month))) {
      totalPossible = daysInMonth * 5;
    } else {
      totalPossible = 0;
    }

    return {
      'completed': completedCount,
      'total': totalPossible,
      'missed': totalPossible - completedCount,
      ...prayerCompleted,
    };
  }
}
