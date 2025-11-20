import 'dart:convert';

class Recipe {
  final int? id;
  final String title;
  final String videoUrl;
  final String? screenshotPath;
  final String? videoPath;
  final List<Ingredient> ingredients;
  final List<String> steps;
  final String? authorComment;
  final DateTime dateCreated;
  final int? folderId;
  final String? reelId;

  Recipe({
    this.id,
    required this.title,
    required this.videoUrl,
    this.screenshotPath,
    this.videoPath,
    required this.ingredients,
    required this.steps,
    this.authorComment,
    required this.dateCreated,
    this.folderId,
    this.reelId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'videoUrl': videoUrl,
      'screenshotPath': screenshotPath,
      'videoPath': videoPath,
      'ingredients': jsonEncode(ingredients.map((x) => x.toMap()).toList()),
      'steps': jsonEncode(steps),
      'authorComment': authorComment,
      'dateCreated': dateCreated.toIso8601String(),
      'folderId': folderId,
      'reelId': reelId,
    };
  }

  factory Recipe.fromMap(Map<String, dynamic> map) {
    return Recipe(
      id: map['id']?.toInt(),
      title: map['title'] ?? '',
      videoUrl: map['videoUrl'] ?? '',
      screenshotPath: map['screenshotPath'],
      videoPath: map['videoPath'],
      ingredients: map['ingredients'] != null
          ? List<Ingredient>.from(
              jsonDecode(map['ingredients'])?.map((x) => Ingredient.fromMap(x)))
          : [],
      steps: map['steps'] != null
          ? List<String>.from(jsonDecode(map['steps']))
          : [],
      authorComment: map['authorComment'],
      dateCreated: DateTime.parse(map['dateCreated']),
      folderId: map['folderId']?.toInt(),
      reelId: map['reelId'],
    );
  }

  Recipe copyWith({
    int? id,
    String? title,
    String? videoUrl,
    String? screenshotPath,
    String? videoPath,
    List<Ingredient>? ingredients,
    List<String>? steps,
    String? authorComment,
    DateTime? dateCreated,
    int? folderId,
    String? reelId,
  }) {
    return Recipe(
      id: id ?? this.id,
      title: title ?? this.title,
      videoUrl: videoUrl ?? this.videoUrl,
      screenshotPath: screenshotPath ?? this.screenshotPath,
      videoPath: videoPath ?? this.videoPath,
      ingredients: ingredients ?? this.ingredients,
      steps: steps ?? this.steps,
      authorComment: authorComment ?? this.authorComment,
      dateCreated: dateCreated ?? this.dateCreated,
      folderId: folderId ?? this.folderId,
      reelId: reelId ?? this.reelId,
    );
  }
}

class Ingredient {
  final String name;
  final String quantity;
  final String unit;

  Ingredient({
    required this.name,
    required this.quantity,
    required this.unit,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
    };
  }

  factory Ingredient.fromMap(Map<String, dynamic> map) {
    return Ingredient(
      name: map['name'] ?? '',
      quantity: map['quantity'] ?? '',
      unit: map['unit'] ?? '',
    );
  }
}
