// video_feed_controller.dart
import 'package:fuzzintest/repo.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'model.dart';

class VideoFeedController extends GetxController {
  final VideoRepository _repository = VideoRepository();

  var videos = <VideoModel>[].obs;
  var controllers = <int, VideoPlayerController>{}.obs; // video pool
  var currentIndex = 0.obs;
  final int prePoolSize = 2; // Preload previous N videos
  final int postPoolSize = 3; // Preload next N videos

  final BaseCacheManager cacheManager = CacheManager(
    Config(
      'persistentVideoCache',
      stalePeriod: const Duration(days: 365),
      maxNrOfCacheObjects: 100,
    ),
  );

  @override
  void onInit() {
    super.onInit();
    videos.assignAll(_repository.getVideos());
    preloadVideos(currentIndex.value);
    ever(currentIndex, (_) => _managePlayback());
  }

  Future<VideoPlayerController> _createController(String url) async {
    final file = await cacheManager.getSingleFile(url);
    final controller = VideoPlayerController.file(file);
    await controller.initialize();
    controller.setLooping(true);
    return controller;
  }

  /// Preload videos in a window around the current index (bidirectional)
  void preloadVideos(int index) {
    for (int i = index - prePoolSize; i <= index + postPoolSize; i++) {
      if (i >= 0 && i < videos.length && !controllers.containsKey(i)) {
        _createController(videos[i].url).then((controller) {
          controllers[i] = controller;
          // Dispose controllers outside the window
          _disposeFarControllers(index);
        });
      }
    }
  }

  void _disposeFarControllers(int currentIndex) {
    controllers.removeWhere((key, controller) {
      if (key < currentIndex - prePoolSize || key > currentIndex + postPoolSize) {
        controller.dispose();
        return true;
      }
      return false;
    });
  }

  void updateCurrentIndex(int index) {
    currentIndex.value = index;
    preloadVideos(index);
  }

  void _managePlayback() {
    controllers.forEach((key, controller) {
      if (key == currentIndex.value) {
        controller.play();
      } else {
        controller.pause();
      }
    });
  }

  void togglePlayPause() {
    final controller = controllers[currentIndex.value];
    if (controller != null) {
      if (controller.value.isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
    }
  }

  @override
  void onClose() {
    controllers.forEach((key, controller) => controller.dispose());
    super.onClose();
  }
}