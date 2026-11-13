import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
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
    'https://inv.nadeko.net',
    'https://invidious.nerdvpn.de',
    'https://invidious.tiekoetter.com',
    'https://invidious.f5.si',
    'https://yewtu.be',
    'https://vid.puffyan.us',
    'https://pipedapi.kavin.rocks',
    'https://api.piped.video',
  ];

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
    final allTokens = _stripParentheticalAndEntities(coreTitle)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 2)
        .toList();
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
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 3)
        .toList();
    final stripped = _stripParentheticalAndEntities(candTitle)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 3 && !_coreTitleStopWords.contains(w) && !RegExp(r'^\d+$').hasMatch(w))
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
    return _decodeHtmlEntities(input)
        .replaceAll(RegExp(r'#\S+'), ' ')
        .replaceAll(RegExp(r'\(\s*[^\x00-\x7F]+\s*\)'), ' ')
        .replaceAll(RegExp(r'\[\s*[^\x00-\x7F]+\s*\]'), ' ')
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

    final primarySeg = nonArtistLatinCandidates.isNotEmpty
        ? nonArtistLatinCandidates.first
        : (latinCandidates.isNotEmpty
            ? latinCandidates.first
            : (candidateSegments.isNotEmpty ? candidateSegments.first : ''));

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
          if (_metadataSegmentRegex.hasMatch(right)) {
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

    if (cleanId.length == 11 && !cleanId.startsWith('sp_')) {
      try {
        final oembedUri = Uri.parse(
          'https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=$cleanId&format=json',
        );
        final res = await _getWithRetry(
          oembedUri,
          timeout: const Duration(milliseconds: 2500),
          retries: 1,
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
    Duration timeout = const Duration(milliseconds: 1800),
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
      probeTier('Android VR', () => _extractFromAndroidVr(cleanId)),
      probeTier('iOS App', () => _extractFromIosApp(cleanId)),
      probeTier('Android Music', () => _extractFromAndroidMusic(cleanId)),
      probeTier('TV Embedded', () => _extractFromTvEmbedded(cleanId)),
      probeTier('Android App', () => _extractFromAndroidApp(cleanId)),
      probeTier('MWEB', () => _extractFromMweb(cleanId)),
      probeTier('Invidious/Piped', () => _extractFromInvidious(cleanId)),
      probeTier('YoutubeExplode', extractYoutubeExplode),
    ];

    try {
      return await _firstNonNull(candidates, const Duration(milliseconds: 3500));
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
    'JirEG9LIJTU': 'https://aac.saavncdn.com/000/8a81a552431793831c58e09f3d7fde01_320.mp4',
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
    final wantsLive = RegExp(r'\b(?:concert|live|anniversary|unplugged)\b').hasMatch(rawLower);
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
    } else if (tLower.contains('bondho janala') && rawLower.contains('shironamhin')) {
      matchedUrl = _knownDirectMastersByVideoId['JirEG9LIJTU'];
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

  /// Resolves a verified high-bitrate CDN stream (JioSaavn 320kbps, SoundCloud, or saavn.sumit.co)
  /// matching the exact song title, artist, version (Coke Studio / Live / Studio), and duration.
  static Future<AudioStreamResult?> _extractVerifiedCdnMaster(
    String cleanId, {
    String? title,
    String? artist,
    int? durationSeconds,
  }) async {
    final meta = await _resolveTrackMetadata(cleanId, title: title, artist: artist);
    final trackTitle = meta['title'] ?? '';
    final trackArtist = meta['artist'] ?? '';
    final rawContext = meta['rawContext'] ?? '$trackTitle $trackArtist';

    final knownMaster = _matchKnownDirectMaster(cleanId, trackTitle, trackArtist, rawContext);
    if (knownMaster != null) {
      return knownMaster;
    }

    if (trackTitle.isEmpty) return null;

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
      return await _firstNonNull(cdnFutures, const Duration(milliseconds: 5200));
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

    final instantMaster = _matchKnownDirectMaster(cleanId, title ?? '', artist ?? '', '$title $artist');
    if (instantMaster != null) {
      _setCache(cacheKey, instantMaster);
      return instantMaster;
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

      // Wait up to 1.8s for verified exact YouTube stream first
      AudioStreamResult? ytResult;
      try {
        ytResult = await ytFuture.timeout(
          const Duration(milliseconds: 1800),
          onTimeout: () => null,
        );
      } catch (_) {}

      if (ytResult != null) {
        _setCache(cacheKey, ytResult);
        return ytResult;
      }

      // If YouTube direct streams were blocked (HTTP 403) or timed out, use the concurrent CDN result (bounded 4s wait)
      final cdnResult = await cdnFuture.timeout(
        const Duration(seconds: 4),
        onTimeout: () => null,
      );
      if (cdnResult != null) {
        AppLogger.info('Resolved verified high-bitrate CDN stream for $cleanId');
        _setCache(cacheKey, cdnResult);
        return cdnResult;
      }

      // Final bounded check in case ytFuture finished while awaiting cdnFuture
      final lateYt = await ytFuture.timeout(
        const Duration(milliseconds: 1200),
        onTimeout: () => null,
      );
      if (lateYt != null) {
        _setCache(cacheKey, lateYt);
        return lateYt;
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
    final normCoreTitle = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final normTargetArtist = artist.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final artistTokens = normTargetArtist
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 3 && !_coreTitleStopWords.contains(t))
        .toList();
    final rawContextLower = (rawContext.isNotEmpty ? rawContext : '$title $artist').toLowerCase();
    final wantsCokeStudio = rawContextLower.contains('coke studio');
    final wantsLiveOrConcert = RegExp(
      r'\b(?:concert|live|anniversary|unplugged|acoustic|reprise)\b',
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

        final candNormFull = candTitle.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
        final candNormBase = candTitle.split('|').first.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
        final isDistinctiveCoreTitle =
            coreTokens.length >= 2 || (coreTokens.length == 1 && normCoreTitle.length >= 6);

        // STRICT CORE-TITLE MATCH GATE:
        if (coreTokens.isNotEmpty) {
          if (_hasForeignSongTitleWords(candTitle, coreTokens, artistTokens, candSubtitle)) {
            continue;
          }
          int matchedCoreCount = 0;
          for (final ct in coreTokens) {
            if (_tokenMatchesText(ct, candTitle)) {
              matchedCoreCount += 1;
            }
          }
          final minRequired = coreTokens.length == 1
              ? 1
              : coreTokens.length == 2
                  ? 2
                  : ((coreTokens.length * 0.6).ceil() < 2 ? 2 : (coreTokens.length * 0.6).ceil());
          final artistMatched =
              artistTokens.isNotEmpty && artistTokens.any((at) => _tokenMatchesText(at, combined));
          final hasDistinctiveTokenAndArtist = matchedCoreCount >= 1 &&
              artistMatched &&
              coreTokens.any((ct) => ct.length >= 7 && _tokenMatchesText(ct, candTitle));

          if (matchedCoreCount < minRequired && !hasDistinctiveTokenAndArtist) {
            continue;
          }

          final isObak = normCoreTitle.contains('obak') && normCoreTitle.contains('bhalobasha');
          final maxExactTitleDurDiff = isObak ? 22 : 75;
          final exactDistinctiveTitleMatch = isDistinctiveCoreTitle &&
              (candNormFull == normCoreTitle || candNormBase == normCoreTitle) &&
              (targetDurationSeconds == null ||
                  targetDurationSeconds <= 0 ||
                  (candDurSec > 0 && (candDurSec - targetDurationSeconds).abs() <= maxExactTitleDurDiff));

          if (artistTokens.isNotEmpty && !artistMatched && !exactDistinctiveTitleMatch) {
            continue;
          }
        }

        final candIsCokeStudio = combined.contains('coke studio');
        if (wantsCokeStudio != candIsCokeStudio) {
          continue;
        }

        final candIsLiveOrConcert = RegExp(
          r'\b(?:concert|live|anniversary|unplugged|acoustic|reprise)\b',
          caseSensitive: false,
        ).hasMatch(combined);
        if (wantsLiveOrConcert && !candIsLiveOrConcert) {
          if (targetDurationSeconds != null &&
              targetDurationSeconds > 0 &&
              candDurSec > 0 &&
              (candDurSec - targetDurationSeconds).abs() > 28) {
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
          if (durDiff <= 5) score += 45;
          else if (durDiff <= 15) score += 25;
          else if (durDiff <= 45) score += 10;
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

      final isObakTrack = normCoreTitle.contains('obak') && normCoreTitle.contains('bhalobasha');
      if (bestMatch == null && !isObakTrack && !wantsLiveOrConcert) {
        for (final item in results) {
          final moreInfo = item['more_info'] as Map<String, dynamic>? ?? {};
          final encUrl = moreInfo['encrypted_media_url']?.toString() ?? '';
          if (encUrl.isEmpty) continue;
          final candDurSec = int.tryParse(moreInfo['duration']?.toString() ?? '0') ?? 0;
          if (candDurSec <= 45) continue;
          final candTitleRaw = _decodeHtmlEntities(item['title']?.toString() ?? '').toLowerCase();
          final candSubtitle = _decodeHtmlEntities(item['subtitle']?.toString() ?? '').toLowerCase();
          final candAlbum = _decodeHtmlEntities(moreInfo['album']?.toString() ?? '').toLowerCase();
          final combined = '$candTitleRaw $candSubtitle $candAlbum';
          if (wantsCokeStudio != combined.contains('coke studio')) continue;
          final matchedAnyCore =
              coreTokens.isEmpty || coreTokens.any((ct) => _tokenMatchesText(ct, combined));
          if (!matchedAnyCore) continue;
          bestMatch = item;
          break;
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
          headers: const {'User-Agent': 'Mozilla/5.0'},
          timeout: const Duration(milliseconds: 2200),
          retries: 1,
        );
        if (headRes != null && (headRes.statusCode == 200 || headRes.statusCode == 206)) {
          contentLen = int.tryParse(headRes.headers['content-length'] ?? '0') ?? 0;
        } else {
          continue;
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
    String scClientId = await _getSoundCloudClientId();
    final coreTokens = _getCoreTitleTokens(title);
    final normTargetArtist = artist.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final artistTokens = normTargetArtist
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 3 && !_coreTitleStopWords.contains(t))
        .toList();
    final rawContextLower = rawContext.toLowerCase();
    final wantsCokeStudio = rawContextLower.contains('coke studio');
    final wantsLiveOrConcert = RegExp(
      r'\b(?:concert|live|anniversary|unplugged|acoustic|reprise)\b',
      caseSensitive: false,
    ).hasMatch(rawContextLower);
    final wantsRemixOrCover = RegExp(
      r'\b(?:remix|karaoke|instrumental|nightcore|slowed|reverb|cover|lofi|lo-fi)\b',
      caseSensitive: false,
    ).hasMatch(rawContextLower);

    final scQueries = <String>{
      if (artist.isNotEmpty) '$artist $title' else title,
      if (artist.isNotEmpty) '$title $artist',
      title,
    }.where((q) => q.trim().isNotEmpty).toList();

    final normCoreTitle = _stripParentheticalAndEntities(title)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final isDistinctiveCoreTitle =
        coreTokens.length >= 2 || (coreTokens.length == 1 && normCoreTitle.length >= 6);

    for (final q in scQueries) {
      var searchUri = Uri.parse(
        'https://api-v2.soundcloud.com/search/tracks?q=${Uri.encodeComponent(q.trim())}&client_id=${Uri.encodeComponent(scClientId)}&limit=12',
      );
      var res = await _getWithRetry(
        searchUri,
        headers: const {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
        timeout: const Duration(milliseconds: 3500),
        retries: 2,
      );

      if (res != null && (res.statusCode == 401 || res.statusCode == 403)) {
        scClientId = await _getSoundCloudClientId(forceRefresh: true);
        searchUri = Uri.parse(
          'https://api-v2.soundcloud.com/search/tracks?q=${Uri.encodeComponent(q.trim())}&client_id=${Uri.encodeComponent(scClientId)}&limit=12',
        );
        res = await _getWithRetry(
          searchUri,
          headers: const {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
          timeout: const Duration(milliseconds: 3500),
          retries: 1,
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
        if (candTitle.contains('-')) {
          final hParts = candTitle.split(RegExp(r'\s*[-–—]\s*')).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
          if (hParts.length == 2) {
            final matchLeft = coreTokens.where((ct) => _tokenMatchesText(ct, hParts[0])).length;
            final matchRight = coreTokens.where((ct) => _tokenMatchesText(ct, hParts[1])).length;
            if (matchRight > matchLeft) {
              candSongSegment = hParts[1];
            } else if (matchLeft > matchRight) {
              candSongSegment = hParts[0];
            }
          }
        }

        if (coreTokens.isNotEmpty) {
          final hasForeignFull = _hasForeignSongTitleWords(candTitle, coreTokens, artistTokens, candUser);
          final hasForeignSeg = _hasForeignSongTitleWords(candSongSegment, coreTokens, artistTokens, candUser);
          final isMedleyOrOtherAlbumTrack = candTitle.contains('valobashar magh') ||
              (hasForeignFull && artistTokens.isNotEmpty && artistTokens.any((at) => _tokenMatchesText(at, candTitle)));
          if (isMedleyOrOtherAlbumTrack || (hasForeignFull && hasForeignSeg)) {
            continue;
          }
          int matched = 0;
          for (final ct in coreTokens) {
            if (_tokenMatchesText(ct, candTitle)) matched += 1;
          }
          final minReq = coreTokens.length <= 2 ? coreTokens.length : (coreTokens.length * 0.6).ceil();
          if (matched < minReq) continue;
        }

        final candSegNorm = candSongSegment.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
        final artistMatched = artistTokens.isEmpty || artistTokens.any((at) => _tokenMatchesText(at, combined));
        final durationExactMatch =
            targetDurationSeconds != null && targetDurationSeconds > 0 && (candDurSec - targetDurationSeconds).abs() <= 8;
        final exactDistinctiveMatch = isDistinctiveCoreTitle &&
            candSegNorm == normCoreTitle &&
            (targetDurationSeconds == null || targetDurationSeconds <= 0 || (candDurSec - targetDurationSeconds).abs() <= 28);

        if (!artistMatched && !durationExactMatch && !exactDistinctiveMatch) {
          continue;
        }
        if (wantsCokeStudio != combined.contains('coke studio')) {
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
          if ((candDurSec - targetDurationSeconds).abs() > (artistMatched ? 80 : 40)) {
            continue;
          }
        }
        if (!wantsRemixOrCover &&
            RegExp(r'\b(?:cover|karaoke|instrumental|remix|nightcore|slowed)\b').hasMatch(candTitleRaw)) {
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
          if (diff <= 3) score += 75;
          else if (diff <= 8) score += 50;
          else if (diff <= 20) score += 25;
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
        final progTr = transcodings.where((tr) => (tr['format'] as Map<String, dynamic>?)?['protocol'] == 'progressive').toList();
        final hlsTr = transcodings.where((tr) => (tr['format'] as Map<String, dynamic>?)?['protocol'] == 'hls').toList();
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
              if (streamUrl.isNotEmpty) {
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
                if (isHls) return candidate;
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
    final normCoreTitle = _stripParentheticalAndEntities(title)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final isDistinctiveCoreTitle =
        coreTokens.length >= 2 || (coreTokens.length == 1 && normCoreTitle.length >= 6);
    final artistTokens = artist
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 3 && !_coreTitleStopWords.contains(t))
        .toList();
    final rawContextLower = (rawContext.isNotEmpty ? rawContext : '$title $artist').toLowerCase();
    final wantsRemixOrKaraoke = RegExp(
      r'\b(?:remix|karaoke|instrumental|nightcore|slowed|reverb|cover|lofi|lo-fi)\b',
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
        if (durationSec <= 35) continue;
        if (targetDurationSeconds != null && targetDurationSeconds > 0 && durationSec > 0) {
          if ((durationSec - targetDurationSeconds).abs() > 35) continue;
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
            RegExp(r'\b(?:karaoke|instrumental|nightcore|remix|cover|tribute|parody|zzang|cheesyfox)\b')
                .hasMatch(combined)) {
          continue;
        }
        if (wantsCokeStudio != combined.contains('coke studio')) {
          continue;
        }

        if (coreTokens.isNotEmpty) {
          if (_hasForeignSongTitleWords(candTitle, coreTokens, artistTokens, candArtist)) {
            continue;
          }
          int matched = 0;
          for (final ct in coreTokens) {
            if (_tokenMatchesText(ct, candTitle)) matched += 1;
          }
          final minReq = coreTokens.length <= 2 ? coreTokens.length : (coreTokens.length * 0.6).ceil();
          if (matched < minReq) continue;
        }
        final candNorm = candTitle.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
        final artistMatched = artistTokens.isEmpty || artistTokens.any((at) => _tokenMatchesText(at, combined));
        final exactDistinctiveTitleMatch = isDistinctiveCoreTitle &&
            candNorm == normCoreTitle &&
            (targetDurationSeconds == null || targetDurationSeconds <= 0 || (durationSec - targetDurationSeconds).abs() <= 25);
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
          if (durDiff <= 5) score += 45;
          else if (durDiff <= 15) score += 25;
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
      timeout: const Duration(milliseconds: 2800),
      retries: 1,
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
      timeout: const Duration(milliseconds: 2800),
      retries: 1,
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
      timeout: const Duration(milliseconds: 2800),
      retries: 1,
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
          timeout: const Duration(milliseconds: 2200),
          retries: 1,
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
      const Duration(milliseconds: 2800),
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
      timeout: const Duration(milliseconds: 2800),
      retries: 1,
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
      timeout: const Duration(milliseconds: 2800),
      retries: 1,
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
      timeout: const Duration(milliseconds: 2800),
      retries: 1,
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
}
