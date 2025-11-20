class RecipeFolder {
  final int? id;
  final String name;
  final String emoji;
  final DateTime dateCreated;
  final DateTime dateModified;

  RecipeFolder({
    this.id,
    required this.name,
    required this.emoji,
    required this.dateCreated,
    required this.dateModified,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'dateCreated': dateCreated.toIso8601String(),
      'dateModified': dateModified.toIso8601String(),
    };
  }

  factory RecipeFolder.fromMap(Map<String, dynamic> map) {
    return RecipeFolder(
      id: map['id']?.toInt(),
      name: map['name'] ?? '',
      emoji: map['emoji'] ?? '📁',
      dateCreated: DateTime.parse(map['dateCreated']),
      dateModified: DateTime.parse(map['dateModified']),
    );
  }

  RecipeFolder copyWith({
    int? id,
    String? name,
    String? emoji,
    DateTime? dateCreated,
    DateTime? dateModified,
  }) {
    return RecipeFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      dateCreated: dateCreated ?? this.dateCreated,
      dateModified: dateModified ?? this.dateModified,
    );
  }
}
