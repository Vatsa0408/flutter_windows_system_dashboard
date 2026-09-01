# Windows System Dashboard

## Integration

```powershell
flutter create --platforms=windows windows_system_dashboard
cd windows_system_dashboard
# Copy this package's pubspec.yaml, analysis_options.yaml and lib folder here
flutter pub get
dart format lib
flutter analyze
flutter run -d windows
```

The app uses Fluent UI, BLoC, PowerShell/CIM system queries, detached developer-tool processes, responsive cards, theme switching, error states, and logging. The command panel executes with the current user's permissions, so only run trusted commands.
