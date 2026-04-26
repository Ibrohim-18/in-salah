import 'dart:convert';
import 'dart:ui';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'insforge_service.dart';

export 'insforge_service.dart' show TranslationOutcome;

class TranslationService {
  static const _targetLangKey = 'translation_target_lang';
  static const _cacheKeyPrefix = 'translation_cache_';

  static final instance = TranslationService._();
  TranslationService._();

  static const supportedLanguages = <TranslationLanguage>[
    TranslationLanguage('en', 'English', 'english'),
    TranslationLanguage('ru', 'Russian', 'russian'),
    TranslationLanguage('ar', 'Arabic', 'arabicLang'),
    TranslationLanguage('tr', 'Turkish', 'turkish'),
    TranslationLanguage('id', 'Indonesian', 'indonesian'),
    TranslationLanguage('ms', 'Malay', 'malay'),
    TranslationLanguage('ur', 'Urdu', 'urdu'),
    TranslationLanguage('fr', 'French', 'french'),
    TranslationLanguage('es', 'Spanish', 'spanish'),
    TranslationLanguage('de', 'German', 'german'),
    TranslationLanguage('it', 'Italian', 'italian'),
    TranslationLanguage('pt', 'Portuguese', 'portuguese'),
    TranslationLanguage('fa', 'Persian', 'persian'),
    TranslationLanguage('bn', 'Bengali', 'bengali'),
    TranslationLanguage('hi', 'Hindi', 'hindi'),
    TranslationLanguage('ha', 'Hausa', 'hausa'),
    TranslationLanguage('sw', 'Swahili', 'swahili'),
    TranslationLanguage('uz', 'Uzbek', 'uzbek'),
    TranslationLanguage('kk', 'Kazakh', 'kazakh'),
    TranslationLanguage('az', 'Azerbaijani', 'azerbaijani'),
    TranslationLanguage('tg', 'Tajik', 'tajik'),
    TranslationLanguage('zh', 'Chinese', 'chinese'),
    TranslationLanguage('ja', 'Japanese', 'japanese'),
    TranslationLanguage('ko', 'Korean', 'korean'),
  ];

  Future<TranslationLanguage> getTargetLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_targetLangKey);
    if (stored != null) {
      final match = supportedLanguages.where((l) => l.code == stored);
      if (match.isNotEmpty) return match.first;
    }
    final locale = PlatformDispatcher.instance.locale.languageCode;
    final localeMatch = supportedLanguages.where((l) => l.code == locale);
    return localeMatch.isNotEmpty ? localeMatch.first : supportedLanguages.first;
  }

  Future<void> setTargetLanguage(TranslationLanguage language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_targetLangKey, language.code);
  }

  String _cacheKey(String text, String langCode) {
    final hash = sha1.convert(utf8.encode(text)).toString();
    return '$_cacheKeyPrefix${langCode}_$hash';
  }

  Future<TranslationOutcome> translate(
    String text,
    TranslationLanguage language,
  ) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const TranslationOutcome(errorCode: 'empty');

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = _cacheKey(trimmed, language.code);
    final cached = prefs.getString(cacheKey);
    if (cached != null) return TranslationOutcome(translation: cached);

    final outcome = await InsforgeService.instance.translateText(
      text: trimmed,
      targetLang: language.name,
    );
    if (outcome.isSuccess) {
      await prefs.setString(cacheKey, outcome.translation!);
    }
    return outcome;
  }
}

class TranslationLanguage {
  final String code;
  final String name;
  final String nameKey;

  const TranslationLanguage(this.code, this.name, this.nameKey);
}
