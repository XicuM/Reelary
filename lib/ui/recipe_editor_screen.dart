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
  late List<Ingredient> _ingredients;
  late List<String> _steps;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.recipe.title);
    _authorCommentController = TextEditingController(text: widget.recipe.authorComment ?? '');
    _ingredients = List.from(widget.recipe.ingredients);
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
        ingredients: _ingredients,
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
      _ingredients.add(Ingredient(name: '', quantity: '', unit: ''));
    });
  }

  void _removeIngredient(int index) {
    setState(() {
      _ingredients.removeAt(index);
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

                  // Ingredients Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                      IconButton(
                        icon: const Icon(Icons.add_circle),
                        onPressed: _addIngredient,
                        tooltip: 'Add Ingredient',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  ..._ingredients.asMap().entries.map((entry) {
                    final index = entry.key;
                    final ingredient = entry.value;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    initialValue: ingredient.name,
                                    decoration: const InputDecoration(
                                      labelText: 'Name',
                                      isDense: true,
                                    ),
                                    onChanged: (value) {
                                      _ingredients[index] = Ingredient(
                                        name: value,
                                        quantity: ingredient.quantity,
                                        unit: ingredient.unit,
                                      );
                                    },
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Required';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: ingredient.quantity,
                                    decoration: const InputDecoration(
                                      labelText: 'Qty',
                                      isDense: true,
                                    ),
                                    onChanged: (value) {
                                      _ingredients[index] = Ingredient(
                                        name: ingredient.name,
                                        quantity: value,
                                        unit: ingredient.unit,
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: ingredient.unit,
                                    decoration: const InputDecoration(
                                      labelText: 'Unit',
                                      isDense: true,
                                    ),
                                    onChanged: (value) {
                                      _ingredients[index] = Ingredient(
                                        name: ingredient.name,
                                        quantity: ingredient.quantity,
                                        unit: value,
                                      );
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 20),
                                  onPressed: () => _removeIngredient(index),
                                  color: Colors.red,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

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
