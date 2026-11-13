import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/song.dart';
import '../../../domain/repositories/youtube_repository.dart';
import '../../widgets/song_card.dart';
import '../../widgets/import_playlist_dialog.dart';
import '../../providers/player_provider.dart';
import '../../../core/services/music_import_service.dart';
import '../main_navigation_screen.dart';
import '../../widgets/app_logo.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  String? _selectedGenre;
  bool _isLoadingGenre = false;
  List<Song> _genreSongs = [];

  final List<Map<String, dynamic>> _genreData = [
    {'title': 'Pop', 'gradient': const [Color(0xFFE91E63), Color(0xFFC2185B)]},
    {'title': 'Rock', 'gradient': const [Color(0xFFD32F2F), Color(0xFF7B1FA2)]},
    {'title': 'Hip-Hop', 'gradient': const [Color(0xFFFF9800), Color(0xFFE65100)]},
    {'title': 'EDM', 'gradient': const [Color(0xFF00BCD4), Color(0xFF0097A7)]},
    {'title': 'Classical', 'gradient': const [Color(0xFF5D4037), Color(0xFF3E2723)]},
    {'title': 'Lo-fi', 'gradient': const [Color(0xFF7E57C2), Color(0xFF512DA8)]},
    {'title': 'Bollywood', 'gradient': const [Color(0xFFFF5722), Color(0xFFBF360C)]},
    {'title': 'Bangla', 'gradient': const [Color(0xFF00897B), Color(0xFF004D40)]},
    {'title': 'K-pop', 'gradient': const [Color(0xFFEC407A), Color(0xFF880E4F)]},
    {'title': 'Instrumental', 'gradient': const [Color(0xFF455A64), Color(0xFF263238)]},
    {'title': 'Islamic/Nasheed', 'gradient': const [Color(0xFF2E7D32), Color(0xFF1B5E20)]},
  ];

  Future<void> _loadGenreSongs(String genre) async {
    setState(() {
      _selectedGenre = genre;
      _isLoadingGenre = true;
    });

    try {
      final repo = context.read<YouTubeRepository>();
      final songs = await repo.getMusicByGenre(genre);

      if (mounted) {
        setState(() {
          _genreSongs = songs;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _genreSongs = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingGenre = false;
        });
      }
    }
  }

  Future<void> _loadGlobalCharts() async {
    setState(() {
      _selectedGenre = 'Global Top 50';
      _isLoadingGenre = true;
    });

    try {
      final songs = await MusicImportService().getGlobalTopCharts();
      if (mounted) {
        setState(() {
          _genreSongs = songs.isNotEmpty ? songs : [];
        });
        if (songs.isEmpty) {
          _loadGenreSongs('Top Global Hits');
        }
      }
    } catch (_) {
      if (mounted) {
        _loadGenreSongs('Top Global Hits');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingGenre = false;
        });
      }
    }
  }

  void _openImportDialog() {
    showDialog(
      context: context,
      builder: (_) => const ImportPlaylistDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCurrentSong = context.select<PlayerProvider, bool>((p) => p.currentSong != null);
    final bottomPadding = hasCurrentSong ? 100.0 : 40.0;

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
                  AppLogo(
                    size: 38,
                    showText: true,
                    subtitle: 'MUSIC',
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.link_rounded, color: Color(0xFFCBD5E1), size: 22),
                        tooltip: 'Import Playlist Link',
                        onPressed: _openImportDialog,
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
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Section Heading (Matching AI Studio PC Web UI)
            const Text(
              'DISCOVER & EXPLORE',
              style: TextStyle(
                color: Color(0xFF818CF8),
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Genres, Moods & Charts',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 20),
            // Top action buttons: New Releases, Global Charts, Import Link
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTopActionTile(
                      icon: Icons.new_releases_outlined,
                      label: 'New Releases',
                      color: const Color(0xFF1E88E5),
                      onTap: () => _loadGenreSongs('New Music 2026'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTopActionTile(
                      icon: Icons.trending_up_rounded,
                      label: 'Global Charts',
                      color: const Color(0xFF00C853),
                      onTap: _loadGlobalCharts,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTopActionTile(
                      icon: Icons.link_rounded,
                      label: 'Import Link',
                      color: const Color(0xFFD81B60),
                      onTap: _openImportDialog,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Active Genre view or Genre selection grid
            if (_selectedGenre != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '$_selectedGenre Hits (${_genreSongs.length})',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary(context)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_genreSongs.isNotEmpty)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: const Text('Play All', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          context.read<PlayerProvider>().selectAndPlaySong(
                                _genreSongs.first,
                                newQueue: _genreSongs,
                                queueIndex: 0,
                              );
                        },
                      ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedGenre = null;
                          _genreSongs = [];
                        });
                      },
                      child: Text('Clear', style: TextStyle(color: AppColors.textSecondary(context))),
                    ),
                  ],
                ),
              ),
              if (_isLoadingGenre)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: AppColors.primaryAccent),
                  ),
                )
              else if (_genreSongs.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          'No tracks found for "$_selectedGenre".',
                          style: TextStyle(color: AppColors.textSecondary(context)),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => _loadGenreSongs(_selectedGenre!),
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _genreSongs.length,
                  itemBuilder: (_, index) {
                    return SongCard(
                      song: _genreSongs[index],
                      queueContext: _genreSongs,
                      variant: SongCardVariant.listTile,
                    );
                  },
                ),
              const SizedBox(height: 24),
            ],

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Moods & Genres',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(context),
                ),
              ),
            ),

            // 2-Column Responsive Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 2.3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _genreData.length,
                itemBuilder: (_, index) {
                  final item = _genreData[index];
                  final title = item['title'] as String;
                  final gradientColors = item['gradient'] as List<Color>;

                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _loadGenreSongs(title),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradientColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
