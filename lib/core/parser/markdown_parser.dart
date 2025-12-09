import 'package:markdown/markdown.dart' as md;
import '../../data/models/block_model.dart';

class MarkdownParser {
  static List<BlockModel> parseMarkdown(String markdown) {
    if (markdown.trim().isEmpty) {
      return [BlockModel(type: BlockType.paragraph, content: '')];
    }

    final blocks = <BlockModel>[];
    final buffer = StringBuffer();
    final lines = markdown.split('\n');
    bool inMath = false;
    final mathLines = <String>[];

    md.Document _buildDocument() {
      return md.Document(
        extensionSet: md.ExtensionSet(
          md.ExtensionSet.gitHubFlavored.blockSyntaxes,
          [
            md.EmojiSyntax(),
            md.InlineHtmlSyntax(),
            ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
          ],
        ),
      );
    }

    void flushBuffer() {
      if (buffer.isEmpty) return;
      final doc = _buildDocument();
      final nodes = doc.parse(_preprocessTasks(buffer.toString()));
      for (final node in nodes) {
        blocks.addAll(_convertNode(node));
      }
      buffer.clear();
    }

    for (final line in lines) {
      final trimmed = line.trimRight();

      // Handle single-line $$...$$
      final singleLineMath = RegExp(r'^\s*\$\$(.+?)\$\$\s*$');
      final singleMatch = singleLineMath.firstMatch(trimmed);
      if (!inMath && singleMatch != null) {
        flushBuffer();
        final content = singleMatch.group(1)!.trim();
        blocks.add(BlockModel(
          type: BlockType.math,
          content: content,
          metadata: {'inline': false},
        ));
        continue;
      }

      // Handle multi-line $$ blocks
      final startsMath = trimmed.startsWith(r'$$');
      final endsMath = trimmed.endsWith(r'$$');

      if (startsMath && !inMath) {
        flushBuffer();
        inMath = true;
        final afterStart = trimmed.substring(2).trimLeft();
        if (afterStart.isNotEmpty) {
          mathLines.add(afterStart);
        }
        if (endsMath && afterStart.isNotEmpty) {
          // $$ content $$ on same line handled above, but guard just in case
          final content = mathLines.join('\n').replaceAll(r'$$', '').trim();
          blocks.add(BlockModel(
            type: BlockType.math,
            content: content,
            metadata: {'inline': false},
          ));
          mathLines.clear();
          inMath = false;
        }
        continue;
      }

      if (inMath && endsMath) {
        final beforeEnd = trimmed.substring(0, trimmed.length - 2).trimRight();
        if (beforeEnd.isNotEmpty) {
          mathLines.add(beforeEnd);
        }
        final content = mathLines.join('\n').trim();
        blocks.add(BlockModel(
          type: BlockType.math,
          content: content,
          metadata: {'inline': false},
        ));
        mathLines.clear();
        inMath = false;
        continue;
      }

      if (inMath) {
        mathLines.add(line);
        continue;
      }

      buffer.writeln(line);
    }

    // Unclosed math block: treat as normal text
    if (inMath) {
      buffer.writeln(r'$$');
      for (final l in mathLines) {
        buffer.writeln(l);
      }
    }

    flushBuffer();

    if (blocks.isEmpty) {
      blocks.add(BlockModel(type: BlockType.paragraph, content: ''));
    }

    return blocks;
  }

  static String _preprocessTasks(String input) {
    final regex = RegExp(r'^(\s*)[-*]\s+\[( |x|X)\]\s+', multiLine: true);
    return input.replaceAllMapped(regex, (m) {
      final indent = m.group(1) ?? '';
      final marker = (m.group(2) ?? ' ').trim().toUpperCase() == 'X'
          ? 'TASKBOX_CHECKED '
          : 'TASKBOX_UNCHECKED ';
      return '$indent- $marker';
    });
  }

