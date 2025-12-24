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


class PlaceProvider with ChangeNotifier {
  List<Place> _places = [];
  List<RecipeFolder> _folders = [];
  List<PlaceTag> _tags = [];
  int? _selectedFolderId = -1;
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
      } else if (_selectedFolderId != null || _selectedFolderId == -1) {
        // Load places from specific folder or all places
        _places = _selectedFolderId == -1
            ? await DatabaseHelper.instance.readAllPlaces()
            : await DatabaseHelper.instance.readPlacesByFolder(_selectedFolderId);
      } else {
        // Load places without folder (default view)
        _places = await DatabaseHelper.instance.readPlacesByFolder(null);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addPlaceFromUrl(String url) async {
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

      // Check if place already exists
      final exists = await DatabaseHelper.instance.placeExistsByReelId(reelId);
      if (exists) {
        throw Exception('This place has already been added!');
      }

      // Check network connectivity first
      final hasNetwork = await _instagramService.isNetworkAvailable();
      if (!hasNetwork) {
        throw Exception('No internet connection');
      }

      // 1. Download video using RapidAPI-based service
      final videoPath = await _instagramService.downloadInstagramVideo(url);

      // 2. Generate thumbnail from video
      final thumbnailPath = await _videoService.generateThumbnail(videoPath);

      // 3. Use Gemini to extract place information
      final result = await _geminiService.extractPlaces(
        videoPath: videoPath,
        videoUrl: url,
      );
      
      Place place = result['place'] as Place;
      final suggestedTag = result['suggestedTag'] as String;

      // 4. Geocode locations if needed
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
      final placeWithMetadata = place.copyWith(
        reelId: reelId,
        screenshotPath: thumbnailPath,
        videoPath: videoPath,
        dateCreated: DateTime.now(),
        tagIds: matchingTag.id != null ? [matchingTag.id!] : [],
      );

      await DatabaseHelper.instance.createPlace(placeWithMetadata);

      // 7. Reload places
      await loadPlaces();

      _error = null;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        debugPrint('Error adding place: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool _isValidInstagramUrl(String url) {
    final instagramUrlPattern =
        RegExp(r'^https?://(www\.)?instagram\.com/(p|reel|tv|stories)/[\w-]+/?');
    return instagramUrlPattern.hasMatch(url);
  }

  String? _extractReelId(String url) {
    final pattern = RegExp(r'/(p|reel|tv|stories)/([\w-]+)');
    final match = pattern.firstMatch(url);
    return match?.group(2);
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
        final updatedPlace = place.copyWith(screenshotPath: thumbnailPath);
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
      
      final updatedPlace = place.copyWith(
        videoPath: videoPath,
        screenshotPath: thumbnailPath,
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