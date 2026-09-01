import 'dart:io';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'app.dart';
import 'core/app_logger.dart';
import 'features/dashboard/dashboard_bloc.dart';
import 'features/dashboard/system_repository.dart';
import 'features/settings/theme_cubit.dart';
import 'features/utilities/utility_bloc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLogger.init();
  FlutterError.onError = (d) {
    FlutterError.presentError(d);
    AppLogger.error('Flutter error', d.exception, d.stack);
  };
  if (!Platform.isWindows)
    AppLogger.warning('This application is intended for Windows.');
  runApp(MultiBlocProvider(providers: [
    BlocProvider(create: (_) => ThemeCubit()),
    BlocProvider(
        create: (_) => DashboardBloc(SystemRepository())
          ..add(const DashboardRefreshRequested())),
    BlocProvider(create: (_) => UtilityBloc()),
  ], child: const DashboardApp()));
}
