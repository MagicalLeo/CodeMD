import 'dart:async';
import 'dart:convert';
import 'dart:collection';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class MermaidRenderResult {
  final String? svgBase64;
  final String? pngBase64;
  final String? error;
  const MermaidRenderResult({this.svgBase64, this.pngBase64, this.error});
}

/// Single headless WebView to render Mermaid locally (no network).
class MermaidHeadlessService {
  static final MermaidHeadlessService _instance = MermaidHeadlessService._internal();
  factory MermaidHeadlessService() => _instance;
  MermaidHeadlessService._internal();

  final Map<String, Completer<MermaidRenderResult>> _pending = {};
  HeadlessInAppWebView? _headless;
  InAppWebViewController? _controller;
  bool _initStarted = false;
  Completer<void>? _readyCompleter;
  bool _isReady = false;
  Future<void>? _renderChain;

  Future<void> ensureInitialized() async {
    if (_controller != null) return;
    if (_initStarted) {
      // wait until controller is ready
      while (_controller == null) {
        await Future.delayed(const Duration(milliseconds: 20));
      }
      if (!_isReady) {
        await _readyCompleter?.future.timeout(const Duration(seconds: 5), onTimeout: () {});
      }
      return;
    }
    _initStarted = true;
    _readyCompleter = Completer<void>();

    // Load assets from Flutter bundle
    String mermaidJs;
    try {
      mermaidJs = await rootBundle.loadString('assets/mermaid/mermaid.min.js');
    } catch (e) {
      // Fallback to CDN if local asset fails
      mermaidJs = '';
    }

    final htmlContent = _buildHtmlContent(mermaidJs);

    _headless = HeadlessInAppWebView(
      initialData: InAppWebViewInitialData(
        data: htmlContent,
        mimeType: 'text/html',
        encoding: 'utf-8',
      ),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        transparentBackground: true,
        useHybridComposition: false,
        allowsInlineMediaPlayback: true,
      ),
      onWebViewCreated: (controller) {
        _controller = controller;
        controller.addJavaScriptHandler(
          handlerName: 'MermaidChannel',
          callback: (args) {
            if (args.isEmpty) return;
            try {
              final Map<String, dynamic> data = Map<String, dynamic>.from(args.first);
              final requestId = data['requestId'] as String?;
              if (data['type'] == 'ready') {
                _isReady = true;
                _readyCompleter?.complete();
                return;
              }
              if (requestId == null) return;
              final completer = _pending.remove(requestId);
              if (completer == null) return;
              completer.complete(MermaidRenderResult(
                svgBase64: data['svg'] as String?,
                pngBase64: data['png'] as String?,
                error: data['error'] as String?,
              ));
            } catch (_) {}
          },
        );
      },
      onLoadError: (controller, url, code, message) {
        _completeAllWithError('load error $message');
      },
      onLoadHttpError: (controller, url, statusCode, description) {
        _completeAllWithError('http error $description');
      },
      onLoadStop: (controller, url) {},
    );

