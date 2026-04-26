import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';

class AppUtils {
  /// Maps a locale code to one that intl's DateFormat has data for.
  /// Tajik ('tg') falls back to Russian ('ru') since intl doesn't ship Tajik symbols.
  static String intlLocale(String locale) {
    if (locale == 'tg') return 'ru';
    return locale;
  }

  static String _contextLocale(BuildContext context) =>
      intlLocale(Localizations.localeOf(context).languageCode);

  static String _rawLocale(BuildContext context) =>
      Localizations.localeOf(context).languageCode;

  // Tajik weekday/month tables — intl ships no Tajik data, so we localize manually.
  static const _tgWeekdaysLong = [
    'Душанбе', 'Сешанбе', 'Чоршанбе', 'Панҷшанбе',
    'Ҷумъа', 'Шанбе', 'Якшанбе',
  ];
  static const _tgWeekdaysShort = [
    'Дш', 'Сш', 'Чш', 'Пш', 'Ҷм', 'Шб', 'Яш',
  ];
  static const _tgMonthsLong = [
    'Январ', 'Феврал', 'Март', 'Апрел', 'Май', 'Июн',
    'Июл', 'Август', 'Сентябр', 'Октябр', 'Ноябр', 'Декабр',
  ];
  static const _tgMonthsShort = [
    'Янв', 'Фев', 'Мар', 'Апр', 'Май', 'Июн',
    'Июл', 'Авг', 'Сен', 'Окт', 'Ноя', 'Дек',
  ];

  static String tgWeekdayLong(DateTime d) => _tgWeekdaysLong[d.weekday - 1];
  static String tgWeekdayShort(DateTime d) => _tgWeekdaysShort[d.weekday - 1];
  static String tgMonthLong(int month) => _tgMonthsLong[month - 1];
  static String tgMonthShort(int month) => _tgMonthsShort[month - 1];

  static String formatTime(DateTime time) {
    return DateFormat('HH:mm').format(time);
  }

  static String formatTime12Hour(DateTime time) {
    return DateFormat('h:mm a').format(time);
  }

  static String formatDate(BuildContext context, DateTime date) {
    if (_rawLocale(context) == 'tg') {
      return '${tgWeekdayLong(date)}, ${date.day} ${tgMonthLong(date.month)} ${date.year}';
    }
    return DateFormat('EEEE, d MMMM yyyy', _contextLocale(context)).format(date);
  }

  static String formatDateShort(BuildContext context, DateTime date) {
    if (_rawLocale(context) == 'tg') {
      return '${date.day} ${tgMonthShort(date.month)}';
    }
    return DateFormat('d MMM', _contextLocale(context)).format(date);
  }

  static String greetingKey() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'goodMorning';
    if (hour < 17) return 'goodAfternoon';
    return 'goodEvening';
  }

  /// Returns localized Hijri month name by 1-12 index.
  static String hijriMonthName(BuildContext context, int month) {
    final t = AppLocalizations.of(context);
    return t.translate('hijriMonth$month');
  }

  static String formatHijriDate(BuildContext context, DateTime date) {
    final hijri = HijriCalendar.fromDate(date);
    final month = hijriMonthName(context, hijri.hMonth);
    final suffix = AppLocalizations.of(context).translate('hijriYearSuffix');
    return '${hijri.hDay} $month ${hijri.hYear} $suffix';
  }

  static String formatHijriDateShort(BuildContext context, DateTime date) {
    final hijri = HijriCalendar.fromDate(date);
    final month = hijriMonthName(context, hijri.hMonth);
    return '${hijri.hDay} $month';
  }

  static String formatHijriMonthYear(BuildContext context, DateTime date) {
    final hijri = HijriCalendar.fromDate(date);
    final month = hijriMonthName(context, hijri.hMonth);
    return '$month ${hijri.hYear}';
  }

  static int hijriDay(DateTime date) {
    return HijriCalendar.fromDate(date).hDay;
  }

  static String getPrayerIcon(String prayerName) {
    switch (prayerName) {
      case 'Fajr':
        return '🌅';
      case 'Dhuhr':
        return '☀️';
      case 'Asr':
        return '🌤️';
      case 'Maghrib':
        return '🌇';
      case 'Isha':
        return '🌙';
      default:
        return '🕌';
    }
  }
}
