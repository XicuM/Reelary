import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io' show Platform;
import '../models/recipe.dart';
import '../models/folder.dart';

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
      version: 4,
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
  dateModified $textType
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
}
