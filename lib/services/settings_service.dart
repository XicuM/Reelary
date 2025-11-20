import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _geminiApiKeyKey = 'gemini_api_key';
  static const String _rapidApiKeyKey = 'rapid_api_key';

  // Get Gemini API Key
  static Future<String?> getGeminiApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_geminiApiKeyKey);
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
    final geminiKey = await getGeminiApiKey();
    final rapidKey = await getRapidApiKey();
    return (geminiKey != null && geminiKey.isNotEmpty) ||
           (rapidKey != null && rapidKey.isNotEmpty);
  }
}
