import 'dart:io';
import 'dart:ui';
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
import '../services/gemini_service.dart';

class PlaceDetailScreen extends StatefulWidget {
  final Place place;

  const PlaceDetailScreen({super.key, required this.place});

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  late Place _currentPlace;
  List<PlaceTag> _tags = [];
  late PageController _pageController;
  int _activePage = 0;
  bool _isRegenerating = false;

  @override
  void initState() {
    super.initState();
    _currentPlace = widget.place;
    _pageController = PageController();
    _loadTags();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadTags() async {
    final allTags = await DatabaseHelper.instance.readAllTags();
    setState(() {
      _tags = allTags.where((tag) => _currentPlace.tagIds.contains(tag.id)).toList();
    });
  }

  // ... (existing code)

  Widget _buildMediaSection(BuildContext context, ColorScheme colorScheme) {
    final theme = Theme.of(context);

    if (_currentPlace.mediaPaths.length > 1) {
      // Carousel View
      return Column(
        children: [
          SizedBox(
            height: 400, // Taller size for carousel
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      dragDevices: {
                        PointerDeviceKind.touch,
                        PointerDeviceKind.mouse,
                      },
                    ),
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() {
                          _activePage = index;
                        });
                      },
                      itemCount: _currentPlace.mediaPaths.length,
                      itemBuilder: (context, index) {
                        final path = _currentPlace.mediaPaths[index];
                        if (File(path).existsSync()) {
                          return Image.file(
                            File(path),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                    color: colorScheme.surfaceContainerHighest,
                                    child: const Icon(Icons.broken_image)),
                          );
                        } else {
                          return Container(
                            color: colorScheme.surfaceContainerHighest,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image,
                                    color: colorScheme.outline),
                                const Text('Image missing'),
                              ],
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ),
                // Previous Button
                if (_activePage > 0)
                  Positioned(
                    left: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: IconButton(
                        onPressed: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        icon: const Icon(Icons.chevron_left),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.5),
                          foregroundColor: Colors.white,
                          hoverColor: Colors.black.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
                // Next Button
                if (_activePage < _currentPlace.mediaPaths.length - 1)
                  Positioned(
                    right: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: IconButton(
                        onPressed: () {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        icon: const Icon(Icons.chevron_right),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.5),
                          foregroundColor: Colors.white,
                          hoverColor: Colors.black.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Simple Dots Indicator (visual only for now)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_currentPlace.mediaPaths.length, (index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _activePage == index
                      ? colorScheme.primary
                      : colorScheme.primary.withValues(alpha: 0.3),
                ),
              );
            }),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              '${_currentPlace.mediaPaths.length} Images',
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: colorScheme.outline),
            ),
          ),
        ],
      );
    }

    // Single Image Fallback
    return Column(
      children: [
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
              ],
            ),
          ),
        const SizedBox(height: 16),

        // Watch Video Button
        if (_currentPlace.videoPath != null &&
            _currentPlace.videoPath!.isNotEmpty &&
            File(_currentPlace.videoPath!).existsSync())
          FilledButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VideoPlayerScreen(
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Download started in the background...'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
              await Provider.of<PlaceProvider>(context, listen: false)
                  .redownloadVideo(_currentPlace.id!);
              await _refreshPlace();
            },
            icon: const Icon(Icons.download),
            label: const Text('Download Media'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              backgroundColor: colorScheme.errorContainer,
              foregroundColor: colorScheme.onErrorContainer,
            ),
          ),
      ],
    );
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

  Future<void> _regenerateDescriptionWithAI() async {
    setState(() => _isRegenerating = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Regenerating description with AI...')),
    );
    try {
      final geminiService = GeminiService();
      final newDescription = await geminiService.regeneratePlaceDescription(
        mediaPaths: _currentPlace.mediaPaths,
        videoPath: _currentPlace.videoPath,
        currentTitle: _currentPlace.title,
        currentDescription: _currentPlace.description,
      );

      final updatedPlace = _currentPlace.copyWith(description: newDescription);
      await Provider.of<PlaceProvider>(context, listen: false).updatePlace(updatedPlace);
      
      await _refreshPlace();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Description regenerated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to regenerate description: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRegenerating = false);
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
      appBar: AppBar(
        title: Text(_currentPlace.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Regenerate with AI',
            onPressed: _regenerateDescriptionWithAI,
          ),
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
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
    
              if (isWide) {
                // 2-Column Layout for Desktop/Wide Screens
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Media (Fixed Width or Flex)
                    SizedBox(
                      width: 400, // Fixed width for media
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _buildMediaSection(context, colorScheme),
                            const SizedBox(height: 16),
                            _buildTagsSection(colorScheme),
                             const SizedBox(height: 16),
                             _buildSourceCard(context, colorScheme, theme),
                          ],
                        ),
                      ),
                    ),
                    // Vertical Divider
                    const VerticalDivider(width: 1),
                    // Right Column: Content (Expanded)
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_currentPlace.description.isNotEmpty) ...[
                              _buildDescriptionSection(theme),
                              const SizedBox(height: 24),
                            ],
                            _buildLocationsSection(context, theme, colorScheme),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              } else {
                // Standard Single Column Layout
                return SingleChildScrollView(
                   padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       _buildMediaSection(context, colorScheme),
                       const SizedBox(height: 16),
                       _buildTagsSection(colorScheme),
                       const SizedBox(height: 16),
                       _buildSourceCard(context, colorScheme, theme),
                       const SizedBox(height: 24),
                      if (_currentPlace.description.isNotEmpty) ...[
                         _buildDescriptionSection(theme),
                         const SizedBox(height: 24),
                      ],
                      _buildLocationsSection(context, theme, colorScheme),
                      const SizedBox(height: 32),
                    ],
                  ),
                );
              }
            },
          ),
          if (_isRegenerating)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }




  Widget _buildTagsSection(ColorScheme colorScheme) {
    if (_tags.isEmpty) return const SizedBox.shrink();
    return Wrap(
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
    );
  }

  Widget _buildSourceCard(BuildContext context, ColorScheme colorScheme, ThemeData theme) {
    return Card(
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
    );
  }

  Widget _buildDescriptionSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
      ],
    );
  }

  Widget _buildLocationsSection(BuildContext context, ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
      ],
    );
  }
}
