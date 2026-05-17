import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/place.dart';
import '../models/folder.dart';
import '../models/tag.dart';
import '../data/database_helper.dart';
import '../services/gemini_service.dart';
import '../services/instagram_service.dart';
import '../services/geocoding_service.dart';
import '../services/video_service.dart';
import '../models/location.dart';
import '../services/background_processing_service.dart';


class PlaceProvider with ChangeNotifier {
  List<Place> _places = [];
  List<RecipeFolder> _folders = [];
  List<PlaceTag> _tags = [];
  int? _selectedFolderId;
  int? _selectedTagId;
  bool _isLoading = false;
  String? _error;

  List<Place> get places => _places;
  List<RecipeFolder> get folders => _folders;
  List<PlaceTag> get tags => _tags;
  int? get selectedFolderId => _selectedFolderId;
  int? get selectedTagId => _selectedTagId;
  bool get isLoading => _isLoading;
  String? get error => _error;

  final GeminiService _geminiService = GeminiService();
  final InstagramService _instagramService = InstagramService();
  final VideoService _videoService = VideoService();
  final GeocodingService _geocodingService = GeocodingService();

  PlaceProvider() {
    loadPlaces();
    loadFolders();
    loadTags();
  }

  void selectFolder(int? folderId) {
    _selectedFolderId = folderId;
    _selectedTagId = null;
    loadPlaces();
  }

  void selectTag(int? tagId) {
    _selectedTagId = tagId;
    _selectedFolderId = null;
    loadPlaces();
  }

