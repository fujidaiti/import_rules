import 'dart:async';
import 'dart:io';

import 'package:analyzer/workspace/workspace.dart';
import 'package:logging/logging.dart' as logging;

class Logger {
  static Logger? of(WorkspacePackage package) {
    // Temporary disable logging
    return null;
    /*
    final key = package.root.path;
    if (_loggers[key] case final logger?) {
      return logger;
    } else {
      final logger = Logger()..setUp(package);
      _loggers[key] = logger;
      return logger;
    }
    */
  }

  static Future<void> closeAll() async {
    await Future.wait(_loggers.values.map((logger) => logger.tearDown()));
    _loggers.clear();
  }

  static final Map<String, Logger> _loggers = {};

  late final StreamSubscription<logging.LogRecord> _onRecordSubscription;
  late final IOSink _logFileStreamSink;
  late final logging.Logger _internalLogger;

  File setUp(WorkspacePackage package) {
    final timestamp = DateTime.now().toIso8601String();
    logging.Logger.root.level;
    final logFile = File(
      '${package.root.path}/.dart_tool/import_rules/instrumentation_$timestamp.log',
    );
    if (!logFile.existsSync()) {
      logFile.createSync(recursive: true);
    }
    _logFileStreamSink = logFile.openWrite();
    _onRecordSubscription = logging.Logger.root.onRecord.listen(_writeRecord);
    _internalLogger = logging.Logger(package.root.shortName);
    return logFile;
  }

  Future<void> tearDown() async {
    _onRecordSubscription.cancel();
    await _logFileStreamSink.flush();
    await _logFileStreamSink.close();
  }

  void _writeRecord(logging.LogRecord record) {
    _logFileStreamSink.write(
      '${record.time.toIso8601String()} '
      '[${record.loggerName}:${record.level.name}] '
      '${record.message}${Platform.lineTerminator}',
    );

    if (record.error case final error?) {
      _logFileStreamSink.write(
        '${Platform.lineTerminator}$error${Platform.lineTerminator}',
      );
    }

    if (record.stackTrace case final stackTrace?) {
      _logFileStreamSink.write(
        '${Platform.lineTerminator}$stackTrace${Platform.lineTerminator}',
      );
    }
  }

  void info(String message) {
    _internalLogger.info(message);
  }

  void warning(String message) {
    _internalLogger.warning(message);
  }

  void severe(String message, [Object? error, StackTrace? stackTrace]) {
    _internalLogger.severe(message, error, stackTrace);
  }
}
