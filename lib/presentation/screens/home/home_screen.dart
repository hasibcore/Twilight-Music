import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../data/models/song_model.dart';
import '../../../domain/entities/song.dart';
import '../../../domain/entities/artist.dart';
import '../../../domain/repositories/youtube_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/download_provider.dart';
import '../../providers/player_provider.dart';
import '../../widgets/app_logo.dart';
import '../main_navigation_screen.dart';

class _VibeCategory {
  final String id;
  final String label;
  final String query;

  const _VibeCategory({
    required this.id,
    required this.label,
    required this.query,
  });
}

const List<_VibeCategory> _kVibeCategories = [
  _VibeCategory(
    id: 'lofi_focus',
    label: '☕ Lo-Fi & Focus',
    query: 'lofi chill beats to study relax instrumental',
  ),
  _VibeCategory(
    id: 'romantic',
    label: '💖 Romantic Melodies',
    query: 'romantic love songs acoustic playlist',
  ),
  _VibeCategory(
    id: 'bengali_hits',
    label: '🇧🇩 Bengali Melodies',
    query: 'top bengali modern songs Arijit Singh Anupam Roy Habib Wahid',
  ),
  _VibeCategory(
    id: 'high_energy',
    label: '⚡ Energy & Pop',
    query: 'upbeat pop dance hits workout music',
  ),
  _VibeCategory(
    id: 'indie_acoustic',
    label: '🎸 Indie & Acoustic',
    query: 'indie folk acoustic chill songs',
  ),
];

const List<Song> _kDefaultFeaturedSongs = [
  Song(
    id: 'fJ9rUzIMcZQ',
    title: 'Bohemian Rhapsody',
    artist: 'Queen',
    channelId: 'QueenOfficial',
    thumbnailUrl: 'https://i.ytimg.com/vi/fJ9rUzIMcZQ/hqdefault.jpg',
    durationSeconds: 355,
    durationFormatted: '5:55',
  ),
  Song(
    id: 'kJQP7kiw5Fk',
    title: 'Despacito',
    artist: 'Luis Fonsi ft. Daddy Yankee',
    channelId: 'LuisFonsiVEVO',
    thumbnailUrl: 'https://i.ytimg.com/vi/kJQP7kiw5Fk/hqdefault.jpg',
    durationSeconds: 281,
    durationFormatted: '4:41',
  ),
  Song(
    id: 'JGwWNGJdvx8',
    title: 'Shape of You',
    artist: 'Ed Sheeran',
    channelId: 'EdSheeranVEVO',
    thumbnailUrl: 'https://i.ytimg.com/vi/JGwWNGJdvx8/hqdefault.jpg',
    durationSeconds: 263,
    durationFormatted: '4:23',
  ),
  Song(
    id: '4NRXx6U8ABQ',
    title: 'Blinding Lights',
    artist: 'The Weeknd',
    channelId: 'TheWeekndVEVO',
    thumbnailUrl: 'https://i.ytimg.com/vi/4NRXx6U8ABQ/hqdefault.jpg',
    durationSeconds: 200,
    durationFormatted: '3:20',
  ),
  Song(
    id: 'hT_nvWreIhg',
    title: 'Counting Stars',
    artist: 'OneRepublic',
    channelId: 'OneRepublicVEVO',
    thumbnailUrl: 'https://i.ytimg.com/vi/hT_nvWreIhg/hqdefault.jpg',
    durationSeconds: 257,
    durationFormatted: '4:17',
  ),
  Song(
    id: 'CevxZvSJLk8',
    title: 'Roar',
    artist: 'Katy Perry',
    channelId: 'KatyPerryVEVO',
    thumbnailUrl: 'https://i.ytimg.com/vi/CevxZvSJLk8/hqdefault.jpg',
    durationSeconds: 269,
    durationFormatted: '4:29',
  ),
];

