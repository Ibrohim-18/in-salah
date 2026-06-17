import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart';
import '../models/user_settings.dart';
import 'notification_service.dart';
import 'prayer_time_service.dart';

/// Builds and schedules the 30-day prayer reminder window from a settings
/// snapshot. Used both from the foreground (AppProvider) and from the
/// background WorkManager task, so it must stay free of any UI/provider state.
class PrayerReminderPlanner {
  PrayerReminderPlanner({
    PrayerTimeService? prayerTimeService,
    NotificationService? notificationService,
  }) : _prayerTimeService = prayerTimeService ?? PrayerTimeService(),
       _notificationService = notificationService ?? NotificationService();

  final PrayerTimeService _prayerTimeService;
  final NotificationService _notificationService;

  static const _prayerOrder = {
    'Fajr': 1,
    'Dhuhr': 2,
    'Asr': 3,
    'Maghrib': 4,
    'Isha': 5,
  };

  /// Builds the notification requests for the next 30 days from [settings].
  Future<List<PrayerNotificationRequest>> buildRequests(
    UserSettings settings,
  ) async {
    final now = DateTime.now();
    final requests = <PrayerNotificationRequest>[];

    final tr = await _loadTranslations(settings.locale);
    final titleTpl = tr['notificationPrayerTitle'] ?? '{prayer} Prayer';
    final bodyTpl =
        tr['notificationPrayerBody'] ?? 'It is time for {prayer} prayer.';
    final iqamaTitleTpl = tr['notificationIqamaTitle'] ?? '{prayer} Iqama';
    final iqamaBodyTpl =
        tr['notificationIqamaBody'] ?? 'Iqama time for {prayer} has started.';

    // Resolve the device position once and reuse it for every day instead of
    // hitting geolocation 30 times. Falls back to cached coordinates inside
    // getPrayersForDate when this fails (e.g. in the background isolate).
    Position? sharedPosition;
    try {
      sharedPosition = await _prayerTimeService.getCurrentPosition();
    } catch (_) {
      sharedPosition = null;
    }

    for (var dayOffset = 0; dayOffset < 30; dayOffset++) {
      final targetDate = DateTime(now.year, now.month, now.day + dayOffset);
      final prayers = await _prayerTimeService.getPrayersForDate(
        targetDate,
        settings: settings,
        position: sharedPosition,
      );

      for (final prayer in prayers) {
        final prayerSettings = settings.prayerSettings[prayer.name];
        if (!(prayerSettings?.isEnabled ?? true)) {
          continue;
        }

        final dateKey =
            (targetDate.year * 10000) +
            (targetDate.month * 100) +
            targetDate.day;
        final localizedName = _localizedPrayerName(prayer.name, tr);
        final prayerOrder = _prayerOrder[prayer.name] ?? 0;
        final idBase = (dateKey * 100) + (prayerOrder * 10);

        if (prayer.time.isAfter(now)) {
          requests.add(
            PrayerNotificationRequest(
              id: idBase + 1,
              prayerName: prayer.name,
              title: titleTpl.replaceAll('{prayer}', localizedName),
              body: bodyTpl.replaceAll('{prayer}', localizedName),
              dateTime: prayer.time,
              sound: prayerSettings?.sound ?? 'default',
            ),
          );
        }

        if (prayer.iqamaTime.isAfter(now) &&
            prayer.iqamaTime.isAfter(prayer.time)) {
          requests.add(
            PrayerNotificationRequest(
              id: idBase + 2,
              prayerName: prayer.name,
              title: iqamaTitleTpl.replaceAll('{prayer}', localizedName),
              body: iqamaBodyTpl.replaceAll('{prayer}', localizedName),
              dateTime: prayer.iqamaTime,
              sound: prayerSettings?.iqamaSound ?? 'iqama_chime',
            ),
          );
        }
      }
    }

    return requests;
  }

  /// Cancels existing reminders and schedules a fresh 30-day window.
  Future<void> reschedule(UserSettings settings) async {
    final requests = await buildRequests(settings);
    await _notificationService.schedulePrayerReminders(requests);
  }

  Future<Map<String, String>> _loadTranslations(String locale) async {
    final code = locale == 'system' ? 'en' : locale;
    const supported = {'en', 'ru', 'ar', 'tg'};
    final effective = supported.contains(code) ? code : 'en';
    try {
      final raw = await rootBundle.loadString('assets/l10n/$effective.json');
      final map = json.decode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return const {};
    }
  }

  String _localizedPrayerName(String name, Map<String, String> tr) {
    return switch (name) {
      'Fajr' => tr['fajr'] ?? name,
      'Dhuhr' => tr['dhuhr'] ?? name,
      'Asr' => tr['asr'] ?? name,
      'Maghrib' => tr['maghrib'] ?? name,
      'Isha' => tr['isha'] ?? name,
      _ => name,
    };
  }
}
