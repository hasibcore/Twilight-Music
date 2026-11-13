// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../utils/logger.dart';
import '../../domain/entities/song.dart';
import 'download_service.dart';
import 'audio_stream_extractor.dart';
import 'artwork_service.dart';

/// Custom StreamAudioSource that proxies YouTube audio chunks directly
/// through YoutubeExplode or Dart HTTP client to just_audio's local proxy.
/// This completely eliminates HTTP 403 Forbidden errors from YouTube botguard.
class YouTubeAudioSource extends StreamAudioSource {
  final AudioOnlyStreamInfo? _streamInfo;
  String? _streamUrl;
  Map<String, String>? _headers;
  final int _totalBytes;
  final bool _hasExactTotalBytes;
  final String _mimeType;
  final File? _cacheFile;
  final MediaItem _mediaItem;
  DateTime _urlResolvedAt = DateTime.now();
  DateTime _lastActiveAt = DateTime.now();

  // In-memory cache for saved-downloads list to avoid JSON parsing on every play
  static List<DownloadItem>? _downloadsCacheSnapshot;
  static DateTime _downloadsCacheTime = DateTime.fromMillisecondsSinceEpoch(0);

  YouTubeAudioSource.fromStreamInfo({
    required YoutubeExplode yt,
    required AudioOnlyStreamInfo streamInfo,
    File? cacheFile,
    required MediaItem mediaItem,
  })  : _streamInfo = streamInfo,
        _streamUrl = streamInfo.url.toString(),
        _headers = const {
          'User-Agent': 'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip',
          'Accept': '*/*',
        },
        _hasExactTotalBytes = streamInfo.size.totalBytes > 0,
        _totalBytes = streamInfo.size.totalBytes > 0
            ? streamInfo.size.totalBytes
            : ((mediaItem.duration != null && mediaItem.duration!.inSeconds > 0)
                ? (mediaItem.duration!.inSeconds * 32000)
                : 15000000),
        _mimeType = streamInfo.container.name,
        _cacheFile = cacheFile,
        _mediaItem = mediaItem,
        super(tag: mediaItem);

  YouTubeAudioSource.fromUrl({
    required String streamUrl,
    Map<String, String>? headers,
    required int totalBytes,
    required String mimeType,
    File? cacheFile,
    required MediaItem mediaItem,
  })  : _streamInfo = null,
        _streamUrl = streamUrl,
        _headers = headers,
        _hasExactTotalBytes = totalBytes > 0,
        _totalBytes = totalBytes > 0
            ? totalBytes
            : ((mediaItem.duration != null && mediaItem.duration!.inSeconds > 0)
                ? (mediaItem.duration!.inSeconds * 32000)
                : 15000000),
        _mimeType = mimeType,
        _cacheFile = cacheFile,
        _mediaItem = mediaItem,
        super(tag: mediaItem);

  // Backwards compatible default constructor
  YouTubeAudioSource({
    required YoutubeExplode yt,
    required AudioOnlyStreamInfo streamInfo,
    File? cacheFile,
    required MediaItem mediaItem,
  }) : this.fromStreamInfo(
          yt: yt,
          streamInfo: streamInfo,
          cacheFile: cacheFile,
          mediaItem: mediaItem,
        );

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final s = start ?? 0;
    final int? sourceLength = _hasExactTotalBytes ? _totalBytes : null;
    final int? contentLength = (end != null)
        ? ((end - s) > 0 ? (end - s) : 1)
        : (_hasExactTotalBytes && (_totalBytes - s) > 0 ? (_totalBytes - s) : null);

    final lowerMime = _mimeType.toLowerCase();
    final String resolvedContentType = (lowerMime.contains('mpeg') || lowerMime.contains('mp3'))
        ? 'audio/mpeg'
        : (lowerMime.contains('mp4') || lowerMime.contains('m4a'))
            ? 'audio/mp4'
            : lowerMime.contains('aac')
                ? 'audio/aac'
                : 'audio/webm';

