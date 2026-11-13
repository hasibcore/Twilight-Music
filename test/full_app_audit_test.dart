import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melody_tube/core/services/audio_stream_extractor.dart';
import 'package:melody_tube/core/services/local_storage_service.dart';
import 'package:melody_tube/core/services/lyrics_service.dart';
import 'package:melody_tube/domain/entities/playlist.dart';
import 'package:melody_tube/domain/entities/song.dart';
import 'package:melody_tube/domain/repositories/music_repository.dart';
import 'package:melody_tube/presentation/providers/playlist_provider.dart';
import 'package:melody_tube/presentation/providers/player_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockMusicRepo implements MusicRepository {
  final List<Playlist> _playlists = [];
  final List<Song> _favorites = [];
  final List<Song> _history = [];
  final List<String> _searchHistory = [];

  @override
  void addChangeListener(VoidCallback listener) {}

  @override
  void removeChangeListener(VoidCallback listener) {}

  @override
  Future<bool> isFavorite(String songId) async => _favorites.any((s) => s.id == songId);

  @override
  Future<List<Playlist>> getUserPlaylists() async => List.from(_playlists);

  @override
  Future<Playlist> createPlaylist(String title, {String? description}) async {
    final pl = Playlist(
      id: 'pl_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: description ?? '',
      songs: [],
      thumbnailUrl: '',
      updatedAt: DateTime.now(),
    );
    _playlists.insert(0, pl);
    return pl;
  }

  @override
  Future<void> deletePlaylist(String playlistId) async {
    _playlists.removeWhere((p) => p.id == playlistId);
  }

  @override
  Future<void> renamePlaylist(String playlistId, String newTitle) async {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx != -1) {
      _playlists[idx] = _playlists[idx].copyWith(title: newTitle);
    }
  }

  @override
  Future<void> addSongToPlaylist(String playlistId, Song song) async {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx != -1) {
      final updated = List<Song>.from(_playlists[idx].songs)..add(song);
      _playlists[idx] = _playlists[idx].copyWith(songs: updated);
    }
  }

  @override
  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx != -1) {
      final updated = List<Song>.from(_playlists[idx].songs)..removeWhere((s) => s.id == songId);
      _playlists[idx] = _playlists[idx].copyWith(songs: updated);
    }
  }

  @override
  Future<List<Song>> getFavorites() async => List.from(_favorites);

  @override
  Future<void> toggleFavorite(Song song) async {
    final idx = _favorites.indexWhere((s) => s.id == song.id);
    if (idx != -1) {
      _favorites.removeAt(idx);
    } else {
      _favorites.add(song);
    }
  }

  @override
  Future<List<Song>> getRecentlyPlayed() async => List.from(_history);

  @override
  Future<void> addRecentlyPlayed(Song song) async {
    _history.removeWhere((s) => s.id == song.id);
    _history.insert(0, song);
  }

  @override
  Future<void> clearRecentlyPlayed() async {
    _history.clear();
  }

  @override
  Future<List<String>> getSearchHistory() async => List.from(_searchHistory);

  @override
  Future<void> addSearchHistory(String query) async {
    _searchHistory.remove(query);
    _searchHistory.insert(0, query);
  }

  @override
  Future<void> clearSearchHistory() async {
    _searchHistory.clear();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageService.init();
  });

  group('PlaylistProvider Synchronous & Async Hardening', () {
    test('createPlaylist returns new Playlist and updates in-memory immediately', () async {
      final repo = MockMusicRepo();
      final prov = PlaylistProvider(musicRepository: repo);
      await prov.loadAll();

      final created = await prov.createPlaylist('Study Beats', description: 'Deep focus');
      expect(created.title, equals('Study Beats'));
      expect(prov.playlists.length, equals(1));
      expect(prov.playlists.first.id, equals(created.id));
    });

    test('addSongToPlaylist and removeSongFromPlaylist update memory synchronously', () async {
      final repo = MockMusicRepo();
      final prov = PlaylistProvider(musicRepository: repo);
      await prov.loadAll();

      final pl = await prov.createPlaylist('Rock Hits');
      const song1 = Song(
        id: 'rock_1',
        title: 'Song 1',
        artist: 'Band',
        channelId: 'ch1',
        thumbnailUrl: '',
        durationSeconds: 200,
        durationFormatted: '3:20',
      );

      await prov.addSongToPlaylist(pl.id, song1);
      final livePl = prov.playlists.firstWhere((p) => p.id == pl.id);
      expect(livePl.songs.length, equals(1));
      expect(livePl.songs.first.id, equals('rock_1'));

      // Now test synchronous removal (crucial for Dismissible in Flutter)
      await prov.removeSongFromPlaylist(pl.id, 'rock_1');
      final afterRemovePl = prov.playlists.firstWhere((p) => p.id == pl.id);
      expect(afterRemovePl.songs.isEmpty, isTrue);
    });
  });

  group('PlayerProvider Settings & Feature Persistence', () {
    test('Audio quality and equalizer presets persist to local storage', () async {
      final repo = MockMusicRepo();
      final player = PlayerProvider(musicRepository: repo);

      player.setAudioQuality('Very High (320 kbps - Lossless)');
      expect(player.audioQuality, equals('Very High (320 kbps - Lossless)'));
      expect(LocalStorageService.getString('mt_audio_quality'), equals('Very High (320 kbps - Lossless)'));

      player.setEqualizerPreset('Bass Boost (Punchy Sub-Bass)');
      expect(player.equalizerPreset, equals('Bass Boost (Punchy Sub-Bass)'));
      expect(LocalStorageService.getString('mt_equalizer_preset'), equals('Bass Boost (Punchy Sub-Bass)'));

      // Construct a new PlayerProvider and verify it loads the persisted settings
      final restoredPlayer = PlayerProvider(musicRepository: repo);
      expect(restoredPlayer.audioQuality, equals('Very High (320 kbps - Lossless)'));
      expect(restoredPlayer.equalizerPreset, equals('Bass Boost (Punchy Sub-Bass)'));
    });
  });

  group('LyricsService Clean String Matching', () {
    test('Cleans bracketed video tags from song title', () {
      expect(
        LyricsService.cleanTitle('Shape of You [Official Music Video]'),
        equals('Shape of You'),
      );
      expect(
        LyricsService.cleanTitle('Blinding Lights (Official Audio)'),
        equals('Blinding Lights'),
      );
      expect(
        LyricsService.cleanTitle('Stay (Lyric Video)'),
        equals('Stay'),
      );
    });

    test('Cleans artist tags such as - Topic or VEVO', () {
      expect(
        LyricsService.cleanArtist('Adele - Topic'),
        equals('Adele'),
      );
      expect(
        LyricsService.cleanArtist('TaylorSwiftVEVO'),
        equals('TaylorSwift'),
      );
    });
  });

  group('AudioStreamExtractor Cache Lifecycle', () {
    test('Caches known direct master under v35_* key and properly invalidates it via invalidateCache', () async {
      final stream = await AudioStreamExtractor.extractAudioStream(
        'kJQP7kiw5Fk',
        title: 'Despacito',
        artist: 'Luis Fonsi',
      );
      expect(stream, isNotNull);
      expect(AudioStreamExtractor.getCacheAge('kJQP7kiw5Fk'), isNotNull);

      AudioStreamExtractor.invalidateCache('kJQP7kiw5Fk');
      expect(AudioStreamExtractor.getCacheAge('kJQP7kiw5Fk'), isNull);
    });
  });
}

