import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/services/artwork_service.dart';
import '../../../core/services/lyrics_service.dart';
import '../../providers/download_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../widgets/cached_artwork_image.dart';
import '../playlist/create_playlist_dialog.dart';
import 'queue_screen.dart';

class FullPlayerScreen extends StatefulWidget {
  const FullPlayerScreen({super.key});

  @override
  State<FullPlayerScreen> createState() => _FullPlayerScreenState();
}

class _FullPlayerScreenState extends State<FullPlayerScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  bool _isDraggingSlider = false;
  double _dragValue = 0.0;
  String? _currentSongId;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final playlistProv = context.watch<PlaylistProvider>();
    final downloadProv = context.watch<DownloadProvider>();
    final currentSong = player.currentSong;

    if (currentSong == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('No song currently playing')),
      );
    }

    if (_currentSongId != currentSong.id) {
      _currentSongId = currentSong.id;
      _isDraggingSlider = false;
    }

    if (player.isPlaying) {
      _animController.repeat();
    } else {
      _animController.stop();
    }

    final isFav = playlistProv.isSongFavorite(currentSong.id);
    final isDownloaded = downloadProv.isDownloaded(currentSong.id);
    final isDownloading = downloadProv.isDownloading(currentSong.id);
    final downloadProgress = downloadProv.getProgress(currentSong.id);


    final currentSecs = player.currentPosition.inSeconds.toDouble();
    final totalSecs = player.totalDuration.inSeconds.toDouble().clamp(1.0, 86400.0);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildBlurredBackgroundWidget(currentSong, downloadProv),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.65),
                  const Color(0xFF0A0E17).withValues(alpha: 0.88),
                  const Color(0xFF0A0E17),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down, size: 34, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Column(
                      children: [
                        const Text(
                          'PLAYING ON TWILIGHT',
                          style: TextStyle(
                            color: AppColors.textTertiaryDark,
                            fontSize: 10,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          isDownloaded ? 'Offline Mode (Downloaded)' : player.audioQuality,
                          style: TextStyle(
                            color: isDownloaded ? const Color(0xFF00E676) : Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Sleep Timer Quick Icon
                        IconButton(
                          icon: Icon(
                            Icons.timer_outlined,
                            color: player.hasActiveSleepTimer ? AppColors.primaryAccent : Colors.white70,
                            size: 22,
                          ),
                          tooltip: player.hasActiveSleepTimer
                              ? 'Timer: ${player.sleepTimerFormatted}'
                              : 'Sleep Timer',
                          onPressed: () => _showSleepTimerSheet(context, player),
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_vert, color: Colors.white),
                          onPressed: () => _showContextMenu(context, currentSong, downloadProv, player),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // Beautiful Artwork Display
              Center(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  height: MediaQuery.of(context).size.width * 0.85,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _buildArtworkWidget(currentSong, downloadProv),
                  ),
                ),
              ),
              const Spacer(),

              // Song Info & Actions (Like, Download, Add to Playlist)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentSong.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentSong.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondaryDark,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Like button with Spotify green / primary accent
                    IconButton(
                      icon: Icon(
                        isFav ? Icons.favorite : Icons.favorite_border,
                        color: isFav ? AppColors.primaryAccent : Colors.white,
                        size: 26,
                      ),
                      onPressed: () => playlistProv.toggleFavorite(currentSong),
                    ),
                    // Download button
                    IconButton(
                      icon: isDownloading
                          ? Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    value: downloadProgress > 0.08 ? downloadProgress : null,
                                    strokeWidth: 2.5,
                                    color: const Color(0xFF00E676),
                                  ),
                                ),
                                const Icon(
                                  Icons.close,
                                  size: 13,
                                  color: Colors.white,
                                ),
                              ],
                            )
                          : Icon(
                              isDownloaded
                                  ? Icons.download_done_rounded
                                  : Icons.download_rounded,
                              color: isDownloaded ? const Color(0xFF00E676) : Colors.white,
                              size: 26,
                            ),
                      tooltip: isDownloading
                          ? 'Downloading ${(downloadProgress * 100).toInt()}% (Tap to cancel)'
                          : (isDownloaded ? 'Downloaded' : 'Download for offline playback'),
                      onPressed: () => _handleDownloadTap(context, currentSong, downloadProv),
                    ),
                    // Add to playlist
                    IconButton(
                      icon: const Icon(Icons.playlist_add, color: Colors.white, size: 26),
                      onPressed: () => _showAddToPlaylist(context, currentSong),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Scrubber Progress Slider
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                        activeTrackColor: AppColors.primaryAccent,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: Colors.white,
                      ),
                      child: Slider(
                        value: _isDraggingSlider
                            ? _dragValue.clamp(0.0, totalSecs)
                            : currentSecs.clamp(0.0, totalSecs),
                        min: 0.0,
                        max: totalSecs,
                        onChangeStart: (val) {
                          player.beginUserSeek();
                          setState(() {
                            _isDraggingSlider = true;
                            _dragValue = val;
                          });
                        },
                        onChanged: (val) {
                          setState(() {
                            _dragValue = val;
                          });
                        },
                        onChangeEnd: (val) {
                          setState(() {
                            _isDraggingSlider = false;
                          });
                          player.endUserSeek(Duration(seconds: val.toInt()));
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _isDraggingSlider
                                ? Formatters.formatDuration(Duration(seconds: _dragValue.toInt()))
                                : Formatters.formatDuration(player.currentPosition),
                            style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 12),
                          ),
                          Text(
                            Formatters.formatDuration(player.totalDuration),
                            style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Player Controls (Shuffle, Prev, Play/Pause, Next, Repeat)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.shuffle,
                        color: player.isShuffle ? AppColors.primaryAccent : Colors.white60,
                        size: 26,
                      ),
                      onPressed: () => player.toggleShuffle(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 40),
                      onPressed: () => player.previous(),
                    ),
                    // Large Play/Pause button
                    GestureDetector(
                      onTap: () {
                        if (player.errorMessage != null) {
                          // Tap to retry on error
                          player.retryCurrentSong();
                        } else {
                          player.togglePlayPause();
                        }
                      },
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: player.errorMessage != null
                              ? Colors.redAccent.withValues(alpha: 0.85)
                              : Colors.white,
                        ),
                        child: Center(
                          child: player.isLoading
                              ? const SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: Colors.black,
                                  ),
                                )
                              : player.errorMessage != null
                                  ? const Icon(
                                      Icons.refresh_rounded,
                                      color: Colors.white,
                                      size: 38,
                                    )
                                  : Icon(
                                      player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                      color: Colors.black,
                                      size: 40,
                                    ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 40),
                      onPressed: () => player.next(),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.repeat,
                        color: player.isRepeat ? AppColors.primaryAccent : Colors.white60,
                        size: 26,
                      ),
                      onPressed: () => player.toggleRepeat(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Spotify Features Row (Speed, Autoplay, Lyrics, Queue)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Playback speed chip
                    GestureDetector(
                      onTap: () => _showSpeedSelectorSheet(context, player),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariantDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.speed, size: 14, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text(
                              '${player.playbackSpeed}x',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Autoplay quick-toggle chip
                    GestureDetector(
                      onTap: () {
                        player.toggleAutoplay();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                Icon(
                                  player.isAutoplay ? Icons.autorenew_rounded : Icons.pause_circle_outline,
                                  color: player.isAutoplay ? AppColors.primaryAccent : Colors.white70,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(player.isAutoplay ? 'Autoplay: ON (Endless Playback)' : 'Autoplay: OFF'),
                              ],
                            ),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: player.isAutoplay ? AppColors.primaryAccent.withValues(alpha: 0.2) : AppColors.surfaceVariantDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: player.isAutoplay ? AppColors.primaryAccent : Colors.white12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.autorenew_rounded,
                              size: 14,
                              color: player.isAutoplay ? AppColors.primaryAccent : Colors.white70,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              player.isAutoplay ? 'Auto ON' : 'Auto OFF',
                              style: TextStyle(
                                color: player.isAutoplay ? AppColors.primaryAccent : Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Lyrics button
                    GestureDetector(
                      onTap: () => _showLyricsSheet(context, currentSong),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariantDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lyrics_outlined, size: 14, color: Colors.white70),
                            SizedBox(width: 4),
                            Text(
                              'Lyrics',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Up Next Queue Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surfaceVariantDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      icon: const Icon(Icons.queue_music, size: 15),
                      label: Text('Queue (${player.queue.length})', style: const TextStyle(fontSize: 11)),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const QueueScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        ],
      ),
    );
  }

  Widget _buildBlurredBackgroundWidget(dynamic currentSong, DownloadProvider downloadProv) {
    final String songId = currentSong.id?.toString() ?? '';
    final String normalizedThumb = ArtworkService.normalizeThumbnailUrl(
      currentSong.thumbnailUrl?.toString(),
      songId: songId,
    );

    final downloadedItem = downloadProv.getDownloadItem(songId);
    final localDownloadThumb = downloadedItem?.localThumbnailPath;
    if (localDownloadThumb != null && File(localDownloadThumb).existsSync()) {
      return ImageFiltered(
        key: ValueKey('bg_dl_${songId}_$localDownloadThumb'),
        imageFilter: ImageFilter.blur(sigmaX: 38, sigmaY: 38),
        child: Image.file(
          File(localDownloadThumb),
          fit: BoxFit.cover,
        ),
      );
    }

    final syncedLocalFile = ArtworkService.getSyncedLocalArtworkFile(songId);
    if (syncedLocalFile != null) {
      return ImageFiltered(
        key: ValueKey('bg_sync_${songId}_${syncedLocalFile.path}'),
        imageFilter: ImageFilter.blur(sigmaX: 38, sigmaY: 38),
        child: Image.file(
          syncedLocalFile,
          fit: BoxFit.cover,
        ),
      );
    }

    if (normalizedThumb.isNotEmpty) {
      return ImageFiltered(
        key: ValueKey('bg_net_${songId}_$normalizedThumb'),
        imageFilter: ImageFilter.blur(sigmaX: 38, sigmaY: 38),
        child: CachedArtworkImage(
          key: ValueKey('bg_cni_${songId}_$normalizedThumb'),
          imageUrl: normalizedThumb,
          songId: songId,
          disableFade: true,
          placeholderWidget: Container(
            decoration: const BoxDecoration(gradient: AppColors.playerGradient),
          ),
          fallbackWidget: Container(
            decoration: const BoxDecoration(gradient: AppColors.playerGradient),
          ),
        ),
      );
    }

    return Container(
      key: ValueKey('bg_empty_$songId'),
      decoration: const BoxDecoration(gradient: AppColors.playerGradient),
    );
  }

  Widget _buildArtworkWidget(dynamic currentSong, DownloadProvider downloadProv) {
    final String songId = currentSong.id?.toString() ?? '';
    final String normalizedThumb = ArtworkService.normalizeThumbnailUrl(
      currentSong.thumbnailUrl?.toString(),
      songId: songId,
    );

    final downloadedItem = downloadProv.getDownloadItem(songId);
    if (downloadedItem != null &&
        downloadedItem.localThumbnailPath != null &&
        File(downloadedItem.localThumbnailPath!).existsSync()) {
      return Image.file(
        File(downloadedItem.localThumbnailPath!),
        key: ValueKey('art_dl_${songId}_${downloadedItem.localThumbnailPath}'),
        fit: BoxFit.cover,
      );
    }

    final syncedLocalFile = ArtworkService.getSyncedLocalArtworkFile(songId);
    if (syncedLocalFile != null) {
      return Image.file(
        syncedLocalFile,
        key: ValueKey('art_sync_${songId}_${syncedLocalFile.path}'),
        fit: BoxFit.cover,
      );
    }

    if (normalizedThumb.isNotEmpty) {
      return CachedArtworkImage(
        key: ValueKey('art_net_${songId}_$normalizedThumb'),
        imageUrl: normalizedThumb,
        songId: songId,
        disableFade: true,
        placeholderWidget: Container(
          color: AppColors.surfaceVariantDark,
          child: const Center(
            child: CircularProgressIndicator(color: AppColors.primaryAccent),
          ),
        ),
        fallbackWidget: Container(
          color: AppColors.surfaceVariantDark,
          child: const Icon(Icons.music_note, size: 80, color: Colors.white24),
        ),
      );
    }

    return Container(
      key: ValueKey('art_empty_$songId'),
      color: AppColors.surfaceVariantDark,
      child: const Icon(Icons.music_note, size: 80, color: Colors.white24),
    );
  }

  void _handleDownloadTap(BuildContext context, dynamic currentSong, DownloadProvider downloadProv) async {
    if (downloadProv.isDownloaded(currentSong.id)) {
      _showDeleteDownloadConfirm(context, currentSong, downloadProv);
    } else if (downloadProv.isDownloading(currentSong.id)) {
      downloadProv.cancelDownload(currentSong.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cancelled download of "${currentSong.title}"'),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloading "${currentSong.title}" for offline playback...'),
          duration: const Duration(seconds: 2),
        ),
      );
      final ok = await downloadProv.startDownload(currentSong);
      if (context.mounted) {
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Downloaded "${currentSong.title}" successfully!'),
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
  }

  void _showDeleteDownloadConfirm(BuildContext context, dynamic song, DownloadProvider downloadProv) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text('Delete Download'),
        content: Text('Are you sure you want to remove "${song.title}" from offline downloads?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              downloadProv.deleteDownload(song.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Download removed')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _showContextMenu(BuildContext context, dynamic song, DownloadProvider downloadProv, PlayerProvider player) {
    final isDownloaded = downloadProv.isDownloaded(song.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.timer_outlined,
                color: player.hasActiveSleepTimer ? AppColors.primaryAccent : Colors.white,
              ),
              title: const Text('Sleep Timer'),
              subtitle: Text(
                player.hasActiveSleepTimer ? 'Active: ${player.sleepTimerFormatted}' : 'Turn off playback automatically',
                style: TextStyle(
                  color: player.hasActiveSleepTimer ? AppColors.primaryAccent : AppColors.textSecondaryDark,
                  fontSize: 12,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _showSleepTimerSheet(context, player);
              },
            ),
            ListTile(
              leading: const Icon(Icons.speed, color: Colors.white),
              title: const Text('Playback Speed'),
              subtitle: Text(
                'Current: ${player.playbackSpeed}x',
                style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                _showSpeedSelectorSheet(context, player);
              },
            ),
            ListTile(
              leading: const Icon(Icons.high_quality, color: Colors.white),
              title: const Text('Audio Streaming Quality'),
              subtitle: Text(
                player.audioQuality,
                style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                _showQualitySelectorSheet(context, player);
              },
            ),
            ListTile(
              leading: Icon(
                isDownloaded ? Icons.delete_outline : Icons.download_rounded,
                color: isDownloaded ? Colors.redAccent : Colors.white,
              ),
              title: Text(isDownloaded ? 'Remove from Downloads' : 'Download Song'),
              onTap: () {
                Navigator.pop(context);
                if (isDownloaded) {
                  _showDeleteDownloadConfirm(context, song, downloadProv);
                } else {
                  _handleDownloadTap(context, song, downloadProv);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add, color: Colors.white),
              title: const Text('Add to playlist'),
              onTap: () {
                Navigator.pop(context);
                _showAddToPlaylist(context, song);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSleepTimerSheet(BuildContext context, PlayerProvider player) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Stop audio in',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (player.hasActiveSleepTimer)
                    TextButton(
                      onPressed: () {
                        player.cancelSleepTimer();
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Sleep timer turned off')),
                        );
                      },
                      child: const Text('Turn Off', style: TextStyle(color: Colors.redAccent)),
                    ),
                ],
              ),
            ),
            const Divider(color: Colors.white10),
            _timerOption(ctx, player, '15 minutes', const Duration(minutes: 15)),
            _timerOption(ctx, player, '30 minutes', const Duration(minutes: 30)),
            _timerOption(ctx, player, '45 minutes', const Duration(minutes: 45)),
            _timerOption(ctx, player, '1 hour', const Duration(hours: 1)),
            _timerOption(
              ctx,
              player,
              'End of this track',
              player.totalDuration > player.currentPosition
                  ? player.totalDuration - player.currentPosition
                  : const Duration(minutes: 3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timerOption(BuildContext ctx, PlayerProvider player, String title, Duration duration) {
    return ListTile(
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white38),
      onTap: () {
        player.setSleepTimer(duration);
        Navigator.pop(ctx);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Audio will stop in $title')),
        );
      },
    );
  }

  void _showSpeedSelectorSheet(BuildContext context, PlayerProvider player) {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Playback Speed',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(color: Colors.white10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: speeds.map((s) {
                final isSelected = player.playbackSpeed == s;
                return ChoiceChip(
                  label: Text('${s}x', style: TextStyle(color: isSelected ? Colors.black : Colors.white)),
                  selected: isSelected,
                  selectedColor: Colors.white,
                  backgroundColor: AppColors.surfaceVariantDark,
                  onSelected: (val) {
                    player.setPlaybackSpeed(s);
                    Navigator.pop(ctx);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showQualitySelectorSheet(BuildContext context, PlayerProvider player) {
    const qualities = [
      'Low (64 kbps - Data Saver)',
      'Normal (128 kbps - Standard)',
      'High (256 kbps - Enhanced AAC)',
      'Very High (320 kbps - Lossless)',
    ];

    const eqPresets = [
      'Flat (Studio Reference)',
      'Bass Boost (Punchy Sub-Bass)',
      'Vocal Booster (Crystal Vocals)',
      'Treble Booster (Crisp Highs)',
      'Rock & Alternative (Dynamic Drive)',
      'Pop & Dance (Vibrant Energy)',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Audio & Sound Settings (Spotify Enhanced)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const Divider(color: Colors.white10),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    'STREAMING BITRATE',
                    style: TextStyle(
                      color: AppColors.textTertiaryDark,
                      fontSize: 11,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...qualities.map((q) {
                  final isSelected = player.audioQuality == q;
                  return ListTile(
                    dense: true,
                    title: Text(q, style: TextStyle(color: isSelected ? AppColors.primaryAccent : Colors.white, fontSize: 13)),
                    trailing: isSelected ? const Icon(Icons.check, color: AppColors.primaryAccent) : null,
                    onTap: () {
                      player.setAudioQuality(q);
                      setSheetState(() {});
                    },
                  );
                }),
                const Divider(color: Colors.white10),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    'SPOTIFY EQUALIZER PRESETS',
                    style: TextStyle(
                      color: AppColors.textTertiaryDark,
                      fontSize: 11,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...eqPresets.map((eq) {
                  final isSelected = player.equalizerPreset == eq;
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.graphic_eq_rounded, color: AppColors.textSecondaryDark, size: 20),
                    title: Text(eq, style: TextStyle(color: isSelected ? AppColors.primaryAccent : Colors.white, fontSize: 13)),
                    trailing: isSelected ? const Icon(Icons.check, color: AppColors.primaryAccent) : null,
                    onTap: () {
                      player.setEqualizerPreset(eq);
                      setSheetState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Equalizer preset applied: $eq'), duration: const Duration(seconds: 1)),
                      );
                    },
                  );
                }),
                const Divider(color: Colors.white10),
                SwitchListTile(
                  dense: true,
                  title: const Text('Autoplay / Song Radio', style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text('Keep playing similar songs when queue ends', style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 12)),
                  value: player.isAutoplay,
                  activeThumbColor: AppColors.primaryAccent,
                  onChanged: (val) {
                    player.toggleAutoplay();
                    setSheetState(() {});
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLyricsSheet(BuildContext context, dynamic song) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1020),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 30,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Lyrics',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            '${song.title} • ${song.artist}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white10),
              Expanded(
                child: FutureBuilder<LyricsResult>(
                  future: LyricsService().getLyrics(title: song.title, artist: song.artist),
                  builder: (ctx, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: AppColors.primaryAccent),
                            SizedBox(height: 16),
                            Text(
                              'Finding lyrics...',
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      );
                    }

                    final lyricsData = snapshot.data;
                    final hasLyrics = lyricsData != null && lyricsData.hasLyrics && lyricsData.plainLyrics != null && lyricsData.plainLyrics!.trim().isNotEmpty;

                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '♪ ${song.title} ♪\n',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryAccent,
                            ),
                          ),
                          if (hasLyrics)
                            Text(
                              lyricsData.plainLyrics!,
                              style: const TextStyle(
                                fontSize: 17,
                                height: 1.8,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            )
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Synchronized lyrics unavailable for this track.\n',
                                  style: TextStyle(color: Colors.white54, fontSize: 14),
                                ),
                                Text(
                                  'Enjoy the acoustic flow and melody of ${song.artist}.\n\n'
                                  'Turn up the volume for enhanced high-fidelity audio.',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    height: 1.7,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 24),
                        ],
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

  void _showAddToPlaylist(BuildContext context, dynamic song) {
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
                            'Save to Playlist',
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
