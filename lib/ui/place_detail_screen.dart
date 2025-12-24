import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/place.dart';
import '../models/tag.dart';
import '../models/location.dart';
import '../data/database_helper.dart';
import 'video_player_screen.dart';
import 'place_editor_screen.dart';
import 'place_map_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../providers/place_provider.dart';

class PlaceDetailScreen extends StatefulWidget {
  final Place place;

  const PlaceDetailScreen({super.key, required this.place});

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  late Place _currentPlace;
  List<PlaceTag> _tags = [];

  @override
  void initState() {
    super.initState();
    _currentPlace = widget.place;
    _loadTags();
  }

  Future<void> _loadTags() async {
    final allTags = await DatabaseHelper.instance.readAllTags();
    setState(() {
      _tags = allTags.where((tag) => _currentPlace.tagIds.contains(tag.id)).toList();
    });
  }

  Future<void> _refreshPlace() async {
    if (widget.place.id != null) {
      final updated = await DatabaseHelper.instance.readPlace(widget.place.id!);
      if (updated != null && mounted) {
        setState(() {
          _currentPlace = updated;
        });
        await _loadTags();
      }
    }
  }

  String _buildPlaceText() {
    final buffer = StringBuffer();
    buffer.writeln('📍 ${_currentPlace.title}');
    buffer.writeln();
    if (_currentPlace.description.isNotEmpty) {
      buffer.writeln(_currentPlace.description);
      buffer.writeln();
    }
    buffer.writeln('🗺️ Locations:');
    for (var i = 0; i < _currentPlace.locations.length; i++) {
      final location = _currentPlace.locations[i];
      buffer.writeln('${i + 1}. ${location.name}');
      if (location.address != null && location.address!.isNotEmpty) {
        buffer.writeln('   ${location.address}');
      }
      buffer.writeln('   ${location.googleMapsUrl}');
    }
    buffer.writeln();
    buffer.writeln('Created with Reelary by Xicu Marí');
    return buffer.toString();
  }

