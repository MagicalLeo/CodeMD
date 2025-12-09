import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/models/block_model.dart';

class EditableBlock extends StatefulWidget {
  final BlockModel block;
  final bool isFocused;
  final Function(String) onChanged;
  final Function(BlockType) onTypeChanged;
  final VoidCallback onSubmitted;
  final VoidCallback onDelete;

  const EditableBlock({
    super.key,
    required this.block,
    required this.isFocused,
    required this.onChanged,
    required this.onTypeChanged,
    required this.onSubmitted,
    required this.onDelete,
  });

  @override
  State<EditableBlock> createState() => _EditableBlockState();
}

class _EditableBlockState extends State<EditableBlock> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _isComposing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.block.content);
    _focusNode = FocusNode();
    
    _controller.addListener(() {
      if (!_isComposing) {
        widget.onChanged(_controller.text);
      }
    });
  }

  @override
  void didUpdateWidget(EditableBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.block.content != widget.block.content &&
        _controller.text != widget.block.content) {
      _controller.text = widget.block.content;
    }
    
    if (widget.isFocused && !_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      // Handle special key combinations
      if (event.isControlPressed || event.isMetaPressed) {
        switch (event.logicalKey) {
          case LogicalKeyboardKey.keyB:
            // Bold formatting
            _wrapSelection('**');
            break;
          case LogicalKeyboardKey.keyI:
            // Italic formatting
            _wrapSelection('*');
            break;
          case LogicalKeyboardKey.keyK:
            // Link insertion
            _insertLink();
            break;
        }
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (event.isShiftPressed) {
          // Shift+Enter: Insert line break
          _insertAtCursor('\n');
        } else {
          // Enter: Create new block
          widget.onSubmitted();
        }
      } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
        if (_controller.text.isEmpty) {
          // Delete empty block
          widget.onDelete();
        }
      } else if (event.logicalKey == LogicalKeyboardKey.tab) {
        if (event.isShiftPressed) {
          // Shift+Tab: Outdent
          // This is handled by the parent widget
        } else {
          // Tab: Indent or insert tab
          _insertAtCursor('  ');
        }
      }
    }
  }

  void _wrapSelection(String wrapper) {
    final selection = _controller.selection;
    if (selection.isValid && !selection.isCollapsed) {
      final text = _controller.text;
      final selectedText = text.substring(selection.start, selection.end);
      final newText = text.replaceRange(
        selection.start,
        selection.end,
        '$wrapper$selectedText$wrapper',
      );
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: selection.end + wrapper.length * 2,
        ),
      );
    }
  }

  void _insertAtCursor(String text) {
    final selection = _controller.selection;
    final currentText = _controller.text;
    final newText = currentText.replaceRange(
      selection.start,
      selection.end,
      text,
    );
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + text.length,
      ),
    );
  }

  void _insertLink() {
    final selection = _controller.selection;
    if (selection.isValid && !selection.isCollapsed) {
      final text = _controller.text;
      final selectedText = text.substring(selection.start, selection.end);
      final newText = text.replaceRange(
        selection.start,
        selection.end,
        '[$selectedText](url)',
      );
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: selection.end + 3,
          extentOffset: selection.end + 6,
        ),
      );
    }
  }

  TextStyle _getTextStyle(BuildContext context) {
    switch (widget.block.type) {
      case BlockType.heading1:
        return Theme.of(context).textTheme.displaySmall!;
      case BlockType.heading2:
        return Theme.of(context).textTheme.headlineLarge!;
      case BlockType.heading3:
        return Theme.of(context).textTheme.headlineMedium!;
      case BlockType.heading4:
        return Theme.of(context).textTheme.headlineSmall!;
      case BlockType.heading5:
      case BlockType.heading6:
        return Theme.of(context).textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.bold,
            );
      case BlockType.code:
      case BlockType.mermaid:
        return const TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
        );
      case BlockType.blockquote:
        return Theme.of(context).textTheme.bodyLarge!.copyWith(
              fontStyle: FontStyle.italic,
            );
      default:
        return Theme.of(context).textTheme.bodyLarge!;
    }
  }

  Widget _buildPrefix() {
    switch (widget.block.type) {
      case BlockType.bulletList:
        return const Padding(
          padding: EdgeInsets.only(right: 8.0),
          child: Text('•', style: TextStyle(fontSize: 16)),
        );
      case BlockType.numberedList:
        final order = widget.block.metadata['order'] ?? 1;
        return Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Text('$order.', style: const TextStyle(fontSize: 16)),
        );
      case BlockType.taskList:
        final isChecked = widget.block.metadata['checked'] ?? false;
        return Checkbox(
          value: isChecked,
          onChanged: (value) {
            // TODO: Update task checked state
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCodeBlock = widget.block.type == BlockType.code || 
                       widget.block.type == BlockType.mermaid;

    return RawKeyboardListener(
      focusNode: FocusNode(),
      onKey: _handleKeyEvent,
      child: Container(
        decoration: BoxDecoration(
          color: widget.isFocused 
              ? Theme.of(context).colorScheme.surface
              : null,
          borderRadius: BorderRadius.circular(4),
          border: widget.isFocused
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  width: 1,
                )
              : null,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isCodeBlock ? 12 : 4,
          vertical: isCodeBlock ? 8 : 2,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPrefix(),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: _getTextStyle(context),
                decoration: InputDecoration(
                  hintText: _getPlaceholder(),
                  hintStyle: _getTextStyle(context).copyWith(
                    color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.3),
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
                maxLines: isCodeBlock ? null : null,
                minLines: isCodeBlock ? 3 : 1,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                onChanged: (text) {
                  // Check for markdown shortcuts
                  _checkMarkdownShortcuts(text);
                },
                onSubmitted: (_) {
                  if (!isCodeBlock) {
                    widget.onSubmitted();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPlaceholder() {
    switch (widget.block.type) {
      case BlockType.heading1:
        return 'Heading 1';
      case BlockType.heading2:
        return 'Heading 2';
      case BlockType.heading3:
        return 'Heading 3';
      case BlockType.heading4:
        return 'Heading 4';
      case BlockType.heading5:
      case BlockType.heading6:
        return 'Heading';
      case BlockType.code:
        return 'Enter code...';
      case BlockType.mermaid:
        return 'Enter Mermaid diagram...';
      case BlockType.blockquote:
        return 'Quote...';
      case BlockType.bulletList:
        return 'List item';
      case BlockType.numberedList:
        return 'List item';
      case BlockType.taskList:
        return 'Task...';
      default:
        return 'Type / for commands';
    }
  }

  void _checkMarkdownShortcuts(String text) {
    if (text.isEmpty) return;

    // Check for markdown shortcuts at the beginning of the line
    if (widget.block.type == BlockType.paragraph) {
      if (text.startsWith('# ')) {
        widget.onTypeChanged(BlockType.heading1);
        _controller.text = text.substring(2);
      } else if (text.startsWith('## ')) {
        widget.onTypeChanged(BlockType.heading2);
        _controller.text = text.substring(3);
      } else if (text.startsWith('### ')) {
        widget.onTypeChanged(BlockType.heading3);
        _controller.text = text.substring(4);
      } else if (text.startsWith('- ') || text.startsWith('* ')) {
        widget.onTypeChanged(BlockType.bulletList);
        _controller.text = text.substring(2);
      } else if (text.startsWith('1. ')) {
        widget.onTypeChanged(BlockType.numberedList);
        _controller.text = text.substring(3);
      } else if (text.startsWith('- [ ] ')) {
        widget.onTypeChanged(BlockType.taskList);
        _controller.text = text.substring(6);
      } else if (text.startsWith('> ')) {
        widget.onTypeChanged(BlockType.blockquote);
        _controller.text = text.substring(2);
      } else if (text.startsWith('```')) {
        widget.onTypeChanged(BlockType.code);
        _controller.text = '';
      }
    }
  }
}