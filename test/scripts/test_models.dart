import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  // Load environment variables if possible, or just expect the user to have it
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    // If running from test/, .env might be in root
    await dotenv.load(fileName: "../.env");
  }
  final apiKey = dotenv.env['GEMINI_API_KEY'];

  if (apiKey == null) {
    print('No API KEY found in .env');
    return;
  }

  // There isn't a direct "listModels" on the GenerativeModel class in simpler versions,
  // but checking if we can use a model that definitely works is better.
  // Actually, the error suggested "Call ListModels", which might refer to the REST API.
  // The Dart SDK might not have a helper for it in 0.4.x.
  
  // Instead of listing, let's just try to instantiate 1.5-flash and see if it works with a hello world.
  final modelsToTest = ['gemini-2.0-flash', 'gemini-1.5-flash', 'gemini-1.5-pro'];

  for (final modelName in modelsToTest) {
    print('Testing model: $modelName...');
    final model = GenerativeModel(model: modelName, apiKey: apiKey);
    try {
      final response = await model.generateContent([Content.text('Hello')]);
      print('SUCCESS: $modelName is available. Response: ${response.text}');
    } catch (e) {
      print('FAILED: $modelName. Error: $e');
    }
    print('---');
  }
}
