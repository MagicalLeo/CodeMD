import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'mermaid_cache_service.dart';

class MermaidRenderService {
  static final MermaidRenderService _instance = MermaidRenderService._internal();
  factory MermaidRenderService() => _instance;
  MermaidRenderService._internal();

  final MermaidCacheService _cache = MermaidCacheService();
  final Map<String, Uint8List> _pngMemoryCache = {};
  
  // Debounced render queue
  final Map<String, Completer<String>> _renderQueue = {};
  Timer? _debounceTimer;
  static const Duration _debounceDelay = Duration(milliseconds: 300);
  
  // Rate limiting
  DateTime _lastRequest = DateTime(0);
  static const Duration _minRequestInterval = Duration(milliseconds: 100);
  
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    
    await _cache.initialize();
    _initialized = true;
  }

  /// Render Mermaid diagram with caching and debouncing
  Future<String> renderDiagram(String mermaidCode, {bool isDarkTheme = false}) async {
    if (!_initialized) await initialize();
    
    if (mermaidCode.trim().isEmpty) {
      throw Exception('Empty diagram code');
    }

    // Process mermaid code to include theme configuration
    final processedCode = _addThemeConfiguration(mermaidCode, isDarkTheme);
    final cacheKey = '${mermaidCode.trim()}|theme:${isDarkTheme ? 'dark' : 'light'}';
    
    // Check cache first
    final cachedSvg = await _cache.getCachedSvg(cacheKey);
    if (cachedSvg != null) {
      return cachedSvg;
    }

    // Check if already in render queue
    final codeKey = cacheKey;
    if (_renderQueue.containsKey(codeKey)) {
      return await _renderQueue[codeKey]!.future;
    }

    // Add to render queue
    final completer = Completer<String>();
    _renderQueue[codeKey] = completer;

    // Debounce requests to avoid overwhelming the API
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDelay, () {
      _processRenderQueue();
    });

    return await completer.future;
  }

  /// Render Mermaid diagram as PNG to bypass flutter_svg CSS limitations.
  /// [scale] can be used to request higher DPI outputs from the renderer.
  Future<Uint8List> renderDiagramPng(
    String mermaidCode, {
    bool isDarkTheme = false,
    double scale = 2.0,
  }) async {
    if (!_initialized) await initialize();

    final cleanCode = mermaidCode.trim();
    if (cleanCode.isEmpty) {
      throw Exception('Empty diagram code');
    }

    final processedCode = _addThemeConfiguration(cleanCode, isDarkTheme);
    final safeScale = scale.clamp(1.0, 4.0);
    final cacheKey = 'png:${processedCode.hashCode}:${isDarkTheme ? 'dark' : 'light'}:scale:$safeScale';

    final cached = _pngMemoryCache[cacheKey];
    if (cached != null) return cached;

    try {
      // Try mermaid.ink first (often more permissive)
      final bytes = await _fetchPngFromMermaidInk(
        processedCode,
        scale: safeScale,
      );
      _pngMemoryCache[cacheKey] = bytes;
      return bytes;
    } catch (_) {
      // Fallback to Kroki
      try {
        final bytes = await _fetchPngFromKroki(
        processedCode,
        isDarkTheme: isDarkTheme,
        scale: safeScale,
      );
      _pngMemoryCache[cacheKey] = bytes;
      return bytes;
      } catch (e) {
        throw Exception('PNG render failed: $e');
      }
    }
  }

  Future<void> _processRenderQueue() async {
    if (_renderQueue.isEmpty) return;

    // Rate limiting
    final now = DateTime.now();
    final timeSinceLastRequest = now.difference(_lastRequest);
    if (timeSinceLastRequest < _minRequestInterval) {
      await Future.delayed(_minRequestInterval - timeSinceLastRequest);
    }

    // Process one request from queue
    final entry = _renderQueue.entries.first;
    final cacheKey = entry.key;
    final completer = entry.value;
    
    _renderQueue.remove(cacheKey);

    try {
      // Extract original code from cache key
      final originalCode = cacheKey.split('|theme:')[0];
      final isDarkTheme = cacheKey.contains('theme:dark');
      final processedCode = _addThemeConfiguration(originalCode, isDarkTheme);
      
      final rawSvgContent = await _fetchFromAPI(processedCode, isDarkTheme: isDarkTheme);
      
      // Post-process SVG for theme
      final svgContent = _processSvgForTheme(rawSvgContent, isDarkTheme);
      
      // Cache the result with cache key
      await _cache.cacheSvg(cacheKey, svgContent);
      
      completer.complete(svgContent);
      _lastRequest = DateTime.now();
      
      // Schedule next item if queue not empty
      if (_renderQueue.isNotEmpty) {
        Timer(_minRequestInterval, () => _processRenderQueue());
      }
    } catch (e) {
      completer.completeError(e);
      
      // Continue processing other items even if one fails
      if (_renderQueue.isNotEmpty) {
        Timer(_minRequestInterval, () => _processRenderQueue());
      }
    }
  }

  Future<String> _fetchFromAPI(String mermaidCode, {bool isDarkTheme = false}) async {
    try {
      // Method 1: Prefer Kroki with inline styles for better flutter_svg compatibility
      return await _fetchFromKroki(mermaidCode, isDarkTheme: isDarkTheme);
    } catch (e) {
      // Method 2: Fallback to mermaid.ink
      try {
        return await _fetchFromMermaidInk(mermaidCode);
      } catch (e2) {
        // Method 3: Fallback to demo SVG if all fail
        final backgroundColor = isDarkTheme ? '#121212' : 'white';
        final textColor = isDarkTheme ? '#ffffff' : '#333333';
        final errorColor = isDarkTheme ? '#ff5722' : '#d32f2f';
        
        return '''
        <svg width="400" height="200" xmlns="http://www.w3.org/2000/svg">
          <rect width="100%" height="100%" fill="$backgroundColor"/>
          <rect x="50" y="50" width="100" height="50" fill="#ffebee" stroke="$errorColor" rx="5"/>
          <text x="100" y="80" text-anchor="middle" font-family="Arial" font-size="12" fill="$errorColor">API Error</text>
          <text x="200" y="120" text-anchor="middle" font-family="Arial" font-size="14" fill="$textColor">Mermaid rendering failed</text>
          <text x="200" y="140" text-anchor="middle" font-family="Arial" font-size="12" fill="$textColor">Check network connection</text>
        </svg>
        ''';
      }
    }
  }

  Future<String> _fetchFromMermaidInk(String mermaidCode) async {
    final encodedCode = base64Encode(utf8.encode(mermaidCode));
    final url = 'https://mermaid.ink/svg/$encodedCode';
    
    final response = await http.get(
      Uri.parse(url),
      headers: {'Accept': 'image/svg+xml'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception('Mermaid.ink API error: ${response.statusCode}');
    }
  }

  Future<String> _fetchFromKroki(String mermaidCode, {bool isDarkTheme = false}) async {
    final theme = isDarkTheme ? 'dark' : 'default';
    final url = 'https://kroki.io/mermaid/svg?theme=$theme&inline-style=true';
    
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'text/plain',
        'Accept': 'image/svg+xml',
      },
      body: mermaidCode,
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception('Kroki API error: ${response.statusCode}');
    }
  }

  Future<Uint8List> _fetchPngFromKroki(
    String mermaidCode, {
    bool isDarkTheme = false,
    double scale = 2.0,
  }) async {
    final theme = isDarkTheme ? 'dark' : 'default';
    // Request higher scale for crisper PNG
    final scaleParam = scale.clamp(1.0, 4.0);
    final url =
        'https://kroki.io/mermaid/png?theme=$theme&background=transparent&scale=$scaleParam';

    final response = await http
        .post(
          Uri.parse(url),
          headers: {'Content-Type': 'text/plain'},
          body: mermaidCode,
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode == 200) {
      return response.bodyBytes;
    }

    throw Exception('Kroki PNG error: ${response.statusCode}');
  }

  Future<Uint8List> _fetchPngFromMermaidInk(String mermaidCode, {double scale = 2.0}) async {
    final encodedCode = base64Encode(utf8.encode(mermaidCode));
    final scaleParam = scale.clamp(1.0, 4.0);
    final url = 'https://mermaid.ink/img/$encodedCode?scale=$scaleParam';

    final response = await http
        .get(Uri.parse(url), headers: {'Accept': 'image/png'})
        .timeout(const Duration(seconds: 12));

    if (response.statusCode == 200) {
      return response.bodyBytes;
    }

    throw Exception('Mermaid.ink PNG error: ${response.statusCode}');
  }

  /// Preload common diagram templates
  Future<void> preloadTemplates() async {
    final templates = [
      'graph TD\n    A[Start] --> B{Is it?}\n    B -->|Yes| C[OK]\n    B -->|No| D[End]',
      'sequenceDiagram\n    Alice->>Bob: Hello\n    Bob-->>Alice: Hi',
      'classDiagram\n    class Animal {\n        +String name\n        +makeSound()\n    }',
      'gitgraph\n    commit\n    branch develop\n    checkout develop\n    commit\n    commit\n    checkout main\n    merge develop',
    ];

    for (final template in templates) {
      try {
        await renderDiagram(template);
      } catch (e) {
        // Ignore preload errors
        print('Failed to preload template: $e');
      }
    }
  }

  /// Get service statistics
  Map<String, dynamic> getStats() {
    return {
      'initialized': _initialized,
      'queue_size': _renderQueue.length,
      'last_request': _lastRequest.toIso8601String(),
      'cache_stats': _cache.getCacheStats(),
    };
  }

  /// Clear all caches
  Future<void> clearCache() async {
    await _cache.clearCache();
  }

  /// Add theme configuration to Mermaid code
  String _addThemeConfiguration(String mermaidCode, bool isDarkTheme) {
    final trimmedCode = mermaidCode.trim();

    final desiredTheme = isDarkTheme ? 'dark' : 'default';
    const initPattern = r'^%%\{init:\s*\{([\s\S]*?)\}\s*%%\s*';
    final regExp = RegExp(initPattern, multiLine: true);
    final match = regExp.firstMatch(trimmedCode);

    final fallbackInit = {
      'theme': desiredTheme,
      // Disable HTML labels to avoid <foreignObject> (flutter_svg renders them as black blocks)
      'flowchart': {'htmlLabels': false},
      'sequence': {'useMaxWidth': false},
      'class': {'useMaxWidth': false},
      'er': {'useMaxWidth': false},
      'themeVariables': isDarkTheme
          ? {
              'primaryColor': '#58a6ff',
              'secondaryColor': '#8b949e',
              'tertiaryColor': '#1f6feb',
              'lineColor': '#58a6ff',
              'textColor': '#e6edf3',
              'mainBkg': '#0d1117',
              'edgeLabelBackground': '#0d1117',
            }
          : {
              'primaryColor': '#1f6feb',
              'secondaryColor': '#57606a',
              'tertiaryColor': '#0969da',
              'lineColor': '#1f6feb',
              'textColor': '#24292f',
              'mainBkg': '#ffffff',
              'edgeLabelBackground': '#ffffff',
            },
    };

    if (match != null) {
      final initContent = match.group(1)!;
      try {
        final existing = json.decode('{${initContent}}') as Map<String, dynamic>;

        // Ensure theme exists; respect user-provided theme if present
        existing.putIfAbsent('theme', () => desiredTheme);

        // Force htmlLabels off to avoid foreignObject usage
        final flowchartConfig = (existing['flowchart'] is Map)
            ? Map<String, dynamic>.from(existing['flowchart'] as Map)
            : <String, dynamic>{};
        flowchartConfig['htmlLabels'] = false;
        existing['flowchart'] = flowchartConfig;

        // Keep other defaults if missing
        void ensureMaxWidth(String key) {
          final current = (existing[key] is Map)
              ? Map<String, dynamic>.from(existing[key] as Map)
              : <String, dynamic>{};
          current.putIfAbsent('useMaxWidth', () => false);
          existing[key] = current;
        }

        ensureMaxWidth('sequence');
        ensureMaxWidth('class');
        ensureMaxWidth('er');

        // Ensure themeVariables are present for consistent coloring
        final themeVars = (existing['themeVariables'] is Map)
            ? Map<String, dynamic>.from(existing['themeVariables'] as Map)
            : <String, dynamic>{};
        if (!themeVars.containsKey('primaryColor')) {
          themeVars.addAll(fallbackInit['themeVariables'] as Map<String, dynamic>);
        }
        existing['themeVariables'] = themeVars;

        final newInit = '%%{init: ${json.encode(existing)}}%%\n';
        final remaining = trimmedCode.substring(match.end);
        return '$newInit$remaining';
      } catch (e) {
        // If parsing fails, fall back to injecting our own init safely
        print('Failed to parse Mermaid init config, injecting fallback: $e');
      }
    }

    // No init block found; inject one with safe defaults
    final initDirective = '%%{init: ${json.encode(fallbackInit)}}%%';
    return '$initDirective\n$trimmedCode';
  }

  /// Post-process SVG for dark theme if needed (minimal processing with inline styles)
  String _processSvgForTheme(String svgContent, bool isDarkTheme) {
    // Strip unsupported foreignObject nodes that can render as black blocks in flutter_svg
    final cleaned = _stripForeignObjects(svgContent);
    return cleaned;
  }

  String _stripForeignObjects(String svgContent) {
    final regex = RegExp(
      r'<foreignObject[^>]*>([\s\S]*?)<\/foreignObject>',
      multiLine: true,
    );

    return svgContent.replaceAllMapped(regex, (match) {
      final inner = match.group(1) ?? '';
      // Remove all tags and decode a few common entities to plain text
      var textOnly = inner.replaceAll(RegExp(r'<[^>]+>'), ' ');
      textOnly = textOnly
          .replaceAll('&nbsp;', ' ')
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&quot;', '"')
          .replaceAll('&#39;', "'");
      textOnly = textOnly.replaceAll(RegExp(r'\s+'), ' ').trim();

      if (textOnly.isEmpty) return '';
      return '<text>$textOnly</text>';
    });
  }
}
