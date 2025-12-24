import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/database_helper.dart';
import '../models/folder.dart';
import '../models/tag.dart';
import '../models/recipe.dart';
import '../models/place.dart';

class DatabaseService {
  static const String _dbName = 'recipes.db';

  static Future<String> get _dbPath async {
    return join(await getDatabasesPath(), _dbName);
  }

  static Future<void> exportDatabase(BuildContext context) async {
    try {
      final dbPath = await _dbPath;
      final file = File(dbPath);

      if (await file.exists()) {
        final tempDir = await getTemporaryDirectory();
        final backupFile = File(join(tempDir.path, 'reelary_backup.db'));
        await file.copy(backupFile.path);

        final xFile = XFile(backupFile.path);
        await Share.shareXFiles(
          [xFile],
          text: 'Here is my Reelary database backup.',
        );
      } else {
        _showSnackBar(context, 'Database not found.', isError: true);
      }
    } catch (e) {
      _showSnackBar(context, 'Error exporting database: $e', isError: true);
    }
  }

  static Future<void> importDatabase(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        final pickedFile = File(result.files.single.path!);
        
        // Merge the imported database with the existing one
        await _mergeDatabase(pickedFile, context);

      } else {
        _showSnackBar(context, 'No file selected.');
      }
    } catch (e) {
      _showSnackBar(context, 'Error importing database: $e', isError: true);
    }
  }

  static Future<void> _mergeDatabase(File importedFile, BuildContext context) async {
    Database? importedDb;
    int mergedRecipes = 0;
    int mergedPlaces = 0;

    try {
      // 1. Open the imported database
      importedDb = await openDatabase(importedFile.path, readOnly: true);
      
      // 2. Merge Folders
      // Map imported Folder IDs to Local Folder IDs
      final Map<int, int> folderIdMap = {};
      final List<Map<String, dynamic>> importedFoldersMap = await importedDb.query('folders');
      final List<RecipeFolder> importedFolders = importedFoldersMap.map((e) => RecipeFolder.fromMap(e)).toList();
      
      final List<RecipeFolder> localFolders = await DatabaseHelper.instance.readAllFolders();

      for (var importedFolder in importedFolders) {
        if (importedFolder.id == null) continue;

        // Check if folder exists locally (by name and entryType)
        final existingFolder = localFolders.cast<RecipeFolder?>().firstWhere(
          (f) => f!.name == importedFolder.name && f.entryType == importedFolder.entryType,
          orElse: () => null,
        );

        if (existingFolder != null) {
          // Map to existing local ID
          folderIdMap[importedFolder.id!] = existingFolder.id!;
        } else {
          // Create new folder locally
          // Use toMap/fromMap to ensure ID is null so autoincrement works
          final newFolderMap = importedFolder.toMap();
          newFolderMap.remove('id');
          final newFolder = RecipeFolder.fromMap(newFolderMap);
          
          final createdFolder = await DatabaseHelper.instance.createFolder(newFolder);
          folderIdMap[importedFolder.id!] = createdFolder.id!;
        }
      }

      // 3. Merge Tags
      // Map imported Tag IDs to Local Tag IDs
      final Map<int, int> tagIdMap = {};
      
      // Check if 'tags' table exists in imported DB (legacy support)
      final tables = await importedDb.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='tags'");
      if (tables.isNotEmpty) {
        final List<Map<String, dynamic>> importedTagsMap = await importedDb.query('tags');
        final List<PlaceTag> importedTags = importedTagsMap.map((e) => PlaceTag.fromMap(e)).toList();
        
        final List<PlaceTag> localTags = await DatabaseHelper.instance.readAllTags();

        for (var importedTag in importedTags) {
          if (importedTag.id == null) continue;

          // Check if tag exists locally (by name)
          final existingTag = localTags.cast<PlaceTag?>().firstWhere(
            (t) => t!.name == importedTag.name,
            orElse: () => null,
          );

          if (existingTag != null) {
            tagIdMap[importedTag.id!] = existingTag.id!;
          } else {
            // Create new tag locally
            final newTagMap = importedTag.toMap();
            newTagMap.remove('id');
            final newTag = PlaceTag.fromMap(newTagMap);

            final createdTag = await DatabaseHelper.instance.createTag(newTag);
            tagIdMap[importedTag.id!] = createdTag.id!;
          }
        }
      }

      // 4. Merge Recipes
      final List<Map<String, dynamic>> importedRecipesMap = await importedDb.query('recipes');
      final List<Recipe> importedRecipes = importedRecipesMap.map((e) => Recipe.fromMap(e)).toList();

      for (var recipe in importedRecipes) {
        // Check duplication by reelId
        bool exists = false;
        if (recipe.reelId != null) {
          exists = await DatabaseHelper.instance.recipeExistsByReelId(recipe.reelId!);
        }
        
        if (!exists) {
          // Map Folder ID
          int? newFolderId;
          if (recipe.folderId != null && folderIdMap.containsKey(recipe.folderId)) {
            newFolderId = folderIdMap[recipe.folderId];
          }

          final newRecipeMap = recipe.toMap();
          newRecipeMap.remove('id');
          newRecipeMap['folderId'] = newFolderId;
          
          final newRecipe = Recipe.fromMap(newRecipeMap);

          await DatabaseHelper.instance.create(newRecipe);
          mergedRecipes++;
        }
      }

      // 5. Merge Places
      // Check if 'places' table exists
      final placeTables = await importedDb.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='places'");
      if (placeTables.isNotEmpty) {
        final List<Map<String, dynamic>> importedPlacesMap = await importedDb.query('places');
        final List<Place> importedPlaces = importedPlacesMap.map((e) => Place.fromMap(e)).toList();

        for (var place in importedPlaces) {
          // Check duplication
          bool exists = false;
          if (place.reelId != null) {
            exists = await DatabaseHelper.instance.placeExistsByReelId(place.reelId!);
          }

          if (!exists) {
            // Map Folder ID
            int? newFolderId;
            if (place.folderId != null && folderIdMap.containsKey(place.folderId)) {
              newFolderId = folderIdMap[place.folderId];
            }

            // Map Tag IDs
            final List<int> newTagIds = [];
            for (var oldTagId in place.tagIds) {
              if (tagIdMap.containsKey(oldTagId)) {
                newTagIds.add(tagIdMap[oldTagId]!);
              }
            }

            final newPlaceMap = place.toMap();
            newPlaceMap.remove('id');
            newPlaceMap['folderId'] = newFolderId;
            newPlaceMap['tagIds'] = jsonEncode(newTagIds); // Re-encode with new IDs

            final newPlace = Place.fromMap(newPlaceMap);

            await DatabaseHelper.instance.createPlace(newPlace);
            mergedPlaces++;
          }
        }
      }

      _showSnackBar(context, 'Merge Complete: Added $mergedRecipes recipes and $mergedPlaces places.');

    } catch (e) {
      _showSnackBar(context, 'Error merging database: $e', isError: true);
    } finally {
      await importedDb?.close();
    }
  }

  static void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }
}
