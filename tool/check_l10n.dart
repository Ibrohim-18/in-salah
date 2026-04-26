// Localization audit tool.
//
// Run from project root:
//   dart run tool/check_l10n.dart
//
// Reports:
//   1. Keys used in lib/ but missing from any locale JSON.
//   2. Keys present in JSON but never used in lib/.
//   3. Suspicious hardcoded English strings inside Text(...) widgets.
//   4. Cross-locale parity: keys missing from one locale but present in another.

import 'dart:convert';
import 'dart:io';

const _localesDir = 'assets/l10n';
const _libDir = 'lib';
const _locales = ['en', 'ru', 'ar', 'tg'];

// Heuristic: hardcoded user-facing strings inside common UI sites.
// Catches Text('...'), Text("...") and the prefixed equivalents used in
// SnackBar / AlertDialog / Tooltip / InputDecoration.
final _hardcodedSites = <RegExp>[
  RegExp(r'''Text\(\s*(?:'([^'\n]{3,})'|"([^"\n]{3,})")'''),
  RegExp(r'''hintText\s*:\s*(?:'([^'\n]{3,})'|"([^"\n]{3,})")'''),
  RegExp(r'''labelText\s*:\s*(?:'([^'\n]{3,})'|"([^"\n]{3,})")'''),
  RegExp(r'''helperText\s*:\s*(?:'([^'\n]{3,})'|"([^"\n]{3,})")'''),
  RegExp(r'''errorText\s*:\s*(?:'([^'\n]{3,})'|"([^"\n]{3,})")'''),
  RegExp(r'''tooltip\s*:\s*(?:'([^'\n]{3,})'|"([^"\n]{3,})")'''),
  RegExp(r'''message\s*:\s*(?:'([^'\n]{3,})'|"([^"\n]{3,})")'''),
  RegExp(r'''title\s*:\s*(?:'([^'\n]{3,})'|"([^"\n]{3,})")'''),
  RegExp(r'''subtitle\s*:\s*(?:'([^'\n]{3,})'|"([^"\n]{3,})")'''),
];

// translate('key') or translate("key").
// Skip dynamic keys containing $ — those are interpolation patterns and
// must be hand-verified.
final _translateCallRe = RegExp(
  r'''translate\(\s*(?:'([^'\n]+)'|"([^"\n]+)")\s*\)''',
);

// String literals (used to detect indirect references like nameKey: 'foo').
final _stringLiteralRe = RegExp(
  r'''(?<![A-Za-z0-9_$])(?:'([^'\\\n]+)'|"([^"\\\n]+)")''',
);

// Brand strings and other accepted hardcoded values.
const _allowlist = <String>{
  'In Salah',     // App brand (MaterialApp.title)
  'IN SALAH',     // App brand (loading screen)
};

// Heuristic for ignoring non-user strings inside Text(...).
bool _isProbablyUiText(String s) {
  final trimmed = s.trim();
  if (_allowlist.contains(trimmed)) return false;
  if (trimmed.isEmpty) return false;
  if (trimmed.length < 3) return false;
  // Skip pure punctuation / symbols.
  if (!RegExp(r'[A-Za-z]').hasMatch(trimmed)) return false;
  // Skip single-word strings that look like identifiers, icons, or numerics.
  final words = trimmed.split(RegExp(r'\s+'));
  if (words.length == 1) {
    // Single word — only flag if it looks like a sentence word (capital + lowercase letters)
    // and isn't an obvious enum/constant.
    if (RegExp(r'^[a-z_]+$').hasMatch(trimmed)) return false; // snake_case
    if (RegExp(r'^[A-Z_]+$').hasMatch(trimmed)) return false; // SCREAMING
    if (RegExp(r'^\$').hasMatch(trimmed)) return false; // interpolation only
  }
  // Skip if starts with $ (pure interpolation like '$count')
  if (trimmed.startsWith(r'$')) return false;
  // Skip format-pattern-looking strings.
  if (RegExp(r'^[dMyEHm:\-/\s,\.]+$').hasMatch(trimmed)) return false;
  return true;
}

Future<Map<String, Set<String>>> _loadLocaleKeys() async {
  final result = <String, Set<String>>{};
  for (final loc in _locales) {
    final file = File('$_localesDir/$loc.json');
    if (!file.existsSync()) {
      stderr.writeln('Missing locale file: ${file.path}');
      continue;
    }
    final raw = await file.readAsString();
    final map = json.decode(raw) as Map<String, dynamic>;
    result[loc] = map.keys.toSet();
  }
  return result;
}

class _Hit {
  final String file;
  final int line;
  final String text;
  _Hit(this.file, this.line, this.text);
}

class _ScanResult {
  final Set<String> staticKeys;        // exact keys from translate('foo')
  final List<String> dynamicPatterns;  // keys with $ interpolation
  final Set<String> stringLiterals;    // every string literal found
  final List<_Hit> suspicious;
  _ScanResult(
    this.staticKeys,
    this.dynamicPatterns,
    this.stringLiterals,
    this.suspicious,
  );
}

