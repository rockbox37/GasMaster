# GasMaster

**Fuel economy tracking for every vehicle in your garage.**

Log fill-ups, watch MPG (or L/100km) trend over time, and keep a clear picture of what each car actually costs to run — all on-device, no cloud account required.

© Jirius Group LLC

---

## What it does

GasMaster is a multi-vehicle fuel economy tracker. Add cars (or trucks, bikes, whatever you fill), record each stop at the pump, and get running averages, charts, and monthly/yearly totals without exporting your life to a server.

Your fill-ups and vehicle data stay on this device.

## Features

- **Multi-vehicle garage** — manage a fleet from one home screen; tap into any vehicle for history and stats
- **Fill-up logging** — odometer, fuel volume, price, date, and a **full-tank** flag so partial top-offs don’t skew efficiency
- **Stats & charts** — MPG or L/100km, running averages, spend and distance totals, plus monthly and yearly aggregates
- **CSV export & share** — export fill-up history or share a quick stats summary
- **Vehicle photos** — attach a photo per vehicle; images are resized/compressed automatically with clear savings feedback
- **Imperial or metric** — miles/gallons or kilometers/liters
- **Local persistence** — Hive for fast on-device storage, with JSON backup/restore for durability across upgrades
- **Branding** — GasMaster logo, native splash, and an About screen with version info and © Jirius Group LLC

## Getting started

### Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install) (SDK `>=3.4.0`)
- Xcode (for iOS / macOS) or Android Studio / SDK (for Android)

### Run

```bash
flutter pub get
flutter run
```

Target a specific platform when you want:

```bash
flutter run -d ios        # Simulator or device via Xcode
flutter run -d android    # Emulator or device
flutter run -d macos      # Desktop
```

Generate launcher icons / splash (after changing assets under `assets/branding/`):

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

## Tech stack

| Layer | Choice |
| --- | --- |
| UI | Flutter (Material) |
| State | Riverpod (`flutter_riverpod`) |
| Navigation | GoRouter |
| Local DB | Hive + `hive_flutter` |
| Charts | fl_chart |
| Preferences | shared_preferences |
| Export / share | path_provider, share_plus |
| Photos | image_picker, `image` (resize/JPEG optimize) |
| Branding | flutter_launcher_icons, flutter_native_splash, package_info_plus |

## Project structure

```
lib/
  main.dart                 # App bootstrap, Hive init, GoRouter
  models/                   # Vehicle, FillUp (+ Hive adapters)
  screens/                  # Garage, vehicle detail, add/edit flows, About
  services/                 # Local repo, JSON backup, preferences, photo optimize
  state/                    # Riverpod app state
  utils/                    # Stats, CSV export, helpers
  widgets/                  # Branding, vehicle avatar, photo picker
assets/branding/            # Logo & app icon
test/                       # Unit / service tests
```

## Contributing

Work on a feature branch and open a pull request into `main`. CI runs `flutter analyze` and `flutter test` on every PR; keep those green before merging.

## Privacy

GasMaster does not upload your garage to the cloud. Data is stored locally on the device (Hive), with a JSON backup written for restore resilience.

---

Built with Flutter · © Jirius Group LLC
