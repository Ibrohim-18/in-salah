import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One rendered unit on a mushaf page: a surah header, a bismillah line, or a
/// justified line of ayah words.
enum MushafRowType { header, bismillah, line }

/// A single word glyph on the page. [code] is the QCF `code_v2` private-use
/// character; it renders as one ligature in the matching per-page font.
class MushafWord {
  final String code;
  final int surah;
  final int ayah;
  final bool isEnd; // true for the end-of-ayah rosette glyph

  const MushafWord({
    required this.code,
    required this.surah,
    required this.ayah,
    required this.isEnd,
  });

  Map<String, dynamic> toJson() => {
    'c': code,
    's': surah,
    'a': ayah,
    if (isEnd) 'e': 1,
  };

  factory MushafWord.fromJson(Map<String, dynamic> j) => MushafWord(
    code: j['c'] as String? ?? '',
    surah: (j['s'] as num?)?.toInt() ?? 0,
    ayah: (j['a'] as num?)?.toInt() ?? 0,
    isEnd: j['e'] == 1,
  );
}

class MushafRow {
  final MushafRowType type;
  final int surah; // for header rows
  final int lineNumber; // for line rows
  final List<MushafWord> words; // for line rows

  const MushafRow({
    required this.type,
    this.surah = 0,
    this.lineNumber = 0,
    this.words = const [],
  });

  Map<String, dynamic> toJson() => {
    't': type.index,
    if (type == MushafRowType.header) 's': surah,
    if (type == MushafRowType.line) 'l': lineNumber,
    if (type == MushafRowType.line)
      'w': words.map((w) => w.toJson()).toList(),
  };

