import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_settings.dart';

class InsforgeUser {
  final String id;
  final String email;
  final bool emailVerified;
  final String? avatarUrl;
  final String? displayName;

  InsforgeUser({
    required this.id,
    required this.email,
    required this.emailVerified,
    this.avatarUrl,
    this.displayName,
  });

  factory InsforgeUser.fromJson(Map<String, dynamic> json) => InsforgeUser(
    id: json['id'] as String,
    email: json['email'] as String,
    emailVerified: json['emailVerified'] as bool? ?? false,
    avatarUrl: _extractAvatarUrl(json),
    displayName: _extractDisplayName(json),
  );

  static String? _extractString(Map source, List<String> keys) {
    for (final key in keys) {
      final v = source[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  static String? _extractAvatarUrl(Map<String, dynamic> json) {
    const keys = ['picture', 'avatar_url', 'avatarUrl', 'photoUrl'];
    String? raw;
    for (final key in keys) {
      final v = json[key];
      if (v is String && v.startsWith('http')) {
        raw = v;
        break;
      }
    }
    if (raw == null) {
      final meta = json['user_metadata'] ?? json['userMetadata'];
      if (meta is Map) {
        for (final key in keys) {
          final v = meta[key];
          if (v is String && v.startsWith('http')) {
            raw = v;
            break;
          }
        }
      }
    }
    if (raw == null) {
      final identities = json['identities'];
      if (identities is List) {
        for (final ident in identities) {
          if (ident is Map) {
            final data = ident['identity_data'] ?? ident['identityData'];
            if (data is Map) {
              for (final key in keys) {
                final v = data[key];
                if (v is String && v.startsWith('http')) {
                  raw = v;
                  break;
                }
              }
            }
          }
          if (raw != null) break;
        }
      }
    }
    if (raw == null) return null;
    return _upscaleGoogleAvatar(raw);
  }

  static String _upscaleGoogleAvatar(String url) {
    if (!url.contains('googleusercontent.com')) return url;
    final regex = RegExp(r'=s\d+-c');
    if (regex.hasMatch(url)) return url.replaceAll(regex, '=s256-c');
    return url.contains('=') ? url : '$url=s256-c';
  }

  static String? _extractDisplayName(Map<String, dynamic> json) {
    final direct = _extractString(json, const ['name', 'displayName', 'full_name', 'fullName']);
    if (direct != null) return direct;

    final meta = json['user_metadata'] ?? json['userMetadata'];
    if (meta is Map) {
      final fromMeta = _extractString(
        meta,
        const ['name', 'full_name', 'fullName', 'displayName'],
      );
      if (fromMeta != null) return fromMeta;
      final given = _extractString(meta, const ['given_name', 'givenName']);
      final family = _extractString(meta, const ['family_name', 'familyName']);
      if (given != null || family != null) {
        return [given, family].whereType<String>().join(' ');
      }
    }

    final identities = json['identities'];
    if (identities is List) {
      for (final ident in identities) {
        if (ident is Map) {
          final data = ident['identity_data'] ?? ident['identityData'];
          if (data is Map) {
            final fromIdent = _extractString(
              data,
              const ['name', 'full_name', 'fullName'],
            );
            if (fromIdent != null) return fromIdent;
            final given = _extractString(data, const ['given_name', 'givenName']);
            final family = _extractString(data, const ['family_name', 'familyName']);
            if (given != null || family != null) {
              return [given, family].whereType<String>().join(' ');
            }
          }
        }
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'emailVerified': emailVerified,
    if (avatarUrl != null) 'avatar_url': avatarUrl,
    if (displayName != null) 'name': displayName,
  };
}

class TranslationOutcome {
  final String? translation;
  final String? errorCode;
  const TranslationOutcome({this.translation, this.errorCode});

  bool get isSuccess => translation != null;
  bool get isAuthRequired => errorCode == 'auth_required';
}

class InsforgeAuthException implements Exception {
  final String message;
  InsforgeAuthException(this.message);
  @override
  String toString() => message;
}

class InsforgeService {
  static const _base = 'https://fn43ntwx.us-east.insforge.app';
  static const _oauthRedirectUri = 'app.insalah.prayer://auth-callback';
  static const _accessTokenStorageKey = 'insforge_access_token';
  static const _refreshTokenStorageKey = 'insforge_refresh_token';
  static const _pkceVerifierStorageKey = 'insforge_pkce_verifier';
  static const _userStorageKey = 'insforge_user';
  static const _anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3OC0xMjM0LTU2NzgtOTBhYi1jZGVmMTIzNDU2NzgiLCJlbWFpbCI6ImFub25AaW5zZm9yZ2UuY29tIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUxMjA2NzB9.3MtSQWt4ommr2dHMAkCZODcAqYNOMwETtvRR5rT0Pns';

  static final instance = InsforgeService._();
  InsforgeService._();

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  InsforgeUser? _user;
  String? _accessToken;
  String? _refreshToken;
  String? _pkceVerifier;

  InsforgeUser? get currentUser => _user;
  String? get accessToken => _accessToken;

  final _authController = StreamController<InsforgeUser?>.broadcast();
  Stream<InsforgeUser?> get onAuthStateChange => _authController.stream;

  static const _oauthTimeout = Duration(seconds: 20);
  // Hard ceiling on every auth/DB request so a stalled network can never hang
  // the loading screen or a sign-in attempt forever.
  static const _httpTimeout = Duration(seconds: 20);

  Map<String, String> get _authHeaders => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${_accessToken ?? _anonKey}',
  };

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    String? token;
    String? refresh;
    try {
      await _migrateLegacyTokens(prefs);
      _pkceVerifier = await _secureStorage.read(key: _pkceVerifierStorageKey);
      token = await _secureStorage.read(key: _accessTokenStorageKey);
      refresh = await _secureStorage.read(key: _refreshTokenStorageKey);
    } catch (e) {
      // Encrypted storage can fail to decrypt after an app update or keystore
      // reset (a common Android crash). Never let that block startup: drop the
      // unreadable entries and continue as a logged-out session.
      debugPrint('Secure storage read failed, clearing: $e');
      try {
        await _secureStorage.deleteAll();
      } catch (_) {}
      return;
    }
    if (token == null) return;

    // Try to validate the current token
    try {
      final resp = await http
          .get(
            Uri.parse('$_base/api/auth/sessions/current'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        _user = InsforgeUser.fromJson(data['user'] as Map<String, dynamic>);
        _accessToken = token;
        _refreshToken = refresh;
        await prefs.setString(_userStorageKey, jsonEncode(_user!.toJson()));
        _authController.add(_user);
        return;
      }
      // Only try refresh if server explicitly rejected the token (401/403)
      if (resp.statusCode == 401 || resp.statusCode == 403) {
        if (refresh != null) {
          await _doRefresh(refresh);
        }
        return;
      }
    } catch (_) {
      // Network error -- keep stored tokens and restore session optimistically
    }

    // Offline or server error -- trust stored tokens and cached user info
    _accessToken = token;
    _refreshToken = refresh;
    final cachedUserJson = prefs.getString(_userStorageKey);
    if (cachedUserJson != null) {
      try {
        _user = InsforgeUser.fromJson(
          jsonDecode(cachedUserJson) as Map<String, dynamic>,
        );
      } catch (_) {
        _user = null;
      }
    }
    _authController.add(_user);
  }

  /// Moves tokens persisted by older builds out of plaintext
  /// SharedPreferences and into encrypted secure storage, once.
  Future<void> _migrateLegacyTokens(SharedPreferences prefs) async {
    for (final key in [
      _accessTokenStorageKey,
      _refreshTokenStorageKey,
      _pkceVerifierStorageKey,
    ]) {
      final legacy = prefs.getString(key);
      if (legacy != null) {
        await _secureStorage.write(key: key, value: legacy);
        await prefs.remove(key);
      }
    }
  }

  Future<void> _doRefresh(String refreshToken) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$_base/api/auth/refresh?client_type=mobile'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        await _applySession(jsonDecode(resp.body) as Map<String, dynamic>);
        return;
      }
      // Only clear session if server explicitly rejected the refresh token
      if (resp.statusCode == 401 || resp.statusCode == 403) {
        await _clearSession();
        return;
      }
      // Other server errors (500, etc.) -- keep tokens, don't logout
    } catch (_) {
      // Network error -- keep tokens, don't logout
    }
  }

  Future<Map<String, dynamic>> _parse(http.Response resp) {
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode >= 400) {
      throw InsforgeAuthException(
        data['message'] as String? ?? 'Error ${resp.statusCode}',
      );
    }
    return Future.value(data);
  }

