import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../../data/models/block_model.dart';
import '../../core/services/reading_position_service.dart';
import '../providers/document_provider.dart';
import 'blocks/view_only_block.dart';
import 'blocks/editable_block.dart';

class BlockList extends ConsumerStatefulWidget {
  final List<BlockModel> blocks;
  final bool isEditMode;
  final Function(String)? onBlockFocused;
  final String? filePath;

  const BlockList({
    super.key,
    required this.blocks,
    required this.isEditMode,
    this.onBlockFocused,
    this.filePath,
  });

  @override
  ConsumerState<BlockList> createState() => _BlockListState();
}

class _BlockListState extends ConsumerState<BlockList> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();

  final Map<String, GlobalKey> _blockKeys = {};
  String? _focusedBlockId;
  Timer? _savePositionTimer;
  bool _hasRestoredPosition = false;

  // For custom scrollbar
  double _scrollProgress = 0.0;
  bool _isDraggingScrollbar = false;

  @override
  void initState() {
    super.initState();
    _itemPositionsListener.itemPositions.addListener(_onPositionChanged);

    // Restore position after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreReadingPosition();
    });
  }

  @override
  void didUpdateWidget(BlockList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _hasRestoredPosition = false;
      _scrollProgress = 0.0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _restoreReadingPosition();
      });
    }
  }

  @override
  void dispose() {
    _savePositionTimer?.cancel();
    _saveCurrentPosition();
    _itemPositionsListener.itemPositions.removeListener(_onPositionChanged);
    super.dispose();
  }

  void _onPositionChanged() {
    if (_isDraggingScrollbar) return;

    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty || widget.blocks.isEmpty) return;

    // Calculate scroll progress based on visible items
    final sortedPositions = positions.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    final firstVisible = sortedPositions.first;
    final progress = (firstVisible.index + (1 - firstVisible.itemLeadingEdge)) / widget.blocks.length;

    setState(() {
      _scrollProgress = progress.clamp(0.0, 1.0);
    });

    // Debounce position saving
    _savePositionTimer?.cancel();
    _savePositionTimer = Timer(const Duration(milliseconds: 1500), () {
      _saveCurrentPosition();
    });
  }

  Future<void> _saveCurrentPosition() async {
    if (widget.filePath == null) return;

    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;

    final sortedPositions = positions.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    final firstVisible = sortedPositions.first;
    await ReadingPositionService.savePosition(
      widget.filePath!,
      firstVisible.index,
      firstVisible.itemLeadingEdge,
    );
  }

  Future<void> _restoreReadingPosition() async {
    if (widget.filePath == null || _hasRestoredPosition) return;
    _hasRestoredPosition = true;

    final position = await ReadingPositionService.getPosition(widget.filePath!);
    if (position == null || !mounted) return;

    final (blockIndex, alignment) = position;
    if (blockIndex >= widget.blocks.length) return;

    // Wait a bit for the list to be ready
    await Future.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;

    _itemScrollController.jumpTo(
      index: blockIndex,
      alignment: alignment.clamp(0.0, 0.5),
    );
  }

  void _onScrollbarDrag(double progress) {
    if (widget.blocks.isEmpty) return;

    final targetIndex = (progress * widget.blocks.length).floor().clamp(0, widget.blocks.length - 1);

    _itemScrollController.jumpTo(index: targetIndex);

    setState(() {
      _scrollProgress = progress;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.blocks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.note_add,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Start writing...',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.5),
                  ),
            ),
          ],
        ),
      );
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // Main list
        ScrollablePositionedList.builder(
          itemCount: widget.blocks.length,
          itemScrollController: _itemScrollController,
          itemPositionsListener: _itemPositionsListener,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemBuilder: (context, index) {
            final block = widget.blocks[index];
            return RepaintBoundary(
              key: ValueKey(block.id),
              child: Padding(
                padding: EdgeInsets.only(
                  left: block.indentLevel * 24.0,
                  bottom: 2.0,
                ),
                child: ViewOnlyBlock(block: block),
              ),
            );
          },
        ),
        // Custom scrollbar - larger touch target
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: _buildScrollbar(isDarkMode),
        ),
      ],
    );
  }

  Widget _buildScrollbar(bool isDarkMode) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportHeight = constraints.maxHeight;
        if (viewportHeight <= 0) return const SizedBox.shrink();

        // Thumb size proportional to visible content
        final thumbHeight = (viewportHeight * 0.15).clamp(50.0, 120.0);
        final trackHeight = viewportHeight - thumbHeight;
        final thumbTop = (_scrollProgress * trackHeight).clamp(0.0, trackHeight);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: (details) {
            _isDraggingScrollbar = true;
          },
          onVerticalDragUpdate: (details) {
            final newProgress = ((details.localPosition.dy - thumbHeight / 2) / trackHeight).clamp(0.0, 1.0);
            _onScrollbarDrag(newProgress);
          },
          onVerticalDragEnd: (_) {
            _isDraggingScrollbar = false;
            _saveCurrentPosition();
          },
          onTapDown: (details) {
            final newProgress = (details.localPosition.dy / viewportHeight).clamp(0.0, 1.0);
            _onScrollbarDrag(newProgress);
          },
          child: Container(
            width: 32, // Wider touch target
            color: Colors.transparent,
            child: Stack(
              children: [
                // Track background
                Positioned(
                  right: 4,
                  top: 8,
                  bottom: 8,
                  child: Container(
                    width: 8,
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.08)
                          : Colors.black.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                // Thumb
                Positioned(
                  right: 2,
                  top: thumbTop + 8,
                  child: Container(
                    width: 12,
                    height: thumbHeight - 16,
                    decoration: BoxDecoration(
                      color: _isDraggingScrollbar
                          ? (isDarkMode ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.5))
                          : (isDarkMode ? Colors.white.withOpacity(0.4) : Colors.black.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBlockItem(BlockModel block) {
    final key = _blockKeys[block.id];

    if (widget.isEditMode) {
      return GestureDetector(
        onTap: () {
          setState(() {
            _focusedBlockId = block.id;
          });
          widget.onBlockFocused?.call(block.id);
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBlockHandle(block),
            Expanded(
              child: EditableBlock(
                key: key,
                block: block,
                isFocused: _focusedBlockId == block.id,
                onChanged: (content) {
                  ref.read(documentProvider.notifier).updateBlock(block.id, content);
                },
                onTypeChanged: (type) {
                  ref.read(documentProvider.notifier).updateBlockType(block.id, type);
                },
                onSubmitted: () {
                  ref.read(documentProvider.notifier).insertBlockAfter(block.id);
                  Future.delayed(const Duration(milliseconds: 100), () {
                    final blocks = ref.read(documentProvider).currentDocument?.blocks ?? [];
                    final currentIndex = blocks.indexWhere((b) => b.id == block.id);
                    if (currentIndex < blocks.length - 1) {
                      setState(() {
                        _focusedBlockId = blocks[currentIndex + 1].id;
                      });
                    }
                  });
                },
                onDelete: () {
                  if (widget.blocks.length > 1) {
                    ref.read(documentProvider.notifier).deleteBlock(block.id);
                  }
                },
              ),
            ),
          ],
        ),
      );
    } else {
      return ViewOnlyBlock(
        key: key,
        block: block,
      );
    }
  }

  Widget _buildBlockHandle(BlockModel block) {
    return Container(
      width: 24,
      height: 24,
      margin: const EdgeInsets.only(right: 8, top: 4),
      child: PopupMenuButton<String>(
        icon: Icon(
          Icons.drag_indicator,
          size: 16,
          color: Theme.of(context).iconTheme.color?.withOpacity(0.3),
        ),
        padding: EdgeInsets.zero,
        onSelected: (value) {
          final notifier = ref.read(documentProvider.notifier);
          switch (value) {
            case 'delete':
              if (widget.blocks.length > 1) {
                notifier.deleteBlock(block.id);
              }
              break;
            case 'duplicate':
              final currentBlock = widget.blocks.firstWhere((b) => b.id == block.id);
              notifier.insertBlockAfter(block.id);
              final blocks = ref.read(documentProvider).currentDocument?.blocks ?? [];
              final currentIndex = blocks.indexWhere((b) => b.id == currentBlock.id);
              if (currentIndex < blocks.length - 1) {
                notifier.updateBlock(blocks[currentIndex + 1].id, currentBlock.content);
              }
              break;
            case 'moveUp':
              notifier.moveBlockUp(block.id);
              break;
            case 'moveDown':
              notifier.moveBlockDown(block.id);
              break;
            case 'indent':
              notifier.indentBlock(block.id);
              break;
            case 'outdent':
              notifier.outdentBlock(block.id);
              break;
          }
        },
        itemBuilder: (BuildContext context) => [
          const PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete, size: 18),
                SizedBox(width: 8),
                Text('Delete'),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            value: 'duplicate',
            child: Row(
              children: [
                Icon(Icons.copy, size: 18),
                SizedBox(width: 8),
                Text('Duplicate'),
              ],
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem<String>(
            value: 'moveUp',
            child: Row(
              children: [
                Icon(Icons.arrow_upward, size: 18),
                SizedBox(width: 8),
                Text('Move Up'),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            value: 'moveDown',
            child: Row(
              children: [
                Icon(Icons.arrow_downward, size: 18),
                SizedBox(width: 8),
                Text('Move Down'),
              ],
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem<String>(
            value: 'indent',
            child: Row(
              children: [
                Icon(Icons.format_indent_increase, size: 18),
                SizedBox(width: 8),
                Text('Indent'),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            value: 'outdent',
            child: Row(
              children: [
                Icon(Icons.format_indent_decrease, size: 18),
                SizedBox(width: 8),
                Text('Outdent'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
