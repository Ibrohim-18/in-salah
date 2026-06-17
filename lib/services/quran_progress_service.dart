import 'package:shared_preferences/shared_preferences.dart';
import 'insforge_service.dart';

/// Tracks which ayahs the user has read, scoped per user (or 'guest'), mirroring
/// the scoping approach of [MissedPrayerService]. Stored locally only.
class QuranProgressService {
  static const String _readPrefix = 'quran_read_';
  static const String _reciterKey = 'quran_reciter';
  static const String _defaultReciter = 'ar.alafasy';
  static const String _fontKey = 'quran_font';
  static const String _defaultFont = 'madina';
  static const String _readerModeKey = 'quran_reader_mode';
  static const String _defaultReaderMode = 'dark';
  static const String _guestScope = 'guest';

  /// Total ayahs in the whole Quran (used as the overall-progress denominator).
  static const int totalAyahs = 6236;

  String _scopeId([String? userId]) {
    return userId ?? InsforgeService.instance.currentUser?.id ?? _guestScope;
  }

  String _surahKey(int surah, {String? userId}) =>
      '$_readPrefix${_scopeId(userId)}_$surah';

  Future<Set<int>> _readAyahs(int surah, {String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_surahKey(surah, userId: userId));
    if (list == null) return <int>{};
    return list.map(int.tryParse).whereType<int>().toSet();
  }

  Future<bool> isAyahRead(int surah, int ayah, {String? userId}) async {
    final read = await _readAyahs(surah, userId: userId);
    return read.contains(ayah);
  }

  /// Marks/unmarks a single ayah. Returns the new read state.
  Future<bool> toggleAyah(
    int surah,
    int ayah, {
    bool? value,
    String? userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final read = await _readAyahs(surah, userId: userId);
    final newValue = value ?? !read.contains(ayah);
    if (newValue) {
      read.add(ayah);
    } else {
      read.remove(ayah);
    }
    await prefs.setStringList(
      _surahKey(surah, userId: userId),
      read.map((e) => e.toString()).toList(),
    );
    return newValue;
  }

  /// Marks all ayahs of a surah read (1..total) or clears them.
  Future<void> setSurahRead(
    int surah,
    int total,
    bool read, {
    String? userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!read) {
      await prefs.remove(_surahKey(surah, userId: userId));
      return;
    }
    final all = List.generate(total, (i) => (i + 1).toString());
    await prefs.setStringList(_surahKey(surah, userId: userId), all);
  }

  Future<int> surahReadCount(int surah, {String? userId}) async {
    final read = await _readAyahs(surah, userId: userId);
    return read.length;
  }

  Future<Set<int>> readAyahsOf(int surah, {String? userId}) =>
      _readAyahs(surah, userId: userId);

  /// Sum of read ayahs across all 114 surahs for the current scope.
  Future<int> overallReadCount({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final scope = _scopeId(userId);
    final prefix = '$_readPrefix${scope}_';
    int total = 0;
    for (final key in prefs.getKeys()) {
      if (key.startsWith(prefix)) {
        total += prefs.getStringList(key)?.length ?? 0;
      }
    }
    return total;
  }

  Future<String> getReciter() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_reciterKey) ?? _defaultReciter;
  }

  Future<void> setReciter(String reciterId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_reciterKey, reciterId);
  }

  Future<String> getFont() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_fontKey) ?? _defaultFont;
  }

  Future<void> setFont(String fontId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fontKey, fontId);
  }

  Future<String> getReaderMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_readerModeKey) ?? _defaultReaderMode;
  }

  Future<void> setReaderMode(String modeId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_readerModeKey, modeId);
  }
}
