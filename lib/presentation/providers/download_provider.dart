import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/services/download_service.dart';
import '../../domain/entities/song.dart';

class DownloadProvider extends ChangeNotifier {
  List<DownloadItem> _downloads = [];
  final Map<String, double> _downloadProgress = {};
  final Set<String> _activeDownloads = {};
  String? _lastError;

  DownloadProvider() {
    _loadInitialDownloads();
  }

  List<DownloadItem> get downloads => List.unmodifiable(_downloads);
  List<Song> get downloadedSongs =>
      _downloads.where((d) => d.isFileHealthy).map((d) => d.song).toList();
  int get count => _downloads.length;
  int get healthyCount => _downloads.where((d) => d.isFileHealthy).length;
  String? get lastError => _lastError;

  bool isDownloaded(String songId) {
    return _downloads.any((d) =>
        (d.song.id == songId ||
         d.resolvedVideoId == songId ||
         d.localFilePath.contains(songId)) &&
        d.isFileHealthy);
  }

  bool isMissingOrCorrupt(String songId) {
    final item = getDownloadItem(songId);
    if (item == null) return false;
    return !item.isFileHealthy;
  }

  bool isDownloading(String songId) {
    return _activeDownloads.contains(songId);
  }

  double getProgress(String songId) {
    return _downloadProgress[songId] ?? 0.0;
  }

  DownloadItem? getDownloadItem(String songId) {
    try {
      return _downloads.firstWhere((d) =>
          d.song.id == songId ||
          d.resolvedVideoId == songId ||
          d.localFilePath.contains(songId));
    } catch (_) {
      return null;
    }
  }

  void _loadInitialDownloads() {
    _downloads = DownloadService.loadSavedDownloads(onlyHealthy: false);
    notifyListeners();
  }

  void refreshDownloadsHealth() {
    _downloads = DownloadService.loadSavedDownloads(onlyHealthy: false);
    notifyListeners();
  }

  Future<bool> retryDownload(Song song) async {
    _activeDownloads.remove(song.id);
    _downloadProgress.remove(song.id);
    return startDownload(song, forceRedownload: true);
  }

  Future<bool> startDownload(Song song, {bool forceRedownload = false}) async {
    if (!forceRedownload && (isDownloaded(song.id) || isDownloading(song.id))) {
      return true;
    }
    if (isDownloading(song.id)) {
      return true;
    }

    _activeDownloads.add(song.id);
    _downloadProgress[song.id] = 0.08;
    _lastError = null;
    notifyListeners();

    DateTime lastProgressAt = DateTime.now();
    final startedAt = lastProgressAt;
    double lastNotifiedProgress = 0.08;
    DateTime lastNotifyAt = startedAt;
    Timer? watchdogTimer;
    final completer = Completer<DownloadItem?>();

    void failWatchdog(Object err) {
      DownloadService.cancelDownload(song.id);
      if (!completer.isCompleted) {
        completer.completeError(err);
      }
    }

    // Inactivity watchdog: allows large legitimate files (e.g. 120 MB) to finish without hitting a fixed 60s cutoff,
    // while aborting genuinely stalled transfers cleanly within 30s and cleaning up the underlying task.
    watchdogTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final now = DateTime.now();
      if (now.difference(lastProgressAt) >= const Duration(seconds: 30)) {
        failWatchdog(
          TimeoutException('Download stalled for 30 seconds. Please check your connection.'),
        );
      } else if (now.difference(startedAt) >= const Duration(minutes: 10)) {
        failWatchdog(
          TimeoutException('Download exceeded maximum 10-minute duration.'),
        );
      }
    });

    try {
      DownloadService.downloadTrack(
        song: song,
        onProgress: (progress) {
          final current = _downloadProgress[song.id] ?? 0.0;
          final monotonic = progress > current ? progress : current;
          _downloadProgress[song.id] = monotonic;
          lastProgressAt = DateTime.now();
          final now = lastProgressAt;
          if ((monotonic - lastNotifiedProgress).abs() >= 0.01 ||
              monotonic >= 0.99 ||
              now.difference(lastNotifyAt).inMilliseconds >= 90) {
            lastNotifiedProgress = monotonic;
            lastNotifyAt = now;
            notifyListeners();
          }
        },
      ).then((item) {
        if (!completer.isCompleted) {
          completer.complete(item);
        }
      }).catchError((Object err, StackTrace st) {
        if (!completer.isCompleted) {
          completer.completeError(err, st);
        }
      });

      final item = await completer.future;

      if (item != null) {
        _downloads.removeWhere((d) =>
            d.song.id == song.id ||
            d.resolvedVideoId == item.resolvedVideoId);
        _downloads.insert(0, item);
      } else {
        _lastError = 'Download could not resolve a stream.';
      }
      _activeDownloads.remove(song.id);
      _downloadProgress.remove(song.id);
      notifyListeners();
      return item != null;
    } catch (e) {
      _lastError = 'Download failed: $e';
      _activeDownloads.remove(song.id);
      _downloadProgress.remove(song.id);
      notifyListeners();
      return false;
    } finally {
      watchdogTimer.cancel();
    }
  }

  void cancelDownload(String songId) {
    DownloadService.cancelDownload(songId);
    _activeDownloads.remove(songId);
    _downloadProgress.remove(songId);
    _lastError = 'Download cancelled';
    notifyListeners();
  }

  Future<void> deleteDownload(String songId) async {
    await DownloadService.deleteTrack(songId);
    _downloads.removeWhere((d) =>
        d.song.id == songId ||
        d.resolvedVideoId == songId ||
        d.localFilePath.contains(songId));
    notifyListeners();
  }
}