  factory MushafRow.fromJson(Map<String, dynamic> j) => MushafRow(
    type: MushafRowType.values[(j['t'] as num).toInt()],
    surah: (j['s'] as num?)?.toInt() ?? 0,
    lineNumber: (j['l'] as num?)?.toInt() ?? 0,
    words: (j['w'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(MushafWord.fromJson)
            .toList() ??
        const [],
  );
}

class MushafPageData {
  final int page;
  final int juz;
  final List<MushafRow> rows;

  const MushafPageData({
    required this.page,
    required this.juz,
    required this.rows,
  });

  Map<String, dynamic> toJson() => {
    'p': page,
    'j': juz,
    'r': rows.map((r) => r.toJson()).toList(),
  };

  factory MushafPageData.fromJson(Map<String, dynamic> j) => MushafPageData(
    page: (j['p'] as num).toInt(),
    juz: (j['j'] as num?)?.toInt() ?? 0,
    rows: (j['r'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(MushafRow.fromJson)
            .toList() ??
        const [],
  );
}

/// Fetches Madinah-mushaf page layouts (QCF `code_v2` glyph codes grouped into
/// printed lines) from the free, key-less Quran.com API, and lazily downloads +
/// registers the matching per-page KFGQPC fonts (plain V2 / colour-tajweed V4)
/// from the Quran Foundation CDN. Everything is cached so revisited pages work
/// offline.
class MushafService {
  static const _api = 'https://api.quran.com/api/v4';
  static const _fontCdn = 'https://verses.quran.foundation/fonts/quran/hafs';
  static const _timeout = Duration(seconds: 20);
  static const int totalPages = 604;

  final Set<String> _loadedFonts = {};

  // ----- page layout -----

  Future<MushafPageData?> fetchPage(int page) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'mushaf_page_v2_$page';
    try {
      final data = await _fetchRows(page);
      if (data != null && data.rows.isNotEmpty) {
        await prefs.setString(cacheKey, jsonEncode(data.toJson()));
        return data;
      }
    } catch (e) {
      debugPrint('MushafService.fetchPage($page): $e');
    }
    final cached = prefs.getString(cacheKey);
    if (cached != null) {
      try {
        return MushafPageData.fromJson(
            jsonDecode(cached) as Map<String, dynamic>);
      } catch (_) {}
    }
    return null;
  }

  Future<MushafPageData?> _fetchRows(int page) async {
    final verses = <Map<String, dynamic>>[];
    var apiPage = 1;
    var juz = 0;
    while (true) {
      final uri = Uri.parse(
        '$_api/verses/by_page/$page'
        '?words=true&word_fields=code_v2,line_number,char_type_name'
        '&per_page=50&page=$apiPage',
      );
      final resp = await http.get(uri).timeout(_timeout);
      if (resp.statusCode != 200) {
        return verses.isEmpty ? null : _buildPage(page, juz, verses);
      }
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final vs = (body['verses'] as List?) ?? const [];
      for (final v in vs.whereType<Map<String, dynamic>>()) {
        verses.add(v);
        juz = (v['juz_number'] as num?)?.toInt() ?? juz;
      }
      final next = (body['pagination'] as Map<String, dynamic>?)?['next_page'];
      if (next == null) break;
      apiPage = (next as num).toInt();
    }
    return _buildPage(page, juz, verses);
  }

  MushafPageData _buildPage(
    int page,
    int juz,
    List<Map<String, dynamic>> verses,
  ) {
    final rows = <MushafRow>[];
    int? currentLine;
    var lineWords = <MushafWord>[];

    void flushLine() {
      if (lineWords.isNotEmpty) {
        rows.add(MushafRow(
          type: MushafRowType.line,
          lineNumber: currentLine ?? 0,
          words: lineWords,
        ));
        lineWords = [];
      }
      currentLine = null;
    }

    for (final v in verses) {
      final key = (v['verse_key'] as String? ?? '0:0').split(':');
      final surah = int.tryParse(key.first) ?? 0;
      final ayah = int.tryParse(key.length > 1 ? key[1] : '0') ?? 0;

      if (ayah == 1) {
        flushLine();
        rows.add(MushafRow(type: MushafRowType.header, surah: surah));
        if (surah != 1 && surah != 9) {
          rows.add(const MushafRow(type: MushafRowType.bismillah));
        }
      }

      final words = (v['words'] as List?)?.whereType<Map>() ?? const [];
      for (final w in words) {
        final ln = (w['line_number'] as num?)?.toInt() ?? currentLine ?? 0;
        final code = (w['code_v2'] as String?) ?? (w['text'] as String?) ?? '';
        if (code.isEmpty) continue;
        final isEnd = (w['char_type_name'] as String?) == 'end';
        if (currentLine != null && ln != currentLine) flushLine();
        currentLine = ln;
        lineWords.add(MushafWord(
          code: code,
          surah: surah,
          ayah: ayah,
          isEnd: isEnd,
        ));
      }
    }
    flushLine();
    return MushafPageData(page: page, juz: juz, rows: rows);
  }

  // ----- fonts -----

  /// Ensures the per-page font (plain V2 or colour-tajweed V4) is downloaded,
  /// cached and registered with the engine. Returns the font family name to use
  /// in a [TextStyle], or null if it could not be loaded.
  Future<String?> ensurePageFont(int page, {required bool tajweed}) async {
    final family = '${tajweed ? 'QCFV4' : 'QCFV2'}P$page';
    if (_loadedFonts.contains(family)) return family;
    try {
      final bytes = await _fontBytes(page, tajweed);
      if (bytes == null) return null;
      final loader = FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
      _loadedFonts.add(family);
      return family;
    } catch (e) {
      debugPrint('MushafService.ensurePageFont($page,$tajweed): $e');
      return null;
    }
  }

  Future<Uint8List?> _fontBytes(int page, bool tajweed) async {
    final dir = await getApplicationSupportDirectory();
    final fontDir = Directory('${dir.path}/mushaf_fonts');
    if (!await fontDir.exists()) await fontDir.create(recursive: true);
    final file =
        File('${fontDir.path}/${tajweed ? 'v4' : 'v2'}_p$page.ttf');
    if (await file.exists()) return file.readAsBytes();

    final variant = tajweed ? 'v4/colrv1' : 'v2';
    final url = '$_fontCdn/$variant/ttf/p$page.ttf';
    final resp = await http.get(Uri.parse(url)).timeout(_timeout);
    if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
      await file.writeAsBytes(resp.bodyBytes);
      return resp.bodyBytes;
    }
    return null;
  }
}

/// Standard Madani 604-page mushaf: the page each surah (1-114) starts on.
/// Lets the reader open the page view at the surah the user tapped.
const List<int> kSurahStartPages = [
  1, 2, 50, 77, 106, 128, 151, 177, 187, 208, 221, 235, 249, 255, 262, 267,
  282, 293, 305, 312, 322, 332, 342, 350, 359, 367, 377, 385, 396, 404, 411,
  415, 418, 428, 434, 440, 446, 453, 458, 467, 477, 483, 489, 496, 499, 502,
  507, 511, 515, 518, 520, 523, 526, 528, 531, 534, 537, 542, 545, 549, 551,
  553, 554, 556, 558, 560, 562, 564, 566, 568, 570, 572, 574, 575, 577, 578,
  580, 582, 583, 585, 586, 587, 587, 589, 590, 591, 591, 592, 593, 594, 595,
  595, 596, 596, 597, 597, 598, 598, 599, 599, 600, 600, 601, 601, 601, 602,
  602, 602, 603, 603, 603, 604, 604, 604,
];

int mushafStartPageForSurah(int surah) {
  if (surah < 1 || surah > kSurahStartPages.length) return 1;
  return kSurahStartPages[surah - 1];
}
