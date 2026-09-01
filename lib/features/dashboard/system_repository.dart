import 'dart:convert';
import 'dart:io';
import '../../core/app_logger.dart';
import 'system_info.dart';
class SystemRepository {
  Future<SystemInfo> load() async {
    if (!Platform.isWindows) throw UnsupportedError('Windows only');
    const script = r"""$o=Get-CimInstance Win32_OperatingSystem;$c=Get-CimInstance Win32_Processor|Select-Object -First 1;$d=Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'";[PSCustomObject]@{computer=$env:COMPUTERNAME;user=$env:USERNAME;os=$o.Caption;version=$o.Version;cpu=$c.Name;cores=$c.NumberOfLogicalProcessors;totalRam=[double]$o.TotalVisibleMemorySize*1KB;freeRam=[double]$o.FreePhysicalMemory*1KB;drive=$d.DeviceID;totalDisk=[double]$d.Size;freeDisk=[double]$d.FreeSpace;booted=$o.LastBootUpTime.ToString('o')}|ConvertTo-Json -Compress""";
    AppLogger.info('Collecting system information');
    final p = await Process.run('powershell.exe',['-NoLogo','-NoProfile','-NonInteractive','-Command',script]).timeout(const Duration(seconds: 15));
    if (p.exitCode != 0) throw ProcessException('powershell.exe', const [], p.stderr.toString(), p.exitCode);
    final m=jsonDecode(p.stdout.toString()) as Map<String,dynamic>; double gb(Object? x)=>((x as num?)?.toDouble()??0)/1073741824;
    return SystemInfo(computer:m['computer']??'Unknown',user:m['user']??'Unknown',os:m['os']??'Windows',version:m['version']??'Unknown',cpu:(m['cpu']??'Unknown').toString().trim(),cores:(m['cores'] as num?)?.toInt()??0,totalRam:gb(m['totalRam']),freeRam:gb(m['freeRam']),drive:m['drive']??'Unknown',totalDisk:gb(m['totalDisk']),freeDisk:gb(m['freeDisk']),booted:DateTime.tryParse('${m['booted']??''}'),updated:DateTime.now());
  }
}
