import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/app_logger.dart';
import 'process_action_service.dart';
import 'process_info.dart';
import 'process_repository.dart';

sealed class ProcessManagerEvent extends Equatable {
  const ProcessManagerEvent();
  @override
  List<Object?> get props => [];
}

final class ProcessManagerStarted extends ProcessManagerEvent {
  const ProcessManagerStarted();
}

final class ProcessManagerStopped extends ProcessManagerEvent {
  const ProcessManagerStopped();
}

final class ProcessRefreshRequested extends ProcessManagerEvent {
  const ProcessRefreshRequested();
}

final class ProcessSearchChanged extends ProcessManagerEvent {
  const ProcessSearchChanged(this.query);
  final String query;
  @override
  List<Object?> get props => [query];
}

final class ProcessSortChanged extends ProcessManagerEvent {
  const ProcessSortChanged(this.field);
  final ProcessSortField field;
  @override
  List<Object?> get props => [field];
}

final class ProcessSortDirectionToggled extends ProcessManagerEvent {
  const ProcessSortDirectionToggled();
}

final class ProcessRefreshIntervalChanged extends ProcessManagerEvent {
  const ProcessRefreshIntervalChanged(this.interval);
  final ProcessRefreshInterval interval;
  @override
  List<Object?> get props => [interval];
}

final class ProcessSelected extends ProcessManagerEvent {
  const ProcessSelected(this.process);
  final ProcessInfo? process;
  @override
  List<Object?> get props => [process];
}

final class ProcessFileLocationRequested extends ProcessManagerEvent {
  const ProcessFileLocationRequested(this.process);
  final ProcessInfo process;
  @override
  List<Object?> get props => [process];
}

final class ProcessTerminationConfirmed extends ProcessManagerEvent {
  const ProcessTerminationConfirmed(this.process);
  final ProcessInfo process;
  @override
  List<Object?> get props => [process];
}

final class ProcessRestartConfirmed extends ProcessManagerEvent {
  const ProcessRestartConfirmed(this.process);
  final ProcessInfo process;
  @override
  List<Object?> get props => [process];
}

enum ProcessManagerStatus { initial, loading, active, paused, failure }
enum ProcessActionStatus { idle, running, success, failure }
enum ProcessSortField { name, pid, cpu, memory, startTime, status }

enum ProcessRefreshInterval {
  twoSeconds('2 seconds', Duration(seconds: 2)),
  fiveSeconds('5 seconds', Duration(seconds: 5)),
  tenSeconds('10 seconds', Duration(seconds: 10));

  const ProcessRefreshInterval(this.label, this.duration);
  final String label;
  final Duration duration;
}

class ProcessManagerState extends Equatable {
  const ProcessManagerState({
    this.status = ProcessManagerStatus.initial,
    this.actionStatus = ProcessActionStatus.idle,
    this.processes = const [],
    this.query = '',
    this.sortField = ProcessSortField.cpu,
    this.sortAscending = false,
    this.refreshInterval = ProcessRefreshInterval.fiveSeconds,
    this.selectedProcess,
    this.errorMessage,
    this.actionMessage,
  });

  final ProcessManagerStatus status;
  final ProcessActionStatus actionStatus;
  final List<ProcessInfo> processes;
  final String query;
  final ProcessSortField sortField;
  final bool sortAscending;
  final ProcessRefreshInterval refreshInterval;
  final ProcessInfo? selectedProcess;
  final String? errorMessage;
  final String? actionMessage;

  List<ProcessInfo> get visibleProcesses {
    final normalizedQuery = query.trim().toLowerCase();
    final filtered = processes.where((process) {
      if (normalizedQuery.isEmpty) return true;
      return process.name.toLowerCase().contains(normalizedQuery) ||
          process.pid.toString().contains(normalizedQuery) ||
          (process.executablePath?.toLowerCase().contains(normalizedQuery) ?? false);
    }).toList();

    int compare(ProcessInfo left, ProcessInfo right) => switch (sortField) {
          ProcessSortField.name =>
            left.name.toLowerCase().compareTo(right.name.toLowerCase()),
          ProcessSortField.pid => left.pid.compareTo(right.pid),
          ProcessSortField.cpu => left.cpuPercent.compareTo(right.cpuPercent),
          ProcessSortField.memory => left.memoryBytes.compareTo(right.memoryBytes),
          ProcessSortField.startTime => (left.startTime ?? DateTime(1970))
              .compareTo(right.startTime ?? DateTime(1970)),
          ProcessSortField.status =>
            left.statusLabel.compareTo(right.statusLabel),
        };

    filtered.sort((left, right) {
      final result = compare(left, right);
      return sortAscending ? result : -result;
    });
    return filtered;
  }

  ProcessManagerState copyWith({
    ProcessManagerStatus? status,
    ProcessActionStatus? actionStatus,
    List<ProcessInfo>? processes,
    String? query,
    ProcessSortField? sortField,
    bool? sortAscending,
    ProcessRefreshInterval? refreshInterval,
    ProcessInfo? selectedProcess,
    bool clearSelection = false,
    String? errorMessage,
    bool clearError = false,
    String? actionMessage,
    bool clearActionMessage = false,
  }) => ProcessManagerState(
        status: status ?? this.status,
        actionStatus: actionStatus ?? this.actionStatus,
        processes: processes ?? this.processes,
        query: query ?? this.query,
        sortField: sortField ?? this.sortField,
        sortAscending: sortAscending ?? this.sortAscending,
        refreshInterval: refreshInterval ?? this.refreshInterval,
        selectedProcess:
            clearSelection ? null : selectedProcess ?? this.selectedProcess,
        errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
        actionMessage: clearActionMessage
            ? null
            : actionMessage ?? this.actionMessage,
      );

