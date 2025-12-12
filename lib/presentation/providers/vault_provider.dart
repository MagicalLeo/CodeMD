import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../data/models/vault_model.dart';
import 'document_provider.dart';
import 'file_provider.dart';

class VaultState {
  final List<VaultFileModel> files;
  final List<VaultFolderModel> folders;
  final bool isLoading;
  final String? error;
  final String? vaultPath;
  final String? currentFolder; // null = all files view
  final String searchQuery;
  final List<VaultFileModel> _pinnedFiles;
  final List<VaultFileModel> _recentFiles;

  VaultState({
    this.files = const [],
    this.folders = const [],
    this.isLoading = false,
    this.error,
    this.vaultPath,
    this.currentFolder,
    this.searchQuery = '',
    List<VaultFileModel>? pinnedFiles,
    List<VaultFileModel>? recentFiles,
  }) : _pinnedFiles = pinnedFiles ?? files.where((f) => f.isPinned).toList(),
       _recentFiles = recentFiles ?? (files
          .where((f) => !f.isPinned)
          .toList()
        ..sort((a, b) => b.lastOpened.compareTo(a.lastOpened)));

  VaultState copyWith({
    List<VaultFileModel>? files,
    List<VaultFolderModel>? folders,
    bool? isLoading,
    String? error,
    String? vaultPath,
    String? currentFolder,
    bool clearCurrentFolder = false,
    String? searchQuery,
  }) {
    final newFiles = files ?? this.files;
    return VaultState(
      files: newFiles,
      folders: folders ?? this.folders,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      vaultPath: vaultPath ?? this.vaultPath,
      currentFolder: clearCurrentFolder ? null : (currentFolder ?? this.currentFolder),
      searchQuery: searchQuery ?? this.searchQuery,
      pinnedFiles: newFiles.where((f) => f.isPinned).toList(),
      recentFiles: newFiles
          .where((f) => !f.isPinned)
          .toList()
        ..sort((a, b) => b.lastOpened.compareTo(a.lastOpened)),
    );
  }

  List<VaultFileModel> get pinnedFiles => _pinnedFiles;
  List<VaultFileModel> get recentFiles => _recentFiles;

  /// Get files filtered by current folder and search query
  List<VaultFileModel> get filteredFiles {
    var result = files.toList();

    // Filter by folder
    if (currentFolder != null) {
      result = result.where((f) => f.folder == currentFolder).toList();
    }

    // Filter by search query
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      result = result.where((f) =>
        f.displayTitle.toLowerCase().contains(query) ||
        f.name.toLowerCase().contains(query)
      ).toList();
    }

    // Sort by last opened
    result.sort((a, b) => b.lastOpened.compareTo(a.lastOpened));
    return result;
  }

  /// Get folders with file counts
  List<VaultFolderModel> get foldersWithCounts {
    return folders.map((folder) {
      final count = files.where((f) => f.folder == folder.name).length;
      return folder.copyWith(fileCount: count);
    }).toList();
  }

  /// Get uncategorized files count
  int get uncategorizedCount => files.where((f) => f.folder == null).length;
}

class VaultNotifier extends StateNotifier<VaultState> {
  final DocumentNotifier documentNotifier;
  final FileNotifier fileNotifier;

  VaultNotifier(this.documentNotifier, this.fileNotifier) : super(VaultState()) {
    _initializeVault();
  }

  Future<void> _initializeVault() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final vaultDir = Directory('${appDir.path}/CodeMD');
      
      if (!await vaultDir.exists()) {
        await vaultDir.create(recursive: true);
      }

