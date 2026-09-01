import 'package:equatable/equatable.dart';
class SystemMetrics extends Equatable {
 const SystemMetrics({required this.cpuPercent,required this.totalMemoryGb,required this.freeMemoryGb,required this.sampledAt});
 final double cpuPercent,totalMemoryGb,freeMemoryGb; final DateTime sampledAt;
 double get usedMemoryGb=>(totalMemoryGb-freeMemoryGb).clamp(0,totalMemoryGb);
 double get memoryPercent=>totalMemoryGb<=0?0:(usedMemoryGb/totalMemoryGb*100).clamp(0,100);
 @override List<Object?>get props=>[cpuPercent,totalMemoryGb,freeMemoryGb,sampledAt];
}
