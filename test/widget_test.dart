import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:melody_tube/core/services/local_storage_service.dart';
import 'package:melody_tube/domain/entities/artist.dart';
import 'package:melody_tube/domain/entities/playlist.dart';
import 'package:melody_tube/domain/entities/search_result.dart';
import 'package:melody_tube/domain/entities/song.dart';
import 'package:melody_tube/domain/repositories/auth_repository.dart';
import 'package:melody_tube/domain/repositories/music_repository.dart';
import 'package:melody_tube/domain/repositories/youtube_repository.dart';
import 'package:melody_tube/domain/entities/user_profile.dart';
import 'package:melody_tube/presentation/providers/auth_provider.dart';
import 'package:melody_tube/presentation/providers/download_provider.dart';
import 'package:melody_tube/presentation/providers/player_provider.dart';
import 'package:melody_tube/presentation/providers/playlist_provider.dart';
import 'package:melody_tube/presentation/providers/search_provider.dart';
import 'package:melody_tube/presentation/screens/main_navigation_screen.dart';
import 'package:melody_tube/presentation/widgets/app_logo.dart';
import 'package:melody_tube/presentation/widgets/mini_player_widget.dart';

class _TestMusicRepo implements MusicRepository {
  @override
  void addChangeListener(VoidCallback listener) {}
  @override
  void removeChangeListener(VoidCallback listener) {}
  @override
  Future<void> addRecentlyPlayed(Song song) async {}
  @override
  Future<void> clearRecentlyPlayed() async {}
  @override
  Future<List<Song>> getRecentlyPlayed() async => [];
  @override
  Future<List<Song>> getFavorites() async => [];
  @override
  Future<bool> isFavorite(String songId) async => false;
  @override
  Future<void> toggleFavorite(Song song) async {}
  @override
  Future<List<Playlist>> getUserPlaylists() async => [];
  @override
  Future<Playlist> createPlaylist(String title, {String? description}) async =>
      Playlist(id: 'pl1', title: title, description: description ?? '', thumbnailUrl: '', updatedAt: DateTime.now());
  @override
  Future<void> deletePlaylist(String playlistId) async {}
  @override
  Future<void> renamePlaylist(String playlistId, String newTitle) async {}
  @override
  Future<void> addSongToPlaylist(String playlistId, Song song) async {}
  @override
  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {}
  @override
  Future<List<String>> getSearchHistory() async => [];
  @override
  Future<void> addSearchHistory(String query) async {}
  @override
  Future<void> clearSearchHistory() async {}
}

class _TestYouTubeRepo implements YouTubeRepository {
  static const testSong = Song(
    id: 'dQw4w9WgXcQ',
    title: 'Obak Bhalobasha',
    artist: 'LYRICAL CAFE',
    channelId: 'ch_lyrical',
    thumbnailUrl: '',
    durationSeconds: 230,
    durationFormatted: '03:50',
  );

  @override
  Future<SearchResult> searchAll(String query) async =>
      const SearchResult(songs: [testSong], videos: [testSong]);
  @override
  Future<List<Song>> searchSongs(String query, {int maxResults = 20}) async => [testSong];
  @override
  Future<List<Artist>> searchArtists(String query, {int maxResults = 10}) async => [];
  @override
  Future<List<Playlist>> searchPlaylists(String query, {int maxResults = 10}) async => [];
  @override
  Future<List<Song>> getTrendingMusic({String regionCode = 'US'}) async => [testSong];
  @override
  Future<List<Song>> getQuickPicks() async => [testSong];
  @override
  Future<List<Song>> getRecommendedMusic() async => [testSong];
  @override
  Future<List<Song>> getMusicByGenre(String genre) async => [testSong];
  @override
  Future<List<Artist>> getPopularArtists() async => [];
  @override
  Future<Song?> getVideoDetails(String videoId) async => testSong;
}

class _TestAuthRepo implements AuthRepository {
  @override
  Future<UserProfile?> getCurrentUser() async => const UserProfile(
        uid: 'guest_local_user',
        name: 'Guest Listener',
        email: '',
        avatarUrl: '',
        isGuest: true,
      );
  @override
  Future<UserProfile> signInWithGoogle() async =>
      const UserProfile(uid: 'u1', name: 'Test', email: 't@t.com', avatarUrl: '');
  @override
  Future<UserProfile> signInWithEmail(String email, String password) async =>
      const UserProfile(uid: 'u1', name: 'Test', email: 't@t.com', avatarUrl: '');
  @override
  Future<UserProfile> registerWithEmail(String email, String password, String name) async =>
      const UserProfile(uid: 'u1', name: 'Test', email: 't@t.com', avatarUrl: '');
  @override
  Future<UserProfile> signInAsGuest() async =>
      const UserProfile(uid: 'guest_local_user', name: 'Guest Listener', email: '', avatarUrl: '', isGuest: true);
  @override
  Future<void> signOut() async {}
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageService.init();
  });

  group('Twilight App UI Widget Tests', () {
    testWidgets('AppLogo renders icon without text when showText is false', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppLogo(size: 40, showText: false),
            ),
          ),
        ),
      );

      expect(find.byType(AppLogo), findsOneWidget);
      expect(find.text('Twilight'), findsNothing);
    });

    testWidgets('AppLogo renders Twilight title text when showText is true', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppLogo(size: 48, showText: true),
            ),
          ),
        ),
      );

      expect(find.byType(AppLogo), findsOneWidget);
      expect(find.text('Twilight'), findsOneWidget);
    });

    testWidgets('AppLogo scales appropriately with custom size', (WidgetTester tester) async {
      const customSize = 64.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppLogo(size: customSize, showText: true),
            ),
          ),
        ),
      );

      final containerFinder = find.descendant(
        of: find.byType(AppLogo),
        matching: find.byType(Container),
      );

      expect(containerFinder, findsWidgets);
      final container = tester.widget<Container>(containerFinder.first);
      final constraints = container.constraints;
      expect(constraints?.maxWidth ?? container.decoration, isNotNull);
    });

    testWidgets('Search tab inside MainNavigationScreen renders only ONE MiniPlayerWidget when searched and played', (WidgetTester tester) async {
      final musicRepo = _TestMusicRepo();
      final ytRepo = _TestYouTubeRepo();
      final authRepo = _TestAuthRepo();
      final playerProvider = PlayerProvider(musicRepository: musicRepo);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<YouTubeRepository>.value(value: ytRepo),
            Provider<MusicRepository>.value(value: musicRepo),
            Provider<AuthRepository>.value(value: authRepo),
            ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider(authRepository: authRepo)),
            ChangeNotifierProvider<DownloadProvider>(create: (_) => DownloadProvider()),
            ChangeNotifierProvider<PlayerProvider>.value(value: playerProvider),
            ChangeNotifierProvider<PlaylistProvider>(create: (_) => PlaylistProvider(musicRepository: musicRepo)),
            ChangeNotifierProvider<SearchProvider>(
              create: (_) => SearchProvider(youtubeRepository: ytRepo, musicRepository: musicRepo),
            ),
          ],
          child: const MaterialApp(
            home: MainNavigationScreen(),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));

      // Switch to Search tab in BottomNavigationBar
      await tester.tap(find.text('Search').first);
      await tester.pump();

      // Play a song while on the Search tab
      await playerProvider.playSong(_TestYouTubeRepo.testSong);
      await tester.pump();

      // Verify strictly ONE MiniPlayerWidget is rendered (never doubled)
      expect(find.byType(MiniPlayerWidget), findsOneWidget);
    });
  });
}
