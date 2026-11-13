import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/playlist.dart';
import '../../../domain/entities/song.dart';
import '../../providers/playlist_provider.dart';
import '../../providers/player_provider.dart';
import '../../widgets/song_card.dart';
import '../../widgets/mini_player_widget.dart';
import '../main_navigation_screen.dart';

class PlaylistDetailScreen extends StatelessWidget {
  final Playlist playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  Widget build(BuildContext context) {
    final playlistProv = context.watch<PlaylistProvider>();
    // Find live playlist instance from provider
    final currentPl = playlistProv.playlists.firstWhere(
      (p) => p.id == playlist.id,
      orElse: () => playlist,
    );

    return Scaffold(
      appBar: AppBar(
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              if (val == 'rename') {
                _showRenameDialog(context, currentPl);
              } else if (val == 'delete') {
                _confirmDelete(context, currentPl);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename Playlist')),
              PopupMenuItem(value: 'delete', child: Text('Delete Playlist')),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Artwork
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: currentPl.thumbnailUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: currentPl.thumbnailUrl,
                      width: 180,
                      height: 180,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 180,
                        height: 180,
                        color: AppColors.surfaceVariantDark,
                        child: const Icon(Icons.queue_music, size: 60, color: Colors.white38),
                      ),
                    )
                  : Container(
                      width: 180,
                      height: 180,
                      color: AppColors.surfaceVariantDark,
                      child: const Icon(Icons.queue_music, size: 60, color: Colors.white38),
                    ),
            ),
            const SizedBox(height: 16),
            // Title
            Text(
              currentPl.title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary(context)),
            ),
            const SizedBox(height: 4),
            Text(
              '${currentPl.songCount} songs • ${currentPl.description}',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Actions: Play All & Shuffle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Play All', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: currentPl.songs.isEmpty
                          ? null
                          : () {
                              context.read<PlayerProvider>().selectAndPlaySong(
                                    currentPl.songs.first,
                                    newQueue: currentPl.songs,
                                    queueIndex: 0,
                                  );
                            },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary(context),
                        side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      icon: const Icon(Icons.shuffle),
                      label: const Text('Shuffle'),
                      onPressed: currentPl.songs.isEmpty
                          ? null
                          : () {
                              final shuffled = List<Song>.from(currentPl.songs)..shuffle();
                              context.read<PlayerProvider>().selectAndPlaySong(
                                    shuffled.first,
                                    newQueue: shuffled,
                                    queueIndex: 0,
                                  );
                            },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Divider(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),

            // Songs List
            if (currentPl.songs.isEmpty)
              Padding(
                padding: const EdgeInsets.all(40),
                child: Text(
                  'This playlist is empty.\nAdd songs using the three-dot menu on any track.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary(context), height: 1.4),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: currentPl.songs.length,
                itemBuilder: (_, index) {
                  final song = currentPl.songs[index];
                  return Dismissible(
                    key: Key('${song.id}_$index'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: AppColors.error,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) {
                      playlistProv.removeSongFromPlaylist(currentPl.id, song.id);
                    },
                    child: SongCard(
                      song: song,
                      queueContext: currentPl.songs,
                      variant: SongCardVariant.listTile,
                    ),
                  );
                },
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: (context.findAncestorWidgetOfExactType<MainNavigationScreen>() == null &&
              context.watch<PlayerProvider>().currentSong != null)
          ? const SafeArea(top: false, child: MiniPlayerWidget())
          : null,
    );
  }

  void _showRenameDialog(BuildContext context, Playlist pl) {
    final controller = TextEditingController(text: pl.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text('Rename Playlist'),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: 'New Title'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final val = controller.text.trim();
              if (val.isNotEmpty) {
                context.read<PlaylistProvider>().renamePlaylist(pl.id, val);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Playlist pl) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text('Delete Playlist'),
        content: Text('Are you sure you want to delete "${pl.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              final nav = Navigator.of(context);
              context.read<PlaylistProvider>().deletePlaylist(pl.id);
              Navigator.pop(ctx);
              if (nav.canPop()) {
                nav.pop(); // Pop detail page
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
