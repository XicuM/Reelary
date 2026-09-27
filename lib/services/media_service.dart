import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'settings_service.dart';

/// Downloads media from Instagram (via RapidAPI) and TikTok (via tikwm.com).
class MediaService {
  /// Matches a supported post URL. The post ID is in the first non-null group.
  /// Instagram: /p/, /reel/, /tv/, /stories/ (optionally prefixed by a username).
  /// TikTok: `/@user/video/{id}`, `/@user/photo/{id}`, and vm./vt./tiktok.com/t/ short links.
  static final RegExp urlPattern = RegExp(
    r'https?://(?:[a-z0-9-]+\.)?instagram\.com/(?:[\w.]+/(?:stories/)?)?(?:p|reels?|tv|stories)/([\w-]+)/?'
    r'|https?://(?:[a-z0-9-]+\.)?tiktok\.com/@[\w.-]+/(?:video|photo)/(\d+)/?'
    r'|https?://(?:(?:vm|vt)\.tiktok\.com|(?:www\.)?tiktok\.com/t)/([\w-]+)/?',
    caseSensitive: false,
  );

  /// Returns the post ID for a supported Instagram/TikTok URL, or null.
  static String? extractPostId(String url) {
    final match = urlPattern.firstMatch(url);
    if (match == null) return null;
    return match.group(1) ?? match.group(2) ?? match.group(3);
  }

  static const String invalidUrlMessage =
      'Invalid URL. Please provide an Instagram post/reel or a TikTok video URL.\n'
      'Example: https://www.instagram.com/reel/ABC123/ or https://www.tiktok.com/@user/video/123';

  final http.Client _client;

  MediaService({http.Client? client}) : _client = client ?? http.Client();

  Future<String> _getRapidApiKey() async {
    return await SettingsService.getEffectiveRapidApiKey() ?? '';
  }
  
  String get _rapidApiHost =>
      dotenv.env['RAPIDAPI_HOST'] ?? 'instagram-looter2.p.rapidapi.com';
  String get _endpoint => dotenv.env['INSTAGRAM_POST_INFO_ENDPOINT'] ?? '/post';

  /// Downloads all media of an Instagram or TikTok post and returns local paths.
  Future<List<String>> downloadPost(String postUrl) async {
    try {
      debugPrint('Fetching post info: $postUrl');

      // Step 1: Get media URLs
      final List<String> mediaUrls;
      if (postUrl.toLowerCase().contains('tiktok.com')) {
        mediaUrls = await _getTikTokMediaUrls(postUrl);
      } else if (postUrl.toLowerCase().contains('instagram.com')) {
        mediaUrls = await _getMediaUrlsFromApi(postUrl);
      } else {
        throw Exception(invalidUrlMessage);
      }

      // Step 2: Download the files
      final List<String> downloadedPaths = [];
      for (final url in mediaUrls) {
        final path = await _downloadFile(url);
        downloadedPaths.add(path);
      }

      debugPrint('Downloaded ${downloadedPaths.length} files successfully.');
      return downloadedPaths;
    } catch (e) {
      debugPrint('Error downloading post: $e');
      rethrow;
    }
  }

  /// Fetches media URLs from the free tikwm.com API (no key required).
  /// Returns the HD video for video posts, or all images for photo slideshows.
  Future<List<String>> _getTikTokMediaUrls(String tiktokUrl) async {
    final uri = Uri.parse('https://www.tikwm.com/api/')
        .replace(queryParameters: {'url': tiktokUrl, 'hd': '1'});
    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
          'TikTok API request failed: ${response.statusCode} - ${response.body}');
    }

    final body = json.decode(response.body) as Map<String, dynamic>;
    if (body['code'] != 0 || body['data'] is! Map) {
      throw Exception('TikTok API error: ${body['msg'] ?? response.body}');
    }
    final data = body['data'] as Map<String, dynamic>;

    if (data['images'] is List && (data['images'] as List).isNotEmpty) {
      return (data['images'] as List).whereType<String>().toList();
    }
    for (final key in ['hdplay', 'play']) {
      if (data[key] is String && (data[key] as String).isNotEmpty) {
        return [data[key] as String];
      }
    }
    throw Exception('No media URLs found in TikTok API response.');
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

      // Generate a unique filename with timestamp. CDN URLs (e.g. TikTok) often
      // lack a file extension, so fall back to the response content type.
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final isVideo = url.contains('.mp4') ||
          (response.headers['content-type'] ?? '').startsWith('video/');
      final extension = isVideo ? '.mp4' : '.jpg';
      final filename = 'video_$timestamp$extension';
      final filePath = '${downloadsDir.path}/$filename';

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
