import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LogLevel { none, error, warning, info, verbose }

enum AppThemeMode { system, light, dark }

class SettingsState {
  final bool debugMode;
  final LogLevel logLevel;
  final AppThemeMode themeMode;

  const SettingsState({
    this.debugMode = false,
    this.logLevel = LogLevel.error,
    this.themeMode = AppThemeMode.system,
  });

  SettingsState copyWith({
    bool? debugMode,
    LogLevel? logLevel,
    AppThemeMode? themeMode,
  }) {
    return SettingsState(
      debugMode: debugMode ?? this.debugMode,
      logLevel: logLevel ?? this.logLevel,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState()) {
    _loadSettings();
  }

  static const _debugModeKey = 'debug_mode';
  static const _logLevelKey = 'log_level';
  static const _themeModeKey = 'theme_mode';

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final logLevelIndex = prefs.getInt(_logLevelKey) ?? LogLevel.error.index;
    final themeModeIndex = prefs.getInt(_themeModeKey) ?? AppThemeMode.system.index;
    state = state.copyWith(
      debugMode: prefs.getBool(_debugModeKey) ?? false,
      logLevel: LogLevel.values[logLevelIndex.clamp(0, LogLevel.values.length - 1)],
      themeMode: AppThemeMode.values[themeModeIndex.clamp(0, AppThemeMode.values.length - 1)],
    );
  }

  Future<void> setDebugMode(bool value) async {
    state = state.copyWith(debugMode: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_debugModeKey, value);
  }

  Future<void> setLogLevel(LogLevel level) async {
    state = state.copyWith(logLevel: level);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_logLevelKey, level.index);
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeModeKey, mode.index);
  }
}

class LogEntry {
  final DateTime time;
  final LogLevel level;
  final String tag;
  final String message;

  LogEntry(this.time, this.level, this.tag, this.message);

  String get formatted {
    final t = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
    final lvl = level.name.toUpperCase().substring(0, 1);
    return '[$t][$lvl][$tag] $message';
  }
}

/// Global debug logger that respects settings
class DebugLogger {
  static LogLevel _currentLevel = LogLevel.error;
  static bool _debugMode = false;
  static final List<LogEntry> _logs = [];
  static const int _maxLogs = 500;

  static void updateSettings(SettingsState settings) {
    _currentLevel = settings.logLevel;
    _debugMode = settings.debugMode;
  }

  static List<LogEntry> get logs => List.unmodifiable(_logs);

  static void clearLogs() => _logs.clear();

  static void _addLog(LogLevel level, String tag, String message) {
    final entry = LogEntry(DateTime.now(), level, tag, message);
    _logs.add(entry);
    if (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }
    debugPrint(entry.formatted);
  }

  static void error(String tag, String message, [Object? error]) {
    final msg = error != null ? '$message -> $error' : message;
    _addLog(LogLevel.error, tag, msg);
  }

  static void warning(String tag, String message) {
    if (_currentLevel.index >= LogLevel.warning.index) {
      _addLog(LogLevel.warning, tag, message);
    }
  }

  static void info(String tag, String message) {
    if (_currentLevel.index >= LogLevel.info.index) {
      _addLog(LogLevel.info, tag, message);
    }
  }

  static void verbose(String tag, String message) {
    if (_currentLevel.index >= LogLevel.verbose.index) {
      _addLog(LogLevel.verbose, tag, message);
    }
  }

  static bool get isDebugMode => _debugMode;
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) => SettingsNotifier(),
);
