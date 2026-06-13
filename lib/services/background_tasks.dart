import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'notification_service.dart';
import 'prayer_reminder_planner.dart';
import 'settings_service.dart';

/// Task name dispatched to the WorkManager callback.
const String kPrayerRescheduleTask = 'reschedulePrayerNotifications';

/// Unique work name so the OS keeps a single periodic chain.
const String _prayerRescheduleUnique = 'prayer-resched-periodic';

/// SharedPreferences key holding the settings scope (user id or 'guest') the
/// background isolate should load, since it has no access to the auth session.
const String kNotifActiveScopeKey = 'notif_active_scope';

/// Records which settings scope the background task should rebuild reminders
/// from. Called from the foreground whenever the active user changes.
Future<void> persistActiveNotificationScope(String scope) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(kNotifActiveScopeKey, scope);
}

/// Entry point for the background isolate. Must be a top-level function
/// annotated for AOT so WorkManager can find it.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();

      final prefs = await SharedPreferences.getInstance();
      final scope = prefs.getString(kNotifActiveScopeKey) ?? 'guest';

      final settings = await SettingsService().loadSettings(userId: scope);
      // Only rebuild reminders once the user has finished setup, otherwise
      // there is nothing meaningful to schedule.
      if (!settings.isSetupComplete) return true;

      final notificationService = NotificationService();
      await notificationService.init();

      await PrayerReminderPlanner(
        notificationService: notificationService,
      ).reschedule(settings);

      return true;
    } catch (e) {
      debugPrint('Background reschedule failed: $e');
      // Returning true avoids aggressive retry storms; the next periodic run
      // (or the next app open) will try again.
      return true;
    }
  });
}

/// Initializes WorkManager and registers the periodic reschedule task.
/// No-op on platforms without WorkManager background support.
Future<void> initializeBackgroundReschedule() async {
  if (kIsWeb) return;
  if (!Platform.isAndroid && !Platform.isIOS) return;

  try {
    await Workmanager().initialize(callbackDispatcher);

    // iOS background scheduling needs BGTaskScheduler identifiers wired in
    // Info.plist/AppDelegate; until that is set up, only register on Android.
    // iOS still re-extends the window on app resume (see AppProvider).
    if (Platform.isAndroid) {
      await Workmanager().registerPeriodicTask(
        _prayerRescheduleUnique,
        kPrayerRescheduleTask,
        frequency: const Duration(hours: 6),
        initialDelay: const Duration(hours: 6),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
        constraints: Constraints(networkType: NetworkType.notRequired),
      );
    }
  } catch (e) {
    debugPrint('Failed to initialize background reschedule: $e');
  }
}
