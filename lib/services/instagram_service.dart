import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'settings_service.dart';

class InstagramService {
  // RapidAPI configuration loaded from settings or .env file
  // Get your API key from: https://rapidapi.com/
  // Currently using Instagram Looter API: https://rapidapi.com/irrors-apis/api/instagram-looter2
  
  Future<String> _getRapidApiKey() async {
    String? key = await SettingsService.getRapidApiKey();
    return key ?? dotenv.env['RAPIDAPI_KEY'] ?? '';
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
      // Get the application documents directory
      final directory = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${directory.path}/insta2cook_downloads');

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

  /// [DEPRECATED] Direct URL extraction no longer works due to Instagram's anti-scraping measures
  /// Use downloadInstagramVideo() instead which uses RapidAPI
  @Deprecated(
      'Instagram blocks direct HTML scraping. Use downloadInstagramVideo() instead.')
  Future<List<String>> extractMediaUrls(String instagramUrl) async {
    final mediaUrls = <String>[];

    try {
      // Validate Instagram URL
      if (!instagramUrl.contains('instagram.com')) {
        throw Exception('Invalid Instagram URL');
      }

      // Remove query parameters from URL and ensure it ends with /
      var cleanUrl = instagramUrl.split('?').first;
      if (!cleanUrl.endsWith('/')) {
        cleanUrl += '/';
      }

      debugPrint('Fetching Instagram page: $cleanUrl');

      // Fetch the HTML page with browser-like headers
      // Note: Don't request gzip encoding to avoid decompression issues
      final response = await http.get(
        Uri.parse(cleanUrl),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.5',
          'Connection': 'keep-alive',
          'Upgrade-Insecure-Requests': '1',
          'Sec-Fetch-Dest': 'document',
          'Sec-Fetch-Mode': 'navigate',
          'Sec-Fetch-Site': 'none',
          'Cache-Control': 'max-age=0',
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to fetch Instagram page: ${response.statusCode}');
      }

      // Use body which is already decoded as UTF-8 string
      final html = response.body;

      // Method 1: Try to find JSON data in script tags
      // Instagram embeds data in <script type="application/ld+json">
      final ldJsonRegex = RegExp(
          r'<script type="application/ld\+json">({.*?})</script>',
          dotAll: true);
      final ldJsonMatch = ldJsonRegex.firstMatch(html);

      if (ldJsonMatch != null) {
        try {
          final jsonStr = ldJsonMatch.group(1)!;
          final jsonData = json.decode(jsonStr);

          // Extract video URL from JSON-LD
          if (jsonData['@type'] == 'VideoObject' &&
              jsonData['contentUrl'] != null) {
            mediaUrls.add(jsonData['contentUrl']);
            debugPrint('Found video URL via JSON-LD: ${jsonData['contentUrl']}');
            return mediaUrls;
          } else if (jsonData['video'] != null && jsonData['video'] is List) {
            for (var video in jsonData['video']) {
              if (video['contentUrl'] != null) {
                mediaUrls.add(video['contentUrl']);
                debugPrint(
                    'Found video URL via JSON-LD array: ${video['contentUrl']}');
              }
            }
            if (mediaUrls.isNotEmpty) return mediaUrls;
          }
        } catch (e) {
          debugPrint('Error parsing JSON-LD: $e');
        }
      }

      // Method 2: Look for video URLs in meta tags
      final ogVideoRegex =
          RegExp(r'<meta property="og:video" content="([^"]+)"');
      final ogVideoMatch = ogVideoRegex.firstMatch(html);
      if (ogVideoMatch != null) {
        final videoUrl = ogVideoMatch.group(1)!;
        mediaUrls.add(videoUrl);
        debugPrint('Found video URL via og:video meta tag: $videoUrl');
        return mediaUrls;
      }

      // Method 3: Look for video URLs in the HTML content
      final videoUrlRegex = RegExp(r'"video_url":"([^"]+)"');
      final videoMatches = videoUrlRegex.allMatches(html);
      for (var match in videoMatches) {
        var videoUrl = match.group(1)!;
        // Unescape the URL
        videoUrl = videoUrl.replaceAll(r'\u0026', '&');
        if (!mediaUrls.contains(videoUrl)) {
          mediaUrls.add(videoUrl);
          debugPrint('Found video URL in HTML: $videoUrl');
        }
      }

      if (mediaUrls.isNotEmpty) {
        return mediaUrls;
      }

      // Method 4: Look for display_url (images)
      final displayUrlRegex = RegExp(r'"display_url":"([^"]+)"');
      final displayMatches = displayUrlRegex.allMatches(html);
      for (var match in displayMatches) {
        var imageUrl = match.group(1)!;
        imageUrl = imageUrl.replaceAll(r'\u0026', '&');
        if (!mediaUrls.contains(imageUrl)) {
          mediaUrls.add(imageUrl);
          debugPrint('Found image URL: $imageUrl');
        }
      }

      if (mediaUrls.isEmpty) {
        throw Exception(
            'No media URLs found. Instagram blocks direct HTML scraping.\n'
            'Please use downloadVideoWithYtDlp() instead, which requires yt-dlp to be installed.\n'
            'See INSTAGRAM_VIDEO_DOWNLOAD.md for details.');
      }
    } catch (e) {
      debugPrint('Error extracting Instagram media: $e');
      rethrow;
    }

    return mediaUrls;
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

  /// Downloads video using a third-party API service
  /// This is the recommended approach for Android/iOS
  /// Requires API key configuration
  Future<String> downloadVideoViaApi(String instagramUrl) async {
    // TODO: Implement with your chosen API service
    // Options:
    // 1. RapidAPI Instagram Downloader
    // 2. Your own backend server
    // 3. Other Instagram API services

    throw UnimplementedError('API-based download not yet implemented.\n'
        'For Android support, you need to:\n'
        '1. Choose an API service (e.g., RapidAPI Instagram Downloader)\n'
        '2. Sign up and get API key\n'
        '3. Implement downloadVideoViaApi() method\n'
        'See INSTAGRAM_VIDEO_DOWNLOAD.md for examples.');

    // Example implementation:
    // final response = await http.get(
    //   Uri.parse('https://instagram-api.com/download?url=$instagramUrl'),
    //   headers: {'X-API-Key': 'YOUR_KEY'},
    // );
    // final videoUrl = json.decode(response.body)['video_url'];
    // return await _downloadFile(videoUrl);
  }
}
