import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/location.dart';

class PlaceMapScreen extends StatefulWidget {
  final List<Location> locations;
  final String placeTitle;

  const PlaceMapScreen({
    super.key,
    required this.locations,
    required this.placeTitle,
  });

  @override
  State<PlaceMapScreen> createState() => _PlaceMapScreenState();
}

class _PlaceMapScreenState extends State<PlaceMapScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  Location? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _createMarkers();
  }

  void _createMarkers() {
    for (var i = 0; i < widget.locations.length; i++) {
      final location = widget.locations[i];
      if (location.latitude != null && location.longitude != null) {
        _markers.add(
          Marker(
            markerId: MarkerId('location_$i'),
            position: LatLng(location.latitude!, location.longitude!),
            infoWindow: InfoWindow(
              title: location.name,
              snippet: location.address ?? '',
              onTap: () {
                setState(() {
                  _selectedLocation = location;
                });
              },
            ),
            onTap: () {
              setState(() {
                _selectedLocation = location;
              });
            },
          ),
        );
      }
    }
  }

  LatLngBounds? _getMapBounds() {
    if (_markers.isEmpty) return null;

    double? minLat, maxLat, minLng, maxLng;

    for (final marker in _markers) {
      final lat = marker.position.latitude;
      final lng = marker.position.longitude;

      minLat = minLat == null ? lat : (lat < minLat ? lat : minLat);
      maxLat = maxLat == null ? lat : (lat > maxLat ? lat : maxLat);
      minLng = minLng == null ? lng : (lng < minLng ? lng : minLng);
      maxLng = maxLng == null ? lng : (lng > maxLng ? lng : maxLng);
    }

    if (minLat == null || maxLat == null || minLng == null || maxLng == null) {
      return null;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  LatLng _getCenterPosition() {
    if (_markers.isEmpty) {
      return const LatLng(0, 0);
    }
    
    double totalLat = 0;
    double totalLng = 0;
    
    for (final marker in _markers) {
      totalLat += marker.position.latitude;
      totalLng += marker.position.longitude;
    }
    
    return LatLng(
      totalLat / _markers.length,
      totalLng / _markers.length,
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    
    // Fit bounds if multiple markers
    if (_markers.length > 1) {
      final bounds = _getMapBounds();
      if (bounds != null) {
        Future.delayed(const Duration(milliseconds: 100), () {
          _mapController?.animateCamera(
            CameraUpdate.newLatLngBounds(bounds, 50),
          );
        });
      }
    }
  }

  Future<void> _openInMaps(Location location) async {
    try {
      final url = Uri.parse(location.googleMapsUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Check if any location has coordinates
    final hasCoordinates = widget.locations.any(
      (loc) => loc.latitude != null && loc.longitude != null,
    );

    if (!hasCoordinates) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Map View'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.location_off,
                size: 64,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                'No locations with coordinates',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add GPS coordinates to view locations on the map',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.placeTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Recenter',
            onPressed: () {
              if (_markers.length == 1) {
                _mapController?.animateCamera(
                  CameraUpdate.newLatLngZoom(_getCenterPosition(), 15),
                );
              } else {
                final bounds = _getMapBounds();
                if (bounds != null) {
                  _mapController?.animateCamera(
                    CameraUpdate.newLatLngBounds(bounds, 50),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _getCenterPosition(),
              zoom: _markers.length == 1 ? 15 : 12,
            ),
            markers: _markers,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            mapToolbarEnabled: false,
          ),
          
          // Selected location info card
          if (_selectedLocation != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Card(
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedLocation!.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                _selectedLocation = null;
                              });
                            },
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      if (_selectedLocation!.address != null &&
                          _selectedLocation!.address!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          _selectedLocation!.address!,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                      if (_selectedLocation!.latitude != null &&
                          _selectedLocation!.longitude != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${_selectedLocation!.latitude!.toStringAsFixed(6)}, '
                          '${_selectedLocation!.longitude!.toStringAsFixed(6)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => _openInMaps(_selectedLocation!),
                        icon: const Icon(Icons.navigation),
                        label: const Text('Navigate'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 40),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
