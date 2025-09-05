// lib/app/mvvm/controller/video_feed_controller.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:fuzzintest/repo.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

import 'model.dart';

class VideoFeedController extends GetxController {
  final VideoRepository _repository = VideoRepository();

  final RxList<VideoModel> videos = <VideoModel>[].obs;
  // Use a regular Map for controllers and call update() on changes.
  final Map<int, VideoPlayerController> _controllers = {};
  Map<int, VideoPlayerController> get controllers => _controllers;

  // Tune for device: 2..5 (default 3)
  final int poolSize = 3;
  final RxInt currentIndex = 0.obs;

  @override
  void onInit() {
    super.onInit();
    videos.assignAll(_repository.getVideos());
    preloadWindow(0);
  }

  /// Create VideoPlayerController from cached file (downloads in isolate if needed)
  Future<VideoPlayerController> _createControllerFromUrl(String url) async {
    final file = await _repository.getCachedFile(url);
    final controller = VideoPlayerController.file(File(file.path));
    await controller.initialize();
    controller.setLooping(true);
    controller.pause(); // ✅ always start paused
    return controller;
  }

  /// Preload controllers for [index] .. [index + poolSize - 1]
  void preloadWindow(int index) {
    if (videos.isEmpty) return;

    currentIndex.value = index;
    final start = index;
    final end = (index + poolSize - 1).clamp(0, videos.length - 1);

    debugPrint('[VideoFeedController] preloadWindow start=$start end=$end');

    for (int i = start; i <= end; i++) {
      if (_controllers.containsKey(i)) continue;

      // create and initialize
      _createControllerFromUrl(videos[i].url).then((controller) {
        // If controller was disposed while loading, drop it
        if (!isClosed) {
          _controllers[i] = controller;
          debugPrint('[VideoFeedController] controller ready for index $i');

          // Auto-play only for the current index; otherwise pause to save CPU
          if (i == currentIndex.value) {
            // small delay to allow UI to settle & buffer
            Future.delayed(const Duration(milliseconds: 80), () {
              try {
                controller.play();
              } catch (_) {}
            });
          } else {
            try {
              controller.pause();
            } catch (_) {}
          }

          // force UI rebuild
          update();
          // cleanup far controllers
          _disposeFarControllers(currentIndex.value);
        } else {
          controller.dispose();
        }
      }).catchError((err) {
        debugPrint('[VideoFeedController] failed to create controller for $i -> $err');
      });
    }

    // Pause non-current playing controllers to save CPU
    _controllers.forEach((key, ctrl) {
      if (key != currentIndex.value && ctrl.value.isPlaying) {
        try {
          ctrl.pause();
        } catch (_) {}
      }
    });
  }

  void _disposeFarControllers(int currentIdx) {
    final keys = List<int>.from(_controllers.keys);
    for (final key in keys) {
      if (key < currentIdx || key >= currentIdx + poolSize) {
        final c = _controllers.remove(key);
        try {
          c?.dispose();
          debugPrint('[VideoFeedController] disposed controller for $key');
        } catch (e) {
          debugPrint('[VideoFeedController] error disposing $key -> $e');
        }
      }
    }
    // notify if controllers changed
    update();
  }

  /// Called when PageView page changes
  /// Called when PageView page changes
  void onPageChanged(int index) {
    final prevIndex = currentIndex.value;
    debugPrint('[VideoFeedController] page changed from $prevIndex to $index');

    currentIndex.value = index;

    // Pause ALL controllers except the new index
    _controllers.forEach((key, ctrl) {
      if (key != index) {
        try {
          ctrl.pause();
        } catch (_) {}
      }
    });

    // Preload nearby videos
    preloadWindow(index);

    // Play the current one (if ready)
    final now = _controllers[index];
    if (now != null && now.value.isInitialized) {
      Future.delayed(const Duration(milliseconds: 80), () {
        try {
          now.play();
        } catch (_) {}
      });
    }
  }

  void togglePlayPause(int index) {
    final c = _controllers[index];
    if (c == null) return;
    try {
      if (c.value.isPlaying) {
        c.pause();
      } else {
        c.play();
      }
    } catch (e) {
      debugPrint('[VideoFeedController] togglePlayPause err: $e');
    }
    update();
  }

  bool isReady(int index) {
    final c = _controllers[index];
    return c != null && c.value.isInitialized;
  }

  VideoPlayerController? getController(int index) => _controllers[index];

  @override
  void onClose() {
    _controllers.forEach((key, controller) {
      try {
        controller.dispose();
      } catch (_) {}
    });
    _controllers.clear();
    super.onClose();
  }
}
