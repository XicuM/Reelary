import 'dart:convert';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recipe.dart';
import '../models/place.dart';
import '../models/location.dart';
import 'settings_service.dart';

class GeminiService {
  GenerativeModel? _model;

  Future<String> _getApiKey() async {
    // Try to get API key from settings first, then fallback to .env
    String? apiKey = await SettingsService.getGeminiApiKey();
    apiKey ??= dotenv.env['GEMINI_API_KEY'];
    
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception(
          'GEMINI_API_KEY not found. Please configure it in Settings or add to .env file.');
    }
    return apiKey;
  }

  Future<GenerativeModel> _getModel() async {
    if (_model != null) return _model!;
    
    final apiKey = await _getApiKey();
    
    _model = GenerativeModel(
      model: 'gemini-3-flash-preview',
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

  static const Duration _rateLimitWindow = Duration(minutes: 1);
  static const int _maxRequestsPerWindow = 15;
  static const String _prefsKey = 'gemini_request_timestamps';

  Future<void> _enforceRateLimit() async {
    final prefs = await SharedPreferences.getInstance();
    
    while (true) {
      final now = DateTime.now();
      
      // 1. Load and parse timestamps
      List<String> storedTimestamps = prefs.getStringList(_prefsKey) ?? [];
      List<DateTime> timestamps = storedTimestamps
          .map((ts) => DateTime.tryParse(ts))
          .where((dt) => dt != null)
          .cast<DateTime>()
          .toList();

      // 2. Prune timestamps older than the window
      timestamps.removeWhere((t) => now.difference(t) > _rateLimitWindow);

      // 3. Check if we have space in the window
      if (timestamps.length < _maxRequestsPerWindow) {
        timestamps.add(now); // Reserve the slot
        // Save back to prefs
        await prefs.setStringList(_prefsKey, timestamps.map((t) => t.toIso8601String()).toList());
        return; // Proceed
      }

      // 4. If full, calculate wait time based on the oldest request
      // We sort just in case, though they should be chronological
      timestamps.sort();
      final oldest = timestamps.first;
      final timeSinceOldest = now.difference(oldest);
      final waitTime = _rateLimitWindow - timeSinceOldest + const Duration(milliseconds: 200); // + buffer

      if (waitTime > Duration.zero) {
        print('Client-side persistent rate limit (2 RPM) reached. Waiting ${waitTime.inSeconds}s...');
        await Future.delayed(waitTime);
        // After waiting, loop repeats to re-check storage (in case another process updated it, theoretically)
      } else {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  Future<T> _retryWithBackoff<T>(Future<T> Function() operation, {int maxRetries = 3}) async {
    // Enforce client-side rate limit BEFORE attempting
    await _enforceRateLimit();

    int attempts = 0;
    while (true) {
      try {
        return await operation();
      } catch (e) {
        attempts++;
        if (attempts >= maxRetries) rethrow;

        if (e.toString().contains('429') || e.toString().contains('quota')) {
          // Exponential backoff: 2s, 4s, 8s
          final delay = Duration(seconds: 2 * attempts);
          print('Quota exceeded. Retrying in ${delay.inSeconds} seconds... (Attempt $attempts/$maxRetries)');
          await Future.delayed(delay);
        } else {
          rethrow;
        }
      }
    }
  }

  Future<Recipe> generateRecipe({
    required String videoPath,
    required String authorComment,
    required String videoUrl,
  }) async {
    return _retryWithBackoff(() async {
      final key = await _getApiKey(); // Ensure key is fresh
      final model = await _getModel();
      
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

      final response = await model.generateContent(content);

      if (response.text == null) {
        throw Exception('Failed to generate recipe from Gemini');
      }

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
    });
  }

  Future<Map<String, dynamic>> extractPlaces({
    required String videoPath,
    required String videoUrl,
  }) async {
    return _retryWithBackoff(() async {
      final model = await _getModel();
      
      final videoFile = File(videoPath);
      final videoBytes = await videoFile.readAsBytes();

      final prompt = '''
      Analyze this video and extract information about places/locations shown or mentioned.
      This could be restaurants, cafes, bars, tourist attractions, travel destinations, or any points of interest.
      
      Please provide the output in the following JSON format:
      {
        "title": "Descriptive title for this place entry (e.g., 'Restaurants in Paris', 'Tokyo Food Tour', 'Beach in Bali')",
        "description": "A brief description of what's shown in the video (2-3 sentences)",
        "category": "One of: Restaurant, Travel Spot, Activities, Nature",
        "locations": [
          {
            "name": "Place Name",
            "address": "Full address if visible or mentioned (or null if not available)",
            "latitude": null or number if coordinates can be determined,
            "longitude": null or number if coordinates can be determined
          }
        ]
      }
      
      Category Guidelines:
      - "Restaurant" for food establishments (restaurants, cafes, bars, bakeries, street food)
      - "Travel Spot" for travel destinations, cities, countries, famous landmarks, hotels
      - "Activities" for entertainment, sports, museums, theme parks, shopping, cultural events
      - "Nature" for natural locations (beaches, mountains, parks, forests, wildlife areas)
      
      Important instructions:
      - Extract ALL distinct locations shown or mentioned in the video
      - If multiple locations are shown (like a food tour), include all of them
      - Try to extract specific place names (restaurant names, attraction names, etc.)
      - If you see text, signs, or overlays showing addresses or location names, extract them
      - If you can identify the place (e.g. "Eiffel Tower"), you can provide its known coordinates.
      - If no specific address is visible, leave it as null
      - The title should summarize what all the locations are about
      - If the video shows a route or tour, mention that in the title
      
      If the video does not contain any identifiable places, return a JSON with a generic title like "Location" and an empty description, but at least one location with just a name.
      ''';

      final mimeType = _getMimeType(videoPath);

      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart(mimeType, videoBytes),
        ])
      ];

      final response = await model.generateContent(content);

      if (response.text == null) {
        throw Exception('Failed to extract places from Gemini');
      }

      // Strip markdown code blocks if present
      String responseText = response.text!.trim();
      if (responseText.startsWith('```json')) {
        responseText = responseText.substring(7);
      } else if (responseText.startsWith('```')) {
        responseText = responseText.substring(3);
      }
      if (responseText.endsWith('```')) {
        responseText = responseText.substring(0, responseText.length - 3);
      }
      responseText = responseText.trim();

      final jsonResponse = jsonDecode(responseText);

      List<Location> locations = [];
      if (jsonResponse['locations'] != null) {
        locations = List<Location>.from(
          jsonResponse['locations'].map((x) => Location.fromMap(x)),
        );
      }

      // Ensure at least one location exists
      if (locations.isEmpty) {
        locations = [
          Location(
            name: 'Location',
            address: null,
            latitude: null,
            longitude: null,
          )
        ];
      }

      final category = jsonResponse['category'] as String?;
      final suggestedTag = _mapCategoryToTag(category);

      final place = Place(
        title: jsonResponse['title'] ?? 'Place',
        videoUrl: videoUrl,
        locations: locations,
        description: jsonResponse['description'] ?? '',
        dateCreated: DateTime.now(),
        tagIds: [],
        // screenshotPath and videoPath will be handled separately
      );

      return {
        'place': place,
        'suggestedTag': suggestedTag,
      };
    });
  }

  String _mapCategoryToTag(String? category) {
    if (category == null) return 'Travel Spot';
    
    final normalized = category.toLowerCase().trim();
    if (normalized.contains('restaurant') || normalized.contains('food') || 
        normalized.contains('cafe') || normalized.contains('bar')) {
      return 'Restaurant';
    } else if (normalized.contains('nature') || normalized.contains('beach') || 
               normalized.contains('mountain') || normalized.contains('park')) {
      return 'Nature';
    } else if (normalized.contains('activit') || normalized.contains('entertainment') || 
               normalized.contains('museum') || normalized.contains('sport')) {
      return 'Activities';
    } else {
      return 'Travel Spot';
    }
  }
}
