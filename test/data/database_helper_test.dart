import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:reelary/data/database_helper.dart';
import 'package:reelary/models/recipe.dart';
import 'package:reelary/models/place.dart';
import 'package:reelary/models/location.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    DatabaseHelper.setDbName(inMemoryDatabasePath);
  });

  tearDown(() async {
    await DatabaseHelper.instance.close();
  });

  group('DatabaseHelper Tests', () {
    test('Recipe CRUD operations', () async {
      final dbHelper = DatabaseHelper.instance;

      // Create
      final recipe = Recipe(
        title: 'Test Pasta',
        videoUrl: 'http://test.url',
        ingredients: [Ingredient(name: 'Tomato', quantity: '1', unit: 'kg')],
        steps: ['Cook'],
        dateCreated: DateTime.now(),
        reelId: 'reel123',
      );

      final createdRecipe = await dbHelper.create(recipe);
      expect(createdRecipe.id, isNotNull);
      expect(createdRecipe.title, 'Test Pasta');

      // Read
      final readRecipe = await dbHelper.readRecipe(createdRecipe.id!);
      expect(readRecipe, isNotNull);
      expect(readRecipe!.reelId, 'reel123');

      // Update
      final updatedRecipe = readRecipe.copyWith(title: 'Updated Pasta');
      await dbHelper.update(updatedRecipe);
      final readUpdated = await dbHelper.readRecipe(createdRecipe.id!);
      expect(readUpdated!.title, 'Updated Pasta');

      // Delete
      await dbHelper.delete(createdRecipe.id!);
      final deleted = await dbHelper.readRecipe(createdRecipe.id!);
      expect(deleted, isNull);
    });

    test('Place CRUD operations', () async {
      final dbHelper = DatabaseHelper.instance;

      final place = Place(
        title: 'Test Place',
        videoUrl: 'http://place.url',
        locations: [Location(name: 'Test Place', latitude: 10, longitude: 20, address: 'Test Address')],
        description: 'Desc',
        dateCreated: DateTime.now(),
        reelId: 'placeReel123',
      );

      final createdPlace = await dbHelper.createPlace(place);
      expect(createdPlace.id, isNotNull);

      final readPlace = await dbHelper.readPlace(createdPlace.id!);
      expect(readPlace!.title, 'Test Place');
      expect(readPlace.locations.first.address, 'Test Address');
    });

    test('Recipe Video Path Persistence', () async {
      // Regression test for checking if videoPath is preserved
       final dbHelper = DatabaseHelper.instance;
       final recipe = Recipe(
        title: 'Video Test',
        videoUrl: 'http://vid.eo',
        ingredients: [],
        steps: [],
        dateCreated: DateTime.now(),
        videoPath: '/local/path/video.mp4'
      );
      
      final created = await dbHelper.create(recipe);
      final read = await dbHelper.readRecipe(created.id!);
      expect(read!.videoPath, '/local/path/video.mp4');
    });
  });
}