  Future<void> _applySession(Map<String, dynamic> data) async {
    _user = InsforgeUser.fromJson(data['user'] as Map<String, dynamic>);
    _accessToken = data['accessToken'] as String;
    _refreshToken = data['refreshToken'] as String?;
    _authController.add(_user);
    final prefs = await SharedPreferences.getInstance();
    await _secureStorage.write(key: _accessTokenStorageKey, value: _accessToken!);
    await prefs.setString(_userStorageKey, jsonEncode(_user!.toJson()));
    if (_refreshToken != null) {
      await _secureStorage.write(
        key: _refreshTokenStorageKey,
        value: _refreshToken!,
      );
    }
  }

  Future<void> _clearSession() async {
    _user = null;
    _accessToken = null;
    _refreshToken = null;
    _authController.add(null);
    final prefs = await SharedPreferences.getInstance();
    await _secureStorage.delete(key: _accessTokenStorageKey);
    await _secureStorage.delete(key: _refreshTokenStorageKey);
    await prefs.remove(_userStorageKey);
  }

  Future<void> _persistPkceVerifier(String? verifier) async {
    _pkceVerifier = verifier;
    if (verifier == null) {
      await _secureStorage.delete(key: _pkceVerifierStorageKey);
      return;
    }
    await _secureStorage.write(key: _pkceVerifierStorageKey, value: verifier);
  }

