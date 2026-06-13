import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart' show HapticFeedback, rootBundle;
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import '../models/user_settings.dart';
import '../models/prayer.dart';
import '../services/insforge_service.dart';
import '../services/settings_service.dart';
import '../services/prayer_time_service.dart';
import '../services/missed_prayer_service.dart';
import '../services/notification_service.dart';

typedef NotificationInitCallback = Future<void> Function();
typedef NotificationScheduler =
    Future<void> Function(List<PrayerNotificationRequest> requests);
typedef NotificationPermissionRequester = Future<bool> Function();
typedef UpsertRecordCallback =
    Future<void> Function(String table, Map<String, dynamic> data);
typedef FetchUserProfileSettingsCallback =
    Future<UserSettings?> Function(String userId);
typedef FetchMissedPrayersCallback =
    Future<List<Map<String, dynamic>>> Function(String userId);

class AppProvider extends ChangeNotifier with WidgetsBindingObserver {
  AppProvider({
    SettingsService? settingsService,
    PrayerTimeService? prayerTimeService,
    MissedPrayerService? missedPrayerService,
    NotificationInitCallback? notificationInit,
    NotificationInitCallback? notificationCancelAll,
    NotificationScheduler? schedulePrayerReminders,
    NotificationPermissionRequester? notificationRequestPermission,
    InsforgeUser? initialUser,
    Stream<InsforgeUser?>? authStateChanges,
    UpsertRecordCallback? upsertRecord,
    FetchUserProfileSettingsCallback? fetchUserProfileSettings,
    FetchMissedPrayersCallback? fetchMissedPrayers,
  }) : _settingsService = settingsService ?? SettingsService(),
       _prayerTimeService = prayerTimeService ?? PrayerTimeService(),
       _missedPrayerService = missedPrayerService ?? MissedPrayerService(),
       _notificationInit = notificationInit ?? NotificationService().init,
       _notificationCancelAll =
           notificationCancelAll ?? NotificationService().cancelAll,
       _schedulePrayerReminders =
           schedulePrayerReminders ??
           NotificationService().schedulePrayerReminders,
       _notificationRequestPermission =
           notificationRequestPermission ??
           NotificationService().requestPermissionIfNeeded,
       _initialUser = initialUser,
       _authStateChanges = authStateChanges,
       _upsertRecord = upsertRecord ?? InsforgeService.instance.upsertRecord,
       _fetchUserProfileSettings =
           fetchUserProfileSettings ??
           InsforgeService.instance.fetchUserProfileSettings,
       _fetchMissedPrayers =
           fetchMissedPrayers ?? InsforgeService.instance.fetchMissedPrayers;

