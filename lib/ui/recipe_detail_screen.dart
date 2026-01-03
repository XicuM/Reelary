import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../models/recipe.dart';
import '../data/database_helper.dart';
import 'video_player_screen.dart';
import 'recipe_editor_screen.dart';
import '../providers/recipe_provider.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  final Set<int> _completedSteps = {};
  late Recipe _currentRecipe;
  late PageController _pageController;
  late PageController _ingredientsPageController;
  int _activePage = 0;

  @override
  void initState() {
    super.initState();
    _currentRecipe = widget.recipe;
    _pageController = PageController();
    _ingredientsPageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _ingredientsPageController.dispose();
    super.dispose();
  }

  Future<void> _refreshRecipe() async {
    if (widget.recipe.id != null) {
      final updated = await DatabaseHelper.instance.readRecipe(widget.recipe.id!);
      if (updated != null && mounted) {
        setState(() {
          _currentRecipe = updated;
        });
      }
    }
  }

  // ... (existing code)



  String _buildRecipeText() {
    final buffer = StringBuffer();
    buffer.writeln('🍳 ${_currentRecipe.title}');
    buffer.writeln();
    buffer.writeln('📋 Ingredients:');
    for (var ingredient in _currentRecipe.ingredients) {
      final qty = ingredient.quantity.isNotEmpty ? ingredient.quantity : '';
      final unit = ingredient.unit.isNotEmpty ? ingredient.unit : '';
      buffer.writeln('• $qty $unit ${ingredient.name}'.trim());
    }
    buffer.writeln();
    buffer.writeln('👨‍🍳 Steps:');
    for (var i = 0; i < _currentRecipe.steps.length; i++) {
      buffer.writeln('${i + 1}. ${_currentRecipe.steps[i]}');
    }
    buffer.writeln();
    buffer.writeln('Created with Reelary by Xicu Marí');
    return buffer.toString();
  }

  Future<void> _shareRecipe(bool includeVideo) async {
    try {
      final text = _buildRecipeText();
      final filesToShare = <XFile>[];
      
      if (_currentRecipe.videoPath != null &&
          _currentRecipe.videoPath!.isNotEmpty &&
          File(_currentRecipe.videoPath!).existsSync()) {
        filesToShare.add(XFile(_currentRecipe.videoPath!));
      } else if (_currentRecipe.screenshotPath != null &&
                 _currentRecipe.screenshotPath!.isNotEmpty &&
                 File(_currentRecipe.screenshotPath!).existsSync()) {
        filesToShare.add(XFile(_currentRecipe.screenshotPath!));
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
      final text = _buildRecipeText();
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recipe copied to clipboard!'),
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

  void _toggleStep(int index) {
    setState(() {
      if (_completedSteps.contains(index)) {
        _completedSteps.remove(index);
      } else {
        _completedSteps.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentRecipe.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Recipe',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RecipeEditorScreen(recipe: _currentRecipe),
                ),
              );
              // Refresh if changes were saved
              if (result == true && mounted) {
                await _refreshRecipe();
              }
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.share),
            tooltip: 'Share Recipe',
            onSelected: (String value) async {
              if (value == 'share') {
                await _shareRecipe(false);
              } else if (value == 'copy') {
                await _copyToClipboard();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'share',
                child: ListTile(
                  leading: Icon(Icons.share),
                  title: Text('Share with video'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'copy',
                child: ListTile(
                  leading: Icon(Icons.copy),
                  title: Text('Copy to clipboard'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 900;
          
          if (isWide) {
            // 2-Column Layout for Desktop/Wide Screens
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Media (Fixed Width or Flex)
                SizedBox(
                  width: 400, // Fixed width for media column side
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                         _buildMediaSection(context, colorScheme, theme),
                         const SizedBox(height: 16),
                         // Source link below media
                        if (_currentRecipe.videoUrl.isNotEmpty)
                          _buildSourceCard(context, colorScheme, theme),
                         if (_currentRecipe.authorComment != null &&
                            _currentRecipe.authorComment!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                           _buildAuthorNote(context, colorScheme, theme),
                        ],
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
                         _buildIngredientsSection(context, colorScheme, theme),
                         const SizedBox(height: 32),
                         _buildStepsSection(context, colorScheme, theme),
                         const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            );
          } else {
            // Original Single Column Layout for Mobile
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   _buildMediaSection(context, colorScheme, theme),
                   const SizedBox(height: 16),
                  if (_currentRecipe.videoUrl.isNotEmpty) ...[
                    _buildSourceCard(context, colorScheme, theme),
                    const SizedBox(height: 24),
                  ],
                  _buildIngredientsSection(context, colorScheme, theme),
                  const SizedBox(height: 32),
                  _buildStepsSection(context, colorScheme, theme),
                  if (_currentRecipe.authorComment != null &&
                      _currentRecipe.authorComment!.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    _buildAuthorNote(context, colorScheme, theme),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildMediaSection(BuildContext context, ColorScheme colorScheme, ThemeData theme) {
    if (_currentRecipe.mediaPaths.length > 1) {
      // Carousel View
      return Column(
        children: [
          SizedBox(
            height: 400, // Taller for carousel
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
                      itemCount: _currentRecipe.mediaPaths.length,
                      itemBuilder: (context, index) {
                        final path = _currentRecipe.mediaPaths[index];
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
                                Icon(Icons.broken_image, color: colorScheme.outline),
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
                if (_activePage < _currentRecipe.mediaPaths.length - 1)
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
          // Simple Dots Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_currentRecipe.mediaPaths.length, (index) {
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
              '${_currentRecipe.mediaPaths.length} Images',
              style: theme.textTheme.labelMedium?.copyWith(color: colorScheme.outline),
            ),
          ),
        ],
      );
    }
    
    // Single Image Fallback
    return Column(
      children: [
        if (_currentRecipe.thumbnailData != null)
                     ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.memory(
                        _currentRecipe.thumbnailData!,
                        width: double.infinity,
                        height: 250,
                        fit: BoxFit.cover,
                      ),
                    )
                  else if (_currentRecipe.screenshotPath != null &&
                      _currentRecipe.screenshotPath!.isNotEmpty &&
                      File(_currentRecipe.screenshotPath!).existsSync())
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        File(_currentRecipe.screenshotPath!),
                        width: double.infinity,
                        height: 250,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      height: 250,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image,
                            size: 64,
                            color: colorScheme.outline,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Media missing',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),

        const SizedBox(height: 16),

                  // Video Player Button
        if (_currentRecipe.videoPath != null &&
            _currentRecipe.videoPath!.isNotEmpty &&
            File(_currentRecipe.videoPath!).existsSync())
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VideoPlayerScreen(
                      videoPath: _currentRecipe.videoPath!,
                      title: _currentRecipe.title,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('Watch Original Video'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          )
        else 
           SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Download started in the background...'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
                await Provider.of<RecipeProvider>(context, listen: false)
                    .redownloadVideo(_currentRecipe.id!);
                await _refreshRecipe();
              },
              icon: const Icon(Icons.download),
              label: const Text('Download Media'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: colorScheme.errorContainer,
                foregroundColor: colorScheme.onErrorContainer,
              ),
            ),
          ),
      ],
    );
  }

  
  Widget _buildSourceCard(BuildContext context, ColorScheme colorScheme, ThemeData theme) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: () {
          Clipboard.setData(
              ClipboardData(text: _currentRecipe.videoUrl));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('URL copied to clipboard'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.link, color: colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Source',
                      style:
                          theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Instagram Reel',
                      style:
                          theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.copy,
                  size: 18, color: colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIngredientsSection(BuildContext context, ColorScheme colorScheme, ThemeData theme) {
    // Check if we have variations
    if (_currentRecipe.variations.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shopping_basket, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Ingredients',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Variations Carousel
          SizedBox(
            height: 400, // Adjust height as needed
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                },
              ),
              child: PageView.builder(
              controller: _ingredientsPageController,
              itemCount: _currentRecipe.variations.length,
              itemBuilder: (context, index) {
                final variation = _currentRecipe.variations[index];
                return Column(
                  children: [
                    // Variation Header with Navigation
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: index > 0 ? () {
                              _ingredientsPageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            } : null, 
                            color: index > 0 ? colorScheme.primary : Colors.transparent,
                          ),

                        Expanded(
                          child: Text(
                            variation.name,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.secondary,
                            ),
                          ),
                        ),

                           IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: index < _currentRecipe.variations.length - 1 ? () {
                              _ingredientsPageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            } : null,
                            color: index < _currentRecipe.variations.length - 1 ? colorScheme.primary : Colors.transparent,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Ingredients List for this variation
                    Expanded(
                      child: Card(
                        elevation: 0,
                        color: colorScheme.surfaceContainerHighest,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: SingleChildScrollView(
                            child: Column(
                                children: variation.ingredients.map((ingredient) {
                                  return _buildIngredientItem(ingredient, colorScheme, theme);
                                }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            ),
          ),
        ],
      );
    }
    
    // Fallback for no variations (old behavior)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.shopping_basket, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Ingredients',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          color: colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: _currentRecipe.ingredients.map((ingredient) {
                return _buildIngredientItem(ingredient, colorScheme, theme);
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIngredientItem(Ingredient ingredient, ColorScheme colorScheme, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.textTheme.bodyLarge?.color,
                ),
                children: [
                  if (ingredient.quantity.isNotEmpty) ...[
                    TextSpan(
                      text: ingredient.quantity,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                        fontSize: (theme.textTheme.bodyLarge?.fontSize ?? 16) + 1,
                      ),
                    ),
                    const TextSpan(text: ' '),
                  ],
                  if (ingredient.unit.isNotEmpty) ...[
                    TextSpan(
                      text: ingredient.unit,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.secondary,
                      ),
                    ),
                    const TextSpan(text: ' '),
                  ],
                  TextSpan(
                    text: ingredient.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepsSection(BuildContext context, ColorScheme colorScheme, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.format_list_numbered,
                color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Instructions',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ..._currentRecipe.steps.asMap().entries.map((entry) {
          int idx = entry.key;
          String step = entry.value;
          final isCompleted = _completedSteps.contains(idx);

          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            color: isCompleted
                ? colorScheme.primaryContainer.withValues(alpha: 0.5)
                : colorScheme.surfaceContainerHighest,
            child: InkWell(
              onTap: () => _toggleStep(idx),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? colorScheme.primary
                            : colorScheme.outline.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: isCompleted
                            ? Icon(
                                Icons.check,
                                color: colorScheme.onPrimary,
                                size: 18,
                              )
                            : Text(
                                '${idx + 1}',
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        step,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: isCompleted
                              ? colorScheme.onSurface
                                  .withValues(alpha: 0.6)
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAuthorNote(BuildContext context, ColorScheme colorScheme, ThemeData theme) {
    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.chat_bubble_outline,
                color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Author\'s Note',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          color: colorScheme.tertiaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _currentRecipe.authorComment!,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onTertiaryContainer,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

