import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  final bool debugMode;

  const SettingsState({
    this.debugMode = false,
  });

  SettingsState copyWith({bool? debugMode}) {
    return SettingsState(
      debugMode: debugMode ?? this.debugMode,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState()) {
    _loadSettings();
  }

  static const _debugModeKey = 'debug_mode';

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      debugMode: prefs.getBool(_debugModeKey) ?? false,
    );
  }

  Future<void> setDebugMode(bool value) async {
    state = state.copyWith(debugMode: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_debugModeKey, value);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) => SettingsNotifier(),
);
