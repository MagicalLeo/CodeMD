import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../../../core/services/ad_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  String _logLevelToString(LogLevel level) {
    switch (level) {
      case LogLevel.none:
        return 'None';
      case LogLevel.error:
        return 'Error';
      case LogLevel.warning:
        return 'Warning';
      case LogLevel.info:
        return 'Info';
      case LogLevel.verbose:
        return 'Verbose';
    }
  }

  String _themeModeToString(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return 'System';
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
    }
  }

  IconData _themeModeIcon(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return Icons.brightness_auto;
      case AppThemeMode.light:
        return Icons.light_mode;
      case AppThemeMode.dark:
        return Icons.dark_mode;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    // Update global logger when settings change
    DebugLogger.updateSettings(settings);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Support Us Section
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [Colors.blue.shade900, Colors.purple.shade900]
                    : [Colors.blue.shade50, Colors.purple.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.blue.shade700 : Colors.blue.shade200,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.favorite,
                  size: 40,
                  color: isDark ? Colors.pink.shade300 : Colors.pink.shade400,
                ),
                const SizedBox(height: 12),
                Text(
                  'Support CodeMD',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Help us keep CodeMD free and ad-free in the reading experience!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    _showRewardedAd(context);
                  },
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('Watch an Ad to Support'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),

          const Divider(),
          const _SectionHeader(title: 'Appearance'),
          ListTile(
            leading: Icon(_themeModeIcon(settings.themeMode)),
            title: const Text('Theme'),
            subtitle: Text(_themeModeToString(settings.themeMode)),
            trailing: SegmentedButton<AppThemeMode>(
              segments: const [
                ButtonSegment(
                  value: AppThemeMode.system,
                  icon: Icon(Icons.brightness_auto, size: 18),
                ),
                ButtonSegment(
                  value: AppThemeMode.light,
                  icon: Icon(Icons.light_mode, size: 18),
                ),
                ButtonSegment(
                  value: AppThemeMode.dark,
                  icon: Icon(Icons.dark_mode, size: 18),
                ),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (Set<AppThemeMode> selected) {
                ref.read(settingsProvider.notifier).setThemeMode(selected.first);
              },
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),

          const Divider(),
          const _SectionHeader(title: 'Developer Options'),
          SwitchListTile(
            title: const Text('Debug Mode'),
            subtitle: const Text('Show debug info overlays and detailed errors'),
            value: settings.debugMode,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setDebugMode(value);
            },
            secondary: const Icon(Icons.bug_report_outlined),
          ),
          ListTile(
            leading: const Icon(Icons.terminal),
            title: const Text('Log Level'),
            subtitle: Text(_logLevelToString(settings.logLevel)),
            trailing: DropdownButton<LogLevel>(
              value: settings.logLevel,
              underline: const SizedBox(),
              onChanged: (LogLevel? newValue) {
                if (newValue != null) {
                  ref.read(settingsProvider.notifier).setLogLevel(newValue);
                }
              },
              items: LogLevel.values.map((LogLevel level) {
                return DropdownMenuItem<LogLevel>(
                  value: level,
                  child: Text(_logLevelToString(level)),
                );
              }).toList(),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: const Text('View Logs'),
            subtitle: Text('${DebugLogger.logs.length} entries'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const _LogViewerScreen()),
              );
            },
          ),

          const Divider(),
          const _SectionHeader(title: 'About'),

          // App Info Card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // App Logo
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/logo.png',
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'CodeMD',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.blue.shade900 : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'v1.0.0',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.blue.shade200 : Colors.blue.shade700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'A fast, beautiful Markdown reader with Mermaid diagrams, LaTeX math, and syntax highlighting.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _FeatureChip(icon: Icons.code, label: 'Flutter', isDark: isDark),
                    const SizedBox(width: 8),
                    _FeatureChip(icon: Icons.lock_outline, label: 'Privacy First', isDark: isDark),
                  ],
                ),
              ],
            ),
          ),

          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            subtitle: const Text('Your data stays on your device'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showPrivacyInfo(context);
            },
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showRewardedAd(BuildContext context) {
    final adService = AdService();

    if (!adService.isAdLoaded) {
      // Ad not ready, show loading message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loading ad, please try again in a moment...'),
          duration: Duration(seconds: 2),
        ),
      );
      // Try to load ad for next time
      adService.loadRewardedAd();
      return;
    }

    adService.showRewardedAd(
      onRewarded: (amount, type) {
        // Show thank you dialog after watching ad
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.favorite, color: Colors.pink),
                SizedBox(width: 8),
                Text('Thank You!'),
              ],
            ),
            content: const Text(
              'Thank you so much for supporting CodeMD!\n\n'
              'Your support helps us keep the app free and continue improving it.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('You\'re welcome!'),
              ),
            ],
          ),
        );
      },
      onAdNotReady: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ad not available right now, please try later'),
            duration: Duration(seconds: 2),
          ),
        );
      },
    );
  }

  void _showPrivacyInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy'),
        content: const SingleChildScrollView(
          child: Text(
            'CodeMD respects your privacy:\n\n'
            '• All files are processed locally on your device\n'
            '• No personal data is collected or transmitted\n'
            '• No account or registration required\n'
            '• Mermaid diagrams use CDN (jsdelivr.net) to load the rendering library\n'
            '• No analytics or tracking',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;

  const _FeatureChip({
    required this.icon,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LogViewerScreen extends StatefulWidget {
  const _LogViewerScreen();

  @override
  State<_LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<_LogViewerScreen> {
  LogLevel _filterLevel = LogLevel.none;

  Color _levelColor(LogLevel level) {
    switch (level) {
      case LogLevel.error:
        return Colors.red;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.info:
        return Colors.blue;
      case LogLevel.verbose:
        return Colors.grey;
      case LogLevel.none:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final logs = DebugLogger.logs
        .where((l) => _filterLevel == LogLevel.none || l.level.index <= _filterLevel.index)
        .toList()
        .reversed
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
        actions: [
          PopupMenuButton<LogLevel>(
            icon: const Icon(Icons.filter_list),
            onSelected: (level) => setState(() => _filterLevel = level),
            itemBuilder: (context) => [
              const PopupMenuItem(value: LogLevel.none, child: Text('All')),
              const PopupMenuItem(value: LogLevel.error, child: Text('Errors only')),
              const PopupMenuItem(value: LogLevel.warning, child: Text('Warnings+')),
              const PopupMenuItem(value: LogLevel.info, child: Text('Info+')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              final allLogs = DebugLogger.logs.map((l) => l.formatted).join('\n');
              Clipboard.setData(ClipboardData(text: allLogs));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Copied ${DebugLogger.logs.length} logs'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            tooltip: 'Copy all logs',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              DebugLogger.clearLogs();
              setState(() {});
            },
            tooltip: 'Clear logs',
          ),
        ],
      ),
      body: logs.isEmpty
          ? const Center(child: Text('No logs yet'))
          : ListView.builder(
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final log = logs[index];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: _levelColor(log.level).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              log.level.name.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: _levelColor(log.level),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            log.tag,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${log.time.hour.toString().padLeft(2, '0')}:${log.time.minute.toString().padLeft(2, '0')}:${log.time.second.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      SelectableText(
                        log.message,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
