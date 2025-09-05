// lib/app/mvvm/repository/video_repository.dart
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'model.dart';

class VideoRepository {
  final Dio _dio = Dio();

  // Persistent cache config
  final CacheManager cacheManager = CacheManager(
    Config(
      'persistentVideoCache',
      stalePeriod: const Duration(days: 365),
      maxNrOfCacheObjects: 200,
      repo: JsonCacheInfoRepository(databaseName: 'videoCache'),
      fileService: HttpFileService(),
    ),
  );

  final List<VideoModel> _videos = [
    VideoModel(
      id: '1',
      url:
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
    ),
    VideoModel(
      id: '2',
      url:
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
    ),
    VideoModel(
      id: '3',
      url:
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4',
    ),
    VideoModel(
      id: '4',
      url:
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4',
    ),
  ];

  List<VideoModel> getVideos() => _videos;

  /// Returns a cached file for [url]. If not cached, downloads in an isolate then stores it.
  Future<File> getCachedFile(String url) async {
    try {
      final cached = await cacheManager.getFileFromCache(url);
      if (cached != null && await cached.file.exists()) {
        debugPrint('[VideoRepository] cache hit for $url');
        return cached.file;
      } else {
        debugPrint('[VideoRepository] cache miss for $url => downloading in isolate');
        final bytes = await compute<_DownloadRequest, Uint8List>(
            _downloadBytesIsolate, _DownloadRequest(url, null));
        final file = await cacheManager.putFile(
          url,
          bytes,
          fileExtension: _extractExtension(url),
        );
        return file;
      }
    } catch (e) {
      debugPrint('[VideoRepository] getCachedFile ERROR: $e');
      // fallback try direct network download on main isolate
      final resp =
      await _dio.get<List<int>>(url, options: Options(responseType: ResponseType.bytes));
      final bytes = Uint8List.fromList(resp.data ?? []);
      final file = await cacheManager.putFile(
        url,
        bytes,
        fileExtension: _extractExtension(url),
      );
      return file;
    }
  }

  String _extractExtension(String url) {
    final idx = url.lastIndexOf('.');
    if (idx == -1) return 'mp4';
    return url.substring(idx + 1);
  }
}

class _DownloadRequest {
  final String url;
  final Map<String, String>? headers;
  _DownloadRequest(this.url, this.headers);
}

Future<Uint8List> _downloadBytesIsolate(_DownloadRequest req) async {
  final dio = Dio();
  final resp =
  await dio.get<List<int>>(req.url, options: Options(responseType: ResponseType.bytes));
  return Uint8List.fromList(resp.data ?? []);
}
