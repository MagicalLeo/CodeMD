import 'dart:io';
import 'package:equatable/equatable.dart';

class VaultFileModel extends Equatable {
  final String path;
  final String name;
  final String? title;
  final DateTime lastModified;
  final DateTime lastOpened;
  final int size;
  final bool isPinned;

  const VaultFileModel({
    required this.path,
    required this.name,
    this.title,
    required this.lastModified,
    required this.lastOpened,
    required this.size,
    this.isPinned = false,
  });

  VaultFileModel copyWith({
    String? path,
    String? name,
    String? title,
    DateTime? lastModified,
    DateTime? lastOpened,
    int? size,
    bool? isPinned,
  }) {
    return VaultFileModel(
      path: path ?? this.path,
      name: name ?? this.name,
      title: title ?? this.title,
      lastModified: lastModified ?? this.lastModified,
      lastOpened: lastOpened ?? this.lastOpened,
      size: size ?? this.size,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  factory VaultFileModel.fromJson(Map<String, dynamic> json) {
    return VaultFileModel(
      path: json['path'] as String,
      name: json['name'] as String,
      title: json['title'] as String?,
      lastModified: DateTime.parse(json['lastModified'] as String),
      lastOpened: DateTime.parse(json['lastOpened'] as String),
      size: json['size'] as int,
      isPinned: json['isPinned'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'name': name,
      'title': title,
      'lastModified': lastModified.toIso8601String(),
      'lastOpened': lastOpened.toIso8601String(),
      'size': size,
      'isPinned': isPinned,
    };
  }

  static Future<VaultFileModel> fromFile(File file, {String? title}) async {
    final stat = await file.stat();
    final name = file.path.split(Platform.pathSeparator).last;
    
    return VaultFileModel(
      path: file.path,
      name: name,
      title: title ?? name.replaceAll(RegExp(r'\.(md|markdown|txt)$'), ''),
      lastModified: stat.modified,
      lastOpened: DateTime.now(),
      size: stat.size,
    );
  }

  String get displayTitle => title ?? name;
  
  String get sizeFormatted {
    if (size < 1024) return '${size}B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)}KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  @override
  List<Object?> get props => [
        path,
        name,
        title,
        lastModified,
        lastOpened,
        size,
        isPinned,
      ];
}