  static List<BlockModel> _convertNode(md.Node node, {int indentLevel = 0}) {
    final blocks = <BlockModel>[];

    if (node is md.Element) {
      switch (node.tag) {
        case 'h1':
          blocks.add(BlockModel(
            type: BlockType.heading1,
            content: _renderInlineMarkdown(node),
            indentLevel: indentLevel,
          ));
          break;
        case 'h2':
          blocks.add(BlockModel(
            type: BlockType.heading2,
            content: _renderInlineMarkdown(node),
            indentLevel: indentLevel,
          ));
          break;
        case 'h3':
          blocks.add(BlockModel(
            type: BlockType.heading3,
            content: _renderInlineMarkdown(node),
            indentLevel: indentLevel,
          ));
          break;
        case 'h4':
          blocks.add(BlockModel(
            type: BlockType.heading4,
            content: _renderInlineMarkdown(node),
            indentLevel: indentLevel,
          ));
          break;
        case 'h5':
          blocks.add(BlockModel(
            type: BlockType.heading5,
            content: _renderInlineMarkdown(node),
            indentLevel: indentLevel,
          ));
          break;
        case 'h6':
          blocks.add(BlockModel(
            type: BlockType.heading6,
            content: _renderInlineMarkdown(node),
            indentLevel: indentLevel,
          ));
          break;
        case 'p':
          final text = _renderInlineMarkdown(node);
          if (text.isNotEmpty) {
            blocks.add(BlockModel(
              type: BlockType.paragraph,
              content: text,
              indentLevel: indentLevel,
              metadata: {'inlineMath': _containsInlineMath(text)},
            ));
          }
          break;
        case 'blockquote':
          for (final child in node.children ?? []) {
            final childBlocks = _convertNode(child, indentLevel: indentLevel);
            for (final block in childBlocks) {
              blocks.add(block.copyWith(type: BlockType.blockquote));
            }
          }
          break;
        case 'ul':
          int order = 1;
          for (final child in node.children ?? []) {
            if (child is md.Element && child.tag == 'li') {
              final text = _renderInlineMarkdown(child);
              bool isTaskList = false;
              bool checked = false;
              String content = text;

              if (text.startsWith('TASKBOX_CHECKED ')) {
                isTaskList = true;
                checked = true;
                content = text.replaceFirst('TASKBOX_CHECKED ', '');
              } else if (text.startsWith('TASKBOX_UNCHECKED ')) {
                isTaskList = true;
                checked = false;
                content = text.replaceFirst('TASKBOX_UNCHECKED ', '');
              } else if (text.startsWith('[ ] ') || text.startsWith('[x] ')) {
                isTaskList = true;
                checked = text.startsWith('[x] ');
                content = text.substring(4);
              }
              
              if (isTaskList) {
                blocks.add(BlockModel(
                  type: BlockType.taskList,
                  content: content,
                  metadata: {'checked': checked},
                  indentLevel: indentLevel,
                ));
              } else {
                blocks.add(BlockModel(
                  type: BlockType.bulletList,
                  content: content,
                  indentLevel: indentLevel,
                ));
              }
              
              // Handle nested lists
              for (final nestedChild in child.children ?? []) {
                if (nestedChild is md.Element && 
                    (nestedChild.tag == 'ul' || nestedChild.tag == 'ol')) {
                  blocks.addAll(_convertNode(nestedChild, indentLevel: indentLevel + 1));
                }
              }
            }
          }
          break;
        case 'ol':
          int order = 1;
          for (final child in node.children ?? []) {
            if (child is md.Element && child.tag == 'li') {
              blocks.add(BlockModel(
                type: BlockType.numberedList,
                content: _renderInlineMarkdown(child),
                metadata: {'order': order},
                indentLevel: indentLevel,
              ));
              order++;
              
              // Handle nested lists
              for (final nestedChild in child.children ?? []) {
                if (nestedChild is md.Element && 
                    (nestedChild.tag == 'ul' || nestedChild.tag == 'ol')) {
                  blocks.addAll(_convertNode(nestedChild, indentLevel: indentLevel + 1));
                }
              }
            }
          }
          break;
        case 'pre':
          final codeElement = node.children?.firstWhere(
            (child) => child is md.Element && child.tag == 'code',
            orElse: () => node,
          );
          
          String content = '';
          String? language;
          
          if (codeElement is md.Element) {
            content = codeElement.textContent;
            final classes = codeElement.attributes['class'];
            if (classes != null && classes.startsWith('language-')) {
              language = classes.substring('language-'.length);
            }
          } else {
            content = node.textContent;
          }
          
          // Check if it's a Mermaid diagram
          if (language == 'mermaid') {
            blocks.add(BlockModel(
              type: BlockType.mermaid,
              content: content,
              metadata: {},
              indentLevel: indentLevel,
            ));
          } else {
            blocks.add(BlockModel(
              type: BlockType.code,
              content: content,
              metadata: {'language': language ?? ''},
              indentLevel: indentLevel,
            ));
          }
          break;
        case 'hr':
          blocks.add(BlockModel(
            type: BlockType.horizontalRule,
            content: '',
            indentLevel: indentLevel,
          ));
          break;
        case 'img':
          blocks.add(BlockModel(
            type: BlockType.image,
            content: node.attributes['src'] ?? '',
            metadata: {
              'alt': node.attributes['alt'] ?? '',
              'title': node.attributes['title'] ?? '',
            },
            indentLevel: indentLevel,
          ));
          break;
        case 'table':
          blocks.add(BlockModel(
            type: BlockType.table,
            content: _serializeTable(node),
            metadata: {},
            indentLevel: indentLevel,
          ));
          break;
        default:
          // For unknown tags, treat as paragraph
          final text = _renderInlineMarkdown(node);
          if (text.isNotEmpty) {
            blocks.add(BlockModel(
              type: BlockType.paragraph,
              content: text,
              indentLevel: indentLevel,
              metadata: {'inlineMath': _containsInlineMath(text)},
            ));
          }
      }
    } else if (node is md.Text) {
      final text = node.text.trim();
      if (text.isNotEmpty) {
        blocks.add(BlockModel(
          type: BlockType.paragraph,
          content: text,
          indentLevel: indentLevel,
          metadata: {'inlineMath': _containsInlineMath(text)},
        ));
      }
    }

    return blocks;
  }

