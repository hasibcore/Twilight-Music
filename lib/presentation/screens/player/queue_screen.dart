import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../widgets/cached_artwork_image.dart';

class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final currentSong = player.currentSong;
    final queue = player.queue;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Queue'),
        actions: [
          if (queue.length > 1)
            IconButton(
              icon: const Icon(Icons.playlist_add),
              tooltip: AppStrings.saveQueueAsPlaylist,
              onPressed: () => _showSaveQueueDialog(context),
            ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: AppStrings.clearQueue,
            onPressed: () {
              player.clearQueue();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Queue cleared')),
              );
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Now Playing Banner
          if (currentSong != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                AppStrings.nowPlaying,
                style: TextStyle(
                  color: AppColors.primaryAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CachedArtworkImage(
                  imageUrl: currentSong.thumbnailUrl,
                  songId: currentSong.id,
                  width: 50,
                  height: 50,
                  fallbackWidget: Container(
                    width: 50,
                    height: 50,
                    color: AppColors.surfaceVariantDark,
                    child: const Icon(Icons.music_note, color: Colors.white38),
                  ),
                ),
              ),
              title: Text(
                currentSong.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              subtitle: Text(
                currentSong.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondaryDark),
              ),
              trailing: const Icon(Icons.graphic_eq, color: AppColors.primaryAccent),
            ),
            const Divider(color: Colors.white10),
          ],

          // Up Next Reorderable List
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              AppStrings.upNext,
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 1.0,
              ),
            ),
          ),
          Expanded(
            child: queue.isEmpty
                ? const Center(
                    child: Text('Queue is empty', style: TextStyle(color: Colors.white38)),
                  )
                : ReorderableListView.builder(
                    itemCount: queue.length,
                    onReorderItem: (oldIndex, newIndex) {
                      player.reorderItem(oldIndex, newIndex);
                    },
                    itemBuilder: (_, index) {
                      final item = queue[index];
                      final isCurrent = item.id == currentSong?.id;

                      return Dismissible(
                        key: ValueKey('${item.id}_$index'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: AppColors.error,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) {
                          player.removeFromQueue(index);
                        },
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: CachedArtworkImage(
                              imageUrl: item.thumbnailUrl,
                              songId: item.id,
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
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isCurrent ? AppColors.primaryAccent : Colors.white,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            item.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 12),
                          ),
                          trailing: const Icon(Icons.drag_handle, color: Colors.white38),
                          onTap: () {
                            player.selectAndPlaySong(item, queueIndex: index);
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: const BoxDecoration(
          color: AppColors.surfaceVariantDark,
          border: Border(top: BorderSide(color: Colors.white10)),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: player.isAutoplay ? AppColors.primaryAccent.withValues(alpha: 0.15) : Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.autorenew_rounded,
                  color: player.isAutoplay ? AppColors.primaryAccent : Colors.white54,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Autoplay Similar Tracks',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      'Keep music playing when queue ends',
                      style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Switch(
                value: player.isAutoplay,
                activeThumbColor: AppColors.primaryAccent,
                onChanged: (val) {
                  player.toggleAutoplay(value: val);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(val ? 'Autoplay Enabled' : 'Autoplay Disabled'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSaveQueueDialog(BuildContext context) {
    final titleController = TextEditingController(text: 'My Queue Playlist');
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text('Save Queue as Playlist'),
        content: TextField(
          controller: titleController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Playlist Title',
            labelStyle: TextStyle(color: AppColors.textSecondaryDark),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final title = titleController.text.trim();
              if (title.isNotEmpty) {
                final playlistProv = context.read<PlaylistProvider>();
                final player = context.read<PlayerProvider>();
                final created = await playlistProv.createPlaylist(title, description: 'Saved from music queue');
                for (final s in player.queue) {
                  await playlistProv.addSongToPlaylist(created.id, s);
                }
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Queue saved to "$title"')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