Future<_ScanResult> _scanLib() async {
  final staticKeys = <String>{};
  final dynamicPatterns = <String>[];
  final stringLiterals = <String>{};
  final suspicious = <_Hit>[];
  final dir = Directory(_libDir);
  if (!dir.existsSync()) {
    stderr.writeln('lib/ not found');
    return _ScanResult(staticKeys, dynamicPatterns, stringLiterals, suspicious);
  }
  await for (final entity in dir.list(recursive: true)) {
    if (entity is! File) continue;
    if (!entity.path.endsWith('.dart')) continue;
    final lines = await entity.readAsLines();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      // 1. translate() calls.
      for (final m in _translateCallRe.allMatches(line)) {
        final key = m.group(1) ?? m.group(2);
        if (key == null) continue;
        if (key.contains(r'$')) {
          dynamicPatterns.add(key);
        } else {
          staticKeys.add(key);
        }
      }

      // 2. All string literals (for indirect nameKey/titleKey usage).
      for (final m in _stringLiteralRe.allMatches(line)) {
        final s = m.group(1) ?? m.group(2);
        if (s != null) stringLiterals.add(s);
      }

      // 3. Hardcoded UI sites — skip lines that are routing to translate().
      if (line.contains('translate(')) continue;
      for (final re in _hardcodedSites) {
        for (final m in re.allMatches(line)) {
          final raw = m.group(1) ?? m.group(2) ?? '';
          if (_isProbablyUiText(raw)) {
            suspicious.add(_Hit(entity.path, i + 1, raw));
          }
        }
      }
    }
  }
  return _ScanResult(staticKeys, dynamicPatterns, stringLiterals, suspicious);
}

// Match a JSON key against dynamic patterns like 'hijriMonth$month'.
bool _matchesDynamic(String key, List<String> patterns) {
  for (final pat in patterns) {
    final regex = RegExp(
      '^${RegExp.escape(pat).replaceAll(RegExp(r'\\\$\w+(?:\\\{[^}]*\\\})?'), r'.+')}\$',
    );
    if (regex.hasMatch(key)) return true;
  }
  return false;
}

void _printSection(String title) {
  stdout.writeln('');
  stdout.writeln('═══ $title ═══');
}

Future<int> main() async {
  final localeKeys = await _loadLocaleKeys();
  final scan = await _scanLib();

  if (localeKeys.isEmpty) {
    stderr.writeln('No locale files loaded — aborting.');
    return 2;
  }

  // Effective "used" keys: explicit translate() calls + JSON keys that appear
  // verbatim as string literals (catches nameKey/titleKey patterns) + JSON
  // keys matching a dynamic pattern (hijriMonth$month → hijriMonth1..12).
  final usedKeys = <String>{...scan.staticKeys};
  final unionAll = <String>{};
  for (final keys in localeKeys.values) {
    unionAll.addAll(keys);
  }
  for (final k in unionAll) {
    if (scan.stringLiterals.contains(k)) usedKeys.add(k);
    if (_matchesDynamic(k, scan.dynamicPatterns)) usedKeys.add(k);
  }

  var problems = 0;

  _printSection('1. Static translate() keys MISSING from JSON');
  // Only static (non-dynamic) keys can be cross-checked here.
  for (final loc in _locales) {
    final keys = localeKeys[loc] ?? <String>{};
    final missing = scan.staticKeys.difference(keys).toList()..sort();
    if (missing.isEmpty) {
      stdout.writeln('  [$loc] OK — all ${scan.staticKeys.length} static keys present.');
    } else {
      problems += missing.length;
      stdout.writeln('  [$loc] MISSING ${missing.length}:');
      for (final k in missing) {
        stdout.writeln('    - $k');
      }
    }
  }

  _printSection('2. Cross-locale parity (key in some locales but not others)');
  final parityMissing = <String, List<String>>{};
  for (final k in unionAll) {
    final missingFrom = <String>[];
    for (final loc in _locales) {
      if (!(localeKeys[loc]?.contains(k) ?? false)) missingFrom.add(loc);
    }
    if (missingFrom.isNotEmpty && missingFrom.length < _locales.length) {
      parityMissing[k] = missingFrom;
    }
  }
  if (parityMissing.isEmpty) {
    stdout.writeln('  OK — all locales have identical key sets.');
  } else {
    problems += parityMissing.length;
    final entries = parityMissing.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    for (final e in entries) {
      stdout.writeln('  - ${e.key}  (missing from: ${e.value.join(", ")})');
    }
  }

  _printSection('3. JSON keys not referenced anywhere (truly orphaned)');
  final enKeys = localeKeys['en'] ?? <String>{};
  final orphaned = enKeys.difference(usedKeys).toList()..sort();
  if (orphaned.isEmpty) {
    stdout.writeln('  OK — every JSON key is referenced (directly, indirectly, or dynamically).');
  } else {
    stdout.writeln('  ${orphaned.length} orphaned:');
    for (final k in orphaned) {
      stdout.writeln('    - $k');
    }
  }

  _printSection('4. Hardcoded user-facing strings in lib/');
  if (scan.suspicious.isEmpty) {
    stdout.writeln('  OK — no hardcoded UI strings detected.');
  } else {
    problems += scan.suspicious.length;
    final byFile = <String, List<_Hit>>{};
    for (final h in scan.suspicious) {
      byFile.putIfAbsent(h.file, () => []).add(h);
    }
    final files = byFile.keys.toList()..sort();
    for (final f in files) {
      stdout.writeln('  $f:');
      for (final h in byFile[f]!) {
        stdout.writeln('    L${h.line}: "${h.text}"');
      }
    }
  }

  _printSection('Summary');
  stdout.writeln('  Static translate() keys: ${scan.staticKeys.length}');
  stdout.writeln('  Dynamic translate() patterns: ${scan.dynamicPatterns.length}');
  stdout.writeln('  Effective used keys (incl. indirect): ${usedKeys.length}');
  for (final loc in _locales) {
    stdout.writeln('  $loc.json keys: ${localeKeys[loc]?.length ?? 0}');
  }
  stdout.writeln('  Hardcoded UI strings: ${scan.suspicious.length}');
  stdout.writeln('  Total problems: $problems');

  return problems == 0 ? 0 : 1;
}