  @override
  List<Object?> get props => [
        status,
        actionStatus,
        processes,
        query,
        sortField,
        sortAscending,
        refreshInterval,
        selectedProcess,
        errorMessage,
        actionMessage,
      ];
}

class ProcessManagerBloc
    extends Bloc<ProcessManagerEvent, ProcessManagerState> {
  ProcessManagerBloc(this._repository, this._actions)
      : super(const ProcessManagerState()) {
    on<ProcessManagerStarted>(_onStarted);
    on<ProcessManagerStopped>(_onStopped);
    on<ProcessRefreshRequested>(_onRefresh);
    on<ProcessSearchChanged>((event, emit) => emit(state.copyWith(query: event.query)));
    on<ProcessSortChanged>((event, emit) => emit(state.copyWith(sortField: event.field)));
    on<ProcessSortDirectionToggled>((event, emit) =>
        emit(state.copyWith(sortAscending: !state.sortAscending)));
    on<ProcessRefreshIntervalChanged>(_onIntervalChanged);
    on<ProcessSelected>((event, emit) => emit(state.copyWith(
          selectedProcess: event.process,
          clearSelection: event.process == null,
        )));
    on<ProcessFileLocationRequested>(_onOpenLocation);
    on<ProcessTerminationConfirmed>(_onTerminate);
    on<ProcessRestartConfirmed>(_onRestart);
  }

  final ProcessRepository _repository;
  final ProcessActionService _actions;
  Timer? _timer;
  bool _refreshInProgress = false;

  void _onStarted(ProcessManagerStarted event, Emitter<ProcessManagerState> emit) {
    _restartTimer();
    emit(state.copyWith(status: ProcessManagerStatus.loading, clearError: true));
    add(const ProcessRefreshRequested());
  }

  void _onStopped(ProcessManagerStopped event, Emitter<ProcessManagerState> emit) {
    _timer?.cancel();
    _timer = null;
    emit(state.copyWith(status: ProcessManagerStatus.paused));
  }

  Future<void> _onRefresh(
    ProcessRefreshRequested event,
    Emitter<ProcessManagerState> emit,
  ) async {
    if (_refreshInProgress) return;
    _refreshInProgress = true;
    try {
      final processes = await _repository.getProcesses();
      final selectedPid = state.selectedProcess?.pid;
      ProcessInfo? updatedSelection;
      if (selectedPid != null) {
        for (final process in processes) {
          if (process.pid == selectedPid) {
            updatedSelection = process;
            break;
          }
        }
      }
      emit(state.copyWith(
        status: _timer == null
            ? ProcessManagerStatus.paused
            : ProcessManagerStatus.active,
        processes: processes,
        selectedProcess: updatedSelection,
        clearSelection: selectedPid != null && updatedSelection == null,
        clearError: true,
      ));
    } catch (error, stackTrace) {
      AppLogger.error('Process refresh failed', error, stackTrace);
      emit(state.copyWith(
        status: ProcessManagerStatus.failure,
        errorMessage: 'Unable to retrieve processes: $error',
      ));
    } finally {
      _refreshInProgress = false;
    }
  }

  void _onIntervalChanged(
    ProcessRefreshIntervalChanged event,
    Emitter<ProcessManagerState> emit,
  ) {
    emit(state.copyWith(refreshInterval: event.interval));
    if (_timer != null) _restartTimer(interval: event.interval);
  }

  Future<void> _onOpenLocation(
    ProcessFileLocationRequested event,
    Emitter<ProcessManagerState> emit,
  ) async {
    await _runAction(emit, () => _actions.openFileLocation(event.process),
        'Opened the executable location.');
  }

  Future<void> _onTerminate(
    ProcessTerminationConfirmed event,
    Emitter<ProcessManagerState> emit,
  ) async {
    await _runAction(emit, () => _actions.terminate(event.process),
        '${event.process.name} was terminated.');
    add(const ProcessRefreshRequested());
  }

  Future<void> _onRestart(
    ProcessRestartConfirmed event,
    Emitter<ProcessManagerState> emit,
  ) async {
    await _runAction(emit, () => _actions.restart(event.process),
        '${event.process.name} was restarted.');
    add(const ProcessRefreshRequested());
  }

  Future<void> _runAction(
    Emitter<ProcessManagerState> emit,
    Future<void> Function() operation,
    String successMessage,
  ) async {
    emit(state.copyWith(
      actionStatus: ProcessActionStatus.running,
      clearActionMessage: true,
    ));
    try {
      await operation();
      emit(state.copyWith(
        actionStatus: ProcessActionStatus.success,
        actionMessage: successMessage,
      ));
    } catch (error, stackTrace) {
      AppLogger.error('Process action failed', error, stackTrace);
      emit(state.copyWith(
        actionStatus: ProcessActionStatus.failure,
        actionMessage: 'Action failed: $error',
      ));
    }
  }

  void _restartTimer({ProcessRefreshInterval? interval}) {
    _timer?.cancel();
    _timer = Timer.periodic(
      (interval ?? state.refreshInterval).duration,
      (_) => add(const ProcessRefreshRequested()),
    );
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
