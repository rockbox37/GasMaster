# GasMaster Agent Instructions

## Project overview

GasMaster is a Flutter app for tracking fuel economy across multiple vehicles. It
stores vehicle and fill-up data locally; it does not require a cloud account.

## Architecture

- `lib/models/`: Hive-persisted `Vehicle` and `FillUp` models plus generated adapters.
- `lib/screens/`: route-level Flutter screens and user flows.
- `lib/services/`: persistence, JSON backup/restore, preferences, and vehicle photos.
- `lib/state/`: Riverpod providers and notifiers.
- `lib/utils/`: calculation, export, sharing, and other reusable helpers.
- `lib/widgets/`: reusable presentation components.
- `test/`: unit, service, widget, and state-management tests organized by layer.

Keep persistence and platform I/O in services. Prefer pure, deterministic utility
functions for calculations and formatting. Update tests when changing provider,
repository, backup, or photo behavior.

## Development workflow

- Work on a feature branch; do not commit directly to `main`.
- Open a pull request into `main` for every change.
- Do not force-push shared branches.
- Keep changes focused and avoid committing generated build output or local IDE files.

## Validation

From the repository root, run:

```sh
flutter pub get
flutter analyze
flutter test
```

Format changed Dart files with:

```sh
dart format lib test
```

CI runs `flutter analyze` and `flutter test`; both must pass before merging.

## Testing guidance

- Use temporary Hive directories and document directories for persistence tests.
- Register Hive adapters once per test isolate and close Hive boxes in teardown.
- Mock `SharedPreferences` with `SharedPreferences.setMockInitialValues`.
- Reset `BackupService.documentsOverride` and `VehiclePhotoService.documentsOverride`
  during teardown.
- Cover listener/provider updates after repository mutations, not only direct box state.

## Data and platform considerations

- Preserve the existing Hive schema and adapter type IDs unless a migration is
  intentionally designed and tested.
- Keep JSON backup compatibility and validate import scope/version behavior.
- Vehicle photo paths are relative to the application documents directory.
- Preserve both imperial and metric calculations.
- Keep user data on-device unless a future change explicitly introduces a reviewed
  backend integration.
