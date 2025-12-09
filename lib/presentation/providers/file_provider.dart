import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../data/models/document_model.dart';
import 'document_provider.dart';

class FileState {
  final bool isLoading;
  final String? error;
  final String? lastOpenedPath;
  final List<String> recentFiles;

  const FileState({
    this.isLoading = false,
    this.error,
    this.lastOpenedPath,
    this.recentFiles = const [],
  });

  FileState copyWith({
    bool? isLoading,
    String? error,
    String? lastOpenedPath,
    List<String>? recentFiles,
  }) {
    return FileState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      lastOpenedPath: lastOpenedPath ?? this.lastOpenedPath,
      recentFiles: recentFiles ?? this.recentFiles,
    );
  }
}

class FileNotifier extends StateNotifier<FileState> {
  final DocumentNotifier documentNotifier;

  FileNotifier(this.documentNotifier) : super(const FileState());

  Future<void> pickAndLoadFile() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['md', 'markdown', 'txt'],
        withData: false,
        withReadStream: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        
        // Web/bytes path
        if (kIsWeb && file.bytes != null) {
          final content = utf8.decode(file.bytes!);
          final fileName = file.name;
          final title = fileName.replaceAll(RegExp(r'\.(md|markdown|txt)$'), '');

          documentNotifier.loadMarkdown(content, title: title, filePath: null);

          state = state.copyWith(
            isLoading: false,
            lastOpenedPath: null,
          );
          return;
        }

        if (file.path != null) {
          await _loadFileFromPath(file.path!);
        } else {
          state = state.copyWith(isLoading: false, error: 'Selected file has no path/bytes');
        }
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to pick file: $e',
      );
    }
  }

  Future<void> _loadFileFromPath(String filePath) async {
    try {
      final file = File(filePath);
      final fileSize = await file.length();
      
      // Use Isolate for files >1MB to prevent UI blocking
      String content;
      if (fileSize > 1024 * 1024 && !kIsWeb) {
        content = await compute(_readFileSafely, filePath);
      } else {
        content = await file.readAsString();
      }

      final fileName = filePath.split(Platform.pathSeparator).last;
      final title = fileName.replaceAll(RegExp(r'\.(md|markdown|txt)$'), '');

      documentNotifier.loadMarkdown(content, title: title, filePath: filePath);
      
      final updatedRecentFiles = [
        filePath,
        ...state.recentFiles.where((path) => path != filePath),
      ].take(10).toList();

      state = state.copyWith(
        isLoading: false,
        lastOpenedPath: filePath,
        recentFiles: updatedRecentFiles,
      );

    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load file: $e',
      );
    }
  }

  Future<void> loadRecentFile(String filePath) async {
    await _loadFileFromPath(filePath);
  }

  Future<void> saveCurrentDocument() async {
    try {
      final currentDocument = documentNotifier.state.currentDocument;
      if (currentDocument == null) return;

      String? filePath = currentDocument.filePath;

      if (filePath == null) {
        // Save As dialog
        final result = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Markdown file',
          fileName: '${currentDocument.title}.md',
          type: FileType.custom,
          allowedExtensions: ['md'],
        );
        
        if (result == null) return;
        filePath = result;
      }

      final markdownContent = currentDocument.toMarkdown();
      final file = File(filePath);
      await file.writeAsString(markdownContent);

      state = state.copyWith(lastOpenedPath: filePath);
      
      // Update document with file path if it was a new file
      if (currentDocument.filePath == null) {
        final updatedDocument = currentDocument.copyWith(filePath: filePath);
        // Update document provider with file path
      }

    } catch (e) {
      state = state.copyWith(error: 'Failed to save file: $e');
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// Isolate function for reading large files
String _readFileSafely(String filePath) {
  final file = File(filePath);
  return file.readAsStringSync();
}

final fileProvider = StateNotifierProvider<FileNotifier, FileState>((ref) {
  final documentNotifier = ref.watch(documentProvider.notifier);
  return FileNotifier(documentNotifier);
});
