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

  /// Create VideoPlayerController intelligently:
  /// - If URL is HLS/DASH manifest (.m3u8 or .mpd), use network controller and stream.
  /// - Otherwise, download via repository (isolate) and play from cached file.
  Future<VideoPlayerController> _createControllerFromUrl(String url) async {
    // If manifest -> use network streaming (ExoPlayer/AVPlayer will handle HLS/DASH)
    if (_repository.isStreamManifest(url)) {
      debugPrint('[VideoFeedController] creating network controller for manifest: $url');
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      controller.setLooping(true);
      controller.pause();
      return controller;
    }

    // Progressive file -> cache first (downloads in isolate)
    final file = await _repository.getCachedFileIfProgressive(url);
    if (file != null && await file.exists()) {
      debugPrint('[VideoFeedController] creating file controller from cache: ${file.path}');
      final controller = VideoPlayerController.file(File(file.path));
      await controller.initialize();
      controller.setLooping(true);
      controller.pause();
      return controller;
    }

    // Fallback: network controller (if cache failed)
    debugPrint('[VideoFeedController] cache unavailable, falling back to network for $url');
    final fallback = VideoPlayerController.networkUrl(Uri.parse(url));
    await fallback.initialize();
    fallback.setLooping(true);
    fallback.pause();
    return fallback;
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

  /// Called when PageView page changes
  void onPageChanged(int index) async {
    final prevIndex = currentIndex.value;
    currentIndex.value = index;

    debugPrint('[VideoFeedController] page changed $prevIndex -> $index');

    // 1. Pause all controllers except current
    _controllers.forEach((key, ctrl) {
      if (key != index) {
        try {
          ctrl.pause();
        } catch (_) {}
      }
    });

    // 2. Ensure current video plays
    final currentCtrl = _controllers[index];
    if (currentCtrl != null && currentCtrl.value.isInitialized) {
      Future.delayed(const Duration(milliseconds: 80), () {
        try {
          currentCtrl.play();
        } catch (_) {}
      });
    } else {
      // If not ready, preload now
      await _preloadSingle(index, play: true);
    }

    // 3. Preload next video silently (paused)
    if (index + 1 < videos.length) {
      _preloadSingle(index + 1, play: false);
    }

    // 4. Keep only prev video for resume, dispose others
    _disposeFarControllers(index);
  }

  /// Preload a single video by index
  Future<void> _preloadSingle(int index, {bool play = false}) async {
    if (_controllers.containsKey(index)) return;

    try {
      final ctrl = await _createControllerFromUrl(videos[index].url);
      if (!isClosed) {
        _controllers[index] = ctrl;

        if (play) {
          ctrl.play();
        } else {
          ctrl.pause();
        }

        update();
      } else {
        ctrl.dispose();
      }
    } catch (e) {
      debugPrint('[VideoFeedController] preload failed for $index -> $e');
    }
  }

  /// Dispose everything except [index], [index - 1], [index + 1]
  void _disposeFarControllers(int currentIdx) {
    final keep = {currentIdx, currentIdx - 1, currentIdx + 1};

    final keys = List<int>.from(_controllers.keys);
    for (final key in keys) {
      if (!keep.contains(key)) {
        final c = _controllers.remove(key);
        try {
          c?.dispose();
          debugPrint('[VideoFeedController] disposed controller for $key');
        } catch (e) {
          debugPrint('[VideoFeedController] error disposing $key -> $e');
        }
      }
    }
    update();
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
