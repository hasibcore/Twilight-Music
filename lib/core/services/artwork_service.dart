import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../utils/logger.dart';

/// Service responsible for providing local and remote artwork URIs
/// for background playback notifications and lockscreen controls.
/// Guarantees that notification artwork is NEVER a blank or white box.
class ArtworkService {
  static String? _appLogoFilePath;

  /// Ensures twilight_icon.png from assets is written to local filesystem
  /// so it can be passed as a local file URI to AudioService/MediaItem.
  static Future<String?> getAppLogoFilePath() async {
    if (kIsWeb) return null;
    if (_appLogoFilePath != null && File(_appLogoFilePath!).existsSync()) {
      return _appLogoFilePath!;
    }
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/twilight_notification_logo.png');
      if (!file.existsSync() || file.lengthSync() < 1000) {
        final byteData = await rootBundle.load('assets/images/twilight_icon.png');
        await file.writeAsBytes(
          byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
          flush: true,
        );
        AppLogger.info('Wrote default notification logo to: ${file.path}');
      }
      _appLogoFilePath = file.path;
      return _appLogoFilePath;
    } catch (e) {
      AppLogger.warning('Failed to initialize app logo artwork file: $e');
      return null;
    }
  }

  static final Map<String, String> _localArtworkPathBySongId = {};

  static const Map<String, String> imageHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
  };

  /// Returns true when [songId] is a genuine 11-character YouTube video ID
  /// (explicitly excluding prefixed catalog IDs such as `sp_...`, `js_...`, `custom_...`).
  static bool isYouTubeVideoId(String? songId) {
    final cleanId = songId?.trim() ?? '';
    return cleanId.length == 11 &&
        !cleanId.startsWith('sp_') &&
        !cleanId.startsWith('js_') &&
        !cleanId.startsWith('custom_') &&
        RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(cleanId);
  }

  /// Normalizes YouTube and remote thumbnail URLs so unreliable `maxresdefault.jpg`
  /// or `sddefault.jpg` URLs (which frequently HTTP 404 and cause Android MediaSession
  /// or player widgets to retain the previous song's image) are converted to guaranteed
  /// verified HQ thumbnails (`hqdefault.jpg`), upgrades cleartext `http://` media CDN
  /// URLs to `https://` for Android NetworkSecurityConfig compliance, and upgrades
  /// low-res JioSaavn artwork (`50x50`/`150x150`) to `500x500`.
  static String normalizeThumbnailUrl(String? thumbnailUrl, {String? songId}) {
    final cleanId = songId?.trim() ?? '';
    String raw = thumbnailUrl?.trim() ?? '';

    if (raw.startsWith('http://')) {
      raw = 'https://${raw.substring(7)}';
    }

    final bool isValidYtId = isYouTubeVideoId(cleanId);

    if (raw.isEmpty || raw.contains('picsum.photos')) {
      if (isValidYtId) {
        return 'https://i.ytimg.com/vi/$cleanId/hqdefault.jpg';
      }
      return '';
    }

    if (raw.contains('saavncdn.com')) {
      return raw.replaceAllMapped(
        RegExp(r'([_-])(?:50x50|150x150)(?=\.[a-zA-Z0-9]+(?:\?|$))'),
        (m) => '${m[1]}500x500',
      );
    }

    // If the URL is a YouTube thumbnail, normalize maxresdefault/sddefault to hqdefault
    // and ensure the video ID in the thumbnail URL matches songId when songId is a valid 11-char YT ID.
    if (raw.contains('ytimg.com/vi/') || raw.contains('img.youtube.com/vi/')) {
      if (isValidYtId) {
        return 'https://i.ytimg.com/vi/$cleanId/hqdefault.jpg';
      }
      return raw
          .replaceAll('/maxresdefault.jpg', '/hqdefault.jpg')
          .replaceAll('/sddefault.jpg', '/hqdefault.jpg')
          .replaceAll('img.youtube.com', 'i.ytimg.com');
    }

    return raw;
  }

  /// Returns a reliable fallback thumbnail URL when [failedUrl] fails to load
  /// (e.g., JioSaavn `-500x500` -> `-150x150`, or YouTube `mqdefault.jpg`).
  static String? fallbackThumbnailUrl(String? failedUrl, {String? songId}) {
    String raw = (failedUrl ?? '').trim();
    if (raw.startsWith('http://')) {
      raw = 'https://${raw.substring(7)}';
    }
    if (raw.isEmpty) return null;

    if (raw.contains('saavncdn.com')) {
      final downgraded = raw.replaceAllMapped(
        RegExp(r'([_-])500x500(?=\.[a-zA-Z0-9]+(?:\?|$))'),
        (m) => '${m[1]}150x150',
      );
      if (downgraded != raw) return downgraded;
    }

    if (isYouTubeVideoId(songId)) {
      final cleanId = songId!.trim();
      final mq = 'https://i.ytimg.com/vi/$cleanId/mqdefault.jpg';
      if (raw != mq) return mq;
    }

    return null;
  }

  /// Synchronously returns the verified local cached thumbnail file for a song if already synced.
  static File? getSyncedLocalArtworkFile(String? songId) {
    if (kIsWeb || songId == null || songId.trim().isEmpty) return null;
    final path = _localArtworkPathBySongId[songId.trim()];
    if (path != null) {
      final file = File(path);
      if (file.existsSync() && file.lengthSync() > 1500) {
        return file;
      }
    }
    return null;
  }

  /// Returns a valid Uri for MediaItem artUri:
  /// 1. If song thumbnail is cached locally -> Uri.file(localCachedFile)
  /// 2. Downloads & verifies the HQ thumbnail locally (bounded 2.2s timeout) -> Uri.file(localCachedFile)
  /// 3. If song thumbnail is a valid HTTP URL -> Uri.parse(normalizedUrl)
  /// 4. Otherwise -> Uri.file(appLogoFilePath)
  static Future<Uri?> getArtworkUri({
    required String? thumbnailUrl,
    String? songId,
  }) async {
    final normalizedUrl = normalizeThumbnailUrl(thumbnailUrl, songId: songId);

    if (kIsWeb) {
      if (normalizedUrl.startsWith('http')) {
        return Uri.tryParse(normalizedUrl);
      }
      return null;
    }

    final logoPath = await getAppLogoFilePath();
    final cleanLogoUri = (logoPath != null && File(logoPath).existsSync())
        ? Uri.file(logoPath)
        : null;

    if (normalizedUrl.isEmpty) {
      return cleanLogoUri;
    }

    if (!normalizedUrl.startsWith('http')) {
      try {
        final localFile = File(normalizedUrl.startsWith('file://')
            ? Uri.parse(normalizedUrl).toFilePath()
            : normalizedUrl);
        if (localFile.existsSync() && localFile.lengthSync() > 500) {
          if (songId != null && songId.trim().isNotEmpty) {
            _localArtworkPathBySongId[songId.trim()] = localFile.path;
          }
          return Uri.file(localFile.path);
        }
      } catch (_) {}
      return cleanLogoUri;
    }

    final cleanSongId = songId?.trim() ?? '';
    final isFlutterTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

    // Check if we have a locally cached thumbnail for this song, or download & verify it now
    if (cleanSongId.isNotEmpty) {
      try {
        final tempDir = await getTemporaryDirectory();
        final safeId = cleanSongId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
        final cachedThumb = File('${tempDir.path}/thumb_$safeId.jpg');
        if (cachedThumb.existsSync() && cachedThumb.lengthSync() > 1500) {
          _localArtworkPathBySongId[cleanSongId] = cachedThumb.path;
          return Uri.file(cachedThumb.path);
        }

        if (!isFlutterTest) {
          final syncedFile = await _downloadAndVerifyThumbnail(
            normalizedUrl,
            cachedThumb,
            songId: cleanSongId,
          );
          if (syncedFile != null) {
            _localArtworkPathBySongId[cleanSongId] = syncedFile.path;
            return Uri.file(syncedFile.path);
          }
        }
      } catch (_) {}
    }

    final parsed = Uri.tryParse(normalizedUrl);
    return parsed ?? cleanLogoUri;
  }

  static Future<File?> _downloadAndVerifyThumbnail(
    String primaryUrl,
    File targetFile, {
    String? songId,
  }) async {
    final candidateUrls = <String>[primaryUrl];
    final fallbackUrl = fallbackThumbnailUrl(primaryUrl, songId: songId);
    if (fallbackUrl != null && !candidateUrls.contains(fallbackUrl)) {
      candidateUrls.add(fallbackUrl);
    }
    if (songId != null && isYouTubeVideoId(songId)) {
      final ytHq = 'https://i.ytimg.com/vi/$songId/hqdefault.jpg';
      final ytMq = 'https://i.ytimg.com/vi/$songId/mqdefault.jpg';
      if (!candidateUrls.contains(ytHq)) candidateUrls.add(ytHq);
      if (!candidateUrls.contains(ytMq)) candidateUrls.add(ytMq);
    }

    for (final url in candidateUrls) {
      try {
        final res = await http
            .get(Uri.parse(url))
            .timeout(const Duration(milliseconds: 2200));
        if (res.statusCode == 200 && res.bodyBytes.length > 1500) {
          await targetFile.writeAsBytes(res.bodyBytes, flush: true);
          if (targetFile.existsSync() && targetFile.lengthSync() > 1500) {
            return targetFile;
          }
        }
      } catch (_) {}
    }
    return null;
  }
}

