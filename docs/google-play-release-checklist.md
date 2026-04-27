# Google Play Release Checklist

## Must Finish Before Upload

1. ~~Create a real upload keystore and copy `android/key.properties.example` to `android/key.properties`.~~ **DONE** — see `SECRETS.md`.
2. Update `version:` in `pubspec.yaml` before each new Play upload.
3. Test notifications on a real Android 13+ device:
   - allow notifications
   - verify reminders fire for today's next prayer
   - verify reminders still exist after app restart
   - verify reminders reschedule after changing calculation method, madhab, iqama, or reminder sound
4. ~~Publish a hosted privacy policy URL and add it to Play Console.~~ **DONE**
5. ~~Prepare account deletion instructions/URL if Play asks for it for signed-in users.~~ **DONE**
6. Fill Data safety form for:
   - location
   - email / account info
   - optional profile image
7. Prepare listing assets:
   - 8+ phone screenshots (1080×1920 portrait or 1920×1080 landscape)
   - feature graphic (1024×500)
   - app icon (512×512) — already produced by `flutter_launcher_icons`
   - short description (≤80 chars)
   - full description (≤4000 chars)
   - localized variants for ru / en / ar / tg if you want non-English listings

## Public URLs

- Privacy Policy: <https://ibrohim-18.github.io/in-salah/privacy-policy/>
- Account deletion: <https://ibrohim-18.github.io/in-salah/account-deletion/>
- Support email: ibrohimovtv@gmail.com

## Build Commands

```bash
flutter analyze
flutter build appbundle
```

Final Android bundle output:

`build/app/outputs/bundle/release/app-release.aab`
