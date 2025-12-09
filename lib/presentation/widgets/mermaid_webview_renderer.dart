import 'dart:async';
import 'dart:convert';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// WebView-based Mermaid renderer using local assets (mermaid.min.js + html).
/// Uses InAppWebView (virtual display) to avoid system WebView crashes.
/// Returns PNG (hi-dpi) and SVG via JS channel; caller handles display.
class MermaidWebViewRenderer extends StatefulWidget {
  final String mermaidCode;
  final bool isDark;
  final double? width;
  final double? height;
  final void Function(String svgBase64)? onRendered;
  final void Function(String error)? onError;
  final void Function(String pngBase64)? onPng;

  const MermaidWebViewRenderer({
    super.key,
    required this.mermaidCode,
    required this.isDark,
    this.width,
    this.height,
    this.onRendered,
    this.onError,
    this.onPng,
  });

  @override
  State<MermaidWebViewRenderer> createState() => _MermaidWebViewRendererState();
}

class _MermaidWebViewRendererState extends State<MermaidWebViewRenderer> {
  InAppWebViewController? _controller;
  late final String _requestId;
  final InAppWebViewSettings _settings = InAppWebViewSettings(
    javaScriptEnabled: true,
    javaScriptCanOpenWindowsAutomatically: false,
    allowsInlineMediaPlayback: true,
    transparentBackground: true,
    useHybridComposition: false, // prefer virtual display
  );

  @override
  void initState() {
    super.initState();
    _requestId = UniqueKey().toString();
  }

  void _postRender() {
    if (_controller == null) return;
    final theme = widget.isDark ? 'dark' : 'default';
    final payload = jsonEncode({
      'code': widget.mermaidCode,
      'theme': theme,
      'requestId': _requestId,
    });
    final script = "renderMermaid($payload);";
    _controller!.evaluateJavascript(source: script);
  }

  @override
  void didUpdateWidget(MermaidWebViewRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mermaidCode != widget.mermaidCode || oldWidget.isDark != widget.isDark) {
      _postRender();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height ?? 320,
      child: InAppWebView(
        initialSettings: _settings,
        initialFile: 'assets/mermaid/mermaid.html',
        onWebViewCreated: (controller) {
          _controller = controller;
          controller.addJavaScriptHandler(handlerName: 'MermaidChannel', callback: (args) {
            try {
              final data = args.first as Map<String, dynamic>;
              if (data['requestId'] != _requestId) return;
              switch (data['type']) {
                case 'renderSuccess':
                  if (data['png'] != null) {
                    widget.onPng?.call(data['png']);
                  }
                  widget.onRendered?.call(data['svg']);
                  break;
                case 'renderError':
                  widget.onError?.call(data['error'] ?? 'unknown error');
                  break;
              }
            } catch (_) {}
          });
        },
        onLoadStop: (controller, url) async {
          _postRender();
        },
        onConsoleMessage: (controller, msg) {
          // Optional: log if needed
        },
        onLoadError: (controller, url, code, message) {
          widget.onError?.call(message);
        },
        onLoadHttpError: (controller, url, statusCode, description) {
          widget.onError?.call(description);
        },
        onReceivedHttpError: (controller, request, errorResponse) {
          widget.onError?.call(errorResponse.reasonPhrase ?? 'http error');
        },
        onJsAlert: (controller, jsAlertRequest) async {
          return JsAlertResponse(
            handledByClient: true,
            action: JsAlertResponseAction.CONFIRM,
          );
        },
        onJsConfirm: (controller, jsConfirmRequest) async {
          return JsConfirmResponse(
            handledByClient: true,
            action: JsConfirmResponseAction.CONFIRM,
          );
        },
        onReceivedError: (controller, request, error) {
          widget.onError?.call(error.description);
        },
        onUpdateVisitedHistory: (controller, url, androidIsReload) {},
        onLoadResourceCustomScheme: (controller, scheme) async {
          return null;
        },
        onJsPrompt: (controller, jsPromptRequest) async {
          return JsPromptResponse(handledByClient: false);
        },
        onLoadResource: (controller, resource) {},
        // Bridge: MermaidChannel.postMessage(...) will hit this handler
        initialUserScripts: UnmodifiableListView([
          UserScript(
            source: """
              window.MermaidChannel = {
                postMessage: function(msg) {
                  window.flutter_inappwebview.callHandler('MermaidChannel', JSON.parse(msg));
                }
              };
            """,
            injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          )
        ]),
      ),
    );
  }
}
