import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recipe.dart';
import '../providers/recipe_provider.dart';

class RecipeEditorScreen extends StatefulWidget {
  final Recipe recipe;

  const RecipeEditorScreen({super.key, required this.recipe});

  @override
  State<RecipeEditorScreen> createState() => _RecipeEditorScreenState();
}

class _RecipeEditorScreenState extends State<RecipeEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _authorCommentController;
  late List<RecipeVariation> _variations;
  late List<String> _steps;
  int _currentVariationIndex = 0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.recipe.title);
    _authorCommentController = TextEditingController(text: widget.recipe.authorComment ?? '');
    
    // Initialize variations
    if (widget.recipe.variations.isNotEmpty) {
      _variations = widget.recipe.variations.map((v) => RecipeVariation(
        name: v.name,
        ingredients: List.from(v.ingredients),
      )).toList();
    } else {
      // Create default variation from existing ingredients
      _variations = [
        RecipeVariation(
          name: 'Original',
          ingredients: List.from(widget.recipe.ingredients),
        )
      ];
    }

    _steps = List.from(widget.recipe.steps);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorCommentController.dispose();
    super.dispose();
  }

  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final updatedRecipe = widget.recipe.copyWith(
        title: _titleController.text.trim(),
        ingredients: _variations.isNotEmpty ? _variations.first.ingredients : [],
        variations: _variations,
        steps: _steps,
        authorComment: _authorCommentController.text.trim().isEmpty 
            ? null 
            : _authorCommentController.text.trim(),
      );

      await Provider.of<RecipeProvider>(context, listen: false)
          .updateRecipe(updatedRecipe);

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate changes were saved
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving recipe: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _addIngredient() {
    setState(() {
      _variations[_currentVariationIndex].ingredients.add(
        Ingredient(name: '', quantity: '', unit: '')
      );
    });
  }

  void _removeIngredient(int index) {
    setState(() {
      _variations[_currentVariationIndex].ingredients.removeAt(index);
    });
  }

  void _addVariation() {
    setState(() {
      _variations.add(RecipeVariation(
        name: 'Variation ${_variations.length + 1}',
        ingredients: [],
      ));
      _currentVariationIndex = _variations.length - 1;
    });
  }

  void _removeVariation(int index) {
    if (_variations.length <= 1) return;
    setState(() {
      _variations.removeAt(index);
      if (_currentVariationIndex >= _variations.length) {
        _currentVariationIndex = _variations.length - 1;
      }
    });
  }

  void _renameVariation(String newName) {
    setState(() {
      _variations[_currentVariationIndex] = RecipeVariation(
        name: newName,
        ingredients: _variations[_currentVariationIndex].ingredients,
      );
    });
  }

  void _addStep() {
    setState(() {
      _steps.add('');
    });
  }

  void _removeStep(int index) {
    setState(() {
      _steps.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Recipe'),
        actions: [
          if (!_isSaving)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveRecipe,
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
                      labelText: 'Recipe Title',
                      prefixIcon: Icon(Icons.restaurant),
                    ),
                    style: theme.textTheme.titleLarge,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Title is required';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 32),

                  // Variations Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.style, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Variations',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle),
                        onPressed: _addVariation,
                        tooltip: 'Add Variation',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Variations Tabs
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _variations.asMap().entries.map((entry) {
                        final index = entry.key;
                        final variation = entry.value;
                        final isSelected = index == _currentVariationIndex;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(variation.name.isNotEmpty ? variation.name : 'Untitled'),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _currentVariationIndex = index;
                                });
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Current Variation Editor
                  Card(
                    color: colorScheme.surfaceContainerHighest,
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            // Variation Name & Actions
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    key: ValueKey('variation_name_$_currentVariationIndex'),
                                    initialValue: _variations[_currentVariationIndex].name,
                                    decoration: const InputDecoration(
                                      labelText: 'Variation Name',
                                      prefixIcon: Icon(Icons.edit),
                                    ),
                                    onChanged: _renameVariation,
                                  ),
                                ),
                                if (_variations.length > 1)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    color: colorScheme.error,
                                    onPressed: () => _removeVariation(_currentVariationIndex),
                                    tooltip: 'Delete Variation',
                                  ),
                              ],
                            ),
                            const Divider(height: 32),
                            
                            // Ingredients Header
                             Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Ingredients',
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle),
                                  onPressed: _addIngredient,
                                  tooltip: 'Add Ingredient',
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Ingredients List
                            ..._variations[_currentVariationIndex].ingredients.asMap().entries.map((entry) {
                              final index = entry.key;
                              final ingredient = entry.value;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                color: colorScheme.surface,
                                key: ValueKey('variation_ingredient_${_currentVariationIndex}_$index'),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: TextFormField(
                                          initialValue: ingredient.name,
                                          decoration: const InputDecoration(
                                            labelText: 'Name',
                                            isDense: true,
                                            border: InputBorder.none,
                                          ),
                                          onChanged: (value) {
                                            setState(() {
                                              _variations[_currentVariationIndex].ingredients[index] = Ingredient(
                                                name: value,
                                                quantity: ingredient.quantity,
                                                unit: ingredient.unit,
                                              );
                                            });
                                          },
                                        ),
                                      ),
                                      Container(width: 1, height: 24, color: colorScheme.outlineVariant),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: ingredient.quantity,
                                          decoration: const InputDecoration(
                                            labelText: 'Qty',
                                            isDense: true,
                                            border: InputBorder.none,
                                          ),
                                          onChanged: (value) {
                                             setState(() {
                                              _variations[_currentVariationIndex].ingredients[index] = Ingredient(
                                                name: ingredient.name,
                                                quantity: value,
                                                unit: ingredient.unit,
                                              );
                                            });
                                          },
                                        ),
                                      ),
                                      Container(width: 1, height: 24, color: colorScheme.outlineVariant),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: ingredient.unit,
                                          decoration: const InputDecoration(
                                            labelText: 'Unit',
                                            isDense: true,
                                            border: InputBorder.none,
                                          ),
                                          onChanged: (value) {
                                             setState(() {
                                              _variations[_currentVariationIndex].ingredients[index] = Ingredient(
                                                name: ingredient.name,
                                                quantity: ingredient.quantity,
                                                unit: value,
                                              );
                                            });
                                          },
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close, size: 18),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => _removeIngredient(index),
                                        color: colorScheme.error,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            
                            if (_variations[_currentVariationIndex].ingredients.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Center(
                                  child: Text(
                                    'No ingredients added yet',
                                    style: TextStyle(color: colorScheme.outline),
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Steps Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.list_alt, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Steps',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle),
                        onPressed: _addStep,
                        tooltip: 'Add Step',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  ..._steps.asMap().entries.map((entry) {
                    final index = entry.key;
                    final step = entry.value;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: colorScheme.primaryContainer,
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                initialValue: step,
                                decoration: const InputDecoration(
                                  hintText: 'Enter step description',
                                  border: InputBorder.none,
                                ),
                                maxLines: null,
                                onChanged: (value) {
                                  _steps[index] = value;
                                },
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Step cannot be empty';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 20),
                              onPressed: () => _removeStep(index),
                              color: Colors.red,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 32),

                  // Author Comment Section
                  Row(
                    children: [
                      Icon(Icons.chat_bubble_outline, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Author\'s Note (Optional)',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _authorCommentController,
                    decoration: const InputDecoration(
                      hintText: 'Add any notes or tips...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 4,
                  ),

                  const SizedBox(height: 32),

                  // Save Button
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _saveRecipe,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Changes'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}
