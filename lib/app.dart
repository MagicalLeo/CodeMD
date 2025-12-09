import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/screens/home/home_screen.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/document_provider.dart';

const _intentChannel = MethodChannel('codemd/intent');

class CodeMDApp extends ConsumerStatefulWidget {
  const CodeMDApp({super.key});

  @override
  ConsumerState<CodeMDApp> createState() => _CodeMDAppState();
}

class _CodeMDAppState extends ConsumerState<CodeMDApp> {
  @override
  void initState() {
    super.initState();
    _bootstrapIntent();
    _intentChannel.setMethodCallHandler((call) async {
      if (call.method == "onNewFile") {
        await _bootstrapIntent();
      }
    });
  }

  Future<void> _bootstrapIntent() async {
    try {
      final path = await _intentChannel.invokeMethod<String>('getInitialFile');
      if (path != null && mounted) {
        await ref.read(documentProvider.notifier).loadFromFile(path);
      }
    } catch (_) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CodeMD',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
