import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../models/folder.dart';
import '../data/database_helper.dart';
import '../services/gemini_service.dart';
import '../services/instagram_service.dart';
import '../services/video_service.dart';
import '../services/background_processing_service.dart';

class RecipeProvider with ChangeNotifier {
  List<Recipe> _recipes = [];
  List<RecipeFolder> _folders = [];
  int? _selectedFolderId;
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
      _recipes = await DatabaseHelper.instance.readRecipesByFolder(_selectedFolderId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addRecipeFromUrl(String url) async {
    // Non-blocking loading state - we don't set _isLoading globally to avoid blocking UI
    // The BackgroundProcessingService will handle notifications
    _error = null;
    notifyListeners();

    final bgService = BackgroundProcessingService();
    await bgService.startService();
    bgService.updateNotification(title: 'Processing Recipe', content: 'Initializing...', showProgress: true, progress: 0);

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
      bgService.updateNotification(title: 'Processing Recipe', content: 'Checking connection...', showProgress: true, progress: 10);
      final hasNetwork = await _instagramService.isNetworkAvailable();
      if (!hasNetwork) {
        throw Exception('No internet connection');
      }

      // 1. Download media (video or images)
      bgService.updateNotification(title: 'Processing Recipe', content: 'Downloading media...', showProgress: true, progress: 30);
      final mediaPaths = await _instagramService.downloadInstagramPost(url);
      
      if (mediaPaths.isEmpty) {
        throw Exception('No media found in post');
      }

      final mainMediaPath = mediaPaths.first;
      // Determine if main media is video based on extension
      final isVideo = mainMediaPath.toLowerCase().endsWith('.mp4');

      // 2. Generate thumbnail (from video or use image)
      bgService.updateNotification(title: 'Processing Recipe', content: 'Generating thumbnail...', showProgress: true, progress: 50);
      
      String? thumbnailPath;
      if (isVideo) {
         thumbnailPath = await _videoService.generateThumbnail(mainMediaPath);
      } else {
        // For images, the image itself can be the thumbnail/screenshot
        thumbnailPath = mainMediaPath;
      }

      // 3. Generate Recipe using Gemini
      // Note: We might want to pass all images to Gemini if it supports it, 
      // but for now let's stick to the main one to avoid breaking API limits.
      bgService.updateNotification(title: 'Processing Recipe', content: 'Analyzing with AI...', showProgress: true, progress: 70);
      Recipe recipe = await _geminiService.generateRecipe(
        videoPath: mainMediaPath,
        authorComment: '', 
        videoUrl: url,
      );

      // 4. Get thumbnail bytes
      bgService.updateNotification(title: 'Processing Recipe', content: 'Finalizing...', showProgress: true, progress: 90);
      Uint8List? thumbnailData;
      if (thumbnailPath != null) {
        if (isVideo) {
           thumbnailData = await _videoService.getThumbnailData(thumbnailPath);
        } else {
           // For images, we might want to read bytes directly or resizing logic if needed
           // For now, assuming getThumbnailData handles generic image paths or we read file
           final file = File(thumbnailPath);
           if (await file.exists()) {
             thumbnailData = await file.readAsBytes();
           }
        }
      }

      // 5. Add metadata to recipe before saving
      final recipeWithMetadata = recipe.copyWith(
        reelId: reelId,
        screenshotPath: thumbnailPath,
        videoPath: isVideo ? mainMediaPath : null, // keep videoPath null if it's an image
        thumbnailData: thumbnailData,
        mediaPaths: mediaPaths,
      );

      // 6. Save recipe to DB
      await DatabaseHelper.instance.create(recipeWithMetadata);

      // Refresh list
      await loadRecipes();

      _error = null;
      bgService.updateNotification(title: 'Recipe Added', content: 'Successfully processed!', showProgress: false);
      // Wait a moment for the user to see "Success" then stop
      await Future.delayed(const Duration(seconds: 3));
      await bgService.stopService();

    } catch (e) {
      _error = e.toString();
      bgService.updateNotification(title: 'Error Processing Recipe', content: e.toString(), showProgress: false);
      debugPrint('Error in addRecipeFromUrl: $e');
      // Wait for user to see error?
      await Future.delayed(const Duration(seconds: 5));
      await bgService.stopService();
    } finally {
      // _isLoading = false; // Intentionally removed to prevent UI blocking
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
