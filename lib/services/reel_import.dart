import 'dart:io';
import 'dart:typed_data';

import '../data/database_helper.dart';
import '../providers/place_provider.dart';
import '../providers/recipe_provider.dart';
import 'background_processing_service.dart';
import 'gemini_service.dart';
import 'media_service.dart';
import 'video_service.dart';

/// Downloads a post, lets Gemini choose recipe or place, and saves it.
///
/// [asPlace] forces the type. [replaceExisting] swaps an item already saved
/// from the same post, keeping [folderId] on the new one.
Future<void> importReel({
  required String url,
  required RecipeProvider recipes,
  required PlaceProvider places,
  bool? asPlace,
  bool replaceExisting = false,
  int? folderId,
}) async {
  final bg = BackgroundProcessingService();
  await bg.startService();
  try {
    final reelId = MediaService.extractPostId(url);
    if (reelId == null) {
      throw Exception(MediaService.invalidUrlMessage);
    }

    final recipeExists = await DatabaseHelper.instance.recipeExistsByReelId(reelId);
    final placeExists = await DatabaseHelper.instance.placeExistsByReelId(reelId);
    if (!replaceExisting && (recipeExists || placeExists)) {
      throw Exception('This post has already been added.');
    }

    bg.updateNotification(
      title: 'Saving post',
      content: 'Checking connection...',
      showProgress: true,
      progress: 10,
    );
    final media = MediaService();
    if (!await media.isNetworkAvailable()) {
      throw Exception('No internet connection');
    }

    bg.updateNotification(
      title: 'Saving post',
      content: 'Downloading media...',
      showProgress: true,
      progress: 30,
    );
    final mediaPaths = await media.downloadPost(url);
    if (mediaPaths.isEmpty) {
      throw Exception('No media found in post');
    }

    final mainMediaPath = mediaPaths.first;
    final isVideo = mainMediaPath.toLowerCase().endsWith('.mp4');

    bg.updateNotification(
      title: 'Saving post',
      content: 'Generating thumbnail...',
      showProgress: true,
      progress: 50,
    );
    final videoService = VideoService();
    String? thumbnailPath;
    Uint8List? thumbnailData;
    if (isVideo) {
      thumbnailPath = await videoService.generateThumbnail(mainMediaPath);
      if (thumbnailPath != null) {
        thumbnailData = await videoService.getThumbnailData(thumbnailPath);
      }
    } else {
      thumbnailPath = mainMediaPath;
      final file = File(thumbnailPath);
      if (await file.exists()) {
        thumbnailData = await file.readAsBytes();
      }
    }

    var saveAsPlace = asPlace;
    if (saveAsPlace == null) {
      bg.updateNotification(
        title: 'Saving post',
        content: 'Deciding what this is...',
        showProgress: true,
        progress: 60,
      );
      saveAsPlace = await GeminiService().isPlaceContent(mediaPaths);
    }

    if (saveAsPlace) {
      if (replaceExisting && placeExists) {
        final existingPlace = await DatabaseHelper.instance.getPlaceByReelId(reelId);
        if (existingPlace?.id != null) {
          await places.deletePlace(existingPlace!.id!);
        }
      }
      await places.savePrepared(
        url: url,
        reelId: reelId,
        mediaPaths: mediaPaths,
        mainMediaPath: mainMediaPath,
        isVideo: isVideo,
        thumbnailPath: thumbnailPath,
        thumbnailData: thumbnailData,
        folderId: folderId,
      );
      if (replaceExisting && recipeExists) {
        final existing = await DatabaseHelper.instance.getRecipeByReelId(reelId);
        if (existing?.id != null) {
          await recipes.deleteRecipe(existing!.id!);
        }
      }
    } else {
      if (replaceExisting && recipeExists) {
        final existingRecipe = await DatabaseHelper.instance.getRecipeByReelId(reelId);
        if (existingRecipe?.id != null) {
          await recipes.deleteRecipe(existingRecipe!.id!);
        }
      }
      await recipes.savePrepared(
        url: url,
        reelId: reelId,
        mediaPaths: mediaPaths,
        mainMediaPath: mainMediaPath,
        isVideo: isVideo,
        thumbnailPath: thumbnailPath,
        thumbnailData: thumbnailData,
        folderId: folderId,
      );
      if (replaceExisting && placeExists) {
        final existing = await DatabaseHelper.instance.getPlaceByReelId(reelId);
        if (existing?.id != null) {
          await places.deletePlace(existing!.id!);
        }
      }
    }

    bg.updateNotification(
      title: saveAsPlace ? 'Place added' : 'Recipe added',
      content: 'Saved.',
      showProgress: false,
    );
    await Future.delayed(const Duration(seconds: 2));
  } catch (e) {
    final message = e.toString().replaceFirst('Exception: ', '');
    bg.updateNotification(
      title: 'Could not save',
      content: message,
      showProgress: false,
    );
    await Future.delayed(const Duration(seconds: 4));
  } finally {
    await bg.stopService();
  }
}
