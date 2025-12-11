import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../data/models/block_model.dart';
import '../../providers/document_provider.dart';
import '../../providers/text_scale_provider.dart';
import '../../widgets/block_list.dart';

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  @override
  Widget build(BuildContext context) {
    final documentState = ref.watch(documentProvider);
    final document = documentState.currentDocument;
    final textScale = ref.watch(textScaleProvider);

    if (document == null) {
      return const Scaffold(
        body: Center(
          child: Text('No document loaded'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(document.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: () {
              ref.read(textScaleProvider.notifier).increaseTextScale();
              HapticFeedback.lightImpact();
            },
            tooltip: 'Zoom In',
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: () {
              ref.read(textScaleProvider.notifier).decreaseTextScale();
              HapticFeedback.lightImpact();
            },
            tooltip: 'Zoom Out',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'info':
                  _showDocumentInfo(context, document);
                  break;
                case 'export':
                  _exportDocument(context);
                  break;
                case 'copy_content':
                  _copyToClipboard(context);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'info',
                child: Row(
                  children: [
                    Icon(Icons.info_outline),
                    SizedBox(width: 12),
                    Text('Document Info'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.share),
                    SizedBox(width: 12),
                    Text('Share File'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'copy_content',
                child: Row(
                  children: [
                    Icon(Icons.copy),
                    SizedBox(width: 12),
                    Text('Copy Content'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: documentState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : documentState.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading document',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        documentState.error!,
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(textScale),
                  ),
                  child: BlockList(
                    blocks: document.blocks,
                    isEditMode: false,
                    onBlockFocused: null,
                    filePath: document.filePath,
                  ),
                ),
    );
  }


  Future<void> _exportDocument(BuildContext context) async {
    final documentState = ref.read(documentProvider);
    final document = documentState.currentDocument;
    if (document == null) return;

    final markdown = ref.read(documentProvider.notifier).exportToMarkdown();

    try {
      // If we have the original file path, share that file directly
      if (document.filePath != null) {
        final file = File(document.filePath!);
        if (await file.exists()) {
          await Share.shareXFiles(
            [XFile(document.filePath!)],
            text: document.title,
          );
          return;
        }
      }

      // Otherwise, create a temp file and share it
      final tempDir = await getTemporaryDirectory();
      final fileName = '${document.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')}.md';
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsString(markdown);

      await Share.shareXFiles(
        [XFile(tempFile.path)],
        text: document.title,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _copyToClipboard(BuildContext context) {
    final markdown = ref.read(documentProvider.notifier).exportToMarkdown();
    
    Clipboard.setData(ClipboardData(text: markdown));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Content copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showDocumentInfo(BuildContext context, document) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Document Info'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Title: ${document.title}'),
              Text('Blocks: ${document.blocks.length}'),
              Text('Words: ${document.wordCount}'),
              Text('Created: ${document.createdAt.toLocal()}'),
              Text('Updated: ${document.updatedAt.toLocal()}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}