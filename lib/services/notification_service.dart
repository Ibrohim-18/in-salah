import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class PrayerNotificationRequest {
  const PrayerNotificationRequest({
    required this.id,
    required this.prayerName,
    required this.title,
    required this.body,
    required this.dateTime,
    required this.sound,
  });

  final int id;
  final String prayerName;
  final String title;
  final String body;
  final DateTime dateTime;
  final String sound;
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelVersion = 'v2';
  static const _silentSound = 'silent';
  static const _prayerChannelId = 'prayer_reminders_$_channelVersion';
  static const _silentChannelId = 'prayer_reminders_silent_$_channelVersion';
  static const _prayerChannelName = 'Prayer Reminders';
  static const _prayerChannelDesc = 'Adhan and prayer time reminders';

  String _customSoundChannelId(String sound) {
    return 'prayer_reminders_${sound}_$_channelVersion';
  }

  bool _isSilentSound(String sound) => sound == _silentSound;

  Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    tz_data.initializeTimeZones();
    await _configureLocalTimeZone();

    const androidSettings = AndroidInitializationSettings(
      'ic_stat_notification',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onTap,
    );

    // Create notification channels on Android
    if (Platform.isAndroid) {
      await _ensureAndroidChannels();

      // Ask for notification permission only from an explicit user action.
      // Requesting it during app startup can leave first-run users staring at
      // the loading screen before onboarding/auth has even appeared.
    }

    _initialized = true;
  }

  /// (Re)creates every notification channel. Each channel is created in its
  /// own try/catch so a single failure — e.g. a custom-sound channel whose raw
  /// resource can't be resolved — can't abort `init()` and leave the device
  /// without the main channel. A notification posted to a missing channel is
  /// silently dropped by Android 8+, so this must always leave the essential
  /// channels in place. Safe to call repeatedly; creating an existing channel
  /// is a no-op.
  Future<void> _ensureAndroidChannels() async {
    if (!Platform.isAndroid) return;
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) return;

    Future<void> create(AndroidNotificationChannel channel) async {
      try {
        await androidPlugin.createNotificationChannel(channel);
      } catch (e) {
        debugPrint('Failed to create channel ${channel.id}: $e');
      }
    }

    // Essential channels first.
    await create(
      const AndroidNotificationChannel(
        _prayerChannelId,
        _prayerChannelName,
        description: _prayerChannelDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      ),
    );
    await create(
      const AndroidNotificationChannel(
        _silentChannelId,
        '$_prayerChannelName (silent)',
        description: _prayerChannelDesc,
        importance: Importance.max,
        playSound: false,
        enableVibration: false,
        showBadge: true,
      ),
    );
    // Separate channels for custom adhan and iqama sounds. Android locks a
    // channel's sound after it is created, so every custom sound gets its own
    // stable channel id.
    for (final sound in ['adhan_makkah', 'adhan_madina', 'iqama_chime']) {
      await create(
        AndroidNotificationChannel(
          _customSoundChannelId(sound),
          '$_prayerChannelName ($sound)',
          description: _prayerChannelDesc,
          importance: Importance.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(sound),
          enableVibration: true,
          showBadge: true,
        ),
      );
    }
  }

  Future<void> _configureLocalTimeZone() async {
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (e) {
      debugPrint('Failed to configure local timezone: $e');
      tz.setLocalLocation(tz.UTC);
    }
  }

  void _onTap(NotificationResponse response) {
    // Can navigate or handle tap later
  }

  Future<bool> requestPermissionIfNeeded() async {
    if (kIsWeb) return false;
    if (!_initialized) await init();

    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        final enabled = await androidPlugin.areNotificationsEnabled();
        if (!(enabled ?? false)) {
          final requested = await androidPlugin
              .requestNotificationsPermission();
          if (!(requested ?? false)) {
            final status = await Permission.notification.request();
            if (!status.isGranted) return false;
          }
        }

        final canScheduleExact = await androidPlugin
            .canScheduleExactNotifications();
        if (canScheduleExact == false) {
          await androidPlugin.requestExactAlarmsPermission();
        }
      }
      return true;
    }

    // iOS permissions are handled during init
    return true;
  }

  /// Whether the OS currently lets the app post notifications. On Xiaomi/Huawei
  /// the system master toggle can be off even after the in-app permission was
  /// granted, which silently suppresses every notification.
  Future<bool> areNotificationsEnabled() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    if (!_initialized) await init();
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return (await androidPlugin?.areNotificationsEnabled()) ?? true;
  }

  /// Whether the app is exempt from battery optimization. When it isn't,
  /// aggressive OEM power management (Xiaomi, Huawei, Oppo, Samsung, …) freezes
  /// the app and its scheduled alarms never fire.
  Future<bool> isBatteryOptimizationDisabled() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    final status = await Permission.ignoreBatteryOptimizations.status;
    return status.isGranted;
  }

  /// Asks the OS to exempt the app from battery optimization. Shows the system
  /// dialog only when not already exempt. Returns whether it is now exempt.
  Future<bool> requestDisableBatteryOptimization() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    final status = await Permission.ignoreBatteryOptimizations.status;
    if (status.isGranted) return true;
    final requested = await Permission.ignoreBatteryOptimizations.request();
    return requested.isGranted;
  }

  Future<AndroidScheduleMode> _resolveAndroidScheduleMode() async {
    if (!Platform.isAndroid) return AndroidScheduleMode.inexactAllowWhileIdle;

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final canScheduleExact = await androidPlugin
        ?.canScheduleExactNotifications();

    if (canScheduleExact ?? false) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }

    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  AndroidNotificationDetails _androidDetails({
    required String channelId,
    required String channelName,
    String? channelDescription,
    String? sound,
    bool isSilent = false,
  }) {
    return AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      icon: 'ic_stat_notification',
      importance: Importance.max,
      priority: Priority.high,
      playSound: !isSilent,
      sound: sound != null && !isSilent
          ? RawResourceAndroidNotificationSound(sound)
          : null,
      enableVibration: !isSilent,
      channelShowBadge: true,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      autoCancel: true,
    );
  }

  DarwinNotificationDetails _iosDetails({
    String? sound,
    bool isSilent = false,
  }) {
    return DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: !isSilent,
      sound: isSilent ? null : sound,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
  }

  Future<void> schedulePrayerNotification({
    required int id,
    required String title,
    required String body,
    required DateTime dateTime,
    required String sound,
  }) async {
    if (!_initialized) await init();
    if (kIsWeb) return;
    if (dateTime.isBefore(DateTime.now())) return;

    final tzDate = tz.TZDateTime.from(dateTime, tz.local);
    final scheduleMode = await _resolveAndroidScheduleMode();

    final isSilent = _isSilentSound(sound);
    final isCustomSound = sound != 'default' && !isSilent;
    final channelId = isSilent
        ? _silentChannelId
        : isCustomSound
        ? _customSoundChannelId(sound)
        : _prayerChannelId;
    final channelName = isSilent
        ? '$_prayerChannelName (silent)'
        : isCustomSound
        ? '$_prayerChannelName ($sound)'
        : _prayerChannelName;

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzDate,
      NotificationDetails(
        android: _androidDetails(
          channelId: channelId,
          channelName: channelName,
          channelDescription: _prayerChannelDesc,
          sound: isCustomSound ? sound : null,
          isSilent: isSilent,
        ),
        iOS: _iosDetails(
          sound: isCustomSound ? '$sound.aiff' : null,
          isSilent: isSilent,
        ),
      ),
      payload: '$title|${dateTime.toIso8601String()}',
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelAll() async {
    if (!_initialized) await init();
    if (kIsWeb) return;
    await _plugin.cancelAll();
  }

  Future<void> cancel(int id) async {
    if (!_initialized) await init();
    if (kIsWeb) return;
    await _plugin.cancel(id);
  }

  Future<void> schedulePrayerReminders(
    List<PrayerNotificationRequest> requests,
  ) async {
    if (!_initialized) await init();
    await _ensureAndroidChannels();
    await cancelAll();

    for (final request in requests) {
      await schedulePrayerNotification(
        id: request.id,
        title: request.title,
        body: request.body,
        dateTime: request.dateTime,
        sound: request.sound,
      );
    }
  }

  /// Returns how many notifications are currently scheduled with the
  /// system. Useful for confirming `schedulePrayerReminders` actually
  /// queued anything.
  Future<int> pendingNotificationCount() async {
    if (!_initialized) await init();
    if (kIsWeb) return 0;
    final pending = await _plugin.pendingNotificationRequests();
    return pending.length;
  }

  /// Fires a one-off notification immediately so the user can verify that
  /// permissions and channels let notifications surface.
  Future<void> sendTestNotification({
    required String title,
    required String body,
    String sound = 'default',
  }) async {
    if (!_initialized) await init();
    if (kIsWeb) return;
    // Re-create channels defensively: if init's channel setup failed, an
    // immediate test would otherwise post to a missing channel and vanish.
    await _ensureAndroidChannels();

    final isSilent = _isSilentSound(sound);
    final isCustomSound = sound != 'default' && !isSilent;
    final channelId = isSilent
        ? _silentChannelId
        : isCustomSound
        ? _customSoundChannelId(sound)
        : _prayerChannelId;
    final channelName = isSilent
        ? '$_prayerChannelName (silent)'
        : isCustomSound
        ? '$_prayerChannelName ($sound)'
        : _prayerChannelName;

    await _plugin.show(
      99999,
      title,
      body,
      NotificationDetails(
        android: _androidDetails(
          channelId: channelId,
          channelName: channelName,
          channelDescription: _prayerChannelDesc,
          sound: isCustomSound ? sound : null,
          isSilent: isSilent,
        ),
        iOS: _iosDetails(
          sound: isCustomSound ? '$sound.aiff' : null,
          isSilent: isSilent,
        ),
      ),
      payload: '$title|${DateTime.now().toIso8601String()}',
    );
  }
}
