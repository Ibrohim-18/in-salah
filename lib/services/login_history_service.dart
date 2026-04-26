import 'package:shared_preferences/shared_preferences.dart';

class LoginHistoryService {
  static const _storageKey = 'login_email_history';
  static const _maxItems = 5;

  Future<List<String>> loadEmailHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_storageKey) ?? const [];
    return _normalize(stored);
  }

  Future<List<String>> saveEmail(String email) async {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty) {
      return loadEmailHistory();
    }

    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_storageKey) ?? const [];
    final updated = _normalize([normalizedEmail, ...existing]);
    await prefs.setStringList(_storageKey, updated);
    return updated;
  }

  List<String> _normalize(List<String> emails) {
    final unique = <String>[];

    for (final email in emails) {
      final trimmed = email.trim();
      if (trimmed.isEmpty) continue;

      final exists = unique.any(
        (savedEmail) => savedEmail.toLowerCase() == trimmed.toLowerCase(),
      );
      if (!exists) {
        unique.add(trimmed);
      }
      if (unique.length == _maxItems) {
        break;
      }
    }

    return unique;
  }
}
