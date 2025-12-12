import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/services/ad_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize AdMob
  AdService().initialize();

  runApp(
    const ProviderScope(
      child: CodeMDApp(),
    ),
  );
}
