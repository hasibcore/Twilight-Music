import 'package:flutter/material.dart';
import '../../domain/entities/playlist.dart';
import '../../core/constants/app_colors.dart';
import '../screens/playlist/playlist_detail_screen.dart';
import 'cached_artwork_image.dart';

class PlaylistCard extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback? onTap;

  const PlaylistCard({
    super.key,
    required this.playlist,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PlaylistDetailScreen(playlist: playlist),
          ),
        );
      },
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedArtworkImage(
                imageUrl: playlist.thumbnailUrl,
                width: 150,
                height: 150,
                fallbackWidget: Container(
                  width: 150,
                  height: 150,
                  color: AppColors.surfaceVariantDark,
                  child: const Icon(Icons.queue_music, color: Colors.white38, size: 48),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              playlist.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              playlist.description.isNotEmpty
                  ? playlist.description
                  : '${playlist.songCount} songs',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
