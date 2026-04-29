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

  static const _prayerChannelId = 'prayer_reminders';
  static const _prayerChannelName = 'Prayer Reminders';
  static const _prayerChannelDesc = 'Adhan and prayer time reminders';


  Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    tz_data.initializeTimeZones();
    await _configureLocalTimeZone();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
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
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
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
        // Create separate channels for custom adhan sounds
        for (final sound in ['adhan_makkah', 'adhan_madina']) {
          await androidPlugin.createNotificationChannel(
            AndroidNotificationChannel(
              'prayer_reminders_$sound',
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

      await Permission.notification.request();
    }

    _initialized = true;
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
          final requested =
              await androidPlugin.requestNotificationsPermission();
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
  }) {
    return AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: sound != null ? RawResourceAndroidNotificationSound(sound) : null,
      enableVibration: true,
      channelShowBadge: true,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      autoCancel: true,
    );
  }

  DarwinNotificationDetails _iosDetails({String? sound}) {
    return DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: sound,
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

    final isCustomSound = sound != 'default';
    final channelId = isCustomSound
        ? 'prayer_reminders_$sound'
        : _prayerChannelId;
    final channelName = isCustomSound
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
        ),
        iOS: _iosDetails(
          sound: isCustomSound ? '$sound.aiff' : null,
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

  /// Fires a one-off notification a few seconds in the future so the user
  /// can verify that permissions, channels and OS battery rules let the
  /// notification actually surface.
  Future<void> sendTestNotification({
    required String title,
    required String body,
    String sound = 'default',
    Duration delay = const Duration(seconds: 5),
  }) async {
    if (!_initialized) await init();
    if (kIsWeb) return;

    final fireAt = DateTime.now().add(delay);
    await schedulePrayerNotification(
      id: 99999,
      title: title,
      body: body,
      dateTime: fireAt,
      sound: sound,
    );
  }
}
