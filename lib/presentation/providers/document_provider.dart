import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/document_model.dart';
import '../../data/models/block_model.dart';
import '../../core/parser/markdown_parser.dart';

class DocumentState {
  final DocumentModel? currentDocument;
  final bool isLoading;
  final bool isEditMode;
  final String? error;
  final Set<String> selectedBlockIds;

  const DocumentState({
    this.currentDocument,
    this.isLoading = false,
    this.isEditMode = false,
    this.error,
    this.selectedBlockIds = const {},
  });

  DocumentState copyWith({
    DocumentModel? currentDocument,
    bool? isLoading,
    bool? isEditMode,
    String? error,
    Set<String>? selectedBlockIds,
  }) {
    return DocumentState(
      currentDocument: currentDocument ?? this.currentDocument,
      isLoading: isLoading ?? this.isLoading,
      isEditMode: isEditMode ?? this.isEditMode,
      error: error ?? this.error,
      selectedBlockIds: selectedBlockIds ?? this.selectedBlockIds,
    );
  }
}

class DocumentNotifier extends StateNotifier<DocumentState> {
  DocumentNotifier() : super(const DocumentState());

  Future<void> loadFromFile(String filePath) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final file = File(filePath);
      final content = await file.readAsString();
      final fileName = filePath.split(Platform.pathSeparator).last;
      final title = fileName.replaceAll(RegExp(r'\.(md|markdown|txt)$'), '');

      final blocks = MarkdownParser.parseMarkdown(content);
      final document = DocumentModel(
        title: title.isEmpty ? 'Untitled' : title,
        blocks: blocks,
        filePath: filePath,
      );

