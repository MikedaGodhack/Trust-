# IRS Refund Tracker (Flutter)

This is a lightweight Flutter project you can build into an APK on Android.

## What this app does
- Shows a **countdown** to your expected deposit date.
- Lets you log **IRS transcript codes** (150, 806, 570, 971, 290, 846, etc.).
- Auto-derives **status** from the codes you enter.
- Displays a **timeline** of your case based on your entries.
- Stores everything **locally** on the device (no cloud).

## How to set up (first time)
1. Install Flutter SDK: https://docs.flutter.dev/get-started/install
2. Enable Android developer mode + USB debugging (on your phone).
3. In a terminal, run:
   ```bash
   git init irs_tracker_flutter && cd irs_tracker_flutter
   flutter create .
   ```
4. Replace the generated `lib/` and `pubspec.yaml` with the ones from this download.
5. Get packages and run:
   ```bash
   flutter pub get
   flutter run
   ```

## Build a release APK
```bash
flutter build apk --release
```
The APK will be at:
```
build/app/outputs/flutter-apk/app-release.apk
```

## Notes
- Data is stored with `shared_preferences` on-device only.
- You can update the default expected deposit date in **Settings**.
- You can export/import a simple JSON backup from Settings.
