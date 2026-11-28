import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/artwork_service.dart';
import '../../core/utils/formatters.dart';
import '../screens/player/full_player_screen.dart';
import '../screens/player/queue_screen.dart';
import 'cached_artwork_image.dart';

class MiniPlayerWidget extends StatelessWidget {
  const MiniPlayerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final playlistProv = context.watch<PlaylistProvider>();
    final currentSong = player.currentSong;

    if (currentSong == null) {
      return const SizedBox.shrink();
    }

    final isFav = playlistProv.isSongFavorite(currentSong.id);

    // Calculate progress ratio
    double progress = 0.0;
    if (player.totalDuration.inMilliseconds > 0) {
      progress = (player.currentPosition.inMilliseconds / player.totalDuration.inMilliseconds).clamp(0.0, 1.0);
    }

    const bgColor = Color(0xF20F172A); // slate-900 with 0.95 alpha (never white)
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    const iconColor = Colors.white;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, anim, secAnim) => const FullPlayerScreen(),
            transitionsBuilder: (context, anim, secAnim, child) {
              const begin = Offset(0.0, 1.0);
              const end = Offset.zero;
              final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: Curves.easeOutCubic));
              return SlideTransition(position: anim.drive(tween), child: child);
            },
          ),
        );
      },
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! < -300) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FullPlayerScreen()),
            );
          } else if (details.primaryVelocity! > 300) {
            player.stop();
          }
        }
      },
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! < -300) {
            player.next();
          } else if (details.primaryVelocity! > 300) {
            player.previous();
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.10),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Gradient Progress Bar at top edge (matching AI Studio Web MiniPlayer)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 3,
                width: double.infinity,
                child: Stack(
                  children: [
                    Container(color: Colors.white10),
                    FractionallySizedBox(
                      widthFactor: progress,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFFA855F7), Color(0xFFF43F5E)],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  // Thumbnail (keyed to currentSong.id + normalized HQ URL + local file sync)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Builder(
                      builder: (_) {
                        final syncedFile = ArtworkService.getSyncedLocalArtworkFile(currentSong.id);
                        if (syncedFile != null) {
                          return Image.file(
                            syncedFile,
                            key: ValueKey('mini_sync_${currentSong.id}_${syncedFile.path}'),
                            width: 46,
                            height: 46,
                            fit: BoxFit.cover,
                          );
                        }
                        final normalizedThumb = ArtworkService.normalizeThumbnailUrl(
                          currentSong.thumbnailUrl,
                          songId: currentSong.id,
                        );
                        if (normalizedThumb.isNotEmpty) {
                          return CachedArtworkImage(
                            key: ValueKey('mini_net_${currentSong.id}_$normalizedThumb'),
                            imageUrl: normalizedThumb,
                            songId: currentSong.id,
                            width: 46,
                            height: 46,
                            disableFade: true,
                            memCacheWidth: 140,
                            fallbackWidget: Container(
                              width: 46,
                              height: 46,
                              color: const Color(0xFF1E293B),
                              child: Icon(Icons.music_note, color: secondaryTextColor),
                            ),
                          );
                        }
                        return Container(
                          key: ValueKey('mini_empty_${currentSong.id}'),
                          width: 46,
                          height: 46,
                          color: const Color(0xFF1E293B),
                          child: Icon(Icons.music_note, color: secondaryTextColor),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Title, Artist & Live Time Counter (overflow-safe single-line artist + time)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currentSong.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: primaryTextColor,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          player.errorMessage ??
                              '${currentSong.artist} • ${Formatters.formatDuration(player.currentPosition)} / ${Formatters.formatDuration(player.totalDuration.inSeconds > 0 ? player.totalDuration : Duration(seconds: currentSong.durationSeconds))}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: player.errorMessage != null
                                ? const Color(0xFFFB7185)
                                : secondaryTextColor,
                            fontSize: 11.0,
                            fontWeight: player.errorMessage != null
                                ? FontWeight.w600
                                : FontWeight.normal,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Favorite Heart Button
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: Icon(
                      isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: isFav ? const Color(0xFFF43F5E) : secondaryTextColor,
                      size: 19,
                    ),
                    onPressed: () => playlistProv.toggleFavorite(currentSong),
                  ),
                  // Previous Track Button
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: const Icon(Icons.skip_previous_rounded, color: iconColor, size: 22),
                    onPressed: () => player.previous(),
                  ),
                  // Circular White Play / Pause Pill Button (matching AI Studio Web UI)
                  GestureDetector(
                    onTap: () {
                      if (player.errorMessage != null) {
                        player.retryCurrentSong();
                      } else {
                        player.togglePlayPause();
                      }
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: player.errorMessage != null ? Colors.redAccent : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.15),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: player.isLoading
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Color(0xFF0F172A),
                              ),
                            )
                          : player.errorMessage != null
                              ? const Icon(
                                  Icons.refresh_rounded,
                                  color: Colors.white,
                                  size: 19,
                                )
                              : Icon(
                                  player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  color: const Color(0xFF0F172A),
                                  size: 22,
                                ),
                    ),
                  ),
                  // Next Track Button
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: const Icon(Icons.skip_next_rounded, color: iconColor, size: 22),
                    onPressed: () => player.next(),
                  ),
                  // Queue Drawer Button
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: Icon(Icons.queue_music_rounded, color: secondaryTextColor, size: 20),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const QueueScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

