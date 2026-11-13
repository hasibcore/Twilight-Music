import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/logger.dart';
import '../models/song_model.dart';
import '../models/artist_model.dart';
import '../models/playlist_model.dart';
import '../models/search_result_model.dart';

/// Handles fetching music, artists, and playlists from YouTube.
/// Uses direct YouTube search via YoutubeExplode for unlimited A to Z music access,
/// with support for YouTube Data API v3 and live streaming.
class YouTubeRemoteDatasource {
  final http.Client client;
  final String apiKey;
  final YoutubeExplode _yt = YoutubeExplode();

  // In-memory cache to prevent redundant network requests and improve performance (capped to prevent memory growth)
  final Map<String, dynamic> _cache = {};
  static const int _maxCacheSize = 100;

  void _setCache(String key, dynamic value) {
    if (_cache.length >= _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = value;
  }

  YouTubeRemoteDatasource({
    required this.client,
    required this.apiKey,
  });

  /// Checks if the configured API key is valid (not empty and not the default placeholder)
  bool get hasValidApiKey =>
      apiKey.isNotEmpty && !apiKey.contains('YOUR_YOUTUBE_DATA_API_V3_KEY_HERE');

  String _normalizePhoneticQuery(String raw) {
    final q = raw.trim();
    final lower = q.toLowerCase();
    if (lower.contains('obak valo') || lower.contains('obak bhalo')) {
      return 'Obak Bhalobasha Warfaze';
    }
    if (lower.contains('tmi hiyar') ||
        lower.contains('tumi hiyar') ||
        lower.contains('hiyar majh')) {
      return 'Amar Hiyar Majhe';
    }
    return q;
  }

  /// Searches for songs, artists, and playlists across all of YouTube.
  Future<SearchResultModel> searchAll(String query) async {
    final cleanQuery = _normalizePhoneticQuery(query);
    if (cleanQuery.isEmpty) {
      return _getEmptySearchResult();
    }

    final cacheKey = 'search_${cleanQuery.toLowerCase()}';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey] as SearchResultModel;
    }