  Future<void> _sharePlace() async {
    try {
      final text = _buildPlaceText();
      final filesToShare = <XFile>[];
      
      if (_currentPlace.videoPath != null &&
          _currentPlace.videoPath!.isNotEmpty &&
          File(_currentPlace.videoPath!).existsSync()) {
        filesToShare.add(XFile(_currentPlace.videoPath!));
      } else if (_currentPlace.screenshotPath != null &&
                 _currentPlace.screenshotPath!.isNotEmpty &&
                 File(_currentPlace.screenshotPath!).existsSync()) {
        filesToShare.add(XFile(_currentPlace.screenshotPath!));
      }
      
      if (filesToShare.isNotEmpty) {
        await SharePlus.instance.share(
          ShareParams(
            files: filesToShare,
            text: text,
          ),
        );
      } else {
        await SharePlus.instance.share(
          ShareParams(text: text),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _copyToClipboard() async {
    try {
      final text = _buildPlaceText();
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Place info copied to clipboard!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error copying: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openInMaps(Location location) async {
    try {
      final url = Uri.parse(location.googleMapsUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open maps'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening maps: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }



  LatLng _getMapCenter(List<Location> locations) {
    if (locations.isEmpty) {
      return const LatLng(0, 0);
    }
    
    double lat = 0;
    double lng = 0;
    int count = 0;
    
    for (final loc in locations) {
      if (loc.latitude != null && loc.longitude != null) {
        lat += loc.latitude!;
        lng += loc.longitude!;
        count++;
      }
    }
    
    if (count == 0) return const LatLng(0, 0);
    
    return LatLng(lat / count, lng / count);
  }

  // Helper to get markers
  Set<Marker> _getLocationMarkers(List<Location> locations) {
    final markers = <Marker>{};
    for (var i = 0; i < locations.length; i++) {
      final loc = locations[i];
      if (loc.latitude != null && loc.longitude != null) {
        markers.add(
          Marker(
            markerId: MarkerId('loc_$i'),
            position: LatLng(loc.latitude!, loc.longitude!),
            infoWindow: InfoWindow(title: loc.name, snippet: loc.address ?? ""),
          ),
        );
      }
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar with Place Title
          SliverAppBar.large(
            title: Text(_currentPlace.title),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Edit Place',
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlaceEditorScreen(place: _currentPlace),
                    ),
                  );
                  if (result == true) {
                    await _refreshPlace();
                  }
                },
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.share),
                tooltip: 'Share',
                onSelected: (value) {
                  if (value == 'share') {
                    _sharePlace();
                  } else if (value == 'copy') {
                    _copyToClipboard();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'share',
                    child: Row(
                      children: [
                        Icon(Icons.share),
                        SizedBox(width: 12),
                        Text('Share'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'copy',
                    child: Row(
                      children: [
                        Icon(Icons.copy),
                        SizedBox(width: 12),
                        Text('Copy to Clipboard'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Place Content
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail Image
                if (_currentPlace.thumbnailData != null)
                  Image.memory(
                    _currentPlace.thumbnailData!,
                    width: double.infinity,
                    height: 250,
                    fit: BoxFit.cover,
                  )
                else if (_currentPlace.screenshotPath != null &&
                    _currentPlace.screenshotPath!.isNotEmpty &&
                    File(_currentPlace.screenshotPath!).existsSync())
                  Image.file(
                    File(_currentPlace.screenshotPath!),
                    width: double.infinity,
                    height: 250,
                    fit: BoxFit.cover,
                  )
                 else
                    Container(
                      width: double.infinity,
                      height: 250,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.broken_image, size: 64),
                          TextButton.icon(
                            onPressed: () async {
                              await Provider.of<PlaceProvider>(context, listen: false)
                                  .regenerateThumbnail(_currentPlace.id!);
                              await _refreshPlace();
                            },
                             icon: const Icon(Icons.refresh),
                             label: const Text('Regenerate Thumbnail'),
                          ),
                        ],
                      ),
                    ),

                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tags
                      if (_tags.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _tags.map((tag) {
                            final color = Color(int.parse('0xFF${tag.color.substring(1)}'));
                            return Chip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(tag.icon),
                                  const SizedBox(width: 4),
                                  Text(tag.name),
                                ],
                              ),
                              backgroundColor: color.withValues(alpha: 0.2),
                              side: BorderSide(color: color),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Watch Video Button
                      if (_currentPlace.videoPath != null &&
                          _currentPlace.videoPath!.isNotEmpty &&
                          File(_currentPlace.videoPath!).existsSync())
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    VideoPlayerScreen(
                                      videoPath: _currentPlace.videoPath!,
                                      title: _currentPlace.title,
                                    ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Watch Original Video'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        )
                       else
                        FilledButton.icon(
                          onPressed: () async {
                             await Provider.of<PlaceProvider>(context, listen: false)
                                  .redownloadVideo(_currentPlace.id!);
                             await _refreshPlace();
                          },
                          icon: const Icon(Icons.download),
                          label: const Text('Redownload Video'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            backgroundColor: colorScheme.errorContainer,
                            foregroundColor: colorScheme.onErrorContainer,
                          ),
                        ),

                      const SizedBox(height: 16),

                      // Source Card
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.link),
                          title: const Text('Instagram Source'),
                          subtitle: Text(
                            _currentPlace.videoUrl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: () async {
                              await Clipboard.setData(
                                  ClipboardData(text: _currentPlace.videoUrl));
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('URL copied to clipboard'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                          ),
                          onTap: () async {
                            final url = Uri.parse(_currentPlace.videoUrl);
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url, mode: LaunchMode.externalApplication);
                            }
                          },
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Description
                      if (_currentPlace.description.isNotEmpty) ...[
                        Text(
                          'Description',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _currentPlace.description,
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Locations Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Locations (${_currentPlace.locations.length})',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_currentPlace.locations.isNotEmpty)
                            FilledButton.tonalIcon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PlaceMapScreen(
                                      locations: _currentPlace.locations,
                                      placeTitle: _currentPlace.title,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.map, size: 18),
                              label: const Text('View Map'),
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Location Cards
                      ...List.generate(_currentPlace.locations.length, (index) {
                        final location = _currentPlace.locations[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${index + 1}',
                                          style: TextStyle(
                                            color: colorScheme.onPrimary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        location.name,
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (location.address != null && location.address!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on, size: 16),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          location.address!,
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                if (location.latitude != null && location.longitude != null) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.pin_drop, size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${location.latitude!.toStringAsFixed(6)}, ${location.longitude!.toStringAsFixed(6)}',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  onPressed: () => _openInMaps(location),
                                  icon: const Icon(Icons.map),
                                  label: const Text('Open in Google Maps'),
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size(double.infinity, 40),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                        // Inline Google Map visualization
                        if (_currentPlace.locations.any((loc) => loc.latitude != null && loc.longitude != null))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: SizedBox(
                              height: 220,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: GoogleMap(
                                  initialCameraPosition: CameraPosition(
                                    target: _getMapCenter(_currentPlace.locations),
                                    zoom: _currentPlace.locations.length == 1 ? 15 : 12,
                                  ),
                                  markers: _getLocationMarkers(_currentPlace.locations),
                                  myLocationButtonEnabled: false,
                                  zoomControlsEnabled: true,
                                  mapToolbarEnabled: false,
                                ),
                              ),
                            ),
                          ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