  /// Returns true if email verification is required.
  Future<bool> signUp(String email, String password) async {
    final resp = await http
        .post(
          Uri.parse('$_base/api/auth/users?client_type=mobile'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(_httpTimeout);
    final data = await _parse(resp);
    if (data['requireEmailVerification'] == true) return true;
    await _applySession(data);
    return false;
  }

  Future<void> signIn(String email, String password) async {
    final resp = await http
        .post(
          Uri.parse('$_base/api/auth/sessions?client_type=mobile'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(_httpTimeout);
    final data = await _parse(resp);
    await _applySession(data);
  }

  Future<void> verifyEmail(String email, String code) async {
    final resp = await http
        .post(
          Uri.parse('$_base/api/auth/email/verify?client_type=mobile'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'otp': code}),
        )
        .timeout(_httpTimeout);
    final data = await _parse(resp);
    await _applySession(data);
  }

  Future<void> signOut() async {
    try {
      await http.post(
        Uri.parse('$_base/api/auth/logout'),
        headers: _authHeaders,
      );
    } catch (_) {}
    await _clearSession();
  }

  // Google OAuth PKCE
  String _randomBase64(int byteCount) {
    final bytes = List<int>.generate(
      byteCount,
      (_) => Random.secure().nextInt(256),
    );
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  String _challenge(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  Future<void> startGoogleOAuth() async {
    final verifier = _randomBase64(32);
    await _persistPkceVerifier(verifier);
    final challenge = _challenge(verifier);
    final resp = await http
        .get(
          Uri.parse('$_base/api/auth/oauth/google').replace(
            queryParameters: {
              'redirect_uri': _oauthRedirectUri,
              'code_challenge': challenge,
            },
          ),
        )
        .timeout(_oauthTimeout);
    final data = await _parse(resp);
    final authUrl = data['authUrl'] as String;
    final uri = Uri.parse(authUrl);
    final launched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (!launched) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> handleOAuthCallback(Uri uri) async {
    final error = uri.queryParameters['insforge_error'];
    if (error != null && error.isNotEmpty) {
      throw InsforgeAuthException(error);
    }

    final code = uri.queryParameters['insforge_code'];
    if (code == null || code.isEmpty) {
      throw InsforgeAuthException(
        'Google login did not return an authorization code.',
      );
    }
    if (_pkceVerifier == null) {
      throw InsforgeAuthException(
        'Google login session expired. Please try again.',
      );
    }

    final verifier = _pkceVerifier!;
    final resp = await http
        .post(
          Uri.parse('$_base/api/auth/oauth/exchange?client_type=mobile'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'code': code, 'code_verifier': verifier}),
        )
        .timeout(_oauthTimeout);
    final data = await _parse(resp);
    await _applySession(data);
    await _persistPkceVerifier(null);
  }

  Future<void> upsertRecord(String table, Map<String, dynamic> data) async {
    if (_accessToken == null) return;
    try {
      await http
          .post(
            Uri.parse('$_base/api/database/records/$table'),
            headers: {..._authHeaders, 'Prefer': 'resolution=merge-duplicates'},
            body: jsonEncode([data]),
          )
          .timeout(_httpTimeout);
    } catch (e) {
      debugPrint('InsForge DB Error: $e');
    }
  }

  Future<void> deleteAccount() async {
    if (_accessToken == null) {
      throw InsforgeAuthException('Not authenticated');
    }
    try {
      final resp = await http.post(
        Uri.parse('$_base/functions/delete-account'),
        headers: _authHeaders,
        body: jsonEncode({}),
      );
      if (resp.statusCode >= 400) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        throw InsforgeAuthException(
          data['error'] as String? ?? 'Failed to delete account',
        );
      }
    } catch (e) {
      if (e is InsforgeAuthException) rethrow;
      throw InsforgeAuthException('Failed to delete account: $e');
    }
    await _clearSession();
  }

  Future<TranslationOutcome> translateText({
    required String text,
    required String targetLang,
  }) async {
    var outcome = await _doTranslate(text, targetLang);
    if (outcome.isAuthRequired && _refreshToken != null) {
      await _doRefresh(_refreshToken!);
      if (_accessToken != null) {
        outcome = await _doTranslate(text, targetLang);
      }
    }
    return outcome;
  }

  Future<TranslationOutcome> _doTranslate(String text, String targetLang) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$_base/functions/translate'),
            headers: _authHeaders,
            body: jsonEncode({'text': text, 'target_lang': targetLang}),
          )
          .timeout(const Duration(seconds: 30));
      if (resp.statusCode >= 400) {
        debugPrint('Translate error (${resp.statusCode}): ${resp.body}');
        String? code;
        try {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          code = data['code'] as String?;
        } catch (_) {}
        return TranslationOutcome(errorCode: code ?? 'failed');
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final translation = (data['translation'] as String?)?.trim();
      if (translation == null || translation.isEmpty) {
        return const TranslationOutcome(errorCode: 'empty');
      }
      return TranslationOutcome(translation: translation);
    } catch (e) {
      debugPrint('Translate error: $e');
      return const TranslationOutcome(errorCode: 'network');
    }
  }

  Future<List<Map<String, dynamic>>> fetchMissedPrayers(String userId) async {
    try {
      final uri = Uri.parse(
        '$_base/api/database/records/missed_prayers_log',
      ).replace(
        queryParameters: {'user_id': 'eq.$userId', 'limit': '10000'},
      );
      final resp =
          await http.get(uri, headers: _authHeaders).timeout(_httpTimeout);
      if (resp.statusCode >= 400) {
        debugPrint(
          'InsForge missed prayers fetch error (${resp.statusCode}): ${resp.body}',
        );
        return const [];
      }
      final decoded = jsonDecode(resp.body);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);
      }
    } catch (e) {
      debugPrint('InsForge missed prayers fetch error: $e');
    }
    return const [];
  }

  Future<UserSettings?> fetchUserProfileSettings(String userId) async {
    try {
      final uri = Uri.parse(
        '$_base/api/database/records/user_profiles',
      ).replace(queryParameters: {'id': 'eq.$userId', 'limit': '1'});
      final resp =
          await http.get(uri, headers: _authHeaders).timeout(_httpTimeout);

      if (resp.statusCode >= 400) {
        debugPrint('InsForge DB Read Error (${resp.statusCode}): ${resp.body}');
        return null;
      }

      final decoded = jsonDecode(resp.body);
      if (decoded is List &&
          decoded.isNotEmpty &&
          decoded.first is Map<String, dynamic>) {
        return UserSettings.fromCloudProfileJson(
          decoded.first as Map<String, dynamic>,
        );
      }
      if (decoded is Map<String, dynamic>) {
        return UserSettings.fromCloudProfileJson(decoded);
      }
    } catch (e) {
      debugPrint('InsForge DB Read Error: $e');
    }

    return null;
  }
}
