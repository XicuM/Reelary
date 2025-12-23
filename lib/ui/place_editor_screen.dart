import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/place.dart';
import '../models/location.dart';
import '../models/tag.dart';
import '../providers/place_provider.dart';
import '../data/database_helper.dart';

class PlaceEditorScreen extends StatefulWidget {
  final Place place;

  const PlaceEditorScreen({super.key, required this.place});

  @override
  State<PlaceEditorScreen> createState() => _PlaceEditorScreenState();
}

class _PlaceEditorScreenState extends State<PlaceEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _videoUrlController;
  late List<LocationEditor> _locations;
  late Set<int> _selectedTagIds;
  List<PlaceTag> _availableTags = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.place.title);
    _descriptionController = TextEditingController(text: widget.place.description);
    _videoUrlController = TextEditingController(text: widget.place.videoUrl);
    _selectedTagIds = Set<int>.from(widget.place.tagIds);
    _locations = widget.place.locations
        .map((loc) => LocationEditor(
              name: loc.name,
              address: loc.address,
              latitude: loc.latitude,
              longitude: loc.longitude,
            ))
        .toList();
    _loadTags();
  }

  Future<void> _loadTags() async {
    final tags = await DatabaseHelper.instance.readAllTags();
    if (mounted) {
      setState(() {
        _availableTags = tags;
      });
    }
  }

  void _showTagSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Tags'),
        content: SizedBox(
          width: double.maxFinite,
          child: _availableTags.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No tags available. Create tags in settings.'),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _availableTags.length,
                  itemBuilder: (context, index) {
                    final tag = _availableTags[index];
                    final isSelected = _selectedTagIds.contains(tag.id);
                    final color = Color(int.parse('0xFF${tag.color.substring(1)}'));
                    
                    return CheckboxListTile(
                      title: Row(
                        children: [
                          Text(tag.icon),
                          const SizedBox(width: 8),
                          Text(tag.name),
                        ],
                      ),
                      value: isSelected,
                      activeColor: color,
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _selectedTagIds.add(tag.id!);
                          } else {
                            _selectedTagIds.remove(tag.id);
                          }
                        });
                        Navigator.pop(context);
                        _showTagSelectionDialog();
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _videoUrlController.dispose();
    for (var loc in _locations) {
      loc.dispose();
    }
    super.dispose();
  }

  Future<void> _savePlace() async {
    if (!_formKey.currentState!.validate()) return;

    // Check if at least one location has a name
    final hasValidLocation = _locations.any((loc) => loc.nameController.text.trim().isNotEmpty);
    if (!hasValidLocation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least one location with a name is required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final locations = _locations
          .where((loc) => loc.nameController.text.trim().isNotEmpty)
          .map((loc) => Location(
                name: loc.nameController.text.trim(),
                address: loc.addressController.text.trim().isEmpty
                    ? null
                    : loc.addressController.text.trim(),
                latitude: loc.latitudeController.text.trim().isEmpty
                    ? null
                    : double.tryParse(loc.latitudeController.text.trim()),
                longitude: loc.longitudeController.text.trim().isEmpty
                    ? null
                    : double.tryParse(loc.longitudeController.text.trim()),
              ))
          .toList();

      final updatedPlace = widget.place.copyWith(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        videoUrl: _videoUrlController.text.trim(),
        locations: locations,
        tagIds: _selectedTagIds.toList(),
      );

      await Provider.of<PlaceProvider>(context, listen: false)
          .updatePlace(updatedPlace);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving place: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _addLocation() {
    setState(() {
      _locations.add(LocationEditor(
        name: '',
        address: null,
        latitude: null,
        longitude: null,
      ));
    });
  }

  void _removeLocation(int index) {
    setState(() {
      _locations[index].dispose();
      _locations.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Place'),
        actions: [
          if (!_isSaving)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _savePlace,
              tooltip: 'Save',
            ),
        ],
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Title
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Place Title',
                      prefixIcon: Icon(Icons.title),
                    ),
                    style: theme.textTheme.titleLarge,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Title is required';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      prefixIcon: Icon(Icons.description),
                    ),
                    maxLines: 3,
                  ),

                  const SizedBox(height: 16),

                  // Video URL (Instagram Source)
                  TextFormField(
                    controller: _videoUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Instagram Source URL',
                      prefixIcon: Icon(Icons.link),
                      hintText: 'https://www.instagram.com/reel/...',
                    ),
                    keyboardType: TextInputType.url,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Instagram URL is required';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 32),

                  // Tags Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.label, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Tags',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      FilledButton.icon(
                        onPressed: _showTagSelectionDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Tag'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Selected Tags
                  if (_selectedTagIds.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _selectedTagIds.map((tagId) {
                        final tag = _availableTags.firstWhere(
                          (t) => t.id == tagId,
                          orElse: () => PlaceTag(
                            name: 'Unknown',
                            icon: '❓',
                            color: '#808080',
                          ),
                        );
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
                          onDeleted: () {
                            setState(() {
                              _selectedTagIds.remove(tagId);
                            });
                          },
                        );
                      }).toList(),
                    )
                  else
                    Text(
                      'No tags selected',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.outline,
                      ),
                    ),

                  const SizedBox(height: 32),

                  // Locations Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.place, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Locations',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      FilledButton.icon(
                        onPressed: _addLocation,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Location'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Location Cards
                  ...List.generate(_locations.length, (index) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
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
                                const Spacer(),
                                if (_locations.length > 1)
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () => _removeLocation(index),
                                    color: Colors.red,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _locations[index].nameController,
                              decoration: const InputDecoration(
                                labelText: 'Location Name *',
                                prefixIcon: Icon(Icons.location_on),
                              ),
                              validator: (value) {
                                // Only validate if this is the only location or if it has any content
                                if (_locations.length == 1 || 
                                    value != null && value.trim().isNotEmpty) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Name is required';
                                  }
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _locations[index].addressController,
                              decoration: const InputDecoration(
                                labelText: 'Address (optional)',
                                prefixIcon: Icon(Icons.home),
                              ),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _locations[index].latitudeController,
                                    decoration: const InputDecoration(
                                      labelText: 'Latitude',
                                      prefixIcon: Icon(Icons.location_searching),
                                    ),
                                    keyboardType: const TextInputType.numberWithOptions(
                                      decimal: true,
                                      signed: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _locations[index].longitudeController,
                                    decoration: const InputDecoration(
                                      labelText: 'Longitude',
                                      prefixIcon: Icon(Icons.location_searching),
                                    ),
                                    keyboardType: const TextInputType.numberWithOptions(
                                      decimal: true,
                                      signed: true,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}

class LocationEditor {
  final TextEditingController nameController;
  final TextEditingController addressController;
  final TextEditingController latitudeController;
  final TextEditingController longitudeController;

  LocationEditor({
    required String name,
    required String? address,
    required double? latitude,
    required double? longitude,
  })  : nameController = TextEditingController(text: name),
        addressController = TextEditingController(text: address ?? ''),
        latitudeController = TextEditingController(
            text: latitude != null ? latitude.toString() : ''),
        longitudeController = TextEditingController(
            text: longitude != null ? longitude.toString() : '');

  void dispose() {
    nameController.dispose();
    addressController.dispose();
    latitudeController.dispose();
    longitudeController.dispose();
  }
}
