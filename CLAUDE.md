# In Salah - Islamic Prayer App

## Project Overview
Flutter app for Islamic prayer tracking: prayer times, missed prayer analytics, tasbeeh counter, dua library. Uses dark theme with "liquid glass" UI style.

## Tech Stack
- **Framework**: Flutter (Dart SDK ^3.11.0)
- **State**: Provider (single AppProvider)
- **Backend**: InsForge (custom BaaS) — auth, database, edge functions
- **Prayer calc**: `adhan` package
- **Notifications**: `flutter_local_notifications`
- **Calendar**: Hijri + Gregorian via `hijri` and `intl`

## Architecture
```
lib/
  main.dart              — App entry, OAuth deep links, onboarding gate
  providers/
    app_provider.dart    — Central state: auth, settings, prayers, missed counts
  screens/
    home_screen.dart     — Prayer schedule, countdown, daily wisdom
    missed_prayers_screen.dart — Analytics: day/month view, breakdown
    tasbeeh_screen.dart  — Dhikr counter with presets
    dua_screen.dart      — Dua library with search + categories
    settings_screen.dart — Profile, reminders, iqama, calc method
    auth_screen.dart     — Email/password + Google OAuth
    onboarding_screen.dart
    main_navigation_screen.dart — Bottom nav (5 tabs)
  services/
    insforge_service.dart    — Auth (email, Google PKCE), DB, translate
    prayer_time_service.dart — Adhan-based prayer calculation
    missed_prayer_service.dart — Local + cloud prayer completion tracking
    notification_service.dart — Prayer reminder scheduling (30 days)
    settings_service.dart    — SharedPreferences persistence
    translation_service.dart
    login_history_service.dart
  models/
    prayer.dart, dua.dart, user_settings.dart
  widgets/
    liquid_background.dart, liquid_glass_container.dart
    prayer_card.dart, prayer_checkbox.dart, missed_counter.dart
    branded_loading_screen.dart, translate_button.dart
  utils/
    theme.dart — AppTheme (dark, primary green #A8FF78)
    utils.dart — Date formatting, Hijri helpers
```

## Key Patterns
- AppProvider uses dependency injection for all services (testable)
- Settings sync: local-first (SharedPreferences) + cloud backup (InsForge user_profiles table)
- Missed prayers: local SQLite-like storage + cloud sync (missed_prayers_log table)
- Notifications: scheduled 30 days ahead on settings change
- OAuth: PKCE flow with deep links (app.insalah.prayer://auth-callback)

## Known Issues
- `main.dart:38`: `prefs.remove('hasSeenOnboarding')` resets onboarding every launch (TODO comment says to remove after testing)

## Build & Run
```bash
flutter pub get
flutter run
```

## Release workflow rule
After any code change, commit and push immediately, then **stop and ask
the user** whether to produce a new release build. Never bump
`pubspec.yaml` `version:` or run `flutter build appbundle` on your own.
Full rules are in [release-build skill](.claude/skills/release-build/SKILL.md).
