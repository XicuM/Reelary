import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _geminiApiKeyKey = 'gemini_api_key';
  static const String _rapidApiKeyKey = 'rapid_api_key';

  // Get Gemini API Key
  static Future<String?> getGeminiApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_geminiApiKeyKey);
  }

  // Get Effective Gemini API Key (Settings > .env)
  static Future<String?> getEffectiveGeminiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_geminiApiKeyKey);
    if (key != null && key.isNotEmpty) return key;
    return dotenv.env['GEMINI_API_KEY'];
  }

  static Future<bool> hasGeminiKey() async {
    final key = await getEffectiveGeminiKey();
    return key != null && key.isNotEmpty;
  }

  // Set Gemini API Key
  static Future<bool> setGeminiApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_geminiApiKeyKey, key);
  }

  // Get RapidAPI Key
  static Future<String?> getRapidApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_rapidApiKeyKey);
  }

  // Get Effective RapidAPI Key (Settings > .env)
  static Future<String?> getEffectiveRapidApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_rapidApiKeyKey);
    if (key != null && key.isNotEmpty) return key;
    return dotenv.env['RAPIDAPI_KEY'];
  }

  static Future<bool> hasRapidApiKey() async {
    final key = await getEffectiveRapidApiKey();
    return key != null && key.isNotEmpty;
  }

  // Set RapidAPI Key
  static Future<bool> setRapidApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_rapidApiKeyKey, key);
  }

  // Clear all settings
  static Future<bool> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_geminiApiKeyKey);
    await prefs.remove(_rapidApiKeyKey);
    return true;
  }

  // Check if API keys are configured
  static Future<bool> hasApiKeys() async {
    return (await hasGeminiKey()) || (await hasRapidApiKey());
  }
}