    await _headless?.run();
    if (!_isReady) {
      await _readyCompleter?.future.timeout(const Duration(seconds: 5), onTimeout: () {});
    }
  }

  String _buildHtmlContent(String mermaidJs) {
    // Always use CDN for reliability - local asset loading has issues in headless webview
    const scriptTag = '<script src="https://cdn.jsdelivr.net/npm/mermaid@10.6.1/dist/mermaid.min.js"></script>';

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8" />
  <style>
    html, body { margin:0; padding:0; overflow:hidden; background: transparent; }
  </style>
  $scriptTag
  <script>
    window.__mermaidReady = typeof mermaid !== 'undefined';

    function sendToFlutter(data) {
      try {
        if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
          window.flutter_inappwebview.callHandler('MermaidChannel', data);
        }
      } catch (e) {
        console.log('postMessage error', e);
      }
    }

    async function waitMermaid() {
      const maxWait = 5000;
      const start = performance.now();
      while (!window.__mermaidReady && !window.mermaid && performance.now() - start < maxWait) {
        await new Promise((r) => setTimeout(r, 50));
      }
      if (!window.mermaid) {
        throw new Error('Mermaid not loaded');
      }
    }

    async function renderMermaid(payload) {
      const { code, theme, requestId } = payload;
      try {
        await waitMermaid();
        window.mermaid.initialize({
          startOnLoad: false,
          securityLevel: 'loose',
          theme: theme || 'default',
          flowchart: { htmlLabels: false, useMaxWidth: false },
          sequence: { useMaxWidth: false, mirrorActors: false, useHtmlLabels: false },
          class: { useMaxWidth: false, htmlLabels: false },
          er: { useMaxWidth: false, htmlLabels: false },
          journey: { useHtmlLabels: false },
          pie: { useHtmlLabels: false },
        });

        const { svg: svgCode } = await window.mermaid.render('id' + Date.now(), code);
        const svgBase64 = btoa(unescape(encodeURIComponent(svgCode)));

        try {
          const isDark = theme === 'dark';
          const pngBase64 = await svgToPng(svgCode, isDark);
          sendToFlutter({ type: 'renderSuccess', requestId, svg: svgBase64, png: pngBase64 });
        } catch (e) {
          sendToFlutter({ type: 'renderSuccess', requestId, svg: svgBase64 });
        }
      } catch (e) {
        sendToFlutter({ type: 'renderError', requestId, error: e.message || String(e) });
      }
    }

    async function svgToPng(svgString, isDark) {
      return new Promise((resolve, reject) => {
        // Parse SVG to get dimensions
        const parser = new DOMParser();
        const svgDoc = parser.parseFromString(svgString, 'image/svg+xml');
        const svgEl = svgDoc.documentElement;

        // Get dimensions from viewBox or width/height attributes
        let width = parseFloat(svgEl.getAttribute('width')) || 800;
        let height = parseFloat(svgEl.getAttribute('height')) || 600;
        const viewBox = svgEl.getAttribute('viewBox');
        if (viewBox) {
          const parts = viewBox.split(' ').map(Number);
          if (parts.length === 4) {
            width = parts[2] || width;
            height = parts[3] || height;
          }
        }

        const svgBlob = new Blob([svgString], { type: 'image/svg+xml' });
        const url = URL.createObjectURL(svgBlob);
        const img = new Image();
        img.onload = () => {
          try {
            const canvas = document.createElement('canvas');
            const ratio = 2.5;
            const w = (img.width || width) * ratio;
            const h = (img.height || height) * ratio;
            canvas.width = w;
            canvas.height = h;
            const ctx = canvas.getContext('2d');
            // Fill background (white for light mode, dark for dark mode)
            ctx.fillStyle = isDark ? '#1a1a2e' : '#ffffff';
            ctx.fillRect(0, 0, w, h);
            ctx.scale(ratio, ratio);
            ctx.drawImage(img, 0, 0);
            const dataUrl = canvas.toDataURL('image/png');
            URL.revokeObjectURL(url);
            resolve(dataUrl.split(',')[1]);
          } catch (err) {
            reject(err);
          }
        };
        img.onerror = reject;
        img.src = url;
      });
    }

    // Signal ready when DOM is loaded
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', () => {
        window.renderMermaid = renderMermaid;
        window.__mermaidReady = typeof mermaid !== 'undefined';
        sendToFlutter({ type: 'ready' });
      });
    } else {
      window.renderMermaid = renderMermaid;
      window.__mermaidReady = typeof mermaid !== 'undefined';
      sendToFlutter({ type: 'ready' });
    }
  </script>
</head>
<body></body>
</html>
''';
  }

  Future<MermaidRenderResult> render(String mermaidCode, {required bool isDark, bool requestPng = false}) async {
    final completer = Completer<MermaidRenderResult>();
    _renderChain = (_renderChain ?? Future.value()).then((_) async {
      final result = await _renderOnce(mermaidCode, isDark, requestPng);
      if (!completer.isCompleted) completer.complete(result);
    }).catchError((e) {
      if (!completer.isCompleted) {
        completer.complete(MermaidRenderResult(error: e.toString()));
      }
    });
    return completer.future;
  }

  Future<MermaidRenderResult> _renderOnce(String mermaidCode, bool isDark, bool requestPng) async {
    await ensureInitialized();
    final controller = _controller;
    if (controller == null) {
      return const MermaidRenderResult(error: 'Renderer not ready');
    }

    final requestId = DateTime.now().microsecondsSinceEpoch.toString();
    final completer = Completer<MermaidRenderResult>();
    _pending[requestId] = completer;

    final payload = jsonEncode({
      'code': mermaidCode,
      'theme': isDark ? 'dark' : 'default',
      'requestId': requestId,
      'png': requestPng,
    });
    final script = "renderMermaid($payload);";
    controller.evaluateJavascript(source: script);

    // timeout safety
    Future.delayed(const Duration(seconds: 8)).then((_) {
      if (!completer.isCompleted) {
        _pending.remove(requestId);
        completer.complete(const MermaidRenderResult(error: 'timeout'));
      }
    });

    return completer.future;
  }

  void _completeAllWithError(String error) {
    final pending = UnmodifiableMapView(_pending);
    _pending.clear();
    for (final c in pending.values) {
      if (!c.isCompleted) c.complete(MermaidRenderResult(error: error));
    }
  }
}
