import 'package:equatable/equatable.dart';

enum ProcessRuntimeStatus { running, suspended, unknown }

class ProcessInfo extends Equatable {
  const ProcessInfo({
    required this.name,
    required this.pid,
    required this.cpuPercent,
    required this.memoryBytes,
    required this.executablePath,
    required this.startTime,
    required this.status,
    required this.threadCount,
    required this.handleCount,
    required this.isCritical,
  });

  final String name;
  final int pid;
  final double cpuPercent;
  final int memoryBytes;
  final String? executablePath;
  final DateTime? startTime;
  final ProcessRuntimeStatus status;
  final int threadCount;
  final int handleCount;
  final bool isCritical;

  double get memoryMb => memoryBytes / 1048576;

  String get statusLabel => switch (status) {
        ProcessRuntimeStatus.running => 'Running',
        ProcessRuntimeStatus.suspended => 'Suspended',
        ProcessRuntimeStatus.unknown => 'Unknown',
      };

  @override
  List<Object?> get props => [
        name,
        pid,
        cpuPercent,
        memoryBytes,
        executablePath,
        startTime,
        status,
        threadCount,
        handleCount,
        isCritical,
      ];
}