    // 1. Try official YouTube Data API if user configured a valid key
    if (hasValidApiKey) {
      try {
        final url = Uri.parse(
          '${ApiEndpoints.search}?part=snippet&q=${Uri.encodeComponent(cleanQuery)}&type=video,channel,playlist&maxResults=25&key=$apiKey',
        );
        final response = await client.get(url);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final items = data['items'] as List<dynamic>? ?? [];

          final List<SongModel> songs = [];
          final List<ArtistModel> artists = [];
          final List<PlaylistModel> playlists = [];

          for (final item in items) {
            final id = item['id'] as Map<String, dynamic>? ?? {};
            final kind = id['kind'] as String? ?? '';
            final snippet = item['snippet'] as Map<String, dynamic>? ?? {};

            if (kind.contains('video')) {
              songs.add(SongModel.fromYouTubeJson(item));
            } else if (kind.contains('channel')) {
              artists.add(ArtistModel(
                id: id['channelId'] as String? ?? '',
                name: snippet['title'] as String? ?? 'Artist',
                thumbnailUrl: snippet['thumbnails']?['high']?['url'] as String? ?? '',
              ));
            } else if (kind.contains('playlist')) {
              playlists.add(PlaylistModel(
                id: id['playlistId'] as String? ?? '',
                title: snippet['title'] as String? ?? 'Playlist',
                description: snippet['description'] as String? ?? '',
                thumbnailUrl: snippet['thumbnails']?['high']?['url'] as String? ?? '',
                updatedAt: DateTime.now(),
              ));
            }
          }

          final result = SearchResultModel(
            songs: songs,
            videos: songs,
            artists: artists,
            playlists: playlists,
          );
          _cache[cacheKey] = result;
          return result;
        }
      } catch (e) {
        AppLogger.error('Official YouTube API search error: $e');
      }
    }

    // 2 & 3. Race YoutubeExplode and InnerTube web search concurrently so flaky/blocked endpoints never stall 4s+5s sequentially
    final ytSearchFuture = () async {
      try {
        final searchList = await _yt.search.search(cleanQuery).timeout(const Duration(milliseconds: 3500));
        final List<SongModel> songs = [];
        final List<ArtistModel> artists = [];
        final Set<String> seenArtists = {};
        final Set<String> seenVideoIds = {};

        for (final video in searchList) {
          try {
            if (video.id.value.isEmpty || seenVideoIds.contains(video.id.value)) {
              continue;
            }
            seenVideoIds.add(video.id.value);

            final durationSecs = video.duration?.inSeconds ?? 0;
            final thumb = 'https://i.ytimg.com/vi/${video.id.value}/hqdefault.jpg';

            int views = 0;
            try {
              views = video.engagement.viewCount;
            } catch (_) {}

            DateTime? uploadDate;
            try {
              uploadDate = video.uploadDate;
            } catch (_) {}

            final song = SongModel(
              id: video.id.value,
              title: video.title,
              artist: video.author,
              channelId: video.channelId.value,
              thumbnailUrl: thumb,
              durationSeconds: durationSecs,
              durationFormatted: Formatters.formatDuration(video.duration ?? Duration.zero),
              viewCount: views,
              publishedAt: uploadDate,
            );
            songs.add(song);

            if (video.author.isNotEmpty && !seenArtists.contains(video.author)) {
              seenArtists.add(video.author);
              artists.add(ArtistModel(
                id: video.channelId.value,
                name: video.author,
                thumbnailUrl: thumb,
              ));
            }
          } catch (_) {}
        }

        if (songs.isNotEmpty) {
          return SearchResultModel(
            songs: songs,
            videos: songs,
            artists: artists,
            playlists: [
              PlaylistModel(
                id: 'pl_${cleanQuery.hashCode}',
                title: '$cleanQuery Collection',
                description: 'YouTube music results for $cleanQuery',
                thumbnailUrl: songs.first.thumbnailUrl,
                updatedAt: DateTime.now(),
              ),
            ],
          );
        }
      } catch (e) {
        AppLogger.error('YouTubeExplode live search error: $e');
      }
      return null;
    }();

    final webSearchFuture = _searchWebFallback(cleanQuery);

    final ytRes = await ytSearchFuture;
    if (ytRes != null && ytRes.songs.isNotEmpty) {
      _setCache(cacheKey, ytRes);
      return ytRes;
    }

    final webRes = await webSearchFuture;
    if (webRes.songs.isNotEmpty) {
      _setCache(cacheKey, webRes);
      return webRes;
    }

    // 4. Fallback: Direct JioSaavn catalog search if both YouTube search endpoints are blocked/unreachable
    final saavnRes = await _searchJioSaavnFallback(cleanQuery);
    if (saavnRes.songs.isNotEmpty) {
      _setCache(cacheKey, saavnRes);
      return saavnRes;
    }

    return _getEmptySearchResult();
  }

  /// Fetches trending music videos for the home screen.
  Future<List<SongModel>> getTrendingMusic({String regionCode = 'US'}) async {
    final cacheKey = 'trending_$regionCode';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey] as List<SongModel>;
    }

    if (hasValidApiKey) {
      try {
        final url = Uri.parse(
          '${ApiEndpoints.videos}?part=snippet,contentDetails,statistics&chart=mostPopular&videoCategoryId=10&maxResults=25&regionCode=$regionCode&key=$apiKey',
        );
        final response = await client.get(url).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final items = data['items'] as List<dynamic>? ?? [];
          final songs = items.map((i) => SongModel.fromYouTubeJson(i)).toList();
          _setCache(cacheKey, songs);
          return songs;
        }
      } catch (e) {
        AppLogger.error('Trending fetch error: $e');
      }
    }

    // Race YoutubeExplode and InnerTube web search concurrently for fast startup
    final ytFuture = () async {
      try {
        final searchList = await _yt.search.search('trending music songs').timeout(const Duration(milliseconds: 3200));
        final List<SongModel> songs = [];
        for (final video in searchList.take(25)) {
          try {
            final durSecs = video.duration?.inSeconds ?? 0;
            if (durSecs > 2700) continue; // Skip full-album / >45m DJ compilations from trending singles
            final thumb = 'https://i.ytimg.com/vi/${video.id.value}/hqdefault.jpg';

            int views = 0;
            try {
              views = video.engagement.viewCount;
            } catch (_) {}

            DateTime? uploadDate;
            try {
              uploadDate = video.uploadDate;
            } catch (_) {}

            songs.add(SongModel(
              id: video.id.value,
              title: video.title,
              artist: video.author,
              channelId: video.channelId.value,
              thumbnailUrl: thumb,
              durationSeconds: durSecs,
              durationFormatted: Formatters.formatDuration(video.duration ?? Duration.zero),
              viewCount: views,
              publishedAt: uploadDate,
            ));
          } catch (_) {}
        }
        return songs;
      } catch (e) {
        AppLogger.error('YouTubeExplode trending error: $e');
        return <SongModel>[];
      }
    }();

    final webFuture = _searchWebFallback('trending music songs');

    final ytSongs = await ytFuture;
    if (ytSongs.isNotEmpty) {
      _setCache(cacheKey, ytSongs);
      return ytSongs;
    }

    final webResults = await webFuture;
    final webFiltered = webResults.songs.where((s) => s.durationSeconds <= 2700).toList();
    if (webFiltered.isNotEmpty) {
      _setCache(cacheKey, webFiltered);
      return webFiltered;
    }

    final saavnRes = await _searchJioSaavnFallback('trending hits');
    if (saavnRes.songs.isNotEmpty) {
      _setCache(cacheKey, saavnRes.songs);
      return saavnRes.songs;
    }

    return [];
  }

  /// Fetches exact details for a specific video ID using direct YouTube resolution.
  Future<SongModel?> getVideoDetails(String videoId) async {
    final cleanId = videoId.trim();
    if (cleanId.isEmpty) return null;

    final cacheKey = 'video_$cleanId';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey] as SongModel?;
    }

    try {
      final video = await _yt.videos.get(cleanId);
      final durationSecs = video.duration?.inSeconds ?? 0;
      final thumb = 'https://i.ytimg.com/vi/${video.id.value}/hqdefault.jpg';

      int views = 0;
      try {
        views = video.engagement.viewCount;
      } catch (_) {}

      final song = SongModel(
        id: video.id.value,
        title: video.title,
        artist: video.author,
        channelId: video.channelId.value,
        thumbnailUrl: thumb,
        durationSeconds: durationSecs,
        durationFormatted: Formatters.formatDuration(video.duration ?? Duration.zero),
        viewCount: views,
        publishedAt: video.uploadDate,
      );

      _setCache(cacheKey, song);
      return song;
    } catch (e) {
      AppLogger.error('getVideoDetails error for $cleanId: $e');
    }
    return null;
  }

  /// Fetches songs by genre name.
  Future<List<SongModel>> getMusicByGenre(String genre) async {
    final search = await searchAll('$genre music songs');
    return search.songs;
  }

  Future<SearchResultModel> _searchWebFallback(String query) async {
    try {
      final uri = Uri.parse('https://www.youtube.com/youtubei/v1/search?prettyPrint=false');
      final resp = await client.post(
        uri,
        headers: {
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
      ).timeout(const Duration(seconds: 5));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final songs = <SongModel>[];
        final artists = <ArtistModel>[];
        final seenArtists = <String>{};
        final seenVideoIds = <String>{};

        String? extractText(dynamic node) {
          if (node == null) return null;
          if (node is Map<String, dynamic>) {
            if (node['simpleText'] is String) return node['simpleText'] as String;
            final runs = node['runs'];
            if (runs is List && runs.isNotEmpty) {
              return runs.map((r) => r is Map ? (r['text'] ?? '').toString() : '').join();
            }
          }
          if (node is String) return node;
          return null;
        }

        void extractVideos(dynamic node) {
          if (node is Map<String, dynamic>) {
            if (node.containsKey('videoRenderer')) {
              final vr = node['videoRenderer'] as Map<String, dynamic>;
              final videoId = vr['videoId'] as String?;
              final title = extractText(vr['title']);
              final author = extractText(vr['ownerText']) ?? extractText(vr['shortBylineText']) ?? 'YouTube Artist';
              final durationText = extractText(vr['lengthText']) ?? '03:30';

              if (videoId != null &&
                  title != null &&
                  videoId.length == 11 &&
                  !seenVideoIds.contains(videoId)) {
                seenVideoIds.add(videoId);
                final song = SongModel(
                  id: videoId,
                  title: title,
                  artist: author,
                  channelId: 'yt_$videoId',
                  thumbnailUrl: 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
                  durationSeconds: Formatters.parseFormattedDuration(durationText),
                  durationFormatted: durationText,
                  viewCount: 100000,
                  publishedAt: null,
                );
                songs.add(song);

                if (!seenArtists.contains(author)) {
                  seenArtists.add(author);
                  artists.add(ArtistModel(
                    id: 'channel_$videoId',
                    name: author,
                    thumbnailUrl: 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
                  ));
                }
              }
            }
            for (final val in node.values) {
              extractVideos(val);
            }
          } else if (node is List) {
            for (final item in node) {
              extractVideos(item);
            }
          }
        }

        extractVideos(data);

        if (songs.isNotEmpty) {
          return SearchResultModel(
            songs: songs,
            videos: songs,
            artists: artists,
            playlists: [
              PlaylistModel(
                id: 'pl_${query.hashCode}',
                title: '$query Hits',
                description: 'Search results for $query',
                thumbnailUrl: songs.first.thumbnailUrl,
                updatedAt: DateTime.now(),
              ),
            ],
          );
        }
      }
    } catch (e) {
      AppLogger.error('InnerTube search fallback error: $e');
    }
    return _getEmptySearchResult();
  }

  Future<SearchResultModel> _searchJioSaavnFallback(String query) async {
    // 1. Primary: Official JioSaavn API (direct & Cloudflare-immune)
    try {
      final officialUri = Uri.parse(
        'https://www.jiosaavn.com/api.php?p=1&q=${Uri.encodeComponent(query.trim())}&_format=json&_marker=0&api_version=4&ctx=web6dot0&n=15&__call=search.getResults',
      );
      final offRes = await client
          .get(officialUri, headers: const {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'})
          .timeout(const Duration(milliseconds: 3500));
      if (offRes.statusCode == 200) {
        final offData = jsonDecode(offRes.body);
        if (offData is Map<String, dynamic>) {
          final items = (offData['results'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
          final songs = <SongModel>[];
          final artists = <ArtistModel>[];
          final seenArtists = <String>{};
          for (final item in items) {
            final id = item['id']?.toString() ?? '';
            final title = item['title']?.toString() ?? '';
            final moreInfo = item['more_info'] as Map<String, dynamic>? ?? {};
            final durSec = int.tryParse(moreInfo['duration']?.toString() ?? '0') ?? 0;
            final encUrl = moreInfo['encrypted_media_url']?.toString() ?? '';
            if (id.isEmpty || title.isEmpty || encUrl.isEmpty || durSec <= 35) continue;
            final artistMap = moreInfo['artistMap'] as Map<String, dynamic>? ?? {};
            final primaryList = (artistMap['primary_artists'] as List? ?? [])
                .whereType<Map<String, dynamic>>()
                .toList();
            final subtitle = item['subtitle']?.toString() ?? '';
            final artistName = primaryList.isNotEmpty
                ? primaryList.map((a) => a['name']?.toString() ?? '').where((s) => s.isNotEmpty).join(', ')
                : (subtitle.split(' - ').first.trim().isNotEmpty ? subtitle.split(' - ').first.trim() : 'Artist');
            final rawImg = item['image']?.toString() ?? '';
            final thumb = rawImg.replaceAll(RegExp(r'150x150|50x50'), '500x500');
            songs.add(SongModel(
              id: 'js_$id',
              title: title,
              artist: artistName,
              channelId: 'js_$id',
              thumbnailUrl: thumb,
              durationSeconds: durSec,
              durationFormatted: Formatters.formatDuration(Duration(seconds: durSec)),
              viewCount: int.tryParse(item['play_count']?.toString() ?? '250000') ?? 250000,
              publishedAt: null,
            ));
            if (artistName.isNotEmpty && !seenArtists.contains(artistName)) {
              seenArtists.add(artistName);
              artists.add(ArtistModel(
                id: 'js_art_$id',
                name: artistName,
                thumbnailUrl: thumb,
              ));
            }
          }
          if (songs.isNotEmpty) {
            return SearchResultModel(
              songs: songs,
              videos: songs,
              artists: artists,
              playlists: const [],
            );
          }
        }
      }
    } catch (_) {}

    // 2. Secondary backup: saavn.sumit.co
    try {
      final uri = Uri.parse(
        'https://saavn.sumit.co/api/search/songs?query=${Uri.encodeComponent(query.trim())}&limit=15',
      );
      final res = await client.get(uri).timeout(const Duration(milliseconds: 2800));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          final items = ((data['data'] as Map<String, dynamic>?)?['results'] as List? ?? [])
              .whereType<Map<String, dynamic>>()
              .toList();
          final songs = <SongModel>[];
          final artists = <ArtistModel>[];
          final seenArtists = <String>{};
          for (final item in items) {
            final id = item['id']?.toString() ?? '';
            final title = item['name']?.toString() ?? '';
            final durSec = int.tryParse(item['duration']?.toString() ?? '0') ?? 0;
            if (id.isEmpty || title.isEmpty || durSec <= 35) continue;
            final primaryList =
                ((item['artists'] as Map<String, dynamic>?)?['primary'] as List? ?? [])
                    .whereType<Map<String, dynamic>>()
                    .toList();
            final artistName = primaryList.isNotEmpty
                ? primaryList.map((a) => a['name']?.toString() ?? '').where((s) => s.isNotEmpty).join(', ')
                : (item['label']?.toString() ?? 'Artist');
            final images = (item['image'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
            final thumb = images.isNotEmpty ? (images.last['url']?.toString() ?? '') : '';
            songs.add(SongModel(
              id: 'js_$id',
              title: title,
              artist: artistName,
              channelId: 'js_$id',
              thumbnailUrl: thumb,
              durationSeconds: durSec,
              durationFormatted: Formatters.formatDuration(Duration(seconds: durSec)),
              viewCount: int.tryParse(item['playCount']?.toString() ?? '250000') ?? 250000,
              publishedAt: null,
            ));
            if (artistName.isNotEmpty && !seenArtists.contains(artistName)) {
              seenArtists.add(artistName);
              artists.add(ArtistModel(
                id: 'js_art_$id',
                name: artistName,
                thumbnailUrl: thumb,
              ));
            }
          }
          if (songs.isNotEmpty) {
            return SearchResultModel(
              songs: songs,
              videos: songs,
              artists: artists,
              playlists: const [],
            );
          }
        }
      }
    } catch (e) {
      AppLogger.error('JioSaavn fallback search error: $e');
    }
    return _getEmptySearchResult();
  }

  SearchResultModel _getEmptySearchResult() {
    return const SearchResultModel(
      songs: [],
      videos: [],
      artists: [],
      playlists: [],
    );
  }
}
