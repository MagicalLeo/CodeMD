import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;
import '../../../data/models/block_model.dart';
import '../../providers/document_provider.dart';
import '../mermaid_svg_renderer.dart';

class _MarkBuilder extends MarkdownElementBuilder {
  final Color highlight;
  _MarkBuilder(this.highlight);

  @override
  Widget? visitText(md.Text text, TextStyle? preferredStyle) {
    return Container(
      decoration: BoxDecoration(
        color: highlight,
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      child: Text(text.text, style: preferredStyle),
    );
  }
}

class _InlineMarkdown extends StatelessWidget {
  final String data;
  final TextStyle? style;

  const _InlineMarkdown({required this.data, this.style});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final withMark = data.replaceAllMapped(
      RegExp(r'<mark>(.+?)</mark>', dotAll: true),
      (m) => '==${m.group(1)}==',
    );
    final processed = withMark.replaceAllMapped(
      RegExp(r'==(.+?)=='),
      (m) => '<mark>${m.group(1)}</mark>',
    );

    return MarkdownBody(
      data: processed,
      selectable: true,
      softLineBreak: true,
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: style ?? theme.textTheme.bodyLarge,
        a: (style ?? theme.textTheme.bodyLarge)?.copyWith(
              color: theme.colorScheme.primary,
              decoration: TextDecoration.underline,
            ),
        code: theme.textTheme.bodyMedium?.copyWith(
          fontFamily: 'monospace',
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
        ),
      ),
      builders: {
        'mark': _MarkBuilder(theme.colorScheme.primary.withOpacity(0.2)),
      },
      shrinkWrap: true,
    );
  }
}

class _InlineMathText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const _InlineMathText({required this.text, this.style});

  @override
  Widget build(BuildContext context) {
    final parts = _splitInlineMath(text);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: parts.map((part) {
        if (part.isMath) {
          return Math.tex(
            part.content,
            mathStyle: MathStyle.text,
            textStyle: style?.copyWith(fontSize: (style?.fontSize ?? 16) + 1),
            onErrorFallback: (err) => Text(part.raw, style: style),
          );
        }
        return Text(part.raw, style: style);
      }).toList(),
    );
  }

  List<_MathSpan> _splitInlineMath(String input) {
    final regex = RegExp(r'(?<!\\)\$(?!\$)(.+?)(?<!\\)\$');
    final spans = <_MathSpan>[];
    int lastIndex = 0;

    for (final match in regex.allMatches(input)) {
      if (match.start > lastIndex) {
        spans.add(_MathSpan(false, input.substring(lastIndex, match.start)));
      }
      spans.add(_MathSpan(true, match.group(1)!, raw: match.group(0)!));
      lastIndex = match.end;
    }

    if (lastIndex < input.length) {
      spans.add(_MathSpan(false, input.substring(lastIndex)));
    }
    return spans;
  }
}

class _MathSpan {
  final bool isMath;
  final String content;
  final String raw;

  _MathSpan(this.isMath, this.content, {String? raw}) : raw = raw ?? content;
}

class ViewOnlyBlock extends ConsumerWidget {
  final BlockModel block;

  const ViewOnlyBlock({
    super.key,
    required this.block,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    switch (block.type) {
      case BlockType.heading1:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: _InlineMarkdown(
            data: block.content,
            style: Theme.of(context).textTheme.displaySmall,
          ),
        );
      
      case BlockType.heading2:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: _InlineMarkdown(
            data: block.content,
            style: Theme.of(context).textTheme.headlineLarge,
          ),
        );
      
      case BlockType.heading3:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: _InlineMarkdown(
            data: block.content,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        );
      
      case BlockType.heading4:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: _InlineMarkdown(
            data: block.content,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        );
      
      case BlockType.heading5:
      case BlockType.heading6:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: _InlineMarkdown(
            data: block.content,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        );
      
      case BlockType.paragraph:
        if (block.content.isEmpty) {
          return const SizedBox(height: 8);
        }
        final containsInlineMath = block.metadata['inlineMath'] == true;
        if (!containsInlineMath) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: _InlineMarkdown(
              data: block.content,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          );
        }
        // Render paragraph with inline math
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: _InlineMathText(
            text: block.content,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        );
      
