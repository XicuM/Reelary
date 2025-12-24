import 'dart:convert';
import 'dart:typed_data';
import 'location.dart';

class Place {
  final int? id;
  final String title;
  final String videoUrl;
  final String? screenshotPath;
  final String? videoPath;
  final List<Location> locations;
  final String description;
  final DateTime dateCreated;
  final int? folderId;
  final String? reelId;
  final List<int> tagIds; // References to PlaceTag ids
  final Uint8List? thumbnailData;

  Place({
    this.id,
    required this.title,
    required this.videoUrl,
    this.screenshotPath,
    this.videoPath,
    required this.locations,
    required this.description,
    required this.dateCreated,
    this.folderId,
    this.reelId,
    this.tagIds = const [],
    this.thumbnailData,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'videoUrl': videoUrl,
      'screenshotPath': screenshotPath,
      'videoPath': videoPath,
      'locations': jsonEncode(locations.map((loc) => loc.toMap()).toList()),
      'description': description,
      'dateCreated': dateCreated.toIso8601String(),
      'folderId': folderId,
      'reelId': reelId,
      'tagIds': jsonEncode(tagIds),
      'thumbnailData': thumbnailData,
    };
  }

  factory Place.fromMap(Map<String, dynamic> map) {
    final locationsJson = jsonDecode(map['locations'] as String) as List;
    final locations = locationsJson
        .map((json) => Location.fromMap(json as Map<String, dynamic>))
        .toList();

    final tagIdsJson = map['tagIds'] as String?;
    final tagIds = tagIdsJson != null 
        ? List<int>.from(jsonDecode(tagIdsJson) as List)
        : <int>[];

    return Place(
      id: map['id'] as int?,
      title: map['title'] as String,
      videoUrl: map['videoUrl'] as String,
      screenshotPath: map['screenshotPath'] as String?,
      videoPath: map['videoPath'] as String?,
      locations: locations,
      description: map['description'] as String,
      dateCreated: DateTime.parse(map['dateCreated'] as String),
      folderId: map['folderId'] as int?,
      reelId: map['reelId'] as String?,
      tagIds: tagIds,
      thumbnailData: map['thumbnailData'],
    );
  }

  Place copyWith({
    int? id,
    String? title,
    String? videoUrl,
    String? screenshotPath,
    String? videoPath,
    List<Location>? locations,
    String? description,
    DateTime? dateCreated,
    int? folderId,
    String? reelId,
    List<int>? tagIds,
    Uint8List? thumbnailData,
  }) {
    return Place(
      id: id ?? this.id,
      title: title ?? this.title,
      videoUrl: videoUrl ?? this.videoUrl,
      screenshotPath: screenshotPath ?? this.screenshotPath,
      videoPath: videoPath ?? this.videoPath,
      locations: locations ?? this.locations,
      description: description ?? this.description,
      dateCreated: dateCreated ?? this.dateCreated,
      folderId: folderId ?? this.folderId,
      reelId: reelId ?? this.reelId,
      tagIds: tagIds ?? this.tagIds,
      thumbnailData: thumbnailData ?? this.thumbnailData,
    );
  }
}
