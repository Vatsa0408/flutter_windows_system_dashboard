import 'package:equatable/equatable.dart';

class SystemMetrics extends Equatable {
  const SystemMetrics({
    required this.cpuPercent,
    required this.totalMemoryGb,
    required this.freeMemoryGb,
    required this.sampledAt,
  });

  final double cpuPercent;
  final double totalMemoryGb;
  final double freeMemoryGb;
  final DateTime sampledAt;

  double get usedMemoryGb =>
      (totalMemoryGb - freeMemoryGb).clamp(0, totalMemoryGb).toDouble();

  double get memoryPercent {
    if (totalMemoryGb <= 0) return 0;
    return (usedMemoryGb / totalMemoryGb * 100).clamp(0, 100).toDouble();
  }

  @override
  List<Object?> get props => [
        cpuPercent,
        totalMemoryGb,
        freeMemoryGb,
        sampledAt,
      ];
}
