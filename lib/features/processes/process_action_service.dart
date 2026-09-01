import 'dart:io';

import '../../core/app_logger.dart';
import 'process_info.dart';

abstract interface class ProcessActionService {
  Future<void> openFileLocation(ProcessInfo process);
  Future<void> terminate(ProcessInfo process);
  Future<void> restart(ProcessInfo process);
}

class WindowsProcessActionService implements ProcessActionService {
  @override
  Future<void> openFileLocation(ProcessInfo process) async {
    final path = process.executablePath;
    if (path == null) {
      throw StateError('The executable path is unavailable.');
    }
    final result = await Process.run(
      'explorer.exe',
      ['/select,$path'],
      runInShell: false,
    );
    if (result.exitCode != 0) {
      throw ProcessException('explorer.exe', ['/select,$path']);
    }
  }

  @override
  Future<void> terminate(ProcessInfo process) async {
    _ensureActionAllowed(process);
    AppLogger.warning('Termination requested for ${process.name} (${process.pid}).');
    final result = await Process.run(
      'taskkill.exe',
      ['/PID', '${process.pid}', '/T', '/F'],
      runInShell: false,
    ).timeout(const Duration(seconds: 10));
    if (result.exitCode != 0) {
      throw ProcessException(
        'taskkill.exe',
        ['/PID', '${process.pid}', '/T', '/F'],
        result.stderr.toString().trim(),
        result.exitCode,
      );
    }
  }

  @override
  Future<void> restart(ProcessInfo process) async {
    _ensureActionAllowed(process);
    final path = process.executablePath;
    if (path == null || !File(path).existsSync()) {
      throw StateError('A valid executable path is required to restart this process.');
    }
    await terminate(process);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    await Process.start(
      path,
      const [],
      workingDirectory: File(path).parent.path,
      mode: ProcessStartMode.detached,
      runInShell: false,
    );
    AppLogger.info('Restarted ${process.name} from $path.');
  }

  void _ensureActionAllowed(ProcessInfo process) {
    if (!Platform.isWindows) {
      throw UnsupportedError('Process actions are available on Windows only.');
    }
    if (process.isCritical) {
      throw StateError('Actions are blocked for protected processes.');
    }
  }
}
