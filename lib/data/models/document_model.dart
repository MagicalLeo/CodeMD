import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import 'block_model.dart';

class DocumentModel extends Equatable {
  final String id;
  final String title;
  final List<BlockModel> blocks;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? filePath;
  final Map<String, dynamic> metadata;

  DocumentModel({
    String? id,
    required this.title,
    List<BlockModel>? blocks,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.filePath,
    Map<String, dynamic>? metadata,
  })  : id = id ?? const Uuid().v4(),
        blocks = blocks ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        metadata = metadata ?? {};

  DocumentModel copyWith({
    String? id,
    String? title,
    List<BlockModel>? blocks,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? filePath,
    Map<String, dynamic>? metadata,
  }) {
    return DocumentModel(
      id: id ?? this.id,
      title: title ?? this.title,
      blocks: blocks ?? this.blocks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      filePath: filePath ?? this.filePath,
      metadata: metadata ?? this.metadata,
    );
  }

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id'] as String,
      title: json['title'] as String,
      blocks: (json['blocks'] as List<dynamic>)
          .map((block) => BlockModel.fromJson(block as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      filePath: json['filePath'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'blocks': blocks.map((block) => block.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'filePath': filePath,
      'metadata': metadata,
    };
  }

  String toMarkdown() {
    final buffer = StringBuffer();
    for (final block in blocks) {
      final indent = '  ' * block.indentLevel;
      switch (block.type) {
        case BlockType.heading1:
          buffer.writeln('${indent}# ${block.content}');
          break;
        case BlockType.heading2:
          buffer.writeln('${indent}## ${block.content}');
          break;
        case BlockType.heading3:
          buffer.writeln('${indent}### ${block.content}');
          break;
        case BlockType.heading4:
          buffer.writeln('${indent}#### ${block.content}');
          break;
        case BlockType.heading5:
          buffer.writeln('${indent}##### ${block.content}');
          break;
        case BlockType.heading6:
          buffer.writeln('${indent}###### ${block.content}');
          break;
        case BlockType.bulletList:
          buffer.writeln('$indent- ${block.content}');
          break;
        case BlockType.numberedList:
          final order = block.metadata['order'] ?? 1;
          buffer.writeln('$indent$order. ${block.content}');
          break;
        case BlockType.taskList:
          final isChecked = block.metadata['checked'] ?? false;
          buffer.writeln('$indent- [${isChecked ? 'x' : ' '}] ${block.content}');
          break;
        case BlockType.code:
          final language = block.metadata['language'] ?? '';
          buffer.writeln('${indent}```$language');
          buffer.writeln(block.content);
          buffer.writeln('${indent}```');
          break;
        case BlockType.mermaid:
          buffer.writeln('${indent}```mermaid');
          buffer.writeln(block.content);
          buffer.writeln('${indent}```');
          break;
        case BlockType.math:
          if (block.metadata['inline'] == true) {
            buffer.write('\$${block.content}\$');
          } else {
            buffer.writeln('${indent}\$\$');
            buffer.writeln(block.content);
            buffer.writeln('${indent}\$\$');
          }
          break;
        case BlockType.blockquote:
          buffer.writeln('$indent> ${block.content}');
          break;
        case BlockType.image:
          final alt = block.metadata['alt'] ?? '';
          buffer.writeln('$indent![$alt](${block.content})');
          break;
        case BlockType.horizontalRule:
          buffer.writeln('${indent}---');
          break;
        case BlockType.table:
          buffer.writeln(block.content);
          break;
        case BlockType.paragraph:
        default:
          buffer.writeln('$indent${block.content}');
          break;
      }
      buffer.writeln();
    }
    return buffer.toString();
  }

  int get wordCount {
    return blocks.fold(0, (sum, block) {
      if (block.type == BlockType.code || 
          block.type == BlockType.mermaid ||
          block.type == BlockType.image ||
          block.type == BlockType.horizontalRule) {
        return sum;
      }
      return sum + block.content.split(RegExp(r'\s+')).length;
    });
  }

  @override
  List<Object?> get props => [
        id,
        title,
        blocks,
        createdAt,
        updatedAt,
        filePath,
        metadata,
      ];
}