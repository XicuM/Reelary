import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';

// Simple .env parser to avoid flutter_dotenv dependency
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
    print('No API KEY found in .env');
    return;
  }

  print('Using API Key: ${apiKey.substring(0, 5)}...');

  final modelsToTest = [
    'gemini-2.0-flash',
    'gemini-1.5-flash',
    'gemini-1.5-flash-001',
    'gemini-1.5-flash-latest',
    'gemini-1.0-pro',
    'gemini-pro',
    'gemini-pro-vision'
  ];

  print('Testing models...');
  
  for (final modelName in modelsToTest) {
    stdout.write('Testing $modelName... ');
    final model = GenerativeModel(model: modelName, apiKey: apiKey);
    try {
      final response = await model.generateContent([Content.text('Hi')]);
      print('✅ SUCCESS');
    } catch (e) {
      if (e.toString().contains('429') || e.toString().contains('quota')) {
        print('⚠️ QUOTA (Model exists)');
      } else if (e.toString().contains('404') || e.toString().contains('not found')) {
        print('❌ NOT FOUND');
      } else {
        print('❌ ERROR: $e');
      }
    }
  }
}
