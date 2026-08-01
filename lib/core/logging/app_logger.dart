import 'package:flutter/foundation.dart';

/// Leveled logger. Debug/info never print in release.
class AppLogger {
  AppLogger._();

  static void debug(String message, [Object? error, StackTrace? stackTrace]) {
    if (!kDebugMode) return;
    debugPrint(_format('DEBUG', message, error));
    if (stackTrace != null) debugPrint('$stackTrace');
  }

  static void info(String message, [Object? error, StackTrace? stackTrace]) {
    if (!kDebugMode) return;
    debugPrint(_format('INFO', message, error));
    if (stackTrace != null) debugPrint('$stackTrace');
  }

  static void warning(String message, [Object? error, StackTrace? stackTrace]) {
    debugPrint(_format('WARN', message, error));
    if (stackTrace != null && kDebugMode) debugPrint('$stackTrace');
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    debugPrint(_format('ERROR', message, error));
    if (stackTrace != null) debugPrint('$stackTrace');
  }

  static String _format(String level, String message, Object? error) {
    if (error == null) return '[$level] $message';
    return '[$level] $message — $error';
  }
}