    return StreamAudioResponse(
      rangeRequestsSupported: true,
      sourceLength: sourceLength,
      contentLength: contentLength,
      offset: s,
      stream: _createResilientStream(s, end ?? (_hasExactTotalBytes ? _totalBytes : null)),
      contentType: resolvedContentType,
    );
  }

  static Duration _computeStreamBackoff(int attempt, {String? retryAfterHeader}) {
    final retrySeconds = int.tryParse((retryAfterHeader ?? '').trim());
    if (retrySeconds != null && retrySeconds > 0) {
      return Duration(milliseconds: math.min(3000, retrySeconds * 1000));
    }
    final expMs = math.min(2800, 240 * (1 << math.min(attempt, 4)));
    final jitterMs = DateTime.now().microsecondsSinceEpoch % 140;
    return Duration(milliseconds: expMs + jitterMs);
  }

  Stream<List<int>> _createResilientStream(int start, int? end) async* {
    int currentPos = start;
    final targetEnd = end;
    int retryAttempts = 0;
    const maxRetries = 10;

    // Proactive URL refresh if this audio source sat paused/idle for >= 3 minutes
    // or if the underlying stream URL is >= 5 minutes old before making any range request.
    final now = DateTime.now();
    final idleDuration = now.difference(_lastActiveAt);
    final urlAge = now.difference(_urlResolvedAt);
    if (idleDuration >= const Duration(minutes: 3) || urlAge >= const Duration(minutes: 5)) {
      final cleanId = _mediaItem.id.trim();
      if (cleanId.isNotEmpty) {
        AppLogger.info('Proactive stream URL refresh in YouTubeAudioSource (idle: ${idleDuration.inSeconds}s, urlAge: ${urlAge.inSeconds}s)');
        final fresh = await AudioStreamExtractor.extractAudioStream(
          cleanId,
          forceRefresh: true,
          title: _mediaItem.title,
          artist: _mediaItem.artist,
        );
        if (fresh != null) {
          _streamUrl = fresh.url;
          _headers = fresh.headers;
          _urlResolvedAt = DateTime.now();
          _lastActiveAt = DateTime.now();
        }
      }
    }

    // Open progressive cache sink if streaming from byte 0
    IOSink? cacheSink;
    File? partFile;
    if (start == 0 && _cacheFile != null) {
      try {
        if (!_cacheFile!.parent.existsSync()) {
          _cacheFile!.parent.createSync(recursive: true);
        }
        partFile = File('${_cacheFile!.path}.part');
        cacheSink = partFile.openWrite(mode: FileMode.write);
      } catch (e) {
        AppLogger.warning('Could not open cache sink: $e');
      }
    }

    final songId = _mediaItem.id.trim();
    bool completedCleanly = false;
    try {
      while ((targetEnd == null || currentPos < targetEnd) && retryAttempts < maxRetries) {
        http.Client? client;
        try {
          client = http.Client();
          final url = _streamUrl ?? (_streamInfo?.url.toString() ?? '');
          if (url.isEmpty) {
            throw Exception('Empty stream URL');
          }

          final request = http.Request('GET', Uri.parse(url));
          if (_headers != null && _headers!.isNotEmpty) {
            request.headers.addAll(_headers!);
          } else {
            request.headers['User-Agent'] =
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';
            request.headers['Accept'] = '*/*';
          }

          final rangeEnd = (targetEnd != null && targetEnd > 0)
              ? (targetEnd - 1).toString()
              : '';
          request.headers['Range'] = 'bytes=$currentPos-$rangeEnd';

          final response = await client.send(request).timeout(const Duration(seconds: 12));

          if (response.statusCode == 200 || response.statusCode == 206) {
            if (retryAttempts > 0) {
              AppLogger.streamEvent(
                StreamLogSeverity.info,
                'recovery',
                'youtubeAudioSource',
                'Byte-range stream reconnected cleanly',
                songId: songId,
                statusCode: response.statusCode,
                attempt: retryAttempts,
                bytePosition: currentPos,
              );
            }
            retryAttempts = 0; // reset retry counter on successful connection
            _lastActiveAt = DateTime.now();
            // Guard against servers returning 200 OK (full body from byte 0) when Range >= currentPos was requested
            int bytesToSkip = (response.statusCode == 200 && currentPos > 0) ? currentPos : 0;
            int bytesReadThisChunk = 0;
            await for (final chunk in response.stream.timeout(const Duration(seconds: 25))) {
              if (chunk.isNotEmpty) {
                _lastActiveAt = DateTime.now();
                List<int> slice = chunk;
                if (bytesToSkip > 0) {
                  if (slice.length <= bytesToSkip) {
                    bytesToSkip -= slice.length;
                    continue;
                  }
                  slice = slice.sublist(bytesToSkip);
                  bytesToSkip = 0;
                }
                currentPos += slice.length;
                bytesReadThisChunk += slice.length;
                if (cacheSink != null) {
                  cacheSink.add(slice);
                }
                yield slice;
              }
            }

            final expectedChunkLen = response.contentLength;
            final reachedTarget = targetEnd != null && currentPos >= targetEnd;
            final reachedOpenEndedEof = targetEnd == null &&
                bytesReadThisChunk == 0 &&
                currentPos > start &&
                (expectedChunkLen == null || expectedChunkLen <= 0);

            if (reachedTarget || reachedOpenEndedEof) {
              completedCleanly = true;
              break;
            }

            if (bytesReadThisChunk == 0) {
              retryAttempts++;
              AppLogger.networkDisconnect(
                'youtubeAudioSource',
                'Premature 0-byte chunk from upstream',
                category: 'premature_eof_disconnect',
                songId: songId,
                attempt: retryAttempts,
                bytePosition: currentPos,
              );
              await Future.delayed(_computeStreamBackoff(retryAttempts));
            } else {
              // Connection closed cleanly after delivering partial data; reconnect from currentPos
              AppLogger.info('Stream socket finished at byte $currentPos of $targetEnd, auto-reconnecting...');
            }
          } else if (response.statusCode == 401 || response.statusCode == 403 || response.statusCode == 410) {
            // Stream URL expired or forbidden. Invalidate cache and refresh immediately!
            AppLogger.networkDisconnect(
              'youtubeAudioSource',
              'Stream URL rejected or expired (${response.statusCode}), refreshing URL',
              category: 'url_expired_disconnect',
              songId: songId,
              statusCode: response.statusCode,
              attempt: retryAttempts + 1,
              bytePosition: currentPos,
            );
            final cleanId = _mediaItem.id.trim();
            if (cleanId.isNotEmpty) {
              AudioStreamExtractor.invalidateCache(cleanId);
              final fresh = await AudioStreamExtractor.extractAudioStream(
                cleanId,
                forceRefresh: true,
                preferCdnFallback: true,
                title: _mediaItem.title,
                artist: _mediaItem.artist,
              );
              if (fresh != null) {
                _streamUrl = fresh.url;
                _headers = fresh.headers;
                _urlResolvedAt = DateTime.now();
                _lastActiveAt = DateTime.now();
                retryAttempts++;
                continue;
              }
            }
            retryAttempts++;
            await Future.delayed(_computeStreamBackoff(retryAttempts));
          } else if (response.statusCode == 416) {
            // Reached end of stream (range not satisfiable = file completely delivered)
            AppLogger.info('Reached end of stream (HTTP 416) at byte $currentPos');
            completedCleanly = true;
            break;
          } else if (response.statusCode == 429 ||
              response.statusCode == 500 ||
              response.statusCode == 502 ||
              response.statusCode == 503 ||
              response.statusCode == 504 ||
              response.statusCode == 408) {
            AppLogger.networkDisconnect(
              'youtubeAudioSource',
              'Transient upstream HTTP ${response.statusCode} while streaming',
              category: 'upstream_retry',
              songId: songId,
              statusCode: response.statusCode,
              attempt: retryAttempts + 1,
              bytePosition: currentPos,
            );
            if (retryAttempts >= 2 || DateTime.now().difference(_urlResolvedAt) >= const Duration(seconds: 90)) {
              final cleanId = _mediaItem.id.trim();
              if (cleanId.isNotEmpty) {
                AudioStreamExtractor.invalidateCache(cleanId);
                final fresh = await AudioStreamExtractor.extractAudioStream(
                  cleanId,
                  forceRefresh: true,
                  preferCdnFallback: true,
                  title: _mediaItem.title,
                  artist: _mediaItem.artist,
                );
                if (fresh != null) {
                  _streamUrl = fresh.url;
                  _headers = fresh.headers;
                  _urlResolvedAt = DateTime.now();
                }
              }
            }
            retryAttempts++;
            await Future.delayed(
              _computeStreamBackoff(retryAttempts, retryAfterHeader: response.headers['retry-after']),
            );
          } else {
            AppLogger.networkDisconnect(
              'youtubeAudioSource',
              'Unexpected stream HTTP status ${response.statusCode}',
              songId: songId,
              statusCode: response.statusCode,
              attempt: retryAttempts + 1,
              bytePosition: currentPos,
            );
            retryAttempts++;
            await Future.delayed(_computeStreamBackoff(retryAttempts));
          }
        } catch (e) {
          AppLogger.networkDisconnect(
            'youtubeAudioSource',
            'Intermittent network disconnection during byte-range transfer',
            category: e is TimeoutException ? 'timeout_disconnect' : 'socket_disconnect',
            songId: songId,
            attempt: retryAttempts + 1,
            bytePosition: currentPos,
            error: e,
          );
          final cleanId = _mediaItem.id.trim();
          if (cleanId.isNotEmpty &&
              (retryAttempts >= 2 || DateTime.now().difference(_urlResolvedAt) >= const Duration(minutes: 2))) {
            AudioStreamExtractor.invalidateCache(cleanId);
            final fresh = await AudioStreamExtractor.extractAudioStream(
              cleanId,
              forceRefresh: true,
              title: _mediaItem.title,
              artist: _mediaItem.artist,
            );
            if (fresh != null) {
              _streamUrl = fresh.url;
              _headers = fresh.headers;
              _urlResolvedAt = DateTime.now();
            }
          }
          retryAttempts++;
          await Future.delayed(_computeStreamBackoff(retryAttempts));
        } finally {
          client?.close();
        }
      }
      if (!completedCleanly &&
          ((targetEnd != null && currentPos < targetEnd) || retryAttempts >= maxRetries)) {
        AppLogger.networkDisconnect(
          'youtubeAudioSource',
          'Stream connection exhausted after $retryAttempts retries',
          severity: StreamLogSeverity.error,
          category: 'retry_exhausted',
          songId: songId,
          attempt: retryAttempts,
          bytePosition: currentPos,
        );
        throw Exception('Stream connection failed at byte $currentPos after $retryAttempts retries');
      }
    } finally {
      if (cacheSink != null) {
        try {
          await cacheSink.flush();
          await cacheSink.close();
        } catch (_) {}

        // Promote to verified progressive cache if complete
        if (partFile != null && partFile.existsSync()) {
          final minExpected = _totalBytes > 0 ? (_totalBytes * 0.90).toInt() : 400000;
          if (partFile.lengthSync() >= minExpected && _cacheFile != null) {
            try {
              if (_cacheFile!.existsSync()) _cacheFile!.deleteSync();
              await partFile.rename(_cacheFile!.path);
              final doneFile = File('${_cacheFile!.path}.done');
              await doneFile.writeAsString('1');
              AppLogger.info('Progressive cache complete: ${_cacheFile!.path} (${_cacheFile!.lengthSync()} bytes)');
            } catch (e) {
              AppLogger.warning('Failed to promote cache file: $e');
            }
          } else {
            // Remove incomplete partial download so it does not waste disk space
            try {
              partFile.deleteSync();
            } catch (_) {}
          }
        }
      }
    }
  }

  /// Called by DownloadService when downloads are added/removed to force
  /// the next resolveAudioSource call to re-read from disk.
  static void invalidateDownloadsCache() {
    _downloadsCacheSnapshot = null;
  }

  /// Resolves an AudioSource for any song:
  /// 1. If downloaded permanently -> AudioSource.file (offline)
  /// 2. If cached in temp -> AudioSource.file (instant offline)
  /// 3. Otherwise -> YouTubeAudioSource (live streaming + background progressive caching)
  static Future<AudioSource> resolveAudioSource({
    required Song song,
    required YoutubeExplode yt,
    bool forceRefresh = false,
  }) async {
    final cleanId = song.id.trim();
    final fallbackSecs = song.durationSeconds > 0 ? song.durationSeconds : 210;

    final webMediaItem = MediaItem(
      id: cleanId.isNotEmpty ? cleanId : 'twilight_track',
      album: 'Twilight Music',
      title: song.title.trim().isNotEmpty ? song.title.trim() : 'Twilight Track',
      artist: song.artist.trim().isNotEmpty ? song.artist.trim() : 'Twilight Artist',
      artUri: Uri.tryParse(song.thumbnailUrl),
      duration: Duration(seconds: fallbackSecs),
    );

    if (kIsWeb) {
      final streamResult = await AudioStreamExtractor.extractAudioStream(
        cleanId,
        forceRefresh: forceRefresh,
        title: song.title,
        artist: song.artist,
        durationSeconds: song.durationSeconds,
      );
      if (streamResult != null) {
        if (streamResult.url.contains('.m3u8') ||
            streamResult.mimeType.toLowerCase().contains('mpegurl')) {
          AppLogger.info('Web playing "${song.title}" via HlsAudioSource');
          return HlsAudioSource(
            Uri.parse(streamResult.url),
            tag: webMediaItem,
          );
        }
        AppLogger.info('Web playing "${song.title}" via direct AudioSource.uri');
        return AudioSource.uri(
          Uri.parse(streamResult.url),
          tag: webMediaItem,
        );
      }

      try {
        final manifest = await yt.videos.streamsClient.getManifest(cleanId).timeout(const Duration(seconds: 8));
        final audioStreams = manifest.audioOnly.toList();
        if (audioStreams.isNotEmpty) {
          final bestStream = audioStreams.withHighestBitrate();
          AppLogger.info('Web playing "${song.title}" via YoutubeExplode AudioSource.uri');
          return AudioSource.uri(
            Uri.parse(bestStream.url.toString()),
            tag: webMediaItem,
          );
        }
      } catch (e) {
        AppLogger.info('Web direct manifest fallback failed: $e');
      }

      throw Exception('No playable web audio stream available for "${song.title}"');
    }

    // 1. Check permanent offline downloads (uses in-memory cache, refreshes every 30s)
    // Bypass local files when forceRefresh is requested so corrupt local files never trap retries.
    final now = DateTime.now();
    if (_downloadsCacheSnapshot == null ||
        now.difference(_downloadsCacheTime).inSeconds > 30) {
      _downloadsCacheSnapshot = DownloadService.loadSavedDownloads(onlyHealthy: true);
      _downloadsCacheTime = now;
    }

    Uri? artUri;

    // Build a lightweight fallback mediaItem with thumbnail URL (no local file needed yet)
    // The artwork service will cache the thumbnail in the background for future plays.
    MediaItem buildMediaItem(Uri? art) => MediaItem(
          id: cleanId.isNotEmpty ? cleanId : 'twilight_track',
          album: 'Twilight Music',
          title: song.title.trim().isNotEmpty ? song.title.trim() : 'Twilight Track',
          artist: song.artist.trim().isNotEmpty ? song.artist.trim() : 'Twilight Artist',
          artUri: art,
          duration: Duration(seconds: fallbackSecs),
        );

    if (!forceRefresh) {
      for (final d in _downloadsCacheSnapshot!) {
        if ((d.song.id == cleanId || d.song.id == song.id || d.resolvedVideoId == cleanId) &&
            d.isFileHealthy) {
          // For offline playback, we need the local artwork — fetch it (fast, local FS only)
          artUri = await ArtworkService.getArtworkUri(
            thumbnailUrl: song.thumbnailUrl,
            songId: cleanId,
          );
          AppLogger.info('Playing "${song.title}" from permanent offline downloads');
          final mediaItem = buildMediaItem(artUri);
          return AudioSource.file(
            d.localFilePath,
            tag: mediaItem.copyWith(
              album: 'Twilight Offline',
              artUri: (d.localThumbnailPath != null && d.localThumbnailPath!.isNotEmpty && File(d.localThumbnailPath!).existsSync())
                  ? Uri.file(d.localThumbnailPath!)
                  : mediaItem.artUri,
            ),
          );
        }
      }
    }

    // 2. Check local temporary progressive cache directory
    final tempDir = await getTemporaryDirectory();
    final cacheFileM4a = File('${tempDir.path}/twilight_v31_cache_$cleanId.m4a');
    final cacheFileWebm = File('${tempDir.path}/twilight_v31_cache_$cleanId.webm');
    final doneM4a = File('${tempDir.path}/twilight_v31_cache_$cleanId.m4a.done');
    final doneWebm = File('${tempDir.path}/twilight_v31_cache_$cleanId.webm.done');

    if (!forceRefresh && cacheFileM4a.existsSync() && doneM4a.existsSync() && cacheFileM4a.lengthSync() > 100000) {
      artUri = await ArtworkService.getArtworkUri(thumbnailUrl: song.thumbnailUrl, songId: cleanId);
      AppLogger.info('Playing "${song.title}" from verified local progressive cache (m4a)');
      return AudioSource.file(cacheFileM4a.path, tag: buildMediaItem(artUri));
    }
    if (!forceRefresh && cacheFileWebm.existsSync() && doneWebm.existsSync() && cacheFileWebm.lengthSync() > 100000) {
      artUri = await ArtworkService.getArtworkUri(thumbnailUrl: song.thumbnailUrl, songId: cleanId);
      AppLogger.info('Playing "${song.title}" from verified local progressive cache (webm)');
      return AudioSource.file(cacheFileWebm.path, tag: buildMediaItem(artUri));
    }
    // Clean up any unverified or corrupt cache file
    if (cacheFileM4a.existsSync() && (!doneM4a.existsSync() || forceRefresh)) {
      try { cacheFileM4a.deleteSync(); } catch (_) {}
      try { if (doneM4a.existsSync()) doneM4a.deleteSync(); } catch (_) {}
    }
    if (cacheFileWebm.existsSync() && (!doneWebm.existsSync() || forceRefresh)) {
      try { cacheFileWebm.deleteSync(); } catch (_) {}
      try { if (doneWebm.existsSync()) doneWebm.deleteSync(); } catch (_) {}
    }

    // 3. NETWORK PATH: Run stream resolution & artwork fetch IN PARALLEL
    // Stream resolution (300-500ms Tier1) and thumbnail HTTP download no longer block each other.
    final results = await Future.wait([
      AudioStreamExtractor.extractAudioStream(
        cleanId,
        forceRefresh: forceRefresh,
        title: song.title,
        artist: song.artist,
        durationSeconds: song.durationSeconds,
      ),
      ArtworkService.getArtworkUri(thumbnailUrl: song.thumbnailUrl, songId: cleanId),
    ]);

    final streamResult = results[0] as AudioStreamResult?;
    artUri = results[1] as Uri?;
    final mediaItem = buildMediaItem(artUri);

    if (streamResult != null) {
      if (streamResult.url.contains('.m3u8') ||
          streamResult.mimeType.toLowerCase().contains('mpegurl')) {
        AppLogger.info('Streaming "${song.title}" via HlsAudioSource (${streamResult.mimeType})');
        return HlsAudioSource(
          Uri.parse(streamResult.url),
          headers: streamResult.headers,
          tag: mediaItem,
        );
      }
      if (streamResult.isDirectDownloadable || !streamResult.url.contains('googlevideo.com')) {
        AppLogger.info('Streaming "${song.title}" via direct native AudioSource.uri (${streamResult.mimeType}, ${streamResult.bitrate}bps)');
        return AudioSource.uri(
          Uri.parse(streamResult.url),
          headers: streamResult.headers,
          tag: mediaItem,
        );
      }
      AppLogger.info('Streaming "${song.title}" via YouTubeAudioSource proxy (${streamResult.mimeType}, ${streamResult.bitrate}bps)');
      final isMp4 = streamResult.mimeType.toLowerCase().contains('mp4') ||
          streamResult.mimeType.toLowerCase().contains('m4a');
      final cacheFile = File('${tempDir.path}/twilight_v31_cache_$cleanId.${isMp4 ? "m4a" : "webm"}');
      return YouTubeAudioSource.fromUrl(
        streamUrl: streamResult.url,
        headers: streamResult.headers,
        totalBytes: streamResult.totalBytes,
        mimeType: streamResult.mimeType,
        cacheFile: cacheFile,
        mediaItem: mediaItem,
      );
    }

    // 4. Secondary Fallback: Direct YoutubeExplode streamsClient with fast 8s timeout
    try {
      final manifest = await yt.videos.streamsClient.getManifest(
        cleanId,
      ).timeout(const Duration(seconds: 8));

      final audioStreams = manifest.audioOnly.toList();
      if (audioStreams.isNotEmpty) {
        final mp4Streams = audioStreams.where((s) =>
            s.container.name.toLowerCase().contains('mp4') ||
            s.container.name.toLowerCase().contains('m4a')).toList();

        final bestStream = mp4Streams.isNotEmpty
            ? mp4Streams.withHighestBitrate()
            : audioStreams.withHighestBitrate();

        AppLogger.info('Streaming "${song.title}" via YouTubeAudioSource.fromStreamInfo (${bestStream.container.name}, ${bestStream.bitrate})');

        final isMp4 = bestStream.container.name.toLowerCase().contains('mp4') ||
            bestStream.container.name.toLowerCase().contains('m4a');
        final cacheFile = File('${tempDir.path}/twilight_v31_cache_$cleanId.${isMp4 ? "m4a" : "webm"}');

        return YouTubeAudioSource.fromStreamInfo(
          yt: yt,
          streamInfo: bestStream,
          cacheFile: cacheFile,
          mediaItem: mediaItem,
        );
      }
    } catch (e) {
      AppLogger.info('Direct getManifest fallback failed for $cleanId: $e');
    }

    throw Exception('No playable audio stream available for "${song.title}"');
  }
}