  static String _renderInlineMarkdown(md.Node node) {
    final buffer = StringBuffer();

    void walk(md.Node n) {
      if (n is md.Text) {
        buffer.write(n.text);
      } else if (n is md.Element) {
        final children = n.children ?? [];
        // Skip whole lists (handled at block level), but keep current <li> text
        if (n.tag == 'ul' || n.tag == 'ol') {
          return;
        }
        switch (n.tag) {
          case 'li':
            for (final c in children) {
              if (c is md.Element && (c.tag == 'ul' || c.tag == 'ol')) {
                continue;
              }
              walk(c);
            }
            break;
          case 'em':
          case 'i':
            buffer.write('*');
            children.forEach(walk);
            buffer.write('*');
            break;
          case 'strong':
          case 'b':
            buffer.write('**');
            children.forEach(walk);
            buffer.write('**');
            break;
          case 'code':
            buffer.write('`');
            children.forEach(walk);
            buffer.write('`');
            break;
          case 'a':
            final href = n.attributes['href'] ?? '';
            final text = StringBuffer();
            for (final c in children) {
              if (c is md.Text) {
                text.write(c.text);
              } else {
                walk(c);
              }
            }
            buffer.write('[${text.toString()}]($href)');
            break;
          case 'del':
          case 's':
          case 'strike':
            buffer.write('~~');
            children.forEach(walk);
            buffer.write('~~');
            break;
          case 'mark':
            buffer.write('==');
            children.forEach(walk);
            buffer.write('==');
            break;
          case 'br':
            buffer.write('  \n');
            break;
          default:
            children.forEach(walk);
        }
      }
    }

    walk(node);
    return buffer.toString().trim();
  }

  static String _serializeTable(md.Element tableNode) {
    final buffer = StringBuffer();
    
    // Extract headers
    final thead = tableNode.children?.firstWhere(
      (child) => child is md.Element && child.tag == 'thead',
      orElse: () => md.Element.empty(''),
    ) as md.Element;
    
    final headers = <String>[];
    if (thead.tag == 'thead') {
      final tr = thead.children?.firstWhere(
        (child) => child is md.Element && child.tag == 'tr',
        orElse: () => md.Element.empty(''),
      ) as md.Element;
      
      if (tr.tag == 'tr') {
        for (final th in tr.children ?? []) {
          if (th is md.Element && th.tag == 'th') {
            headers.add(_renderInlineMarkdown(th));
          }
        }
      }
    }
    
    // Extract body
    final tbody = tableNode.children?.firstWhere(
      (child) => child is md.Element && child.tag == 'tbody',
      orElse: () => md.Element.empty(''),
    ) as md.Element;
    
    final rows = <List<String>>[];
    if (tbody.tag == 'tbody') {
      for (final tr in tbody.children ?? []) {
        if (tr is md.Element && tr.tag == 'tr') {
          final row = <String>[];
          for (final td in tr.children ?? []) {
            if (td is md.Element && td.tag == 'td') {
              row.add(_renderInlineMarkdown(td));
            }
          }
          rows.add(row);
        }
      }
    }
    
    // Build markdown table
    if (headers.isNotEmpty) {
      buffer.writeln('| ${headers.join(' | ')} |');
      buffer.writeln('| ${headers.map((_) => '---').join(' | ')} |');
    }
    
    for (final row in rows) {
      buffer.writeln('| ${row.join(' | ')} |');
    }
    
    return buffer.toString().trim();
  }

  static String combineBlocks(List<BlockModel> blocks) {
    final buffer = StringBuffer();
    for (final block in blocks) {
      buffer.writeln(block.content);
    }
    return buffer.toString();
  }

  static bool _containsInlineMath(String text) {
    // Detect $...$ but avoid $$...$$
    final regex = RegExp(r'(?<!\\)\$(?!\$)(.+?)(?<!\\)\$');
    return regex.hasMatch(text);
  }
}
