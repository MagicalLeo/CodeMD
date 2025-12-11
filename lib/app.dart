import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/screens/editor/editor_screen.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/document_provider.dart';
import 'presentation/providers/vault_provider.dart';

const _intentChannel = MethodChannel('codemd/intent');

class CodeMDApp extends ConsumerStatefulWidget {
  const CodeMDApp({super.key});

  @override
  ConsumerState<CodeMDApp> createState() => _CodeMDAppState();
}

class _CodeMDAppState extends ConsumerState<CodeMDApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _intentChannel.setMethodCallHandler((call) async {
      if (call.method == "onNewFile") {
        await _bootstrapIntent();
      }
    });
    // Delay initial intent check to ensure navigator is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrapIntent();
    });
  }

  Future<void> _bootstrapIntent() async {
    try {
      final path = await _intentChannel.invokeMethod<String>('getInitialFile');
      if (path != null && mounted) {
        await ref.read(documentProvider.notifier).loadFromFile(path);
        final doc = ref.read(documentProvider).currentDocument;
        if (doc != null) {
          // Add to vault
          if (doc.filePath != null) {
            await ref.read(vaultProvider.notifier).addFile(
              doc.filePath!,
              title: doc.title,
            );
          }
          // Navigate to editor
          _navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => const EditorScreen(),
            ),
          );
        }
      }
    } catch (_) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CodeMD',
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
