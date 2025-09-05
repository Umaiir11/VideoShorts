// lib/app/mvvm/view/video_feed_view.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:shimmer/shimmer.dart';
import 'controller.dart';

class VideoFeedView extends StatelessWidget {
  VideoFeedView({super.key});
  final VideoFeedController controller = Get.put(VideoFeedController(), permanent: true);
  final PageController _pageController = PageController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Obx(() {
        final itemCount = controller.videos.length;
        return PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          itemCount: itemCount,
          onPageChanged: (index) => controller.onPageChanged(index),
          itemBuilder: (context, index) {
            return _VideoPage(index: index, controller: controller);
          },
        );
      }),
    );
  }
}

class _VideoPage extends StatefulWidget {
  final int index;
  final VideoFeedController controller;
  const _VideoPage({required this.index, required this.controller});

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> with SingleTickerProviderStateMixin {
  bool _showPlayIcon = false;
  late final AnimationController _iconAnim;

  @override
  void initState() {
    super.initState();
    _iconAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  }

  @override
  void dispose() {
    _iconAnim.dispose();
    super.dispose();
  }

  void _onTapPlayPause() {
    widget.controller.togglePlayPause(widget.index);
    setState(() {
      _showPlayIcon = true;
      _iconAnim.forward(from: 0.0);
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() => _showPlayIcon = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // We use GetBuilder here so the widget rebuilds when controller.update() is called
    return GetBuilder<VideoFeedController>(
      init: widget.controller,
      builder: (_) {
        final vController = widget.controller.getController(widget.index);
        final isReady = vController != null && vController.value.isInitialized;

        return Stack(
          fit: StackFit.expand,
          children: [
            // Video or Shimmer placeholder
            if (isReady && vController != null)
              _buildVideoPlayer(vController)
            else
              _buildShimmer(),

            // bottom-left text (metadata)
            Positioned(
              left: 16,
              bottom: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Video #${widget.index + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Description or author',
                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12),
                  ),
                ],
              ),
            ),

            // Center tappable overlay for play/pause
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _onTapPlayPause,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _showPlayIcon ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: ScaleTransition(
                      scale: Tween(begin: 0.8, end: 1.0).animate(
                        CurvedAnimation(parent: _iconAnim, curve: Curves.easeOutBack),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Icon(
                          (vController != null && vController.value.isPlaying) ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 42,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Right side action buttons
            Positioned(
              right: 8,
              bottom: 80,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SideButton(icon: Icons.favorite, label: '1.2k'),
                  const SizedBox(height: 18),
                  _SideButton(icon: Icons.chat_bubble, label: '152'),
                  const SizedBox(height: 18),
                  _SideButton(icon: Icons.share, label: 'Share'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVideoPlayer(VideoPlayerController controller) {
    final size = controller.value.size;
    if (size == null || size == Size.zero) {
      return _buildShimmer();
    }
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: VideoPlayer(controller),
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade900,
      highlightColor: Colors.grey.shade700,
      child: Container(color: Colors.grey.shade800),
    );
  }
}

class _SideButton extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SideButton({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          backgroundColor: Colors.black54,
          radius: 24,
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}
