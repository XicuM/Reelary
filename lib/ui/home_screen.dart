import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../providers/recipe_provider.dart';
import '../models/folder.dart';
import 'recipe_detail_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showFolders = true;

  void _showCreateFolderDialog() {
    final nameController = TextEditingController();
    String selectedEmoji = '📁';

    final List<String> emojiOptions = [
      '📁',
      '🍕',
      '🍔',
      '🍰',
      '🥗',
      '🍜',
      '🍳',
      '🥘',
      '🍲',
      '🥙',
      '🌮',
      '🍱',
      '🍛',
      '🍝',
      '🥟',
      '🍩',
      '🧁',
      '🍪',
      '☕',
      '🍷',
      '🥂',
      '🎂',
      '🍾',
      '🥃',
      '❤️',
      '⭐',
      '🔥',
      '✨',
      '🎉',
      '💚',
      '💙',
      '💜'
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Folder'),
          content: Column(
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  Provider.of<RecipeProvider>(context, listen: false)
                      .createFolder(nameController.text, selectedEmoji);
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

    final List<String> emojiOptions = [
      '📁',
      '🍕',
      '🍔',
      '🍰',
      '🥗',
      '🍜',
      '🍳',
      '🥘',
      '🍲',
      '🥙',
      '🌮',
      '🍱',
      '🍛',
      '🍝',
      '🥟',
      '🍩',
      '🧁',
      '🍪',
      '☕',
      '🍷',
      '🥂',
      '🎂',
      '🍾',
      '🥃',
      '❤️',
      '⭐',
      '🔥',
      '✨',
      '🎉',
      '💚',
      '💙',
      '💜'
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Folder'),
          content: Column(
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  Provider.of<RecipeProvider>(context, listen: false)
                      .updateFolder(
                          folder.id!, nameController.text, selectedEmoji);
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

  void _showMoveToFolderDialog(int recipeId) {
    final provider = Provider.of<RecipeProvider>(context, listen: false);

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
                provider.moveRecipeToFolder(recipeId, null);
                Navigator.pop(context);
              },
            ),
            ...provider.folders.map((folder) => ListTile(
                  leading:
                      Text(folder.emoji, style: const TextStyle(fontSize: 24)),
                  title: Text(folder.name),
                  onTap: () {
                    provider.moveRecipeToFolder(recipeId, folder.id);
                    Navigator.pop(context);
                  },
                )),
          ],
        ),
      ),
    );
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
            Consumer<RecipeProvider>(
              builder: (context, provider, child) {
                return Container(
                  height: 100,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: provider.folders.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        // "All Recipes" folder
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

          const Divider(),

          // Recipes List
          Expanded(
            child: Consumer<RecipeProvider>(
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
                if (provider.recipes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.restaurant_menu,
                            size: 64, color: colorScheme.outline),
                        const SizedBox(height: 16),
                        Text(
                          'No recipes yet',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add your first recipe from Instagram!',
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
                    // Calculate number of columns based on available width
                    // Each card should be around 180-200px wide
                    final crossAxisCount = (constraints.maxWidth / 150).floor().clamp(1, 6);
                    
                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: 0.75,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: provider.recipes.length,
                  itemBuilder: (context, index) {
                    final recipe = provider.recipes[index];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  RecipeDetailScreen(recipe: recipe),
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Recipe Image
                            Expanded(
                              child: recipe.screenshotPath != null &&
                                      recipe.screenshotPath!.isNotEmpty
                                  ? Image.file(
                                      File(recipe.screenshotPath!),
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Container(
                                          color: colorScheme.surfaceContainerHighest,
                                          child: Icon(
                                            Icons.restaurant,
                                            size: 64,
                                            color: colorScheme.onSurface,
                                          ),
                                        );
                                      },
                                    )
                                  : Container(
                                      color: colorScheme.surfaceContainerHighest,
                                      child: Icon(
                                        Icons.restaurant,
                                        size: 64,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                            ),
                            // Recipe Info
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    recipe.title,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${recipe.ingredients.length} ingredients',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${recipe.steps.length} steps',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
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
                                                    recipe.id!),
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
                                              provider.deleteRecipe(recipe.id!);
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
