import 'dart:async';
import 'dart:convert';
import 'dart:collection';
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
  bool _warmStarted = false;

  Future<void> ensureInitialized() async {
    if (_controller != null) return;
    if (_initStarted) {
      // wait until controller is ready
      while (_controller == null) {
        await Future.delayed(const Duration(milliseconds: 20));
      }
      if (!_isReady) {
        await _readyCompleter?.future.timeout(const Duration(seconds: 3), onTimeout: () {});
      }
      return;
    }
    _initStarted = true;
    _readyCompleter = Completer<void>();

    _headless = HeadlessInAppWebView(
      initialFile: 'assets/mermaid/mermaid.html',
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
      await _readyCompleter?.future.timeout(const Duration(seconds: 3), onTimeout: () {});
    }
  }

  Future<MermaidRenderResult> render(String mermaidCode, {required bool isDark, bool requestPng = false}) async {
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
    });
    final script = "renderMermaid($payload);";
    controller.evaluateJavascript(source: script);

    // timeout safety
    Future.delayed(const Duration(seconds: 6)).then((_) {
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
