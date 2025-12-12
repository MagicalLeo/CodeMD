import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/document_provider.dart';
import '../../providers/file_provider.dart';
import '../../providers/vault_provider.dart';
import '../../../data/models/vault_model.dart';
import '../editor/editor_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vaultState = ref.watch(vaultProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0d1117) : const Color(0xFFF6F8FA),
      appBar: _buildAppBar(context, vaultState, isDark),
      body: vaultState.files.isEmpty && vaultState.folders.isEmpty
          ? _buildEmptyState(context, isDark)
          : _buildMainContent(context, vaultState, isDark),
      floatingActionButton: _buildFAB(context, isDark),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, VaultState vaultState, bool isDark) {
    if (_isSearching) {
      return AppBar(
        backgroundColor: isDark ? const Color(0xFF161b22) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _isSearching = false;
              _searchController.clear();
            });
            ref.read(vaultProvider.notifier).clearSearch();
          },
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search files...',
            border: InputBorder.none,
            hintStyle: TextStyle(
              color: isDark ? Colors.grey[500] : Colors.grey[400],
            ),
          ),
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
          ),
          onChanged: (value) {
            ref.read(vaultProvider.notifier).setSearchQuery(value);
          },
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                ref.read(vaultProvider.notifier).clearSearch();
              },
            ),
        ],
      );
    }

    return AppBar(
      backgroundColor: isDark ? const Color(0xFF161b22) : Colors.white,
      elevation: 0,
      title: vaultState.currentFolder != null
          ? Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    ref.read(vaultProvider.notifier).setCurrentFolder(null);
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                Text(
                  vaultState.currentFolder!,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          : Text(
              'CodeMD',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () {
            setState(() {
              _isSearching = true;
            });
          },
          tooltip: 'Search',
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          },
          tooltip: 'Settings',
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF21262d) : Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.description_outlined,
                size: 40,
                color: isDark ? Colors.blue[400] : Colors.blue[600],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome to CodeMD',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'A fast, beautiful Markdown reader',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => _openFile(context),
              icon: const Icon(Icons.folder_open),
              label: const Text('Open Markdown File'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, VaultState vaultState, bool isDark) {
    // If searching, show search results
    if (vaultState.searchQuery.isNotEmpty) {
      return _buildSearchResults(context, vaultState, isDark);
    }

    // If in a folder, show folder contents
    if (vaultState.currentFolder != null) {
      return _buildFolderContents(context, vaultState, isDark);
    }

    // Otherwise show main vault view
    return _buildVaultView(context, vaultState, isDark);
  }

  Widget _buildVaultView(BuildContext context, VaultState vaultState, bool isDark) {
    return CustomScrollView(
      slivers: [
        // Folders section
        if (vaultState.folders.isNotEmpty) ...[
          _buildSectionHeader('Folders', isDark),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.5,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final folder = vaultState.foldersWithCounts[index];
                  return _buildFolderCard(context, folder, isDark);
                },
                childCount: vaultState.foldersWithCounts.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],

        // Recent files section
        if (vaultState.recentFiles.isNotEmpty) ...[
          _buildSectionHeader('Recent', isDark),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final file = vaultState.recentFiles[index];
                  return _buildFileCard(context, file, isDark);
                },
                childCount: vaultState.recentFiles.length,
              ),
            ),
          ),
        ],

        // Pinned files section
        if (vaultState.pinnedFiles.isNotEmpty) ...[
          _buildSectionHeader('Pinned', isDark),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final file = vaultState.pinnedFiles[index];
                  return _buildFileCard(context, file, isDark);
                },
                childCount: vaultState.pinnedFiles.length,
              ),
            ),
          ),
        ],

        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _buildSearchResults(BuildContext context, VaultState vaultState, bool isDark) {
    final results = vaultState.filteredFiles;

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final file = results[index];
        return _buildFileCard(context, file, isDark);
      },
    );
  }

  Widget _buildFolderContents(BuildContext context, VaultState vaultState, bool isDark) {
    final files = vaultState.filteredFiles;

    if (files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 64,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'This folder is empty',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        return _buildFileCard(context, file, isDark);
      },
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildFolderCard(BuildContext context, VaultFolderModel folder, bool isDark) {
    return Material(
      color: isDark ? const Color(0xFF21262d) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          ref.read(vaultProvider.notifier).setCurrentFolder(folder.name);
        },
        onLongPress: () => _showFolderOptions(context, folder),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.folder,
                color: Colors.blue[400],
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      folder.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${folder.fileCount} files',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileCard(BuildContext context, VaultFileModel file, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isDark ? const Color(0xFF21262d) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openFileFromVault(context, file),
          onLongPress: () => _showFileOptions(context, file),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.blue.withOpacity(0.2)
                        : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    file.isPinned ? Icons.push_pin : Icons.description_outlined,
                    color: Colors.blue[400],
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.displayTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${file.sizeFormatted} • ${_formatTime(file.lastOpened)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFAB(BuildContext context, bool isDark) {
    return FloatingActionButton.extended(
      onPressed: () => _showAddOptions(context, isDark),
      icon: const Icon(Icons.add),
      label: const Text('Add'),
      backgroundColor: Colors.blue,
      foregroundColor: Colors.white,
    );
  }

  void _showAddOptions(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF21262d) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.file_open, color: Colors.blue),
                title: const Text('Open File'),
                subtitle: const Text('Open a Markdown file from storage'),
                onTap: () {
                  Navigator.pop(context);
                  _openFile(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.create_new_folder, color: Colors.orange),
                title: const Text('New Folder'),
                subtitle: const Text('Create a folder to organize files'),
                onTap: () {
                  Navigator.pop(context);
                  _showCreateFolderDialog(context, isDark);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateFolderDialog(BuildContext context, bool isDark) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF21262d) : Colors.white,
        title: const Text('New Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Folder name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref.read(vaultProvider.notifier).createFolder(name);
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showFolderOptions(BuildContext context, VaultFolderModel folder) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF21262d) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Rename'),
                onTap: () {
                  Navigator.pop(context);
                  _showRenameFolderDialog(context, folder, isDark);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(vaultProvider.notifier).deleteFolder(folder.name);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRenameFolderDialog(BuildContext context, VaultFolderModel folder, bool isDark) {
    final controller = TextEditingController(text: folder.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF21262d) : Colors.white,
        title: const Text('Rename Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Folder name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != folder.name) {
                ref.read(vaultProvider.notifier).renameFolder(folder.name, newName);
                Navigator.pop(context);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showFileOptions(BuildContext context, VaultFileModel file) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vaultState = ref.read(vaultProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF21262d) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Icon(file.isPinned ? Icons.push_pin_outlined : Icons.push_pin),
                title: Text(file.isPinned ? 'Unpin' : 'Pin'),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(vaultProvider.notifier).togglePin(file.path);
                },
              ),
              if (vaultState.folders.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.drive_file_move_outline),
                  title: const Text('Move to Folder'),
                  onTap: () {
                    Navigator.pop(context);
                    _showMoveToFolderDialog(context, file, isDark);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Remove from Library', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(vaultProvider.notifier).removeFile(file.path);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMoveToFolderDialog(BuildContext context, VaultFileModel file, bool isDark) {
    final vaultState = ref.read(vaultProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF21262d) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Move to Folder',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.folder_off_outlined),
                title: const Text('No Folder'),
                selected: file.folder == null,
                onTap: () {
                  Navigator.pop(context);
                  ref.read(vaultProvider.notifier).moveFileToFolder(file.path, null);
                },
              ),
              ...vaultState.folders.map((folder) => ListTile(
                leading: const Icon(Icons.folder),
                title: Text(folder.name),
                selected: file.folder == folder.name,
                onTap: () {
                  Navigator.pop(context);
                  ref.read(vaultProvider.notifier).moveFileToFolder(file.path, folder.name);
                },
              )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openFile(BuildContext context) async {
    await ref.read(fileProvider.notifier).pickAndLoadFile();
    final doc = ref.read(documentProvider).currentDocument;
    if (doc != null) {
      if (doc.filePath != null) {
        await ref.read(vaultProvider.notifier).addFile(
          doc.filePath!,
          title: doc.title,
        );
      }
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const EditorScreen(),
          ),
        );
      }
    }
  }

  Future<void> _openFileFromVault(BuildContext context, VaultFileModel file) async {
    await ref.read(fileProvider.notifier).loadRecentFile(file.path);

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const EditorScreen(),
        ),
      );

      ref.read(vaultProvider.notifier).updateLastOpened(file.path);
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inDays > 7) {
      return '${dateTime.month}/${dateTime.day}';
    } else if (diff.inDays > 0) {
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