  Future<void> loadFolders() async {
    try {
      final allFolders = await DatabaseHelper.instance.readAllFolders();
      _folders = allFolders.where((folder) =>
        folder.entryType == FolderEntryType.place ||
        folder.entryType == FolderEntryType.both
      ).toList();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> loadTags() async {
    try {
      _tags = await DatabaseHelper.instance.readAllTags();

      // Initialize predefined tags if none exist
      if (_tags.isEmpty) {
        await _initializePredefinedTags();
        _tags = await DatabaseHelper.instance.readAllTags();
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> _initializePredefinedTags() async {
    final predefinedTags = [
      PlaceTag(name: 'Restaurant', icon: '🍽️', color: '#F44336'),
      PlaceTag(name: 'Travel Spot', icon: '✈️', color: '#2196F3'),
      PlaceTag(name: 'Activities', icon: '🎪', color: '#FF9800'),
      PlaceTag(name: 'Nature', icon: '🌲', color: '#4CAF50'),
    ];

    for (var tag in predefinedTags) {
      await DatabaseHelper.instance.createTag(tag);
    }
  }

  Future<void> loadPlaces() async {
    _isLoading = true;
    notifyListeners();
    try {
      if (_selectedTagId != null) {
        // Load places by tag
        _places = await DatabaseHelper.instance.readPlacesByTag(_selectedTagId!);
      } else {
        // Load places from specific folder or no folder (if null)
        _places = await DatabaseHelper.instance.readPlacesByFolder(_selectedFolderId);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addPlaceFromUrl(String url) async {
    // Non-blocking loading state - we don't set _isLoading globally to avoid blocking UI
    // The BackgroundProcessingService will handle notifications
    _error = null;
    notifyListeners();

    final bgService = BackgroundProcessingService();
    await bgService.startService();
    bgService.updateNotification(title: 'Processing Place', content: 'Initializing...', showProgress: true, progress: 0);

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

      // Check if place already exists
      final exists = await DatabaseHelper.instance.placeExistsByReelId(reelId);
      if (exists) {
        throw Exception('This place has already been added!');
      }

      // Check network connectivity first
      bgService.updateNotification(title: 'Processing Place', content: 'Checking connection...', showProgress: true, progress: 10);
      final hasNetwork = await _instagramService.isNetworkAvailable();
      if (!hasNetwork) {
        throw Exception('No internet connection');
      }

      // 1. Download media (video or images)
      bgService.updateNotification(title: 'Processing Place', content: 'Downloading media...', showProgress: true, progress: 30);
      final mediaPaths = await _instagramService.downloadInstagramPost(url);
      
      if (mediaPaths.isEmpty) {
        throw Exception('No media found in post');
      }

      final mainMediaPath = mediaPaths.first;
      final isVideo = mainMediaPath.toLowerCase().endsWith('.mp4');

      // 2. Generate thumbnail from video or use image
      bgService.updateNotification(title: 'Processing Place', content: 'Generating thumbnail...', showProgress: true, progress: 50);
      
      String? thumbnailPath;
      if (isVideo) {
        thumbnailPath = await _videoService.generateThumbnail(mainMediaPath);
      } else {
        thumbnailPath = mainMediaPath;
      }

      // 3. Use Gemini to extract place information
      bgService.updateNotification(title: 'Processing Place', content: 'Analyzing with AI...', showProgress: true, progress: 70);
      final result = await _geminiService.extractPlaces(
        videoPath: mainMediaPath,
        videoUrl: url,
      );
      
      Place place = result['place'] as Place;
      final suggestedTag = result['suggestedTag'] as String;

      // 4. Geocode locations if needed
      bgService.updateNotification(title: 'Processing Place', content: 'Geocoding locations...', showProgress: true, progress: 85);
      final geocodedLocations = <Location>[];
      for (final location in place.locations) {
        if (location.latitude == null || location.longitude == null) {
          final geocoded = await _geocodingService.getLocationFromAddress(location.address ?? location.name);
          if (geocoded != null) {
            geocodedLocations.add(geocoded);
          } else {
            geocodedLocations.add(location);
          }
        } else {
          geocodedLocations.add(location);
        }
      }
      place = place.copyWith(locations: geocodedLocations);


      // 5. Find matching tag ID
      final matchingTag = _tags.firstWhere(
        (tag) => tag.name == suggestedTag,
        orElse: () => _tags.first, // Default to first tag if not found
      );

      // 6. Add metadata (reel ID, paths, tag) and save to database
      // Get thumbnail bytes
      Uint8List? thumbnailData;
      if (thumbnailPath != null) {
         if (isVideo) {
            thumbnailData = await _videoService.getThumbnailData(thumbnailPath);
         } else {
             final file = File(thumbnailPath);
             if (await file.exists()) {
               thumbnailData = await file.readAsBytes();
             }
         }
      }

      final placeWithMetadata = place.copyWith(
        reelId: reelId,
        screenshotPath: thumbnailPath,
        videoPath: isVideo ? mainMediaPath : null,
        dateCreated: DateTime.now(),
        tagIds: matchingTag.id != null ? [matchingTag.id!] : [],
        thumbnailData: thumbnailData,
        mediaPaths: mediaPaths,
      );

      bgService.updateNotification(title: 'Processing Place', content: 'Saving...', showProgress: true, progress: 95);
      await DatabaseHelper.instance.createPlace(placeWithMetadata);

      // 7. Reload places
      await loadPlaces();

      _error = null;
      bgService.updateNotification(title: 'Place Added', content: 'Successfully processed!', showProgress: false);
      // Wait a moment for the user to see "Success" then stop
      await Future.delayed(const Duration(seconds: 3));
      await bgService.stopService();

    } catch (e) {
      _error = e.toString();
      bgService.updateNotification(title: 'Error Processing Place', content: e.toString(), showProgress: false);
      if (kDebugMode) {
        debugPrint('Error adding place: $e');
      }
      // Wait for user to see error?
      await Future.delayed(const Duration(seconds: 5));
      await bgService.stopService();
    } finally {
      // _isLoading = false; // Intentionally removed to prevent UI blocking
      notifyListeners();
    }
  }

  bool _isValidInstagramUrl(String url) {
    if (url.isEmpty) return false;
    final instagramUrlPattern = RegExp(
      r'^https?://(?:[a-z0-9-]+\.)?instagram\.com/(?:[\w.]+/(?:stories/)?)?(p|reel|tv|stories)/([\w-]+)',
      caseSensitive: false,
    );
    return instagramUrlPattern.hasMatch(url);
  }

  String? _extractReelId(String url) {
    if (url.isEmpty) return null;
    final pattern = RegExp(
      r'instagram\.com/(?:[\w.]+/(?:stories/)?)?(p|reel|tv|stories)/([\w-]+)',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(url);
    if (match != null && match.groupCount >= 2) {
      return match.group(2);
    }
    return null;
  }

  Future<void> updatePlace(Place place) async {
    try {
      await DatabaseHelper.instance.updatePlace(place);
      await loadPlaces();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<void> deletePlace(int id) async {
    try {
      await DatabaseHelper.instance.deletePlace(id);
      await loadPlaces();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<void> movePlaceToFolder(int placeId, int? folderId) async {
    try {
      final place = _places.firstWhere((r) => r.id == placeId);
      final updatedPlace = place.copyWith(folderId: folderId);
      await DatabaseHelper.instance.updatePlace(updatedPlace);
      await loadPlaces();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<void> addTagToPlace(int placeId, int tagId) async {
    try {
      final place = _places.firstWhere((p) => p.id == placeId);
      if (!place.tagIds.contains(tagId)) {
        final updatedTagIds = [...place.tagIds, tagId];
        final updatedPlace = place.copyWith(tagIds: updatedTagIds);
        await DatabaseHelper.instance.updatePlace(updatedPlace);
        await loadPlaces();
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<void> removeTagFromPlace(int placeId, int tagId) async {
    try {
      final place = _places.firstWhere((p) => p.id == placeId);
      final updatedTagIds = place.tagIds.where((id) => id != tagId).toList();
      final updatedPlace = place.copyWith(tagIds: updatedTagIds);
      await DatabaseHelper.instance.updatePlace(updatedPlace);
      await loadPlaces();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  // Tag management
  Future<void> createTag(PlaceTag tag) async {
    try {
      await DatabaseHelper.instance.createTag(tag);
      await loadTags();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<void> updateTag(PlaceTag tag) async {
    try {
      await DatabaseHelper.instance.updateTag(tag);
      await loadTags();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<void> deleteTag(int id) async {
    try {
      await DatabaseHelper.instance.deleteTag(id);
      await loadTags();
      await loadPlaces(); // Reload places since tag associations changed
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  // Folder management (same as recipe provider, but for places)
  Future<void> createFolder(RecipeFolder folder) async {
    try {
      await DatabaseHelper.instance.createFolder(folder);
      await loadFolders();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<void> updateFolder(RecipeFolder folder) async {
    try {
      await DatabaseHelper.instance.updateFolder(folder);
      await loadFolders();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<void> deleteFolder(int id) async {
    try {
      await DatabaseHelper.instance.deleteFolder(id);
      await loadFolders();
      await loadPlaces();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }
  Future<void> regenerateThumbnail(int id) async {
    try {
      final place = _places.firstWhere((p) => p.id == id);
      if (place.videoPath != null &&
          place.videoPath!.isNotEmpty &&
          File(place.videoPath!).existsSync()) {
        final thumbnailPath =
            await _videoService.generateThumbnail(place.videoPath!);
        
        final thumbnailData = thumbnailPath != null 
            ? await _videoService.getThumbnailData(thumbnailPath) 
            : null;

        final updatedPlace = place.copyWith(
          screenshotPath: thumbnailPath,
          thumbnailData: thumbnailData
        );
        await DatabaseHelper.instance.updatePlace(updatedPlace);
        await loadPlaces();
        _error = null;
      } else {
        throw Exception('Video file not found. Cannot regenerate thumbnail.');
      }
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<void> redownloadVideo(int id) async {
    try {
      final place = _places.firstWhere((p) => p.id == id);
      
      // Check network
      final hasNetwork = await _instagramService.isNetworkAvailable();
      if (!hasNetwork) {
        throw Exception('No internet connection');
      }

      // Download video
      final videoPath = await _instagramService.downloadInstagramVideo(place.videoUrl);
      
      // Generate thumbnail
      final thumbnailPath = await _videoService.generateThumbnail(videoPath);
      final thumbnailData = thumbnailPath != null 
          ? await _videoService.getThumbnailData(thumbnailPath) 
          : null;
      
      final updatedPlace = place.copyWith(
        videoPath: videoPath,
        screenshotPath: thumbnailPath,
        thumbnailData: thumbnailData,
      );
      
      await DatabaseHelper.instance.updatePlace(updatedPlace);
      await loadPlaces();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }
}