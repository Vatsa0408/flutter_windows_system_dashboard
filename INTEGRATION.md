# Process Manager integration

## Replace

- `pubspec.yaml`
- `lib/main.dart`
- `lib/features/shell/app_shell.dart`

## Add

- `lib/features/processes/process_info.dart`
- `lib/features/processes/process_repository.dart`
- `lib/features/processes/process_action_service.dart`
- `lib/features/processes/process_manager_bloc.dart`
- `lib/features/processes/process_manager_page.dart`

No new package is required beyond the packages already used by the historical-chart version. Clipboard support comes from Flutter's built-in `services.dart` API.

## Run

```powershell
flutter clean
flutter pub get
dart format lib
flutter analyze
flutter run -d windows
```

## CPU behavior

The first sample shows 0% because per-process CPU is calculated from the difference between two cumulative CPU-time samples. A meaningful value appears after the next refresh.

## Security behavior

- Critical Windows processes, PID 0 to 4, and the dashboard itself are protected.
- End and Restart require typing the exact process name.
- Some process details and actions require elevated permissions.
- Restart is enabled only when a readable executable path is available.
- Restart cannot restore original command-line arguments or unsaved application state.
