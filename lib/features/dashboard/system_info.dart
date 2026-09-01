import 'package:equatable/equatable.dart';
class SystemInfo extends Equatable {
  const SystemInfo({required this.computer, required this.user, required this.os, required this.version, required this.cpu, required this.cores, required this.totalRam, required this.freeRam, required this.drive, required this.totalDisk, required this.freeDisk, required this.booted, required this.updated});
  final String computer, user, os, version, cpu, drive;
  final int cores; final double totalRam, freeRam, totalDisk, freeDisk; final DateTime? booted; final DateTime updated;
  double get ramUsage => totalRam == 0 ? 0 : ((totalRam-freeRam)/totalRam).clamp(0,1);
  double get diskUsage => totalDisk == 0 ? 0 : ((totalDisk-freeDisk)/totalDisk).clamp(0,1);
  @override List<Object?> get props => [computer,user,os,version,cpu,cores,totalRam,freeRam,drive,totalDisk,freeDisk,booted,updated];
}
