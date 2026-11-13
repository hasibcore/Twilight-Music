import 'package:flutter/foundation.dart';
import '../../core/services/music_import_service.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/music_repository.dart';

class PlaylistProvider extends ChangeNotifier {
  final MusicRepository musicRepository;

  List<Playlist> _playlists = [];
  List<Song> _favorites = [];
  List<Song> _recentlyPlayed = [];
  bool _isLoading = false;
  bool _isDisposed = false;
  int _syncSeq = 0;

  PlaylistProvider({required this.musicRepository}) {
    musicRepository.addChangeListener(_onRepositoryChanged);
    loadAll();
  }

  List<Playlist> get playlists => _playlists;
  List<Song> get favorites => _favorites;
  List<Song> get recentlyPlayed => _recentlyPlayed;
  bool get isLoading => _isLoading;

  void _safeNotify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  Future<void> _onRepositoryChanged() async {
    if (_isDisposed) return;
    final seq = ++_syncSeq;
    try {
      final results = await Future.wait([
        musicRepository.getUserPlaylists(),
        musicRepository.getFavorites(),
        musicRepository.getRecentlyPlayed(),
      ]);
      if (_isDisposed || seq != _syncSeq) return;
      _playlists = results[0] as List<Playlist>;
      _favorites = results[1] as List<Song>;
      _recentlyPlayed = results[2] as List<Song>;
      _safeNotify();
    } catch (_) {}
  }

  Future<void> loadAll() async {
    final seq = ++_syncSeq;
    _isLoading = true;
    _safeNotify();

    try {
      final results = await Future.wait([
        musicRepository.getUserPlaylists(),
        musicRepository.getFavorites(),
        musicRepository.getRecentlyPlayed(),
      ]);
      if (_isDisposed || seq != _syncSeq) return;
      _playlists = results[0] as List<Playlist>;
      _favorites = results[1] as List<Song>;
      _recentlyPlayed = results[2] as List<Song>;
    } catch (_) {
      // Retain existing state if load encounters an error
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        _safeNotify();
      }
    }
  }

  Future<Playlist> createPlaylist(String title, {String? description}) async {
    final newPl = await musicRepository.createPlaylist(title, description: description);
    if (!_playlists.any((p) => p.id == newPl.id)) {
      _playlists.insert(0, newPl);
    }
    _safeNotify();
    return newPl;
  }

  Future<void> deletePlaylist(String playlistId) async {
    _playlists.removeWhere((p) => p.id == playlistId);
    _safeNotify();
    await musicRepository.deletePlaylist(playlistId);
  }

  Future<void> renamePlaylist(String playlistId, String newTitle) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      _playlists[index] = _playlists[index].copyWith(
        title: newTitle,
        updatedAt: DateTime.now(),
      );
      _safeNotify();
    }
    await musicRepository.renamePlaylist(playlistId, newTitle);
  }

  Future<void> addSongToPlaylist(String playlistId, Song song) async {
    final plIndex = _playlists.indexWhere((p) => p.id == playlistId);
    if (plIndex != -1) {
      final updated = List<Song>.from(_playlists[plIndex].songs)
        ..removeWhere((s) => s.id == song.id || s.isSameTrack(song))
        ..insert(0, song);
      final nextThumb = song.thumbnailUrl.isNotEmpty
          ? song.thumbnailUrl
          : _playlists[plIndex].thumbnailUrl;
      _playlists[plIndex] = _playlists[plIndex].copyWith(
        songs: updated,
        thumbnailUrl: nextThumb,
        updatedAt: DateTime.now(),
      );
      _safeNotify();
    }
    await musicRepository.addSongToPlaylist(playlistId, song);
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    final plIndex = _playlists.indexWhere((p) => p.id == playlistId);
    if (plIndex != -1) {
      final updated = List<Song>.from(_playlists[plIndex].songs)
        ..removeWhere((s) => s.id == songId);
      final nextThumb = updated.isNotEmpty ? updated.first.thumbnailUrl : '';
      _playlists[plIndex] = _playlists[plIndex].copyWith(
        songs: updated,
        thumbnailUrl: nextThumb,
        updatedAt: DateTime.now(),
      );
      _safeNotify();
    }
    await musicRepository.removeSongFromPlaylist(playlistId, songId);
  }

  Future<void> toggleFavorite(Song song) async {
    await musicRepository.toggleFavorite(song);
    _favorites = await musicRepository.getFavorites();
    _safeNotify();
  }

  bool isSongFavorite(String songId) {
    final clean = songId.trim();
    if (_favorites.any((s) => s.id == clean)) return true;
    final resolvedKnown = MusicImportService.resolveKnownVideoIdByIdOrTitle(clean);
    if (resolvedKnown != null && _favorites.any((s) => s.id == resolvedKnown)) {
      return true;
    }
    for (final fav in _favorites) {
      final favResolved = MusicImportService.resolveKnownVideoIdByIdOrTitle(
        fav.id,
        title: fav.title,
      );
      if (favResolved != null && favResolved == clean) {
        return true;
      }
    }
    return false;
  }

  Future<void> clearRecentlyPlayed() async {
    await musicRepository.clearRecentlyPlayed();
    _recentlyPlayed = [];
    _safeNotify();
  }

  @override
  void dispose() {
    _isDisposed = true;
    musicRepository.removeChangeListener(_onRepositoryChanged);
    super.dispose();
  }
}
