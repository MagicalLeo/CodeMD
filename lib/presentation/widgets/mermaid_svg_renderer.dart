import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:visibility_detector/visibility_detector.dart';
import '../../core/repositories/mermaid_repository.dart';

class MermaidSvgRenderer extends StatefulWidget {
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
  State<MermaidSvgRenderer> createState() => _MermaidSvgRendererState();
}

class _MermaidSvgRendererState extends State<MermaidSvgRenderer> {
  static final Map<String, String> _svgMemoryCache = {};
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

  ScrollHoldController? _scrollHold;
  int _pointerCount = 0;

  void _onScaleStart(ScaleStartDetails details) {
    // Lock scroll more aggressively for better zoom UX
    if (details.pointerCount > 1) {
      _scrollHold ??= Scrollable.of(context)?.position.hold(() {});
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    // More sensitive detection: smaller scale threshold and faster lock
    if (details.pointerCount > 1 || (details.scale - 1.0).abs() > 0.01) {
      _scrollHold ??= Scrollable.of(context)?.position.hold(() {});
    } else if (details.pointerCount <= 1 && (details.scale - 1.0).abs() <= 0.005) {
      _scrollHold?.cancel();
      _scrollHold = null;
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _scrollHold?.cancel();
    _scrollHold = null;
    _pointerCount = 0;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _scrollHold?.cancel();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointerCount++;
    // More aggressive: lock scroll as soon as 2 fingers detected
    if (_pointerCount >= 2) {
      _scrollHold ??= Scrollable.of(context)?.position.hold(() {});
    }
  }

  void _onPointerUp(PointerEvent event) {
    _pointerCount = (_pointerCount - 1).clamp(0, 10);
    // Add small delay before releasing scroll lock for better UX
    if (_pointerCount < 2) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_pointerCount < 2) {
          _scrollHold?.cancel();
          _scrollHold = null;
        }
      });
    }
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
    final cleanCode = widget.mermaidCode.trim();
    if (cleanCode.isEmpty) {
      setState(() {
        _error = 'Empty diagram code';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _pngData = null;
      _svgData = null;
    });

    try {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final result = await _repository.render(cleanCode, isDark: isDark);
      if (!mounted) return;

      if (result.error != null) {
        setState(() {
          _error = result.error;
          _isLoading = false;
        });
        if (_renderStart != null) {
          final ms = DateTime.now().difference(_renderStart!).inMilliseconds;
          debugPrint('[Mermaid] render failed after ${ms}ms');
        }
        return;
      }

      if (result.pngBytes != null) {
        setState(() {
          _pngData = Uint8List.fromList(result.pngBytes!);
          _isLoading = false;
          _error = null;
        });
        if (_renderStart != null) {
          final ms = DateTime.now().difference(_renderStart!).inMilliseconds;
          debugPrint('[Mermaid] render success (png) in ${ms}ms');
        }
      } else if (result.svg != null) {
        setState(() {
          _svgData = result.svg;
          _isLoading = false;
          _error = null;
        });
        if (_renderStart != null) {
          final ms = DateTime.now().difference(_renderStart!).inMilliseconds;
          debugPrint('[Mermaid] render success (svg) in ${ms}ms');
        }
      } else {
        setState(() {
          _error = 'Unknown render result';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Render failed: $e';
        _isLoading = false;
      });
      if (_renderStart != null) {
        final ms = DateTime.now().difference(_renderStart!).inMilliseconds;
        debugPrint('[Mermaid] render exception after ${ms}ms -> $e');
      }
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
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
              ),
            ),
            child: const Text(
              'Mermaid Diagram (Error)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.blue,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            width: double.infinity,
            child: Text(
              code,
              style: const TextStyle(
                fontFamily: 'Courier New',
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build WebView-based renderer that streams SVG back then uses flutter_svg to display.
  Widget _buildWebViewFlow(BuildContext context) {
    final processedCode =
        _prepareCode(widget.mermaidCode, Theme.of(context).brightness == Brightness.dark);
    final cacheKey = _cacheKey(processedCode, Theme.of(context).brightness == Brightness.dark);
    final cached = _svgMemoryCache[cacheKey];
    if (_svgData == null && cached != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _svgData = cached;
          _isLoading = false;
        });
      });
    }

    final currentSvg = _svgData ?? cached;

    final content = currentSvg != null
        ? _buildSvgContainer(currentSvg)
        : _error != null
            ? _buildErrorCard(widget.mermaidCode)
            : _buildLoading();

    return content;
  }

  String _cacheKey(String processedCode, bool isDark) =>
      '${processedCode.hashCode}:${isDark ? 'd' : 'l'}';

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

  String _prepareCode(String raw, bool isDark) {
    final cleanCode = raw
        .replaceAll('&gt;', '>')
        .replaceAll('&lt;', '<')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();

    final desiredTheme = isDark ? 'dark' : 'default';
    const initPattern = r'^%%\{init:\s*\{([\s\S]*?)\}\s*%%\s*';
    final regExp = RegExp(initPattern, multiLine: true);
    final match = regExp.firstMatch(cleanCode);

    final fallbackInit = {
      'theme': desiredTheme,
      'flowchart': {'htmlLabels': false},
      'sequence': {'useMaxWidth': false},
      'class': {'useMaxWidth': false},
      'er': {'useMaxWidth': false},
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
        existing.putIfAbsent('theme', () => desiredTheme);
        final flowchart = (existing['flowchart'] is Map)
            ? Map<String, dynamic>.from(existing['flowchart'] as Map)
            : <String, dynamic>{};
        flowchart['htmlLabels'] = false;
        existing['flowchart'] = flowchart;

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
        // fall through to fallback inject
      }
    }

    final initDirective = '%%{init: ${json.encode(fallbackInit)}}%%';
    return '$initDirective\n$cleanCode';
  }

  Widget _buildSvgContainer(String svg) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: (widget.height ?? 400) * 1.25,
            minHeight: widget.height ?? 350,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final viewWidth = constraints.maxWidth;
              return Listener(
                onPointerDown: _onPointerDown,
                onPointerUp: _onPointerUp,
                onPointerCancel: _onPointerUp,
                child: GestureDetector(
                  onScaleStart: _onScaleStart,
                  onScaleUpdate: _onScaleUpdate,
                  onScaleEnd: _onScaleEnd,
                  child: InteractiveViewer(
                    panEnabled: true,
                    scaleEnabled: true,
                    minScale: 0.5,
                    maxScale: 14.0,
                    boundaryMargin: const EdgeInsets.all(140),
                    constrained: true,
                    child: SizedBox(
                      width: viewWidth,
                      child: SvgPicture.string(
                        svg,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Builder(builder: (context) {
      if (_isLoading) {
        return _buildLoading();
      }

      if (_error != null) {
        return _buildErrorCard(widget.mermaidCode);
      }

      if (_pngData != null) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: (widget.height ?? 400) * 1.25,
              minHeight: widget.height ?? 350,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final viewWidth = constraints.maxWidth;
                  return Listener(
                    onPointerDown: _onPointerDown,
                    onPointerUp: _onPointerUp,
                    onPointerCancel: _onPointerUp,
                    child: GestureDetector(
                      onScaleStart: _onScaleStart,
                      onScaleUpdate: _onScaleUpdate,
                      onScaleEnd: _onScaleEnd,
                      child: InteractiveViewer(
                        panEnabled: true,
                        scaleEnabled: true,
                        minScale: 0.5,
                        maxScale: 14.0,
                        boundaryMargin: const EdgeInsets.all(140),
                        constrained: true,
                        child: SizedBox(
                          width: viewWidth,
                          child: Image.memory(
                            _pngData!,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      }

      if (_svgData != null) {
        // Sanitize SVG to remove foreignObject elements that cause black blocks
        final sanitizedSvg = _sanitizeSvg(_svgData!);
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: (widget.height ?? 400) * 1.25,
                minHeight: widget.height ?? 350,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final viewWidth = constraints.maxWidth;
                  return GestureDetector(
                    onScaleStart: _onScaleStart,
                    onScaleUpdate: _onScaleUpdate,
                    onScaleEnd: _onScaleEnd,
                    child: InteractiveViewer(
                      panEnabled: true,
                      scaleEnabled: true,
                      minScale: 0.6,
                      maxScale: 14.0,
                      boundaryMargin: const EdgeInsets.all(80),
                      constrained: true,
                      child: SizedBox(
                        width: viewWidth,
                        child: SvgPicture.string(
                          sanitizedSvg,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
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
        if (visible && !wasVisible) {
          _generateWhenVisible();
        }
      },
      child: content,
    );
  }
}
