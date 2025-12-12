import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../core/repositories/mermaid_repository.dart';
import '../providers/settings_provider.dart';

class MermaidSvgRenderer extends ConsumerStatefulWidget {
  final String mermaidCode;
  final double? width;
  final double? height;

  const MermaidSvgRenderer({
    super.key,
    required this.mermaidCode,
    this.width,
    this.height,
  });

  @override
  ConsumerState<MermaidSvgRenderer> createState() => _MermaidSvgRendererState();
}

class _MermaidSvgRendererState extends ConsumerState<MermaidSvgRenderer> {
  String? _svgData;
  Uint8List? _pngData;
  bool _isLoading = true;
  String? _error;

  final MermaidRepository _repository = MermaidRepositoryImpl();
  bool _didInitDependencies = false;
  bool _isVisible = false;
  bool _requestedRender = false;
  Timer? _debounceTimer;
  DateTime? _renderStart;

  @override
  void dispose() {
    DebugLogger.verbose('Mermaid', 'dispose() called, hasSvg=${_svgData != null}, hasPng=${_pngData != null}');
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _showFullScreenViewer(BuildContext context, {Uint8List? pngData, String? svgData}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullScreenMermaidViewer(
          pngData: pngData,
          svgData: svgData,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _isVisible = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _generateWhenVisible();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInitDependencies) {
      _didInitDependencies = true;
      // Wait for inherited widgets (Theme/MediaQuery) to be ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _generateWhenVisible();
      });
    }
  }

  @override
  void didUpdateWidget(MermaidSvgRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mermaidCode != widget.mermaidCode) {
      _requestedRender = false;
      _generateWhenVisible();
    }
  }

  void _generateWhenVisible() {
    if (!_isVisible) return;
    // If we already have data, don't re-render
    if (_svgData != null || _pngData != null) {
      DebugLogger.verbose('Mermaid', '_generateWhenVisible: already have data, skipping');
      return;
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 140), () {
      if (mounted && !_requestedRender) {
        _requestedRender = true;
        _renderStart = DateTime.now();
        // Defer the heavy render until after the current frame to avoid
        // blocking first paint when the page first opens.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _generateDiagram();
          }
        });
      }
    });
  }

  Future<void> _generateDiagram() async {
    // Don't re-render if we already have data
    if (_svgData != null || _pngData != null) {
      DebugLogger.verbose('Mermaid', '_generateDiagram: already have data, skipping');
      return;
    }

    final cleanCode = widget.mermaidCode.trim();
    DebugLogger.verbose('Mermaid', 'Starting render, code length: ${cleanCode.length}');

    if (cleanCode.isEmpty) {
      setState(() {
        _error = 'Empty diagram code';
        _isLoading = false;
      });
      DebugLogger.warning('Mermaid', 'Empty diagram code');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      // Don't clear existing data - only set when we get new results
    });

    try {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      DebugLogger.info('Mermaid', 'Rendering with isDark=$isDark');
      final result = await _repository.render(cleanCode, isDark: isDark);
      if (!mounted) return;

      if (result.error != null) {
        setState(() {
          _error = result.error;
          _isLoading = false;
        });
        final ms = _renderStart != null
            ? DateTime.now().difference(_renderStart!).inMilliseconds
            : 0;
        DebugLogger.error('Mermaid', 'Render failed after ${ms}ms: ${result.error}');
        return;
      }

      if (result.pngBytes != null) {
        final pngSize = result.pngBytes!.length;
        setState(() {
          _pngData = Uint8List.fromList(result.pngBytes!);
          _isLoading = false;
          _error = null;
        });
        final ms = _renderStart != null
            ? DateTime.now().difference(_renderStart!).inMilliseconds
            : 0;
        DebugLogger.info('Mermaid', 'Render success (png) in ${ms}ms, size: ${(pngSize / 1024).toStringAsFixed(1)}KB');
      } else if (result.svg != null) {
        final svgLen = result.svg!.length;
        DebugLogger.info('Mermaid', 'SVG received, length=$svgLen');
        setState(() {
          _svgData = result.svg;
          _isLoading = false;
          _error = null;
        });
        final ms = _renderStart != null
            ? DateTime.now().difference(_renderStart!).inMilliseconds
            : 0;
        DebugLogger.info('Mermaid', 'Render success (svg) in ${ms}ms, length=$svgLen');
      } else {
        setState(() {
          _error = 'Unknown render result';
          _isLoading = false;
        });
        DebugLogger.warning('Mermaid', 'Unknown render result - no png or svg');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Render failed: $e';
        _isLoading = false;
      });
      final ms = _renderStart != null
          ? DateTime.now().difference(_renderStart!).inMilliseconds
          : 0;
      DebugLogger.error('Mermaid', 'Render exception after ${ms}ms', e);
    }
  }

  String _buildFallbackSvg(String code, String error) {
    final escapedCode = code
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
    final escapedError = error
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    return '''
<svg width="800" height="220" xmlns="http://www.w3.org/2000/svg">
  <rect width="100%" height="100%" fill="#111827" rx="12"/>
  <text x="20" y="30" fill="#f87171" font-size="14" font-family="monospace">Mermaid rendering unavailable</text>
  <text x="20" y="50" fill="#9ca3af" font-size="12" font-family="monospace">Error: $escapedError</text>
  <text x="20" y="68" fill="#9ca3af" font-size="12" font-family="monospace">Rendered locally (no network).</text>
  <rect x="20" y="80" width="760" height="120" fill="#0b1120" stroke="#1f2937" rx="8"/>
  <text x="28" y="104" fill="#d1d5db" font-family="monospace" font-size="12">
$escapedCode
  </text>
</svg>
''';
  }

  Widget _buildLoading() {
    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? 400,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 8),
            Text('Generating diagram...'),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(String code) {
    // Always show error details
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
              ),
            ),
            child: const Text(
              'Mermaid Error',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.red,
              ),
            ),
          ),
          if (_error != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              width: double.infinity,
              color: Colors.red[50]?.withOpacity(0.5),
              child: SelectableText(
                _error!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red[700],
                  fontFamily: 'Courier New',
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(12),
            width: double.infinity,
            child: SelectableText(
              code.length > 800 ? '${code.substring(0, 800)}...' : code,
              style: const TextStyle(
                fontFamily: 'Courier New',
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }


  String _sanitizeSvg(String svgContent) {
    // Remove foreignObject blocks that flutter_svg renders as black boxes.
    var cleaned = svgContent.replaceAll(RegExp(
      r'<foreignObject[^>]*>[\s\S]*?<\/foreignObject>',
      multiLine: true,
    ), '');
    // Remove <style> blocks that may embed @font-face / unsupported CSS.
    cleaned = cleaned.replaceAll(RegExp(
      r'<style[^>]*>[\s\S]*?<\/style>',
      multiLine: true,
    ), '');
    // Remove marker/defs that occasionally break rendering.
    cleaned = cleaned.replaceAll(RegExp(
      r'<marker[^>]*>[\s\S]*?<\/marker>',
      multiLine: true,
    ), '');

    // Ensure background is transparent instead of forced white/black.
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

  @override
  Widget build(BuildContext context) {
    DebugLogger.verbose('Mermaid', 'build() called: isLoading=$_isLoading, hasError=${_error != null}, hasPng=${_pngData != null}, hasSvg=${_svgData != null}, requestedRender=$_requestedRender, isVisible=$_isVisible');

    final content = Builder(builder: (context) {
      if (_isLoading) {
        DebugLogger.verbose('Mermaid', 'Returning loading widget');
        return _buildLoading();
      }

      if (_error != null) {
        DebugLogger.verbose('Mermaid', 'Returning error widget');
        return _buildErrorCard(widget.mermaidCode);
      }

      if (_pngData != null) {
        DebugLogger.verbose('Mermaid', 'Returning PNG widget');
        final isDebug = DebugLogger.isDebugMode;
        final pngSizeKb = (_pngData!.length / 1024).toStringAsFixed(1);
        return Container(
          constraints: const BoxConstraints(minHeight: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                // Show full image scaled to fit width
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Image.memory(
                    _pngData!,
                    fit: BoxFit.fitWidth,
                    width: double.infinity,
                  ),
                ),
                // Debug info overlay
                if (isDebug)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'PNG ${pngSizeKb}KB',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Material(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(20),
                    elevation: 4,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _showFullScreenViewer(context, pngData: _pngData),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.fullscreen, color: Colors.white, size: 24),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      if (_svgData != null) {
        final isDebug = DebugLogger.isDebugMode;
        final svgSizeKb = (_svgData!.length / 1024).toStringAsFixed(1);
        DebugLogger.info('Mermaid', 'SVG received, size=${svgSizeKb}KB - showing placeholder with fullscreen');

        // All SVG rendering moved to fullscreen WebView to avoid crashes
        // Show a simple placeholder card with fullscreen button
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Container(
          constraints: const BoxConstraints(minHeight: 120),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2d2d2d) : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
          ),
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.schema_outlined,
                        size: 40,
                        color: isDark ? Colors.blue[300] : Colors.blue[700],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Mermaid Diagram',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                      if (isDebug)
                        Text(
                          '${svgSizeKb}KB',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey[500] : Colors.grey[500],
                          ),
                        ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => _showFullScreenViewer(context, svgData: _svgData),
                        icon: const Icon(Icons.fullscreen, size: 18),
                        label: const Text('View Diagram'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }

      return Container(
        width: widget.width ?? double.infinity,
        height: widget.height ?? 320,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Center(
          child: Text('No diagram to display'),
        ),
      );
    });

    return VisibilityDetector(
      key: ValueKey('mermaid-${widget.mermaidCode.hashCode}-${widget.key ?? ''}'),
      onVisibilityChanged: (info) {
        final visible = info.visibleFraction > 0.05;
        final wasVisible = _isVisible;
        _isVisible = visible;
        DebugLogger.verbose('Mermaid', 'Visibility changed: visible=$visible, wasVisible=$wasVisible, hasSvg=${_svgData != null}, hasPng=${_pngData != null}');
        if (visible && !wasVisible) {
          _generateWhenVisible();
        }
      },
      child: content,
    );
  }
}

class _FullScreenMermaidViewer extends StatelessWidget {
  final Uint8List? pngData;
  final String? svgData;

  const _FullScreenMermaidViewer({
    this.pngData,
    this.svgData,
  });

  /// Clean SVG to remove foreignObject elements that render as black boxes
  String _cleanSvgForDisplay(String svg, bool isDark) {
    var cleaned = svg;

    // Remove foreignObject elements (they render as black boxes)
    cleaned = cleaned.replaceAll(RegExp(
      r'<foreignObject[^>]*>[\s\S]*?</foreignObject>',
      multiLine: true,
    ), '');

    // Remove style blocks that may cause issues
    cleaned = cleaned.replaceAll(RegExp(
      r'<style[^>]*>[\s\S]*?</style>',
      multiLine: true,
    ), '');

    // Replace black fills with appropriate colors
    final replacementColor = isDark ? '#374151' : '#e5e7eb';
    cleaned = cleaned.replaceAll('fill="black"', 'fill="$replacementColor"');
    cleaned = cleaned.replaceAll('fill="#000"', 'fill="$replacementColor"');
    cleaned = cleaned.replaceAll('fill="#000000"', 'fill="$replacementColor"');
    cleaned = cleaned.replaceAll('fill:black', 'fill:$replacementColor');
    cleaned = cleaned.replaceAll('fill:#000', 'fill:$replacementColor');
    cleaned = cleaned.replaceAll('fill:#000000', 'fill:$replacementColor');
    cleaned = cleaned.replaceAll('fill: black', 'fill: $replacementColor');
    cleaned = cleaned.replaceAll('fill: #000', 'fill: $replacementColor');
    cleaned = cleaned.replaceAll('fill: #000000', 'fill: $replacementColor');
    // Also handle rgb(0,0,0)
    cleaned = cleaned.replaceAll(RegExp(r'fill:\s*rgb\(0,\s*0,\s*0\)'), 'fill:$replacementColor');
    cleaned = cleaned.replaceAll(RegExp(r'fill="rgb\(0,\s*0,\s*0\)"'), 'fill="$replacementColor"');

    // Fix text elements that might have been inside foreignObject
    // Replace any remaining HTML-like content in text elements
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'<text([^>]*)>([\s\S]*?)</text>', multiLine: true),
      (match) {
        final attrs = match.group(1) ?? '';
        var content = match.group(2) ?? '';
        // Remove any nested HTML tags from text content
        content = content.replaceAll(RegExp(r'<[^>]+>'), '');
        return '<text$attrs>$content</text>';
      },
    );

    // Add appropriate background based on theme
    final bgColor = isDark ? '#1a1a2e' : '#ffffff';
    final svgTag = RegExp(r'(<svg\b[^>]*)(>)', multiLine: true);
    cleaned = cleaned.replaceFirstMapped(svgTag, (m) {
      final tag = m.group(1)!;
      final end = m.group(2)!;
      if (tag.contains('style="')) {
        return '${tag.replaceFirst('style="', 'style="background:$bgColor; ')}$end';
      }
      return '$tag style="background:$bgColor;"$end';
    });

    return cleaned;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // For PNG, use Image widget with InteractiveViewer
    if (pngData != null) {
      return Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Diagram',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
        ),
        body: InteractiveViewer(
          panEnabled: true,
          scaleEnabled: true,
          minScale: 0.5,
          maxScale: 20.0,
          boundaryMargin: const EdgeInsets.all(200),
          child: Center(
            child: Image.memory(pngData!, fit: BoxFit.contain),
          ),
        ),
      );
    }

    // For SVG, use WebView to avoid flutter_svg crashes on large SVGs
    if (svgData != null) {
      final cleanedSvg = _cleanSvgForDisplay(svgData!, isDark);
      final bgColor = isDark ? '#1a1a2e' : '#ffffff';
      final textColor = isDark ? '#e6edf3' : '#24292f';
      final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=10.0, user-scalable=yes">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body {
      width: 100%;
      height: 100%;
      background: $bgColor;
      overflow: auto;
      -webkit-overflow-scrolling: touch;
    }
    .container {
      min-width: 100%;
      min-height: 100%;
      display: flex;
      justify-content: center;
      align-items: flex-start;
      padding: 16px;
    }
    svg {
      max-width: none !important;
      height: auto !important;
    }
    /* Fix text visibility */
    svg text, svg tspan {
      fill: $textColor !important;
    }
    /* Hide any remaining foreignObject */
    foreignObject {
      display: none !important;
    }
    /* Fix black rectangles - make them transparent or use proper colors */
    svg rect[fill="black"], svg rect[fill="#000"], svg rect[fill="#000000"] {
      fill: ${isDark ? '#374151' : '#e5e7eb'} !important;
    }
    svg path[fill="black"], svg path[fill="#000"], svg path[fill="#000000"] {
      fill: ${isDark ? '#374151' : '#e5e7eb'} !important;
    }
    /* Fix blocks with inline style black fill */
    svg [style*="fill: black"], svg [style*="fill:black"],
    svg [style*="fill: rgb(0, 0, 0)"], svg [style*="fill:#000"] {
      fill: ${isDark ? '#374151' : '#e5e7eb'} !important;
    }
  </style>
</head>
<body>
  <div class="container">
    $cleanedSvg
  </div>
</body>
</html>
''';
      return Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Diagram',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
        ),
        body: InAppWebView(
          initialData: InAppWebViewInitialData(
            data: html,
            mimeType: 'text/html',
            encoding: 'utf-8',
          ),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: false,
            transparentBackground: true,
            supportZoom: true,
            builtInZoomControls: true,
            displayZoomControls: false,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Diagram',
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
      ),
      body: const Center(child: Text('No diagram')),
    );
  }
}
