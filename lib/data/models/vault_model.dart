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
  final String? folder; // null means root/uncategorized

  const VaultFileModel({
    required this.path,
    required this.name,
    this.title,
    required this.lastModified,
    required this.lastOpened,
    required this.size,
    this.isPinned = false,
    this.folder,
  });

  VaultFileModel copyWith({
    String? path,
    String? name,
    String? title,
    DateTime? lastModified,
    DateTime? lastOpened,
    int? size,
    bool? isPinned,
    String? folder,
    bool clearFolder = false,
  }) {
    return VaultFileModel(
      path: path ?? this.path,
      name: name ?? this.name,
      title: title ?? this.title,
      lastModified: lastModified ?? this.lastModified,
      lastOpened: lastOpened ?? this.lastOpened,
      size: size ?? this.size,
      isPinned: isPinned ?? this.isPinned,
      folder: clearFolder ? null : (folder ?? this.folder),
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
      folder: json['folder'] as String?,
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
      'folder': folder,
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
        folder,
      ];
}

/// Folder model for organizing files
class VaultFolderModel extends Equatable {
  final String name;
  final String? icon; // emoji or icon name
  final int fileCount;

  const VaultFolderModel({
    required this.name,
    this.icon,
    this.fileCount = 0,
  });

  factory VaultFolderModel.fromJson(Map<String, dynamic> json) {
    return VaultFolderModel(
      name: json['name'] as String,
      icon: json['icon'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'icon': icon,
    };
  }

  VaultFolderModel copyWith({String? name, String? icon, int? fileCount}) {
    return VaultFolderModel(
      name: name ?? this.name,
      icon: icon ?? this.icon,
      fileCount: fileCount ?? this.fileCount,
    );
  }

  @override
  List<Object?> get props => [name, icon, fileCount];
}