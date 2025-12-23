import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../providers/place_provider.dart';
import '../providers/recipe_provider.dart';
import '../models/folder.dart';
import 'place_detail_screen.dart';
import 'settings_screen.dart';

class PlacesHomeScreen extends StatefulWidget {
  const PlacesHomeScreen({super.key});

  @override
  State<PlacesHomeScreen> createState() => _PlacesHomeScreenState();
}

class _PlacesHomeScreenState extends State<PlacesHomeScreen> {
  bool _showFolders = true;

  void _showCreateFolderDialog() {
    final nameController = TextEditingController();
    String selectedEmoji = '📁';
    FolderEntryType selectedEntryType = FolderEntryType.place;

    final List<String> emojiOptions = [
      '📁',
      '🗺️',
      '📍',
      '🏖️',
      '🏔️',
      '🏙️',
      '🏝️',
      '🏞️',
      '🏟️',
      '🗼',
      '🗽',
      '⛰️',
      '🌋',
      '🏕️',
      '🏖️',
      '🏛️',
      '🕌',
      '⛪',
      '🕍',
      '⛩️',
      '🎡',
      '🎢',
      '🎠',
      '⛲',
      '⛱️',
      '🌊',
      '🌅',
      '🌄',
      '❤️',
      '⭐',
      '✨',
      '💙'
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Folder'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Folder Name',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                const Text('Entry Type:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SegmentedButton<FolderEntryType>(
                  segments: const [
                    ButtonSegment(
                      value: FolderEntryType.place,
                      label: Text('Place'),
                      icon: Icon(Icons.place),
                    ),
                    ButtonSegment(
                      value: FolderEntryType.both,
                      label: Text('Both'),
                      icon: Icon(Icons.folder),
                    ),
                  ],
                  selected: {selectedEntryType},
                  onSelectionChanged: (Set<FolderEntryType> newSelection) {
                    setDialogState(() {
                      selectedEntryType = newSelection.first;
                    });
                  },
                ),
                const SizedBox(height: 16),
                const Text('Choose Icon:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 120,
                  width: double.maxFinite,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: GridView.builder(
                      padding: const EdgeInsets.all(8),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 8,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemCount: emojiOptions.length,
                      itemBuilder: (context, index) {
                        final emoji = emojiOptions[index];
                        final isSelected = emoji == selectedEmoji;
                        return InkWell(
                          onTap: () {
                            setDialogState(() {
                              selectedEmoji = emoji;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primaryContainer
                                  : null,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(emoji,
                                  style: const TextStyle(fontSize: 24)),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  final folder = RecipeFolder(
                    name: nameController.text,
                    emoji: selectedEmoji,
                    dateCreated: DateTime.now(),
                    dateModified: DateTime.now(),
                    entryType: selectedEntryType,
                  );
                  Provider.of<PlaceProvider>(context, listen: false)
                      .createFolder(folder);
                  Navigator.pop(context);
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditFolderDialog(RecipeFolder folder) {
    final nameController = TextEditingController(text: folder.name);
    String selectedEmoji = folder.emoji;
    FolderEntryType selectedEntryType = folder.entryType;

    final List<String> emojiOptions = [
      '📁', '🗺️', '📍', '🏖️', '🏔️', '🏙️', '🏝️', '🏞️', '🏟️', '🗼', '🗽',
      '⛰️', '🌋', '🏕️', '🏖️', '🏛️', '🕌', '⛪', '🕍', '⛩️', '🎡', '🎢',
      '🎠', '⛲', '⛱️', '🌊', '🌅', '🌄', '❤️', '⭐', '✨', '💙'
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Folder'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Folder Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Entry Type:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SegmentedButton<FolderEntryType>(
                  segments: const [
                    ButtonSegment(
                      value: FolderEntryType.place,
                      label: Text('Place'),
                      icon: Icon(Icons.place),
                    ),
                    ButtonSegment(
                      value: FolderEntryType.both,
                      label: Text('Both'),
                      icon: Icon(Icons.folder),
                    ),
                  ],
                  selected: {selectedEntryType},
                  onSelectionChanged: (Set<FolderEntryType> newSelection) {
                    setDialogState(() {
                      selectedEntryType = newSelection.first;
                    });
                  },
                ),
                const SizedBox(height: 16),
                const Text('Choose Icon:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 120,
                  width: double.maxFinite,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: GridView.builder(
                      padding: const EdgeInsets.all(8),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 8,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemCount: emojiOptions.length,
                      itemBuilder: (context, index) {
                        final emoji = emojiOptions[index];
                        final isSelected = emoji == selectedEmoji;
                        return InkWell(
                          onTap: () {
                            setDialogState(() {
                              selectedEmoji = emoji;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primaryContainer
                                  : null,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(emoji,
                                  style: const TextStyle(fontSize: 24)),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  final updatedFolder = folder.copyWith(
                    name: nameController.text,
                    emoji: selectedEmoji,
                    entryType: selectedEntryType,
                    dateModified: DateTime.now(),
                  );
                  Provider.of<PlaceProvider>(context, listen: false)
                      .updateFolder(updatedFolder);
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoveToFolderDialog(int placeId) {
    final provider = Provider.of<PlaceProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to Folder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('No Folder'),
              onTap: () {
                provider.movePlaceToFolder(placeId, null);
                Navigator.pop(context);
              },
            ),
            ...provider.folders.map((folder) => ListTile(
                  leading:
                      Text(folder.emoji, style: const TextStyle(fontSize: 24)),
                  title: Text(folder.name),
                  onTap: () {
                    provider.movePlaceToFolder(placeId, folder.id);
                    Navigator.pop(context);
                  },
                )),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String hexColor) {
    return Color(int.parse(hexColor.substring(1, 7), radix: 16) + 0xFF000000);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reelary'),
        actions: [
          IconButton(
            icon: Icon(_showFolders ? Icons.folder : Icons.folder_outlined),
            tooltip: _showFolders ? 'Hide Folders' : 'Show Folders',
            onPressed: () {
              setState(() {
                _showFolders = !_showFolders;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.create_new_folder),
            tooltip: 'Create Folder',
            onPressed: _showCreateFolderDialog,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [


          // Folders Section
          if (_showFolders)
            Consumer<PlaceProvider>(
              builder: (context, provider, child) {
                return Container(
                  height: 100,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: provider.folders.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        // "All Places" folder
                        final isSelected = provider.selectedFolderId == -1;
                        return GestureDetector(
                          onTap: () => provider.selectFolder(-1),
                          child: Container(
                            width: 80,
                            margin: const EdgeInsets.only(right: 12),
                            child: Column(
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? colorScheme.primaryContainer
                                        : colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected
                                          ? colorScheme.primary
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text('🏠',
                                        style: const TextStyle(fontSize: 32)),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'All',
                                  style: theme.textTheme.bodySmall,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final folder = provider.folders[index - 1];
                      final isSelected = provider.selectedFolderId == folder.id;
                      return GestureDetector(
                        onTap: () => provider.selectFolder(folder.id),
                        onLongPress: () => _showEditFolderDialog(folder),
                        child: Container(
                          width: 80,
                          margin: const EdgeInsets.only(right: 12),
                          child: Column(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? colorScheme.primaryContainer
                                      : colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? colorScheme.primary
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Text(folder.emoji,
                                      style: const TextStyle(fontSize: 32)),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                folder.name,
                                style: theme.textTheme.bodySmall,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),

          // Tag Filter Bar
          Consumer<PlaceProvider>(
            builder: (context, provider, child) {
              if (provider.tags.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        'No tags yet',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Container(
                height: 50,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: provider.tags.length,
                  itemBuilder: (context, index) {
                    final tag = provider.tags[index];
                    final isSelected = provider.selectedTagId == tag.id;
                    final tagColor = _parseColor(tag.color);

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                          avatar: Text(tag.icon, style: const TextStyle(fontSize: 16)),
                          label: Text(tag.name),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              provider.selectTag(tag.id);
                            } else {
                              provider.selectTag(null);
                              provider.selectFolder(-1);
                            }
                          },
                          backgroundColor: tagColor.withValues(alpha: 0.1),
                          selectedColor: tagColor.withValues(alpha: 0.3),
                          checkmarkColor: tagColor,
                          labelStyle: TextStyle(
                            color: isSelected ? tagColor : colorScheme.onSurface,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                  },
                ),
              );
            },
          ),

          const Divider(),

          // Places Grid
          Expanded(
            child: Consumer<PlaceProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (provider.error != null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline,
                              size: 64, color: colorScheme.error),
                          const SizedBox(height: 16),
                          Text(
                            'Error: ${provider.error}',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: colorScheme.error),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (provider.places.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.place,
                            size: 64, color: colorScheme.outline),
                        const SizedBox(height: 16),
                        Text(
                          'No places yet',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add your first place from Instagram!',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = (constraints.maxWidth / 150).floor().clamp(1, 6);
                    
                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: 0.75,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: provider.places.length,
                      itemBuilder: (context, index) {
                        final place = provider.places[index];
                        final placeTags = provider.tags
                            .where((tag) => place.tagIds.contains(tag.id))
                            .toList();

                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      PlaceDetailScreen(place: place),
                                ),
                              );
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Place Image
                                Expanded(
                                  child: place.screenshotPath != null &&
                                          place.screenshotPath!.isNotEmpty
                                      ? Image.file(
                                          File(place.screenshotPath!),
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return Container(
                                              color: colorScheme.surfaceContainerHighest,
                                              child: Icon(
                                                Icons.place,
                                                size: 64,
                                                color: colorScheme.onSurface,
                                              ),
                                            );
                                          },
                                        )
                                      : Container(
                                          color: colorScheme.surfaceContainerHighest,
                                          child: Icon(
                                            Icons.place,
                                            size: 64,
                                            color: colorScheme.onSurface,
                                          ),
                                        ),
                                ),
                                // Place Info
                                Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        place.title,
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${place.locations.length} ${place.locations.length == 1 ? 'location' : 'locations'}',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      if (placeTags.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 4,
                                          runSpacing: 4,
                                          children: placeTags.take(3).map((tag) {
                                            final tagColor = _parseColor(tag.color);
                                            return Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: tagColor.withValues(alpha: 0.2),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    tag.icon,
                                                    style: const TextStyle(fontSize: 10),
                                                  ),
                                                  const SizedBox(width: 2),
                                                  Text(
                                                    tag.name,
                                                    style: theme.textTheme.bodySmall?.copyWith(
                                                      fontSize: 10,
                                                      color: tagColor,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          PopupMenuButton(
                                            icon: Icon(Icons.more_vert,
                                                size: 18,
                                                color: colorScheme.onSurface),
                                            padding: EdgeInsets.zero,
                                            itemBuilder: (context) => [
                                              PopupMenuItem(
                                                child: const ListTile(
                                                  leading: Icon(Icons.folder_open),
                                                  title: Text('Move to Folder'),
                                                  contentPadding: EdgeInsets.zero,
                                                ),
                                                onTap: () {
                                                  Future.delayed(
                                                    Duration.zero,
                                                    () => _showMoveToFolderDialog(
                                                        place.id!),
                                                  );
                                                },
                                              ),
                                              PopupMenuItem(
                                                child: const ListTile(
                                                  leading: Icon(Icons.delete,
                                                      color: Colors.red),
                                                  title: Text('Delete',
                                                      style: TextStyle(
                                                          color: Colors.red)),
                                                  contentPadding: EdgeInsets.zero,
                                                ),
                                                onTap: () {
                                                  provider.deletePlace(place.id!);
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
