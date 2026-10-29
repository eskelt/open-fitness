# Open Fitness

**Free, open-source running statistics for your Xiaomi / Redmi watch, straight from your own Mi Fitness account.**

Open Fitness signs in to your Xiaomi account and reads your workout data directly
from Xiaomi's cloud, giving you richer, clearer stats than the official app,
without waiting on Mi Fitness updates. Your data, your way.

> ⚠️ **Unofficial.** Open Fitness is not affiliated with, endorsed by, or
> connected to Xiaomi. It talks to the same cloud API the official Mi Fitness app
> uses, with *your own* credentials, to read *your own* data. Use at your own risk.

## Status

Early but working. The app is **focused on running** for now. The data layer
already parses other sports (cycling, swimming, walking, hiking, tennis, strength,
…), and they'll be surfaced in the UI as each sport's stats are polished. See the
[Roadmap](#roadmap).

## Features

- **Sign in with your Xiaomi account**: the same one you use in Mi Fitness,
  including Xiaomi's new-device verification (handled in-app, see below).
- **Summary**: total distance, time, calories, average pace, average heart rate,
  plus this-week / this-month distance.
- **Weekly volume** chart over the last 12 weeks.
- **Personal records**: longest distance, longest time, fastest average pace,
  best VO₂max, most calories, best training effect.
- **Heart-rate zones** breakdown.
- **Per-session detail**: pace, speed, cadence, stride length, HR and HR zones,
  VO₂max, training effect, training load, and Xiaomi's race-time predictions
  (5K / 10K / half / full marathon).
- **English & Spanish**, auto-detected from your device and switchable in settings.
- **Offline cache**: your latest data is there even without a connection.

## Privacy & security

- Your **password never leaves your device** except to Xiaomi's official login
  servers. It is used only to compute the login hash Xiaomi's endpoint expects;
  never stored, never logged, never sent anywhere else.
- Only the resulting **session token** is stored locally, so you don't have to log
  in every time.
- The app uses a **stable device identifier** (the system `ANDROID_ID`) so Xiaomi
  recognizes your device across reinstalls and doesn't ask you to re-verify every
  time, exactly like the official app.
- All network traffic goes **only** to Xiaomi's own servers. There are no
  analytics, trackers, or third-party backends.

## First sign-in & device verification

The first time you sign in on a new device, Xiaomi may ask you to verify it (an
email or SMS code). Open Fitness opens that verification **inside the app** (in a
WebView carrying your device identity), so the verification binds to this device.
After you confirm, sign-in completes and future logins won't ask again.

## Regions

Xiaomi stores your data in a regional data center. Pick yours on the login screen:

| Code | Region |
|------|--------|
| `de` | Europe (default) |
| `sg` | Asia / Singapore |
| `in` | India |
| `ru` | Russia |
| `i2` | Americas |
| `cn` | China |

If sign-in succeeds but no sessions show up, your account is probably in another
region; try a different one.

## Build & run

Android app built with [Flutter](https://docs.flutter.dev/get-started/install)
(3.29+). You'll need the Flutter SDK and the Android SDK.

```bash
flutter pub get
flutter run                 # on a connected device/emulator
# or build an installable APK:
flutter build apk --release # -> build/app/outputs/flutter-apk/
```

## How it works

Open Fitness reproduces the Mi Fitness cloud protocol end to end: Xiaomi Passport
password login, in-app device verification, per-request signing with RC4
encryption, and the region-specific data host. It then pages through your sport
records via `get_sport_records_by_time` and computes every statistic locally on
your device.

## License

[MIT](LICENSE). Free to use, modify and share.
