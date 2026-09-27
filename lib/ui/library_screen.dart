import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../models/folder.dart';
import '../models/place.dart';
import '../models/recipe.dart';
import '../providers/place_provider.dart';
import '../providers/recipe_provider.dart';
import '../services/media_service.dart';
import '../services/reel_import.dart';
import '../services/settings_service.dart';
import 'place_detail_screen.dart';
import 'recipe_detail_screen.dart';
import 'settings_screen.dart';

const _folderEmojis = [
  '📁', '🍕', '🍔', '🍰', '🥗', '🍜', '🍳', '🍝', '🌮', '🍱',
  '☕', '🍷', '🗺️', '📍', '🏖️', '🏔️', '🏙️', '🏛️', '✈️', '🏨',
  '❤️', '⭐', '✨',
];

enum _LibraryView { all, recipes, places, unfiled, folder }

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<List<SharedMediaFile>>? _shareSub;

  _LibraryView _view = _LibraryView.all;
  int? _folderId;
  int? _tagId;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkApiKeys());
    _listenForShares();
  }

  @override
  void dispose() {
    _shareSub?.cancel();
    _urlController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _listenForShares() {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    _shareSub = ReceiveSharingIntent.instance.getMediaStream().listen((value) {
      _importShared(value);
    }, onError: (err) {
      debugPrint('Error receiving shared data: $err');
    });

    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      if (value.isEmpty) return;
      _importShared(value);
      ReceiveSharingIntent.instance.reset();
    }).catchError((err) {
      if (err is MissingPluginException) {
        debugPrint('receive_sharing_intent not available: $err');
      } else {
        debugPrint('Error getting initial shared data: $err');
      }
    });
  }

  void _importShared(List<SharedMediaFile> value) {
    if (value.isEmpty || value.first.type != SharedMediaType.text) return;
    final url = MediaService.urlPattern.firstMatch(value.first.path)?.group(0);
    if (url == null || !mounted) return;
    _import(url);
  }

  Future<void> _checkApiKeys() async {
    final hasKeys = await SettingsService.hasApiKeys();
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearMaterialBanners();
    if (hasKeys) return;

    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        content: const Text('Add your API keys in Settings to save a post.'),
        leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        actions: [
          TextButton(
            onPressed: () async {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              _checkApiKeys();
            },
            child: const Text('Settings'),
          ),
          TextButton(
            onPressed: () => ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  void _select(_LibraryView view, {int? folderId}) {
    setState(() {
      _view = view;
      _folderId = folderId;
      if (view == _LibraryView.recipes) _tagId = null;
    });
  }

  Future<void> _import(String url, {bool? asPlace, bool replaceExisting = false, int? folderId}) {
    return importReel(
      url: url,
      recipes: Provider.of<RecipeProvider>(context, listen: false),
      places: Provider.of<PlaceProvider>(context, listen: false),
      asPlace: asPlace,
      replaceExisting: replaceExisting,
      folderId: folderId,
    );
  }

  Future<void> _showAddDialog() async {
    String? error;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add a post'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _urlController,
                autofocus: true,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Instagram or TikTok URL',
                  hintText: 'https://www.instagram.com/reel/...',
                  prefixIcon: Icon(Icons.link),
                ),
                onSubmitted: (_) => _submitUrl(context, setDialogState, (message) {
                  error = message;
                }),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _urlController.clear();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => _submitUrl(context, setDialogState, (message) {
                error = message;
              }),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _submitUrl(BuildContext dialogContext, StateSetter setDialogState, void Function(String?) setError) {
    final text = _urlController.text.trim();
    final url = MediaService.urlPattern.firstMatch(text)?.group(0) ?? text;
    if (MediaService.extractPostId(url) == null) {
      setDialogState(() => setError('Paste an Instagram or TikTok link.'));
      return;
    }
    _urlController.clear();
    Navigator.pop(dialogContext);
    _import(url);
  }

  Future<void> _createFolder() async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New folder'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, nameController.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    nameController.dispose();
    if (name == null || name.trim().isEmpty || !mounted) return;
    await Provider.of<RecipeProvider>(context, listen: false).createFolder(name.trim(), '📁');
  }

  Future<void> _showFolderActions(RecipeFolder folder) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(folder.name),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'rename'),
            child: const ListTile(
              leading: Icon(Icons.drive_file_rename_outline),
              title: Text('Rename'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'icon'),
            child: const ListTile(
              leading: Icon(Icons.emoji_emotions_outlined),
              title: Text('Change icon'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'delete'),
            child: const ListTile(
              leading: Icon(Icons.delete_outline),
              title: Text('Delete folder'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
    if (!mounted || action == null || folder.id == null) return;

    final recipes = Provider.of<RecipeProvider>(context, listen: false);
    final places = Provider.of<PlaceProvider>(context, listen: false);
    if (action == 'rename') {
      final name = await _askName(folder.name);
      if (name == null || name.trim().isEmpty) return;
      await recipes.updateFolder(folder.id!, name.trim(), folder.emoji);
    } else if (action == 'icon') {
      final emoji = await _pickEmoji();
      if (emoji == null) return;
      await recipes.updateFolder(folder.id!, folder.name, emoji);
    } else if (action == 'delete') {
      final confirmed = await _confirm(
        title: 'Delete ${folder.name}?',
        body: 'Items in this folder stay in the library, under Unfiled.',
        confirm: 'Delete',
      );
      if (!confirmed || !mounted) return;
      await recipes.deleteFolder(folder.id!);
      await places.loadPlaces(silent: true);
      if (_folderId == folder.id) _select(_LibraryView.all);
    }
  }

  Future<String?> _askName(String current) async {
    final controller = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return name;
  }

  Future<String?> _pickEmoji() {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Folder icon'),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.count(
            crossAxisCount: 6,
            shrinkWrap: true,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              for (final emoji in _folderEmojis)
                InkWell(
                  onTap: () => Navigator.pop(context, emoji),
                  borderRadius: BorderRadius.circular(8),
                  child: Center(child: Text(emoji, style: const TextStyle(fontSize: 26))),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _confirm({required String title, required String body, required String confirm}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(confirm),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _moveToFolder({required int? currentId, required Future<void> Function(int?) move}) async {
    final folders = Provider.of<RecipeProvider>(context, listen: false).folders;
    final folderId = await showDialog<int?>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Move to folder'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, -1),
            child: const ListTile(
              leading: Icon(Icons.folder_off_outlined),
              title: Text('Unfiled'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          for (final folder in folders)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, folder.id),
              child: ListTile(
                leading: Text(folder.emoji, style: const TextStyle(fontSize: 22)),
                title: Text(folder.name),
                trailing: folder.id == currentId ? const Icon(Icons.check) : null,
                contentPadding: EdgeInsets.zero,
              ),
            ),
        ],
      ),
    );
    if (folderId == null) return;
    await move(folderId == -1 ? null : folderId);
  }

  bool _matchesQuery(List<String> fields) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    return fields.any((field) => field.toLowerCase().contains(query));
  }

  bool _visible({required bool isRecipe, required int? folderId, List<int> tagIds = const []}) {
    if (_tagId != null && (isRecipe || !tagIds.contains(_tagId))) return false;
    switch (_view) {
      case _LibraryView.all:
        return true;
      case _LibraryView.recipes:
        return isRecipe;
      case _LibraryView.places:
        return !isRecipe;
      case _LibraryView.unfiled:
        return folderId == null;
      case _LibraryView.folder:
        return folderId == _folderId;
    }
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
            tooltip: 'New folder',
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: _createFolder,
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              _checkApiKeys();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add a post',
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search titles, ingredients, places',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          SizedBox(
            height: 52,
            child: Consumer<RecipeProvider>(
              builder: (context, recipes, _) {
                return ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _filterChip('All', _view == _LibraryView.all, () => _select(_LibraryView.all)),
                    _filterChip('Recipes', _view == _LibraryView.recipes, () => _select(_LibraryView.recipes)),
                    _filterChip('Places', _view == _LibraryView.places, () => _select(_LibraryView.places)),
                    _filterChip('Unfiled', _view == _LibraryView.unfiled, () => _select(_LibraryView.unfiled)),
                    for (final folder in recipes.folders)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onLongPress: () => _showFolderActions(folder),
                          child: FilterChip(
                            label: Text('${folder.emoji} ${folder.name}'),
                            selected: _view == _LibraryView.folder && _folderId == folder.id,
                            onSelected: (_) {
                              if (_view == _LibraryView.folder && _folderId == folder.id) {
                                _showFolderActions(folder);
                              } else {
                                _select(_LibraryView.folder, folderId: folder.id);
                              }
                            },
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          if (_view != _LibraryView.recipes)
            Consumer<PlaceProvider>(
              builder: (context, places, _) {
                if (places.tags.isEmpty) return const SizedBox.shrink();
                return SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      for (final tag in places.tags)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            avatar: Text(tag.icon),
                            label: Text(tag.name),
                            selected: _tagId == tag.id,
                            onSelected: (selected) {
                              setState(() => _tagId = selected ? tag.id : null);
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          const Divider(height: 1),
          Expanded(
            child: Consumer2<RecipeProvider, PlaceProvider>(
              builder: (context, recipes, places, _) {
                final waiting = (recipes.isLoading || places.isLoading) &&
                    recipes.recipes.isEmpty &&
                    places.places.isEmpty;
                if (waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final error = recipes.error ?? places.error;
                if (error != null && recipes.recipes.isEmpty && places.places.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(error, textAlign: TextAlign.center),
                    ),
                  );
                }

                final entries = <_Entry>[
                  for (final recipe in recipes.recipes)
                    if (_matchesQuery([
                      recipe.title,
                      for (final ingredient in recipe.ingredients) ingredient.name,
                    ]) &&
                        _visible(isRecipe: true, folderId: recipe.folderId))
                      _Entry.recipe(recipe),
                  for (final place in places.places)
                    if (_matchesQuery([
                      place.title,
                      for (final location in place.locations) location.name,
                    ]) &&
                        _visible(isRecipe: false, folderId: place.folderId, tagIds: place.tagIds))
                      _Entry.place(place),
                ]..sort((a, b) => b.date.compareTo(a.date));

                if (entries.isEmpty) {
                  final libraryEmpty = recipes.recipes.isEmpty && places.places.isEmpty;
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            libraryEmpty ? Icons.video_library_outlined : Icons.search_off,
                            size: 56,
                            color: colorScheme.outline,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            libraryEmpty ? 'Nothing saved yet' : 'Nothing matches',
                            style: theme.textTheme.titleLarge?.copyWith(color: colorScheme.outline),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            libraryEmpty
                                ? 'Add an Instagram or TikTok post.'
                                : 'Try another search or filter.',
                            style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = (constraints.maxWidth / 180).floor().clamp(1, 6);
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        childAspectRatio: 0.72,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: entries.length,
                      itemBuilder: (context, index) => _card(context, entries[index]),
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

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }

  Widget _card(BuildContext context, _Entry entry) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final recipe = entry.recipe;
    final place = entry.place;
    final title = recipe?.title ?? place!.title;
    final imagePath = recipe?.screenshotPath ?? place?.screenshotPath;
    final subtitle = recipe != null
        ? '${recipe.ingredients.length} ingredients'
        : '${place!.locations.length} ${place.locations.length == 1 ? 'location' : 'locations'}';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => recipe != null
                  ? RecipeDetailScreen(recipe: recipe)
                  : PlaceDetailScreen(place: place!),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _thumbnail(imagePath, recipe != null, colorScheme),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(
                          recipe != null ? 'Recipe' : 'Place',
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Item actions',
                        icon: Icon(Icons.more_vert, size: 18, color: colorScheme.onSurface),
                        padding: EdgeInsets.zero,
                        onSelected: (value) => _onCardAction(entry, value),
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'move', child: Text('Move to folder')),
                          PopupMenuItem(
                            value: 'switch',
                            child: Text(recipe != null ? 'Save as place' : 'Save as recipe'),
                          ),
                          const PopupMenuItem(value: 'delete', child: Text('Delete')),
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
  }

  Widget _thumbnail(String? path, bool isRecipe, ColorScheme colorScheme) {
    if (path != null && path.isNotEmpty) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _thumbnailFallback(isRecipe, colorScheme),
      );
    }
    return _thumbnailFallback(isRecipe, colorScheme);
  }

  Widget _thumbnailFallback(bool isRecipe, ColorScheme colorScheme) {
    return ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: Icon(isRecipe ? Icons.restaurant : Icons.place, size: 48),
    );
  }

  Future<void> _onCardAction(_Entry entry, String action) async {
    final recipe = entry.recipe;
    final place = entry.place;
    if (action == 'move') {
      if (recipe?.id != null) {
        final recipes = Provider.of<RecipeProvider>(context, listen: false);
        await _moveToFolder(
          currentId: recipe!.folderId,
          move: (folderId) => recipes.moveRecipeToFolder(recipe.id!, folderId),
        );
      } else if (place?.id != null) {
        final places = Provider.of<PlaceProvider>(context, listen: false);
        await _moveToFolder(
          currentId: place!.folderId,
          move: (folderId) => places.movePlaceToFolder(place.id!, folderId),
        );
      }
      return;
    }

    if (action == 'delete') {
      final isRecipe = recipe != null;
      final confirmed = await _confirm(
        title: isRecipe ? 'Delete this recipe?' : 'Delete this place?',
        body: 'This removes it from the library.',
        confirm: 'Delete',
      );
      if (!confirmed || !mounted) return;
      if (recipe?.id != null) {
        await Provider.of<RecipeProvider>(context, listen: false).deleteRecipe(recipe!.id!);
      } else if (place?.id != null) {
        await Provider.of<PlaceProvider>(context, listen: false).deletePlace(place!.id!);
      }
      return;
    }

    if (action == 'switch') {
      final saveAsPlace = recipe != null;
      final confirmed = await _confirm(
        title: saveAsPlace ? 'Save as a place?' : 'Save as a recipe?',
        body: saveAsPlace
            ? 'Reelary will read this post again and save it as a place. This recipe is replaced.'
            : 'Reelary will read this post again and save it as a recipe. This place is replaced.',
        confirm: 'Continue',
      );
      if (!confirmed || !mounted) return;
      final url = recipe?.videoUrl ?? place!.videoUrl;
      final folderId = recipe?.folderId ?? place?.folderId;
      await _import(url, asPlace: saveAsPlace, replaceExisting: true, folderId: folderId);
    }
  }
}

class _Entry {
  final Recipe? recipe;
  final Place? place;

  _Entry.recipe(Recipe this.recipe) : place = null;
  _Entry.place(Place this.place) : recipe = null;

  DateTime get date => recipe?.dateCreated ?? place!.dateCreated;
}