      case BlockType.bulletList:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(right: 8.0, left: block.indentLevel * 12.0),
                child: const Text('•', style: TextStyle(fontSize: 16, height: 1.2)),
              ),
              Expanded(
                child: _InlineMarkdown(
                  data: block.content,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ),
        );
      
      case BlockType.numberedList:
        final order = block.metadata['order'] ?? 1;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(right: 8.0, left: block.indentLevel * 12.0),
                child: Text('$order.', style: const TextStyle(fontSize: 16, height: 1.2)),
              ),
              Expanded(
                child: _InlineMarkdown(
                  data: block.content,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ),
        );
      
      case BlockType.taskList:
        final hasExplicitChecked = block.metadata.containsKey('checked');
        final isChecked = hasExplicitChecked
            ? (block.metadata['checked'] == true)
            : (block.content.contains('[x]') || block.content.contains('[X]'));
        final cleanContent = block.content
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
        
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: isChecked,
                  onChanged: (value) {
                    ref.read(documentProvider.notifier).toggleTaskStatus(block.id);
                  },
                  tristate: false,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _InlineMarkdown(
                  data: cleanContent,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        decoration: isChecked 
                            ? TextDecoration.lineThrough 
                            : null,
                      ),
                ),
              ),
            ],
          ),
        );
      
      case BlockType.code:
        final language = block.metadata['language'] ?? 'plaintext';
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).dividerColor,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (language.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(7),
                      topRight: Radius.circular(7),
                    ),
                  ),
                  child: Text(
                    language,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SelectableText(
                    block.content,
                    style: TextStyle(
                      fontFamily: 'Courier New',
                      fontSize: 14,
                      color: isDarkMode ? Colors.white : Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      
      case BlockType.blockquote:
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 4,
              ),
            ),
            color: Theme.of(context).colorScheme.surface,
          ),
          child: _InlineMarkdown(
            data: block.content,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
          ),
        );
      
      case BlockType.image:
        final alt = block.metadata['alt'] ?? '';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            children: [
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                child: block.content.startsWith('http')
                    ? Image.network(
                        block.content,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            color: Theme.of(context).colorScheme.surface,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.broken_image, size: 48),
                                const SizedBox(height: 8),
                                Text('Failed to load image'),
                              ],
                            ),
                          );
                        },
                      )
                    : Container(
                        padding: const EdgeInsets.all(16),
                        color: Theme.of(context).colorScheme.surface,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.image, size: 48),
                            const SizedBox(height: 8),
                            Text(block.content),
                          ],
                        ),
                      ),
              ),
              if (alt.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    alt,
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        );
      
      case BlockType.horizontalRule:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Divider(
            thickness: 1,
            color: Theme.of(context).dividerColor,
          ),
        );
      
      case BlockType.table:
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _buildTable(context, block.content),
            ),
          ),
        );
      
      case BlockType.mermaid:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: MermaidSvgRenderer(
            mermaidCode: block.content,
            width: double.infinity,
          ),
        );
      
      case BlockType.math:
        // Math formula display - show as formatted code for performance
        final isInline = block.metadata['inline'] ?? false;
        return Container(
          margin: EdgeInsets.symmetric(
            vertical: isInline ? 2.0 : 10.0,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Math.tex(
            block.content.trim(),
            mathStyle: isInline ? MathStyle.text : MathStyle.display,
            textStyle: TextStyle(
              fontSize: isInline ? 16 : 20,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onErrorFallback: (err) => SelectableText(
              block.content,
              style: const TextStyle(
                fontFamily: 'monospace',
              ),
            ),
          ),
        );
      
      default:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text(
            block.content,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        );
    }
  }

  Widget _buildTable(BuildContext context, String markdownTable) {
    final lines = markdownTable.split('\n').where((line) => line.trim().isNotEmpty).toList();
    if (lines.isEmpty) return const Text('Empty table');

    List<String> headers = [];
    List<List<String>> rows = [];
    List<TextAlign> aligns = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('|') && line.endsWith('|')) {
        final cells = line
            .substring(1, line.length - 1)
            .split('|')
            .map((cell) => cell.trim())
            .toList();
        
        if (i == 0) {
          headers = cells;
        } else if (i == 1) {
          // Alignment row e.g. :---, ---:, :---:
          aligns = cells.map((cell) {
            final hasLeft = cell.startsWith(':');
            final hasRight = cell.endsWith(':');
            if (hasLeft && hasRight) return TextAlign.center;
            if (hasRight) return TextAlign.right;
            return TextAlign.left;
          }).toList();
        } else {
          rows.add(cells);
        }
      }
    }

    if (headers.isEmpty) return const Text('Invalid table format');
    if (aligns.length < headers.length) {
      aligns = List<TextAlign>.filled(headers.length, TextAlign.left);
    }

    return Table(
      border: TableBorder.all(
        color: Theme.of(context).dividerColor,
        width: 1,
      ),
      defaultColumnWidth: const IntrinsicColumnWidth(),
      children: [
        TableRow(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          ),
          children: headers.asMap().entries.map((entry) {
            final idx = entry.key;
            final header = entry.value;
            final align = idx < aligns.length ? aligns[idx] : TextAlign.left;
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                header,
                style: const TextStyle(fontWeight: FontWeight.bold),
                textAlign: align,
              ),
            );
          }).toList(),
        ),
        ...rows.map((row) {
          return TableRow(
            children: row.asMap().entries.map((entry) {
              final idx = entry.key;
              final cell = entry.value;
              final align = idx < aligns.length ? aligns[idx] : TextAlign.left;
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  cell,
                  textAlign: align,
                ),
              );
            }).toList(),
          );
        }),
      ],
    );
  }
}
