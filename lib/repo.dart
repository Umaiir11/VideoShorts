import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'model.dart';

class VideoRepository {
  final Dio _dio = Dio();

  // Persistent cache config (1-year TTL, 200 objects)
  final CacheManager cacheManager = CacheManager(
    Config(
      'persistentVideoCache',
      stalePeriod: const Duration(days: 365),
      maxNrOfCacheObjects: 200,
      repo: JsonCacheInfoRepository(databaseName: 'videoCache'),
      fileService: HttpFileService(),
    ),
  );

  /// Demo video list (replace with API later)
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
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/WhatCarCanYouGetForAGrand.mp4',
    ),
    VideoModel(
      id: '4',
      url:
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/WeAreGoingOnBullrun.mp4',
    ),
    VideoModel(
      id: '5',
      url:
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
    ),
    VideoModel(
      id: '6',
      url:
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
    ),
    VideoModel(
      id: '7',
      url:
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
    ),
    VideoModel(
      id: '8',
      url:
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4',
    ),
    VideoModel(
      id: '9',
      url:
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4',
    ),
  ];

  List<VideoModel> getVideos() => _videos;

  /// Returns true if the URL is an HLS/DASH manifest (we treat as streaming)
  bool isStreamManifest(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.m3u8') || lower.contains('.mpd');
  }

  /// If URL is HLS/DASH, don't download — stream using network controller.
  /// For progressive files (mp4), returns cached File (downloads in isolate if needed).
  Future<File?> getCachedFileIfProgressive(String url,
      {Map<String, String>? headers}) async {
    // If it's a streaming manifest, return null — caller should use network stream.
    if (isStreamManifest(url)) {
      debugPrint('[VideoRepository] detected stream manifest (no file cache) for $url');
      return null;
    }

    try {
      // 1. Cache Hit
      final cached = await cacheManager.getFileFromCache(url);
      if (cached != null && await cached.file.exists()) {
        debugPrint('[VideoRepository] cache HIT for $url');
        return cached.file;
      }

      // 2. Cache Miss → download in isolate
      debugPrint('[VideoRepository] cache MISS for $url → downloading in isolate...');
      final bytes = await compute<_DownloadRequest, Uint8List>(
        _downloadBytesIsolate,
        _DownloadRequest(url, headers),
      );

      final file = await cacheManager.putFile(
        url,
        bytes,
        fileExtension: _extractExtension(url),
      );
      debugPrint('[VideoRepository] cached file saved for $url -> ${file.path}');
      return file;
    } catch (e) {
      debugPrint('[VideoRepository] getCachedFile ERROR: $e');

      // 3. Fallback → direct download on main isolate
      final resp = await _dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: headers,
        ),
      );
      final bytes = Uint8List.fromList(resp.data ?? []);
      final file = await cacheManager.putFile(
        url,
        bytes,
        fileExtension: _extractExtension(url),
      );
      return file;
    }
  }

  /// Extracts file extension safely
  String _extractExtension(String url) {
    final idx = url.lastIndexOf('.');
    if (idx == -1) return 'mp4';
    return url.substring(idx + 1).split('?').first; // remove query params
  }
}

/// Request model for isolate downloads
class _DownloadRequest {
  final String url;
  final Map<String, String>? headers;

  _DownloadRequest(this.url, this.headers);
}

/// Isolate worker for background video downloading
Future<Uint8List> _downloadBytesIsolate(_DownloadRequest req) async {
  final dio = Dio();
  final resp = await dio.get<List<int>>(
    req.url,
    options: Options(
      responseType: ResponseType.bytes,
      headers: req.headers,
    ),
  );
  return Uint8List.fromList(resp.data ?? []);
}
