import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/app_logger.dart';
import 'system_metrics.dart';
import 'system_monitor_repository.dart';

sealed class SystemMonitorEvent extends Equatable {
  const SystemMonitorEvent();

  @override
  List<Object?> get props => [];
}

final class SystemMonitorStarted extends SystemMonitorEvent {
  const SystemMonitorStarted();
}

final class SystemMonitorStopped extends SystemMonitorEvent {
  const SystemMonitorStopped();
}

final class SystemMonitorTicked extends SystemMonitorEvent {
  const SystemMonitorTicked();
}

final class SystemMonitorHistoryCleared extends SystemMonitorEvent {
  const SystemMonitorHistoryCleared();
}

final class SystemMonitorWindowChanged extends SystemMonitorEvent {
  const SystemMonitorWindowChanged(this.window);

  final MonitorHistoryWindow window;

  @override
  List<Object?> get props => [window];
}

enum SystemMonitorStatus { initial, loading, active, paused, failure }

enum MonitorHistoryWindow {
  oneMinute('1 minute', 30),
  twoMinutes('2 minutes', 60),
  fourMinutes('4 minutes', 120);

  const MonitorHistoryWindow(this.label, this.maximumSamples);

  final String label;
  final int maximumSamples;
}

class SystemMonitorState extends Equatable {
  const SystemMonitorState({
    this.status = SystemMonitorStatus.initial,
    this.metrics,
    this.history = const [],
    this.historyWindow = MonitorHistoryWindow.twoMinutes,
    this.error,
  });

  final SystemMonitorStatus status;
  final SystemMetrics? metrics;
  final List<SystemMetrics> history;
  final MonitorHistoryWindow historyWindow;
  final String? error;

  bool get isRunning => status != SystemMonitorStatus.paused;

  double get averageCpu => _average(history.map((item) => item.cpuPercent));
  double get maximumCpu => _maximum(history.map((item) => item.cpuPercent));
  double get averageMemory =>
      _average(history.map((item) => item.memoryPercent));
  double get maximumMemory =>
      _maximum(history.map((item) => item.memoryPercent));

  static double _average(Iterable<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((first, second) => first + second) / values.length;
  }

  static double _maximum(Iterable<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((first, second) => first > second ? first : second);
  }

  SystemMonitorState copyWith({
    SystemMonitorStatus? status,
    SystemMetrics? metrics,
    List<SystemMetrics>? history,
    MonitorHistoryWindow? historyWindow,
    String? error,
    bool clearError = false,
  }) {
    return SystemMonitorState(
      status: status ?? this.status,
      metrics: metrics ?? this.metrics,
      history: history ?? this.history,
      historyWindow: historyWindow ?? this.historyWindow,
      error: clearError ? null : error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [
        status,
        metrics,
        history,
        historyWindow,
        error,
      ];
}

class SystemMonitorBloc
    extends Bloc<SystemMonitorEvent, SystemMonitorState> {
  SystemMonitorBloc(this.repository) : super(const SystemMonitorState()) {
    on<SystemMonitorStarted>(_onStarted);
    on<SystemMonitorStopped>(_onStopped);
    on<SystemMonitorTicked>(_onTicked);
    on<SystemMonitorHistoryCleared>(_onHistoryCleared);
    on<SystemMonitorWindowChanged>(_onWindowChanged);
  }

  final SystemMonitorRepository repository;
  Timer? _timer;
  bool _sampleInProgress = false;

  void _onStarted(
    SystemMonitorStarted event,
    Emitter<SystemMonitorState> emit,
  ) {
    _timer?.cancel();
    emit(state.copyWith(
      status: SystemMonitorStatus.loading,
      clearError: true,
    ));
    add(const SystemMonitorTicked());
    _timer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => add(const SystemMonitorTicked()),
    );
  }

  void _onStopped(
    SystemMonitorStopped event,
    Emitter<SystemMonitorState> emit,
  ) {
    _timer?.cancel();
    _timer = null;
    emit(state.copyWith(status: SystemMonitorStatus.paused));
  }

  Future<void> _onTicked(
    SystemMonitorTicked event,
    Emitter<SystemMonitorState> emit,
  ) async {
    if (_sampleInProgress || _timer == null) return;
    _sampleInProgress = true;

    try {
      final sample = await repository.read();
      final updatedHistory = [...state.history, sample];
      final maximumSamples = state.historyWindow.maximumSamples;
      final boundedHistory = updatedHistory.length > maximumSamples
          ? updatedHistory.sublist(updatedHistory.length - maximumSamples)
          : updatedHistory;

      emit(state.copyWith(
        status: SystemMonitorStatus.active,
        metrics: sample,
        history: List.unmodifiable(boundedHistory),
        clearError: true,
      ));
    } catch (error, stackTrace) {
      AppLogger.error('Monitoring failed', error, stackTrace);
      emit(state.copyWith(
        status: SystemMonitorStatus.failure,
        error: 'Monitoring failed: $error',
      ));
    } finally {
      _sampleInProgress = false;
    }
  }

  void _onHistoryCleared(
    SystemMonitorHistoryCleared event,
    Emitter<SystemMonitorState> emit,
  ) {
    emit(state.copyWith(history: const []));
  }

  void _onWindowChanged(
    SystemMonitorWindowChanged event,
    Emitter<SystemMonitorState> emit,
  ) {
    final maximumSamples = event.window.maximumSamples;
    final trimmedHistory = state.history.length > maximumSamples
        ? state.history.sublist(state.history.length - maximumSamples)
        : state.history;

    emit(state.copyWith(
      historyWindow: event.window,
      history: List.unmodifiable(trimmedHistory),
    ));
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
