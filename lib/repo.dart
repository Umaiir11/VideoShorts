import 'dart:io';
import 'dart:isolate';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'model.dart';

class VideoRepository {
  final Dio _dio = Dio();

  // Persistent cache
  final CacheManager cacheManager = CacheManager(
    Config(
      'progressiveVideoCache',
      stalePeriod: const Duration(days: 365),
      maxNrOfCacheObjects: 200,
    ),
  );

  final Set<String> _cachedUrls = {};

  final List<VideoModel> _videos = [
    VideoModel(
      id: '1',
      url:
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
    ),
    VideoModel(
      id: '2',
      url:
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
    ),
    VideoModel(
      id: '3',
      url:
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4',
    ),
    VideoModel(
      id: '4',
      url:
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/WeAreGoingOnBullrun.mp4',
    ),
    VideoModel(
      id: '5',
      url: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8', // HLS
    ),VideoModel(
      id: '6',
      url: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4', // HLS
    ),VideoModel(
      id: '6',
      url: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4', // HLS
    ),
  ];

  VideoRepository();

  Future<void> initializeCacheMetadata() async {
    // Load cached URLs (this is a simplified example; use a proper cache index if needed)
    for (var video in _videos) {
      final cached = await cacheManager.getFileFromCache(video.url);
      if (cached != null && await cached.file.exists()) {
        _cachedUrls.add(video.url);
      }
    }
  }

  List<VideoModel> getVideos() => _videos;

  bool isStreamManifest(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.m3u8') || lower.contains('.mpd');
  }

  /// Returns cache file if exists, else null
  Future<File?> getCachedFile(String url) async {
    if (_cachedUrls.contains(url)) {
      final cached = await cacheManager.getFileFromCache(url);
      if (cached != null && await cached.file.exists()) {
        debugPrint('[VideoRepository] cache HIT → $url');
        return cached.file;
      } else {
        _cachedUrls.remove(url);
      }
    }
    return null;
  }

  /// Spawn isolate for progressive caching (non-blocking UI)
  Future<void> cacheInBackground(String url) async {
    if (isStreamManifest(url)) return;

    if (_cachedUrls.contains(url)) return;

    await compute(_downloadProgressive, {
      "url": url,
    });
    _cachedUrls.add(url); // Update cache metadata after download
  }

  /// Static function for isolate download
  static Future<void> _downloadProgressive(Map<String, dynamic> args) async {
    final url = args['url'] as String;
    final dio = Dio();

    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${Uri.parse(url).pathSegments.last}');
      final sink = file.openWrite(mode: FileMode.writeOnly);

      final resp = await dio.get<ResponseBody>(
        url,
        options: Options(responseType: ResponseType.stream),
      );

      await for (final chunk in resp.data!.stream) {
        sink.add(chunk);
      }
      await sink.close();

      final bytes = await file.readAsBytes();
      await DefaultCacheManager().putFile(
        url,
        bytes,
        fileExtension: _extractExtension(url),
      );
      debugPrint('[VideoRepository] cached in bg → $url');
    } catch (e) {
      debugPrint('[VideoRepository] isolate download failed → $e');
    }
  }

  static String _extractExtension(String url) {
    final idx = url.lastIndexOf('.');
    if (idx == -1) return 'mp4';
    return url.substring(idx + 1).split('?').first;
  }
}