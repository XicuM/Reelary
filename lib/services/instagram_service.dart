import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'settings_service.dart';

class InstagramService {
  
  Future<String> _getRapidApiKey() async {
    return await SettingsService.getEffectiveRapidApiKey() ?? '';
  }
  
  String get _rapidApiHost =>
      dotenv.env['RAPIDAPI_HOST'] ?? 'instagram-looter2.p.rapidapi.com';
  String get _endpoint => dotenv.env['INSTAGRAM_POST_INFO_ENDPOINT'] ?? '/post';

  Future<String> downloadInstagramVideo(String instagramUrl) async {
    try {
      // Validate Instagram URL
      if (!instagramUrl.contains('instagram.com')) {
        throw Exception('Invalid Instagram URL');
      }

      debugPrint('Fetching video info from RapidAPI: $instagramUrl');

      // Step 1: Get video URL from RapidAPI
      final videoUrl = await _getVideoUrlFromApi(instagramUrl);

      // Step 2: Download the video
      final videoPath = await _downloadFile(videoUrl);

      debugPrint('Video downloaded successfully to: $videoPath');
      return videoPath;
    } catch (e) {
      debugPrint('Error downloading Instagram video: $e');
      rethrow;
    }
  }

  /// Fetches video URL from RapidAPI Instagram Downloader
  Future<String> _getVideoUrlFromApi(String instagramUrl) async {
    final rapidApiKey = await _getRapidApiKey();
    
    if (rapidApiKey.isEmpty) {
      throw Exception('RapidAPI key not configured.\n\n'
          'Please configure it in Settings or add RAPIDAPI_KEY to your .env file.\n'
          'Sign up at: https://rapidapi.com/\n'
          'Subscribe to: Instagram Looter API\n'
          'https://rapidapi.com/irrors-apis/api/instagram-looter2\n\n'
          'Alternative: Use a different API service or implement your own backend.');
    }

    try {
      // Instagram Looter API uses 'link' parameter
      final uri = Uri.parse('https://$_rapidApiHost$_endpoint')
          .replace(queryParameters: {
        'link': instagramUrl,
      });

      debugPrint('Querying Instagram Looter API: $_endpoint');
      final response = await http.get(
        uri,
        headers: {
          'X-RapidAPI-Key': rapidApiKey,
          'X-RapidAPI-Host': _rapidApiHost,
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
            'API request failed: ${response.statusCode} - ${response.body}');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;

      // Check API success status
      if (data['status'] != true) {
        throw Exception(
            'API returned unsuccessful status. Response: ${response.body}');
      }

      // Extract video URL from Instagram Looter API response
      // The API returns video_url directly for video posts
      String? videoUrl;

      if (data['video_url'] is String &&
          (data['video_url'] as String).isNotEmpty) {
        videoUrl = data['video_url'];
      } else if (data['display_url'] is String) {
        // Fallback to display_url (image) if no video
        videoUrl = data['display_url'];
      }

      if (videoUrl == null || videoUrl.isEmpty) {
        throw Exception(
            'No video URL found in API response. This might be an image post or carousel. Response: ${response.body}');
      }

      debugPrint('Video URL retrieved: $videoUrl');
      return videoUrl;
    } catch (e) {
      debugPrint('Error fetching from RapidAPI: $e');
      rethrow;
    }
  }

  /// Downloads a file from URL and saves it locally
  Future<String> _downloadFile(String url) async {
    try {
      // Get the application directory based on platform
      final Directory directory;
      if (Platform.isWindows) {
        directory = await getApplicationSupportDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }
      final downloadsDir = Directory('${directory.path}/reelary_downloads');

      // Create downloads directory if it doesn't exist
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      // Generate a unique filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = url.contains('.mp4') ? '.mp4' : '.jpg';
      final filename = 'video_$timestamp$extension';
      final filePath = '${downloadsDir.path}/$filename';

      debugPrint('Downloading file from: $url');

      // Download the file
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to download file: ${response.statusCode}');
      }

      // Save to file
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      debugPrint('File saved to: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('Error downloading file: $e');
      rethrow;
    }
  }

  /// Checks if network is available
  Future<bool> isNetworkAvailable() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
