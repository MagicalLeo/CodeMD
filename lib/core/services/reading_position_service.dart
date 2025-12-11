import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ReadingPositionService {
  static const String _keyPrefix = 'reading_position_';
  static const int _maxStoredPositions = 100;

  /// Save reading position by block index
  static Future<void> savePosition(String filePath, int blockIndex, double alignment) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyPrefix + _hashFilePath(filePath);

    final data = {
      'blockIndex': blockIndex,
      'alignment': alignment,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'filePath': filePath,
    };

    await prefs.setString(key, jsonEncode(data));
    await _cleanupOldEntries(prefs);
  }

  /// Get reading position as (blockIndex, alignment)
  static Future<(int, double)?> getPosition(String filePath) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyPrefix + _hashFilePath(filePath);

    final dataStr = prefs.getString(key);
    if (dataStr == null) return null;

    try {
      final data = jsonDecode(dataStr) as Map<String, dynamic>;
      final blockIndex = data['blockIndex'] as int? ?? 0;
      final alignment = (data['alignment'] as num?)?.toDouble() ?? 0.0;
      return (blockIndex, alignment);
    } catch (e) {
      return null;
    }
  }

  static Future<void> removePosition(String filePath) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyPrefix + _hashFilePath(filePath);
    await prefs.remove(key);
  }

  static String _hashFilePath(String filePath) {
    return filePath.hashCode.toRadixString(16);
  }

  static Future<void> _cleanupOldEntries(SharedPreferences prefs) async {
    final allKeys = prefs.getKeys().where((k) => k.startsWith(_keyPrefix)).toList();

    if (allKeys.length <= _maxStoredPositions) return;

    final entries = <MapEntry<String, int>>[];
    for (final key in allKeys) {
      final dataStr = prefs.getString(key);
      if (dataStr != null) {
        try {
          final data = jsonDecode(dataStr) as Map<String, dynamic>;
          final timestamp = data['timestamp'] as int? ?? 0;
          entries.add(MapEntry(key, timestamp));
        } catch (e) {
          await prefs.remove(key);
        }
      }
    }

    entries.sort((a, b) => a.value.compareTo(b.value));

    final toRemove = entries.length - _maxStoredPositions;
    for (int i = 0; i < toRemove; i++) {
      await prefs.remove(entries[i].key);
    }
  }
}
