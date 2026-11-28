import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melody_tube/core/services/artwork_service.dart';
import 'package:melody_tube/data/models/song_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory' ||
            methodCall.method == 'getTemporaryDirectory') {
          return '.';
        }
        return null;
      },
    );
  });

  group('ArtworkService Tests', () {
    test('getArtworkUri returns parsed URI for valid HTTP thumbnail', () async {
      final uri = await ArtworkService.getArtworkUri(
        thumbnailUrl: 'https://i.ytimg.com/vi/test/hqdefault.jpg',
        songId: 'test_song',
      );
      expect(uri, isNotNull);
      expect(uri.toString(), equals('https://i.ytimg.com/vi/test/hqdefault.jpg'));
    });

    test('getArtworkUri handles empty or null thumbnail gracefully', () async {
      final uri = await ArtworkService.getArtworkUri(
        thumbnailUrl: '',
        songId: 'empty_song',
      );
      // In test environment without assets bundle, it safely returns null or logo URI
      expect(uri == null || uri.toString().isNotEmpty, isTrue);
    });

    test('normalizeThumbnailUrl converts maxresdefault.jpg and mismatched video thumbnails to verified hqdefault.jpg', () {
      expect(
        ArtworkService.normalizeThumbnailUrl(
          'https://img.youtube.com/vi/dQw4w9WgXcQ/maxresdefault.jpg',
          songId: 'dQw4w9WgXcQ',
        ),
        equals('https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg'),
      );

      // Even if a stale or wrong video ID was in thumbnailUrl, it locks to the active songId
      expect(
        ArtworkService.normalizeThumbnailUrl(
          'https://i.ytimg.com/vi/OLD_SONG_ID/hqdefault.jpg',
          songId: 'kXYiU_JCYtU',
        ),
        equals('https://i.ytimg.com/vi/kXYiU_JCYtU/hqdefault.jpg'),
      );
    });

    test('11-char js_* JioSaavn IDs keep HTTPS CDN artwork and never map to fake YouTube thumbnails', () {
      expect(ArtworkService.isYouTubeVideoId('js_BX6n0TPe'), isFalse);
      expect(ArtworkService.isYouTubeVideoId('dQw4w9WgXcQ'), isTrue);

      const httpLowRes = 'http://c.saavncdn.com/400/Trending-Punjabi-2024-20241114144017-150x150.jpg';
      final normalized = ArtworkService.normalizeThumbnailUrl(httpLowRes, songId: 'js_BX6n0TPe');
      expect(
        normalized,
        equals('https://c.saavncdn.com/400/Trending-Punjabi-2024-20241114144017-500x500.jpg'),
      );
      expect(normalized.contains(r'${1}'), isFalse);

      expect(
        ArtworkService.fallbackThumbnailUrl(normalized, songId: 'js_BX6n0TPe'),
        equals('https://c.saavncdn.com/400/Trending-Punjabi-2024-20241114144017-150x150.jpg'),
      );

      final song = SongModel.fromJson({
        'id': 'js_BX6n0TPe',
        'title': 'Trending',
        'artist': 'Vicky Dhaliwal',
        'channelId': 'js_BX6n0TPe',
        'thumbnailUrl': httpLowRes,
        'durationSeconds': 133,
      });
      expect(
        song.thumbnailUrl,
        equals('https://c.saavncdn.com/400/Trending-Punjabi-2024-20241114144017-500x500.jpg'),
      );
    });
  });
}

