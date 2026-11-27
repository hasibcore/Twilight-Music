import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../providers/theme_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../providers/search_provider.dart';
import '../../providers/player_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProv = context.watch<ThemeProvider>();
    final playlistProv = context.watch<PlaylistProvider>();
    final searchProv = context.watch<SearchProvider>();
    final isAutoplay = context.select<PlayerProvider, bool>((p) => p.isAutoplay);
    final dividerColor = Theme.of(context).dividerColor.withValues(alpha: 0.1);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        surfaceTintColor: Colors.transparent,
        title: const Text('Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        children: [
          // Appearance
          _buildHeader(context, 'Appearance'),
          ListTile(
            title: Text('Theme Mode', style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.w600)),
            subtitle: Text(
              themeProv.themeMode == ThemeMode.dark
                  ? 'Dark (Recommended for OLED)'
                  : themeProv.themeMode == ThemeMode.light
                      ? 'Light Theme'
                      : 'System Default',
              style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12),
            ),
            trailing: DropdownButton<ThemeMode>(
              value: themeProv.themeMode,
              dropdownColor: AppColors.surface(context),
              underline: const SizedBox(),
              style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.bold),
              items: [
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark', style: TextStyle(color: AppColors.textPrimary(context)))),
                DropdownMenuItem(value: ThemeMode.light, child: Text('Light', style: TextStyle(color: AppColors.textPrimary(context)))),
                DropdownMenuItem(value: ThemeMode.system, child: Text('System', style: TextStyle(color: AppColors.textPrimary(context)))),
              ],
              onChanged: (mode) {
                if (mode != null) themeProv.setThemeMode(mode);
              },
            ),
          ),
          Divider(color: dividerColor),

          // Playback
          _buildHeader(context, 'Playback & Performance'),
          SwitchListTile(
            title: Text('Autoplay', style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.w600)),
            subtitle: Text('Automatically play recommended tracks when queue ends',
                style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
            value: isAutoplay,
            activeThumbColor: AppColors.primaryAccent,
            onChanged: (val) {
              themeProv.toggleAutoplay(val);
              context.read<PlayerProvider>().toggleAutoplay(value: val);
            },
          ),
          SwitchListTile(
            title: Text('Stream on Wi-Fi Only', style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.w600)),
            subtitle: Text('Save mobile data by disabling playback on cellular networks',
                style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
            value: themeProv.wifiOnly,
            activeThumbColor: AppColors.primaryAccent,
            onChanged: (val) => themeProv.toggleWifiOnly(val),
          ),
          SwitchListTile(
            title: Text('Data Saver Mode', style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.w600)),
            subtitle: Text('Request lower bitrate streams to save bandwidth',
                style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
            value: themeProv.dataSaver,
            activeThumbColor: AppColors.primaryAccent,
            onChanged: (val) => themeProv.toggleDataSaver(val),
          ),
          Divider(color: dividerColor),

          // History & Privacy
          _buildHeader(context, 'History & Privacy'),
          ListTile(
            title: Text('Clear Search History', style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.w600)),
            subtitle: Text('Remove all saved search suggestions', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
            trailing: Icon(Icons.delete_outline, color: AppColors.icon(context)),
            onTap: () async {
              await searchProv.clearHistory();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Search history cleared')),
                );
              }
            },
          ),
          ListTile(
            title: Text('Clear Playback History', style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.w600)),
            subtitle: Text('Reset recently played songs list', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
            trailing: Icon(Icons.history_toggle_off, color: AppColors.icon(context)),
            onTap: () async {
              await playlistProv.clearRecentlyPlayed();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Playback history cleared')),
                );
              }
            },
          ),
          Divider(color: dividerColor),

          // About & Compliance
          _buildHeader(context, 'About & Legal'),
          ListTile(
            title: Text('App Version', style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.w600)),
            subtitle: Text('Twilight Music Player v3.6.2 (Build 62)',
                style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Latest',
                  style: TextStyle(
                      color: AppColors.primaryAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          ListTile(
            title: Text('YouTube & Spotify Disclaimer', style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.w600)),
            subtitle: Text('Third-party API and content fair use policy',
                style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
            trailing: Icon(Icons.chevron_right, color: AppColors.iconMuted(context)),
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: AppColors.surface(context),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: const Text('Content Disclaimer'),
                  content: Text(
                    '• Twilight Music utilizes public YouTube API streams for media playback.\n'
                    '• Twilight is not affiliated with, authorized, or endorsed by Google LLC, YouTube, or Spotify AB.\n'
                    '• All trademarks and copyright remain the sole property of their respective owners.',
                    style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13, height: 1.4),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Understood', style: TextStyle(color: AppColors.primaryAccent)),
                    ),
                  ],
                ),
              );
            },
          ),
          ListTile(
            title: Text('Open Source Licenses', style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.w600)),
            trailing: Icon(Icons.chevron_right, color: AppColors.iconMuted(context)),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Twilight Music Player',
              applicationVersion: '3.0.0',
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.primaryAccent,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
