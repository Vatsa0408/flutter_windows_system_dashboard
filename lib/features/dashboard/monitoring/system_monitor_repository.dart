import 'dart:convert';
import 'dart:io';
import 'system_metrics.dart';
class SystemMonitorRepository {
 Future<SystemMetrics> read() async {
  if(!Platform.isWindows)throw UnsupportedError('Windows only');
  const script=r"""$cpu=Get-CimInstance Win32_Processor|Measure-Object -Property LoadPercentage -Average;$os=Get-CimInstance Win32_OperatingSystem;[PSCustomObject]@{cpu=[double]$cpu.Average;total=[double]$os.TotalVisibleMemorySize*1KB;free=[double]$os.FreePhysicalMemory*1KB}|ConvertTo-Json -Compress""";
  final p=await Process.run('powershell.exe',const['-NoLogo','-NoProfile','-NonInteractive','-Command',script]).timeout(const Duration(seconds:8));
  if(p.exitCode!=0)throw ProcessException('powershell.exe',const[],p.stderr.toString(),p.exitCode);
  final m=jsonDecode(p.stdout.toString())as Map<String,dynamic>;double gb(Object?x)=>((x as num?)?.toDouble()??0)/1073741824;
  return SystemMetrics(cpuPercent:((m['cpu']as num?)?.toDouble()??0).clamp(0,100),totalMemoryGb:gb(m['total']),freeMemoryGb:gb(m['free']),sampledAt:DateTime.now());
 }
}