  final SettingsService _settingsService;
  final PrayerTimeService _prayerTimeService;
  final MissedPrayerService _missedPrayerService;
  final NotificationInitCallback _notificationInit;
  final NotificationInitCallback _notificationCancelAll;
  final NotificationScheduler _schedulePrayerReminders;
  final NotificationPermissionRequester _notificationRequestPermission;
  final InsforgeUser? _initialUser;
  final Stream<InsforgeUser?>? _authStateChanges;
  final UpsertRecordCallback _upsertRecord;
  final FetchUserProfileSettingsCallback _fetchUserProfileSettings;
  final FetchMissedPrayersCallback _fetchMissedPrayers;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  DateTime? _lastNotificationSync;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_isLoading || !_settings.isSetupComplete) return;

    // Throttle: re-syncing on every brief foreground toggle is wasteful, but
    // we want to refresh prayer times and re-extend the 30-day notification
    // window whenever the app comes back after being idle for a while.
    final now = DateTime.now();
    if (_lastNotificationSync != null &&
        now.difference(_lastNotificationSync!) < const Duration(minutes: 30)) {
      return;
    }
    _lastNotificationSync = now;

    unawaited(_refreshOnResume());
  }

  Future<void> _refreshOnResume() async {
    try {
      await _loadPrayersAndCount(userId: _currentUser?.id);
      await _scheduleNotifications();
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing on resume: $e');
    }
  }

  UserSettings _settings = UserSettings();
  InsforgeUser? _currentUser;
  StreamSubscription? _authSubscription;
  List<Prayer> _todayPrayers = [];
  Prayer? _tomorrowFajr;
  int _missedCount = 0;
  int _totalObligatory = 0;
  int _lifetimeCompleted = 0;
  bool _isLoading = true;
  String _error = '';
  MemoryImage? _avatarImage;
  String? _lastAvatarPath;
  Future<void> _settingsSaveQueue = Future.value();
  LocationStatus _locationStatus = LocationStatus.available;
  int _currentStreak = 0;

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _settingsFingerprint(UserSettings settings) =>
      jsonEncode(settings.toJson());

  Future<UserSettings> _restoreCloudBackedSettings(
    String userId,
    UserSettings localSettings,
  ) async {
    final hasLocalSettings = await _settingsService.hasSettings(userId: userId);
    final needsHydration =
        !hasLocalSettings ||
        !localSettings.isSetupComplete ||
        localSettings.avatarPath == null;

    if (!needsHydration) return localSettings;

    final cloudSettings = await _fetchUserProfileSettings(userId);
    if (cloudSettings == null) return localSettings;

    final restoredSettings = localSettings.mergeCloudProfile(
      cloudSettings,
      preferCloudBackedSettings: !hasLocalSettings,
    );

    if (_settingsFingerprint(restoredSettings) !=
        _settingsFingerprint(localSettings)) {
      await _persistSettingsLocally(restoredSettings, userId: userId);
    }

    return restoredSettings;
  }

  Future<void> _restoreCloudMissedPrayers(String userId) async {
    try {
      final records = await _fetchMissedPrayers(userId);
      if (records.isEmpty) return;
      await _missedPrayerService.restoreFromCloud(userId, records);
    } catch (e) {
      debugPrint('Error restoring missed prayers from cloud: $e');
    }
  }

  Future<List<Prayer>> _withTodayCompletionStatuses(
    List<Prayer> prayers, {
    String? userId,
  }) async {
    final statuses = await _missedPrayerService.getDayPrayerStatuses(
      DateTime.now(),
      userId: userId,
    );

    return prayers
        .map(
          (prayer) =>
              prayer.copyWith(isCompleted: statuses[prayer.name] ?? false),
        )
        .toList();
  }

  UserSettings get settings => _settings;
  InsforgeUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  List<Prayer> get todayPrayers => _todayPrayers;
  Prayer? get tomorrowFajr => _tomorrowFajr;
  int get missedCount => _missedCount;
  int get totalObligatory => _totalObligatory;
  int get lifetimeCompleted => _lifetimeCompleted;
  bool get isLoading => _isLoading;
  String get error => _error;
  MemoryImage? get avatarImage => _avatarImage;
  LocationStatus get locationStatus => _locationStatus;
  int get currentStreak => _currentStreak;

  void _cacheAvatar() {
    final path = _settings.avatarPath;
    if (path == _lastAvatarPath) return;
    _lastAvatarPath = path;
    if (path != null && path.startsWith('base64:')) {
      try {
        _avatarImage = MemoryImage(base64Decode(path.substring(7)));
      } catch (_) {
        _avatarImage = null;
      }
    } else {
      _avatarImage = null;
    }
  }

  Future<void> _reloadStateForCurrentUser() async {
    _todayPrayers = [];
    _tomorrowFajr = null;
    _missedCount = 0;
    _totalObligatory = 0;
    _lifetimeCompleted = 0;

    if (_currentUser == null) {
      _settings = UserSettings();
      _cacheAvatar();
      await _notificationCancelAll();
      return;
    }

    _settings = await _settingsService.loadSettings(userId: _currentUser!.id);
    _settings = await _restoreCloudBackedSettings(_currentUser!.id, _settings);

    final googleAvatar = _currentUser!.avatarUrl;
    final googleName = _currentUser!.displayName;
    var settingsChanged = false;
    var updated = _settings;
    if (googleAvatar != null &&
        googleAvatar.isNotEmpty &&
        (updated.avatarPath == null || updated.avatarPath!.isEmpty)) {
      updated = updated.copyWith(avatarPath: googleAvatar);
      settingsChanged = true;
    }
    if (googleName != null &&
        googleName.isNotEmpty &&
        (updated.displayName == null || updated.displayName!.isEmpty)) {
      updated = updated.copyWith(displayName: googleName);
      settingsChanged = true;
    }
    if (settingsChanged) {
      _settings = updated;
      await _persistSettingsLocally(_settings, userId: _currentUser!.id);
    }

    _cacheAvatar();

    await _restoreCloudMissedPrayers(_currentUser!.id);

    if (_settings.isSetupComplete) {
      await _loadPrayersAndCount(userId: _currentUser!.id);
      await _scheduleNotifications();
      return;
    }

    await _notificationCancelAll();
  }

  Future<void> _handleAuthStateChanged(InsforgeUser? user) async {
    _debounceTimer?.cancel();
    _currentUser = user;
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      await _reloadStateForCurrentUser();
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    try {
      WidgetsBinding.instance.addObserver(this);
      await _notificationInit();

      // Setup Auth Listener
      _currentUser = _initialUser ?? InsforgeService.instance.currentUser;
      _authSubscription =
          (_authStateChanges ?? InsforgeService.instance.onAuthStateChange)
              .listen((user) {
                unawaited(_handleAuthStateChanged(user));
              });

      await _reloadStateForCurrentUser();
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  int getPastPrayersToday() {
    final now = DateTime.now();
    int count = 0;
    for (final prayer in _todayPrayers) {
      // Small buffer, assuming if prayer time is exactly now it's basically past
      if (prayer.time.isBefore(now) || prayer.time.isAtSameMomentAs(now)) {
        count++;
      }
    }
    return count;
  }

  /// Manually trigger a reload of prayer times and counts, e.g. from a
  /// pull-to-refresh gesture on the Home screen.
  Future<void> refresh() async {
    await _loadPrayersAndCount(userId: _currentUser?.id);
    notifyListeners();
  }

  Future<void> _loadPrayersAndCount({String? userId}) async {
    final prayers = await _prayerTimeService.getPrayers();
    _locationStatus = _prayerTimeService.lastLocationStatus;
    _todayPrayers = await _withTodayCompletionStatuses(prayers, userId: userId);
    final tomorrowPrayers = await _prayerTimeService.getPrayers(
      DateTime.now().add(const Duration(days: 1)),
    );
    _tomorrowFajr = tomorrowPrayers.firstWhere(
      (p) => p.name == 'Fajr',
      orElse: () => tomorrowPrayers.first,
    );

    final stats = await _missedPrayerService.getLifetimeStats(
      _settings,
      getPastPrayersToday(),
      userId: userId,
    );
    _missedCount = stats['missed'] ?? 0;
    _totalObligatory = stats['total'] ?? 0;
    _lifetimeCompleted = stats['completed'] ?? 0;
    _currentStreak = await _calculateStreak(userId: userId);
  }

  /// How many consecutive days (ending today or yesterday) the user has
  /// completed all five prayers. Today only counts past prayers — future
  /// prayers don't break the streak.
  Future<int> _calculateStreak({String? userId}) async {
    int streak = 0;
    final now = DateTime.now();

    final todayPast = _todayPrayers.where((p) => p.time.isBefore(now)).toList();
    DateTime cursor = DateTime(now.year, now.month, now.day);

    if (todayPast.isNotEmpty) {
      final allDone = todayPast.every((p) => p.isCompleted);
      if (!allDone) return 0;
      streak = 1;
    }
    cursor = cursor.subtract(const Duration(days: 1));

    for (var i = 0; i < 365; i++) {
      final statuses = await _missedPrayerService.getDayPrayerStatuses(
        cursor,
        userId: userId,
      );
      final allDone = statuses.values.every((v) => v);
      if (!allDone) break;
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return streak;
  }

  /// Loads the active locale's translation map for use outside of widget tree
  /// (e.g. when scheduling notifications).
  Future<Map<String, String>> _loadActiveTranslations() async {
    final code = _settings.locale == 'system' ? 'en' : _settings.locale;
    final supported = const {'en', 'ru', 'ar', 'tg'};
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

  Future<void> _scheduleNotifications() async {
    final now = DateTime.now();
    final requests = <PrayerNotificationRequest>[];
    final prayerOrder = const {
      'Fajr': 1,
      'Dhuhr': 2,
      'Asr': 3,
      'Maghrib': 4,
      'Isha': 5,
    };

    final tr = await _loadActiveTranslations();
    final titleTpl = tr['notificationPrayerTitle'] ?? '{prayer} Prayer';
    final bodyTpl =
        tr['notificationPrayerBody'] ?? 'It is time for {prayer} prayer.';

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
        settings: _settings,
        position: sharedPosition,
      );

      for (final prayer in prayers) {
        final prayerSettings = _settings.prayerSettings[prayer.name];
        if (!(prayerSettings?.isEnabled ?? true) || !prayer.time.isAfter(now)) {
          continue;
        }

        final dateKey =
            (targetDate.year * 10000) +
            (targetDate.month * 100) +
            targetDate.day;
        final localizedName = _localizedPrayerName(prayer.name, tr);
        requests.add(
          PrayerNotificationRequest(
            id: (dateKey * 10) + (prayerOrder[prayer.name] ?? 0),
            prayerName: prayer.name,
            title: titleTpl.replaceAll('{prayer}', localizedName),
            body: bodyTpl.replaceAll('{prayer}', localizedName),
            dateTime: prayer.time,
            sound: prayerSettings?.sound ?? 'default',
          ),
        );
      }
    }

    await _schedulePrayerReminders(requests);
    _lastNotificationSync = DateTime.now();
  }

  Future<bool> ensureNotificationPermission() async {
    final granted = await _notificationRequestPermission();
    if (granted && _settings.isSetupComplete) {
      try {
        await _loadPrayersAndCount(userId: _currentUser?.id);
        await _scheduleNotifications();
      } catch (e) {
        _error = e.toString();
        debugPrint('Error scheduling notifications after permission: $e');
      }
    }
    notifyListeners();
    return granted;
  }

  Future<int> pendingNotificationCount() {
    return NotificationService().pendingNotificationCount();
  }

  Future<void> sendTestNotification({
    required String title,
    required String body,
  }) {
    return NotificationService().sendTestNotification(title: title, body: body);
  }

  Timer? _debounceTimer;

  Future<void> _persistSettingsLocally(
    UserSettings settings, {
    String? userId,
  }) {
    _settingsSaveQueue = _settingsSaveQueue
        .catchError((_) {})
        .then((_) => _settingsService.saveSettings(settings, userId: userId));

    return _settingsSaveQueue;
  }

  Future<void> updateSettings(UserSettings newSettings) async {
    final userId = _currentUser?.id;
    final settingsSnapshot = newSettings;

    _settings = settingsSnapshot;
    _cacheAvatar();
    _error = '';
    notifyListeners();

    try {
      await _persistSettingsLocally(settingsSnapshot, userId: userId);
    } catch (e) {
      _error = e.toString();
      debugPrint('Error saving settings locally: $e');
      notifyListeners();
    }

    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!identical(_settings, settingsSnapshot)) return;

      // Cloud Sync Settings
      if (userId != null) {
        await _upsertRecord('user_profiles', {
          'id': userId,
          'gender': settingsSnapshot.gender?.name,
          'date_of_birth': settingsSnapshot.dateOfBirth
              ?.toIso8601String()
              .split('T')[0],
          'avatar_url': settingsSnapshot.avatarPath,
          'calculation_method': settingsSnapshot.calculationMethod,
          'madhab': settingsSnapshot.madhab,
          'ui_scale': settingsSnapshot.interfaceScale,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      if (settingsSnapshot.isSetupComplete) {
        try {
          await _loadPrayersAndCount(userId: userId);
          await _scheduleNotifications();
          notifyListeners();
        } catch (e) {
          _error = e.toString();
          debugPrint('Error updating provider: $e');
        }
      }
    });
  }

  /// Toggles a prayer's completion status. Returns `true` when this toggle
  /// is the one that completed all five of today's prayers — useful for
  /// the Home screen to fire a celebratory animation/SnackBar.
  Future<bool> togglePrayerCompletion(
    String prayerName,
    DateTime date,
    bool completed,
  ) async {
    final userId = _currentUser?.id;
    final isToday = _isSameDay(date, DateTime.now());
    int todayPrayerIndex = -1;
    final wasAllDone =
        isToday &&
        _todayPrayers.isNotEmpty &&
        _todayPrayers.every((p) => p.isCompleted);

    if (isToday) {
      todayPrayerIndex = _todayPrayers.indexWhere((p) => p.name == prayerName);
    }

    final previousCompleted = todayPrayerIndex >= 0
        ? _todayPrayers[todayPrayerIndex].isCompleted
        : await _missedPrayerService.isPrayerCompleted(
            prayerName,
            date,
            userId: userId,
          );

    if (previousCompleted == completed) return false;

    HapticFeedback.selectionClick();

    final previousMissedCount = _missedCount;
    final previousLifetimeCompleted = _lifetimeCompleted;
    Prayer? previousPrayer;

    if (todayPrayerIndex >= 0) {
      previousPrayer = _todayPrayers[todayPrayerIndex];
      _todayPrayers = List<Prayer>.from(_todayPrayers);
      _todayPrayers[todayPrayerIndex] = previousPrayer.copyWith(
        isCompleted: completed,
      );
    }

    if (_settings.isSetupComplete) {
      final delta = completed ? 1 : -1;
      _lifetimeCompleted = (_lifetimeCompleted + delta).clamp(
        0,
        _totalObligatory,
      );
      _missedCount = (_totalObligatory - _lifetimeCompleted).clamp(
        0,
        _totalObligatory,
      );
    }

    notifyListeners();

    try {
      await _missedPrayerService.markPrayerCompleted(
        prayerName,
        date,
        completed,
        userId: userId,
      );
      _currentStreak = await _calculateStreak(userId: userId);
      notifyListeners();

      final allDoneNow =
          isToday &&
          _todayPrayers.isNotEmpty &&
          _todayPrayers.every((p) => p.isCompleted);
      return allDoneNow && !wasAllDone;
    } catch (e) {
      if (todayPrayerIndex >= 0 && previousPrayer != null) {
        _todayPrayers = List<Prayer>.from(_todayPrayers);
        _todayPrayers[todayPrayerIndex] = previousPrayer;
      }
      _missedCount = previousMissedCount;
      _lifetimeCompleted = previousLifetimeCompleted;
      _error = e.toString();
      notifyListeners();
      debugPrint('Error toggling prayer completion: $e');
      return false;
    }
  }

  Future<Map<String, bool>> getDayPrayerStatuses(DateTime date) {
    return _missedPrayerService.getDayPrayerStatuses(
      date,
      userId: _currentUser?.id,
    );
  }

  Future<Map<String, int>> getMonthStats(int year, int month) {
    return _missedPrayerService.getMonthStats(
      year,
      month,
      getPastPrayersToday(),
      userId: _currentUser?.id,
    );
  }

  Future<Map<int, int>> getMonthDayCompletions(int year, int month) {
    return _missedPrayerService.getMonthDayCompletions(
      year,
      month,
      userId: _currentUser?.id,
    );
  }

  Future<void> setAllPrayersForDay(DateTime date, bool completed) async {
    final prayerNames = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    final isToday = _isSameDay(date, DateTime.now());
    final limit = isToday ? getPastPrayersToday() : prayerNames.length;

    for (int i = 0; i < prayerNames.length && i < limit; i++) {
      await togglePrayerCompletion(prayerNames[i], date, completed);
    }
  }

  String getNextPrayerName() {
    if (_todayPrayers.isEmpty) return '';
    return _prayerTimeService.getNextPrayerName(_todayPrayers);
  }

  String getCurrentPrayerStatus() {
    if (_todayPrayers.isEmpty) return '';
    return _prayerTimeService.getCurrentPrayerStatus(_todayPrayers);
  }
}
