import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../providers/download_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../providers/player_provider.dart';
import '../../widgets/song_card.dart';
import '../playlist/create_playlist_dialog.dart';
import '../playlist/playlist_detail_screen.dart';
import '../../widgets/import_playlist_dialog.dart';
import '../../widgets/app_logo.dart';
import '../main_navigation_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playlistProv = context.watch<PlaylistProvider>();
    final downloadProv = context.watch<DownloadProvider>();
    final hasCurrentSong = context.select<PlayerProvider, bool>((p) => p.currentSong != null);
    final bottomPadding = hasCurrentSong ? 100.0 : 40.0;

    final currentSongId = context.select<PlayerProvider, String?>((p) => p.currentSong?.id);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(114),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AppLogo(
                        size: 38,
                        showText: true,
                        subtitle: 'MUSIC',
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.add, color: Color(0xFFCBD5E1), size: 22),
                            tooltip: AppStrings.createPlaylist,
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => const CreatePlaylistDialog(),
                              );
                            },
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
                                  color: const Color(0xFF6366F1),
                                  width: 1.5,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'H',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  indicatorColor: AppColors.primaryAccent,
                  labelColor: Colors.white,
                  unselectedLabelColor: const Color(0xFF94A3B8),
                  tabs: [
                    const Tab(text: 'Playlists'),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Downloads'),
                          if (downloadProv.count > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E676).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${downloadProv.count}',
                                style: const TextStyle(
                                  color: Color(0xFF00E676),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Tab(text: 'Liked Songs'),
                    const Tab(text: 'History'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: TabBarView(
          controller: _tabController,
          children: [
            // Playlists Tab
            _buildPlaylistsTab(playlistProv),
            // Downloads Tab
            _buildDownloadsTab(downloadProv, currentSongId),
            // Liked Songs Tab
            _buildLikedSongsTab(playlistProv),
            // History Tab
            _buildHistoryTab(playlistProv),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadsTab(DownloadProvider downloadProv, String? currentSongId) {
    final downloads = downloadProv.downloads;

    if (downloads.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.download_for_offline_outlined, size: 64, color: AppColors.textTertiary(context)),
              const SizedBox(height: 16),
              Text(
                'No downloaded songs',
                style: TextStyle(color: AppColors.textPrimary(context), fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap the download icon on any song to save it for offline playback without internet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Action header (Track count & Play All button)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${downloads.length} Offline Tracks',
                style: const TextStyle(color: Color(0xFF00E676), fontSize: 13, fontWeight: FontWeight.w600),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: const Text('Play All'),
                onPressed: () {
                  final downloadedSongs = downloadProv.downloadedSongs;
                  if (downloadedSongs.isNotEmpty) {
                    context.read<PlayerProvider>().selectAndPlaySong(
                          downloadedSongs.first,
                          newQueue: downloadedSongs,
                          queueIndex: 0,
                        );
                  }
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: downloads.length,
            itemBuilder: (context, index) {
              final item = downloads[index];
              final isCurrent = currentSongId == item.song.id || currentSongId == item.resolvedVideoId;
              final isHealthy = item.isFileHealthy;
              final isDownloading = downloadProv.isDownloading(item.song.id);
              final progress = downloadProv.getProgress(item.song.id);
              final sizeMb = (item.fileSize / (1024 * 1024)).toStringAsFixed(1);

              return ListTile(
                leading: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: item.localThumbnailPath != null && File(item.localThumbnailPath!).existsSync()
                          ? Image.file(
                              File(item.localThumbnailPath!),
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                            )
                          : (item.song.thumbnailUrl.startsWith('http')
                              ? Image.network(
                                  item.song.thumbnailUrl,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 48,
                                    height: 48,
                                    color: AppColors.surfaceVariantDark,
                                    child: const Icon(Icons.music_note, color: Colors.white38),
                                  ),
                                )
                              : Container(
                                  width: 48,
                                  height: 48,
                                  color: AppColors.surfaceVariantDark,
                                  child: const Icon(Icons.music_note, color: Colors.white38),
                                )),
                    ),
                    if (isCurrent)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.equalizer, color: AppColors.primaryAccent, size: 24),
                        ),
                      ),
                  ],
                ),
                title: Text(
                  item.song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isCurrent ? AppColors.primaryAccent : AppColors.textPrimary(context),
                  ),
                ),
                subtitle: isDownloading
                    ? Text(
                        'Re-downloading ${(progress * 100).toInt()}%...',
                        style: const TextStyle(color: Color(0xFF00E676), fontSize: 12, fontWeight: FontWeight.w600),
                      )
                    : isHealthy
                        ? Text(
                            '${item.song.artist} • $sizeMb MB',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12),
                          )
                        : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 14),
                              SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'File missing · Tap to re-download',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Color(0xFFF59E0B),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isHealthy && !isDownloading)
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: Color(0xFFF59E0B)),
                        tooltip: 'Re-download track',
                        onPressed: () {
                          downloadProv.retryDownload(item.song);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Re-downloading "${item.song.title}"...')),
                          );
                        },
                      ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: AppColors.icon(context)),
                      color: AppColors.surface(context),
                      onSelected: (val) {
                        if (val == 'play') {
                          context.read<PlayerProvider>().selectAndPlaySong(
                                item.song,
                                newQueue: downloadProv.downloadedSongs,
                              );
                        } else if (val == 'redownload') {
                          downloadProv.retryDownload(item.song);
                        } else if (val == 'delete') {
                          downloadProv.deleteDownload(item.song.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Download removed')),
                          );
                        }
                      },
                      itemBuilder: (_) => [
                        if (isHealthy)
                          PopupMenuItem(
                            value: 'play',
                            child: Row(
                              children: [
                                Icon(Icons.play_arrow, color: AppColors.icon(context)),
                                const SizedBox(width: 8),
                                Text('Play offline', style: TextStyle(color: AppColors.textPrimary(context))),
                              ],
                            ),
                          )
                        else
                          const PopupMenuItem(
                            value: 'redownload',
                            child: Row(
                              children: [
                                Icon(Icons.refresh_rounded, color: Color(0xFFF59E0B)),
                                SizedBox(width: 8),
                                Text('Re-download track', style: TextStyle(color: Color(0xFFF59E0B))),
                              ],
                            ),
                          ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: Colors.redAccent),
                              SizedBox(width: 8),
                              Text('Delete download', style: TextStyle(color: Colors.redAccent)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                onTap: () {
                  if (isHealthy) {
                    context.read<PlayerProvider>().selectAndPlaySong(
                          item.song,
                          newQueue: downloadProv.downloadedSongs,
                        );
                  } else if (!isDownloading) {
                    downloadProv.retryDownload(item.song);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Re-downloading "${item.song.title}"...')),
                    );
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlaylistsTab(PlaylistProvider prov) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        // Create Playlist Action Tile
        ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant(context),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.add, color: AppColors.primaryAccent, size: 28),
          ),
          title: Text(
            AppStrings.createPlaylist,
            style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            'Create a new music collection',
            style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12),
          ),
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => const CreatePlaylistDialog(),
            );
          },
        ),
        Divider(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),

        // User Playlists List
        ...prov.playlists.map((playlist) {
          return ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: playlist.thumbnailUrl.isNotEmpty
                  ? Image.network(
                      playlist.thumbnailUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 48,
                        height: 48,
                        color: AppColors.surfaceVariant(context),
                        child: Icon(Icons.queue_music, color: AppColors.iconMuted(context)),
                      ),
                    )
                  : Container(
                      width: 48,
                      height: 48,
                      color: AppColors.surfaceVariant(context),
                      child: Icon(Icons.queue_music, color: AppColors.iconMuted(context)),
                    ),
            ),
            title: Text(
              playlist.title,
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary(context)),
            ),
            subtitle: Text(
              '${playlist.songCount} songs • ${playlist.description}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12),
            ),
            trailing: Icon(Icons.chevron_right, color: AppColors.iconMuted(context)),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PlaylistDetailScreen(playlist: playlist),
                ),
              );
            },
          );
        }),

        if (prov.playlists.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.queue_music, size: 48, color: AppColors.textTertiary(context).withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  Text('No playlists yet', style: TextStyle(color: AppColors.textPrimary(context), fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Tap "+ New Playlist" above to create one.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLikedSongsTab(PlaylistProvider prov) {
    if (prov.favorites.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.favorite_border, size: 64, color: AppColors.textTertiary(context)),
              const SizedBox(height: 16),
              Text(
                'No liked songs yet',
                style: TextStyle(color: AppColors.textPrimary(context), fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap the heart icon while playing any song to save it here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: prov.favorites.length,
      itemBuilder: (_, index) {
        final song = prov.favorites[index];
        return SongCard(
          song: song,
          queueContext: prov.favorites,
          variant: SongCardVariant.listTile,
        );
      },
    );
  }

  Widget _buildHistoryTab(PlaylistProvider prov) {
    if (prov.recentlyPlayed.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history, size: 64, color: AppColors.textTertiary(context)),
              const SizedBox(height: 16),
              Text(
                'No listening history',
                style: TextStyle(color: AppColors.textPrimary(context), fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Songs you listen to will automatically appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${prov.recentlyPlayed.length} Tracks',
                style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13),
              ),
              TextButton(
                onPressed: () => prov.clearRecentlyPlayed(),
                child: const Text('Clear History', style: TextStyle(color: AppColors.primaryAccent)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: prov.recentlyPlayed.length,
            itemBuilder: (_, index) {
              final song = prov.recentlyPlayed[index];
              return SongCard(
                song: song,
                queueContext: prov.recentlyPlayed,
                variant: SongCardVariant.listTile,
              );
            },
          ),
        ),
      ],
    );
  }
}
