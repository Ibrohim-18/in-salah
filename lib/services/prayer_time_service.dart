import 'package:adhan/adhan.dart' as adhan;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/prayer.dart';
import '../models/user_settings.dart';
import 'settings_service.dart';

class PrayerTimeService {
  final SettingsService _settingsService = SettingsService();

  Future<Position> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied');
    }

    return Geolocator.getCurrentPosition();
  }

  adhan.CalculationMethod _resolveCalculationMethod(String value) {
    switch (value) {
      case 'umm_al_qura':
        return adhan.CalculationMethod.umm_al_qura;
      case 'isna':
        return adhan.CalculationMethod.north_america;
      case 'egyptian':
        return adhan.CalculationMethod.egyptian;
      case 'karachi':
        return adhan.CalculationMethod.karachi;
      case 'muslim_world_league':
      default:
        return adhan.CalculationMethod.muslim_world_league;
    }
  }

  List<Prayer> _fallbackPrayers(DateTime targetDate, UserSettings settings) {
    return [
      Prayer(
        name: 'Fajr',
        nameArabic: 'الفجر',
        time: DateTime(targetDate.year, targetDate.month, targetDate.day, 5, 0),
        iqamaTime: DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          5,
          settings.iqamaTimes['Fajr'] ?? 15,
        ),
      ),
      Prayer(
        name: 'Dhuhr',
        nameArabic: 'الظهر',
        time: DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          12,
          30,
        ),
        iqamaTime: DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          12,
          30 + (settings.iqamaTimes['Dhuhr'] ?? 10),
        ),
      ),
      Prayer(
        name: 'Asr',
        nameArabic: 'العصر',
        time: DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          15,
          45,
        ),
        iqamaTime: DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          15,
          45 + (settings.iqamaTimes['Asr'] ?? 10),
        ),
      ),
      Prayer(
        name: 'Maghrib',
        nameArabic: 'المغرب',
        time: DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          18,
          15,
        ),
        iqamaTime: DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          18,
          15 + (settings.iqamaTimes['Maghrib'] ?? 5),
        ),
      ),
      Prayer(
        name: 'Isha',
        nameArabic: 'العشاء',
        time: DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          19,
          45,
        ),
        iqamaTime: DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          19,
          45 + (settings.iqamaTimes['Isha'] ?? 15),
        ),
      ),
    ];
  }

  Future<List<Prayer>> getPrayersForDate(
    DateTime targetDate, {
    UserSettings? settings,
    Position? position,
  }) async {
    final resolvedSettings = settings ?? await _settingsService.loadSettings();

    try {
      final resolvedPosition = position ?? await getCurrentPosition();
      final coordinates = adhan.Coordinates(
        resolvedPosition.latitude,
        resolvedPosition.longitude,
      );
      final params = _resolveCalculationMethod(
        resolvedSettings.calculationMethod,
      ).getParameters();

      params.madhab = resolvedSettings.madhab == 'hanafi'
          ? adhan.Madhab.hanafi
          : adhan.Madhab.shafi;

      final dateComponents = adhan.DateComponents(
        targetDate.year,
        targetDate.month,
        targetDate.day,
      );
      final prayerTimes = adhan.PrayerTimes(
        coordinates,
        dateComponents,
        params,
      );

      return [
        Prayer(
          name: 'Fajr',
          nameArabic: 'الفجر',
          time: prayerTimes.fajr,
          iqamaTime: prayerTimes.fajr.add(
            Duration(minutes: resolvedSettings.iqamaTimes['Fajr'] ?? 15),
          ),
        ),
        Prayer(
          name: 'Dhuhr',
          nameArabic: 'الظهر',
          time: prayerTimes.dhuhr,
          iqamaTime: prayerTimes.dhuhr.add(
            Duration(minutes: resolvedSettings.iqamaTimes['Dhuhr'] ?? 10),
          ),
        ),
        Prayer(
          name: 'Asr',
          nameArabic: 'العصر',
          time: prayerTimes.asr,
          iqamaTime: prayerTimes.asr.add(
            Duration(minutes: resolvedSettings.iqamaTimes['Asr'] ?? 10),
          ),
        ),
        Prayer(
          name: 'Maghrib',
          nameArabic: 'المغرب',
          time: prayerTimes.maghrib,
          iqamaTime: prayerTimes.maghrib.add(
            Duration(minutes: resolvedSettings.iqamaTimes['Maghrib'] ?? 5),
          ),
        ),
        Prayer(
          name: 'Isha',
          nameArabic: 'العشاء',
          time: prayerTimes.isha,
          iqamaTime: prayerTimes.isha.add(
            Duration(minutes: resolvedSettings.iqamaTimes['Isha'] ?? 15),
          ),
        ),
      ];
    } catch (e, st) {
      debugPrint('[PrayerTimeService] geolocation/calc failed: $e');
      debugPrintStack(stackTrace: st, label: 'PrayerTimeService');
      return _fallbackPrayers(targetDate, resolvedSettings);
    }
  }

  Future<List<Prayer>> getPrayers([DateTime? date]) async {
    final targetDate = date ?? DateTime.now();
    return getPrayersForDate(targetDate);
  }

  String getNextPrayerName(List<Prayer> prayers) {
    final now = DateTime.now();
    for (final prayer in prayers) {
      if (prayer.time.isAfter(now)) {
        return prayer.name;
      }
    }
    return 'Fajr (tomorrow)';
  }

  String getCurrentPrayerStatus(List<Prayer> prayers) {
    final now = DateTime.now();
    Prayer? currentPrayer;
    for (final prayer in prayers) {
      if (prayer.time.isBefore(now)) {
        currentPrayer = prayer;
      } else {
        break;
      }
    }
    if (currentPrayer == null) return 'Before Fajr';
    return currentPrayer.name;
  }
}