      state = state.copyWith(vaultPath: vaultDir.path);
      await _loadVault();
    } catch (e) {
      state = state.copyWith(error: 'Failed to initialize vault: $e');
    }
  }

  Future<void> _loadVault() async {
    try {
      state = state.copyWith(isLoading: true);

      final appDir = await getApplicationDocumentsDirectory();
      final vaultFile = File('${appDir.path}/CodeMD/vault.json');

      List<VaultFileModel> files = [];
      List<VaultFolderModel> folders = [];

      if (await vaultFile.exists()) {
        final content = await vaultFile.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;

        if (data['files'] != null) {
          files = (data['files'] as List)
              .map((f) => VaultFileModel.fromJson(f as Map<String, dynamic>))
              .where((f) => File(f.path).existsSync()) // Only keep existing files
              .toList();
        }

        if (data['folders'] != null) {
          folders = (data['folders'] as List)
              .map((f) => VaultFolderModel.fromJson(f as Map<String, dynamic>))
              .toList();
        }
      }

      state = state.copyWith(files: files, folders: folders, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load vault: $e',
      );
    }
  }

  Future<void> _saveVault() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final vaultFile = File('${appDir.path}/CodeMD/vault.json');

      final data = {
        'files': state.files.map((f) => f.toJson()).toList(),
        'folders': state.folders.map((f) => f.toJson()).toList(),
        'lastUpdated': DateTime.now().toIso8601String(),
      };

      await vaultFile.writeAsString(jsonEncode(data));
    } catch (e) {
      state = state.copyWith(error: 'Failed to save vault: $e');
    }
  }

  Future<void> addFile(String filePath, {String? title}) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return;

      // Remove existing entry if any
      final updatedFiles = state.files.where((f) => f.path != filePath).toList();
      
      // Add new entry
      final vaultFile = await VaultFileModel.fromFile(file, title: title);
      updatedFiles.insert(0, vaultFile);
      
      state = state.copyWith(files: updatedFiles);
      await _saveVault();
    } catch (e) {
      state = state.copyWith(error: 'Failed to add file to vault: $e');
    }
  }

  Future<void> removeFile(String filePath) async {
    final updatedFiles = state.files.where((f) => f.path != filePath).toList();
    state = state.copyWith(files: updatedFiles);
    await _saveVault();
  }

  Future<void> togglePin(String filePath) async {
    final updatedFiles = state.files.map((f) {
      if (f.path == filePath) {
        return f.copyWith(isPinned: !f.isPinned);
      }
      return f;
    }).toList();
    
    state = state.copyWith(files: updatedFiles);
    await _saveVault();
  }

  Future<void> updateLastOpened(String filePath) async {
    final updatedFiles = state.files.map((f) {
      if (f.path == filePath) {
        return f.copyWith(lastOpened: DateTime.now());
      }
      return f;
    }).toList();
    
    state = state.copyWith(files: updatedFiles);
    await _saveVault();
  }

  Future<void> openFile(String filePath) async {
    try {
      // Load file first, then update timestamp silently to avoid UI flicker
      await fileNotifier.loadRecentFile(filePath);
      // Update timestamp in background without triggering immediate UI update
      await _updateLastOpenedSilently(filePath);
    } catch (e) {
      state = state.copyWith(error: 'Failed to open file: $e');
    }
  }

  Future<void> _updateLastOpenedSilently(String filePath) async {
    // Update timestamp without immediately triggering state change
    final updatedFiles = state.files.map((f) {
      if (f.path == filePath) {
        return f.copyWith(lastOpened: DateTime.now());
      }
      return f;
    }).toList();
    
    // Save to disk but delay state update to prevent rebuild loops
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final vaultFile = File('${appDir.path}/CodeMD/vault.json');
      
      final data = {
        'files': updatedFiles.map((f) => f.toJson()).toList(),
        'lastUpdated': DateTime.now().toIso8601String(),
      };
      
      await vaultFile.writeAsString(jsonEncode(data));
      
      // Delay state update to break rebuild cycles
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Only update if we're still mounted and no other operations are in progress
      if (mounted) {
        state = state.copyWith(files: updatedFiles);
      }
    } catch (e) {
      // Silent error - don't update state on error to avoid rebuild loops
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  // Folder management
  Future<void> createFolder(String name, {String? icon}) async {
    if (state.folders.any((f) => f.name == name)) return;

    final newFolder = VaultFolderModel(name: name, icon: icon);
    final updatedFolders = [...state.folders, newFolder];
    state = state.copyWith(folders: updatedFolders);
    await _saveVault();
  }

  Future<void> deleteFolder(String name) async {
    // Move files in this folder to uncategorized
    final updatedFiles = state.files.map((f) {
      if (f.folder == name) {
        return f.copyWith(clearFolder: true);
      }
      return f;
    }).toList();

    final updatedFolders = state.folders.where((f) => f.name != name).toList();
    state = state.copyWith(files: updatedFiles, folders: updatedFolders);
    await _saveVault();
  }

  Future<void> renameFolder(String oldName, String newName) async {
    if (state.folders.any((f) => f.name == newName)) return;

    // Update folder name
    final updatedFolders = state.folders.map((f) {
      if (f.name == oldName) {
        return f.copyWith(name: newName);
      }
      return f;
    }).toList();

    // Update files in this folder
    final updatedFiles = state.files.map((f) {
      if (f.folder == oldName) {
        return f.copyWith(folder: newName);
      }
      return f;
    }).toList();

    state = state.copyWith(files: updatedFiles, folders: updatedFolders);
    await _saveVault();
  }

  Future<void> moveFileToFolder(String filePath, String? folderName) async {
    final updatedFiles = state.files.map((f) {
      if (f.path == filePath) {
        return f.copyWith(folder: folderName, clearFolder: folderName == null);
      }
      return f;
    }).toList();

    state = state.copyWith(files: updatedFiles);
    await _saveVault();
  }

  // Navigation
  void setCurrentFolder(String? folderName) {
    state = state.copyWith(currentFolder: folderName, clearCurrentFolder: folderName == null);
  }

  // Search
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void clearSearch() {
    state = state.copyWith(searchQuery: '');
  }
}

final vaultProvider = StateNotifierProvider<VaultNotifier, VaultState>((ref) {
  final documentNotifier = ref.watch(documentProvider.notifier);
  final fileNotifier = ref.watch(fileProvider.notifier);
  return VaultNotifier(documentNotifier, fileNotifier);
});