import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

enum BlockType {
  heading1,
  heading2,
  heading3,
  heading4,
  heading5,
  heading6,
  paragraph,
  bulletList,
  numberedList,
  taskList,
  code,
  blockquote,
  image,
  horizontalRule,
  table,
  mermaid,
  math,
  footnoteDefinition,
}

class BlockModel extends Equatable {
  final String id;
  final BlockType type;
  final String content;
  final Map<String, dynamic> metadata;
  final int indentLevel;
  final bool isEditing;
  final DateTime createdAt;
  final DateTime updatedAt;

  BlockModel({
    String? id,
    required this.type,
    required this.content,
    Map<String, dynamic>? metadata,
    this.indentLevel = 0,
    this.isEditing = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        metadata = metadata ?? {},
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  BlockModel copyWith({
    String? id,
    BlockType? type,
    String? content,
    Map<String, dynamic>? metadata,
    int? indentLevel,
    bool? isEditing,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BlockModel(
      id: id ?? this.id,
      type: type ?? this.type,
      content: content ?? this.content,
      metadata: metadata ?? this.metadata,
      indentLevel: indentLevel ?? this.indentLevel,
      isEditing: isEditing ?? this.isEditing,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  factory BlockModel.fromJson(Map<String, dynamic> json) {
    return BlockModel(
      id: json['id'] as String,
      type: BlockType.values.firstWhere(
        (e) => e.toString() == 'BlockType.${json['type']}',
        orElse: () => BlockType.paragraph,
      ),
      content: json['content'] as String,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      indentLevel: json['indentLevel'] as int? ?? 0,
      isEditing: json['isEditing'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString().split('.').last,
      'content': content,
      'metadata': metadata,
      'indentLevel': indentLevel,
      'isEditing': isEditing,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  String get displayContent {
    switch (type) {
      case BlockType.heading1:
        return '# $content';
      case BlockType.heading2:
        return '## $content';
      case BlockType.heading3:
        return '### $content';
      case BlockType.heading4:
        return '#### $content';
      case BlockType.heading5:
        return '##### $content';
      case BlockType.heading6:
        return '###### $content';
      case BlockType.bulletList:
        return '• $content';
      case BlockType.numberedList:
        return '${metadata['order'] ?? 1}. $content';
      case BlockType.taskList:
        final isChecked = metadata['checked'] ?? false;
        return '${isChecked ? '☑' : '☐'} $content';
      case BlockType.code:
        return content;
      case BlockType.blockquote:
        return '> $content';
      default:
        return content;
    }
  }

  @override
  List<Object?> get props => [
        id,
        type,
        content,
        metadata,
        indentLevel,
        isEditing,
        createdAt,
        updatedAt,
      ];
}