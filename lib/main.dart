import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/services/ad_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize AdMob (don't await - let it run in background)
  try {
    AdService().initialize();
  } catch (e) {
    debugPrint('AdMob init error: $e');
  }

  runApp(
    const ProviderScope(
      child: CodeMDApp(),
    ),
  );
}
