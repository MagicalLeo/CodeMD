import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:path/path.dart' as p;
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

class _SuperscriptBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitText(md.Text text, TextStyle? preferredStyle) {
    return Transform.translate(
      offset: const Offset(0, -4),
      child: Text(
        text.text,
        style: preferredStyle?.copyWith(fontSize: (preferredStyle.fontSize ?? 14) * 0.75),
      ),
    );
  }
}

class _SubscriptBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitText(md.Text text, TextStyle? preferredStyle) {
    return Transform.translate(
      offset: const Offset(0, 4),
      child: Text(
        text.text,
        style: preferredStyle?.copyWith(fontSize: (preferredStyle.fontSize ?? 14) * 0.75),
      ),
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

    // Process highlight ==text==
    var processed = data.replaceAllMapped(
      RegExp(r'<mark>(.+?)</mark>', dotAll: true),
      (m) => '==${m.group(1)}==',
    );
    processed = processed.replaceAllMapped(
      RegExp(r'==(.+?)=='),
      (m) => '<mark>${m.group(1)}</mark>',
    );

    // Process superscript ^text^
    processed = processed.replaceAllMapped(
      RegExp(r'\^([^\^]+)\^'),
      (m) => '<sup>${m.group(1)}</sup>',
    );

    // Process subscript ~text~
    processed = processed.replaceAllMapped(
      RegExp(r'~([^~]+)~'),
      (m) => '<sub>${m.group(1)}</sub>',
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
          fontFamily: 'Consolas',
          fontFamilyFallback: const ['Monaco', 'Courier New', 'monospace'],
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
        ),
      ),
      builders: {
        'mark': _MarkBuilder(theme.colorScheme.primary.withOpacity(0.2)),
        'sup': _SuperscriptBuilder(),
        'sub': _SubscriptBuilder(),
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
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: Text(
            block.content,
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
          ),
        );
      
