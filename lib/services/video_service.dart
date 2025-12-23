import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path/path.dart' as path;

class VideoService {
  /// Generates a thumbnail from a video file
  Future<String?> generateThumbnail(String videoPath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final thumbnailDir = Directory('${appDir.path}/thumbnails');

    if (!await thumbnailDir.exists()) {
      await thumbnailDir.create(recursive: true);
    }

    final videoFileName = path.basenameWithoutExtension(videoPath);
    final thumbnailPath = '${thumbnailDir.path}/$videoFileName.jpg';

    // If the videoPath is already an image, just copy it or return it
    final ext = path.extension(videoPath).toLowerCase();
    if (['.jpg', '.jpeg', '.png', '.webp', '.heic'].contains(ext)) {
      try {
        final file = File(videoPath);
        await file.copy(thumbnailPath);
        return thumbnailPath;
      } catch (e) {
        debugPrint('Failed to copy image as thumbnail: $e');
        return videoPath; // Return original path as fallback
      }
    }

    // Prefer native plugin (mobile), fallback to ffmpeg for desktop/web
    try {
      if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
        final thumbnail = await VideoThumbnail.thumbnailFile(
          video: videoPath,
          thumbnailPath: thumbnailPath,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 800,
          quality: 85,
          timeMs: 1000,
        );
        if (thumbnail != null) {
          return thumbnail;
        }
      } else if (Platform.isWindows || Platform.isLinux) {
        try {
          // Use system ffmpeg on Windows/Linux
          final result = await Process.run('ffmpeg', [
            '-y',
            '-ss', '1',
            '-i', videoPath,
            '-frames:v', '1',
            '-q:v', '2',
            thumbnailPath,
          ]);

          if (result.exitCode == 0) {
            final file = File(thumbnailPath);
            if (await file.exists()) {
              return thumbnailPath;
            }
          } else {
            debugPrint('FFmpeg process failed: ${result.stderr}');
          }
        } catch (e) {
          debugPrint('System FFmpeg failed: $e');
        }
      }
    } catch (e) {
      // Ignore and fallback
      debugPrint('Primary thumbnail generation failed, falling back to ffmpeg: $e');
    }

    return null;
  }

  /// Gets the video file path from recipe's videoUrl (stored local path)
  /// Returns null if video file doesn't exist
  Future<String?> getVideoPath(String? storedPath) async {
    if (storedPath == null || storedPath.isEmpty) {
      return null;
    }

    final file = File(storedPath);
    if (await file.exists()) {
      return storedPath;
    }

    // Fallback: The stored path might be absolute from a previous installation/OS version
    // but now invalid. Try to find the filename in the current app directory.
    try {
      final fileName = path.basename(storedPath);
      
      // Check 1: Documents/reelary_downloads (Android/Standard)
      final docsDir = await getApplicationDocumentsDirectory();
      final recoveryPath1 = path.join(docsDir.path, 'reelary_downloads', fileName);
      if (await File(recoveryPath1).exists()) return recoveryPath1;

      // Check 2: Support/reelary_downloads (Windows)
      final supportDir = await getApplicationSupportDirectory();
      final recoveryPath2 = path.join(supportDir.path, 'reelary_downloads', fileName);
      if (await File(recoveryPath2).exists()) return recoveryPath2;

      // Check 3: Root Videos folder (Legacy)
      final recoveryPath3 = path.join(docsDir.path, 'videos', fileName);
      if (await File(recoveryPath3).exists()) return recoveryPath3;
      
    } catch (e) {
      debugPrint('Error recovering video path: $e');
    }

    return null;
  }

  /// Stores video path in app documents directory
  Future<String> getVideoStoragePath(String reelId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final videoDir = Directory('${appDir.path}/videos');

    if (!await videoDir.exists()) {
      await videoDir.create(recursive: true);
    }

    return '${videoDir.path}/$reelId.mp4';
  }
}
