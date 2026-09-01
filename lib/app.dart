import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'features/settings/theme_cubit.dart';
import 'features/shell/app_shell.dart';

class DashboardApp extends StatelessWidget {
  const DashboardApp({super.key});
  @override Widget build(BuildContext context) => BlocBuilder<ThemeCubit, ThemeMode>(builder: (_, mode) => FluentApp(
    title: 'Windows System Dashboard', debugShowCheckedModeBanner: false, themeMode: mode,
    theme: FluentThemeData(brightness: Brightness.light, accentColor: Colors.blue),
    darkTheme: FluentThemeData(brightness: Brightness.dark, accentColor: Colors.blue),
    home: const AppShell(),
  ));
}
