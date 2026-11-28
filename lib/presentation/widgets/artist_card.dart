import 'package:flutter/material.dart';
import '../../domain/entities/artist.dart';
import '../../core/constants/app_colors.dart';
import '../screens/search/search_screen.dart';
import 'cached_artwork_image.dart';

class ArtistCard extends StatelessWidget {
  final Artist artist;
  final VoidCallback? onTap;

  const ArtistCard({
    super.key,
    required this.artist,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SearchScreen(initialQuery: artist.name),
          ),
        );
      },
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          children: [
            ClipOval(
              child: CachedArtworkImage(
                imageUrl: artist.thumbnailUrl,
                width: 100,
                height: 100,
                fallbackWidget: Container(
                  width: 100,
                  height: 100,
                  color: AppColors.surfaceVariantDark,
                  child: const Icon(Icons.person, color: Colors.white54, size: 40),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              artist.name,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (artist.subscriberCountFormatted.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                artist.subscriberCountFormatted,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
