# Guardian App

Flutter client for Guardian.

## Install And Run (Android)

Run from this folder only:

```powershell
cd C:\experiments\ai-elderly-scam\guardian_app
flutter clean
flutter pub get
flutter run
```

## Expected Android Identity

- App label: `Guardian`
- Package: `com.guardian.guardian`

If you see `mlkit_runner`, you are running the other Flutter app at:
`C:\experiments\ai-elderly-scam\mlkit_runner`.

## Quick Device Checks

```powershell
adb shell pm list packages | Select-String "com.guardian.guardian"
adb shell pm list packages | Select-String "com.aielderlyscam.mlkit_runner"
```

## Firebase Setup Blocker (Required For Real Build)

This app is wired for Firebase Core + Auth/Firestore + Crashlytics, but real
Firebase credentials are intentionally not checked into the repo.

Required before full Firebase behavior works:

1. Add a real `google-services.json` from Firebase Console to:
   `guardian_app/android/app/google-services.json`
2. Run `flutter pub get` in `guardian_app/` after pulling dependency updates.

Without the real `google-services.json`, app bootstrap stays defensive and
continues to run locally, but Firebase/Crashlytics initialization will be
skipped.

## Play Console Video Flow (Accessibility Declaration)

Use this in the recording:

1. Open Guardian.
2. Go through onboarding and choose `I am the parent / elder`.
3. On the parent disclosure screen, show `Guardian needs one permission` and the supporting bullets.
4. Open `See exactly what Guardian can and cannot see →` and slowly show the standalone `Permissions & privacy` disclosure screen.
5. Return to the parent disclosure screen, tap `Open Android Accessibility settings`, and enable `Guardian payment protection` in Android settings.
6. Return to the app and show `Live payment protection is on`.
7. Continue to `Guardian is ready.` and then open the parent home screen.
8. Show `Protection summary` and the `Privacy and permissions` card.
9. Re-open `Privacy and permissions` from home to prove the disclosure remains reachable after setup.

Do not use the old labels `I Agree - Enable Protection`, `Not now`, `Protection monitor active`, or `Last monitored app`; the app now uses the updated copy above.
