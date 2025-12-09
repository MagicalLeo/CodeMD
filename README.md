# CodeMD

Local-first Markdown notebook built with Flutter. It supports rich Markdown, task lists, math (LaTeX), and Mermaid diagrams rendered entirely on-device (no network calls). Pinch/zoom works on diagrams and we bundle Mermaid assets for offline use.

## Features
- Full Markdown basics: headings, bold/italic/strike, inline code, links, blockquote, tables, fenced code blocks.
- Lists: ordered, unordered, nested, and task lists (checkboxes toggle state).
- Math: inline and block LaTeX equations.
- Mermaid: flowchart/sequence/class/state/pie/gantt, rendered locally via bundled `assets/mermaid/mermaid.html` + `mermaid.min.js` with SVG→PNG conversion for crisp zooming.
- Touch gestures: pinch/zoom and pan on diagrams; task list check toggles strike-through.
- Dark/Light aware theme variables for diagrams; HTML labels are disabled for safety/perf.

## Architecture (overview)
- Clean-ish layers: `core/` (services, repositories), `presentation/` (widgets/screens), `assets/mermaid/` for the headless renderer HTML/JS.
- Mermaid rendering uses a headless `InAppWebView` (no external API). JS posts results back through `MermaidChannel` (base64 SVG/PNG). Caching and sanitization live in the repository layer.

## Getting started
Prerequisites: Flutter stable (tested with 3.38.x / Dart 3.10.x). FVM is configured via `.fvmrc` if you use it.

```bash
flutter pub get
flutter run   # pick your device: windows / android / web / etc.
```

### Android / WebView notes
- Uses the system WebView. Ensure an updated WebView/Chrome (you’re on 142.x in current logs).
- Mermaid assets are bundled; no network access is required. CDN fallback is only used if the local JS fails to load.

### Desktop
Just run `flutter run -d windows` (or your platform). Mermaid still uses the bundled assets; no extra setup.

## Mermaid rendering details
- Entry: `lib/presentation/widgets/mermaid_svg_renderer.dart`
- Repo: `lib/core/repositories/mermaid_repository.dart`
- Headless webview service: `lib/core/services/mermaid_headless_service.dart`
- Assets: `assets/mermaid/mermaid.html`, `assets/mermaid/mermaid.min.js` (Mermaid 9.4.3)
- Logs: look for `[Mermaid] render ... in XXXms` in console to gauge render times.

## Known quirks
- Impeller is currently opted out (Flutter will deprecate this opt-out in future); remove the manifest flag when ready to try Impeller.
- Lint output includes some deprecated API warnings and unused helpers that are still under refactor.

## License
TBD.
