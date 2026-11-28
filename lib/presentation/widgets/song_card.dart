import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/song.dart';
import '../../core/constants/app_colors.dart';
import '../providers/download_provider.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';
import '../screens/playlist/create_playlist_dialog.dart';
import 'cached_artwork_image.dart';

enum SongCardVariant { horizontalCard, listTile }

class SongCard extends StatelessWidget {
  final Song song;
  final SongCardVariant variant;
  final List<Song>? queueContext;
  final VoidCallback? onTap;

  const SongCard({
    super.key,
    required this.song,
    this.variant = SongCardVariant.horizontalCard,
    this.queueContext,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (variant == SongCardVariant.horizontalCard) {
      return _buildHorizontalCard(context);
    }
    return _buildListTile(context);
  }

  Widget _buildHorizontalCard(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final isCurrent = player.currentSong?.id == song.id;

    return GestureDetector(
      onTap: onTap ?? () {
        context.read<PlayerProvider>().selectAndPlaySong(song, newQueue: queueContext);
      },
      child: Container(
        width: 145,
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Artwork with play badge overlay
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedArtworkImage(
                    imageUrl: song.thumbnailUrl,
                    songId: song.id,
                    width: 145,
                    height: 145,
                    placeholderWidget: Container(
                      width: 145,
                      height: 145,
                      color: AppColors.surfaceVariantDark,
                      child: const Center(
                        child: Icon(Icons.music_note, color: Colors.white24),
                      ),
                    ),
                    fallbackWidget: Container(
                      width: 145,
                      height: 145,
                      color: AppColors.surfaceVariantDark,
                      child: const Icon(Icons.music_note, color: Colors.white24),
                    ),
                  ),
                ),
                if (isCurrent)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.graphic_eq_rounded,
                          color: AppColors.primaryAccent,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Title
            Text(
              song.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isCurrent ? AppColors.primaryAccent : AppColors.textPrimary(context),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 3),
            // Artist
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final isCurrent = player.currentSong?.id == song.id;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: CachedArtworkImage(
              imageUrl: song.thumbnailUrl,
              songId: song.id,
              width: 52,
              height: 52,
              placeholderWidget: Container(
                width: 52,
                height: 52,
                color: AppColors.surfaceVariant(context),
              ),
              fallbackWidget: Container(
                width: 52,
                height: 52,
                color: AppColors.surfaceVariant(context),
                child: Icon(Icons.music_note, color: AppColors.iconMuted(context)),
              ),
            ),
          ),
          if (isCurrent)
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.graphic_eq_rounded, color: AppColors.primaryAccent, size: 24),
            ),
        ],
      ),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isCurrent ? AppColors.primaryAccent : AppColors.textPrimary(context),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        '${song.artist} • ${song.durationFormatted}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.textSecondary(context),
          fontSize: 12,
        ),
      ),
      trailing: IconButton(
        icon: Icon(Icons.more_vert, color: AppColors.textSecondary(context)),
        onPressed: () => _showContextMenu(context),
      ),
      onTap: onTap ?? () {
        context.read<PlayerProvider>().selectAndPlaySong(song, newQueue: queueContext);
      },
    );
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        final playlistProv = sheetContext.watch<PlaylistProvider>();
        final isFav = playlistProv.isSongFavorite(song.id);

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedArtworkImage(
                    imageUrl: song.thumbnailUrl,
                    songId: song.id,
                    width: 44,
                    height: 44,
                    fallbackWidget: Container(
                      width: 44,
                      height: 44,
                      color: AppColors.surfaceVariantDark,
                      child: const Icon(Icons.music_note, color: Colors.white38),
                    ),
                  ),
                ),
                title: Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondaryDark),
                ),
              ),
              const Divider(color: Colors.white10),
              ListTile(
                leading: const Icon(Icons.queue_music, color: Colors.white),
                title: const Text('Play next'),
                onTap: () {
                  context.read<PlayerProvider>().playNext(song);
                  Navigator.pop(sheetContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Playing next')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add, color: Colors.white),
                title: const Text('Add to queue'),
                onTap: () {
                  context.read<PlayerProvider>().addToQueue(song);
                  Navigator.pop(sheetContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Added to queue')),
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  isFav ? Icons.favorite : Icons.favorite_border,
                  color: isFav ? AppColors.primaryAccent : Colors.white,
                ),
                title: Text(isFav ? 'Remove from Favorites' : 'Add to Favorites'),
                onTap: () {
                  playlistProv.toggleFavorite(song);
                  Navigator.pop(sheetContext);
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_to_photos_outlined, color: Colors.white),
                title: const Text('Add to Playlist'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showAddToPlaylistSheet(context);
                },
              ),
              Consumer<DownloadProvider>(
                builder: (_, downloadProv, __) {
                  final isDownloaded = downloadProv.isDownloaded(song.id);
                  final isDownloading = downloadProv.isDownloading(song.id);

                  return ListTile(
                    leading: isDownloading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primaryAccent,
                            ),
                          )
                        : Icon(
                            isDownloaded ? Icons.delete_outline : Icons.download_rounded,
                            color: isDownloaded ? Colors.redAccent : Colors.white,
                          ),
                    title: Text(
                      isDownloaded
                          ? 'Remove from Downloads'
                          : (isDownloading ? 'Cancel Download' : 'Download Song'),
                      style: TextStyle(
                        color: isDownloaded ? Colors.redAccent : (isDownloading ? Colors.orangeAccent : Colors.white),
                      ),
                    ),
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      if (isDownloaded) {
                        downloadProv.deleteDownload(song.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Download removed')),
                        );
                      } else if (isDownloading) {
                        downloadProv.cancelDownload(song.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Cancelled download of "${song.title}"')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Downloading "${song.title}"...')),
                        );
                        final ok = await downloadProv.startDownload(song);
                        if (context.mounted) {
                          if (ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Downloaded "${song.title}" for offline playback!'),
                                backgroundColor: const Color(0xFF00E676),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(downloadProv.lastError ?? 'Download failed'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                      }
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddToPlaylistSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Consumer<PlaylistProvider>(
          builder: (modalCtx, playlistProv, _) {
            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Add to playlist',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('New'),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => const CreatePlaylistDialog(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white10),
                    if (playlistProv.playlists.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.queue_music, size: 40, color: Colors.white30),
                              SizedBox(height: 8),
                              Text('No playlists yet', style: TextStyle(color: Colors.white70)),
                              SizedBox(height: 4),
                              Text(
                                'Tap "+ New" above to create your first playlist.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          itemCount: playlistProv.playlists.length,
                          itemBuilder: (_, index) {
                            final pl = playlistProv.playlists[index];
                            return ListTile(
                              leading: const Icon(Icons.queue_music, color: AppColors.primaryAccent),
                              title: Text(pl.title, style: const TextStyle(color: Colors.white)),
                              subtitle: Text('${pl.songCount} songs', style: const TextStyle(color: AppColors.textSecondaryDark)),
                              onTap: () {
                                playlistProv.addSongToPlaylist(pl.id, song);
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Added to ${pl.title}')),
                                );
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
