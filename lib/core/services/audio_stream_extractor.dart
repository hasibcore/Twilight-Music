import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'artwork_service.dart';
import '../utils/logger.dart';

class AudioStreamResult {
  final String url;
  final int totalBytes;
  final String mimeType;
  final int bitrate;
  final Map<String, String> headers;
  final bool isDirectDownloadable;

  AudioStreamResult({
    required this.url,
    required this.totalBytes,
    required this.mimeType,
    required this.bitrate,
    required this.headers,
    this.isDirectDownloadable = false,
  });
}

class AudioStreamExtractor {
  static final YoutubeExplode _yt = YoutubeExplode();

  // Updated iOS App InnerTube Client
  static const Map<String, String> _iosAppHeaders = {
    'Content-Type': 'application/json',
    'User-Agent': 'com.google.ios.youtube/20.03.02 (iPhone16,2; U; CPU iOS 18_2_1 like Mac OS X; en_US)',
    'X-YouTube-Client-Name': '5',
    'X-YouTube-Client-Version': '20.03.02',
    'Accept': '*/*',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  // Mobile Web InnerTube Client
  static const Map<String, String> _mwebHeaders = {
    'Content-Type': 'application/json',
    'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1',
    'X-YouTube-Client-Name': '2',
    'X-YouTube-Client-Version': '2.20240920.01.00',
    'Accept': '*/*',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  // TV Embedded Player client
  static const String _tvApiKey = 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8';

  static const Map<String, String> _tvHeaders = {
    'Content-Type': 'application/json',
    'User-Agent': 'Mozilla/5.0 (SMART-TV; Linux; Tizen 6.0) AppleWebKit/538.1 (KHTML, like Gecko) Version/6.0 TV Safari/538.1',
    'Accept': '*/*',
    'Accept-Language': 'en-US,en;q=0.9',
    'Origin': 'https://www.youtube.com',
    'Referer': 'https://www.youtube.com/',
  };

  // Android Music client
  static const Map<String, String> _androidMusicHeaders = {
    'Content-Type': 'application/json',
    'User-Agent': 'com.google.android.apps.youtube.music/7.27.52 (Linux; U; Android 14) gzip',
    'X-YouTube-Client-Name': '21',
    'X-YouTube-Client-Version': '7.27.52',
    'Accept': '*/*',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  // Official Android YouTube App client
  static const Map<String, String> _androidAppHeaders = {
    'Content-Type': 'application/json',
    'User-Agent': 'com.google.android.youtube/20.10.38 (Linux; U; Android 14) gzip',
    'X-YouTube-Client-Name': '3',
    'X-YouTube-Client-Version': '20.10.38',
    'Accept': '*/*',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  static const List<String> _invidiousInstances = [
    'https://invidious.nerdvpn.de',
    'https://invidious.tiekoetter.com',
    'https://invidious.f5.si',
    'https://api.piped.video',
  ];

  static final RegExp _nonWordUnicodeRegex = RegExp(r'[^\p{L}\p{N}\s]', unicode: true);

  // In-memory cache with timestamps (stream URLs cached up to 5m30s)
  static final Map<String, AudioStreamResult> _cache = {};
  static final Map<String, DateTime> _cacheTime = {};
  static final Map<String, Map<String, String>> _metadataByVideoId = {};
  static const int _maxCacheSize = 100;
  static const Duration _cacheTTL = Duration(minutes: 5, seconds: 30);

  static const Set<int> _retryableStatuses = {408, 425, 429, 500, 502, 503, 504};
  static final Map<String, Future<AudioStreamResult?>> _inFlightExtractions = {};

  static String _cachedScClientId = '39AVoiZVrdvJEMFLH8T0c5WGshQaAPRJ';
  static DateTime _lastScClientIdRefresh = DateTime.fromMillisecondsSinceEpoch(0);

  static String _safeUriLabel(Uri uri) => '${uri.host}${uri.path}';

  static Duration _computeRetryDelay(int attempt, int baseDelayMs, http.Response? res) {
    final retryAfterRaw = res?.headers['retry-after'] ?? '';
    final retrySeconds = int.tryParse(retryAfterRaw.trim());
    if (retrySeconds != null && retrySeconds > 0) {
      return Duration(milliseconds: math.min(2500, retrySeconds * 1000));
    }
    final expMs = math.min(2000, baseDelayMs * (1 << math.min(attempt, 3)));
    final jitterMs = ((DateTime.now().microsecondsSinceEpoch % 110) + 15);
    return Duration(milliseconds: expMs + jitterMs);
  }

  static Future<http.Response?> _getWithRetry(
    Uri uri, {
    Map<String, String>? headers,
    Duration timeout = const Duration(milliseconds: 3000),
    int retries = 2,
    int baseDelayMs = 200,
  }) async {
    http.Response? lastResponse;
    final label = _safeUriLabel(uri);
    for (int attempt = 0; attempt <= retries; attempt++) {
      try {
        final res = await http.get(uri, headers: headers).timeout(timeout);
        lastResponse = res;
        if (!_retryableStatuses.contains(res.statusCode) || attempt == retries) {
          if (_retryableStatuses.contains(res.statusCode) && attempt == retries) {
            AppLogger.networkDisconnect(
              'extractor:GET',
              'Retryable HTTP status exhausted for $label',
              category: 'retry_exhausted',
              statusCode: res.statusCode,
              attempt: attempt + 1,
            );
          }
          return res;
        }
        AppLogger.networkDisconnect(
          'extractor:GET',
          'Retrying $label after HTTP ${res.statusCode}',
          category: 'upstream_retry',
          statusCode: res.statusCode,
          attempt: attempt + 1,
        );
        await Future.delayed(_computeRetryDelay(attempt, baseDelayMs, res));
      } on TimeoutException catch (e) {
        AppLogger.networkDisconnect(
          'extractor:GET',
          'GET timeout on $label',
          severity: attempt == retries ? StreamLogSeverity.error : StreamLogSeverity.warn,
          category: 'timeout_disconnect',
          attempt: attempt + 1,
          error: e,
        );
        if (attempt == retries) return lastResponse;
        await Future.delayed(_computeRetryDelay(attempt, baseDelayMs, null));
      } on SocketException catch (e) {
        AppLogger.networkDisconnect(
          'extractor:GET',
          'Socket disconnect on $label',
          severity: attempt == retries ? StreamLogSeverity.error : StreamLogSeverity.warn,
          category: 'socket_disconnect',
          attempt: attempt + 1,
          error: e,
        );
        if (attempt == retries) return lastResponse;
        await Future.delayed(_computeRetryDelay(attempt, baseDelayMs, null));
      } on http.ClientException catch (e) {
        AppLogger.networkDisconnect(
          'extractor:GET',
          'HTTP client disconnect on $label',
          severity: attempt == retries ? StreamLogSeverity.error : StreamLogSeverity.warn,
          category: 'client_disconnect',
          attempt: attempt + 1,
          error: e,
        );
        if (attempt == retries) return lastResponse;
        await Future.delayed(_computeRetryDelay(attempt, baseDelayMs, null));
      } catch (e) {
        AppLogger.networkDisconnect(
          'extractor:GET',
          'Unexpected network error on $label',
          attempt: attempt + 1,
          error: e,
        );
        if (attempt == retries) return lastResponse;
        await Future.delayed(_computeRetryDelay(attempt, baseDelayMs, null));
      }
    }
    return lastResponse;
  }

  static Future<http.Response?> _postWithRetry(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration timeout = const Duration(milliseconds: 3000),
    int retries = 1,
    int baseDelayMs = 200,
  }) async {
    http.Response? lastResponse;
    final label = _safeUriLabel(uri);
    for (int attempt = 0; attempt <= retries; attempt++) {
      try {
        final res = await http.post(uri, headers: headers, body: body).timeout(timeout);
        lastResponse = res;
        if (!_retryableStatuses.contains(res.statusCode) || attempt == retries) {
          if (_retryableStatuses.contains(res.statusCode) && attempt == retries) {
            AppLogger.networkDisconnect(
              'extractor:POST',
              'Retryable HTTP status exhausted for $label',
              category: 'retry_exhausted',
              statusCode: res.statusCode,
              attempt: attempt + 1,
            );
          }
          return res;
        }
        AppLogger.networkDisconnect(
          'extractor:POST',
          'Retrying POST $label after HTTP ${res.statusCode}',
          category: 'upstream_retry',
          statusCode: res.statusCode,
          attempt: attempt + 1,
        );
        await Future.delayed(_computeRetryDelay(attempt, baseDelayMs, res));
      } on TimeoutException catch (e) {
        AppLogger.networkDisconnect(
          'extractor:POST',
          'POST timeout on $label',
          category: 'timeout_disconnect',
          attempt: attempt + 1,
          error: e,
        );
        if (attempt == retries) return lastResponse;
        await Future.delayed(_computeRetryDelay(attempt, baseDelayMs, null));
      } on SocketException catch (e) {
        AppLogger.networkDisconnect(
          'extractor:POST',
          'POST socket disconnect on $label',
          category: 'socket_disconnect',
          attempt: attempt + 1,
          error: e,
        );
        if (attempt == retries) return lastResponse;
        await Future.delayed(_computeRetryDelay(attempt, baseDelayMs, null));
      } on http.ClientException catch (e) {
        AppLogger.networkDisconnect(
          'extractor:POST',
          'POST HTTP client disconnect on $label',
          category: 'client_disconnect',
          attempt: attempt + 1,
          error: e,
        );
        if (attempt == retries) return lastResponse;
        await Future.delayed(_computeRetryDelay(attempt, baseDelayMs, null));
      } catch (e) {
        AppLogger.networkDisconnect(
          'extractor:POST',
          'Unexpected POST error on $label',
          attempt: attempt + 1,
          error: e,
        );
        if (attempt == retries) return lastResponse;
        await Future.delayed(_computeRetryDelay(attempt, baseDelayMs, null));
      }
    }
    return lastResponse;
  }

  static Future<http.Response?> _headWithRetry(
    Uri uri, {
    Map<String, String>? headers,
    Duration timeout = const Duration(milliseconds: 2200),
    int retries = 1,
    int baseDelayMs = 180,
  }) async {
    http.Response? lastResponse;
    final label = _safeUriLabel(uri);
    for (int attempt = 0; attempt <= retries; attempt++) {
      try {
        final res = await http.head(uri, headers: headers).timeout(timeout);
        lastResponse = res;
        if (!_retryableStatuses.contains(res.statusCode) || attempt == retries) {
          return res;
        }
        AppLogger.networkDisconnect(
          'extractor:HEAD',
          'Retrying HEAD $label after HTTP ${res.statusCode}',
          category: 'upstream_retry',
          statusCode: res.statusCode,
          attempt: attempt + 1,
        );
        await Future.delayed(_computeRetryDelay(attempt, baseDelayMs, res));
      } catch (e) {
        AppLogger.networkDisconnect(
          'extractor:HEAD',
          'HEAD probe disconnect on $label',
          category: 'socket_disconnect',
          attempt: attempt + 1,
          error: e,
        );
        if (attempt == retries) return lastResponse;
        await Future.delayed(_computeRetryDelay(attempt, baseDelayMs, null));
      }
    }
    return lastResponse;
  }

  static Future<String> _getSoundCloudClientId({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedScClientId.isNotEmpty &&
        DateTime.now().difference(_lastScClientIdRefresh) < const Duration(minutes: 30)) {
      return _cachedScClientId;
    }
    try {
      final homeRes = await _getWithRetry(
        Uri.parse('https://soundcloud.com'),
        headers: const {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
        timeout: const Duration(milliseconds: 2500),
        retries: 1,
      );
      if (homeRes != null && homeRes.statusCode == 200) {
        final scriptMatches = RegExp(r'src="(https://a-v2\.sndcdn\.com/assets/[^"]+\.js)"')
            .allMatches(homeRes.body)
            .map((m) => m.group(1) ?? '')
            .where((u) => u.isNotEmpty)
            .toList();
        for (final scriptUrl in scriptMatches.reversed.take(3)) {
          try {
            final jsRes = await _getWithRetry(
              Uri.parse(scriptUrl),
              timeout: const Duration(milliseconds: 2500),
              retries: 1,
            );
            if (jsRes != null && jsRes.statusCode == 200) {
              final idMatch = RegExp(r'client_id\s*:\s*"([a-zA-Z0-9]{32})"').firstMatch(jsRes.body);
              if (idMatch != null && idMatch.group(1) != null) {
                _cachedScClientId = idMatch.group(1)!;
                _lastScClientIdRefresh = DateTime.now();
                return _cachedScClientId;
              }
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
    _lastScClientIdRefresh = DateTime.now();
    return _cachedScClientId;
  }

  /// Races [futures] concurrently and resolves immediately as soon as ANY future returns non-null.
  /// Never discards an already-succeeded fast stream just because a slow tier timed out.
  static Future<T?> _firstNonNull<T>(List<Future<T?>> futures, Duration timeout) {
    if (futures.isEmpty) return Future.value(null);
    final completer = Completer<T?>();
    int remaining = futures.length;
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });

    for (final f in futures) {
      f.then((value) {
        if (value != null && !completer.isCompleted) {
          timer.cancel();
          completer.complete(value);
          return;
        }
        remaining--;
        if (remaining <= 0 && !completer.isCompleted) {
          timer.cancel();
          completer.complete(null);
        }
      }).catchError((_) {
        remaining--;
        if (remaining <= 0 && !completer.isCompleted) {
          timer.cancel();
          completer.complete(null);
        }
      });
    }
    return completer.future;
  }

  static void _setCache(String key, AudioStreamResult result) {
    if (_cache.length >= _maxCacheSize) {
      final oldest = _cacheTime.entries.reduce((a, b) => a.value.isBefore(b.value) ? a : b);
      _cache.remove(oldest.key);
      _cacheTime.remove(oldest.key);
    }
    _cache[key] = result;
    _cacheTime[key] = DateTime.now();
  }

  static void invalidateCache(String videoId) {
    final cleanId = videoId.trim();
    final keysToRemove = _cache.keys
        .where((k) => k == '${cleanId}_false' || k == '${cleanId}_true' || k.startsWith('v35_${cleanId}_'))
        .toList();
    for (final k in keysToRemove) {
      _cache.remove(k);
      _cacheTime.remove(k);
    }
  }

  /// Returns the age of the cached stream URL for [videoId], or null if not cached.
  static Duration? getCacheAge(String videoId, {bool preferDownload = false}) {
    final cleanId = videoId.trim();
    final ts = _cacheTime['v35_${cleanId}_${preferDownload}_false'] ??
        _cacheTime['v35_${cleanId}_${preferDownload}_true'] ??
        _cacheTime['${cleanId}_$preferDownload'];
    if (ts == null) return null;
    return DateTime.now().difference(ts);
  }

  static final RegExp _metadataSegmentRegex = RegExp(
    r'^(?:coke\s+studio(?:\s+bangla|\s+india|\s+pakistan|\s+global|\s+tamil|\s+bharat)?|season\s*\d+|episode\s*\d+|ep\s*\.?\s*\d+|s\d+\s*e\d+|official.*|lyric(?:al)?.*|full\s+(?:song|video|audio|album).*|audio\s+song.*|video\s+song.*|music\s+video.*|rabindra\s+sangeet.*|tagore\s+song.*|nazrul\s+geeti.*|bangla\s+(?:gaan|song|music|band|lofi).*|new\s+(?:bangla|bengali|hindi)\s+song.*|\d+(?:st|nd|rd|th)\s+anniversary(?:\s+concert.*)?|anniversary\s+concert.*|live\s+concert.*|concert.*|hd|4k|hq|remaster(?:ed)?|live(?:\s+performance|\s+session|\s+in\s+concert)?|unplugged|mtv\s+unplugged.*|t-series.*|sony\s+music.*|zee\s+music.*|svf.*|sangeet\s+bangla.*|soundtek.*|laser\s+vision.*|cd\s+choice.*|eagle\s+music.*|gaanchill.*|bhavna\s+records.*|g-series.*|agniveena.*|saregama.*|times\s+music.*|tips\s+official.*|yrf.*|speed\s+records.*)$',
    caseSensitive: false,
  );

  static const Set<String> _coreTitleStopWords = {
    'the', 'and', 'for', 'with', 'from', 'feat', 'ft', 'of', 'in', 'on', 'to', 'at', 'by', 'is', 'it', 'my', 'me',
    'official', 'music', 'video', 'audio', 'song', 'songs', 'full', 'lyric', 'lyrics', 'lyrical',
    'hd', '4k', 'hq', 'live', 'session', 'studio', 'coke', 'bangla', 'bengali', 'hindi', 'english',
    'season', 'episode', 'version', 'unplugged', 'rabindra', 'sangeet', 'tagore', 'records', 'creations',
    'anniversary', 'concert', 'performance', 'track', 'album', 'movie', 'film', 'ost', 'soundtrack',
    'title', 'theme', 'natok', 'drama', 'telefilm', 'new', 'hit', 'hits', 'single',
  };

  static String _decodeHtmlEntities(String input) {
    return input
        .replaceAll(RegExp(r'&quot;', caseSensitive: false), '"')
        .replaceAll(RegExp(r'&#0*39;|&apos;', caseSensitive: false), "'")
        .replaceAll(RegExp(r'&amp;', caseSensitive: false), '&')
        .replaceAll(RegExp(r'&lt;', caseSensitive: false), '<')
        .replaceAll(RegExp(r'&gt;', caseSensitive: false), '>');
  }

  static String _stripParentheticalAndEntities(String input) {
    return _decodeHtmlEntities(input)
        .replaceAll(RegExp(r'\([^)]*\)'), ' ')
        .replaceAll(RegExp(r'\[[^\]]*\]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _normalizePhoneticToken(String input) {
    return input
        .toLowerCase()
        .replaceAll('bh', 'v')
        .replaceAll('sh', 's')
        .replaceAll('ph', 'f')
        .replaceAll('kh', 'k')
        .replaceAll('gh', 'g')
        .replaceAll('chh', 'ch')
        .replaceAll('aa', 'a')
        .replaceAll('ee', 'i')
        .replaceAll('oo', 'u')
        .replaceAll('ou', 'o');
  }

  static bool _tokenMatchesText(String token, String text) {
    if (token.isEmpty || text.isEmpty) return false;
    final tLower = token.toLowerCase();
    final textLower = text.toLowerCase();
    if (textLower.contains(tLower)) return true;
    final pToken = _normalizePhoneticToken(tLower);
    final pText = _normalizePhoneticToken(textLower);
    return pToken.length >= 2 && pText.contains(pToken);
  }

  static List<String> _getCoreTitleTokens(String coreTitle) {
    final cleaned = _stripParentheticalAndEntities(coreTitle)
        .toLowerCase()
        .replaceAll(_nonWordUnicodeRegex, ' ');
    final allTokens = cleaned
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 2)
        .toList();
    if (allTokens.isEmpty) {
      return cleaned
          .split(RegExp(r'\s+'))
          .where((t) => t.isNotEmpty && !RegExp(r'^\d+$').hasMatch(t))
          .toList();
    }
    final filtered = allTokens.where((t) => !_coreTitleStopWords.contains(t)).toList();
    return filtered.isNotEmpty ? filtered : allTokens;
  }

  static bool _hasForeignSongTitleWords(
    String candTitle,
    List<String> coreTokens,
    List<String> artistTokens, [
    String extraAllowedText = '',
  ]) {
    if (coreTokens.isEmpty) return false;
    final extraTokens = _stripParentheticalAndEntities(extraAllowedText)
        .toLowerCase()
        .replaceAll(_nonWordUnicodeRegex, ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 2)
        .toList();
    final stripped = _stripParentheticalAndEntities(candTitle)
        .toLowerCase()
        .replaceAll(_nonWordUnicodeRegex, ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 2 && !_coreTitleStopWords.contains(w) && !RegExp(r'^\d+$').hasMatch(w))
        .toList();
    for (final w in stripped) {
      final matchesCore = coreTokens.any((ct) => _tokenMatchesText(ct, w) || _tokenMatchesText(w, ct));
      final matchesArtist = artistTokens.any((at) => _tokenMatchesText(at, w) || _tokenMatchesText(w, at));
      final matchesExtra = extraTokens.any((et) => _tokenMatchesText(et, w) || _tokenMatchesText(w, et));
      if (!matchesCore && !matchesArtist && !matchesExtra) {
        return true;
      }
    }
    return false;
  }

  /// Cleans YouTube video titles and channel names into a canonical song search query
  static String cleanTrackText(String input) {
    final decoded = _decodeHtmlEntities(input).replaceAll(RegExp(r'#\S+'), ' ');
    final hasLatinOutsideParens = RegExp(r'[a-zA-Z]').hasMatch(
      decoded.replaceAll(RegExp(r'\([^)]*\)'), ' ').replaceAll(RegExp(r'\[[^\]]*\]'), ' '),
    );
    final baseText = hasLatinOutsideParens
        ? decoded
            .replaceAll(RegExp(r'\(\s*[^\x00-\x7F]+\s*\)'), ' ')
            .replaceAll(RegExp(r'\[\s*[^\x00-\x7F]+\s*\]'), ' ')
        : decoded;
    return baseText
        .replaceAll(RegExp(r'\([^)]*(?:official|video|audio|lyric|lyrics|visualizer|hd|4k|hq|remaster|live|mv|full\s+song|coke\s+studio|season\s*\d+|anniversary|concert|from\s+|feat\.?\s+|ft\.?\s+|original\s+motion|soundtrack|ost|film|movie|natok|drama|telefilm)[^)]*\)', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\[[^\]]*(?:official|video|audio|lyric|lyrics|visualizer|hd|4k|hq|remaster|live|mv|full\s+song|coke\s+studio|season\s*\d+|anniversary|concert|from\s+|feat\.?\s+|ft\.?\s+|original\s+motion|soundtrack|ost|film|movie|natok|drama|telefilm)[^\]]*\]', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\b(?:official\s+music\s+video|official\s+video|official\s+audio|lyric(?:al)?\s+video|full\s+video|full\s+audio|full\s+song|4k\s+remaster|audio\s+song|video\s+song)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s*[-|•·]\s*(?:official|topic|vevo).*$', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\b(?:VEVO|Topic)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'[|•·"“”‘’]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Extracts the core song title and specific artist from pipe/hyphen-delimited YouTube titles
  static Map<String, String> extractCoreTitleAndArtist(String rawTitle, String? rawArtist) {
    final cleanedChannelArtist = cleanTrackText(rawArtist ?? '')
        .replaceAll(
          RegExp(
            r'\b(?:sony\s+music(?:\s+india|\s+south|\s+east)?|sony\s+india|zeee?\s+music(?:\s+company|\s+bangla)?|t-series(?:\s+bangla|\s+regional)?|saregama(?:\s+bengali|\s+music|\s+india)?|maddock\s+films|anupam\s+movie\s+songs|dhruba\s+music(?:\s+station)?|red\s+flag\s+gamer|eagle\s+music|cd\s+choice|coke\s+studio(?:\s+bangla|\s+india|\s+pakistan)?|svf(?:\s+music)?|sangeet\s+bangla|soundtek|laser\s+vision|gaanchill(?:\s+music)?|bhavna\s+records|yrf|tips\s+official|speed\s+records|times\s+music|agniveena|g-series|g\s+series|satv(?:\s+music)?)\b',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(RegExp(r'(?:theband|official|vevo|topic|music|records|channel|band)$', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\b(?:official|vevo|topic|music|records|channel|various\s+artists)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final isChannelGenericOrShow =
        cleanedChannelArtist.isEmpty || _metadataSegmentRegex.hasMatch(cleanedChannelArtist);
    final compactChannel = cleanedChannelArtist.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    final rawSegments = rawTitle
        .split(RegExp(r'(?:\s*\|\|\s*|\s*[|•·]\s*|\s+\/\/\s+)'))
        .map((s) => cleanTrackText(s))
        .where((s) => s.isNotEmpty)
        .toList();

    final meaningfulSegments = rawSegments.where((s) => !_metadataSegmentRegex.hasMatch(s)).toList();
    final candidateSegments =
        meaningfulSegments.isNotEmpty ? meaningfulSegments : [cleanTrackText(rawTitle)];

    final latinCandidates = candidateSegments.where((s) => RegExp(r'[a-zA-Z]').hasMatch(s)).toList();
    final nonArtistLatinCandidates = compactChannel.length >= 3 && latinCandidates.length > 1
        ? latinCandidates.where((s) {
            final c = s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
            return c != compactChannel;
          }).toList()
        : latinCandidates;

    final firstSegment = candidateSegments.isNotEmpty ? candidateSegments.first : '';
    final firstSegHasLatin = RegExp(r'[a-zA-Z]').hasMatch(firstSegment);
    final useNonLatinFirstSegment = firstSegment.isNotEmpty &&
        !firstSegHasLatin &&
        (nonArtistLatinCandidates.isEmpty || (latinCandidates.length == 1 && candidateSegments.length >= 2));

    final primarySeg = useNonLatinFirstSegment
        ? firstSegment
        : (nonArtistLatinCandidates.isNotEmpty
            ? nonArtistLatinCandidates.first
            : (latinCandidates.isNotEmpty
                ? latinCandidates.first
                : (candidateSegments.isNotEmpty ? candidateSegments.first : '')));

    String coreTitle = primarySeg;
    String extractedArtist = '';

    if (primarySeg.contains('-') || primarySeg.contains('–') || primarySeg.contains('—')) {
      final hyphenParts = primarySeg
          .split(RegExp(r'\s*[-–—]\s*'))
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();
      if (hyphenParts.length == 2) {
        final left = hyphenParts[0];
        final right = hyphenParts[1];
        final leftCompact = left.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        final rightCompact = right.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        if (compactChannel.isNotEmpty &&
            leftCompact.isNotEmpty &&
            (leftCompact == compactChannel ||
                compactChannel.contains(leftCompact) ||
                leftCompact.contains(compactChannel))) {
          coreTitle = right;
          extractedArtist = left;
        } else if (compactChannel.isNotEmpty &&
            rightCompact.isNotEmpty &&
            (rightCompact == compactChannel ||
                compactChannel.contains(rightCompact) ||
                rightCompact.contains(compactChannel))) {
          coreTitle = left;
          extractedArtist = right;
        } else if (RegExp(r'\s+[-–—]\s+').hasMatch(primarySeg)) {
          final trailingVersionDescRegex = RegExp(
            r'^(?:female(?:\s+version)?|male(?:\s+version)?|sad(?:\s+version)?|unplugged|acoustic|reprise|remix|lofi|lo-fi|slowed(?:\s*(?:&|\+|and|n)\s*reverb)?|reverb|extended|duet(?:\s+version)?|title\s+track|version|instrumental|from\s+.+)$',
            caseSensitive: false,
          );
          if (_metadataSegmentRegex.hasMatch(right) ||
              rawSegments.length >= 3 ||
              trailingVersionDescRegex.hasMatch(right)) {
            coreTitle = left;
          } else {
            coreTitle = right;
            extractedArtist = left;
          }
        }
      }
    }

    if (extractedArtist.isEmpty) {
      final otherLatinSegments = candidateSegments
          .where((s) => s != primarySeg && RegExp(r'[a-zA-Z]').hasMatch(s) && !_metadataSegmentRegex.hasMatch(s))
          .toList();
      if (otherLatinSegments.isNotEmpty) {
        final channelMatchedSeg = compactChannel.length >= 3
            ? otherLatinSegments.where((s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '') == compactChannel).toList()
            : <String>[];
        extractedArtist = channelMatchedSeg.isNotEmpty ? channelMatchedSeg.first : otherLatinSegments.last;
      }
    }

    final preferExtracted = extractedArtist.isNotEmpty &&
        (isChannelGenericOrShow ||
            (!cleanedChannelArtist.contains(' ') && extractedArtist.contains(' ')) ||
            compactChannel == extractedArtist.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), ''));

    final primaryArtist = preferExtracted
        ? (extractedArtist.isNotEmpty ? extractedArtist : cleanedChannelArtist)
        : (cleanedChannelArtist.isNotEmpty ? cleanedChannelArtist : extractedArtist);

    final finalCore = _stripParentheticalAndEntities(coreTitle.trim().isNotEmpty ? coreTitle.trim() : cleanTrackText(rawTitle));

    return {
      'title': finalCore.isNotEmpty ? finalCore : (coreTitle.trim().isNotEmpty ? coreTitle.trim() : cleanTrackText(rawTitle)),
      'artist': primaryArtist.trim(),
      'rawContext': '$rawTitle ${rawArtist ?? ''}',
    };
  }

  /// Resolves canonical track title and artist for [videoId] using provided metadata or YouTube oEmbed
  static Future<Map<String, String>> _resolveTrackMetadata(
    String videoId, {
    String? title,
    String? artist,
  }) async {
    final cleanId = videoId.trim();
    if (title != null && title.trim().isNotEmpty) {
      final extracted = extractCoreTitleAndArtist(title, artist);
      if (cleanId.isNotEmpty) {
        _metadataByVideoId[cleanId] = extracted;
      }
      return extracted;
    }

    if (_metadataByVideoId.containsKey(cleanId)) {
      return _metadataByVideoId[cleanId]!;
    }

    if (ArtworkService.isYouTubeVideoId(cleanId)) {
      try {
        final oembedUri = Uri.parse(
          'https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=$cleanId&format=json',
        );
        final res = await _getWithRetry(
          oembedUri,
          timeout: const Duration(milliseconds: 2200),
          retries: 0,
        );
        if (res != null && res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final oembedTitle = data['title']?.toString() ?? '';
          final oembedArtist = data['author_name']?.toString() ?? '';
          if (oembedTitle.isNotEmpty) {
            final meta = extractCoreTitleAndArtist(oembedTitle, oembedArtist);
            _metadataByVideoId[cleanId] = meta;
            return meta;
          }
        }
      } catch (_) {}
    }

    return {'title': '', 'artist': '', 'rawContext': ''};
  }

  /// Probes a candidate stream URL with a fast Range: bytes=0-511 request to verify
  /// it returns HTTP 200 or 206 (and not 403 Forbidden) before handing it to just_audio.
  /// Retries once on transient socket/timeout or 5xx/429 responses.
  static Future<AudioStreamResult?> _verifyStreamPlayable(
    AudioStreamResult? candidate, {
    Duration timeout = const Duration(milliseconds: 1200),
  }) async {
    if (candidate == null || candidate.url.isEmpty) return null;
    for (int attempt = 0; attempt < 2; attempt++) {
      http.Client? client;
      try {
        client = http.Client();
        final req = http.Request('GET', Uri.parse(candidate.url));
        if (candidate.headers.isNotEmpty) {
          req.headers.addAll(candidate.headers);
        } else {
          req.headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)';
        }
        req.headers['Range'] = 'bytes=0-511';

        final res = await client.send(req).timeout(timeout);
        if (res.statusCode == 200 || res.statusCode == 206) {
          final contentType = (res.headers['content-type'] ?? '').toLowerCase();
          if (contentType.contains('text/html') ||
              contentType.contains('application/json') ||
              contentType.contains('text/plain') ||
              contentType.contains('application/xml') ||
              contentType.contains('text/xml')) {
            AppLogger.networkDisconnect(
              'extractor:probe',
              'Stream probe rejected non-audio content-type "$contentType"',
              statusCode: res.statusCode,
              attempt: attempt + 1,
            );
            return null;
          }
          int resolvedTotal = candidate.totalBytes;
          final contentRange = res.headers['content-range'] ?? '';
          if (contentRange.contains('/')) {
            final slashTotal = int.tryParse(contentRange.split('/').last.trim()) ?? 0;
            if (slashTotal > 10000) {
              resolvedTotal = slashTotal;
            }
          }
          if (resolvedTotal <= 0) {
            final clen = int.tryParse(res.headers['content-length'] ?? '0') ?? 0;
            if (clen > 10000) {
              resolvedTotal = clen;
            }
          }
          return AudioStreamResult(
            url: candidate.url,
            totalBytes: resolvedTotal,
            mimeType: candidate.mimeType,
            bitrate: candidate.bitrate,
            headers: candidate.headers,
            isDirectDownloadable: candidate.isDirectDownloadable,
          );
        }
        AppLogger.networkDisconnect(
          'extractor:probe',
          'Stream probe rejected status ${res.statusCode}',
          statusCode: res.statusCode,
          attempt: attempt + 1,
        );
        if (!_retryableStatuses.contains(res.statusCode) || attempt == 1) {
          return null;
        }
      } catch (e) {
        AppLogger.networkDisconnect(
          'extractor:probe',
          'Stream probe disconnected',
          attempt: attempt + 1,
          error: e,
        );
        if (attempt == 1) return null;
      } finally {
        client?.close();
      }
      await Future.delayed(const Duration(milliseconds: 180));
    }
    return null;
  }

  /// Races all YouTube direct/Invidious extractors in parallel and returns the first
  /// stream verified playable (HTTP 200/206) within the timeout budget.
  static Future<AudioStreamResult?> _extractVerifiedYouTubeDirect(String cleanId) async {
    Future<AudioStreamResult?> probeTier(
      String name,
      Future<AudioStreamResult?> Function() extractor,
    ) async {
      try {
        final raw = await extractor();
        if (raw == null) return null;
        final verified = await _verifyStreamPlayable(raw);
        if (verified != null) {
          AppLogger.info('Verified playable YouTube stream via $name for $cleanId');
          return verified;
        }
      } catch (_) {}
      return null;
    }

    Future<AudioStreamResult?> extractYoutubeExplode() async {
      try {
        final manifest = await _yt.videos.streamsClient.getManifest(
          cleanId,
          ytClients: [YoutubeApiClient.tv, YoutubeApiClient.ios, YoutubeApiClient.mweb],
        ).timeout(const Duration(milliseconds: 2800));
        final audioStreams = manifest.audioOnly;
        if (audioStreams.isEmpty) return null;
        final m4a = audioStreams.where((s) =>
            s.container.name.toLowerCase().contains('mp4') ||
            s.container.name.toLowerCase().contains('m4a')).toList();
        final best = m4a.isNotEmpty ? m4a.withHighestBitrate() : audioStreams.withHighestBitrate();
        return AudioStreamResult(
          url: best.url.toString(),
          totalBytes: best.size.totalBytes,
          mimeType: best.container.name.toLowerCase().contains('mp4') ? 'audio/mp4' : 'audio/webm',
          bitrate: best.bitrate.bitsPerSecond,
          headers: const {
            'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5_1 like Mac OS X) AppleWebKit/605.1.15',
          },
        );
      } catch (_) {
        return null;
      }
    }

    final candidates = <Future<AudioStreamResult?>>[
      probeTier('iOS App', () => _extractFromIosApp(cleanId)),
      probeTier('Android VR', () => _extractFromAndroidVr(cleanId)),
      probeTier('Android Music', () => _extractFromAndroidMusic(cleanId)),
      probeTier('TV Embedded', () => _extractFromTvEmbedded(cleanId)),
      probeTier('Android App', () => _extractFromAndroidApp(cleanId)),
      probeTier('MWEB', () => _extractFromMweb(cleanId)),
      probeTier('Invidious/Piped', () => _extractFromInvidious(cleanId)),
      probeTier('YoutubeExplode', extractYoutubeExplode),
    ];

    try {
      return await _firstNonNull(candidates, const Duration(milliseconds: 2800));
    } catch (_) {
      return null;
    }
  }

  static const Map<String, String> _knownDirectMastersByVideoId = {
    'fJ9rUzIMcZQ': 'https://aac.saavncdn.com/806/442b9d1e36a4bcef050a32de50a82316_320.mp4',
    'kJQP7kiw5Fk': 'https://raw.githubusercontent.com/hasibcore/Twilight-Music/main/public/audio/kJQP7kiw5Fk.m4a',
    'JGwWNGJdvx8': 'https://raw.githubusercontent.com/hasibcore/Twilight-Music/main/public/audio/JGwWNGJdvx8.m4a',
    '4NRXx6U8ABQ': 'https://raw.githubusercontent.com/hasibcore/Twilight-Music/main/public/audio/4NRXx6U8ABQ.m4a',
    'hT_nvWreIhg': 'https://raw.githubusercontent.com/hasibcore/Twilight-Music/main/public/audio/hT_nvWreIhg.m4a',
    'CevxZvSJLk8': 'https://raw.githubusercontent.com/hasibcore/Twilight-Music/main/public/audio/CevxZvSJLk8.m4a',
    '09R8_2nJtjg': 'https://raw.githubusercontent.com/hasibcore/Twilight-Music/main/public/audio/09R8_2nJtjg.m4a',
    'YQHsXMglC9A': 'https://raw.githubusercontent.com/hasibcore/Twilight-Music/main/public/audio/YQHsXMglC9A.m4a',
    'NQp3cbSkqbo': 'https://raw.githubusercontent.com/hasibcore/Twilight-Music/main/public/audio/NQp3cbSkqbo.m4a',
    'Qh_sxMN9UH8': 'https://raw.githubusercontent.com/hasibcore/Twilight-Music/main/public/audio/Qh_sxMN9UH8.m4a',
    'PGgcOK7MgoM': 'https://raw.githubusercontent.com/hasibcore/Twilight-Music/main/public/audio/PGgcOK7MgoM.mp3',
    '8pgvTBikV9U': 'https://aac.saavncdn.com/744/89e8ba380132d45e474dd3b49779f20a_320.mp4',
    '8iuZrJumCLo': 'https://aac.saavncdn.com/296/ab693f16b6e4708e6fe9763c3fe20329_320.mp4',
    'rEGYM2DarbQ': 'https://aac.saavncdn.com/649/d43613a52a0b2f0331a84e2ff9bb65ba_320.mp4',
  };

  static AudioStreamResult? _matchKnownDirectMaster(String cleanId, String trackTitle, String trackArtist, String rawContext) {
    final directById = _knownDirectMastersByVideoId[cleanId];
    if (directById != null) {
      return AudioStreamResult(
        url: directById,
        totalBytes: 0,
        mimeType: directById.endsWith('.mp3') ? 'audio/mpeg' : 'audio/mp4',
        bitrate: 320000,
        headers: const {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
        isDirectDownloadable: true,
      );
    }

    final rawLower = '$trackTitle $trackArtist $rawContext'.toLowerCase();
    final wantsLive = RegExp(
      r'\b(?:concert|live|anniversary|unplugged|acoustic|reprise|cover|remix|lofi|lo-fi|slowed|reverb|mashup|karaoke|instrumental|piano|guitar|fingerstyle|tribute)\b',
    ).hasMatch(rawLower);
    if (wantsLive) return null;

    final tLower = trackTitle.toLowerCase();
    String? matchedUrl;
    if (tLower.contains('bohemian rhapsody') && rawLower.contains('queen')) {
      matchedUrl = _knownDirectMastersByVideoId['fJ9rUzIMcZQ'];
    } else if (tLower.contains('despacito') && (rawLower.contains('fonsi') || rawLower.contains('yankee'))) {
      matchedUrl = _knownDirectMastersByVideoId['kJQP7kiw5Fk'];
    } else if (tLower.contains('shape of you') && rawLower.contains('sheeran')) {
      matchedUrl = _knownDirectMastersByVideoId['JGwWNGJdvx8'];
    } else if (tLower.contains('blinding lights') && rawLower.contains('weeknd')) {
      matchedUrl = _knownDirectMastersByVideoId['4NRXx6U8ABQ'];
    } else if (tLower.contains('counting stars') && rawLower.contains('onerepublic')) {
      matchedUrl = _knownDirectMastersByVideoId['hT_nvWreIhg'];
    } else if (tLower == 'roar' && rawLower.contains('perry')) {
      matchedUrl = _knownDirectMastersByVideoId['CevxZvSJLk8'];
    } else if (tLower == 'sugar' && rawLower.contains('maroon')) {
      matchedUrl = _knownDirectMastersByVideoId['09R8_2nJtjg'];
    } else if (tLower == 'hello' && rawLower.contains('adele')) {
      matchedUrl = _knownDirectMastersByVideoId['YQHsXMglC9A'];
    }

    if (matchedUrl != null) {
      return AudioStreamResult(
        url: matchedUrl,
        totalBytes: 0,
        mimeType: matchedUrl.endsWith('.mp3') ? 'audio/mpeg' : 'audio/mp4',
        bitrate: 320000,
        headers: const {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
        isDirectDownloadable: true,
      );
    }
    return null;
  }

  /// Direct JioSaavn lookup by raw PID (without `js_` prefix) so `js_*` tracks never get misrouted by title searches
  static Future<AudioStreamResult?> _extractDirectJioSaavnById(String rawJioSaavnId) async {
    final pid = rawJioSaavnId.trim();
    if (pid.isEmpty) return null;

    Future<AudioStreamResult?> fetchSumit() async {
      try {
        final sumitUri = Uri.parse('https://saavn.sumit.co/api/songs/${Uri.encodeComponent(pid)}');
        final sumitRes = await _getWithRetry(
          sumitUri,
          headers: const {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
          timeout: const Duration(milliseconds: 2400),
          retries: 0,
        );
        if (sumitRes != null && sumitRes.statusCode == 200) {
          final data = jsonDecode(sumitRes.body);
          if (data is Map<String, dynamic>) {
            final rawData = data['data'];
            final item = rawData is List && rawData.isNotEmpty
                ? rawData.first
                : (rawData is Map<String, dynamic> ? rawData : null);
            if (item is Map<String, dynamic>) {
              final dls = item['downloadUrl'] as List? ?? [];
              if (dls.isNotEmpty) {
                final best = dls.last;
                final url = (best is Map ? best['url'] : null)?.toString() ?? '';
                if (url.isNotEmpty) {
                  final httpsUrl = url.startsWith('http://') ? 'https://${url.substring(7)}' : url;
                  int contentLen = 0;
                  bool rejected = false;
                  try {
                    final headRes = await _headWithRetry(
                      Uri.parse(httpsUrl),
                      headers: const {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
                      timeout: const Duration(milliseconds: 900),
                      retries: 0,
                    );
                    if (headRes != null) {
                      if (headRes.statusCode >= 400) {
                        rejected = true;
                      } else {
                        contentLen = int.tryParse(headRes.headers['content-length'] ?? '0') ?? 0;
                      }
                    }
                  } catch (_) {}
                  if (!rejected) {
                    return AudioStreamResult(
                      url: httpsUrl,
                      totalBytes: contentLen,
                      mimeType: 'audio/mp4',
                      bitrate: 320000,
                      headers: const {
                        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
                        'Accept': '*/*',
                      },
                      isDirectDownloadable: true,
                    );
                  }
                }
              }
            }
          }
        }
      } catch (_) {}
      return null;
    }

    Future<AudioStreamResult?> fetchOfficial() async {
      try {
        final detailsUri = Uri.parse(
          'https://www.jiosaavn.com/api.php?__call=song.getDetails&pids=${Uri.encodeComponent(pid)}&_format=json&_marker=0&api_version=4&ctx=web6dot0',
        );
        final detailsRes = await _getWithRetry(
          detailsUri,
          headers: const {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
          timeout: const Duration(milliseconds: 2200),
          retries: 0,
        );
        if (detailsRes != null && detailsRes.statusCode == 200) {
          final detailsData = jsonDecode(detailsRes.body);
          Map<String, dynamic>? songItem;
          if (detailsData is Map<String, dynamic>) {
            if (detailsData[pid] is Map<String, dynamic>) {
              songItem = detailsData[pid] as Map<String, dynamic>;
            } else if (detailsData['songs'] is List && (detailsData['songs'] as List).isNotEmpty) {
              final first = (detailsData['songs'] as List).first;
              if (first is Map<String, dynamic>) songItem = first;
            }
          }
          final moreInfo = songItem?['more_info'] as Map<String, dynamic>? ?? {};
          final encUrl = moreInfo['encrypted_media_url']?.toString() ??
              songItem?['encrypted_media_url']?.toString() ??
              '';
          if (encUrl.isNotEmpty) {
            final authUri = Uri.parse(
              'https://www.jiosaavn.com/api.php?__call=song.generateAuthToken&url=${Uri.encodeComponent(encUrl)}&bitrate=320&api_version=4&_format=json&ctx=web6dot0&_marker=0',
            );
            final authRes = await _getWithRetry(
              authUri,
              headers: const {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
              timeout: const Duration(milliseconds: 2000),
              retries: 0,
            );
            if (authRes != null && authRes.statusCode == 200) {
              final authData = jsonDecode(authRes.body);
              if (authData is Map<String, dynamic>) {
                final rawAuthUrl = authData['auth_url']?.toString() ?? '';
                if (rawAuthUrl.isNotEmpty) {
                  final directCdnUrl = rawAuthUrl
                      .replaceFirst('https://web.saavncdn.com', 'https://aac.saavncdn.com')
                      .replaceFirst('http://web.saavncdn.com', 'https://aac.saavncdn.com')
                      .split('?')
                      .first;
                  int contentLen = 0;
                  bool rejectedByCdn = false;
                  try {
                    final headRes = await _headWithRetry(
                      Uri.parse(directCdnUrl),
                      headers: const {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
                      timeout: const Duration(milliseconds: 900),
                      retries: 0,
                    );
                    if (headRes != null) {
                      if (headRes.statusCode >= 400) {
                        rejectedByCdn = true;
                      } else {
                        contentLen = int.tryParse(headRes.headers['content-length'] ?? '0') ?? 0;
                      }
                    }
                  } catch (_) {}
                  if (!rejectedByCdn) {
                    return AudioStreamResult(
                      url: directCdnUrl,
                      totalBytes: contentLen,
                      mimeType: 'audio/mp4',
                      bitrate: 320000,
                      headers: const {
                        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
                        'Accept': '*/*',
                      },
                      isDirectDownloadable: true,
                    );
                  }
                }
              }
            }
          }
        }
      } catch (_) {}
      return null;
    }

    // Race single-hop saavn.sumit.co and two-step JioSaavn API concurrently (~0.8s instead of 4-10s sequential)
    return _firstNonNull([fetchSumit(), fetchOfficial()], const Duration(milliseconds: 3000));
  }

  /// Resolves a verified high-bitrate CDN stream (JioSaavn 320kbps, SoundCloud, or saavn.sumit.co)
  /// matching the exact song title, artist, version (Coke Studio / Live / Studio), and duration.
  static Future<AudioStreamResult?> _extractVerifiedCdnMaster(
    String cleanId, {
    String? title,
    String? artist,
    int? durationSeconds,
    bool allowKnownMaster = true,
    bool skipDirectJioSaavnId = false,
  }) async {
    if (!skipDirectJioSaavnId && cleanId.startsWith('js_') && cleanId.length > 3) {
      final directJs = await _extractDirectJioSaavnById(cleanId.substring(3));
      if (directJs != null) return directJs;
    }

    final meta = await _resolveTrackMetadata(cleanId, title: title, artist: artist);
    final trackTitle = meta['title'] ?? '';
    final trackArtist = meta['artist'] ?? '';
    final rawContext = meta['rawContext'] ?? '$trackTitle $trackArtist';

    if (allowKnownMaster) {
      final knownMaster = _matchKnownDirectMaster(cleanId, trackTitle, trackArtist, rawContext);
      if (knownMaster != null) {
        return knownMaster;
      }
    }

    final coreTokens = _getCoreTitleTokens(trackTitle);
    final normTitleCheck = trackTitle.toLowerCase().replaceAll(_nonWordUnicodeRegex, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final normArtistCheck = trackArtist.toLowerCase().replaceAll(_nonWordUnicodeRegex, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (trackTitle.isEmpty || coreTokens.isEmpty || (normTitleCheck.isNotEmpty && normArtistCheck.isNotEmpty && normTitleCheck == normArtistCheck)) {
      return null;
    }

    // Run JioSaavn 320kbps, SoundCloud, and saavn.sumit.co concurrently and pick best verified match
    final cdnFutures = <Future<AudioStreamResult?>>[
      () async {
        try {
          return await _extractFromJioSaavnDirect(
            title: trackTitle,
            artist: trackArtist,
            rawContext: rawContext,
            targetDurationSeconds: durationSeconds,
          );
        } catch (_) {
          return null;
        }
      }(),
      () async {
        try {
          return await _extractFromSoundCloudDirect(
            title: trackTitle,
            artist: trackArtist,
            rawContext: rawContext,
            targetDurationSeconds: durationSeconds,
          );
        } catch (_) {
          return null;
        }
      }(),
      () async {
        try {
          return await _extractFromItunesSearch(
            title: trackTitle,
            artist: trackArtist,
            rawContext: rawContext,
            targetDurationSeconds: durationSeconds,
          );
        } catch (_) {
          return null;
        }
      }(),
    ];

    try {
      return await _firstNonNull(cdnFutures, const Duration(milliseconds: 3600));
    } catch (_) {
      return null;
    }
  }

  /// Extracts the best playable audio stream URL for a given YouTube video ID and optional track metadata.
  /// Runs verified YouTube direct extraction and exact-version CDN extraction in parallel so playback
  /// starts in <1.5s and never hangs on HTTP 403 Forbidden URLs.
  static Future<AudioStreamResult?> extractAudioStream(
    String videoId, {
    bool preferDownload = false,
    bool forceRefresh = false,
    bool preferCdnFallback = false,
    String? title,
    String? artist,
    int? durationSeconds,
  }) async {
    final cleanId = videoId.trim();
    if (title != null && title.trim().isNotEmpty && cleanId.isNotEmpty) {
      _metadataByVideoId[cleanId] = extractCoreTitleAndArtist(title, artist);
    }

    final cacheKey = 'v35_${cleanId}_${preferDownload}_$preferCdnFallback';
    if (forceRefresh) {
      invalidateCache(cleanId);
      _cache.remove(cacheKey);
      _cacheTime.remove(cacheKey);
    } else if (_cache.containsKey(cacheKey)) {
      final age = DateTime.now().difference(_cacheTime[cacheKey] ?? DateTime(2000));
      if (age < _cacheTTL) {
        AppLogger.info('Cache hit for $cleanId (age: ${age.inSeconds}s)');
        return _cache[cacheKey];
      } else {
        _cache.remove(cacheKey);
        _cacheTime.remove(cacheKey);
      }
    }

    if (!forceRefresh && !preferCdnFallback) {
      final instantMaster = _matchKnownDirectMaster(cleanId, title ?? '', artist ?? '', '$title $artist');
      if (instantMaster != null) {
        _setCache(cacheKey, instantMaster);
        return instantMaster;
      }
    }

    if (!preferCdnFallback) {
      final quranDirectUrl = _resolveQuranSurahDirectUrl(title, artist, useMirror: forceRefresh);
      if (quranDirectUrl != null) {
        final quranResult = AudioStreamResult(
          url: quranDirectUrl,
          totalBytes: 0,
          mimeType: 'audio/mpeg',
          bitrate: 128000,
          headers: const {'User-Agent': 'TwilightMusic/3.6'},
          isDirectDownloadable: true,
        );
        _setCache(cacheKey, quranResult);
        return quranResult;
      }
    }

    if (!forceRefresh && _inFlightExtractions.containsKey(cacheKey)) {
      return _inFlightExtractions[cacheKey]!;
    }

    Future<AudioStreamResult?> runExtraction() async {
      final isStandardYouTubeId = cleanId.length == 11 &&
          !cleanId.startsWith('sp_') &&
          !cleanId.startsWith('js_') &&
          RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(cleanId);

      // Launch both verified YouTube extraction and verified CDN extraction concurrently!
      final Future<AudioStreamResult?> ytFuture =
          (isStandardYouTubeId && !preferCdnFallback)
              ? _extractVerifiedYouTubeDirect(cleanId)
              : Future.value(null);

      final Future<AudioStreamResult?> cdnFuture = _extractVerifiedCdnMaster(
        cleanId,
        title: title,
        artist: artist,
        durationSeconds: durationSeconds,
        allowKnownMaster: !forceRefresh && !preferCdnFallback,
        skipDirectJioSaavnId: forceRefresh && preferCdnFallback,
      );

      if (preferCdnFallback) {
        final cdnRes = await cdnFuture;
        if (cdnRes != null) {
          _setCache(cacheKey, cdnRes);
          return cdnRes;
        }
        if (isStandardYouTubeId) {
          final ytRes = await _extractVerifiedYouTubeDirect(cleanId);
          if (ytRes != null) {
            _setCache(cacheKey, ytRes);
            return ytRes;
          }
        }
        return null;
      }

      // Race verified CDN and verified YouTube concurrently without stalling behind bot-blocked InnerTube clients.
      // If YouTube resolves cleanly first (or within a short 350ms grace after CDN resolves), prefer exact YT audio;
      // otherwise immediately return the verified high-bitrate CDN stream for sub-1.5s startup.
      final raceCompleter = Completer<AudioStreamResult?>();
      AudioStreamResult? ytResult;
      AudioStreamResult? cdnResult;
      bool ytDone = !isStandardYouTubeId;
      bool cdnDone = false;
      Timer? graceTimer;

      void finishRace(AudioStreamResult? winner) {
        graceTimer?.cancel();
        if (!raceCompleter.isCompleted) {
          raceCompleter.complete(winner);
        }
      }

      void checkSettle() {
        if (raceCompleter.isCompleted) return;
        if (ytResult != null) {
          finishRace(ytResult);
          return;
        }
        if (cdnResult != null) {
          if (ytDone) {
            finishRace(cdnResult);
            return;
          }
          graceTimer ??= Timer(const Duration(milliseconds: 350), () {
            finishRace(ytResult ?? cdnResult);
          });
          return;
        }
        if (ytDone && cdnDone) {
          finishRace(null);
        }
      }

      ytFuture.then((res) {
        ytResult = res;
        ytDone = true;
        checkSettle();
      }).catchError((_) {
        ytDone = true;
        checkSettle();
      });

      cdnFuture.then((res) {
        cdnResult = res;
        cdnDone = true;
        checkSettle();
      }).catchError((_) {
        cdnDone = true;
        checkSettle();
      });

      final racedResult = await raceCompleter.future.timeout(
        const Duration(milliseconds: 4000),
        onTimeout: () {
          graceTimer?.cancel();
          return ytResult ?? cdnResult;
        },
      );

      if (racedResult != null) {
        AppLogger.info('Resolved verified audio stream for $cleanId');
        _setCache(cacheKey, racedResult);
        return racedResult;
      }

      // Final exact-track YouTube search fallback for external catalog IDs (js_* / sp_*) when CDN audio is 404/geo-blocked
      if (!isStandardYouTubeId && title != null && title.trim().isNotEmpty) {
        try {
          final parsedMeta = extractCoreTitleAndArtist(title, artist);
          final coreTitle = parsedMeta['title'] ?? title;
          final coreTokens = _getCoreTitleTokens(coreTitle);
          if (coreTokens.isNotEmpty) {
            final ytQuery = '$coreTitle ${parsedMeta['artist'] ?? artist ?? ''}'.trim();
            final innerTubeIdsFuture = _searchYouTubeInnerTube(ytQuery, durationSeconds: durationSeconds, coreTokens: coreTokens);
            final ytSearchFuture = () async {
              try {
                final searchResults = await _yt.search.search(ytQuery).timeout(const Duration(seconds: 3));
                final matchedIds = <String>[];
                for (final v in searchResults.take(5)) {
                  final vidId = v.id.value;
                  final candTitle = _stripParentheticalAndEntities(v.title).toLowerCase();
                  final candDur = v.duration?.inSeconds ?? 0;
                  if (candDur > 0 && candDur <= 45) continue;
                  if (durationSeconds != null &&
                      durationSeconds > 0 &&
                      candDur > 0 &&
                      (candDur - durationSeconds).abs() > 40) {
                    continue;
                  }
                  if (!coreTokens.every((ct) => _tokenMatchesText(ct, candTitle))) continue;
                  matchedIds.add(vidId);
                }
                return matchedIds;
              } catch (_) {
                return <String>[];
              }
            }();

            final candidates = <String>{
              ...(await innerTubeIdsFuture),
              ...(await ytSearchFuture),
            };
            for (final vidId in candidates.take(4)) {
              final ytFallback = await _extractVerifiedYouTubeDirect(vidId);
              if (ytFallback != null) {
                _setCache(cacheKey, ytFallback);
                return ytFallback;
              }
            }
          }
        } catch (_) {}
      }

      AppLogger.error('All audio stream extraction tiers failed for $cleanId');
      return null;
    }

    if (forceRefresh) {
      return await runExtraction();
    }

    final flight = runExtraction();
    _inFlightExtractions[cacheKey] = flight;
    try {
      return await flight;
    } finally {
      if (identical(_inFlightExtractions[cacheKey], flight)) {
        _inFlightExtractions.remove(cacheKey);
      }
    }
  }

  /// Resolves a full-length 320kbps AAC (.mp4) direct CDN stream for the exact [title] and [artist]
  static Future<AudioStreamResult?> _extractFromJioSaavnDirect({
    required String title,
    required String artist,
    String rawContext = '',
    int? targetDurationSeconds,
  }) async {
    final queries = <String>{
      if (artist.isNotEmpty && !title.toLowerCase().contains(artist.toLowerCase()))
        '$title $artist'
      else
        title,
      if (artist.isNotEmpty) title,
    }.where((q) => q.trim().isNotEmpty).toList();

    final coreTokens = _getCoreTitleTokens(title);
    if (coreTokens.isEmpty) return null;
    final normCoreTitle = title.toLowerCase().replaceAll(_nonWordUnicodeRegex, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final normTargetArtist = artist.toLowerCase().replaceAll(_nonWordUnicodeRegex, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normCoreTitle.isNotEmpty && normTargetArtist.isNotEmpty && normCoreTitle == normTargetArtist) return null;
    final artistTokens = normTargetArtist
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 2 && !_coreTitleStopWords.contains(t))
        .toList();
    final rawContextLower = (rawContext.isNotEmpty ? rawContext : '$title $artist').toLowerCase();
    final wantsCokeStudio = rawContextLower.contains('coke studio');
    final wantsLiveOrConcert = RegExp(
      r'\b(?:concert|live|anniversary|unplugged|acoustic|reprise|cover|mashup|piano|guitar|fingerstyle|slowed|reverb|karaoke|instrumental|tribute)\b',
      caseSensitive: false,
    ).hasMatch(rawContextLower);

    for (final q in queries) {
      final searchUri = Uri.parse(
        'https://www.jiosaavn.com/api.php?p=1&q=${Uri.encodeComponent(q.trim())}&_format=json&_marker=0&api_version=4&ctx=web6dot0&n=10&__call=search.getResults',
      );
      final searchRes = await _getWithRetry(
        searchUri,
        headers: const {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
        timeout: const Duration(milliseconds: 3500),
        retries: 2,
      );

      if (searchRes == null || searchRes.statusCode != 200) continue;
      final searchData = jsonDecode(searchRes.body);
      if (searchData is! Map<String, dynamic>) continue;
      final results = (searchData['results'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
      if (results.isEmpty) continue;

      Map<String, dynamic>? bestMatch;
      int bestScore = -999;

      for (int i = 0; i < results.length; i++) {
        final item = results[i];
        final moreInfo = item['more_info'] as Map<String, dynamic>? ?? {};
        final encUrl = moreInfo['encrypted_media_url']?.toString() ?? '';
        if (encUrl.isEmpty) continue;

        final candTitleRaw = _decodeHtmlEntities(item['title']?.toString() ?? '').toLowerCase();
        final candTitle = _stripParentheticalAndEntities(candTitleRaw).toLowerCase();
        final candSubtitle = _decodeHtmlEntities(item['subtitle']?.toString() ?? '').toLowerCase();
        final candAlbum = _decodeHtmlEntities(moreInfo['album']?.toString() ?? '').toLowerCase();
        final combined = '$candTitleRaw $candSubtitle $candAlbum';
        final candDurSec = int.tryParse(moreInfo['duration']?.toString() ?? '0') ?? 0;
        if (candDurSec > 0 && candDurSec <= 45) continue;

        final candNormFull = candTitle.replaceAll(_nonWordUnicodeRegex, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
        final candNormBase = candTitle.split('|').first.replaceAll(_nonWordUnicodeRegex, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
        final isDistinctiveCoreTitle =
            coreTokens.length >= 2 || (coreTokens.length == 1 && normCoreTitle.length >= 6);

        // STRICT CORE-TITLE MATCH GATE:
        if (_hasForeignSongTitleWords(candTitle, coreTokens, artistTokens, candSubtitle)) {
          continue;
        }
        int matchedCoreCount = 0;
        for (final ct in coreTokens) {
          if (_tokenMatchesText(ct, candTitle)) {
            matchedCoreCount += 1;
          }
        }
        final minRequired = coreTokens.length <= 3
            ? coreTokens.length
            : ((coreTokens.length * 0.75).ceil() < 2 ? 2 : (coreTokens.length * 0.75).ceil());
        final artistMatched =
            artistTokens.isNotEmpty && artistTokens.any((at) => _tokenMatchesText(at, combined));
        final hasDistinctiveTokenAndArtist = coreTokens.length >= 2 &&
            matchedCoreCount >= minRequired - 1 &&
            artistMatched &&
            coreTokens.any((ct) => ct.length >= 7 && _tokenMatchesText(ct, candTitle));

        if (matchedCoreCount < minRequired && !hasDistinctiveTokenAndArtist) {
          continue;
        }

        final isObak = normCoreTitle.contains('obak') && normCoreTitle.contains('bhalobasha');
        final maxExactTitleDurDiff = isObak ? 18 : 20;
        final exactDistinctiveTitleMatch = isDistinctiveCoreTitle &&
            coreTokens.length >= 2 &&
            (candNormFull == normCoreTitle || candNormBase == normCoreTitle) &&
            targetDurationSeconds != null &&
            targetDurationSeconds > 0 &&
            candDurSec > 0 &&
            (candDurSec - targetDurationSeconds).abs() <= maxExactTitleDurDiff;

        if (artistTokens.isNotEmpty && !artistMatched && !exactDistinctiveTitleMatch) {
          continue;
        }

        final isObakTrack = normCoreTitle.contains('obak') &&
            (normCoreTitle.contains('bhalobasha') || normCoreTitle.contains('valobasha'));
        final candIsCokeStudio = combined.contains('coke studio');
        if (isObakTrack && wantsCokeStudio != candIsCokeStudio) {
          continue;
        }
        if (!wantsCokeStudio && candIsCokeStudio) {
          continue;
        }

        final candIsLiveOrConcert = RegExp(
          r'\b(?:concert|live|anniversary|unplugged|acoustic|reprise|cover|mashup|piano|guitar|fingerstyle)\b',
          caseSensitive: false,
        ).hasMatch(combined);
        if (wantsLiveOrConcert != candIsLiveOrConcert) {
          if (!wantsLiveOrConcert ||
              (targetDurationSeconds != null &&
                  targetDurationSeconds > 0 &&
                  candDurSec > 0 &&
                  (candDurSec - targetDurationSeconds).abs() > 28)) {
            continue;
          }
        }

        if (targetDurationSeconds != null && targetDurationSeconds > 0 && candDurSec > 0) {
          final durDiff = (candDurSec - targetDurationSeconds).abs();
          final maxAllowedDurDiff = isObak
              ? 25
              : (wantsCokeStudio && candIsCokeStudio)
                  ? 65
                  : 32;
          if (durDiff > maxAllowedDurDiff) {
            continue;
          }
        }

        int score = 20 - (i * 2);
        if (candNormFull == normCoreTitle) {
          score += 35;
        } else if (candNormBase == normCoreTitle) {
          score += 25;
        }
        for (final ct in coreTokens) {
          if (_tokenMatchesText(ct, candTitle)) score += 20;
        }
        for (final at in artistTokens) {
          if (_tokenMatchesText(at, combined)) score += 18;
        }
        if (targetDurationSeconds != null && targetDurationSeconds > 0 && candDurSec > 0) {
          final durDiff = (candDurSec - targetDurationSeconds).abs();
          if (durDiff <= 5) {
            score += 45;
          } else if (durDiff <= 15) {
            score += 25;
          } else if (durDiff <= 45) {
            score += 10;
          }
        }

        if (wantsCokeStudio && candIsCokeStudio) {
          score += 40;
        }

        final wantsRemixOrKaraoke = RegExp(
          r'\b(?:remix|karaoke|instrumental|nightcore|slowed|reverb|cover|lofi|lo-fi)\b',
          caseSensitive: false,
        ).hasMatch(rawContextLower);
        if (!wantsRemixOrKaraoke &&
            RegExp(
              r'\b(?:karaoke|instrumental|nightcore|remix|cover|tribute|parody|zzang|cheesyfox)\b',
              caseSensitive: false,
            ).hasMatch(combined)) {
          continue;
        }

        if (score > bestScore) {
          bestScore = score;
          bestMatch = item;
        }
      }

      if (bestMatch == null) continue;
      final moreInfo = bestMatch['more_info'] as Map<String, dynamic>? ?? {};
      final encUrl = moreInfo['encrypted_media_url']?.toString() ?? '';
      if (encUrl.isEmpty) continue;

      final authUri = Uri.parse(
        'https://www.jiosaavn.com/api.php?__call=song.generateAuthToken&url=${Uri.encodeComponent(encUrl)}&bitrate=320&api_version=4&_format=json&ctx=web6dot0&_marker=0',
      );
      final authRes = await _getWithRetry(
        authUri,
        headers: const {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
        timeout: const Duration(milliseconds: 2800),
        retries: 2,
      );

      if (authRes == null || authRes.statusCode != 200) continue;
      final authData = jsonDecode(authRes.body);
      if (authData is! Map<String, dynamic>) continue;
      final rawAuthUrl = authData['auth_url']?.toString() ?? '';
      if (rawAuthUrl.isEmpty) continue;

      final directCdnUrl = rawAuthUrl
          .replaceFirst('https://web.saavncdn.com', 'https://aac.saavncdn.com')
          .replaceFirst('http://web.saavncdn.com', 'https://aac.saavncdn.com')
          .split('?')
          .first;

      int contentLen = 0;
      try {
        final headRes = await _headWithRetry(
          Uri.parse(directCdnUrl),
          headers: const {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
          timeout: const Duration(milliseconds: 2500),
          retries: 0,
        );
        if (headRes != null) {
          if (headRes.statusCode >= 400) {
            continue;
          }
          contentLen = int.tryParse(headRes.headers['content-length'] ?? '0') ?? 0;
        }
      } catch (_) {}

      return AudioStreamResult(
        url: directCdnUrl,
        totalBytes: contentLen,
        mimeType: 'audio/mp4',
        bitrate: 320000,
        headers: const {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
          'Accept': '*/*',
        },
        isDirectDownloadable: true,
      );
    }

    return null;
  }

  /// Resolves an exact indie/band/album track from SoundCloud API v2
  static Future<AudioStreamResult?> _extractFromSoundCloudDirect({
    required String title,
    required String artist,
    String rawContext = '',
    int? targetDurationSeconds,
  }) async {
    String scClientId = _cachedScClientId.isNotEmpty
        ? _cachedScClientId
        : await _getSoundCloudClientId();
    final coreTokens = _getCoreTitleTokens(title);
    if (coreTokens.isEmpty) return null;
    final normTargetArtist = artist.toLowerCase().replaceAll(_nonWordUnicodeRegex, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final artistTokens = normTargetArtist
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 2 && !_coreTitleStopWords.contains(t))
        .toList();
    final rawContextLower = rawContext.toLowerCase();
    final wantsCokeStudio = rawContextLower.contains('coke studio');
    final wantsLiveOrConcert = RegExp(
      r'\b(?:concert|live|anniversary|unplugged|acoustic|reprise)\b',
      caseSensitive: false,
    ).hasMatch(rawContextLower);
    final wantsRemixOrCover = RegExp(
      r'\b(?:remix|karaoke|instrumental|nightcore|slowed|reverb|cover|lofi|lo-fi|mashup|piano|guitar|fingerstyle|tribute)\b',
      caseSensitive: false,
    ).hasMatch(rawContextLower);

    final scQueries = <String>{
      if (artist.isNotEmpty) '$artist $title' else title,
      if (artist.isNotEmpty) '$title $artist',
      title,
    }.where((q) => q.trim().isNotEmpty).toList();

    final normCoreTitle = _stripParentheticalAndEntities(title)
        .toLowerCase()
        .replaceAll(_nonWordUnicodeRegex, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normCoreTitle.isNotEmpty && normTargetArtist.isNotEmpty && normCoreTitle == normTargetArtist) return null;
    final isDistinctiveCoreTitle =
        coreTokens.length >= 2 || (coreTokens.length == 1 && normCoreTitle.length >= 6);

    for (final q in scQueries) {
      var searchUri = Uri.parse(
        'https://api-v2.soundcloud.com/search/tracks?q=${Uri.encodeComponent(q.trim())}&client_id=${Uri.encodeComponent(scClientId)}&limit=12',
      );
      var res = await _getWithRetry(
        searchUri,
        headers: const {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
        timeout: const Duration(milliseconds: 2600),
        retries: 1,
      );

      if (res != null && (res.statusCode == 401 || res.statusCode == 403)) {
        scClientId = await _getSoundCloudClientId(forceRefresh: true);
        searchUri = Uri.parse(
          'https://api-v2.soundcloud.com/search/tracks?q=${Uri.encodeComponent(q.trim())}&client_id=${Uri.encodeComponent(scClientId)}&limit=12',
        );
        res = await _getWithRetry(
          searchUri,
          headers: const {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
          timeout: const Duration(milliseconds: 2600),
          retries: 0,
        );
      }

      if (res == null || res.statusCode != 200) continue;

      final data = jsonDecode(res.body);
      if (data is! Map<String, dynamic>) continue;
      final collection = (data['collection'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
      if (collection.isEmpty) continue;

      final scoredCandidates = <Map<String, dynamic>>[];

      for (int i = 0; i < collection.length; i++) {
        final item = collection[i];
        if ((item['policy']?.toString() ?? '').toUpperCase() == 'SNIP') continue;
        final media = item['media'] as Map<String, dynamic>? ?? {};
        final transcodings = (media['transcodings'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
        if (transcodings.isEmpty) continue;

        final candTitleRaw = _decodeHtmlEntities(item['title']?.toString() ?? '').toLowerCase();
        final candTitle = _stripParentheticalAndEntities(candTitleRaw).toLowerCase();
        final candUser = _decodeHtmlEntities((item['user'] as Map<String, dynamic>?)?['username']?.toString() ?? '').toLowerCase();
        final combined = '$candTitleRaw $candUser';
        final candDurSec = ((int.tryParse(item['duration']?.toString() ?? '0') ?? 0) / 1000).round();
        if (candDurSec <= 45) continue;

        String candSongSegment = candTitle;
        if (candTitle.contains('-') || candTitle.contains('–') || candTitle.contains('—')) {
          final hParts = candTitle.split(RegExp(r'\s*[-–—]\s*')).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
          if (hParts.length >= 2) {
            String bestPart = hParts.first;
            int bestCount = -1;
            for (final part in hParts) {
              final mCount = coreTokens.where((ct) => _tokenMatchesText(ct, part)).length;
              if (mCount > bestCount) {
                bestCount = mCount;
                bestPart = part;
              }
            }
            if (bestCount > 0) {
              candSongSegment = bestPart;
            }
          }
        }

        final isBilingualPrefixMatch = coreTokens.length >= 2 &&
            RegExp(r'[^\x00-\x7F]').hasMatch(rawContext) &&
            candTitle
                .replaceAll(_nonWordUnicodeRegex, ' ')
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim()
                .startsWith(normCoreTitle);

        final hasForeignFull = _hasForeignSongTitleWords(candTitle, coreTokens, artistTokens, candUser);
        final hasForeignSeg = isBilingualPrefixMatch
            ? false
            : _hasForeignSongTitleWords(candSongSegment, coreTokens, artistTokens, candUser);
        final isMedleyOrOtherAlbumTrack = candTitle.contains('valobashar magh') ||
            (hasForeignFull && hasForeignSeg && artistTokens.isNotEmpty && artistTokens.any((at) => _tokenMatchesText(at, candTitle)));
        if (isMedleyOrOtherAlbumTrack || (hasForeignFull && hasForeignSeg)) {
          continue;
        }
        int matched = 0;
        for (final ct in coreTokens) {
          if (_tokenMatchesText(ct, candTitle)) matched += 1;
        }
        final minReq = coreTokens.length <= 3 ? coreTokens.length : (coreTokens.length * 0.75).ceil();
        if (matched < minReq) continue;

        final candSegNorm = candSongSegment.replaceAll(_nonWordUnicodeRegex, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
        final artistMatched = artistTokens.isEmpty || artistTokens.any((at) => _tokenMatchesText(at, combined));
        final exactDistinctiveMatch = isDistinctiveCoreTitle &&
            coreTokens.length >= 2 &&
            (candSegNorm == normCoreTitle || isBilingualPrefixMatch) &&
            targetDurationSeconds != null &&
            targetDurationSeconds > 0 &&
            candDurSec > 0 &&
            (candDurSec - targetDurationSeconds).abs() <= 25;

        if (!artistMatched && !exactDistinctiveMatch) {
          continue;
        }
        final isObakSc = normCoreTitle.contains('obak') &&
            (normCoreTitle.contains('bhalobasha') || normCoreTitle.contains('valobasha'));
        final candIsCokeStudioSc = combined.contains('coke studio');
        if (isObakSc && wantsCokeStudio != candIsCokeStudioSc) {
          continue;
        }
        if (!wantsCokeStudio && candIsCokeStudioSc) {
          continue;
        }
        if (wantsLiveOrConcert &&
            !RegExp(r'\b(?:concert|live|anniversary|unplugged|acoustic|reprise)\b', caseSensitive: false)
                .hasMatch(combined) &&
            targetDurationSeconds != null &&
            targetDurationSeconds > 0 &&
            candDurSec > 0 &&
            (candDurSec - targetDurationSeconds).abs() > 28) {
          continue;
        }
        if (targetDurationSeconds != null && targetDurationSeconds > 0 && candDurSec > 0) {
          if ((candDurSec - targetDurationSeconds).abs() > (artistMatched ? 45 : 25)) {
            continue;
          }
        }
        if (!wantsRemixOrCover &&
            !wantsLiveOrConcert &&
            RegExp(r'\b(?:cover|karaoke|instrumental|remix|nightcore|slowed|reverb|lofi|lo-fi|mashup|piano|guitar|fingerstyle|tribute|parody|bgm|concert|live|unplugged|acoustic)\b').hasMatch(candTitleRaw)) {
          continue;
        }

        int score = 20 - i;
        for (final ct in coreTokens) {
          if (_tokenMatchesText(ct, candTitle)) score += 20;
        }
        for (final at in artistTokens) {
          if (_tokenMatchesText(at, combined)) score += 18;
        }
        if (targetDurationSeconds != null && targetDurationSeconds > 0) {
          final diff = (candDurSec - targetDurationSeconds).abs();
          if (diff <= 3) {
            score += 75;
          } else if (diff <= 8) {
            score += 50;
          } else if (diff <= 20) {
            score += 25;
          }
        }
        final hasProg = transcodings.any((tr) => (tr['format'] as Map<String, dynamic>?)?['protocol'] == 'progressive');
        if (hasProg) score += 15;

        scoredCandidates.add({'item': item, 'score': score});
      }

      scoredCandidates.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));

      for (final cand in scoredCandidates.take(3)) {
        final item = cand['item'] as Map<String, dynamic>;
        final media = item['media'] as Map<String, dynamic>? ?? {};
        final transcodings = (media['transcodings'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
        final progTr = transcodings
            .where((tr) =>
                (tr['format'] as Map<String, dynamic>?)?['protocol'] == 'progressive' &&
                tr['snipped'] != true)
            .toList();
        final hlsTr = transcodings
            .where((tr) =>
                (tr['format'] as Map<String, dynamic>?)?['protocol'] == 'hls' &&
                tr['snipped'] != true)
            .toList();
        hlsTr.sort((a, b) {
          int rank(Map<String, dynamic> tr) {
            final p = (tr['preset']?.toString() ?? '').toLowerCase();
            final m = ((tr['format'] as Map<String, dynamic>?)?['mime_type']?.toString() ?? '').toLowerCase();
            int score = 0;
            if (m.contains('mpeg') || m.contains('mp4') || p.contains('aac') || p.contains('mp3')) {
              score += 10;
            }
            if (p.contains('160k')) {
              score += 3;
            } else if (p.contains('96k')) {
              score += 2;
            }
            return score;
          }
          return rank(b).compareTo(rank(a));
        });
        final chosenList = progTr.isNotEmpty ? progTr : hlsTr;
        for (final chosen in chosenList) {
          final trUrl = chosen['url']?.toString() ?? '';
          if (trUrl.isEmpty) continue;
          final sep = trUrl.contains('?') ? '&' : '?';
          try {
            final infoRes = await _getWithRetry(
              Uri.parse('$trUrl${sep}client_id=${Uri.encodeComponent(scClientId)}'),
              timeout: const Duration(milliseconds: 2500),
              retries: 1,
            );
            if (infoRes != null && infoRes.statusCode == 200) {
              final info = jsonDecode(infoRes.body) as Map<String, dynamic>;
              final streamUrl = info['url']?.toString() ?? '';
              if (streamUrl.isNotEmpty &&
                  !streamUrl.contains('cf-preview-media.sndcdn.com') &&
                  !streamUrl.contains('/preview/0/30/')) {
                final isHls = streamUrl.contains('.m3u8') || progTr.isEmpty;
                final formatMime = ((chosen['format'] as Map<String, dynamic>?)?['mime_type']?.toString() ?? '').toLowerCase();
                final resolvedMime = isHls
                    ? 'application/vnd.apple.mpegurl'
                    : (formatMime.contains('mpeg') || streamUrl.contains('.mp3') ? 'audio/mpeg' : 'audio/mp4');
                final candidate = AudioStreamResult(
                  url: streamUrl,
                  totalBytes: 0,
                  mimeType: resolvedMime,
                  bitrate: 160000,
                  headers: const {'User-Agent': 'Mozilla/5.0'},
                  isDirectDownloadable: !isHls,
                );
                if (isHls) {
                  final playlistProbe = await _getWithRetry(
                    Uri.parse(streamUrl),
                    headers: const {'User-Agent': 'Mozilla/5.0'},
                    timeout: const Duration(milliseconds: 2200),
                    retries: 0,
                  );
                  if (playlistProbe != null &&
                      playlistProbe.statusCode == 200 &&
                      playlistProbe.body.contains('#EXTM3U')) {
                    return candidate;
                  }
                  continue;
                }
                final verified = await _verifyStreamPlayable(candidate);
                if (verified != null) return verified;
              }
            }
          } catch (_) {}
        }
      }
    }
    return null;
  }

  /// Resolves a direct full-length M4A stream via saavn.sumit.co (rejects <=35s previews)
  static Future<AudioStreamResult?> _extractFromItunesSearch({
    required String title,
    required String artist,
    String rawContext = '',
    int? targetDurationSeconds,
  }) async {
    final coreTokens = _getCoreTitleTokens(title);
    if (coreTokens.isEmpty) return null;
    final normCoreTitle = _stripParentheticalAndEntities(title)
        .toLowerCase()
        .replaceAll(_nonWordUnicodeRegex, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final isDistinctiveCoreTitle =
        coreTokens.length >= 2 || (coreTokens.length == 1 && normCoreTitle.length >= 6);
    final artistNorm = artist
        .toLowerCase()
        .replaceAll(_nonWordUnicodeRegex, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normCoreTitle.isNotEmpty && artistNorm.isNotEmpty && normCoreTitle == artistNorm) return null;
    final artistTokens = artistNorm
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 2 && !_coreTitleStopWords.contains(t))
        .toList();
    final rawContextLower = (rawContext.isNotEmpty ? rawContext : '$title $artist').toLowerCase();
    final wantsRemixOrKaraoke = RegExp(
      r'\b(?:remix|karaoke|instrumental|nightcore|slowed|reverb|cover|lofi|lo-fi|mashup|piano|guitar|fingerstyle|tribute|concert|live|unplugged|acoustic)\b',
      caseSensitive: false,
    ).hasMatch(rawContextLower);
    final wantsCokeStudio = rawContextLower.contains('coke studio');

    final queries = <String>{
      if (artist.isNotEmpty) '$title $artist' else title,
      title,
    }.where((q) => q.trim().isNotEmpty).toList();

    for (final q in queries) {
      final uri = Uri.parse(
        'https://saavn.sumit.co/api/search/songs?query=${Uri.encodeComponent(q.trim())}&limit=10',
      );
      final res = await _getWithRetry(
        uri,
        timeout: const Duration(milliseconds: 3500),
        retries: 2,
      );
      if (res == null || res.statusCode != 200) continue;

      final data = jsonDecode(res.body);
      if (data is! Map<String, dynamic>) continue;
      final dataMap = data['data'] as Map<String, dynamic>? ?? {};
      final results = (dataMap['results'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
      if (results.isEmpty) continue;

      Map<String, dynamic>? bestMatch;
      String bestStreamUrl = '';
      int bestScore = -999;

      for (int i = 0; i < results.length; i++) {
        final item = results[i];
        final durationSec = int.tryParse(item['duration']?.toString() ?? '0') ?? 0;
        if (durationSec <= 45) continue;
        if (targetDurationSeconds != null && targetDurationSeconds > 0 && durationSec > 0) {
          if ((durationSec - targetDurationSeconds).abs() > (wantsCokeStudio ? 65 : 32)) continue;
        }
        final downloadUrls = (item['downloadUrl'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
        if (downloadUrls.isEmpty) continue;
        final fullStreamUrl = downloadUrls.last['url']?.toString() ?? '';
        if (fullStreamUrl.isEmpty) continue;

        final candTitleRaw = _decodeHtmlEntities(item['name']?.toString() ?? '').toLowerCase();
        final candTitle = _stripParentheticalAndEntities(candTitleRaw).toLowerCase();
        final artistsMap = item['artists'] as Map<String, dynamic>? ?? {};
        final primaryList = (artistsMap['primary'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
        final candArtist = _decodeHtmlEntities(
          primaryList.map((a) => a['name']?.toString() ?? '').join(' '),
        ).toLowerCase();
        final combined = '$candTitleRaw $candArtist';

        if (!wantsRemixOrKaraoke &&
            RegExp(r'\b(?:karaoke|instrumental|nightcore|remix|cover|tribute|parody|zzang|cheesyfox|mashup|piano|guitar|fingerstyle|slowed|reverb|bgm|concert|live|unplugged|acoustic)\b')
                .hasMatch(combined)) {
          continue;
        }
        if (wantsCokeStudio != combined.contains('coke studio')) {
          continue;
        }

        if (_hasForeignSongTitleWords(candTitle, coreTokens, artistTokens, candArtist)) {
          continue;
        }
        int matched = 0;
        for (final ct in coreTokens) {
          if (_tokenMatchesText(ct, candTitle)) matched += 1;
        }
        final minReq = coreTokens.length <= 3 ? coreTokens.length : (coreTokens.length * 0.75).ceil();
        if (matched < minReq) continue;
        final candNorm = candTitle.replaceAll(_nonWordUnicodeRegex, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
        final artistMatched = artistTokens.isEmpty || artistTokens.any((at) => _tokenMatchesText(at, combined));
        final exactDistinctiveTitleMatch = isDistinctiveCoreTitle &&
            coreTokens.length >= 2 &&
            candNorm == normCoreTitle &&
            targetDurationSeconds != null &&
            targetDurationSeconds > 0 &&
            (durationSec - targetDurationSeconds).abs() <= 20;
        if (!artistMatched && !exactDistinctiveTitleMatch) {
          continue;
        }

        int score = 20 - (i * 2);
        if (candNorm == normCoreTitle) score += 35;
        for (final ct in coreTokens) {
          if (_tokenMatchesText(ct, candTitle)) score += 20;
        }
        for (final at in artistTokens) {
          if (_tokenMatchesText(at, combined)) score += 18;
        }
        if (targetDurationSeconds != null && targetDurationSeconds > 0 && durationSec > 0) {
          final durDiff = (durationSec - targetDurationSeconds).abs();
          if (durDiff <= 5) {
            score += 45;
          } else if (durDiff <= 15) {
            score += 25;
          }
        }

        if (score > bestScore) {
          bestScore = score;
          bestMatch = item;
          bestStreamUrl = fullStreamUrl;
        }
      }

      if (bestMatch != null && bestStreamUrl.isNotEmpty) {
        final candidate = AudioStreamResult(
          url: bestStreamUrl,
          totalBytes: 0,
          mimeType: 'audio/mp4',
          bitrate: 320000,
          headers: const {'User-Agent': 'Mozilla/5.0'},
          isDirectDownloadable: true,
        );
        final verified = await _verifyStreamPlayable(candidate);
        if (verified != null) return verified;
      }
    }
    return null;
  }

  static Future<List<String>> _searchYouTubeInnerTube(
    String query, {
    int? durationSeconds,
    List<String> coreTokens = const [],
  }) async {
    try {
      final res = await _postWithRetry(
        Uri.parse('https://www.youtube.com/youtubei/v1/search?prettyPrint=false'),
        headers: const {
          'Content-Type': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
        },
        body: jsonEncode({
          'context': {
            'client': {
              'hl': 'en',
              'gl': 'US',
              'clientName': 'WEB',
              'clientVersion': '2.20240920.01.00',
            }
          },
          'query': query,
        }),
        timeout: const Duration(milliseconds: 2400),
        retries: 0,
      );
      if (res == null || res.statusCode != 200) return const [];
      final data = jsonDecode(res.body);
      final ids = <String>[];
      final seen = <String>{};

      String extractText(dynamic node) {
        if (node is Map<String, dynamic>) {
          if (node['simpleText'] is String) return node['simpleText'] as String;
          final runs = node['runs'];
          if (runs is List) return runs.map((r) => r is Map ? (r['text'] ?? '').toString() : '').join();
        }
        return '';
      }

      int parseDur(String formatted) {
        final parts = formatted.split(':').map((p) => int.tryParse(p) ?? 0).toList();
        if (parts.length == 2) return parts[0] * 60 + parts[1];
        if (parts.length == 3) return parts[0] * 3600 + parts[1] * 60 + parts[2];
        return 0;
      }

      void walk(dynamic node) {
        if (ids.length >= 5) return;
        if (node is Map<String, dynamic>) {
          if (node['videoRenderer'] is Map<String, dynamic>) {
            final vr = node['videoRenderer'] as Map<String, dynamic>;
            final vid = vr['videoId']?.toString() ?? '';
            final candTitle = _stripParentheticalAndEntities(extractText(vr['title'])).toLowerCase();
            final candDur = parseDur(extractText(vr['lengthText']));
            if (ArtworkService.isYouTubeVideoId(vid) && !seen.contains(vid)) {
              if ((candDur == 0 || candDur > 45) &&
                  (durationSeconds == null || durationSeconds <= 0 || candDur == 0 || (candDur - durationSeconds).abs() <= 40) &&
                  (coreTokens.isEmpty || coreTokens.every((ct) => _tokenMatchesText(ct, candTitle)))) {
                seen.add(vid);
                ids.add(vid);
              }
            }
          }
          for (final v in node.values) {
            walk(v);
          }
        } else if (node is List) {
          for (final item in node) {
            walk(item);
          }
        }
      }

      walk(data);
      return ids;
    } catch (_) {
      return const [];
    }
  }

  /// Extracts exact YouTube video audio via official YouTube Android VR client
  static Future<AudioStreamResult?> _extractFromAndroidVr(String videoId) async {
    final uri = Uri.parse('https://www.youtube.com/youtubei/v1/player?prettyPrint=false');
    const vrUserAgent =
        'com.google.android.apps.youtube.vr.oculus/1.60.19 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip';

    final payload = {
      'context': {
        'client': {
          'clientName': 'ANDROID_VR',
          'clientVersion': '1.60.19',
          'deviceMake': 'Oculus',
          'deviceModel': 'Quest 3',
          'osName': 'Android',
          'osVersion': '12L',
          'androidSdkVersion': 32,
          'hl': 'en',
          'gl': 'US',
          'utcOffsetMinutes': 0,
        },
      },
      'videoId': videoId,
    };

    final res = await _postWithRetry(
      uri,
      headers: const {
        'Content-Type': 'application/json',
        'User-Agent': vrUserAgent,
        'X-YouTube-Client-Name': '28',
        'X-YouTube-Client-Version': '1.60.19',
        'Accept': '*/*',
      },
      body: jsonEncode(payload),
      timeout: const Duration(milliseconds: 2200),
      retries: 0,
    );

    if (res == null || res.statusCode != 200) return null;

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final playStatus = (data['playabilityStatus'] as Map<String, dynamic>?)?['status'];
    if (playStatus != 'OK') return null;

    final streamingData = data['streamingData'] as Map<String, dynamic>?;
    if (streamingData == null) return null;

    return _pickBestAudioFormat(
      streamingData,
      headers: const {
        'User-Agent': vrUserAgent,
      },
      clientName: 'Android VR',
    );
  }

  /// Extracts audio via official YouTube iOS App client
  static Future<AudioStreamResult?> _extractFromIosApp(String videoId) async {
    final uri = Uri.parse('https://www.youtube.com/youtubei/v1/player?prettyPrint=false');

    final payload = {
      'context': {
        'client': {
          'clientName': 'IOS',
          'clientVersion': '20.03.02',
          'deviceMake': 'Apple',
          'deviceModel': 'iPhone16,2',
          'osName': 'iOS',
          'osVersion': '18.2.1.22C161',
          'hl': 'en',
          'gl': 'US',
          'utcOffsetMinutes': 0,
        },
      },
      'videoId': videoId,
    };

    final res = await _postWithRetry(
      uri,
      headers: _iosAppHeaders,
      body: jsonEncode(payload),
      timeout: const Duration(milliseconds: 2200),
      retries: 0,
    );

    if (res == null || res.statusCode != 200) return null;

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final playStatus = (data['playabilityStatus'] as Map<String, dynamic>?)?['status'];
    if (playStatus != 'OK') return null;

    final streamingData = data['streamingData'] as Map<String, dynamic>?;
    if (streamingData == null) return null;

    return _pickBestAudioFormat(
      streamingData,
      headers: const {
        'User-Agent': 'com.google.ios.youtube/20.03.02 (iPhone16,2; U; CPU iOS 18_2_1 like Mac OS X; en_US)',
      },
      clientName: 'iOS App',
    );
  }

  /// Extracts audio via Mobile Web InnerTube client
  static Future<AudioStreamResult?> _extractFromMweb(String videoId) async {
    final uri = Uri.parse('https://www.youtube.com/youtubei/v1/player?prettyPrint=false');

    final payload = {
      'context': {
        'client': {
          'clientName': 'MWEB',
          'clientVersion': '2.20240920.01.00',
          'hl': 'en',
          'gl': 'US',
          'utcOffsetMinutes': 0,
        },
      },
      'videoId': videoId,
    };

    final res = await _postWithRetry(
      uri,
      headers: _mwebHeaders,
      body: jsonEncode(payload),
      timeout: const Duration(milliseconds: 2200),
      retries: 0,
    );

    if (res == null || res.statusCode != 200) return null;

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final playStatus = (data['playabilityStatus'] as Map<String, dynamic>?)?['status'];
    if (playStatus != 'OK') return null;

    final streamingData = data['streamingData'] as Map<String, dynamic>?;
    if (streamingData == null) return null;

    return _pickBestAudioFormat(
      streamingData,
      headers: const {
        'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1',
      },
      clientName: 'MWEB',
    );
  }

  /// Extracts unthrottled audio stream via public Invidious / Piped instances concurrently
  static Future<AudioStreamResult?> _extractFromInvidious(String videoId) async {
    Future<AudioStreamResult?> queryInstance(String inst) async {
      try {
        final isPiped = inst.contains('piped');
        final uri = Uri.parse(
          isPiped ? '$inst/streams/$videoId' : '$inst/api/v1/videos/$videoId',
        );
        final res = await _getWithRetry(
          uri,
          headers: const {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
          timeout: const Duration(milliseconds: 1800),
          retries: 0,
        );

        if (res == null || res.statusCode != 200) return null;
        final trimmed = res.body.trimLeft();
        if (!trimmed.startsWith('{')) return null;

        final dynamic decoded = jsonDecode(trimmed);
        if (decoded is! Map<String, dynamic>) return null;

        if (isPiped) {
          final audioStreams = (decoded['audioStreams'] as List? ?? [])
              .whereType<Map<String, dynamic>>()
              .toList();
          if (audioStreams.isEmpty) return null;
          audioStreams.sort((a, b) {
            final mA = (a['mimeType'] ?? '').toString().toLowerCase();
            final mB = (b['mimeType'] ?? '').toString().toLowerCase();
            final mp4A = mA.contains('mp4') || mA.contains('m4a');
            final mp4B = mB.contains('mp4') || mB.contains('m4a');
            if (mp4A && !mp4B) return -1;
            if (!mp4A && mp4B) return 1;
            final bitA = (a['bitrate'] as num?)?.toInt() ?? 0;
            final bitB = (b['bitrate'] as num?)?.toInt() ?? 0;
            return bitB.compareTo(bitA);
          });
          for (final audio in audioStreams) {
            final url = audio['url'] as String?;
            if (url != null && url.isNotEmpty) {
              final clen = (audio['contentLength'] as num?)?.toInt() ?? 0;
              final bitrate = (audio['bitrate'] as num?)?.toInt() ?? 128000;
              final mime = (audio['mimeType'] as String? ?? 'audio/mp4').split(';').first;
              return AudioStreamResult(
                url: url,
                totalBytes: clen,
                mimeType: mime,
                bitrate: bitrate,
                headers: const {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
                isDirectDownloadable: true,
              );
            }
          }
          return null;
        }

        final adaptive = (decoded['adaptiveFormats'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();

        final audios = adaptive.where((f) {
          final type = (f['type'] ?? '').toString().toLowerCase();
          return type.contains('audio');
        }).toList();

        if (audios.isEmpty) return null;

        audios.sort((a, b) {
          final typeA = (a['type'] ?? '').toString().toLowerCase();
          final typeB = (b['type'] ?? '').toString().toLowerCase();
          final isMp4A = typeA.contains('mp4') || typeA.contains('m4a');
          final isMp4B = typeB.contains('mp4') || typeB.contains('m4a');
          if (isMp4A && !isMp4B) return -1;
          if (!isMp4A && isMp4B) return 1;

          final bitA = int.tryParse(a['bitrate']?.toString() ?? '0') ?? 0;
          final bitB = int.tryParse(b['bitrate']?.toString() ?? '0') ?? 0;
          return bitB.compareTo(bitA);
        });

        for (final audio in audios) {
          final url = audio['url'] as String?;
          if (url != null && url.isNotEmpty) {
            final clen = int.tryParse(audio['clen']?.toString() ?? '') ?? 0;
            final bitrate = int.tryParse(audio['bitrate']?.toString() ?? '') ?? 128000;
            final mime = (audio['type'] as String? ?? 'audio/mp4').split(';').first;

            return AudioStreamResult(
              url: url,
              totalBytes: clen,
              mimeType: mime,
              bitrate: bitrate,
              headers: const {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
              },
              isDirectDownloadable: true,
            );
          }
        }
      } catch (_) {}
      return null;
    }

    return _firstNonNull(
      _invidiousInstances.map(queryInstance).toList(),
      const Duration(milliseconds: 2200),
    );
  }

  /// Extracts audio stream via YouTube TV Embedded Player InnerTube endpoint.
  static Future<AudioStreamResult?> _extractFromTvEmbedded(String videoId) async {
    final uri = Uri.parse(
        'https://www.youtube.com/youtubei/v1/player?key=$_tvApiKey&prettyPrint=false');

    final payload = {
      'context': {
        'client': {
          'clientName': 'TVHTML5_SIMPLY_EMBEDDED_PLAYER',
          'clientVersion': '2.0',
          'hl': 'en',
          'gl': 'US',
          'utcOffsetMinutes': 0,
        },
        'thirdParty': {
          'embedUrl': 'https://www.youtube.com/',
        },
      },
      'videoId': videoId,
      'playbackContext': {
        'contentPlaybackContext': {
          'html5Preference': 'HTML5_PREF_WANTS',
        },
      },
    };

    final res = await _postWithRetry(
      uri,
      headers: _tvHeaders,
      body: jsonEncode(payload),
      timeout: const Duration(milliseconds: 2200),
      retries: 0,
    );

    if (res == null || res.statusCode != 200) return null;

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final playStatus = (data['playabilityStatus'] as Map<String, dynamic>?)?['status'];
    if (playStatus != 'OK') return null;

    final streamingData = data['streamingData'] as Map<String, dynamic>?;
    if (streamingData == null) return null;

    return _pickBestAudioFormat(
      streamingData,
      headers: const {
        'User-Agent': 'Mozilla/5.0 (SMART-TV; Linux; Tizen 6.0) AppleWebKit/538.1 (KHTML, like Gecko) Version/6.0 TV Safari/538.1',
        'Referer': 'https://www.youtube.com/',
        'Origin': 'https://www.youtube.com',
      },
      clientName: 'TV Embedded',
    );
  }

  /// Extracts audio via Android Music client
  static Future<AudioStreamResult?> _extractFromAndroidMusic(String videoId) async {
    final uri = Uri.parse('https://www.youtube.com/youtubei/v1/player?prettyPrint=false');

    final payload = {
      'context': {
        'client': {
          'clientName': 'ANDROID_MUSIC',
          'clientVersion': '7.27.52',
          'androidSdkVersion': 34,
          'hl': 'en',
          'gl': 'US',
          'utcOffsetMinutes': 0,
        },
      },
      'videoId': videoId,
    };

    final res = await _postWithRetry(
      uri,
      headers: _androidMusicHeaders,
      body: jsonEncode(payload),
      timeout: const Duration(milliseconds: 2200),
      retries: 0,
    );

    if (res == null || res.statusCode != 200) return null;

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final playStatus = (data['playabilityStatus'] as Map<String, dynamic>?)?['status'];
    if (playStatus != 'OK') return null;

    final streamingData = data['streamingData'] as Map<String, dynamic>?;
    if (streamingData == null) return null;

    return _pickBestAudioFormat(
      streamingData,
      headers: const {
        'User-Agent': 'com.google.android.apps.youtube.music/7.27.52 (Linux; U; Android 14) gzip',
      },
      clientName: 'Android Music',
    );
  }

  /// Extracts audio via official YouTube Android App client
  static Future<AudioStreamResult?> _extractFromAndroidApp(String videoId) async {
    final uri = Uri.parse('https://www.youtube.com/youtubei/v1/player?prettyPrint=false');

    final payload = {
      'context': {
        'client': {
          'clientName': 'ANDROID',
          'clientVersion': '20.10.38',
          'androidSdkVersion': 34,
          'hl': 'en',
          'gl': 'US',
          'utcOffsetMinutes': 0,
        },
      },
      'videoId': videoId,
    };

    final res = await _postWithRetry(
      uri,
      headers: _androidAppHeaders,
      body: jsonEncode(payload),
      timeout: const Duration(milliseconds: 2200),
      retries: 0,
    );

    if (res == null || res.statusCode != 200) return null;

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final playStatus = (data['playabilityStatus'] as Map<String, dynamic>?)?['status'];
    if (playStatus != 'OK') return null;

    final streamingData = data['streamingData'] as Map<String, dynamic>?;
    if (streamingData == null) return null;

    return _pickBestAudioFormat(
      streamingData,
      headers: const {
        'User-Agent': 'com.google.android.youtube/20.10.38 (Linux; U; Android 14) gzip',
      },
      clientName: 'Android App',
    );
  }

  /// Picks the best audio format from a streamingData map.
  static AudioStreamResult? _pickBestAudioFormat(
    Map<String, dynamic> streamingData, {
    required Map<String, String> headers,
    required String clientName,
  }) {
    final adaptiveFormats = [
      ...(streamingData['adaptiveFormats'] as List? ?? []),
      ...(streamingData['formats'] as List? ?? []),
    ].whereType<Map<String, dynamic>>().toList();

    final audioFormats = adaptiveFormats.where((f) {
      final mime = f['mimeType']?.toString().toLowerCase() ?? '';
      return mime.contains('audio');
    }).toList();

    if (audioFormats.isEmpty) return null;

    audioFormats.sort((a, b) {
      final mimeA = a['mimeType']?.toString().toLowerCase() ?? '';
      final mimeB = b['mimeType']?.toString().toLowerCase() ?? '';
      final isMp4A = mimeA.contains('mp4') || mimeA.contains('m4a');
      final isMp4B = mimeB.contains('mp4') || mimeB.contains('m4a');
      if (isMp4A && !isMp4B) return -1;
      if (!isMp4A && isMp4B) return 1;
      final bitA = (a['bitrate'] as num?)?.toInt() ?? 0;
      final bitB = (b['bitrate'] as num?)?.toInt() ?? 0;
      return bitB.compareTo(bitA);
    });

    for (final f in audioFormats) {
      final streamUrl = f['url'] as String?;
      if (streamUrl != null && streamUrl.isNotEmpty) {
        final clen = int.tryParse(f['contentLength']?.toString() ?? '0') ?? 0;
        final mime = f['mimeType']?.toString().split(';').first ?? 'audio/mp4';
        final bitrate = (f['bitrate'] as num?)?.toInt() ?? 128000;
        return AudioStreamResult(
          url: streamUrl,
          totalBytes: clen,
          mimeType: mime,
          bitrate: bitrate,
          headers: headers,
          isDirectDownloadable: false,
        );
      }
    }

    return null;
  }

  static String? _resolveQuranSurahDirectUrl(
    String? rawTitle,
    String? rawArtist, {
    bool useMirror = false,
  }) {
    final combined = '${rawTitle ?? ''} ${rawArtist ?? ''}'.trim();
    if (combined.isEmpty) return null;

    final isQuranContext = RegExp(
      r'\b(?:surah|sura|surat|quran|quraan|koran|tilawat|telawat|recitation|murattal|qari|sheikh|shaikh|alafasy|sudais|abdul\s*basit|muaiqly|ghamdi|dosari|hussary|minshawi|baqarah?|bakarah?)\b|سورة|القرآن|সুরা|সূরা|বাকারা|কুরআন|তিলাওয়াত|তিলাওয়াত',
      caseSensitive: false,
    ).hasMatch(combined);
    if (!isQuranContext) return null;

    final isExplicitFullSurah = RegExp(r'\b(?:full|complete|1\s*[-–to]+\s*286)\b|كاملة', caseSensitive: false).hasMatch(combined);
    if (!isExplicitFullSurah &&
        (RegExp(r'\b(?:ayat|ayah|verse|verses|part|pt\.?)\s*\d+', caseSensitive: false).hasMatch(combined) ||
            RegExp(r'\b(?:urdu|english|hindi|bangla)\s+translation\b', caseSensitive: false).hasMatch(combined))) {
      return null;
    }

    final patterns = <MapEntry<String, RegExp>>[
      MapEntry('001', RegExp(r'\b(?:al[-\s]?)?(?:fatihah?|fateha)\b|الفاتحة|ফাতিহা', caseSensitive: false)),
      MapEntry('002', RegExp(r'\b(?:al[-\s]?)?(?:baqarah?|bakarah?|baqra|bakra)\b|البقرة|বাকারা', caseSensitive: false)),
      MapEntry('003', RegExp(r'\b(?:aal|al|ali)[-\s]?(?:e[-\s]?)?imran\b|آل عمران|ইমরান', caseSensitive: false)),
      MapEntry('018', RegExp(r'\b(?:al[-\s]?)?kahf\b|الكهف|কাহফ', caseSensitive: false)),
      MapEntry('019', RegExp(r'\bmaryam\b|مريم|মারইয়াম', caseSensitive: false)),
      MapEntry('036', RegExp(r'\b(?:ya[-\s]?sin|yaseen|yasin)\b|يس|ইয়াসিন|ইয়াসিন', caseSensitive: false)),
      MapEntry('055', RegExp(r'\b(?:ar[-\s]?|al[-\s]?)?rahman\b|الرحمن|রহমান', caseSensitive: false)),
      MapEntry('056', RegExp(r"\b(?:al[-\s]?)?(?:waqiah?|wakiah?|waqi'ah?)\b|الواقعة|ওয়াকিয়া|ওয়াকিয়া", caseSensitive: false)),
      MapEntry('067', RegExp(r'\b(?:al[-\s]?)?mulk\b|الملك|মুলক', caseSensitive: false)),
      MapEntry('073', RegExp(r'\b(?:al[-\s]?)?muz+am+il\b|المزمل|মুজাম্মিল', caseSensitive: false)),
      MapEntry('078', RegExp(r'\b(?:an[-\s]?|al[-\s]?)?naba\b|النبأ|নাবা', caseSensitive: false)),
      MapEntry('087', RegExp(r"\b(?:al[-\s]?)?a'?la\b|الأعلى", caseSensitive: false)),
      MapEntry('093', RegExp(r'\b(?:ad[-\s]?|al[-\s]?)?(?:duha|dhuha)\b|الضحى', caseSensitive: false)),
      MapEntry('097', RegExp(r'\b(?:al[-\s]?)?qadr\b|القدر|কদর', caseSensitive: false)),
      MapEntry('108', RegExp(r'\b(?:al[-\s]?)?(?:kawthar|kausar)\b|الكوثر|কাউসার', caseSensitive: false)),
      MapEntry('109', RegExp(r'\b(?:al[-\s]?)?kafirun\b|الكافرون', caseSensitive: false)),
      MapEntry('112', RegExp(r'\b(?:al[-\s]?)?ikhlas\b|الإخلاص|ইখলাস', caseSensitive: false)),
      MapEntry('113', RegExp(r'\b(?:al[-\s]?)?falaq\b|الفلق|ফালাক', caseSensitive: false)),
      MapEntry('114', RegExp(r'\b(?:an[-\s]?|al[-\s]?)?(?:nas|naas)\b|الناس|নাস', caseSensitive: false)),
    ];

    String? surahNum;
    for (final entry in patterns) {
      if (entry.value.hasMatch(combined)) {
        surahNum = entry.key;
        break;
      }
    }
    if (surahNum == null) {
      final numMatch = RegExp(r'\b(?:surah|sura|surat)\s*#?\s*(\d{1,3})\b', caseSensitive: false).firstMatch(combined);
      if (numMatch != null) {
        final parsed = int.tryParse(numMatch.group(1) ?? '') ?? 0;
        if (parsed >= 1 && parsed <= 114) {
          surahNum = parsed.toString().padLeft(3, '0');
        }
      }
    }
    if (surahNum == null) return null;

    final lower = combined.toLowerCase();
    if (RegExp(r'sudais|sudays').hasMatch(lower)) {
      return useMirror
          ? 'https://server11.mp3quran.net/sds/$surahNum.mp3'
          : 'https://download.quranicaudio.com/quran/abdurrahmaan_as-sudays/$surahNum.mp3';
    }
    if (RegExp(r'abdul\s*basit|abd\s*al\s*basit').hasMatch(lower)) {
      return useMirror
          ? 'https://server7.mp3quran.net/basit/$surahNum.mp3'
          : 'https://download.quranicaudio.com/quran/abdul_basit_murattal/$surahNum.mp3';
    }
    if (RegExp(r'maher|muaiqly|muayqali').hasMatch(lower)) {
      return useMirror
          ? 'https://download.quranicaudio.com/quran/maher_256/$surahNum.mp3'
          : 'https://server12.mp3quran.net/maher/$surahNum.mp3';
    }
    if (RegExp(r'yasser|dosari|dossari').hasMatch(lower)) {
      return useMirror
          ? 'https://download.quranicaudio.com/quran/yasser_ad-dussary/$surahNum.mp3'
          : 'https://server11.mp3quran.net/yasser/$surahNum.mp3';
    }
    if (RegExp(r'ghamdi|ghamidi').hasMatch(lower)) {
      return useMirror
          ? 'https://server7.mp3quran.net/s_gmd/$surahNum.mp3'
          : 'https://download.quranicaudio.com/quran/sa3d_al-ghaamidi/complete/$surahNum.mp3';
    }
    return useMirror
        ? 'https://server8.mp3quran.net/afs/$surahNum.mp3'
        : 'https://download.quranicaudio.com/quran/mishaari_raashid_al_3afaasee/$surahNum.mp3';
  }
}
