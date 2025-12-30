import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Simple .env parser (reused to avoid strict dependency on flutter context)
Map<String, String> loadEnv() {
  var file = File('.env');
  if (!file.existsSync()) {
    file = File('../.env');
  }
  if (!file.existsSync()) return {};
  final lines = file.readAsLinesSync();
  final map = <String, String>{};
  for (final line in lines) {
    if (line.trim().isEmpty || line.startsWith('#')) continue;
    final parts = line.split('=');
    if (parts.length >= 2) {
      final key = parts[0].trim();
      final value = parts.sublist(1).join('=').trim();
      map[key] = value;
    }
  }
  return map;
}

Future<void> main() async {
  final env = loadEnv();
  final apiKey = env['GEMINI_API_KEY'];

  if (apiKey == null) {
    print('No API KEY found.');
    return;
  }

  print('Listing models for API Key ending in ...${apiKey.substring(apiKey.length - 4)}');
  
  // Use REST API directly to list models
  final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey');
  
  try {
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List models = data['models'];
      print('Found ${models.length} models:');
      for (var m in models) {
        print('- ${m['name']} (${m['displayName']})');
      }
    } else {
      print('Failed to list models. Status: ${response.statusCode}');
      print('Body: ${response.body}');
    }
  } catch (e) {
    print('Error requesting models: $e');
  }
}
