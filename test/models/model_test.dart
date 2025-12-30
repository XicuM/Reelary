import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelary/models/recipe.dart';
import 'package:reelary/models/place.dart';
import 'package:reelary/models/folder.dart';
import 'package:reelary/models/location.dart';

void main() {
  group('Recipe Model Tests', () {
    test('Recipe.toMap and fromMap should work correctly', () {
      final recipe = Recipe(
        id: 1,
        title: 'Pasta',
        videoUrl: 'http://video.url',
        ingredients: [Ingredient(name: 'Tomato', quantity: '2', unit: 'pcs')],
        steps: ['Boil water', 'Cook pasta'],
        dateCreated: DateTime(2023, 1, 1),
        folderId: 1,
        thumbnailData: null,
      );

      final map = recipe.toMap();
      final newRecipe = Recipe.fromMap(map);

      expect(newRecipe.id, recipe.id);
      expect(newRecipe.title, recipe.title);
      expect(newRecipe.videoUrl, recipe.videoUrl);
      expect(newRecipe.ingredients.length, 1);
      expect(newRecipe.ingredients.first.name, 'Tomato');
      expect(newRecipe.steps.length, 2);
      expect(newRecipe.dateCreated, recipe.dateCreated);
      expect(newRecipe.folderId, recipe.folderId);
    });

    test('Recipe.copyWith should return a new instance with updated fields', () {
      final recipe = Recipe(
        title: 'Pasta',
        videoUrl: 'http://video.url',
        ingredients: [],
        steps: [],
        dateCreated: DateTime.now(),
      );

      final updatedRecipe = recipe.copyWith(title: 'Pizza');

      expect(updatedRecipe.title, 'Pizza');
      expect(updatedRecipe.videoUrl, recipe.videoUrl);
    });
  });

  group('Place Model Tests', () {
    test('Place.toMap and fromMap should work correctly', () {
      final place = Place(
        id: 1,
        title: 'Eiffel Tower',
        videoUrl: 'http://video.url',
        locations: [Location(name: 'Paris', latitude: 48.8584, longitude: 2.2945, address: 'Paris')],
        description: 'Beautiful place',
        dateCreated: DateTime(2023, 1, 1),
        folderId: 2,
        tagIds: [1, 2],
      );

      final map = place.toMap();
      final newPlace = Place.fromMap(map);

      expect(newPlace.id, place.id);
      expect(newPlace.title, place.title);
      expect(newPlace.locations.length, 1);
      expect(newPlace.locations.first.latitude, 48.8584);
      expect(newPlace.tagIds, [1, 2]);
    });
  });

  group('RecipeFolder Model Tests', () {
    test('RecipeFolder.toMap and fromMap should handle EntryType correctly', () {
      final folder = RecipeFolder(
        id: 1,
        name: 'Favorites',
        emoji: '⭐',
        dateCreated: DateTime(2023, 1, 1),
        dateModified: DateTime(2023, 1, 2),
        entryType: FolderEntryType.both,
      );

      final map = folder.toMap();
      final newFolder = RecipeFolder.fromMap(map);

      expect(newFolder.entryType, FolderEntryType.both);
      expect(newFolder.name, 'Favorites');
    });

     test('FolderEntryType parsing', () {
       expect(FolderEntryType.fromJson('recipe'), FolderEntryType.recipe);
       expect(FolderEntryType.fromJson('place'), FolderEntryType.place);
       expect(FolderEntryType.fromJson('both'), FolderEntryType.both);
       expect(FolderEntryType.fromJson('invalid'), FolderEntryType.recipe); // Default
     });
  });
}