const List<Artist> _kFeaturedArtists = [
  Artist(
    id: 'art_weeknd',
    name: 'The Weeknd',
    thumbnailUrl: 'https://i.ytimg.com/vi/4NRXx6U8ABQ/hqdefault.jpg',
    subscriberCountFormatted: '36.2M listeners',
  ),
  Artist(
    id: 'art_arijit',
    name: 'Arijit Singh',
    thumbnailUrl: 'https://i.ytimg.com/vi/Umqb9KENgmk/hqdefault.jpg',
    subscriberCountFormatted: '42.8M listeners',
  ),
  Artist(
    id: 'art_ed',
    name: 'Ed Sheeran',
    thumbnailUrl: 'https://i.ytimg.com/vi/JGwWNGJdvx8/hqdefault.jpg',
    subscriberCountFormatted: '54.9M listeners',
  ),
  Artist(
    id: 'art_coldplay',
    name: 'Coldplay',
    thumbnailUrl: 'https://i.ytimg.com/vi/YykjpeuMNEk/hqdefault.jpg',
    subscriberCountFormatted: '28.1M listeners',
  ),
  Artist(
    id: 'art_dua',
    name: 'Dua Lipa',
    thumbnailUrl: 'https://i.ytimg.com/vi/TUVcZfQe-Kw/hqdefault.jpg',
    subscriberCountFormatted: '24.6M listeners',
  ),
  Artist(
    id: 'art_imagine',
    name: 'Imagine Dragons',
    thumbnailUrl: 'https://i.ytimg.com/vi/7wtfhZwyrcc/hqdefault.jpg',
    subscriberCountFormatted: '31.4M listeners',
  ),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _dynamicCacheKey = 'twilight_home_dynamic_flutter_v3';

  String _selectedVibeId = 'for_you';
  bool _isRefreshingMix = false;
  List<Song> _dynamicSongs = List<Song>.from(_kDefaultFeaturedSongs);
  List<Artist> _artists = List<Artist>.from(_kFeaturedArtists);

  @override
  void initState() {
    super.initState();
    final hasCached = _loadCachedHomeDataSync();
    _loadArtists();
    if (!hasCached) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadLiveTrendingMix();
      });
    }
  }

  bool _loadCachedHomeDataSync() {
    try {
      final raw = LocalStorageService.getString(_dynamicCacheKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List?;
        if (decoded != null && decoded.isNotEmpty) {
          final parsed = decoded
              .whereType<Map>()
              .map((m) => SongModel.fromJson(Map<String, dynamic>.from(m)).toEntity())
              .toList();
          if (parsed.isNotEmpty) {
            _dynamicSongs = parsed;
            return true;
          }
        }
      }
    } catch (_) {}
    return false;
  }

  Future<void> _loadLiveTrendingMix() async {
    try {
      final ytRepo = context.read<YouTubeRepository>();
      final trending = await ytRepo.getTrendingMusic();
      if (mounted && trending.isNotEmpty && _selectedVibeId == 'for_you') {
        final merged = <Song>[];
        final seen = <String>{};
        for (final s in [...trending, ..._kDefaultFeaturedSongs]) {
          if (seen.contains(s.id)) continue;
          seen.add(s.id);
          merged.add(s);
          if (merged.length >= 16) break;
        }
        setState(() {
          _dynamicSongs = merged;
        });
        try {
          final payload = jsonEncode(
            merged.map((s) => SongModel.fromEntity(s).toJson()).toList(),
          );
          LocalStorageService.setString(_dynamicCacheKey, payload);
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> _loadArtists() async {
    try {
      final ytRepo = context.read<YouTubeRepository>();
      final fetched = await ytRepo.getPopularArtists();
      if (mounted && fetched.isNotEmpty) {
        setState(() {
          _artists = fetched;
        });
      }
    } catch (_) {}
  }

  ({String label, String query}) _getTimeBasedVibe() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return (label: '🌅 Morning Boost', query: 'upbeat acoustic morning chill songs');
    } else if (hour >= 12 && hour < 17) {
      return (label: '☀️ Afternoon Flow', query: 'feel good pop indie hits');
    } else if (hour >= 17 && hour < 22) {
      return (label: '🌆 Sunset Groove', query: 'chill evening sunset r&b synthwave');
    } else {
      return (label: '🌙 Midnight Serenade', query: 'late night lofi chill aesthetic songs');
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 17) return 'Good afternoon';
    if (hour >= 17 && hour < 22) return 'Good evening';
    return 'Good night';
  }

  Future<void> _refreshDynamicMix([String? vibeId]) async {
    final nextVibeId = vibeId ?? _selectedVibeId;
    setState(() {
      _selectedVibeId = nextVibeId;
      _isRefreshingMix = true;
    });

    try {
      if (nextVibeId == 'for_you' && vibeId != null) {
        final ytRepo = context.read<YouTubeRepository>();
        final trending = await ytRepo.getTrendingMusic();
        if (mounted) {
          setState(() {
            _dynamicSongs = trending.isNotEmpty
                ? trending
                : List<Song>.from(_kDefaultFeaturedSongs);
            _isRefreshingMix = false;
          });
        }
        return;
      }

      final vibeObj = _kVibeCategories.where((v) => v.id == nextVibeId).firstOrNull;
      final query = vibeObj != null ? vibeObj.query : _getTimeBasedVibe().query;
      final ytRepo = context.read<YouTubeRepository>();
      final songs = await ytRepo.searchSongs(query);

      if (mounted) {
        setState(() {
          if (songs.isNotEmpty) {
            _dynamicSongs = songs;
            try {
              final payload = jsonEncode(
                songs.map((s) => SongModel.fromEntity(s).toJson()).toList(),
              );
              LocalStorageService.setString(_dynamicCacheKey, payload);
            } catch (_) {}
          }
          _isRefreshingMix = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isRefreshingMix = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerProv = context.watch<PlayerProvider>();
    final downloadProv = context.watch<DownloadProvider>();
    final authProv = context.watch<AuthProvider>();
    final hasCurrentSong = playerProv.currentSong != null;
    final bottomPadding = hasCurrentSong ? 110.0 : 48.0;
    final timeVibe = _getTimeBasedVibe();
    final activeVibeLabel = _selectedVibeId == 'for_you'
        ? timeVibe.label
        : (_kVibeCategories.where((v) => v.id == _selectedVibeId).firstOrNull?.label ??
            'Personalized Mix');

    final userName = authProv.user?.name ?? '';
    final userInitial = userName.trim().isNotEmpty && !authProv.isGuest
        ? userName.trim()[0].toUpperCase()
        : 'G';

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(62),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF020617).withValues(alpha: 0.90),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.05),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const AppLogo(
                    size: 38,
                    showText: true,
                    subtitle: 'MUSIC',
                  ),
                  GestureDetector(
                    onTap: () => MainNavigationScreen.switchToTab(context, 4),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFF64748B).withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                          width: 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        userInitial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _refreshDynamicMix(_selectedVibeId),
        color: AppColors.primaryAccent,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Header / Greeting Bar (Matching Screenshot)
              Text(
                timeVibe.label.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF818CF8),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _getGreeting(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 20),

              // 2. Vibe Categories Filter Chips (Matching Screenshot)
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildVibeChip(
                      id: 'for_you',
                      label: 'For You',
                      leadingIcon: Icons.auto_awesome_rounded,
                      isForYou: true,
                    ),
                    ..._kVibeCategories.map(
                      (vibe) => _buildVibeChip(
                        id: vibe.id,
                        label: vibe.label,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // 3. Dynamic Taste Engine Section Header + Refresh Mix Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DYNAMIC TASTE ENGINE',
                          style: TextStyle(
                            color: Color(0xFF818CF8),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          activeVibeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Material(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _isRefreshingMix ? null : () => _refreshDynamicMix(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isRefreshingMix)
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFFCBD5E1),
                                ),
                              )
                            else
                              const Icon(
                                Icons.refresh_rounded,
                                size: 15,
                                color: Color(0xFFCBD5E1),
                              ),
                            const SizedBox(width: 6),
                            const Text(
                              'Refresh Mix',
                              style: TextStyle(
                                color: Color(0xFFCBD5E1),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 4. Responsive Song Cards Grid (Matching Screenshot)
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final crossAxisCount = width >= 1100
                      ? 6
                      : width >= 780
                          ? 4
                          : width >= 520
                              ? 3
                              : 2;
                  final displaySongs = _dynamicSongs.take(6).toList();

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: displaySongs.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 0.78,
                    ),
                    itemBuilder: (context, index) {
                      final song = displaySongs[index];
                      return _buildTasteSongCard(
                        song: song,
                        queue: _dynamicSongs,
                        playerProv: playerProv,
                        downloadProv: downloadProv,
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 32),

              // 5. Artist Radio Stations Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.podcasts_rounded,
                          size: 18,
                          color: Color(0xFFF43F5E),
                        ),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Artist Radio Stations',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => MainNavigationScreen.openSearch(context),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Explore All',
                          style: TextStyle(
                            color: Color(0xFF818CF8),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: Color(0xFF818CF8),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 132,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _artists.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    final artist = _artists[index];
                    return GestureDetector(
                      onTap: () => MainNavigationScreen.openSearch(
                        context,
                        initialQuery: artist.name,
                      ),
                      child: SizedBox(
                        width: 96,
                        child: Column(
                          children: [
                            Container(
                              width: 82,
                              height: 82,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF1E293B),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  width: 2,
                                ),
                              ),
                              child: ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: artist.thumbnailUrl,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => const Icon(
                                    Icons.person_rounded,
                                    color: Colors.white54,
                                    size: 36,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              artist.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFE2E8F0),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              artist.subscriberCountFormatted,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVibeChip({
    required String id,
    required String label,
    IconData? leadingIcon,
    bool isForYou = false,
  }) {
    final isActive = _selectedVibeId == id;
    final bgColor = isActive
        ? (isForYou ? Colors.white : const Color(0xFF4F46E5))
        : Colors.white.withValues(alpha: 0.05);
    final textColor = isActive
        ? (isForYou ? const Color(0xFF020617) : Colors.white)
        : const Color(0xFFCBD5E1);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _refreshDynamicMix(id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leadingIcon != null) ...[
                  Icon(
                    leadingIcon,
                    size: 14,
                    color: textColor,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTasteSongCard({
    required Song song,
    required List<Song> queue,
    required PlayerProvider playerProv,
    required DownloadProvider downloadProv,
  }) {
    final isCurrent = playerProv.currentSong?.id == song.id;
    final isDown = downloadProv.isDownloaded(song.id);
    final isDownLoading = downloadProv.isDownloading(song.id);
    final thumbUrl = song.id.length == 11 && !song.id.startsWith('sp_')
        ? 'https://i.ytimg.com/vi/${song.id}/hqdefault.jpg'
        : song.thumbnailUrl;

    return GestureDetector(
      onTap: () => playerProv.selectAndPlaySong(song, newQueue: queue),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isCurrent
              ? const Color(0xFF4F46E5).withValues(alpha: 0.20)
              : const Color(0xFF0F172A).withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCurrent
                ? const Color(0xFF6366F1).withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: thumbUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: const Color(0xFF1E293B),
                        child: const Icon(
                          Icons.music_note_rounded,
                          color: Colors.white54,
                          size: 32,
                        ),
                      ),
                    ),
                  ),

                  // Top-right Download / Check Button (Matching Screenshot)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () {
                        if (!isDownLoading) {
                          downloadProv.startDownload(song);
                        }
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isDown
                              ? const Color(0xFF10B981).withValues(alpha: 0.30)
                              : isDownLoading
                                  ? const Color(0xFF6366F1).withValues(alpha: 0.35)
                                  : Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDown
                                ? const Color(0xFF34D399).withValues(alpha: 0.55)
                                : Colors.white.withValues(alpha: 0.16),
                            width: 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: isDownLoading
                            ? const SizedBox(
                                width: 13,
                                height: 13,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                isDown ? Icons.check_rounded : Icons.download_rounded,
                                size: 15,
                                color: isDown ? const Color(0xFF6EE7B7) : Colors.white,
                              ),
                      ),
                    ),
                  ),

                  // Active Track Overlay
                  if (isCurrent)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.38),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4F46E5),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: playerProv.isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                playerProv.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isCurrent ? const Color(0xFFA5B4FC) : Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
