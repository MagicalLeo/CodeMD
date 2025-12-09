import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/block_model.dart';
import '../providers/document_provider.dart';
import 'blocks/view_only_block.dart';
import 'blocks/editable_block.dart';

class BlockList extends ConsumerStatefulWidget {
  final List<BlockModel> blocks;
  final bool isEditMode;
  final Function(String)? onBlockFocused;

  const BlockList({
    super.key,
    required this.blocks,
    required this.isEditMode,
    this.onBlockFocused,
  });

  @override
  ConsumerState<BlockList> createState() => _BlockListState();
}

class _BlockListState extends ConsumerState<BlockList> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _blockKeys = {};
  String? _focusedBlockId;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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

    // Using CustomScrollView with SliverList for optimal performance
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index >= widget.blocks.length) return null;
                
                final block = widget.blocks[index];
                
                return RepaintBoundary(
                  key: ValueKey(block.id),
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: block.indentLevel * 24.0,
                      bottom: 2.0, // Reduced padding for performance
                    ),
                    child: ViewOnlyBlock(block: block), // Direct view-only blocks
                  ),
                );
              },
              childCount: widget.blocks.length,
              // Extreme performance optimizations
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: false, // We handle it manually above
              addSemanticIndexes: false,
              findChildIndexCallback: (Key key) {
                final valueKey = key as ValueKey<String>;
                return widget.blocks.indexWhere((block) => block.id == valueKey.value);
              },
            ),
          ),
        ),
      ],
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
            // Block handle for dragging (Notion-style)
            _buildBlockHandle(block),
            // Main block content
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
                  // Focus next block after a short delay
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