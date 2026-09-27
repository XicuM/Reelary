import 'package:flutter/foundation.dart';
import '../models/recipe.dart';
import '../models/folder.dart';
import '../data/database_helper.dart';
import '../services/gemini_service.dart';
import '../services/media_service.dart';
import '../services/video_service.dart';
import '../services/background_processing_service.dart';

class RecipeProvider with ChangeNotifier {
  List<Recipe> _recipes = [];
  List<RecipeFolder> _folders = [];
  bool _isLoading = false;
  String? _error;

  List<Recipe> get recipes => _recipes;
  List<RecipeFolder> get folders => _folders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  final GeminiService _geminiService = GeminiService();
  final MediaService _mediaService = MediaService();
  final VideoService _videoService = VideoService();

  RecipeProvider() {
    loadRecipes();
    loadFolders();
  }

  Future<void> loadFolders() async {
    try {
      _folders = await DatabaseHelper.instance.readAllFolders();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> loadRecipes({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      _recipes = await DatabaseHelper.instance.readAllRecipes();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Saves a recipe from media that has already been downloaded.
  Future<void> savePrepared({
    required String url,
    required String reelId,
    required List<String> mediaPaths,
    required String mainMediaPath,
    required bool isVideo,
    required String? thumbnailPath,
    required Uint8List? thumbnailData,
    int? folderId,
  }) async {
    BackgroundProcessingService().updateNotification(
      title: 'Saving post',
      content: 'Analyzing with AI...',
      showProgress: true,
      progress: 70,
    );
    final recipe = await _geminiService.generateRecipe(
      mediaPaths: mediaPaths,
      authorComment: '',
      videoUrl: url,
    );

    await DatabaseHelper.instance.create(recipe.copyWith(
      reelId: reelId,
      screenshotPath: thumbnailPath,
      videoPath: isVideo ? mainMediaPath : null,
      thumbnailData: thumbnailData,
      mediaPaths: mediaPaths,
      folderId: folderId,
    ));
    await loadRecipes(silent: true);
  }

  Future<void> updateRecipe(Recipe recipe) async {
    try {
      await DatabaseHelper.instance.update(recipe);
      await loadRecipes(silent: true);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteRecipe(int id) async {
    await DatabaseHelper.instance.delete(id);
    await loadRecipes(silent: true);
  }

  Future<void> moveRecipeToFolder(int recipeId, int? folderId) async {
    try {
      final recipe = _recipes.firstWhere((r) => r.id == recipeId);
      final updatedRecipe = recipe.copyWith(folderId: folderId);
      await DatabaseHelper.instance.update(updatedRecipe);
      await loadRecipes(silent: true);
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
      await loadRecipes(silent: true);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<int> getFolderRecipeCount(int? folderId) async {
    return await DatabaseHelper.instance.getRecipeCountInFolder(folderId);
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
      if (!await _mediaService.isNetworkAvailable()) {
        throw Exception('No internet connection');
      }

      // Download
      final videoPath = (await _mediaService.downloadPost(recipe.videoUrl)).first;
      
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

}
