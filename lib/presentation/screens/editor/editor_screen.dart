import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/block_model.dart';
import '../../providers/document_provider.dart';
import '../../widgets/block_list.dart';

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  String? _focusedBlockId;

  @override
  Widget build(BuildContext context) {
    final documentState = ref.watch(documentProvider);
    final document = documentState.currentDocument;

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
          // Removed edit mode for pure viewing experience
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'export':
                  _exportDocument(context);
                  break;
                case 'info':
                  _showDocumentInfo(context, document);
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'export',
                child: Text('Export as Markdown'),
              ),
              const PopupMenuItem<String>(
                value: 'info',
                child: Text('Document Info'),
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
              : BlockList(
                blocks: document.blocks,
                isEditMode: false, // Always view mode for performance
                onBlockFocused: null, // No editing
              ),
    );
  }

  Widget _buildToolbarButton(
    BuildContext context,
    IconData icon,
    String tooltip,
    VoidCallback onPressed,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: IconButton(
        icon: Icon(icon),
        onPressed: onPressed,
        tooltip: tooltip,
        iconSize: 20,
      ),
    );
  }

  void _applyFormatting(String formatType) {
    if (_focusedBlockId != null) {
      ref.read(documentProvider.notifier).applyFormatting(_focusedBlockId!, formatType);
    } else {
      _showNoBlockSelectedMessage();
    }
  }

  void _insertLink() {
    if (_focusedBlockId == null) {
      _showNoBlockSelectedMessage();
      return;
    }
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String url = '';
        return AlertDialog(
          title: const Text('Insert Link'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'URL',
              hintText: 'https://example.com',
            ),
            onChanged: (value) {
              url = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (url.isNotEmpty) {
                  ref.read(documentProvider.notifier).applyFormatting(
                    _focusedBlockId!,
                    'link',
                    value: url,
                  );
                }
                Navigator.pop(context);
              },
              child: const Text('Insert'),
            ),
          ],
        );
      },
    );
  }

  void _convertToList() {
    if (_focusedBlockId != null) {
      ref.read(documentProvider.notifier).convertToList(_focusedBlockId!);
    } else {
      _showNoBlockSelectedMessage();
    }
  }

  void _convertToTaskList() {
    if (_focusedBlockId != null) {
      ref.read(documentProvider.notifier).convertToList(_focusedBlockId!, isTask: true);
    } else {
      _showNoBlockSelectedMessage();
    }
  }

  void _insertImage() {
    if (_focusedBlockId == null) {
      _showNoBlockSelectedMessage();
      return;
    }
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String imageUrl = '';
        return AlertDialog(
          title: const Text('Insert Image'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Image URL',
              hintText: 'https://example.com/image.png',
            ),
            onChanged: (value) {
              imageUrl = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (imageUrl.isNotEmpty) {
                  ref.read(documentProvider.notifier).insertImage(
                    _focusedBlockId!,
                    imageUrl,
                  );
                }
                Navigator.pop(context);
              },
              child: const Text('Insert'),
            ),
          ],
        );
      },
    );
  }

  void _insertTemplate(String templateType) {
    if (_focusedBlockId != null) {
      ref.read(documentProvider.notifier).addQuickInsert(_focusedBlockId!, templateType);
    } else {
      _showNoBlockSelectedMessage();
    }
  }

  void _showNoBlockSelectedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please select a block first'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showBlockTypeMenu(BuildContext context) {
    if (_focusedBlockId == null) {
      _showNoBlockSelectedMessage();
      return;
    }
    
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.looks_one),
                title: const Text('Heading 1'),
                onTap: () {
                  ref.read(documentProvider.notifier).updateBlockType(
                    _focusedBlockId!,
                    BlockType.heading1,
                  );
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.looks_two),
                title: const Text('Heading 2'),
                onTap: () {
                  ref.read(documentProvider.notifier).updateBlockType(
                    _focusedBlockId!,
                    BlockType.heading2,
                  );
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.looks_3),
                title: const Text('Heading 3'),
                onTap: () {
                  ref.read(documentProvider.notifier).updateBlockType(
                    _focusedBlockId!,
                    BlockType.heading3,
                  );
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.text_fields),
                title: const Text('Paragraph'),
                onTap: () {
                  ref.read(documentProvider.notifier).updateBlockType(
                    _focusedBlockId!,
                    BlockType.paragraph,
                  );
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.format_list_bulleted),
                title: const Text('Bullet List'),
                onTap: () {
                  ref.read(documentProvider.notifier).updateBlockType(
                    _focusedBlockId!,
                    BlockType.bulletList,
                  );
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.format_list_numbered),
                title: const Text('Numbered List'),
                onTap: () {
                  ref.read(documentProvider.notifier).updateBlockType(
                    _focusedBlockId!,
                    BlockType.numberedList,
                  );
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.check_box),
                title: const Text('Task List'),
                onTap: () {
                  ref.read(documentProvider.notifier).updateBlockType(
                    _focusedBlockId!,
                    BlockType.taskList,
                  );
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('Code Block'),
                onTap: () {
                  ref.read(documentProvider.notifier).updateBlockType(
                    _focusedBlockId!,
                    BlockType.code,
                  );
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.format_quote),
                title: const Text('Quote'),
                onTap: () {
                  ref.read(documentProvider.notifier).updateBlockType(
                    _focusedBlockId!,
                    BlockType.blockquote,
                  );
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.account_tree),
                title: const Text('Mermaid Diagram'),
                onTap: () {
                  ref.read(documentProvider.notifier).updateBlockType(
                    _focusedBlockId!,
                    BlockType.mermaid,
                  );
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _exportDocument(BuildContext context) {
    final markdown = ref.read(documentProvider.notifier).exportToMarkdown();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Exported Markdown'),
          content: SingleChildScrollView(
            child: SelectableText(
              markdown,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
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