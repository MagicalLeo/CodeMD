import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../data/models/vault_model.dart';
import 'document_provider.dart';
import 'file_provider.dart';

class VaultState {
  final List<VaultFileModel> files;
  final bool isLoading;
  final String? error;
  final String? vaultPath;

  const VaultState({
    this.files = const [],
    this.isLoading = false,
    this.error,
    this.vaultPath,
  });

  VaultState copyWith({
    List<VaultFileModel>? files,
    bool? isLoading,
    String? error,
    String? vaultPath,
  }) {
    return VaultState(
      files: files ?? this.files,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      vaultPath: vaultPath ?? this.vaultPath,
    );
  }

  List<VaultFileModel> get pinnedFiles => files.where((f) => f.isPinned).toList();
  List<VaultFileModel> get recentFiles => files
      .where((f) => !f.isPinned)
      .toList()
    ..sort((a, b) => b.lastOpened.compareTo(a.lastOpened));
}

class VaultNotifier extends StateNotifier<VaultState> {
  final DocumentNotifier documentNotifier;
  final FileNotifier fileNotifier;

  VaultNotifier(this.documentNotifier, this.fileNotifier) : super(const VaultState()) {
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
      
      if (await vaultFile.exists()) {
        final content = await vaultFile.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        
        if (data['files'] != null) {
          files = (data['files'] as List)
              .map((f) => VaultFileModel.fromJson(f as Map<String, dynamic>))
              .where((f) => File(f.path).existsSync()) // Only keep existing files
              .toList();
        }
      }

      state = state.copyWith(files: files, isLoading: false);
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
      await updateLastOpened(filePath);
      await fileNotifier.loadRecentFile(filePath);
    } catch (e) {
      state = state.copyWith(error: 'Failed to open file: $e');
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final vaultProvider = StateNotifierProvider<VaultNotifier, VaultState>((ref) {
  final documentNotifier = ref.watch(documentProvider.notifier);
  final fileNotifier = ref.watch(fileProvider.notifier);
  return VaultNotifier(documentNotifier, fileNotifier);
});