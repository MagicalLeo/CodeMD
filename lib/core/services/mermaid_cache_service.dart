import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

class MermaidCacheService {
  static final MermaidCacheService _instance = MermaidCacheService._internal();
  factory MermaidCacheService() => _instance;
  MermaidCacheService._internal();

  // Memory cache for recent diagrams (LRU-like)
  final Map<String, String> _memoryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const int _maxMemoryCacheSize = 20;
  static const Duration _cacheExpiry = Duration(days: 7);

  Directory? _cacheDirectory;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDirectory = Directory('${appDir.path}/mermaid_cache');
      
      if (!await _cacheDirectory!.exists()) {
        await _cacheDirectory!.create(recursive: true);
      }
      
      _initialized = true;
      
      // Clean old cache files
      await _cleanExpiredCache();
    } catch (e) {
      print('Failed to initialize Mermaid cache: $e');
    }
  }

  String _generateKey(String mermaidCode) {
    // Generate MD5 hash for consistent key
    final bytes = utf8.encode(mermaidCode.trim());
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  Future<String?> getCachedSvg(String mermaidCode) async {
    if (!_initialized) await initialize();
    
    final key = _generateKey(mermaidCode);
    
    // Check memory cache first
    if (_memoryCache.containsKey(key)) {
      final timestamp = _cacheTimestamps[key];
      if (timestamp != null && 
          DateTime.now().difference(timestamp) < _cacheExpiry) {
        return _memoryCache[key];
      } else {
        // Remove expired entry
        _memoryCache.remove(key);
        _cacheTimestamps.remove(key);
      }
    }

    // Check disk cache
    if (_cacheDirectory != null) {
      final file = File('${_cacheDirectory!.path}/$key.svg');
      if (await file.exists()) {
        try {
          final stat = await file.stat();
          if (DateTime.now().difference(stat.modified) < _cacheExpiry) {
            final svgContent = await file.readAsString();
            
            // Add to memory cache
            _addToMemoryCache(key, svgContent);
            
            return svgContent;
          } else {
            // Delete expired file
            await file.delete();
          }
        } catch (e) {
          print('Error reading cache file: $e');
        }
      }
    }

    return null;
  }

  Future<void> cacheSvg(String mermaidCode, String svgContent) async {
    if (!_initialized) await initialize();
    
    final key = _generateKey(mermaidCode);
    
    // Add to memory cache
    _addToMemoryCache(key, svgContent);
    
    // Save to disk cache
    if (_cacheDirectory != null) {
      try {
        final file = File('${_cacheDirectory!.path}/$key.svg');
        await file.writeAsString(svgContent);
      } catch (e) {
        print('Error writing cache file: $e');
      }
    }
  }

  void _addToMemoryCache(String key, String content) {
    // Implement simple LRU eviction
    if (_memoryCache.length >= _maxMemoryCacheSize) {
      // Remove oldest entry
      String? oldestKey;
      DateTime? oldestTime;
      
      for (final entry in _cacheTimestamps.entries) {
        if (oldestTime == null || entry.value.isBefore(oldestTime)) {
          oldestTime = entry.value;
          oldestKey = entry.key;
        }
      }
      
      if (oldestKey != null) {
        _memoryCache.remove(oldestKey);
        _cacheTimestamps.remove(oldestKey);
      }
    }
    
    _memoryCache[key] = content;
    _cacheTimestamps[key] = DateTime.now();
  }

  Future<void> _cleanExpiredCache() async {
    if (_cacheDirectory == null || !await _cacheDirectory!.exists()) return;
    
    try {
      final files = _cacheDirectory!.listSync();
      final now = DateTime.now();
      
      for (final file in files) {
        if (file is File && file.path.endsWith('.svg')) {
          final stat = await file.stat();
          if (now.difference(stat.modified) > _cacheExpiry) {
            await file.delete();
          }
        }
      }
    } catch (e) {
      print('Error cleaning cache: $e');
    }
  }

  Future<void> clearCache() async {
    _memoryCache.clear();
    _cacheTimestamps.clear();
    
    if (_cacheDirectory != null && await _cacheDirectory!.exists()) {
      try {
        await _cacheDirectory!.delete(recursive: true);
        await _cacheDirectory!.create(recursive: true);
      } catch (e) {
        print('Error clearing cache: $e');
      }
    }
  }

  // Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'memoryCache_size': _memoryCache.length,
      'memoryCache_maxSize': _maxMemoryCacheSize,
      'cache_directory': _cacheDirectory?.path,
      'initialized': _initialized,
    };
  }
}