      state = state.copyWith(
        currentDocument: document,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void loadMarkdown(String markdown, {String? title, String? filePath}) {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final blocks = MarkdownParser.parseMarkdown(markdown);
      final document = DocumentModel(
        title: title ?? 'Untitled',
        blocks: blocks,
        filePath: filePath,
      );
      
      state = state.copyWith(
        currentDocument: document,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void createNewDocument() {
    final document = DocumentModel(
      title: 'Untitled',
      blocks: [
        BlockModel(
          type: BlockType.paragraph,
          content: '',
        ),
      ],
    );
    
    state = state.copyWith(
      currentDocument: document,
      isEditMode: true,
    );
  }

  void toggleEditMode() {
    state = state.copyWith(isEditMode: !state.isEditMode);
  }

  void updateBlock(String blockId, String content) {
    if (state.currentDocument == null) return;
    
    final blocks = state.currentDocument!.blocks.map((block) {
      if (block.id == blockId) {
        return block.copyWith(content: content);
      }
      return block;
    }).toList();
    
    state = state.copyWith(
      currentDocument: state.currentDocument!.copyWith(blocks: blocks),
    );
  }

  void updateBlockType(String blockId, BlockType type) {
    if (state.currentDocument == null) return;
    
    final blocks = state.currentDocument!.blocks.map((block) {
      if (block.id == blockId) {
        return block.copyWith(type: type);
      }
      return block;
    }).toList();
    
    state = state.copyWith(
      currentDocument: state.currentDocument!.copyWith(blocks: blocks),
    );
  }

  void insertBlockAfter(String blockId) {
    if (state.currentDocument == null) return;
    
    final blocks = <BlockModel>[];
    for (int i = 0; i < state.currentDocument!.blocks.length; i++) {
      blocks.add(state.currentDocument!.blocks[i]);
      if (state.currentDocument!.blocks[i].id == blockId) {
        blocks.add(BlockModel(
          type: BlockType.paragraph,
          content: '',
          indentLevel: state.currentDocument!.blocks[i].indentLevel,
        ));
      }
    }
    
    state = state.copyWith(
      currentDocument: state.currentDocument!.copyWith(blocks: blocks),
    );
  }

  void deleteBlock(String blockId) {
    if (state.currentDocument == null) return;
    
    final blocks = state.currentDocument!.blocks
        .where((block) => block.id != blockId)
        .toList();
    
    // Ensure at least one block remains
    if (blocks.isEmpty) {
      blocks.add(BlockModel(
        type: BlockType.paragraph,
        content: '',
      ));
    }
    
    state = state.copyWith(
      currentDocument: state.currentDocument!.copyWith(blocks: blocks),
    );
  }

  void moveBlockUp(String blockId) {
    if (state.currentDocument == null) return;
    
    final index = state.currentDocument!.blocks
        .indexWhere((block) => block.id == blockId);
    
    if (index > 0) {
      final blocks = List<BlockModel>.from(state.currentDocument!.blocks);
      final temp = blocks[index];
      blocks[index] = blocks[index - 1];
      blocks[index - 1] = temp;
      
      state = state.copyWith(
        currentDocument: state.currentDocument!.copyWith(blocks: blocks),
      );
    }
  }

  void moveBlockDown(String blockId) {
    if (state.currentDocument == null) return;
    
    final index = state.currentDocument!.blocks
        .indexWhere((block) => block.id == blockId);
    
    if (index >= 0 && index < state.currentDocument!.blocks.length - 1) {
      final blocks = List<BlockModel>.from(state.currentDocument!.blocks);
      final temp = blocks[index];
      blocks[index] = blocks[index + 1];
      blocks[index + 1] = temp;
      
      state = state.copyWith(
        currentDocument: state.currentDocument!.copyWith(blocks: blocks),
      );
    }
  }

  void indentBlock(String blockId) {
    if (state.currentDocument == null) return;
    
    final blocks = state.currentDocument!.blocks.map((block) {
      if (block.id == blockId && block.indentLevel < 5) {
        return block.copyWith(indentLevel: block.indentLevel + 1);
      }
      return block;
    }).toList();
    
    state = state.copyWith(
      currentDocument: state.currentDocument!.copyWith(blocks: blocks),
    );
  }

  void outdentBlock(String blockId) {
    if (state.currentDocument == null) return;
    
    final blocks = state.currentDocument!.blocks.map((block) {
      if (block.id == blockId && block.indentLevel > 0) {
        return block.copyWith(indentLevel: block.indentLevel - 1);
      }
      return block;
    }).toList();
    
    state = state.copyWith(
      currentDocument: state.currentDocument!.copyWith(blocks: blocks),
    );
  }

  void toggleBlockSelection(String blockId) {
    final selectedIds = Set<String>.from(state.selectedBlockIds);
    if (selectedIds.contains(blockId)) {
      selectedIds.remove(blockId);
    } else {
      selectedIds.add(blockId);
    }
    
    state = state.copyWith(selectedBlockIds: selectedIds);
  }

  void clearSelection() {
    state = state.copyWith(selectedBlockIds: {});
  }

  void applyFormatting(String blockId, String formatType, {String? value}) {
    if (state.currentDocument == null) return;
    
    final blocks = state.currentDocument!.blocks.map((block) {
      if (block.id == blockId) {
        String newContent = block.content;
        
        switch (formatType) {
          case 'bold':
            if (newContent.isNotEmpty) {
              // Toggle bold formatting - remove if already bold
              if (newContent.startsWith('**') && newContent.endsWith('**')) {
                newContent = newContent.substring(2, newContent.length - 2);
              } else {
                newContent = '**$newContent**';
              }
            } else {
              newContent = '**Bold text**';
            }
            break;
          case 'italic':
            if (newContent.isNotEmpty) {
              // Toggle italic formatting
              if (newContent.startsWith('*') && newContent.endsWith('*') && 
                  !newContent.startsWith('**')) {
                newContent = newContent.substring(1, newContent.length - 1);
              } else {
                newContent = '*$newContent*';
              }
            } else {
              newContent = '*Italic text*';
            }
            break;
          case 'code':
            if (newContent.isNotEmpty) {
              // Toggle code formatting
              if (newContent.startsWith('`') && newContent.endsWith('`')) {
                newContent = newContent.substring(1, newContent.length - 1);
              } else {
                newContent = '`$newContent`';
              }
            } else {
              newContent = '`code`';
            }
            break;
          case 'link':
            if (value != null) {
              if (newContent.isEmpty) {
                newContent = '[Link text]($value)';
              } else {
                newContent = '[$newContent]($value)';
              }
            }
            break;
        }
        
        return block.copyWith(content: newContent);
      }
      return block;
    }).toList();
    
    state = state.copyWith(
      currentDocument: state.currentDocument!.copyWith(blocks: blocks),
    );
  }

  void convertToList(String blockId, {bool isNumbered = false, bool isTask = false}) {
    if (state.currentDocument == null) return;
    
    final blocks = state.currentDocument!.blocks.map((block) {
      if (block.id == blockId) {
        BlockType newType;
        String newContent = block.content;
        
        if (isTask) {
          newType = BlockType.taskList;
          if (!newContent.startsWith('- [ ] ') && !newContent.startsWith('- [x] ')) {
            newContent = '- [ ] $newContent';
          }
        } else if (isNumbered) {
          newType = BlockType.numberedList;
          if (!RegExp(r'^\d+\.\s').hasMatch(newContent)) {
            newContent = '1. $newContent';
          }
        } else {
          newType = BlockType.bulletList;
          if (!newContent.startsWith('- ')) {
            newContent = '- $newContent';
          }
        }
        
        return block.copyWith(type: newType, content: newContent);
      }
      return block;
    }).toList();
    
    state = state.copyWith(
      currentDocument: state.currentDocument!.copyWith(blocks: blocks),
    );
  }

  void insertImage(String blockId, String imageUrl) {
    if (state.currentDocument == null) return;
    
    final blocks = <BlockModel>[];
    for (int i = 0; i < state.currentDocument!.blocks.length; i++) {
      blocks.add(state.currentDocument!.blocks[i]);
      if (state.currentDocument!.blocks[i].id == blockId) {
        blocks.add(BlockModel(
          type: BlockType.image,
          content: imageUrl,
          indentLevel: state.currentDocument!.blocks[i].indentLevel,
        ));
      }
    }
    
    state = state.copyWith(
      currentDocument: state.currentDocument!.copyWith(blocks: blocks),
    );
  }

  void toggleTaskStatus(String blockId) {
    if (state.currentDocument == null) return;
    
    final blocks = state.currentDocument!.blocks.map((block) {
      if (block.id == blockId && block.type == BlockType.taskList) {
        final currentChecked = block.metadata['checked'] == true ||
            block.content.contains('[x]') ||
            block.content.contains('[X]');
        final newChecked = !currentChecked;

        final cleanedContent = block.content
            .replaceAll('- [ ] ', '')
            .replaceAll('- [x] ', '')
            .replaceAll('- [X] ', '')
            .replaceAll('* [ ] ', '')
            .replaceAll('* [x] ', '')
            .replaceAll('* [X] ', '')
            .replaceAll('[ ] ', '')
            .replaceAll('[x] ', '')
            .replaceAll('[X] ', '')
            .trim();

        final newMetadata = Map<String, dynamic>.from(block.metadata)
          ..['checked'] = newChecked;

        return block.copyWith(
          content: cleanedContent,
          metadata: newMetadata,
        );
      }
      return block;
    }).toList();
    
    state = state.copyWith(
      currentDocument: state.currentDocument!.copyWith(blocks: blocks),
    );
  }

  String? getCurrentFocusedBlockId() {
    return state.selectedBlockIds.isNotEmpty ? state.selectedBlockIds.first : null;
  }

  void handleShortcutInput(String blockId, String input) {
    if (state.currentDocument == null) return;
    
    // Auto-formatting based on Markdown shortcuts (Obsidian/Notion style)
    final shortcuts = {
      '# ': BlockType.heading1,
      '## ': BlockType.heading2,
      '### ': BlockType.heading3,
      '- ': BlockType.bulletList,
      '* ': BlockType.bulletList,
      '1. ': BlockType.numberedList,
      '- [ ] ': BlockType.taskList,
      '- [x] ': BlockType.taskList,
      '> ': BlockType.blockquote,
      '``` ': BlockType.code,
    };

    for (final shortcut in shortcuts.keys) {
      if (input.startsWith(shortcut)) {
        final newType = shortcuts[shortcut]!;
        final content = input.substring(shortcut.length);
        
        updateBlockType(blockId, newType);
        updateBlock(blockId, content);
        return;
      }
    }

    // If no shortcuts match, just update content normally
    updateBlock(blockId, input);
  }

  void addQuickInsert(String blockId, String type) {
    if (state.currentDocument == null) return;
    
    final templates = {
      'table': '| Header 1 | Header 2 | Header 3 |\n| --- | --- | --- |\n| Cell 1 | Cell 2 | Cell 3 |',
      'divider': '---',
      'quote': '> A meaningful quote',
      'codeblock': '```javascript\n// Your code here\nconsole.log("Hello World");\n```',
      'checklist': '- [ ] Task 1\n- [ ] Task 2\n- [ ] Task 3',
      'flowchart': 'graph TD\n    A[Start] --> B{Is it?}\n    B -->|Yes| C[OK]\n    C --> D[Rethink]\n    D --> B\n    B ---->|No| E[End]',
      'sequence': 'sequenceDiagram\n    participant Alice\n    participant Bob\n    Alice->>John: Hello John, how are you?\n    loop Healthcheck\n        John->>John: Fight against hypochondria\n    end\n    Note right of John: Rational thoughts <br/>prevail!\n    John-->>Alice: Great!\n    John->>Bob: How about you?\n    Bob-->>John: Jolly good!',
    };

    if (templates.containsKey(type)) {
      updateBlock(blockId, templates[type]!);
      
      // Auto-detect type based on content
      switch (type) {
        case 'table':
          updateBlockType(blockId, BlockType.table);
          break;
        case 'divider':
          updateBlockType(blockId, BlockType.horizontalRule);
          break;
        case 'quote':
          updateBlockType(blockId, BlockType.blockquote);
          break;
        case 'codeblock':
          updateBlockType(blockId, BlockType.code);
          break;
        case 'checklist':
          updateBlockType(blockId, BlockType.taskList);
          break;
        case 'flowchart':
        case 'sequence':
          updateBlockType(blockId, BlockType.mermaid);
          break;
      }
    }
  }

  String exportToMarkdown() {
    if (state.currentDocument == null) return '';
    return state.currentDocument!.toMarkdown();
  }
}

final documentProvider = StateNotifierProvider<DocumentNotifier, DocumentState>(
  (ref) => DocumentNotifier(),
);
