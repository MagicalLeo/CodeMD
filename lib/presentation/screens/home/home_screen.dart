import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/document_provider.dart';
import '../../providers/file_provider.dart';
import '../../providers/vault_provider.dart';
import '../editor/editor_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vaultState = ref.watch(vaultProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('CodeMD'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              ref.read(documentProvider.notifier).createNewDocument();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EditorScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: vaultState.files.isEmpty
          ? _buildEmptyState(context, ref)
          : _buildVaultContent(context, ref, vaultState),
    );
  }

  void _loadSampleDocument(WidgetRef ref, BuildContext context) {
    // Load a sample markdown document for testing
    const sampleMarkdown = '''
# Welcome to CodeMD

This is a **blazing fast** Markdown editor designed for mobile devices.

## Features

- 🚀 Ultra-fast rendering with virtual list
- 📝 Notion-style block editing
- 🎨 Syntax highlighting for code blocks
- 📊 Mermaid diagram support
- ✨ Real-time preview

## Code Example

```dart
void main() {
  print('Hello, CodeMD!');
}
```

## Task List

- [x] Create project structure
- [ ] Implement virtual list
- [ ] Add block editing
- [ ] Support Mermaid diagrams

## Quote

> The best way to predict the future is to invent it.
> - Alan Kay

## Table

| Feature | Status | Progress |
|---------|--------|----------|
| Virtual List | ✅ | 100% |
| Block Editor | 🚧 | 60% |
| Mermaid | 📋 | 10% |
| Performance | ⚡ | 80% |

## Mermaid Diagram

```mermaid
graph TD
    A[Start] --> B{Is it working?}
    B -->|Yes| C[Great!]
    B -->|No| D[Debug]
    D --> A
```

---

Made with ❤️ using Flutter
''';

    ref.read(documentProvider.notifier).loadMarkdown(
      sampleMarkdown,
      title: 'Sample Document',
    );
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EditorScreen(),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_outlined,
              size: 100,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome to CodeMD',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'A blazing fast Markdown editor',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(documentProvider.notifier).createNewDocument();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EditorScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Create New Document'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                await ref.read(fileProvider.notifier).pickAndLoadFile();
                final doc = ref.read(documentProvider).currentDocument;
                if (doc != null) {
                  // Add to vault only when we have a real path
                  if (doc.filePath != null) {
                    await ref.read(vaultProvider.notifier).addFile(
                      doc.filePath!,
                      title: doc.title,
                    );
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EditorScreen(),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.folder_open),
              label: const Text('Open Document'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                _loadSampleDocument(ref, context);
              },
              icon: const Icon(Icons.description),
              label: const Text('Load Sample'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVaultContent(BuildContext context, WidgetRef ref, VaultState vaultState) {
    return CustomScrollView(
      slivers: [
        // Quick actions
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ref.read(documentProvider.notifier).createNewDocument();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EditorScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('New'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await ref.read(fileProvider.notifier).pickAndLoadFile();
                      final doc = ref.read(documentProvider).currentDocument;
                      if (doc != null) {
                        if (doc.filePath != null) {
                          await ref.read(vaultProvider.notifier).addFile(
                            doc.filePath!,
                            title: doc.title,
                          );
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EditorScreen(),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.folder_open, size: 20),
                    label: const Text('Open'),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Pinned files
        if (vaultState.pinnedFiles.isNotEmpty) ...[
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Pinned',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final file = vaultState.pinnedFiles[index];
                return _buildFileItem(context, ref, file);
              },
              childCount: vaultState.pinnedFiles.length,
            ),
          ),
        ],

        // Recent files
        if (vaultState.recentFiles.isNotEmpty) ...[
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Recent',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final file = vaultState.recentFiles[index];
                return _buildFileItem(context, ref, file);
              },
              childCount: vaultState.recentFiles.length,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFileItem(BuildContext context, WidgetRef ref, file) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Icon(
          Icons.description,
          color: file.isPinned
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).iconTheme.color,
        ),
        title: Text(
          file.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${file.sizeFormatted} • ${_formatTime(file.lastOpened)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            switch (value) {
              case 'pin':
                await ref.read(vaultProvider.notifier).togglePin(file.path);
                break;
              case 'remove':
                await ref.read(vaultProvider.notifier).removeFile(file.path);
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              value: 'pin',
              child: Row(
                children: [
                  Icon(file.isPinned ? Icons.push_pin_outlined : Icons.push_pin),
                  const SizedBox(width: 8),
                  Text(file.isPinned ? 'Unpin' : 'Pin'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'remove',
              child: Row(
                children: [
                  Icon(Icons.delete_outline),
                  SizedBox(width: 8),
                  Text('Remove from vault'),
                ],
              ),
            ),
          ],
        ),
        onTap: () async {
          await ref.read(vaultProvider.notifier).openFile(file.path);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EditorScreen(),
            ),
          );
        },
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
