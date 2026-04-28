---
name: release-build
description: Workflow rule for In Salah — never bump pubspec version or run flutter build appbundle automatically. Commit code changes immediately, ask the user before producing a new release build. Triggers any time you finish a code change in this Flutter app.
---

# Release build workflow for In Salah

Owner: Ibrohim. The Play Console release pipeline is shared/manual, so the
repo owner decides exactly when a new build goes out. Do not surprise him
with a build.

## Order of operations after every code change

1. **Edit and verify** the code change as usual (Edit/Write + `flutter analyze`).
2. **Commit and push immediately** with a focused commit message — even if
   the user has not asked for a build yet. Do not include the version bump
   or any rebuild artifacts in this commit.
3. **Stop. Ask the user for permission to release.** A short single sentence
   like:

   > Готово, изменения закоммичены. Собирать новый AAB в Play Store? (поднять версию + flutter build appbundle)

   Wait for an explicit yes (`да`, `yes`, `собирай`, `давай`, etc.). If the
   user says no or stays silent on the question, do nothing further.

## Only after the user says yes

1. Bump `version:` in `pubspec.yaml` — increment the build number after `+`
   by 1 every time, and bump the semantic part as appropriate
   (`1.0.2+3` → `1.0.3+4` for normal fixes, `1.1.0+4` for a feature, etc.).
2. Run `flutter build appbundle`. If the build fails, report the failure
   instead of guessing.
3. Stage and commit the version bump separately, e.g.
   `Bump version to 1.0.3+4`, then `git push`.
4. Tell the user the AAB path:
   `D:\IN SALAH\in_salah\build\app\outputs\bundle\release\app-release.aab`
   plus a ready-to-paste release notes block in `<en-US>...</en-US>` tags
   covering the changes since the previous release.

## Why this is enforced

- Every Play Console upload triggers a fresh review cycle. Stacking small
  fixes into one release is cheaper and easier to write release notes for.
- Version bumps belong in their own commit so the diff against the
  previous release is clean.
- The user wants explicit control over what reaches testers and when.

## Common mistakes to avoid

- Bumping `pubspec.yaml` in the same commit as a code fix.
- Running `flutter build appbundle` "to verify the change compiles" — use
  `flutter analyze` for that, not a release bundle build.
- Forgetting to push after committing — testers can only get the change
  after it is in `origin/main` AND the new AAB is uploaded.
