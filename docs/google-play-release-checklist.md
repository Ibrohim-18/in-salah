# Google Play Release Checklist

## Must Finish Before Upload

1. Create a real upload keystore and copy `android/key.properties.example` to `android/key.properties`.
2. Update `version:` in `pubspec.yaml` before each new Play upload.
3. Test notifications on a real Android 13+ device:
   - allow notifications
   - verify reminders fire for today's next prayer
   - verify reminders still exist after app restart
   - verify reminders reschedule after changing calculation method, madhab, iqama, or reminder sound
4. Publish a hosted privacy policy URL and add it to Play Console.
5. Prepare account deletion instructions/URL if Play asks for it for signed-in users.
6. Fill Data safety form for:
   - location
   - email / account info
   - optional profile image

## Build Commands

```bash
flutter analyze
flutter build appbundle
```

Final Android bundle output:

`build/app/outputs/bundle/release/app-release.aab`
