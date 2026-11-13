import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../data/models/song_model.dart';
import '../../domain/entities/song.dart';
import '../utils/logger.dart';
import 'audio_stream_extractor.dart';
import 'local_storage_service.dart';
import 'youtube_audio_source.dart';

import 'music_import_service.dart';

class DownloadItem {
  final Song song;
  final String localFilePath;
  final String? localThumbnailPath;
  final int downloadedAtMillis;
  final int fileSize;
  final String resolvedVideoId;

  DownloadItem({
    required this.song,
    required this.localFilePath,
    this.localThumbnailPath,
    required this.downloadedAtMillis,
    required this.fileSize,
    String? resolvedVideoId,
  }) : resolvedVideoId = resolvedVideoId ?? song.id;

  /// Checks whether the downloaded local audio file exists on disk, is non-corrupted (>10KB),
  /// and is a genuine binary media container (not an #EXTM3U playlist, HTML page, or JSON error).
  bool get isFileHealthy {
    if (kIsWeb || localFilePath.isEmpty) return false;
    try {
      final file = File(localFilePath);
      if (!file.existsSync()) return false;
      final len = file.lengthSync();
      if (len <= 10000) return false;
      final raf = file.openSync(mode: FileMode.read);
      try {
        final headBytes = raf.readSync(len < 16 ? len : 16);
        final prefix = String.fromCharCodes(headBytes).trimLeft();
        if (prefix.startsWith('#EXTM3U') ||
            prefix.startsWith('<!DOC') ||
            prefix.startsWith('<html') ||
            prefix.startsWith('<HTML') ||
            prefix.startsWith('{')) {
          return false;
        }
      } finally {
        raf.closeSync();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> toJson() => {
        'song': SongModel.fromEntity(song).toJson(),
        'localFilePath': localFilePath,
        'localThumbnailPath': localThumbnailPath,
        'downloadedAtMillis': downloadedAtMillis,
        'fileSize': fileSize,
        'resolvedVideoId': resolvedVideoId,
      };

  factory DownloadItem.fromJson(Map<String, dynamic> json) {
    final parsedSong = SongModel.fromJson(
      json['song'] is Map ? Map<String, dynamic>.from(json['song'] as Map) : {},
    ).toEntity();
    final path = json['localFilePath'] as String? ?? '';
    String? inferredCleanId = json['resolvedVideoId'] as String?;
    if ((inferredCleanId == null || inferredCleanId.isEmpty) && path.isNotEmpty) {
      final base = path.split('/').last.split('\\').last;
      if (base.contains('.')) {
        inferredCleanId = base.split('.').first;
      }
    }
    return DownloadItem(
      song: parsedSong,
      localFilePath: path,
      localThumbnailPath: json['localThumbnailPath'] as String?,
      downloadedAtMillis: (json['downloadedAtMillis'] as num?)?.toInt() ?? 0,
      fileSize: (json['fileSize'] as num?)?.toInt() ?? 0,
      resolvedVideoId: inferredCleanId ?? parsedSong.id,
    );
  }
}

class DownloadService {
  static const String _storageKey = 'twilight_downloaded_tracks';
  static final Set<String> _cancelledDownloads = <String>{};

  static void cancelDownload(String songId) {
    _cancelledDownloads.add(songId);
    try {
      final cleanId = songId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
      _cancelledDownloads.add(cleanId);
    } catch (_) {}
  }

  static bool isDownloadCancelled(String songId) {
    return _cancelledDownloads.contains(songId);
  }

  static Future<Directory> getDownloadsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/twilight_downloads');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Loads all saved download metadata entries across app restarts (including any whose
  /// local file was externally deleted or corrupted so UI can offer 1-tap Re-download).
  static List<DownloadItem> loadSavedDownloads({bool onlyHealthy = false}) {
    if (kIsWeb) return [];
    try {
      final jsonList = LocalStorageService.getStringList(_storageKey);
      final items = <DownloadItem>[];
      for (final str in jsonList) {
        final map = jsonDecode(str) as Map<String, dynamic>;
        final item = DownloadItem.fromJson(map);
        if (!onlyHealthy || item.isFileHealthy) {
          items.add(item);
        }
      }
      return items;
    } catch (e) {
      AppLogger.error('Failed to load saved downloads', e);
      return [];
    }
  }

  /// Finds a verified, healthy local DownloadItem matching either the original song ID
  /// (e.g. `sp_...`) or the resolved 11-char video ID.
  static DownloadItem? findVerifiedDownload(String songId) {
    if (kIsWeb || songId.isEmpty) return null;
    final clean = songId.trim();
    final knownResolved = MusicImportService.resolveKnownVideoIdByIdOrTitle(clean);
    for (final item in loadSavedDownloads(onlyHealthy: true)) {
      if (item.song.id == clean ||
          item.resolvedVideoId == clean ||
          (knownResolved != null &&
              (item.song.id == knownResolved || item.resolvedVideoId == knownResolved)) ||
          item.localFilePath.endsWith('/$clean.m4a') ||
          item.localFilePath.endsWith('\\$clean.m4a')) {
        return item;
      }
    }
    return null;
  }

  static Future<void> _saveDownloads(List<DownloadItem> items) async {
    final list = items.map((i) => jsonEncode(i.toJson())).toList();
    await LocalStorageService.setStringList(_storageKey, list);
  }

  static final YoutubeExplode _yt = YoutubeExplode();

  static Future<DownloadItem?> downloadTrack({
    required Song song,
    required void Function(double progress) onProgress,
  }) async {
    String? tmpFilePath;
    try {
      final String originalSongId = song.id.trim();
      _cancelledDownloads.remove(originalSongId);

      Song targetSong = song;
      if (song.id.startsWith('sp_')) {
        final resolved = await MusicImportService().resolveStreamTrack(song);
        if (resolved != null) {
          targetSong = resolved;
        }
      }
      String cleanId = targetSong.id.trim();
      try {
        cleanId = VideoId(cleanId).value;
      } catch (_) {
        cleanId = cleanId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
      }

      if (_cancelledDownloads.contains(originalSongId)) {
        throw Exception('Download cancelled by user');
      }
      _cancelledDownloads.remove(cleanId);

      onProgress(0.08);

      final dir = await getDownloadsDirectory();
      final audioFilePath = '${dir.path}/$cleanId.m4a';
      final thumbFilePath = '${dir.path}/$cleanId.jpg';
      tmpFilePath = '${dir.path}/$cleanId.tmp';
      int finalFileSize = 0;

      // 1. Check if already cached in verified progressive cache
      final tempDir = await getTemporaryDirectory();
      final v31CacheM4a = File('${tempDir.path}/twilight_v31_cache_$cleanId.m4a');
      final v31CacheWebm = File('${tempDir.path}/twilight_v31_cache_$cleanId.webm');
      final v31DoneM4a = File('${tempDir.path}/twilight_v31_cache_$cleanId.m4a.done');
      final v31DoneWebm = File('${tempDir.path}/twilight_v31_cache_$cleanId.webm.done');
      final cacheM4a = File('${tempDir.path}/twilight_cache_$cleanId.m4a');
      final cacheWebm = File('${tempDir.path}/twilight_cache_$cleanId.webm');
      final doneM4a = File('${tempDir.path}/twilight_cache_$cleanId.m4a.done');
      final doneWebm = File('${tempDir.path}/twilight_cache_$cleanId.webm.done');

      bool isValidBinaryAudioFile(File f) {
        try {
          if (!f.existsSync() || f.lengthSync() <= 10000) return false;
          final raf = f.openSync(mode: FileMode.read);
          try {
            final headBytes = raf.readSync(16);
            final prefix = String.fromCharCodes(headBytes).trimLeft();
            if (prefix.startsWith('#EXTM3U') ||
                prefix.startsWith('<!DOC') ||
                prefix.startsWith('<html') ||
                prefix.startsWith('<HTML') ||
                prefix.startsWith('{')) {
              return false;
            }
          } finally {
            raf.closeSync();
          }
          return true;
        } catch (_) {
          return false;
        }
      }

      File? sourceCached;
      if (v31CacheM4a.existsSync() && v31DoneM4a.existsSync() && v31CacheM4a.lengthSync() > 100000 && isValidBinaryAudioFile(v31CacheM4a)) {
        sourceCached = v31CacheM4a;
      } else if (v31CacheWebm.existsSync() && v31DoneWebm.existsSync() && v31CacheWebm.lengthSync() > 100000 && isValidBinaryAudioFile(v31CacheWebm)) {
        sourceCached = v31CacheWebm;
      } else if (cacheM4a.existsSync() && doneM4a.existsSync() && cacheM4a.lengthSync() > 100000 && isValidBinaryAudioFile(cacheM4a)) {
        sourceCached = cacheM4a;
      } else if (cacheWebm.existsSync() && doneWebm.existsSync() && cacheWebm.lengthSync() > 100000 && isValidBinaryAudioFile(cacheWebm)) {
        sourceCached = cacheWebm;
      }

      if (sourceCached != null) {
        onProgress(0.50);
        await sourceCached.copy(audioFilePath);
        finalFileSize = sourceCached.lengthSync();
        onProgress(0.90);
      } else {
        // 2. Resolve audio stream URL with multi-tiered extractor priority
        onProgress(0.15);
        String? streamUrl;
        Map<String, String> streamHeaders = {};
        int streamTotalBytes = 0;

        // Try Tier A: AudioStreamExtractor (Fast direct 320kbps AAC CDN / iOS / TV clients)
        try {
          final streamResult = await AudioStreamExtractor.extractAudioStream(
            cleanId,
            preferDownload: true,
            title: targetSong.title,
            artist: targetSong.artist,
            durationSeconds: targetSong.durationSeconds,
          ).timeout(const Duration(seconds: 9));
          if (streamResult != null && streamResult.url.isNotEmpty) {
            streamUrl = streamResult.url;
            streamHeaders = streamResult.headers;
            streamTotalBytes = streamResult.totalBytes;
          }
        } catch (e) {
          AppLogger.info('AudioStreamExtractor download resolution error: $e');
        }

        // Try Tier B: YoutubeExplode TV / MWEB clients fallback
        if (streamUrl == null) {
          try {
            final manifest = await _yt.videos.streamsClient.getManifest(
              cleanId,
              ytClients: [YoutubeApiClient.tv, YoutubeApiClient.mweb, YoutubeApiClient.ios],
            ).timeout(const Duration(seconds: 9));
            final audios = manifest.audioOnly.toList();
            if (audios.isNotEmpty) {
              final mp4s = audios.where((s) =>
                  s.container.name.toLowerCase().contains('mp4') ||
                  s.container.name.toLowerCase().contains('m4a')).toList();
              final bestStream = mp4s.isNotEmpty
                  ? mp4s.withHighestBitrate()
                  : audios.withHighestBitrate();
              streamUrl = bestStream.url.toString();
              streamTotalBytes = bestStream.size.totalBytes;
              streamHeaders = {
                'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5_1 like Mac OS X) AppleWebKit/605.1.15',
              };
            }
          } catch (e) {
            AppLogger.info('YoutubeExplode manifest download error: $e');
          }
        }

        if (streamUrl == null || streamUrl.isEmpty) {
          throw Exception('Could not resolve playable audio stream for "${song.title}"');
        }

        if (_cancelledDownloads.contains(cleanId) || _cancelledDownloads.contains(originalSongId)) {
          throw Exception('Download cancelled by user');
        }

        // 3. Download using HLS segment assembly (for .m3u8 SoundCloud streams) or resilient chunked Range requests
        final bool isHlsStream = streamUrl.contains('.m3u8');
        final downloadedBytes = isHlsStream
            ? await _downloadHlsPlaylistToFile(
                url: streamUrl,
                headers: streamHeaders,
                tmpFilePath: tmpFilePath,
                songId: cleanId,
                originalSongId: originalSongId,
                onProgress: onProgress,
              )
            : await _downloadUrlWithResilientRanges(
                url: streamUrl,
                headers: streamHeaders,
                tmpFilePath: tmpFilePath,
                knownTotalBytes: streamTotalBytes,
                songId: cleanId,
                originalSongId: originalSongId,
                onProgress: onProgress,
              );

        if (_cancelledDownloads.contains(cleanId) || _cancelledDownloads.contains(originalSongId)) {
          throw Exception('Download cancelled by user');
        }

        final tmpFile = File(tmpFilePath);
        if (!isValidBinaryAudioFile(tmpFile)) {
          throw Exception('Downloaded file is incomplete or invalid container.');
        }

        final finalAudioFile = File(audioFilePath);
        if (await finalAudioFile.exists()) {
          try {
            await finalAudioFile.delete();
          } catch (_) {}
        }
        try {
          await tmpFile.rename(audioFilePath);
        } catch (_) {
          await tmpFile.copy(audioFilePath);
          try {
            await tmpFile.delete();
          } catch (_) {}
        }
        finalFileSize = downloadedBytes > 0 ? downloadedBytes : finalAudioFile.lengthSync();
      }

      onProgress(0.99);

      // 4. Fast non-blocking thumbnail fetch for offline artwork display (max 1.5s, never hangs completion)
      String? savedThumbPath;
      final thumbUrlToFetch = song.thumbnailUrl.isNotEmpty ? song.thumbnailUrl : targetSong.thumbnailUrl;
      if (thumbUrlToFetch.isNotEmpty) {
        try {
          final uri = Uri.tryParse(thumbUrlToFetch);
          if (uri != null) {
            final thumbRes = await http.get(uri).timeout(const Duration(milliseconds: 1500));
            if (thumbRes.statusCode == 200 && thumbRes.bodyBytes.length > 500) {
              final thumbFile = File(thumbFilePath);
              await thumbFile.writeAsBytes(thumbRes.bodyBytes);
              savedThumbPath = thumbFilePath;
            }
          }
        } catch (e) {
          AppLogger.info('Optional thumbnail cache skipped or timed out: $e');
        }
      }

      onProgress(1.0);

      final cleanSong = Song(
        id: song.id,
        title: song.title.isNotEmpty ? song.title : targetSong.title,
        artist: song.artist.isNotEmpty ? song.artist : targetSong.artist,
        channelId: song.channelId.isNotEmpty ? song.channelId : targetSong.channelId,
        thumbnailUrl: song.thumbnailUrl.startsWith('http')
            ? song.thumbnailUrl
            : (targetSong.thumbnailUrl.isNotEmpty ? targetSong.thumbnailUrl : (savedThumbPath ?? '')),
        durationSeconds: song.durationSeconds > 0 ? song.durationSeconds : targetSong.durationSeconds,
        durationFormatted: song.durationFormatted.isNotEmpty ? song.durationFormatted : targetSong.durationFormatted,
        viewCount: song.viewCount,
        publishedAt: song.publishedAt,
        isFavorite: song.isFavorite,
      );

      final item = DownloadItem(
        song: cleanSong,
        localFilePath: audioFilePath,
        localThumbnailPath: savedThumbPath,
        downloadedAtMillis: DateTime.now().millisecondsSinceEpoch,
        fileSize: finalFileSize > 0 ? finalFileSize : (File(audioFilePath).existsSync() ? File(audioFilePath).lengthSync() : 0),
        resolvedVideoId: cleanId,
      );

      // Persist in metadata
      final currentList = loadSavedDownloads();
      currentList.removeWhere((i) =>
          i.song.id == song.id ||
          i.song.id == cleanId ||
          i.resolvedVideoId == cleanId ||
          i.localFilePath.contains(cleanId));
      currentList.insert(0, item);
      await _saveDownloads(currentList);

      AppLogger.info('Successfully downloaded track: "${song.title}" (${(finalFileSize / (1024 * 1024)).toStringAsFixed(1)} MB)');

      // Invalidate in-memory downloads cache so next play sees this file
      YouTubeAudioSource.invalidateDownloadsCache();

      return item;
    } catch (e) {
      AppLogger.error('Download failed for ${song.title}: $e');
      try {
        if (tmpFilePath != null) {
          final tmpFile = File(tmpFilePath);
          if (tmpFile.existsSync()) {
            tmpFile.deleteSync();
          }
        }
      } catch (_) {}
      rethrow;
    }
  }

  /// Downloads stream with Range requests to avoid 20KB/s throttling & infinite stalls
  static Future<int> _downloadUrlWithResilientRanges({
    required String url,
    required Map<String, String> headers,
    required String tmpFilePath,
    required int knownTotalBytes,
    required String songId,
    String? originalSongId,
    required void Function(double progress) onProgress,
  }) async {
    bool isCancelled() =>
        _cancelledDownloads.contains(songId) ||
        (originalSongId != null && _cancelledDownloads.contains(originalSongId));

    final file = File(tmpFilePath);
    if (file.existsSync()) {
      try {
        file.deleteSync();
      } catch (_) {}
    }
    final sink = file.openWrite();
    int downloadedBytes = 0;
    int totalBytes = knownTotalBytes;

    final client = http.Client();
    try {
      // 1. If total bytes unknown, query HEAD with 4s timeout
      if (totalBytes <= 0) {
        try {
          final headRes = await client.head(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 4));
          if (headRes.contentLength != null && headRes.contentLength! > 0) {
            totalBytes = headRes.contentLength!;
          }
        } catch (_) {}
      }

      // 2. Segmented Range requests: 512 KB per chunk to bypass bandwidth throttles
      const int chunkSize = 512 * 1024;

      if (totalBytes > 0) {
        while (downloadedBytes < totalBytes) {
          if (isCancelled()) {
            throw Exception('Download cancelled by user');
          }

          final int start = downloadedBytes;
          final int end = (start + chunkSize - 1) < totalBytes ? (start + chunkSize - 1) : (totalBytes - 1);

          bool chunkSuccess = false;
          int retries = 0;

          while (!chunkSuccess && retries < 3) {
            if (isCancelled()) {
              throw Exception('Download cancelled by user');
            }
            try {
              final rangeHeaders = Map<String, String>.from(headers);
              rangeHeaders['Range'] = 'bytes=$start-$end';

              final req = http.Request('GET', Uri.parse(url));
              req.headers.addAll(rangeHeaders);

              final streamedRes = await client.send(req).timeout(const Duration(seconds: 8));
              if (streamedRes.statusCode == 200 || streamedRes.statusCode == 206) {
                // Update exact totalBytes from Content-Range header if provided (e.g. "bytes 0-524287/16813294")
                final contentRange = streamedRes.headers['content-range'];
                if (contentRange != null && contentRange.contains('/')) {
                  final exactTotal = int.tryParse(contentRange.split('/').last.trim());
                  if (exactTotal != null && exactTotal > 0) {
                    totalBytes = exactTotal;
                  }
                }

                int bytesInThisChunk = 0;
                await for (final chunk in streamedRes.stream.timeout(const Duration(seconds: 6))) {
                  if (isCancelled()) {
                    throw Exception('Download cancelled by user');
                  }
                  sink.add(chunk);
                  downloadedBytes += chunk.length;
                  bytesInThisChunk += chunk.length;
                  final progress = 0.08 + (0.90 * (downloadedBytes / totalBytes));
                  onProgress(progress.clamp(0.08, 0.98));
                }

                // If server returned 200 OK (entire file in one stream) or EOF reached
                if (streamedRes.statusCode == 200 || bytesInThisChunk == 0) {
                  chunkSuccess = true;
                  downloadedBytes = totalBytes;
                  break;
                }
                chunkSuccess = true;
              } else if (streamedRes.statusCode == 416) {
                // Range Not Satisfiable: Stream has finished sending all bytes
                chunkSuccess = true;
                downloadedBytes = totalBytes;
                break;
              } else {
                retries++;
                await Future.delayed(const Duration(milliseconds: 200));
              }
            } catch (e) {
              if (isCancelled()) rethrow;
              retries++;
              await Future.delayed(const Duration(milliseconds: 250));
              if (retries >= 3) {
                rethrow;
              }
            }
          }

          if (downloadedBytes >= totalBytes) break;
        }
      } else {
        // Fallback single stream with chunk timeout watchdog
        final req = http.Request('GET', Uri.parse(url));
        req.headers.addAll(headers);
        final streamedRes = await client.send(req).timeout(const Duration(seconds: 8));
        if (streamedRes.statusCode != 200 && streamedRes.statusCode != 206) {
          throw Exception('Stream HTTP status ${streamedRes.statusCode}');
        }
        final streamTotal = streamedRes.contentLength ?? 4000000;
        await for (final chunk in streamedRes.stream.timeout(const Duration(seconds: 6))) {
          if (isCancelled()) {
            throw Exception('Download cancelled by user');
          }
          sink.add(chunk);
          downloadedBytes += chunk.length;
          final progress = 0.08 + (0.90 * (downloadedBytes / streamTotal));
          onProgress(progress.clamp(0.08, 0.98));
        }
      }

      await sink.flush();
      await sink.close();
      onProgress(0.99);
      return downloadedBytes;
    } catch (e) {
      try {
        await sink.close();
      } catch (_) {}
      rethrow;
    } finally {
      client.close();
    }
  }

  /// Downloads an HLS .m3u8 audio playlist (such as SoundCloud AAC 160k/96k fMP4 or MP3 segments),
  /// assembles all segments in order, normalizes fMP4 container boxes, and writes a clean binary .m4a file.
  static Future<int> _downloadHlsPlaylistToFile({
    required String url,
    required Map<String, String> headers,
    required String tmpFilePath,
    required String songId,
    String? originalSongId,
    required void Function(double progress) onProgress,
  }) async {
    bool isCancelled() =>
        _cancelledDownloads.contains(songId) ||
        (originalSongId != null && _cancelledDownloads.contains(originalSongId));

    final client = http.Client();
    try {
      final playlistRes = await client
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 6));
      if (playlistRes.statusCode != 200) {
        throw Exception('HLS playlist HTTP ${playlistRes.statusCode}');
      }
      final m3u8Text = playlistRes.body;
      final baseUri = Uri.parse(url);
      String resolveSegUrl(String raw) {
        final trimmed = raw.trim();
        if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
          return trimmed;
        }
        return baseUri.resolve(trimmed).toString();
      }

      final segmentUrls = <String>[];
      final mapMatch = RegExp(r'#EXT-X-MAP:URI="([^"]+)"').firstMatch(m3u8Text);
      if (mapMatch != null && mapMatch.group(1) != null && mapMatch.group(1)!.isNotEmpty) {
        segmentUrls.add(resolveSegUrl(mapMatch.group(1)!));
      }

      for (final rawLine in m3u8Text.split('\n')) {
        final line = rawLine.trim();
        if (line.isEmpty || line.startsWith('#')) continue;
        segmentUrls.add(resolveSegUrl(line));
      }

      if (segmentUrls.isEmpty) {
        throw Exception('HLS playlist contained no audio segments');
      }

      final segmentBytes = List<Uint8List?>.filled(segmentUrls.length, null);
      int completedCount = 0;
      const int batchSize = 4;

      for (int batchStart = 0; batchStart < segmentUrls.length; batchStart += batchSize) {
        if (isCancelled()) {
          throw Exception('Download cancelled by user');
        }
        final int batchEnd = (batchStart + batchSize < segmentUrls.length)
            ? batchStart + batchSize
            : segmentUrls.length;

        await Future.wait(
          List.generate(batchEnd - batchStart, (offset) async {
            final idx = batchStart + offset;
            final segUrl = segmentUrls[idx];
            Uint8List? fetched;
            for (int attempt = 0; attempt < 3; attempt++) {
              if (isCancelled()) return;
              try {
                final res = await client
                    .get(Uri.parse(segUrl), headers: headers)
                    .timeout(const Duration(seconds: 6));
                if (res.statusCode == 200 || res.statusCode == 206) {
                  fetched = res.bodyBytes;
                  break;
                }
              } catch (_) {}
              await Future.delayed(Duration(milliseconds: 180 * (attempt + 1)));
            }
            if (fetched == null || fetched.isEmpty) {
              throw Exception('Failed to download HLS segment $idx');
            }
            segmentBytes[idx] = fetched;
            completedCount++;
            final progress = 0.08 + (0.88 * (completedCount / segmentUrls.length));
            onProgress(progress.clamp(0.08, 0.96));
          }),
        );
      }

      final builder = BytesBuilder(copy: false);
      for (final b in segmentBytes) {
        if (b != null) builder.add(b);
      }
      final rawAll = builder.takeBytes();
      final finalBytes = mapMatch != null ? _normalizeAssembledFmp4Bytes(rawAll) : rawAll;

      final file = File(tmpFilePath);
      if (file.existsSync()) {
        try {
          file.deleteSync();
        } catch (_) {}
      }
      await file.writeAsBytes(finalBytes, flush: true);
      onProgress(0.99);
      return finalBytes.length;
    } finally {
      client.close();
    }
  }

  /// Strips fragmented MP4 `styp` and `sidx` boxes and patches `moov` (`mvhd`, `mdhd`, `tkhd`)
  /// total duration so native players (ExoPlayer, AVPlayer, Windows Media Player) seek & play seamlessly.
  static Uint8List _normalizeAssembledFmp4Bytes(Uint8List input) {
    try {
      final bd = ByteData.sublistView(input);
      int off = 0;
      final boxes = <Map<String, dynamic>>[];
      int totalSubsegDur = 0;
      int sidxTimescale = 44100;

      while (off + 8 <= input.length) {
        final sz = bd.getUint32(off, Endian.big);
        final tp = String.fromCharCodes(input.sublist(off + 4, off + 8));
        if (sz < 8 || off + sz > input.length) break;
        final data = Uint8List.sublistView(input, off, off + sz);
        boxes.add({'tp': tp, 'sz': sz, 'data': data});
        if (tp == 'sidx' && sz >= 44) {
          final ver = data[8];
          final subBd = ByteData.sublistView(data);
          final ts = subBd.getUint32(16, Endian.big);
          if (ts > 0) sidxTimescale = ts;
          final subsegDur = subBd.getUint32(ver == 0 ? 36 : 44, Endian.big);
          totalSubsegDur += subsegDur;
        }
        off += sz;
      }

      if (boxes.isEmpty || totalSubsegDur <= 0) return input;
      final double durSec = sidxTimescale > 0 ? totalSubsegDur / sidxTimescale : 0;

      void patchMoovDurations(Uint8List slice) {
        final sliceBd = ByteData.sublistView(slice);
        int p = 0;
        while (p + 8 <= slice.length) {
          final bsz = sliceBd.getUint32(p, Endian.big);
          final btp = String.fromCharCodes(slice.sublist(p + 4, p + 8));
          if (bsz < 8 || p + bsz > slice.length) break;
          if (const {'moov', 'trak', 'mdia', 'minf', 'stbl', 'mvex'}.contains(btp)) {
            patchMoovDurations(Uint8List.sublistView(slice, p + 8, p + bsz));
          } else if (btp == 'mvhd' || btp == 'mdhd') {
            final ver = slice[p + 8];
            final ts = sliceBd.getUint32(p + (ver == 0 ? 20 : 28), Endian.big);
            if (ts > 0) {
              final targetDur = (durSec * ts).round();
              if (ver == 0) {
                sliceBd.setUint32(p + 24, targetDur, Endian.big);
              } else {
                sliceBd.setUint64(p + 32, targetDur, Endian.big);
              }
            }
          } else if (btp == 'tkhd') {
            final ver = slice[p + 8];
            final targetDur = (durSec * 1000).round();
            if (ver == 0) {
              sliceBd.setUint32(p + 28, targetDur, Endian.big);
            } else {
              sliceBd.setUint64(p + 36, targetDur, Endian.big);
            }
          }
          p += bsz;
        }
      }

      final out = BytesBuilder(copy: false);
      for (final b in boxes) {
        final tp = b['tp'] as String;
        final data = b['data'] as Uint8List;
        if (tp == 'styp' || tp == 'sidx') continue;
        if (tp == 'moov' && durSec > 0) {
          final moovCopy = Uint8List.fromList(data);
          patchMoovDurations(moovCopy);
          out.add(moovCopy);
        } else {
          out.add(data);
        }
      }
      return out.takeBytes();
    } catch (_) {
      return input;
    }
  }

  static Future<void> deleteTrack(String songId) async {
    try {
      final clean = songId.trim();
      final knownResolved = MusicImportService.resolveKnownVideoIdByIdOrTitle(clean);
      final currentList = loadSavedDownloads();
      final toDelete = currentList.where(
        (i) =>
            i.song.id == clean ||
            i.resolvedVideoId == clean ||
            (knownResolved != null &&
                (i.song.id == knownResolved || i.resolvedVideoId == knownResolved)) ||
            i.localFilePath.contains(clean),
      ).toList();

      for (final item in toDelete) {
        if (item.localFilePath.isNotEmpty) {
          final audioFile = File(item.localFilePath);
          if (audioFile.existsSync()) {
            try {
              audioFile.deleteSync();
            } catch (_) {}
          }
        }
        if (item.localThumbnailPath != null && item.localThumbnailPath!.isNotEmpty) {
          final thumbFile = File(item.localThumbnailPath!);
          if (thumbFile.existsSync()) {
            try {
              thumbFile.deleteSync();
            } catch (_) {}
          }
        }
      }

      currentList.removeWhere(
        (i) =>
            i.song.id == clean ||
            i.resolvedVideoId == clean ||
            (knownResolved != null &&
                (i.song.id == knownResolved || i.resolvedVideoId == knownResolved)) ||
            i.localFilePath.contains(clean),
      );
      await _saveDownloads(currentList);
      AppLogger.info('Deleted download for $songId');

      // Invalidate in-memory downloads cache
      YouTubeAudioSource.invalidateDownloadsCache();
    } catch (e) {
      AppLogger.error('Failed to delete download for $songId: $e');
    }
  }
}
