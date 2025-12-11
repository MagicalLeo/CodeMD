import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../core/repositories/mermaid_repository.dart';

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
            child: Stack(
              children: [
                // Use intrinsic height to show full image without cutting
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Image.memory(
                    _pngData!,
                    fit: BoxFit.contain,
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
            child: Stack(
              children: [
                // Use intrinsic height to show full image without cutting
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: SvgPicture.string(
                    sanitizedSvg,
                    fit: BoxFit.contain,
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
                      onTap: () => _showFullScreenViewer(context, svgData: sanitizedSvg),
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

class _FullScreenMermaidViewer extends StatelessWidget {
  final Uint8List? pngData;
  final String? svgData;

  const _FullScreenMermaidViewer({
    this.pngData,
    this.svgData,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          child: pngData != null
              ? Image.memory(pngData!, fit: BoxFit.contain)
              : svgData != null
                  ? SvgPicture.string(svgData!, fit: BoxFit.contain)
                  : const Text('No diagram'),
        ),
      ),
    );
  }
}
