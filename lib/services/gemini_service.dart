import 'dart:convert';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/recipe.dart';
import 'settings_service.dart';

class GeminiService {
  GenerativeModel? _model;

  Future<GenerativeModel> _getModel() async {
    if (_model != null) return _model!;
    
    // Try to get API key from settings first, then fallback to .env
    String? apiKey = await SettingsService.getGeminiApiKey();
    apiKey ??= dotenv.env['GEMINI_API_KEY'];
    
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception(
          'GEMINI_API_KEY not found. Please configure it in Settings or add to .env file.');
    }
    
    _model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: apiKey,
    );
    return _model!;
  }

  String _getMimeType(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    switch (ext) {
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      case 'wmv':
        return 'video/x-ms-wmv';
      case 'mpg':
      case 'mpeg':
        return 'video/mpeg';
      case 'webm':
        return 'video/webm';
      case 'flv':
        return 'video/x-flv';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      default:
        return 'video/mp4'; // Default fallback
    }
  }

  Future<Recipe> generateRecipe({
    required String videoPath,
    required String authorComment,
    required String videoUrl,
  }) async {
    final videoFile = File(videoPath);
    final videoBytes = await videoFile.readAsBytes();

    final prompt = '''
    Extract a recipe from this video and the author's comment.
    
    Author's Comment:
    $authorComment

    Please provide the output in the following JSON format:
    {
      "title": "Recipe Title",
      "ingredients": [
        {
          "name": "Ingredient Name (just the ingredient, without quantity)",
          "quantity": "Quantity as a number or fraction (e.g. 2, 1/2, 0.5, 100)",
          "unit": "Unit of measurement (e.g. cup, cups, g, grams, ml, tbsp, tsp, oz, lb, kg, or empty string if none)"
        }
      ],
      "steps": [
        "Step 1 description",
        "Step 2 description"
      ]
    }
    
    Important instructions for ingredients:
    - Separate the quantity from the ingredient name
    - Keep quantities as numbers/fractions in the quantity field (e.g., "2", "1/2", "0.5")
    - Put measurement units in the unit field (e.g., "cups", "tbsp", "g")
    - If no specific quantity, use "to taste" or "as needed" in quantity field
    - Examples:
      * "2 cups flour" -> {"name": "flour", "quantity": "2", "unit": "cups"}
      * "1/2 tsp salt" -> {"name": "salt", "quantity": "1/2", "unit": "tsp"}
      * "100g butter" -> {"name": "butter", "quantity": "100", "unit": "g"}
      * "Salt to taste" -> {"name": "salt", "quantity": "to taste", "unit": ""}
    
    If the video or comment does not contain a recipe, return a JSON with empty fields but do not error out.
    ''';

    final mimeType = _getMimeType(videoPath);

    final content = [
      Content.multi([
        TextPart(prompt),
        DataPart(mimeType, videoBytes),
      ])
    ];

    final model = await _getModel();
    final response = await model.generateContent(content);

    if (response.text == null) {
      throw Exception('Failed to generate recipe from Gemini');
    }

    try {
      // Strip markdown code blocks if present (```json ... ```)
      String responseText = response.text!.trim();
      if (responseText.startsWith('```json')) {
        responseText = responseText.substring(7); // Remove ```json
      } else if (responseText.startsWith('```')) {
        responseText = responseText.substring(3); // Remove ```
      }
      if (responseText.endsWith('```')) {
        responseText = responseText.substring(
            0, responseText.length - 3); // Remove trailing ```
      }
      responseText = responseText.trim();

      final jsonResponse = jsonDecode(responseText);

      List<Ingredient> ingredients = [];
      if (jsonResponse['ingredients'] != null) {
        ingredients = List<Ingredient>.from(
          jsonResponse['ingredients'].map((x) => Ingredient.fromMap(x)),
        );
      }

      List<String> steps = [];
      if (jsonResponse['steps'] != null) {
        steps = List<String>.from(jsonResponse['steps']);
      }

      return Recipe(
        title: jsonResponse['title'] ?? 'Unknown Recipe',
        videoUrl: videoUrl,
        ingredients: ingredients,
        steps: steps,
        authorComment: authorComment,
        dateCreated: DateTime.now(),
        // screenshotPath will be handled separately
      );
    } catch (e) {
      throw Exception('Failed to parse Gemini response: $e');
    }
  }
}
