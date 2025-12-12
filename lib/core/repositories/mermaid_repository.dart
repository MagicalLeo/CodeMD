import 'dart:convert';
import '../../presentation/providers/settings_provider.dart';
import '../services/mermaid_headless_service.dart';

class MermaidRenderOutput {
  final String? svg;
  final List<int>? pngBytes;
  final String? error;
  const MermaidRenderOutput({this.svg, this.pngBytes, this.error});
}

abstract class MermaidRepository {
  Future<MermaidRenderOutput> render(String code, {required bool isDark});
}

class MermaidRepositoryImpl implements MermaidRepository {
  final MermaidHeadlessService _headless;
  final Map<String, String> _svgMemCache = {};

  MermaidRepositoryImpl({MermaidHeadlessService? headless})
      : _headless = headless ?? MermaidHeadlessService();

  @override
  Future<MermaidRenderOutput> render(String code, {required bool isDark}) async {
    try {
      DebugLogger.info('MermaidRepo', 'render() called, code length=${code.length}');
      final processed = _prepareCode(code, isDark);
      final cacheKey = _cacheKey(processed, isDark);
      final cached = _svgMemCache[cacheKey];
      if (cached != null) {
        DebugLogger.info('MermaidRepo', 'Cache hit');
        return MermaidRenderOutput(svg: cached);
      }

      DebugLogger.info('MermaidRepo', 'Calling headless.render()');
      // Request PNG first to avoid SVG black-block issues on some renderers.
      final result = await _headless.render(processed, isDark: isDark, requestPng: true);
      DebugLogger.info('MermaidRepo', 'headless.render() returned: error=${result.error}, hasPng=${result.pngBase64 != null}, hasSvg=${result.svgBase64 != null}');

      if (result.error != null) {
        DebugLogger.error('MermaidRepo', 'Render error: ${result.error}');
        return MermaidRenderOutput(error: result.error);
      }
      if (result.pngBase64 != null) {
        final pngBytes = base64Decode(result.pngBase64!);
        DebugLogger.info('MermaidRepo', 'PNG decoded, size=${pngBytes.length} bytes');
        return MermaidRenderOutput(pngBytes: pngBytes);
      }
      if (result.svgBase64 != null) {
        final decoded = utf8.decode(base64Decode(result.svgBase64!));
        final sanitized = _sanitizeSvg(decoded);
        _svgMemCache[cacheKey] = sanitized;
        DebugLogger.info('MermaidRepo', 'SVG decoded, length=${sanitized.length}');
        return MermaidRenderOutput(svg: sanitized);
      }
      DebugLogger.warning('MermaidRepo', 'No result returned');
      return const MermaidRenderOutput(error: 'Unknown render result');
    } catch (e, st) {
      DebugLogger.error('MermaidRepo', 'Exception in render()', '$e\n$st');
      return MermaidRenderOutput(error: 'Exception: $e');
    }
  }

  String _cacheKey(String processedCode, bool isDark) =>
      '${processedCode.hashCode}:${isDark ? 'd' : 'l'}';

  String _prepareCode(String raw, bool isDark) {
    var cleanCode = raw
        .replaceAll('&gt;', '>')
        .replaceAll('&lt;', '<')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();

    // Remove Obsidian embed syntax like ![[filename]] that may appear before the diagram
    cleanCode = cleanCode.replaceAll(RegExp(r'^!\[\[[^\]]*\]\]\s*', multiLine: true), '');

    final desiredTheme = isDark ? 'dark' : 'default';
    const initPattern = r'^%%\{init:\s*\{([\s\S]*?)\}\s*%%\s*';
    final regExp = RegExp(initPattern, multiLine: true);
    final match = regExp.firstMatch(cleanCode);

    final fallbackInit = {
      'theme': desiredTheme,
      'flowchart': {'htmlLabels': false, 'useMaxWidth': false},
      'sequence': {'useMaxWidth': false, 'mirrorActors': false, 'htmlLabels': false},
      'class': {'useMaxWidth': false, 'htmlLabels': false},
      'er': {'useMaxWidth': false, 'htmlLabels': false},
      'journey': {'useHtmlLabels': false},
      'pie': {'useHtmlLabels': false},
      'themeVariables': isDark
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
        existing['theme'] = existing['theme'] ?? desiredTheme;
        void enforce(String key) {
          final current = (existing[key] is Map)
              ? Map<String, dynamic>.from(existing[key] as Map)
              : <String, dynamic>{};
          current['useMaxWidth'] = false;
          current['htmlLabels'] = false;
          existing[key] = current;
        }

        enforce('flowchart');
        enforce('sequence');
        enforce('class');
        enforce('er');

        final journey = (existing['journey'] is Map)
            ? Map<String, dynamic>.from(existing['journey'] as Map)
            : <String, dynamic>{};
        journey['useHtmlLabels'] = false;
        existing['journey'] = journey;

        final pie = (existing['pie'] is Map)
            ? Map<String, dynamic>.from(existing['pie'] as Map)
            : <String, dynamic>{};
        pie['useHtmlLabels'] = false;
        existing['pie'] = pie;

        final themeVars = (existing['themeVariables'] is Map)
            ? Map<String, dynamic>.from(existing['themeVariables'] as Map)
            : <String, dynamic>{};
        if (!themeVars.containsKey('primaryColor')) {
          themeVars.addAll(fallbackInit['themeVariables'] as Map<String, dynamic>);
        }
        existing['themeVariables'] = themeVars;

        final newInit = '%%{init: ${json.encode(existing)}}%%\n';
        final remaining = cleanCode.substring(match.end);
        return '$newInit$remaining';
      } catch (_) {
        // fall back
      }
    }

    final initDirective = '%%{init: ${json.encode(fallbackInit)}}%%';
    return '$initDirective\n$cleanCode';
  }

  String _sanitizeSvg(String svgContent) {
    var cleaned = svgContent.replaceAll(RegExp(
      r'<foreignObject[^>]*>[\s\S]*?<\/foreignObject>',
      multiLine: true,
    ), '');
    cleaned = cleaned.replaceAll(RegExp(
      r'<style[^>]*>[\s\S]*?<\/style>',
      multiLine: true,
    ), '');
    cleaned = cleaned.replaceAll(RegExp(
      r'<marker[^>]*>[\s\S]*?<\/marker>',
      multiLine: true,
    ), '');

    final svgTag = RegExp(r'(<svg\b[^>]*)(>)', multiLine: true);
    cleaned = cleaned.replaceFirstMapped(svgTag, (m) {
      final tag = m.group(1)!;
      final end = m.group(2)!;
      if (tag.contains('style="')) {
        return '${tag.replaceFirst('style="', 'style="background:transparent; ')}$end';
      }
      return '$tag style="background:transparent;"$end';
    });
    return cleaned;
  }
}
