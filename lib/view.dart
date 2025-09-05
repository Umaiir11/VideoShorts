// video_feed_view.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:video_player/video_player.dart';
import 'controller.dart';

class VideoFeedView extends StatelessWidget {
  VideoFeedView({super.key});
  final VideoFeedController controller = Get.put(VideoFeedController(), permanent: true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(() {
        return PageView.builder(
          scrollDirection: Axis.vertical,
          itemCount: controller.videos.length,
          onPageChanged: (index) => controller.updateCurrentIndex(index),
          itemBuilder: (context, index) {
            return Obx(() {
              final videoController = controller.controllers[index];
              if (videoController != null && videoController.value.isInitialized) {
                return GestureDetector(
                  onTap: controller.togglePlayPause,
                  child: Stack(
                    children: [
                      SizedBox.expand(
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: videoController.value.size.width,
                            height: videoController.value.size.height,
                            child: VideoPlayer(videoController),
                          ),
                        ),
                      ),
                      // Play/Pause button overlay (visible when paused)
                      Center(
                        child: AnimatedOpacity(
                          opacity: videoController.value.isPlaying ? 0.0 : 1.0,
                          duration: const Duration(milliseconds: 300),
                          child: IconButton(
                            iconSize: 100,
                            icon: const Icon(Icons.play_arrow, color: Colors.white),
                            onPressed: controller.togglePlayPause,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              } else {
                // Shimmer loading effect
                return Shimmer.fromColors(
                  baseColor: Colors.grey[800]!,
                  highlightColor: Colors.grey[700]!,
                  child: Container(color: Colors.black),
                );
              }
            });
          },
        );
      }),
    );
  }
}