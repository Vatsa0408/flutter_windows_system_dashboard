import 'dart:io';
import 'package:logging/logging.dart';
class AppLogger {
  static IOSink? _sink;
  static final _log = Logger('Dashboard');
  static Future<void> init() async {
    Logger.root.level = Level.ALL;
    final file = File('${Directory.systemTemp.path}${Platform.pathSeparator}windows_system_dashboard.log');
    _sink = file.openWrite(mode: FileMode.append);
    Logger.root.onRecord.listen((r) { _sink?.writeln('${r.time.toIso8601String()} [${r.level.name}] ${r.message}'); if (r.error != null) _sink?.writeln(r.error); if (r.stackTrace != null) _sink?.writeln(r.stackTrace); });
    info('Application started. Log: ${file.path}');
  }
  static void info(String v) => _log.info(v);
  static void warning(String v) => _log.warning(v);
  static void error(String v, [Object? e, StackTrace? s]) => _log.severe(v, e, s);
}
