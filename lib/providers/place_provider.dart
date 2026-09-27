import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/place.dart';
import '../models/folder.dart';
import '../models/tag.dart';
import '../data/database_helper.dart';
import '../services/gemini_service.dart';
import '../services/media_service.dart';
import '../services/geocoding_service.dart';
import '../services/video_service.dart';
import '../models/location.dart';
import '../services/background_processing_service.dart';


class PlaceProvider with ChangeNotifier {
  List<Place> _places = [];
  List<RecipeFolder> _folders = [];
  List<PlaceTag> _tags = [];
  bool _isLoading = false;
  String? _error;

  List<Place> get places => _places;
  List<RecipeFolder> get folders => _folders;
  List<PlaceTag> get tags => _tags;
  bool get isLoading => _isLoading;
  String? get error => _error;

  final GeminiService _geminiService = GeminiService();
  final MediaService _mediaService = MediaService();
  final VideoService _videoService = VideoService();
  final GeocodingService _geocodingService = GeocodingService();

  PlaceProvider() {
    loadPlaces();
    loadFolders();
    loadTags();
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

  Future<void> loadPlaces({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      _places = await DatabaseHelper.instance.readAllPlaces();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Saves a place from media that has already been downloaded.
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
    final bgService = BackgroundProcessingService();
    bgService.updateNotification(
      title: 'Saving post',
      content: 'Analyzing with AI...',
      showProgress: true,
      progress: 70,
    );

    final result = await _geminiService.extractPlaces(
      videoPath: mainMediaPath,
      videoUrl: url,
    );

    Place place = result['place'] as Place;
    final suggestedTag = result['suggestedTag'] as String;

    bgService.updateNotification(
      title: 'Saving post',
      content: 'Geocoding locations...',
      showProgress: true,
      progress: 85,
    );
    final geocodedLocations = <Location>[];
    for (final location in place.locations) {
      if (location.latitude == null || location.longitude == null) {
        final geocoded = await _geocodingService.getLocationFromAddress(
          location.address ?? location.name,
        );
        geocodedLocations.add(geocoded ?? location);
      } else {
        geocodedLocations.add(location);
      }
    }
    place = place.copyWith(locations: geocodedLocations);

    final matchingTag = _tags.cast<PlaceTag?>().firstWhere(
          (tag) => tag!.name == suggestedTag,
          orElse: () => _tags.isEmpty ? null : _tags.first,
        );

    await DatabaseHelper.instance.createPlace(place.copyWith(
      reelId: reelId,
      screenshotPath: thumbnailPath,
      videoPath: isVideo ? mainMediaPath : null,
      dateCreated: DateTime.now(),
      tagIds: matchingTag?.id != null ? [matchingTag!.id!] : [],
      thumbnailData: thumbnailData,
      mediaPaths: mediaPaths,
      folderId: folderId,
    ));
    await loadPlaces(silent: true);
  }



  Future<void> updatePlace(Place place) async {
    try {
      await DatabaseHelper.instance.updatePlace(place);
      await loadPlaces(silent: true);
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<void> deletePlace(int id) async {
    try {
      await DatabaseHelper.instance.deletePlace(id);
      await loadPlaces(silent: true);
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
      await loadPlaces(silent: true);
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
        await loadPlaces(silent: true);
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
      await loadPlaces(silent: true);
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
      await loadPlaces(silent: true); // Reload places since tag associations changed
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
      await loadPlaces(silent: true);
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
        await loadPlaces(silent: true);
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
      final hasNetwork = await _mediaService.isNetworkAvailable();
      if (!hasNetwork) {
        throw Exception('No internet connection');
      }

      // Download video
      final videoPath = (await _mediaService.downloadPost(place.videoUrl)).first;
      
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
      await loadPlaces(silent: true);
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }
}