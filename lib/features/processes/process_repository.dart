import 'dart:convert';
import 'dart:io';

import '../../core/app_logger.dart';
import 'process_info.dart';

abstract interface class ProcessRepository {
  Future<List<ProcessInfo>> getProcesses();
}

class WindowsProcessRepository implements ProcessRepository {
  Map<int, _PreviousCpuSample> _previousCpuSamples = const {};

  static const _criticalProcessNames = <String>{
    'system',
    'registry',
    'smss',
    'csrss',
    'wininit',
    'services',
    'lsass',
    'winlogon',
    'dwm',
    'fontdrvhost',
    'memory compression',
    'secure system',
  };

  @override
  Future<List<ProcessInfo>> getProcesses() async {
    if (!Platform.isWindows) {
      throw UnsupportedError(
        'The process manager is available on Windows only.',
      );
    }

    const script = r'''
$items = foreach ($process in Get-Process) {
  $path = $null
  $started = $null
  $suspended = $false

  try {
    $path = $process.Path
  } catch {
  }

  try {
    $started = $process.StartTime.ToUniversalTime().ToString('o')
  } catch {
  }

  try {
    $threads = @($process.Threads)

    if ($threads.Count -gt 0) {
      $waiting = @(
        $threads | Where-Object {
          $_.ThreadState -eq 'Wait'
        }
      )

      $suspendedThreads = @(
        $waiting | Where-Object {
          try {
            $_.WaitReason -eq 'Suspended'
          } catch {
            $false
          }
        }
      )

      $suspended =
        $waiting.Count -eq $threads.Count -and
        $suspendedThreads.Count -eq $threads.Count
    }
  } catch {
  }

  [PSCustomObject]@{
    Name = $process.ProcessName
    Id = [int]$process.Id
    CpuSeconds = if ($null -eq $process.CPU) {
      0.0
    } else {
      [double]$process.CPU
    }
    WorkingSetBytes = [int64]$process.WorkingSet64
    Path = $path
    StartTime = $started
    Suspended = [bool]$suspended
    ThreadCount = [int]$process.Threads.Count
    HandleCount = if ($null -eq $process.HandleCount) {
      0
    } else {
      [int]$process.HandleCount
    }
  }
}

@($items) | ConvertTo-Json -Compress -Depth 3
''';

    final sampledAt = DateTime.now();

    // Capture the PID of this Flutter dashboard before the process-loop PID
    // variable is declared. This allows the dashboard to protect itself.
    final dashboardProcessId = pid;

    final result = await Process.run(
      'powershell.exe',
      const [
        '-NoLogo',
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        script,
      ],
      runInShell: false,
    ).timeout(const Duration(seconds: 15));

    if (result.exitCode != 0) {
      throw ProcessException(
        'powershell.exe',
        const [],
        result.stderr.toString().trim(),
        result.exitCode,
      );
    }

    final output = result.stdout.toString().trim();

    if (output.isEmpty) {
      _previousCpuSamples = const {};
      return const [];
    }

    final dynamic decoded = jsonDecode(output);

    final records = decoded is List<dynamic> ? decoded : <dynamic>[decoded];

    final logicalProcessors = Platform.numberOfProcessors.clamp(
      1,
      1024,
    );

    final nextSamples = <int, _PreviousCpuSample>{};
    final processes = <ProcessInfo>[];

    for (final value in records) {
      if (value is! Map<String, dynamic>) {
        continue;
      }

      final processId = (value['Id'] as num?)?.toInt() ?? -1;

      if (processId < 0) {
        continue;
      }

      final cpuSeconds = (value['CpuSeconds'] as num?)?.toDouble() ?? 0.0;

      final previousSample = _previousCpuSamples[processId];

      var cpuPercent = 0.0;

      if (previousSample != null) {
        final elapsedMicroseconds =
            sampledAt.difference(previousSample.sampledAt).inMicroseconds;

        final elapsedSeconds =
            elapsedMicroseconds / Duration.microsecondsPerSecond;

        final cpuDelta = cpuSeconds - previousSample.cpuSeconds;

        if (elapsedSeconds > 0 && cpuDelta >= 0) {
          cpuPercent = (cpuDelta / elapsedSeconds / logicalProcessors * 100)
              .clamp(0, 100)
              .toDouble();
        }
      }

      nextSamples[processId] = _PreviousCpuSample(
        cpuSeconds,
        sampledAt,
      );

      final name = value['Name']?.toString().trim() ?? 'Unknown';

      final normalizedName = name.toLowerCase().replaceAll('.exe', '').trim();

      final isCritical = processId <= 4 ||
          processId == dashboardProcessId ||
          _criticalProcessNames.contains(normalizedName);

      final startTimeText = value['StartTime']?.toString();

      final startTime = startTimeText == null || startTimeText.trim().isEmpty
          ? null
          : DateTime.tryParse(startTimeText)?.toLocal();

      processes.add(
        ProcessInfo(
          name: name,
          pid: processId,
          cpuPercent: cpuPercent,
          memoryBytes: (value['WorkingSetBytes'] as num?)?.toInt() ?? 0,
          executablePath: _nullableText(value['Path']),
          startTime: startTime,
          status: value['Suspended'] == true
              ? ProcessRuntimeStatus.suspended
              : ProcessRuntimeStatus.running,
          threadCount: (value['ThreadCount'] as num?)?.toInt() ?? 0,
          handleCount: (value['HandleCount'] as num?)?.toInt() ?? 0,
          isCritical: isCritical,
        ),
      );
    }

    _previousCpuSamples = nextSamples;

    AppLogger.info(
      'Collected ${processes.length} running processes.',
    );

    return List<ProcessInfo>.unmodifiable(processes);
  }

  static String? _nullableText(Object? value) {
    final text = value?.toString().trim();

    if (text == null || text.isEmpty) {
      return null;
    }

    return text;
  }
}

class _PreviousCpuSample {
  const _PreviousCpuSample(
    this.cpuSeconds,
    this.sampledAt,
  );

  final double cpuSeconds;
  final DateTime sampledAt;
}
