import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/app_logger.dart';

enum DevUtility {
  terminal,
  powershell,
  commandPrompt,
  vscode,
  gitBash,
  taskManager,
  deviceManager,
  environment,
}

extension DevUtilityX on DevUtility {
  String get label => switch (this) {
        DevUtility.terminal => 'Windows Terminal',
        DevUtility.powershell => 'PowerShell',
        DevUtility.commandPrompt => 'Command Prompt',
        DevUtility.vscode => 'Visual Studio Code',
        DevUtility.gitBash => 'Git Bash',
        DevUtility.taskManager => 'Task Manager',
        DevUtility.deviceManager => 'Device Manager',
        DevUtility.environment => 'Environment Variables',
      };

  String get executable => switch (this) {
        DevUtility.terminal => 'wt.exe',
        DevUtility.powershell => 'powershell.exe',
        DevUtility.commandPrompt => 'cmd.exe',
        DevUtility.vscode => 'code.cmd',
        DevUtility.gitBash => 'git-bash.exe',
        DevUtility.taskManager => 'taskmgr.exe',
        DevUtility.deviceManager => 'devmgmt.msc',
        DevUtility.environment => 'rundll32.exe',
      };

  List<String> get arguments => this == DevUtility.environment
      ? const ['sysdm.cpl,EditEnvironmentVariables']
      : const [];
}

sealed class UtilityEvent extends Equatable {
  const UtilityEvent();

  @override
  List<Object?> get props => [];
}

final class LaunchRequested extends UtilityEvent {
  const LaunchRequested(this.utility);

  final DevUtility utility;

  @override
  List<Object?> get props => [utility];
}

final class CommandRequested extends UtilityEvent {
  const CommandRequested(this.command);

  final String command;

  @override
  List<Object?> get props => [command];
}

enum UtilityStatus { idle, running, success, failure }

class UtilityState extends Equatable {
  const UtilityState({
    this.status = UtilityStatus.idle,
    this.message,
    this.output = '',
  });

  final UtilityStatus status;
  final String? message;
  final String output;

  @override
  List<Object?> get props => [status, message, output];
}

class UtilityBloc extends Bloc<UtilityEvent, UtilityState> {
  UtilityBloc() : super(const UtilityState()) {
    on<LaunchRequested>(_onLaunchRequested);
    on<CommandRequested>(_onCommandRequested);
  }

  Future<void> _onLaunchRequested(
    LaunchRequested event,
    Emitter<UtilityState> emit,
  ) async {
    if (!Platform.isWindows) {
      emit(
        const UtilityState(
          status: UtilityStatus.failure,
          message: 'Developer utilities can only be launched on Windows.',
        ),
      );
      return;
    }

    emit(const UtilityState(status: UtilityStatus.running));

    try {
      await Process.start(
        event.utility.executable,
        event.utility.arguments,
        mode: ProcessStartMode.detached,
        runInShell: true,
      );

      emit(
        UtilityState(
          status: UtilityStatus.success,
          message: '${event.utility.label} launched.',
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.error('Utility launch failed', error, stackTrace);
      emit(
        UtilityState(
          status: UtilityStatus.failure,
          message: 'Could not launch ${event.utility.label}: $error',
        ),
      );
    }
  }

  Future<void> _onCommandRequested(
    CommandRequested event,
    Emitter<UtilityState> emit,
  ) async {
    final command = event.command.trim();

    if (command.isEmpty) {
      emit(
        const UtilityState(
          status: UtilityStatus.failure,
          message: 'Enter a PowerShell command first.',
        ),
      );
      return;
    }

    if (!Platform.isWindows) {
      emit(
        const UtilityState(
          status: UtilityStatus.failure,
          message: 'PowerShell command execution is available on Windows only.',
        ),
      );
      return;
    }

    emit(const UtilityState(status: UtilityStatus.running));

    try {
      final result = await Process.run(
        'powershell.exe',
        [
          '-NoLogo',
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          command,
        ],
        runInShell: false,
      ).timeout(const Duration(seconds: 30));

      final standardOutput = result.stdout.toString().trim();
      final standardError = result.stderr.toString().trim();
      final outputParts = <String>[
        if (standardOutput.isNotEmpty) standardOutput,
        if (standardError.isNotEmpty) standardError,
      ];

      emit(
        UtilityState(
          status: result.exitCode == 0
              ? UtilityStatus.success
              : UtilityStatus.failure,
          message: 'Command finished with exit code ${result.exitCode}.',
          output: outputParts.join('\n'),
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.error('PowerShell command failed', error, stackTrace);
      emit(
        UtilityState(
          status: UtilityStatus.failure,
          message: 'Command failed: $error',
        ),
      );
    }
  }
}
