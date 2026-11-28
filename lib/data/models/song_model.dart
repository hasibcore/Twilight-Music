import '../../domain/entities/song.dart';
import '../../core/services/artwork_service.dart';
import '../../core/utils/formatters.dart';

class SongModel extends Song {
  const SongModel({
    required super.id,
    required super.title,
    required super.artist,
    required super.channelId,
    required super.thumbnailUrl,
    required super.durationSeconds,
    required super.durationFormatted,
    super.viewCount = 0,
    super.publishedAt,
    super.isFavorite = false,
  });

  static int _parseSafeInt(dynamic value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim()) ?? fallback;
  }

  static bool _parseSafeBool(dynamic value, [bool fallback = false]) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final str = value.toString().toLowerCase().trim();
    if (str == 'true' || str == '1') return true;
    if (str == 'false' || str == '0') return false;
    return fallback;
  }

  Song toEntity() {
    return Song(
      id: id,
      title: title,
      artist: artist,
      channelId: channelId,
      thumbnailUrl: thumbnailUrl,
      durationSeconds: durationSeconds,
      durationFormatted: durationFormatted,
      viewCount: viewCount,
      publishedAt: publishedAt,
      isFavorite: isFavorite,
    );
  }

  factory SongModel.fromEntity(Song entity) {
    return SongModel(
      id: entity.id,
      title: entity.title,
      artist: entity.artist,
      channelId: entity.channelId,
      thumbnailUrl: entity.thumbnailUrl,
      durationSeconds: entity.durationSeconds,
      durationFormatted: entity.durationFormatted.isNotEmpty
          ? entity.durationFormatted
          : Formatters.formatSeconds(entity.durationSeconds),
      viewCount: entity.viewCount,
      publishedAt: entity.publishedAt,
      isFavorite: entity.isFavorite,
    );
  }

  factory SongModel.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? '').toString().trim();
    final durationSecs = _parseSafeInt(json['durationSeconds'], 0);
    final rawDurationFormatted = (json['durationFormatted'] ?? '').toString().trim();
    final durationFormatted =
        (rawDurationFormatted.isNotEmpty && rawDurationFormatted != '00:00') || durationSecs <= 0
            ? (rawDurationFormatted.isNotEmpty ? rawDurationFormatted : '00:00')
            : Formatters.formatSeconds(durationSecs);

    final rawThumb = (json['thumbnailUrl'] ?? '').toString().trim();
    final thumbnailUrl = ArtworkService.normalizeThumbnailUrl(rawThumb, songId: id);

    DateTime? parsedDate;
    final rawPub = json['publishedAt'];
    if (rawPub is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(rawPub);
    } else if (rawPub != null) {
      parsedDate = DateTime.tryParse(rawPub.toString());
    }

    return SongModel(
      id: id,
      title: (json['title'] ?? 'Unknown Title').toString().trim(),
      artist: (json['artist'] ?? 'Unknown Artist').toString().trim(),
      channelId: (json['channelId'] ?? '').toString().trim(),
      thumbnailUrl: thumbnailUrl,
      durationSeconds: durationSecs,
      durationFormatted: durationFormatted,
      viewCount: _parseSafeInt(json['viewCount'], 0),
      publishedAt: parsedDate,
      isFavorite: _parseSafeBool(json['isFavorite'], false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'channelId': channelId,
      'thumbnailUrl': thumbnailUrl,
      'durationSeconds': durationSeconds,
      'durationFormatted': durationFormatted.isNotEmpty
          ? durationFormatted
          : Formatters.formatSeconds(durationSeconds),
      'viewCount': viewCount,
      'publishedAt': publishedAt?.toIso8601String(),
      'isFavorite': isFavorite,
    };
  }

  /// Parses YouTube Data API v3 video item
  factory SongModel.fromYouTubeJson(Map<String, dynamic> item) {
    String videoId = '';
    final idField = item['id'];
    if (idField is Map) {
      videoId = (idField['videoId'] ?? '').toString().trim();
    } else if (idField != null) {
      videoId = idField.toString().trim();
    }

    final snippet = item['snippet'] is Map
        ? Map<String, dynamic>.from(item['snippet'] as Map)
        : <String, dynamic>{};
    final title = (snippet['title'] ?? 'Unknown Song').toString().trim();
    final artist = (snippet['channelTitle'] ?? 'Unknown Artist').toString().trim();
    final channelId = (snippet['channelId'] ?? '').toString().trim();

    // Prefer hqdefault ('high') over 'maxres' because maxresdefault returns 404 on non-1080p uploads
    final thumbnails = snippet['thumbnails'] is Map
        ? Map<String, dynamic>.from(snippet['thumbnails'] as Map)
        : <String, dynamic>{};
    String thumb = '';
    if (thumbnails['high'] is Map) {
      thumb = (thumbnails['high']['url'] ?? '').toString();
    } else if (thumbnails['medium'] is Map) {
      thumb = (thumbnails['medium']['url'] ?? '').toString();
    } else if (thumbnails['maxres'] is Map) {
      thumb = (thumbnails['maxres']['url'] ?? '').toString();
    } else if (thumbnails['default'] is Map) {
      thumb = (thumbnails['default']['url'] ?? '').toString();
    }

    if (videoId.length == 11 &&
        (thumb.isEmpty || thumb.contains('maxresdefault') || thumb.contains('sddefault'))) {
      thumb = 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
    }

    // Parse ISO 8601 duration (e.g. PT3M45S)
    int durationSecs = 210; // Default fallback 3m30s
    final contentDetails = item['contentDetails'] is Map
        ? Map<String, dynamic>.from(item['contentDetails'] as Map)
        : null;
    if (contentDetails != null && contentDetails['duration'] != null) {
      durationSecs = _parseIsoDuration(contentDetails['duration'].toString());
    }

    final statistics = item['statistics'] is Map
        ? Map<String, dynamic>.from(item['statistics'] as Map)
        : null;
    int views = 0;
    if (statistics != null && statistics['viewCount'] != null) {
      views = _parseSafeInt(statistics['viewCount'], 0);
    }

    return SongModel(
      id: videoId,
      title: title,
      artist: artist,
      channelId: channelId,
      thumbnailUrl: thumb.isNotEmpty
          ? thumb
          : (videoId.isNotEmpty ? 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg' : ''),
      durationSeconds: durationSecs,
      durationFormatted: Formatters.formatSeconds(durationSecs),
      viewCount: views,
      publishedAt: snippet['publishedAt'] != null
          ? DateTime.tryParse(snippet['publishedAt'].toString())
          : null,
      isFavorite: false,
    );
  }

  static int _parseIsoDuration(String isoDuration) {
    try {
      final regex = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?');
      final match = regex.firstMatch(isoDuration);
      if (match != null) {
        final hours = int.tryParse(match.group(1) ?? '0') ?? 0;
        final minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
        final seconds = int.tryParse(match.group(3) ?? '0') ?? 0;
        final total = (hours * 3600) + (minutes * 60) + seconds;
        return total > 0 ? total : 180;
      }
    } catch (_) {}
    return 180;
  }
}
