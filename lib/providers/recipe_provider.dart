import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../models/folder.dart';
import '../data/database_helper.dart';
import '../services/gemini_service.dart';
import '../services/instagram_service.dart';
import '../services/video_service.dart';

class RecipeProvider with ChangeNotifier {
  List<Recipe> _recipes = [];
  List<RecipeFolder> _folders = [];
  int? _selectedFolderId = -1;
  bool _isLoading = false;
  String? _error;

  List<Recipe> get recipes => _recipes;
  List<RecipeFolder> get folders => _folders;
  int? get selectedFolderId => _selectedFolderId;
  bool get isLoading => _isLoading;
  String? get error => _error;

  final GeminiService _geminiService = GeminiService();
  final InstagramService _instagramService = InstagramService();
  final VideoService _videoService = VideoService();

  RecipeProvider() {
    loadRecipes();
    loadFolders();
  }

  void selectFolder(int? folderId) {
    _selectedFolderId = folderId;
    loadRecipes();
  }

  Future<void> loadFolders() async {
    try {
      final allFolders = await DatabaseHelper.instance.readAllFolders();
      _folders = allFolders.where((folder) => 
        folder.entryType == FolderEntryType.recipe || 
        folder.entryType == FolderEntryType.both
      ).toList();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> loadRecipes() async {
    _isLoading = true;
    notifyListeners();
    try {
      if (_selectedFolderId != null || _selectedFolderId == -1) {
        // Load recipes from specific folder or all recipes
        _recipes = _selectedFolderId == -1
            ? await DatabaseHelper.instance.readAllRecipes()
            : await DatabaseHelper.instance
                .readRecipesByFolder(_selectedFolderId);
      } else {
        // Load recipes without folder (default view)
        _recipes = await DatabaseHelper.instance.readRecipesByFolder(null);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addRecipeFromUrl(String url) async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Validate Instagram URL format
      if (!_isValidInstagramUrl(url)) {
        throw Exception(
            'Invalid Instagram URL. Please provide a valid Instagram post, reel, or story URL.\nExample: https://www.instagram.com/reel/ABC123/');
      }

      // Extract reel ID from URL
      final reelId = _extractReelId(url);
      if (reelId == null) {
        throw Exception('Could not extract reel ID from URL');
      }

      // Check if recipe already exists
      final exists = await DatabaseHelper.instance.recipeExistsByReelId(reelId);
      if (exists) {
        throw Exception('This recipe has already been added!');
      }

      // Check network connectivity first
      final hasNetwork = await _instagramService.isNetworkAvailable();
      if (!hasNetwork) {
        throw Exception('No internet connection');
      }

      // 1. Download video using RapidAPI-based service
      // This method uses a third-party API for cross-platform compatibility
      final videoPath = await _instagramService.downloadInstagramVideo(url);

      // 2. Generate thumbnail from video
      final thumbnailPath = await _videoService.generateThumbnail(videoPath);

      // 3. Generate Recipe using Gemini
      // Note: We don't extract the author's comment in this version,
      // so Gemini will analyze just the video content
      Recipe recipe = await _geminiService.generateRecipe(
        videoPath: videoPath,
        authorComment: '', // Could be extracted via API metadata in future
        videoUrl: url,
      );

      // 4. Get thumbnail bytes
      final thumbnailData = await _videoService.getThumbnailData(thumbnailPath!);

      // 5. Add metadata to recipe before saving
      final recipeWithMetadata = recipe.copyWith(
        reelId: reelId,
        screenshotPath: thumbnailPath,
        videoPath: videoPath,
        thumbnailData: thumbnailData,
      );

      // 5. Save recipe to DB
      await DatabaseHelper.instance.create(recipeWithMetadata);

      // Refresh list
      await loadRecipes();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error in addRecipeFromUrl: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateRecipe(Recipe recipe) async {
    try {
      await DatabaseHelper.instance.update(recipe);
      await loadRecipes();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteRecipe(int id) async {
    await DatabaseHelper.instance.delete(id);
    await loadRecipes();
  }

  Future<void> moveRecipeToFolder(int recipeId, int? folderId) async {
    try {
      final recipe = _recipes.firstWhere((r) => r.id == recipeId);
      final updatedRecipe = recipe.copyWith(folderId: folderId);
      await DatabaseHelper.instance.update(updatedRecipe);
      await loadRecipes();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Folder management methods
  Future<void> createFolder(String name, String emoji, {FolderEntryType entryType = FolderEntryType.recipe}) async {
    try {
      final folder = RecipeFolder(
        name: name,
        emoji: emoji,
        dateCreated: DateTime.now(),
        dateModified: DateTime.now(),
        entryType: entryType,
      );
      await DatabaseHelper.instance.createFolder(folder);
      await loadFolders();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateFolder(int id, String name, String emoji) async {
    try {
      final folder = _folders.firstWhere((f) => f.id == id);
      final updatedFolder = folder.copyWith(
          entryType: folder.entryType,
        name: name,
        emoji: emoji,
        dateModified: DateTime.now(),
      );
      await DatabaseHelper.instance.updateFolder(updatedFolder);
      await loadFolders();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteFolder(int id) async {
    try {
      await DatabaseHelper.instance.deleteFolder(id);
      await loadFolders();
      await loadRecipes();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<int> getFolderRecipeCount(int? folderId) async {
    return await DatabaseHelper.instance.getRecipeCountInFolder(folderId);
  }

  /// Validates if the provided URL is a valid Instagram URL
  bool _isValidInstagramUrl(String url) {
    if (url.isEmpty) return false;

    // Check if URL contains instagram.com domain
    if (!url.contains('instagram.com')) return false;

    // Valid Instagram URL patterns:
    // - https://www.instagram.com/p/POST_ID/
    // - https://www.instagram.com/reel/REEL_ID/
    // - https://www.instagram.com/tv/TV_ID/
    // - https://instagram.com/p/POST_ID/
    // - Can include query parameters: ?utm_source=...

    final instagramUrlPattern = RegExp(
      r'^https?://(www\.)?instagram\.com/(p|reel|tv|stories)/[\w-]+/?',
      caseSensitive: false,
    );

    return instagramUrlPattern.hasMatch(url);
  }

  Future<void> regenerateThumbnail(int recipeId) async {
    try {
      final recipe = _recipes.firstWhere((r) => r.id == recipeId);
      final videoPath = await _videoService.getVideoPath(recipe.videoPath);
      
      if (videoPath != null) {
        final thumbnailPath = await _videoService.generateThumbnail(videoPath);
        if (thumbnailPath != null) {
          final thumbnailData = await _videoService.getThumbnailData(thumbnailPath);
          final updatedRecipe = recipe.copyWith(
            screenshotPath: thumbnailPath,
            thumbnailData: thumbnailData,
          );
          await updateRecipe(updatedRecipe);
        }
      }
    } catch (e) {
      _error = 'Failed to regenerate thumbnail: $e';
      notifyListeners();
    }
  }

  Future<void> redownloadVideo(int recipeId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final recipe = _recipes.firstWhere((r) => r.id == recipeId);
      
      // Check network
      if (!await _instagramService.isNetworkAvailable()) {
        throw Exception('No internet connection');
      }

      // Download
      final videoPath = await _instagramService.downloadInstagramVideo(recipe.videoUrl);
      
      // Regenerate thumbnail while we're at it
      final thumbnailPath = await _videoService.generateThumbnail(videoPath);
      final thumbnailData = thumbnailPath != null 
          ? await _videoService.getThumbnailData(thumbnailPath) 
          : null;

      final updatedRecipe = recipe.copyWith(
        videoPath: videoPath,
        screenshotPath: thumbnailPath ?? recipe.screenshotPath,
        thumbnailData: thumbnailData ?? recipe.thumbnailData,
      );
      
      await updateRecipe(updatedRecipe);
    } catch (e) {
      _error = 'Failed to redownload video: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Extracts the reel/post ID from an Instagram URL
  String? _extractReelId(String url) {
    // Pattern to extract ID from URLs like:
    // https://www.instagram.com/reel/ABC123/
    // https://instagram.com/p/XYZ789/
    // https://www.instagram.com/tv/DEF456/?utm_source=...
    final pattern = RegExp(
      r'instagram\.com/(p|reel|tv|stories)/([\w-]+)',
      caseSensitive: false,
    );

    final match = pattern.firstMatch(url);
    if (match != null && match.groupCount >= 2) {
      return match.group(2); // Return the ID part
    }
    return null;
  }
}