      case BlockType.heading2:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            block.content,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
          ),
        );
      
      case BlockType.heading3:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Text(
            block.content,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
          ),
        );
      
      case BlockType.heading4:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text(
            block.content,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
          ),
        );
      
      case BlockType.heading5:
      case BlockType.heading6:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text(
            block.content,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.25,
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
        final language = block.metadata['language'] ?? '';
        final highlightTheme = isDarkMode ? atomOneDarkTheme : githubTheme;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDarkMode ? const Color(0xFF30363D) : const Color(0xFFD0D7DE),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with language and copy button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF161B22) : const Color(0xFFEFF2F5),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(7),
                    topRight: Radius.circular(7),
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: isDarkMode ? const Color(0xFF30363D) : const Color(0xFFD0D7DE),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      language.isNotEmpty ? language : 'text',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? const Color(0xFF8B949E) : const Color(0xFF57606A),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: block.content));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Code copied to clipboard'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Icon(
                        Icons.copy_outlined,
                        size: 16,
                        color: isDarkMode ? const Color(0xFF8B949E) : const Color(0xFF57606A),
                      ),
                    ),
                  ],
                ),
              ),
              // Code content with syntax highlighting
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(12),
                child: HighlightView(
                  block.content,
                  language: language.isNotEmpty ? language : 'plaintext',
                  theme: highlightTheme,
                  padding: EdgeInsets.zero,
                  textStyle: TextStyle(
                    fontFamily: 'Consolas',
                    fontFamilyFallback: const ['Monaco', 'Courier New', 'monospace'],
                    fontSize: 13,
                    height: 1.5,
                    color: isDarkMode ? const Color(0xFFE6EDF3) : const Color(0xFF24292F),
                  ),
                ),
              ),
            ],
          ),
        );
      
      case BlockType.blockquote:
        final admonition = block.metadata['admonition'];
        if (admonition == 'note' || admonition == 'tip' || admonition == 'important' || admonition == 'warning' || admonition == 'caution') {
          final theme = Theme.of(context);

          // Define colors and icons for each admonition type (light and dark mode)
          late final Color primaryColor;
          late final Color backgroundColor;
          late final Color borderColor;
          late final Color textColor;
          late final String label;
          late final IconData icon;

          switch (admonition) {
            case 'note':
              primaryColor = isDarkMode ? const Color(0xFF58A6FF) : const Color(0xFF0969DA);
              backgroundColor = isDarkMode ? const Color(0xFF0D1117).withOpacity(0.6) : const Color(0xFFDDF4FF);
              borderColor = isDarkMode ? const Color(0xFF388BFD) : const Color(0xFF54AEFF);
              textColor = isDarkMode ? const Color(0xFFC9D1D9) : const Color(0xFF24292F);
              label = 'Note';
              icon = Icons.info_outline;
              break;
            case 'tip':
              primaryColor = isDarkMode ? const Color(0xFF3FB950) : const Color(0xFF2DA44E);
              backgroundColor = isDarkMode ? const Color(0xFF0D1117).withOpacity(0.6) : const Color(0xFFDDFBE7);
              borderColor = isDarkMode ? const Color(0xFF238636) : const Color(0xFF4AC26B);
              textColor = isDarkMode ? const Color(0xFFC9D1D9) : const Color(0xFF24292F);
              label = 'Tip';
              icon = Icons.lightbulb_outline;
              break;
            case 'important':
              primaryColor = isDarkMode ? const Color(0xFFA371F7) : const Color(0xFF8250DF);
              backgroundColor = isDarkMode ? const Color(0xFF0D1117).withOpacity(0.6) : const Color(0xFFFBEFFF);
              borderColor = isDarkMode ? const Color(0xFF8957E5) : const Color(0xFFD8B9FF);
              textColor = isDarkMode ? const Color(0xFFC9D1D9) : const Color(0xFF24292F);
              label = 'Important';
              icon = Icons.chat_bubble_outline;
              break;
            case 'warning':
              primaryColor = isDarkMode ? const Color(0xFFD29922) : const Color(0xFFBF8700);
              backgroundColor = isDarkMode ? const Color(0xFF0D1117).withOpacity(0.6) : const Color(0xFFFFF8C5);
              borderColor = isDarkMode ? const Color(0xFFBB8009) : const Color(0xFFD4A72C);
              textColor = isDarkMode ? const Color(0xFFC9D1D9) : const Color(0xFF24292F);
              label = 'Warning';
              icon = Icons.warning_amber_outlined;
              break;
            case 'caution':
              primaryColor = isDarkMode ? const Color(0xFFF85149) : const Color(0xFFCF222E);
              backgroundColor = isDarkMode ? const Color(0xFF0D1117).withOpacity(0.6) : const Color(0xFFFFEBE9);
              borderColor = isDarkMode ? const Color(0xFFDA3633) : const Color(0xFFFF8182);
              textColor = isDarkMode ? const Color(0xFFC9D1D9) : const Color(0xFF24292F);
              label = 'Caution';
              icon = Icons.error_outline;
              break;
            default:
              primaryColor = isDarkMode ? const Color(0xFF58A6FF) : const Color(0xFF0969DA);
              backgroundColor = isDarkMode ? const Color(0xFF0D1117).withOpacity(0.6) : const Color(0xFFDDF4FF);
              borderColor = isDarkMode ? const Color(0xFF388BFD) : const Color(0xFF54AEFF);
              textColor = isDarkMode ? const Color(0xFFC9D1D9) : const Color(0xFF24292F);
              label = 'Note';
              icon = Icons.info_outline;
          }
          
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            decoration: BoxDecoration(
              color: backgroundColor,
              border: Border.all(
                color: borderColor,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with icon and label
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: borderColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        size: 20,
                        color: primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildAdmonitionContent(context, ref, block, textColor, isDarkMode),
                ),
              ],
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.6),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.4)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Expanded(
                child: MarkdownBody(
                  data: block.content,
                  shrinkWrap: true,
                  softLineBreak: true,
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                    p: Theme.of(context).textTheme.bodyLarge,
                    listBullet: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
            ],
          ),
        );
      
      case BlockType.image:
        final alt = block.metadata['alt'] ?? '';
        final imagePath = block.content;
        final basePath = block.metadata['basePath'] as String?;

        Widget buildImage() {
          // Network image
          if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
            return Image.network(
              imagePath,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => _buildImageError(context, 'Failed to load image'),
            );
          }

          // Local image - resolve relative path
          String fullPath = imagePath;
          if (basePath != null && !p.isAbsolute(imagePath)) {
            fullPath = p.join(p.dirname(basePath), imagePath);
          }

          final file = File(fullPath);
          if (file.existsSync()) {
            return Image.file(
              file,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => _buildImageError(context, 'Failed to load image'),
            );
          }

          return _buildImageError(context, imagePath);
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            children: [
              Container(
                constraints: const BoxConstraints(maxHeight: 400),
                child: buildImage(),
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
      
      case BlockType.footnoteDefinition:
        final index = block.metadata['index'] ?? 1;
        final footnoteTextColor = isDarkMode
            ? const Color(0xFFC9D1D9)
            : Theme.of(context).colorScheme.onSurface;
        return Container(
          margin: const EdgeInsets.only(top: 4.0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDarkMode
                ? const Color(0xFF161B22)
                : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(6),
            border: Border(
              left: BorderSide(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                width: 3,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$index',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  block.content,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: footnoteTextColor,
                  ),
                ),
              ),
            ],
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
              child: _buildTableCell(context, header, align, isHeader: true),
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
                child: _buildTableCell(context, cell, align, isHeader: false),
              );
            }).toList(),
          );
        }),
      ],
    );
  }

  Widget _buildTableCell(BuildContext context, String content, TextAlign align, {required bool isHeader}) {
    final theme = Theme.of(context);

    // Check if content has inline markdown (bold, code, etc.)
    final hasBold = content.contains('**') || content.contains('__');
    final hasCode = content.contains('`');
    final hasItalic = content.contains('*') || content.contains('_');

    if (hasBold || hasCode || hasItalic) {
      return _InlineMarkdown(
        data: content,
        style: isHeader
            ? theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)
            : theme.textTheme.bodyMedium,
      );
    }

    return Text(
      content,
      style: isHeader
          ? theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)
          : theme.textTheme.bodyMedium,
      textAlign: align,
    );
  }

  Widget _buildImageError(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image, size: 48, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAdmonitionContent(BuildContext context, WidgetRef ref, BlockModel block, Color textColor, bool isDarkMode) {
    // Use innerBlocks if available, otherwise fallback to markdown parsing
    final innerBlocks = block.metadata['innerBlocks'] as List<BlockModel>?;

    if (innerBlocks != null && innerBlocks.isNotEmpty) {
      // Render each inner block with proper styling
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: innerBlocks.asMap().entries.map((entry) {
          final index = entry.key;
          final innerBlock = entry.value;
          return Padding(
            padding: EdgeInsets.only(top: index > 0 ? 8.0 : 0.0),
            child: _buildAdmonitionInnerBlock(context, ref, innerBlock, textColor, isDarkMode),
          );
        }).toList(),
      );
    }

    // Fallback to MarkdownBody for simple content
    final theme = Theme.of(context);
    final codeColor = isDarkMode ? const Color(0xFF79C0FF) : const Color(0xFF0550AE);

    return MarkdownBody(
      data: block.content,
      shrinkWrap: true,
      softLineBreak: true,
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: theme.textTheme.bodyLarge?.copyWith(
          color: textColor,
          height: 1.5,
        ),
        h1: theme.textTheme.displayLarge?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
          height: 1.2,
          fontSize: 28.0,
        ),
        h2: theme.textTheme.displayMedium?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
          height: 1.25,
          fontSize: 24.0,
        ),
        h3: theme.textTheme.displaySmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
          height: 1.25,
          fontSize: 20.0,
        ),
        h4: theme.textTheme.headlineMedium?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
          height: 1.25,
          fontSize: 18.0,
        ),
        h5: theme.textTheme.headlineSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
          height: 1.25,
          fontSize: 16.0,
        ),
        h6: theme.textTheme.headlineSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
          height: 1.25,
          fontSize: 14.0,
        ),
        listBullet: theme.textTheme.bodyLarge?.copyWith(
          color: textColor,
        ),
        code: TextStyle(
          fontFamily: 'Consolas',
          fontFamilyFallback: const ['Monaco', 'Courier New', 'monospace'],
          fontSize: 13,
          backgroundColor: isDarkMode
              ? Colors.black.withOpacity(0.3)
              : Colors.white.withOpacity(0.7),
          color: codeColor,
        ),
        codeblockDecoration: BoxDecoration(
          color: isDarkMode
              ? Colors.black.withOpacity(0.3)
              : Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget _buildAdmonitionInnerBlock(BuildContext context, WidgetRef ref, BlockModel innerBlock, Color textColor, bool isDarkMode) {
    final theme = Theme.of(context);

    switch (innerBlock.type) {
      case BlockType.heading1:
        return Text(
          innerBlock.content,
          style: theme.textTheme.headlineLarge?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        );
      case BlockType.heading2:
        return Text(
          innerBlock.content,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        );
      case BlockType.heading3:
        return Text(
          innerBlock.content,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        );
      case BlockType.heading4:
      case BlockType.heading5:
      case BlockType.heading6:
        return Text(
          innerBlock.content,
          style: theme.textTheme.titleLarge?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        );
      case BlockType.bulletList:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(right: 8.0, left: innerBlock.indentLevel * 12.0),
              child: Text('•', style: TextStyle(fontSize: 16, height: 1.2, color: textColor)),
            ),
            Expanded(
              child: _InlineMarkdown(
                data: innerBlock.content,
                style: theme.textTheme.bodyLarge?.copyWith(color: textColor),
              ),
            ),
          ],
        );
      case BlockType.numberedList:
        final order = innerBlock.metadata['order'] ?? 1;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(right: 8.0, left: innerBlock.indentLevel * 12.0),
              child: Text('$order.', style: TextStyle(fontSize: 16, height: 1.2, color: textColor)),
            ),
            Expanded(
              child: _InlineMarkdown(
                data: innerBlock.content,
                style: theme.textTheme.bodyLarge?.copyWith(color: textColor),
              ),
            ),
          ],
        );
      case BlockType.code:
        final language = innerBlock.metadata['language'] ?? '';
        final highlightTheme = isDarkMode ? atomOneDarkTheme : githubTheme;
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.8),
            borderRadius: BorderRadius.circular(6),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(8),
            child: HighlightView(
              innerBlock.content,
              language: language.isNotEmpty ? language : 'plaintext',
              theme: highlightTheme,
              padding: EdgeInsets.zero,
              textStyle: TextStyle(
                fontFamily: 'Consolas',
                fontFamilyFallback: const ['Monaco', 'Courier New', 'monospace'],
                fontSize: 12,
                height: 1.4,
                color: isDarkMode ? const Color(0xFFE6EDF3) : const Color(0xFF24292F),
              ),
            ),
          ),
        );
      case BlockType.math:
        final isInline = innerBlock.metadata['inline'] ?? false;
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Math.tex(
            innerBlock.content.trim(),
            mathStyle: isInline ? MathStyle.text : MathStyle.display,
            textStyle: TextStyle(
              fontSize: isInline ? 14 : 18,
              color: textColor,
            ),
            onErrorFallback: (err) => Text(
              innerBlock.content,
              style: TextStyle(
                fontFamily: 'Consolas',
                fontFamilyFallback: const ['Monaco', 'Courier New', 'monospace'],
                color: textColor,
              ),
            ),
          ),
        );
      case BlockType.mermaid:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: MermaidSvgRenderer(
            mermaidCode: innerBlock.content,
            width: double.infinity,
          ),
        );
      case BlockType.paragraph:
      default:
        if (innerBlock.content.isEmpty) {
          return const SizedBox(height: 4);
        }
        return _InlineMarkdown(
          data: innerBlock.content,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: textColor,
            height: 1.5,
          ),
        );
    }
  }
}
