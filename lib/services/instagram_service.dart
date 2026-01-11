import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'settings_service.dart';

class InstagramService {
  
  final http.Client _client;

  InstagramService({http.Client? client}) : _client = client ?? http.Client();
  
  Future<String> _getRapidApiKey() async {
    return await SettingsService.getEffectiveRapidApiKey() ?? '';
  }
  
  String get _rapidApiHost =>
      dotenv.env['RAPIDAPI_HOST'] ?? 'instagram-looter2.p.rapidapi.com';
  String get _endpoint => dotenv.env['INSTAGRAM_POST_INFO_ENDPOINT'] ?? '/post';

  Future<List<String>> downloadInstagramPost(String instagramUrl) async {
    try {
      // Validate Instagram URL
      if (!instagramUrl.contains('instagram.com')) {
        throw Exception('Invalid Instagram URL');
      }

      debugPrint('Fetching post info from RapidAPI: $instagramUrl');

      // Step 1: Get media URLs from RapidAPI
      final mediaUrls = await _getMediaUrlsFromApi(instagramUrl);

      // Step 2: Download the files
      final List<String> downloadedPaths = [];
      for (final url in mediaUrls) {
        final path = await _downloadFile(url);
        downloadedPaths.add(path);
      }

      debugPrint('Downloaded ${downloadedPaths.length} files successfully.');
      return downloadedPaths;
    } catch (e) {
      debugPrint('Error downloading Instagram post: $e');
      rethrow;
    }
  }

  // Deprecated: kept for backward compatibility if needed, but redirects to new method
  Future<String> downloadInstagramVideo(String instagramUrl) async {
    final paths = await downloadInstagramPost(instagramUrl);
    if (paths.isNotEmpty) {
      return paths.first;
    }
    throw Exception('No media found');
  }

  /// Fetches media URLs from RapidAPI Instagram Downloader
  Future<List<String>> _getMediaUrlsFromApi(String instagramUrl) async {
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
      final response = await _client.get(
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
      
      // Log full response for debugging
      if (kDebugMode) {
        debugPrint('API Response: ${json.encode(data)}');
      }

      final Set<String> uniqueUrls = {};

      // 1. Check for single video (Reel) - Highest Priority
      if (data['video_url'] is String && (data['video_url'] as String).isNotEmpty) {
        uniqueUrls.add(data['video_url']);
      }

      // 2. Check for carousel - Secondary Priority
      if (uniqueUrls.isEmpty) {
        // 2a. Check 'edge_sidecar_to_children' (Raw GraphAPI - most reliable for carousels)
        // Check top level and inside 'shortcode_media' or 'graphql.shortcode_media'
        List? edges;
        if (data['edge_sidecar_to_children']?['edges'] is List) {
          edges = data['edge_sidecar_to_children']['edges'];
        } else if (data['shortcode_media']?['edge_sidecar_to_children']?['edges'] is List) {
          edges = data['shortcode_media']['edge_sidecar_to_children']['edges'];
        } else if (data['graphql']?['shortcode_media']?['edge_sidecar_to_children']?['edges'] is List) {
          edges = data['graphql']['shortcode_media']['edge_sidecar_to_children']['edges'];
        }

        if (edges != null) {
          for (var edge in edges) {
             final node = edge['node'];
             if (node != null) {
                if (node['is_video'] == true && node['video_url'] != null) {
                   uniqueUrls.add(node['video_url']);
                } else if (node['display_url'] != null) {
                   uniqueUrls.add(node['display_url']);
                } else if (node['display_resources'] is List && node['display_resources'].isNotEmpty) {
                   uniqueUrls.add(node['display_resources'].last['src']);
                }
             }
          }
        }

        // 2b. Check 'carousel_media' (RapidAPI normalized)
        if (uniqueUrls.isEmpty && data['carousel_media'] is List) {
           for (var item in data['carousel_media']) {
             if (item is Map && item['url'] is String) {
               uniqueUrls.add(item['url']);
             } else if (item is String) {
               uniqueUrls.add(item);
             }
          }
        }

        // 2c. Check 'medias' list (RapidAPI normalized)
        if (uniqueUrls.isEmpty && data['medias'] is List) {
          for (var item in data['medias']) {
             if (item is Map && item['url'] is String) {
               uniqueUrls.add(item['url']);
             } else if (item is String) {
               uniqueUrls.add(item);
             }
          }
        }
      }

      // 3. Check 'display_resources' for single post high-res IMAGE
      // Only if we haven't found anything yet (no carousel, no video)
      if (uniqueUrls.isEmpty && data['display_resources'] is List) {
         final resources = data['display_resources'] as List;
         if (resources.isNotEmpty) {
           // Get the last one (highest resolution)
           final lastItem = resources.last;
           if (lastItem is Map && lastItem['src'] is String) {
             uniqueUrls.add(lastItem['src']);
           }
         }
      }
      
      // 4. Fallback to single display_url if nothing found
      if (uniqueUrls.isEmpty) {
        if (data['display_url'] is String && (data['display_url'] as String).isNotEmpty) {
          uniqueUrls.add(data['display_url']);
        }
      }

      if (uniqueUrls.isEmpty) {
        // Fallback: Dump keys to help debug
        debugPrint('Available keys: ${data.keys.toList()}');
        throw Exception(
            'No media URLs found in API response. See logs for details.');
      }

      final mediaUrls = uniqueUrls.toList();
      debugPrint('Found ${mediaUrls.length} media URLs in total.');
      return mediaUrls;
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
      final response = await _client.get(
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
