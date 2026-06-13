import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quran_models.dart';

/// Fetches Quran text, translation and audio from the free AlQuran.cloud API
/// (no key/registration). Caches responses in SharedPreferences so revisited
/// surahs load instantly and survive offline.
class QuranService {
  static const _base = 'https://api.alquran.cloud/v1';
  static const _arabicEdition = 'quran-uthmani';
  static const _surahListKey = 'quran_surah_list';

  static const _timeout = Duration(seconds: 20);

  // Audio comes from everyayah.com instead of cdn.islamic.network: the latter
  // sends no CORS headers, which breaks playback on web (audioplayers sets
  // crossOrigin=anonymous on its audio element).
  static const _reciterFolders = {
    'ar.alafasy': 'Alafasy_128kbps',
    'ar.abdurrahmaansudais': 'Abdurrahmaan_As-Sudais_192kbps',
    'ar.husary': 'Husary_128kbps',
    'ar.mahermuaiqly': 'MaherAlMuaiqly128kbps',
    'ar.shaatree': 'Abu_Bakr_Ash-Shaatree_128kbps',
  };

  static String audioUrl(String reciter, int surah, int ayahInSurah) {
    final folder = _reciterFolders[reciter] ?? _reciterFolders['ar.alafasy']!;
    final s = surah.toString().padLeft(3, '0');
    final a = ayahInSurah.toString().padLeft(3, '0');
    return 'https://everyayah.com/data/$folder/$s$a.mp3';
  }

  /// Maps the app's interface locale to a translation edition. Arabic returns
  /// null (Arabic-only display, no translation block).
  static String? translationEditionForLocale(String locale) {
    switch (locale) {
      case 'ru':
        return 'ru.kuliev';
      case 'tg':
        return 'tg.ayati';
      case 'ar':
        return null;
      case 'en':
        return 'en.sahih';
      default:
        return 'en.sahih';
    }
  }

  Future<List<Surah>> fetchSurahList() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final resp = await http
          .get(Uri.parse('$_base/surah'))
          .timeout(_timeout);
      if (resp.statusCode == 200) {
        final data = (jsonDecode(resp.body) as Map<String, dynamic>)['data'];
        if (data is List) {
          final surahs = data
              .whereType<Map<String, dynamic>>()
              .map(Surah.fromJson)
              .toList(growable: false);
          await prefs.setString(
            _surahListKey,
            jsonEncode(surahs.map((s) => s.toJson()).toList()),
          );
          return surahs;
        }
      }
    } catch (e) {
      debugPrint('QuranService.fetchSurahList error: $e');
    }

    // Offline / error fallback to cache.
    final cached = prefs.getString(_surahListKey);
    if (cached != null) {
      try {
        final list = jsonDecode(cached) as List;
        return list
            .whereType<Map<String, dynamic>>()
            .map(Surah.fromJson)
            .toList(growable: false);
      } catch (_) {}
    }
    return const [];
  }

  /// Loads a full surah, zipping Arabic text, translation and audio by index.
  /// [translationEdition] may be null (Arabic-only).
  Future<List<Ayah>> fetchSurah(
    int number, {
    required String? translationEdition,
    required String reciter,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey =
        'quran_surah_${number}_${translationEdition ?? 'none'}_$reciter';

    final editions = [
      _arabicEdition,
      ?translationEdition,
    ].join(',');

    try {
      final resp = await http
          .get(Uri.parse('$_base/surah/$number/editions/$editions'))
          .timeout(_timeout);
      if (resp.statusCode == 200) {
        final data = (jsonDecode(resp.body) as Map<String, dynamic>)['data'];
        if (data is List) {
          final ayahs = _zipEditions(
            data,
            translationEdition: translationEdition,
            reciter: reciter,
            surahNumber: number,
          );
          if (ayahs.isNotEmpty) {
            await prefs.setString(
              cacheKey,
              jsonEncode(ayahs.map((a) => a.toJson()).toList()),
            );
            return ayahs;
          }
        }
      }
    } catch (e) {
      debugPrint('QuranService.fetchSurah error: $e');
    }

    // Offline / error fallback to cache.
    final cached = prefs.getString(cacheKey);
    if (cached != null) {
      try {
        final list = jsonDecode(cached) as List;
        return list
            .whereType<Map<String, dynamic>>()
            .map(Ayah.fromJson)
            .toList(growable: false);
      } catch (_) {}
    }
    return const [];
  }

  List<Ayah> _zipEditions(
    List<dynamic> editionsData, {
    required String? translationEdition,
    required String reciter,
    required int surahNumber,
  }) {
    Map<String, dynamic>? findEdition(String identifier) {
      for (final e in editionsData) {
        if (e is Map<String, dynamic>) {
          final ed = e['edition'];
          if (ed is Map && ed['identifier'] == identifier) return e;
        }
      }
      return null;
    }

    final arabic = findEdition(_arabicEdition);
    if (arabic == null) return const [];
    final arabicAyahs = (arabic['ayahs'] as List?) ?? const [];

    final translation = translationEdition == null
        ? null
        : findEdition(translationEdition);
    final translationAyahs = (translation?['ayahs'] as List?) ?? const [];

    final result = <Ayah>[];
    for (var i = 0; i < arabicAyahs.length; i++) {
      final a = arabicAyahs[i];
      if (a is! Map) continue;
      final tr = i < translationAyahs.length ? translationAyahs[i] : null;
      final numberInSurah = (a['numberInSurah'] as num?)?.toInt() ?? (i + 1);
      result.add(
        Ayah(
          numberInSurah: numberInSurah,
          arabic: a['text'] as String? ?? '',
          translation: tr is Map ? tr['text'] as String? : null,
          audioUrl: audioUrl(reciter, surahNumber, numberInSurah),
        ),
      );
    }
    return result;
  }
}
