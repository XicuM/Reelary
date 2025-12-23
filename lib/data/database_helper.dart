import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io' show Platform;
import '../models/recipe.dart';
import '../models/folder.dart';
import '../models/place.dart';
import '../models/tag.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('recipes.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    // Initialize FFI for desktop platforms
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 5,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add folders table
      const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
      const textType = 'TEXT NOT NULL';
      await db.execute('''
CREATE TABLE IF NOT EXISTS folders ( 
  id $idType, 
  name $textType,
  emoji $textType,
  dateCreated $textType,
  dateModified $textType
  )
''');

      // Add folderId column to recipes
      await db.execute('''
ALTER TABLE recipes ADD COLUMN folderId INTEGER
''');
    }

    if (oldVersion < 3) {
      // Add reelId column to recipes with unique constraint
      await db.execute('''
ALTER TABLE recipes ADD COLUMN reelId TEXT
''');

      // Note: SQLite ALTER TABLE doesn't support adding UNIQUE constraint
      // Uniqueness will be enforced at the application level and in new databases
    }

    if (oldVersion < 4) {
      // Add videoPath column to store local video file path
      await db.execute('''
ALTER TABLE recipes ADD COLUMN videoPath TEXT
''');
    }

    if (oldVersion < 5) {
      // Add entryType column to folders
      await db.execute('''
ALTER TABLE folders ADD COLUMN entryType TEXT DEFAULT 'recipe'
''');

      // Create tags table
      await db.execute('''
CREATE TABLE IF NOT EXISTS tags (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  icon TEXT NOT NULL,
  color TEXT NOT NULL
)
''');

      // Create places table
      await db.execute('''
CREATE TABLE IF NOT EXISTS places (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  videoUrl TEXT NOT NULL,
  screenshotPath TEXT,
  videoPath TEXT,
  locations TEXT NOT NULL,
  description TEXT NOT NULL,
  dateCreated TEXT NOT NULL,
  folderId INTEGER,
  reelId TEXT UNIQUE,
  tagIds TEXT NOT NULL,
  FOREIGN KEY (folderId) REFERENCES folders (id) ON DELETE SET NULL
)
''');
    }
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textNullableType = 'TEXT';
    const intNullableType = 'INTEGER';

    await db.execute('''
CREATE TABLE folders ( 
  id $idType, 
  name $textType,
  emoji $textType,
  dateCreated $textType,
  dateModified $textType,
  entryType $textType DEFAULT 'recipe'
  )
''');

    await db.execute('''
CREATE TABLE recipes ( 
  id $idType, 
  title $textType,
  videoUrl $textType,
  screenshotPath $textNullableType,
  videoPath $textNullableType,
  ingredients $textType,
  steps $textType,
  authorComment $textNullableType,
  dateCreated $textType,
  folderId $intNullableType,
  reelId $textNullableType UNIQUE,
  FOREIGN KEY (folderId) REFERENCES folders (id) ON DELETE SET NULL
  )
''');

    await db.execute('''
CREATE TABLE tags ( 
  id $idType, 
  name $textType,
  icon $textType,
  color $textType
  )
''');

    await db.execute('''
CREATE TABLE places ( 
  id $idType, 
  title $textType,
  videoUrl $textType,
  screenshotPath $textNullableType,
  videoPath $textNullableType,
  locations $textType,
  description $textType,
  dateCreated $textType,
  folderId $intNullableType,
  reelId $textNullableType UNIQUE,
  tagIds $textType,
  FOREIGN KEY (folderId) REFERENCES folders (id) ON DELETE SET NULL
  )
''');
  }

  Future<Recipe> create(Recipe recipe) async {
    final db = await instance.database;
    final id = await db.insert('recipes', recipe.toMap());
    return Recipe(
      id: id,
      title: recipe.title,
      videoUrl: recipe.videoUrl,
      screenshotPath: recipe.screenshotPath,
      videoPath: recipe.videoPath,
      ingredients: recipe.ingredients,
      steps: recipe.steps,
      authorComment: recipe.authorComment,
      dateCreated: recipe.dateCreated,
      folderId: recipe.folderId,
      reelId: recipe.reelId,
    );
  }

  Future<bool> recipeExistsByReelId(String reelId) async {
    final db = await instance.database;
    final result = await db.query(
      'recipes',
      where: 'reelId = ?',
      whereArgs: [reelId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<Recipe?> getRecipeByReelId(String reelId) async {
    final db = await instance.database;
    final result = await db.query(
      'recipes',
      where: 'reelId = ?',
      whereArgs: [reelId],
      limit: 1,
    );
    if (result.isNotEmpty) {
      return Recipe.fromMap(result.first);
    }
    return null;
  }

  Future<Recipe?> readRecipe(int id) async {
    final db = await instance.database;

    final maps = await db.query(
      'recipes',
      columns: null,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Recipe.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<List<Recipe>> readAllRecipes() async {
    final db = await instance.database;
    const orderBy = 'dateCreated DESC';
    final result = await db.query('recipes', orderBy: orderBy);

    return result.map((json) => Recipe.fromMap(json)).toList();
  }

  Future<int> update(Recipe recipe) async {
    final db = await instance.database;

    return db.update(
      'recipes',
      recipe.toMap(),
      where: 'id = ?',
      whereArgs: [recipe.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await instance.database;

    return await db.delete(
      'recipes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }

  // Folder operations
  Future<RecipeFolder> createFolder(RecipeFolder folder) async {
    final db = await instance.database;
    final id = await db.insert('folders', folder.toMap());
    return folder.copyWith(id: id);
  }

  Future<List<RecipeFolder>> readAllFolders() async {
    final db = await instance.database;
    const orderBy = 'dateModified DESC';
    final result = await db.query('folders', orderBy: orderBy);
    return result.map((json) => RecipeFolder.fromMap(json)).toList();
  }

  Future<RecipeFolder?> readFolder(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'folders',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return RecipeFolder.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateFolder(RecipeFolder folder) async {
    final db = await instance.database;
    return db.update(
      'folders',
      folder.toMap(),
      where: 'id = ?',
      whereArgs: [folder.id],
    );
  }

  Future<int> deleteFolder(int id) async {
    final db = await instance.database;
    // First, set folderId to null for all recipes in this folder
    await db.update(
      'recipes',
      {'folderId': null},
      where: 'folderId = ?',
      whereArgs: [id],
    );
    // Then delete the folder
    return await db.delete(
      'folders',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Recipe>> readRecipesByFolder(int? folderId) async {
    final db = await instance.database;
    const orderBy = 'dateCreated DESC';
    final result = await db.query(
      'recipes',
      where: folderId == null ? 'folderId IS NULL' : 'folderId = ?',
      whereArgs: folderId == null ? null : [folderId],
      orderBy: orderBy,
    );
    return result.map((json) => Recipe.fromMap(json)).toList();
  }

  Future<int> getRecipeCountInFolder(int? folderId) async {
    final db = await instance.database;
    final result = await db.query(
      'recipes',
      columns: ['COUNT(*) as count'],
      where: folderId == null ? 'folderId IS NULL' : 'folderId = ?',
      whereArgs: folderId == null ? null : [folderId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Place operations
  Future<Place> createPlace(Place place) async {
    final db = await instance.database;
    final id = await db.insert('places', place.toMap());
    return place.copyWith(id: id);
  }

  Future<bool> placeExistsByReelId(String reelId) async {
    final db = await instance.database;
    final result = await db.query(
      'places',
      where: 'reelId = ?',
      whereArgs: [reelId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<Place?> getPlaceByReelId(String reelId) async {
    final db = await instance.database;
    final result = await db.query(
      'places',
      where: 'reelId = ?',
      whereArgs: [reelId],
      limit: 1,
    );
    if (result.isNotEmpty) {
      return Place.fromMap(result.first);
    }
    return null;
  }

  Future<Place?> readPlace(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'places',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Place.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Place>> readAllPlaces() async {
    final db = await instance.database;
    const orderBy = 'dateCreated DESC';
    final result = await db.query('places', orderBy: orderBy);
    return result.map((json) => Place.fromMap(json)).toList();
  }

  Future<List<Place>> readPlacesByFolder(int? folderId) async {
    final db = await instance.database;
    const orderBy = 'dateCreated DESC';
    final result = await db.query(
      'places',
      where: folderId == null ? 'folderId IS NULL' : 'folderId = ?',
      whereArgs: folderId == null ? null : [folderId],
      orderBy: orderBy,
    );
    return result.map((json) => Place.fromMap(json)).toList();
  }

  Future<List<Place>> readPlacesByTag(int tagId) async {
    final db = await instance.database;
    const orderBy = 'dateCreated DESC';
    final result = await db.query('places', orderBy: orderBy);
    final places = result.map((json) => Place.fromMap(json)).toList();
    return places.where((place) => place.tagIds.contains(tagId)).toList();
  }

  Future<int> updatePlace(Place place) async {
    final db = await instance.database;
    return db.update(
      'places',
      place.toMap(),
      where: 'id = ?',
      whereArgs: [place.id],
    );
  }

  Future<int> deletePlace(int id) async {
    final db = await instance.database;
    return await db.delete(
      'places',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> getPlaceCountInFolder(int? folderId) async {
    final db = await instance.database;
    final result = await db.query(
      'places',
      columns: ['COUNT(*) as count'],
      where: folderId == null ? 'folderId IS NULL' : 'folderId = ?',
      whereArgs: folderId == null ? null : [folderId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Tag operations
  Future<PlaceTag> createTag(PlaceTag tag) async {
    final db = await instance.database;
    final id = await db.insert('tags', tag.toMap());
    return tag.copyWith(id: id);
  }

  Future<List<PlaceTag>> readAllTags() async {
    final db = await instance.database;
    const orderBy = 'name ASC';
    final result = await db.query('tags', orderBy: orderBy);
    return result.map((json) => PlaceTag.fromMap(json)).toList();
  }

  Future<PlaceTag?> readTag(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'tags',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return PlaceTag.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateTag(PlaceTag tag) async {
    final db = await instance.database;
    return db.update(
      'tags',
      tag.toMap(),
      where: 'id = ?',
      whereArgs: [tag.id],
    );
  }

  Future<int> deleteTag(int id) async {
    final db = await instance.database;
    // Remove tag from all places
    final places = await readAllPlaces();
    for (var place in places) {
      if (place.tagIds.contains(id)) {
        final updatedTagIds = place.tagIds.where((tid) => tid != id).toList();
        await updatePlace(place.copyWith(tagIds: updatedTagIds));
      }
    }
    // Delete the tag
    return await db.delete(
      'tags',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
