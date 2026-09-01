import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app.dart';
import 'core/app_logger.dart';
import 'features/dashboard/dashboard_bloc.dart';
import 'features/dashboard/monitoring/system_monitor_bloc.dart';
import 'features/dashboard/monitoring/system_monitor_repository.dart';
import 'features/dashboard/system_repository.dart';
import 'features/processes/process_action_service.dart';
import 'features/processes/process_manager_bloc.dart';
import 'features/processes/process_repository.dart';
import 'features/settings/theme_cubit.dart';
import 'features/utilities/tool_detection_bloc.dart';
import 'features/utilities/utility_bloc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLogger.init();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLogger.error('Flutter error', details.exception, details.stack);
  };

  if (!Platform.isWindows) {
    AppLogger.warning('This application is intended for Windows.');
  }

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ThemeCubit()),
        BlocProvider(
          create: (_) => DashboardBloc(SystemRepository())
            ..add(const DashboardRefreshRequested()),
        ),
        BlocProvider(
          create: (_) => SystemMonitorBloc(SystemMonitorRepository())
            ..add(const SystemMonitorStarted()),
        ),
        BlocProvider(create: (_) => UtilityBloc()),
        BlocProvider(
          create: (_) => ToolDetectionBloc()
            ..add(const ToolDetectionRequested()),
        ),
        BlocProvider(
          create: (_) => ProcessManagerBloc(
            WindowsProcessRepository(),
            WindowsProcessActionService(),
          )..add(const ProcessManagerStarted()),
        ),
      ],
      child: const DashboardApp(),
    ),
  );
}
