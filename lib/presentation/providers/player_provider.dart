import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart' hide PlayerState;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../data/datasources/youtube_remote_datasource.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/music_repository.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/formatters.dart';
import '../../core/services/youtube_audio_source.dart';
import '../../core/services/audio_stream_extractor.dart';
import '../../core/services/artwork_service.dart';
import '../../core/services/download_service.dart';
import '../../core/services/music_import_service.dart';
import '../../core/services/local_storage_service.dart';
import 'package:just_audio_background/just_audio_background.dart';

/// Manages music playback using native AudioPlayer (just_audio) with Android
/// MediaSession / AudioService background notifications, high-bitrate audio streaming,
/// progressive offline caching, and Spotify-grade power features.
class PlayerProvider extends ChangeNotifier {
  final MusicRepository musicRepository;
  final YoutubeExplode _yt = YoutubeExplode();

  AudioPlayer? _audioPlayer;
  StreamSubscription? _playerStateSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _playbackEventSub;

  Song? _currentSong;
  List<Song> _queue = [];
  int _currentIndex = -1;

  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = const Duration(minutes: 3, seconds: 30);

  bool _isShuffle = false;
  bool _isRepeat = false;
  double _playbackSpeed = 1.0;
  String _audioQuality = 'High (256 kbps - Enhanced AAC)';
  String _equalizerPreset = 'Flat (Studio Reference)';
  bool _isAutoplay = true;

  // Spotify Sleep Timer Feature
  Timer? _sleepTimer;
  DateTime? _sleepTimerEndTime;

  // Error skip: only fire ONCE per error, then reset
  Timer? _errorSkipTimer;

  // Watchdog timer to ensure loading indicator never stays stuck
  Timer? _loadingWatchdog;
  Timer? _resumeStallWatchdog;
  Timer? _proactivePauseRefreshTimer;
  Timer? _playDebounceTimer;
  Completer<void>? _pendingPlayCompleter;

  // Throttle position-stream notifications to reduce excessive widget rebuilds
  DateTime _lastPositionNotify = DateTime.fromMillisecondsSinceEpoch(0);

  // Monotonically increasing request counter to cancel stale async playback tasks
  int _playRequestId = 0;

  // True while a song is actively resolving and connecting its stream
  bool _isResolvingSong = false;
  bool _isAutoRecovering = false;
  int _autoRecoveryAttempts = 0;
  static const int _maxRecoveryAttempts = 3;
  static const Duration proactivePauseRefreshThreshold = Duration(minutes: 3);
  static const Duration songSelectionDebounceDuration = Duration(milliseconds: 300);

  // Pause & stream expiry tracking
  bool _intentionalPause = false;
  bool _isPlayingOfflineFile = false;
  bool _isUserSeeking = false;
  bool _isRefreshingStream = false;
  bool _streamPrewarmedWhilePaused = false;
  DateTime? _pausedAt;
  DateTime? _streamResolvedAt;
  int _streamRefreshCount = 0;

  String? _errorMessage;

  bool get _isTest => !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  PlayerProvider({required this.musicRepository}) {
    _isAutoplay = LocalStorageService.getBool('mt_autoplay') ?? true;
    _audioQuality = LocalStorageService.getString('mt_audio_quality') ?? 'High (256 kbps - Enhanced AAC)';
    _equalizerPreset = LocalStorageService.getString('mt_equalizer_preset') ?? 'Flat (Studio Reference)';
    _initAudioPlayer();
  }

  void _initAudioPlayer() {
    try {
      _audioPlayer = AudioPlayer(
        handleInterruptions: true,
        androidApplyAudioAttributes: true,
        handleAudioSessionActivation: true,
      );

      _playerStateSub = _audioPlayer!.playerStateStream.listen((state) {
        if (_isResolvingSong &&
            (state.processingState == ProcessingState.idle ||
             state.processingState == ProcessingState.completed)) {
          // While resolving & buffering a new track, suppress premature idle/completed events
          return;
        }

        // Guard against auto-resuming when the user explicitly paused
        if (_intentionalPause && state.playing) {
          _audioPlayer?.pause();
          _isPlaying = false;
          notifyListeners();
          return;
        }

        if (!_isResolvingSong && !_intentionalPause) {
          _isPlaying = state.playing;
        }

        // Set loading=true during buffering/loading states and arm stall recovery if stuck
        if (state.processingState == ProcessingState.buffering ||
            state.processingState == ProcessingState.loading) {
          _isLoading = true;
          if (!_isResolvingSong && !_intentionalPause && (_loadingWatchdog == null || !_loadingWatchdog!.isActive)) {
            final stalledReqId = _playRequestId;
            _loadingWatchdog = Timer(const Duration(seconds: 12), () {
              if (_isLoading && stalledReqId == _playRequestId && !_intentionalPause && _currentSong != null) {
                AppLogger.networkDisconnect(
                  'playerProvider:buffering',
                  'Buffering stalled for 12s on "${_currentSong!.title}"',
                  category: 'stall',
                  songId: _currentSong!.id,
                  attempt: _autoRecoveryAttempts + 1,
                );
                if (!_isAutoRecovering && _autoRecoveryAttempts < _maxRecoveryAttempts) {
                  unawaited(_autoRecoverPlayback(_currentPosition));
                } else {
                  _isLoading = false;
                  _isPlaying = false;
                  _errorMessage = 'Connection timed out. Tap to retry.';
                  notifyListeners();
                }
              }
            });
          }
        } else if (state.processingState == ProcessingState.ready) {
          // Do not prematurely clear resolving state during initial setAudioSource() before play() starts
          if (!_isResolvingSong || state.playing) {
            _isLoading = false;
            _isResolvingSong = false;
            _loadingWatchdog?.cancel();
            _resumeStallWatchdog?.cancel();
            if (!_intentionalPause) {
              _isPlaying = state.playing;
            }
          }
        } else if (state.processingState == ProcessingState.completed) {
          // Song completed — clear all resolving/loading flags
          _isLoading = false;
          _isResolvingSong = false;
          _loadingWatchdog?.cancel();
          _resumeStallWatchdog?.cancel();
          if (!_intentionalPause) {
            _isPlaying = state.playing;
          }
        }

        if (state.processingState == ProcessingState.completed) {
          if (_intentionalPause || _isResolvingSong || isDebouncePending) return;
          // A song is ONLY naturally completed if it played near its expected duration
          final bool isNearEnd = _totalDuration.inSeconds > 20 &&
              (_currentPosition.inSeconds >= (_totalDuration.inSeconds * 0.85).toInt() ||
               (_totalDuration - _currentPosition).inSeconds <= 15);

          if (isNearEnd) {
            onTrackEnded();
          } else {
            // Premature stream completion (unexpected network drop)
            AppLogger.networkDisconnect(
              'playerProvider:completed',
              'Premature stream completion at ${_currentPosition.inSeconds}s/${_totalDuration.inSeconds}s',
              category: 'premature_eof_disconnect',
              songId: _currentSong?.id,
              attempt: _autoRecoveryAttempts + 1,
            );
            final pos = _currentPosition;
            if (_currentSong != null &&
                !_isAutoRecovering &&
                !_intentionalPause &&
                _autoRecoveryAttempts < _maxRecoveryAttempts) {
              _autoRecoverPlayback(pos);
            } else {
              _isLoading = false;
              _isPlaying = false;
              _loadingWatchdog?.cancel();
              _errorMessage = 'Playback paused. Tap to retry.';
            }
          }
        }

        notifyListeners();
      });

      _positionSub = _audioPlayer!.positionStream.listen((pos) {
        if (_isUserSeeking) return;
        _currentPosition = pos;
        if (_isLoading && pos > Duration.zero) {
          _isLoading = false;
          _loadingWatchdog?.cancel();
          _resumeStallWatchdog?.cancel();
          notifyListeners();
          return;
        }
        if (!_isAutoRecovering && pos.inSeconds >= 2 && _autoRecoveryAttempts > 0) {
          _autoRecoveryAttempts = 0;
        }
        // Throttle position updates to ~300ms to prevent excessive UI rebuilds
        final now = DateTime.now();
        if (now.difference(_lastPositionNotify).inMilliseconds >= 300) {
          _lastPositionNotify = now;
          notifyListeners();
        }
      });

      _durationSub = _audioPlayer!.durationStream.listen((dur) {
        if (dur != null && dur > Duration.zero) {
          _totalDuration = dur;
          notifyListeners();
        }
      });

      // Hard player-level error (codec, network drop mid-stream or startup drop)
      // Attempt bounded auto-recovery before falling back to manual retry
      _playbackEventSub = _audioPlayer!.playbackEventStream.listen(
        (_) {},
        onError: (Object e, StackTrace st) {
          AppLogger.networkDisconnect(
            'playerProvider:playbackEvent',
            'AudioPlayer stream error during playback',
            severity: StreamLogSeverity.error,
            category: 'player_error',
            songId: _currentSong?.id,
            attempt: _autoRecoveryAttempts + 1,
            error: e,
          );
          _loadingWatchdog?.cancel();
          _resumeStallWatchdog?.cancel();
          _errorSkipTimer?.cancel();
          _errorSkipTimer = null;
          if (_intentionalPause) return;
          final pos = _currentPosition;
          if (_currentSong != null &&
              !_isAutoRecovering &&
              _autoRecoveryAttempts < _maxRecoveryAttempts) {
            _autoRecoverPlayback(pos);
          } else {
            _isLoading = false;
            _isPlaying = false;
            _errorMessage = 'Playback interrupted. Tap to retry.';
            if (_currentSong != null) {
              AudioStreamExtractor.invalidateCache(_currentSong!.id);
            }
            notifyListeners();
          }
        },
      );
    } catch (e) {
      AppLogger.info('AudioPlayer init: $e');
    }
  }

  // Compatibility getters
  dynamic get controller => null;
  bool get isPlayerReady => true;
  bool get isUsingFallbackIframe => false;
  void onPlayerReady() {}

  Song? get currentSong => _currentSong;
  // displaySong always matches currentSong to keep UI completely synchronized
  Song? get displaySong => _currentSong;
  List<Song> get queue => _queue;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  bool get isShuffle => _isShuffle;
  bool get isRepeat => _isRepeat;
  double get playbackSpeed => _playbackSpeed;
  String get audioQuality => _audioQuality;
  String get equalizerPreset => _equalizerPreset;
  bool get isAutoplay => _isAutoplay;
  String? get errorMessage => _errorMessage;

  // Sleep Timer Getters
  bool get hasActiveSleepTimer =>
      _sleepTimerEndTime != null && _sleepTimerEndTime!.isAfter(DateTime.now());

  Duration? get sleepTimerRemaining {
    if (_sleepTimerEndTime == null) return null;
    final remaining = _sleepTimerEndTime!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  String get sleepTimerFormatted {
    final rem = sleepTimerRemaining;
    if (rem == null || rem == Duration.zero) return 'Off';
    final minutes = rem.inMinutes;
    final seconds = rem.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  List<Song> get upNextQueue {
    if (_currentIndex >= 0 && _currentIndex + 1 < _queue.length) {
      return _queue.sublist(_currentIndex + 1);
    }
    return [];
  }

  bool get intentionalPause => _intentionalPause;
  bool get isPlayingOfflineFile => _isPlayingOfflineFile;
  bool get isRefreshingStream => _isRefreshingStream;
  bool get isDebouncePending => _playDebounceTimer?.isActive ?? false;
  int get streamRefreshCount => _streamRefreshCount;
  int get playRequestId => _playRequestId;

  void beginUserSeek() {
    _isUserSeeking = true;
  }

  void endUserSeek(Duration targetPosition) {
    _isUserSeeking = false;
    seekTo(targetPosition);
  }

  /// Helper for automated tests to simulate an extended pause duration
  @visibleForTesting
  void simulatePausedDuration(Duration duration) {
    _pausedAt = DateTime.now().subtract(duration);
    if (duration >= proactivePauseRefreshThreshold && _currentSong != null) {
      _streamPrewarmedWhilePaused = false;
      AudioStreamExtractor.invalidateCache(_currentSong!.id);
    }
  }

  String _extractImmediateCleanId(Song song) {
    final raw = song.id.trim();
    final verifiedDownload = DownloadService.findVerifiedDownload(raw);
    if (verifiedDownload != null) {
      return verifiedDownload.resolvedVideoId;
    }
    if (raw.startsWith('sp_') || song.channelId == 'spotify') {
      final knownResolved = MusicImportService.resolveKnownVideoIdByIdOrTitle(
        raw,
        title: song.title,
      );
      if (knownResolved != null && knownResolved.length == 11) {
        return knownResolved;
      }
      return raw;
    }
    try {
      return VideoId(raw).value;
    } catch (_) {
      return raw.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    }
  }

  void _applyOptimisticQueueState(
    Song targetSong,
    Song originalSong, {
    List<Song>? newQueue,
    int? queueIndex,
    Duration? initialPosition,
  }) {
    _currentSong = targetSong;

    int targetIndex = queueIndex ?? -1;

    if (newQueue != null && newQueue.isNotEmpty) {
      if (targetIndex < 0 || targetIndex >= newQueue.length) {
        targetIndex = newQueue.indexWhere(
          (s) => s.id == originalSong.id || s.id == targetSong.id || s.isSameTrack(originalSong),
        );
      }

      _queue = List.from(newQueue);

      if (targetIndex >= 0 && targetIndex < _queue.length) {
        _currentIndex = targetIndex;
        _queue[_currentIndex] = targetSong;
      } else {
        _queue.insert(0, targetSong);
        _currentIndex = 0;
      }
    } else {
      if (targetIndex >= 0 && targetIndex < _queue.length) {
        _currentIndex = targetIndex;
        _queue[_currentIndex] = targetSong;
      } else {
        final existingIndex = _queue.indexWhere(
          (s) => s.id == originalSong.id || s.id == targetSong.id || s.isSameTrack(originalSong),
        );
        if (existingIndex != -1) {
          _currentIndex = existingIndex;
          _queue[_currentIndex] = targetSong;
        } else {
          _queue.add(targetSong);
          _currentIndex = _queue.length - 1;
        }
      }
    }

    final fallbackSecs = targetSong.durationSeconds > 0 ? targetSong.durationSeconds : 210;
    _totalDuration = Duration(seconds: fallbackSecs);
    _currentPosition = initialPosition ?? Duration.zero;
  }

  /// Explicit 'stop current' instruction that clears any pending 300ms debounced
  /// player initialization, cancels active watchdogs, and halts the native audio
  /// player before launching a new track to prevent overlapping audio instances.
  Future<void> stopCurrentBeforeSwitch() async {
    _playDebounceTimer?.cancel();
    _playDebounceTimer = null;
    if (_pendingPlayCompleter != null && !_pendingPlayCompleter!.isCompleted) {
      _pendingPlayCompleter!.complete();
    }
    _pendingPlayCompleter = null;

    _errorSkipTimer?.cancel();
    _errorSkipTimer = null;
    _loadingWatchdog?.cancel();
    _loadingWatchdog = null;
    _resumeStallWatchdog?.cancel();
    _resumeStallWatchdog = null;
    _proactivePauseRefreshTimer?.cancel();
    _proactivePauseRefreshTimer = null;

    _isRefreshingStream = false;
    _isPlaying = false;

    if (_audioPlayer != null && !_isTest) {
      final wasResolving = _isResolvingSong;
      _isResolvingSong = true;
      try {
        await _audioPlayer!.stop();
      } catch (_) {}
      _isResolvingSong = wasResolving;
    } else {
      _isResolvingSong = false;
    }
  }

  /// User-facing song selection & play handler for Search and Queue controllers:
  /// - Toggles play/pause without restarting if the selected song is already active
  /// - Otherwise executes stopCurrentBeforeSwitch(), updates UI state immediately (0ms),
  ///   and debounces stream initialization by 300ms (songSelectionDebounceDuration)
  Future<void> selectAndPlaySong(
    Song song, {
    List<Song>? newQueue,
    List<Song>? queue,
    int? queueIndex,
    Duration? debounceDuration,
  }) async {
    await playSong(
      song,
      newQueue: newQueue ?? queue,
      queueIndex: queueIndex,
      toggleIfSameTrack: true,
      debounceDuration: debounceDuration ?? (_isTest ? Duration.zero : songSelectionDebounceDuration),
    );
  }

  Future<void> playSong(
    Song song, {
    List<Song>? newQueue,
    List<Song>? queue,
    int? queueIndex,
    Duration? initialPosition,
    bool forceRefreshStream = false,
    bool toggleIfSameTrack = false,
    Duration? debounceDuration,
  }) async {
    final effectiveNewQueue = newQueue ?? queue;
    // Confirmed Decision 2: When selecting the song that is already actively playing or paused,
    // toggle play and pause without restarting playback position
    final immediateCleanId = _extractImmediateCleanId(song);
    final isSameActiveTrack = _currentSong != null &&
        (_currentSong!.id == song.id ||
            _currentSong!.id == immediateCleanId ||
            _currentSong!.isSameTrack(song));

    if (toggleIfSameTrack &&
        initialPosition == null &&
        !forceRefreshStream &&
        isSameActiveTrack &&
        _errorMessage == null &&
        !isDebouncePending) {
      if (_isPlaying || _isLoading || _isResolvingSong) {
        pause();
      } else {
        play();
      }
      return;
    }

    final currentRequestId = ++_playRequestId;

    // 1. Synchronously clear any pending debounced initialization and timers
    _playDebounceTimer?.cancel();
    _playDebounceTimer = null;
    if (_pendingPlayCompleter != null && !_pendingPlayCompleter!.isCompleted) {
      _pendingPlayCompleter!.complete();
    }
    _pendingPlayCompleter = null;

    _intentionalPause = false;
    _pausedAt = null;
    _streamPrewarmedWhilePaused = false;
    _isResolvingSong = true;
    _errorMessage = null;
    _isLoading = true;
    _isPlaying = false;
    if (!_isAutoRecovering) {
      _autoRecoveryAttempts = 0;
    }

    // 2. Confirmed Decision 3: Update UI state immediately on tap (0ms latency) before debounce
    final normalizedInitialThumb = ArtworkService.normalizeThumbnailUrl(
      song.thumbnailUrl,
      songId: immediateCleanId,
    );
    final optimisticSong = (song.id == immediateCleanId && song.thumbnailUrl == normalizedInitialThumb)
        ? song
        : Song(
            id: immediateCleanId,
            title: song.title,
            artist: song.artist,
            channelId: song.channelId,
            thumbnailUrl: normalizedInitialThumb,
            durationSeconds: song.durationSeconds,
            durationFormatted: song.durationFormatted,
            viewCount: song.viewCount,
            publishedAt: song.publishedAt,
            isFavorite: song.isFavorite,
          );

    _applyOptimisticQueueState(
      optimisticSong,
      song,
      newQueue: effectiveNewQueue,
      queueIndex: queueIndex,
      initialPosition: initialPosition,
    );
    notifyListeners();

    final effectiveDebounce =
        debounceDuration ?? (_isTest ? Duration.zero : songSelectionDebounceDuration);

    if (effectiveDebounce > Duration.zero) {
      // 3a. Synchronously halt timers and schedule 300ms debounce so isDebouncePending is true at 0ms
      _errorSkipTimer?.cancel();
      _errorSkipTimer = null;
      _loadingWatchdog?.cancel();
      _loadingWatchdog = null;
      _resumeStallWatchdog?.cancel();
      _resumeStallWatchdog = null;
      _proactivePauseRefreshTimer?.cancel();
      _proactivePauseRefreshTimer = null;
      _isRefreshingStream = false;
      _isPlaying = false;
      _isResolvingSong = true;
      _isLoading = true;

      final completer = Completer<void>();
      _pendingPlayCompleter = completer;
      _playDebounceTimer = Timer(effectiveDebounce, () async {
        _playDebounceTimer = null;
        try {
          if (currentRequestId != _playRequestId || _intentionalPause) {
            return;
          }
          await _executeDebouncedStreamLoad(
            song,
            currentRequestId: currentRequestId,
            newQueue: effectiveNewQueue,
            queueIndex: queueIndex,
            initialPosition: initialPosition,
            forceRefreshStream: forceRefreshStream,
          );
        } finally {
          if (!completer.isCompleted) completer.complete();
        }
      });

      if (_audioPlayer != null && !_isTest) {
        try {
          await _audioPlayer!.stop();
        } catch (_) {}
      }
      await completer.future;
      return;
    }

    // 3b. Explicit 'stop current' instruction to halt active native audio decoder immediately
    await stopCurrentBeforeSwitch();
    if (currentRequestId != _playRequestId || _intentionalPause) return;

    // Restore resolving/loading flags after stopCurrentBeforeSwitch
    _isResolvingSong = true;
    _isLoading = true;

    await _executeDebouncedStreamLoad(
      song,
      currentRequestId: currentRequestId,
      newQueue: effectiveNewQueue,
      queueIndex: queueIndex,
      initialPosition: initialPosition,
      forceRefreshStream: forceRefreshStream,
    );
  }

  Future<void> _executeDebouncedStreamLoad(
    Song song, {
    required int currentRequestId,
    List<Song>? newQueue,
    int? queueIndex,
    Duration? initialPosition,
    bool forceRefreshStream = false,
  }) async {
    try {
      if (currentRequestId != _playRequestId || _intentionalPause) return;

      Song effectiveSong = song;
      String cleanId = effectiveSong.id.trim();

      // 1. LOCAL-FIRST OFFLINE SHORT-CIRCUIT:
      // Check verified local downloads BEFORE any network resolution call so Airplane Mode
      // plays downloaded tracks (including `sp_...` imported tracks) immediately!
      final verifiedDownload = DownloadService.findVerifiedDownload(song.id);
      if (verifiedDownload != null) {
        cleanId = verifiedDownload.resolvedVideoId;
        _isPlayingOfflineFile = true;
      } else {
        _isPlayingOfflineFile = false;
        try {
          cleanId = VideoId(cleanId).value;
        } catch (_) {
          cleanId = effectiveSong.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
        }

        if (effectiveSong.id.startsWith('sp_') ||
            effectiveSong.channelId == 'spotify' ||
            cleanId.length != 11) {
          try {
            final resolved = await MusicImportService().resolveStreamTrack(effectiveSong);
            if (resolved != null && !resolved.id.startsWith('sp_')) {
              effectiveSong = resolved;
              try {
                cleanId = VideoId(effectiveSong.id.trim()).value;
              } catch (_) {
                cleanId = effectiveSong.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
              }
            }
          } catch (e) {
            AppLogger.error('Failed to resolve track stream: $e');
          }
        }

        if (currentRequestId != _playRequestId) return;

        // Re-check local downloads with resolved cleanId in case it was downloaded under cleanId
        final resolvedLocal = DownloadService.findVerifiedDownload(cleanId);
        if (resolvedLocal != null) {
          _isPlayingOfflineFile = true;
        } else if (cleanId.length != 11 && !_isTest) {
          try {
            final searchRes = await _yt.search
                .search('${effectiveSong.title} ${effectiveSong.artist}')
                .timeout(const Duration(seconds: 4));
            if (searchRes.isNotEmpty) {
              cleanId = searchRes.first.id.value;
            }
          } catch (_) {}

          if (cleanId.length != 11) {
            final tempClient = http.Client();
            try {
              final ytDatasource = YouTubeRemoteDatasource(client: tempClient, apiKey: '');
              final searchResult = await ytDatasource.searchAll('${effectiveSong.title} ${effectiveSong.artist}');
              if (searchResult.songs.isNotEmpty) {
                cleanId = searchResult.songs.first.id;
              }
            } catch (_) {
            } finally {
              tempClient.close();
            }
          }
        }
      }

      if (currentRequestId != _playRequestId) return;

      final verifiedThumb = ArtworkService.normalizeThumbnailUrl(
        effectiveSong.thumbnailUrl,
        songId: cleanId,
      );

      final targetSong = (effectiveSong.id == cleanId && effectiveSong.thumbnailUrl == verifiedThumb)
          ? effectiveSong
          : Song(
              id: cleanId,
              title: effectiveSong.title,
              artist: effectiveSong.artist,
              channelId: effectiveSong.channelId,
              thumbnailUrl: verifiedThumb,
              durationSeconds: effectiveSong.durationSeconds,
              durationFormatted: effectiveSong.durationFormatted,
              viewCount: effectiveSong.viewCount,
              publishedAt: effectiveSong.publishedAt,
              isFavorite: effectiveSong.isFavorite,
            );

      _applyOptimisticQueueState(
        targetSong,
        song,
        newQueue: newQueue,
        queueIndex: queueIndex,
        initialPosition: initialPosition,
      );
      notifyListeners();

      // Log to Recently Played (non-blocking – don't wait for DB write)
      unawaited(musicRepository.addRecentlyPlayed(targetSong));

      // Fast-path unit test environment
      if (_isTest) {
        _streamResolvedAt = DateTime.now();
        _isResolvingSong = false;
        _isLoading = false;
        _isPlaying = true;
        notifyListeners();
        return;
      }

      _audioPlayer ??= AudioPlayer();

      if (currentRequestId != _playRequestId) return;

      // Start loading watchdog (25s safety net to clear spinner on slow networks)
      _loadingWatchdog = Timer(const Duration(seconds: 25), () {
        if (_isLoading && currentRequestId == _playRequestId) {
          AppLogger.networkDisconnect(
            'playerProvider:loadingWatchdog',
            'Stream loading exceeded 25s watchdog on "${targetSong.title}"',
            category: 'stall',
            songId: targetSong.id,
          );
          _isLoading = false;
          _isResolvingSong = false;
          _isRefreshingStream = false;
          _isPlaying = false;
          if (_pendingPlayCompleter != null && !_pendingPlayCompleter!.isCompleted) {
            _pendingPlayCompleter!.complete();
          }
          if (_audioPlayer != null) {
            unawaited(_audioPlayer!.stop().catchError((_) {}));
          }
          // Show actionable error so user knows they can retry
          _errorMessage = 'Connection timed out. Tap to retry.';
          notifyListeners();
        }
      });

      // Try primary audio source, with instant resilient fallback if setAudioSource fails
      try {
        final source = await YouTubeAudioSource.resolveAudioSource(
          song: targetSong,
          yt: _yt,
          forceRefresh: forceRefreshStream,
        );

        if (currentRequestId != _playRequestId || _intentionalPause) {
          return;
        }
        await _audioPlayer!.setAudioSource(source).timeout(const Duration(seconds: 15));
        if (currentRequestId != _playRequestId || _intentionalPause) {
          try {
            await _audioPlayer!.stop();
          } catch (_) {}
          return;
        }
      } catch (primaryErr) {
        if (currentRequestId != _playRequestId || _intentionalPause) return;
        AppLogger.networkDisconnect(
          'playerProvider:primarySource',
          'Primary audio source failed for "${targetSong.title}", trying fallback',
          category: 'upstream_retry',
          songId: targetSong.id,
          error: primaryErr,
        );

        final fallbackResult = await AudioStreamExtractor.extractAudioStream(
          targetSong.id,
          preferDownload: true,
          forceRefresh: true,
          preferCdnFallback: true,
          title: targetSong.title,
          artist: targetSong.artist,
          durationSeconds: targetSong.durationSeconds,
        );

        if (fallbackResult != null && currentRequestId == _playRequestId && !_intentionalPause) {
          final fallbackArtUri = await ArtworkService.getArtworkUri(
            thumbnailUrl: targetSong.thumbnailUrl,
            songId: targetSong.id,
          );
          if (currentRequestId != _playRequestId || _intentionalPause) return;

          final fallbackTag = MediaItem(
            id: targetSong.id,
            album: 'Twilight Music',
            title: targetSong.title,
            artist: targetSong.artist,
            artUri: fallbackArtUri,
            duration: Duration(
              seconds: targetSong.durationSeconds > 0 ? targetSong.durationSeconds : 210,
            ),
          );
          final bool isFallbackHls = fallbackResult.url.contains('.m3u8') ||
              fallbackResult.mimeType.toLowerCase().contains('mpegurl');
          final fallbackSource = isFallbackHls
              ? HlsAudioSource(
                  Uri.parse(fallbackResult.url),
                  headers: fallbackResult.headers,
                  tag: fallbackTag,
                )
              : AudioSource.uri(
                  Uri.parse(fallbackResult.url),
                  headers: fallbackResult.headers,
                  tag: fallbackTag,
                );
          await _audioPlayer!.setAudioSource(fallbackSource).timeout(const Duration(seconds: 15));
          if (currentRequestId != _playRequestId || _intentionalPause) {
            try {
              await _audioPlayer!.stop();
            } catch (_) {}
            return;
          }
        } else {
          if (currentRequestId != _playRequestId || _intentionalPause) return;
          rethrow;
        }
      }

      if (currentRequestId != _playRequestId || _intentionalPause) {
        try {
          await _audioPlayer?.stop();
        } catch (_) {}
        return;
      }

      // Lock _currentSong to the exact targetSong whose AudioSource & MediaItem are now loaded
      _currentSong = targetSong;
      if (_currentIndex >= 0 && _currentIndex < _queue.length) {
        _queue[_currentIndex] = targetSong;
      }
      _streamResolvedAt = DateTime.now();

      if (initialPosition != null && initialPosition > Duration.zero) {
        try {
          await _audioPlayer!.seek(initialPosition);
        } catch (seekErr) {
          AppLogger.networkDisconnect(
            'playerProvider:initialSeek',
            'Initial seek interrupted safely',
            songId: targetSong.id,
            error: seekErr,
          );
        }
      }

      if (currentRequestId != _playRequestId || _intentionalPause) {
        try {
          await _audioPlayer?.stop();
        } catch (_) {}
        return;
      }

      if (_playbackSpeed != 1.0) {
        try {
          await _audioPlayer!.setSpeed(_playbackSpeed);
        } catch (_) {}
      }

      if (currentRequestId != _playRequestId || _intentionalPause) {
        try {
          await _audioPlayer?.stop();
        } catch (_) {}
        return;
      }

      // In just_audio, play() resolves when playback stops/completes rather than on start.
      // Clear resolving/loading state and start native playback asynchronously so controls & state updates unlock immediately.
      _loadingWatchdog?.cancel();
      _isResolvingSong = false;
      _isRefreshingStream = false;
      _isPlaying = !_intentionalPause;
      _isLoading = false;
      notifyListeners();

      unawaited(
        _audioPlayer!.play().catchError((Object playErr) {
          if (currentRequestId != _playRequestId || _intentionalPause) return;
          AppLogger.networkDisconnect(
            'playerProvider:nativePlay',
            'Native play() failed for "${targetSong.title}"',
            severity: StreamLogSeverity.error,
            category: 'player_error',
            songId: targetSong.id,
            error: playErr,
          );
          final pos = _currentPosition;
          if (!_isAutoRecovering && _autoRecoveryAttempts < _maxRecoveryAttempts) {
            unawaited(_autoRecoverPlayback(pos));
          } else {
            _isLoading = false;
            _isPlaying = false;
            _errorMessage = 'Could not play "${targetSong.title}". Tap to retry.';
            notifyListeners();
          }
        }),
      );
    } catch (e) {
      if (currentRequestId != _playRequestId || _intentionalPause) return;
      AppLogger.error('Playback error for "${song.title}": $e');
      _errorMessage = 'Could not play "${song.title}". Tap to retry.';
      _isLoading = false;
      _isPlaying = false;
      _isResolvingSong = false;
      _isRefreshingStream = false;
      _loadingWatchdog?.cancel();
      _resumeStallWatchdog?.cancel();
      _errorSkipTimer?.cancel();
      _errorSkipTimer = null;
      notifyListeners();
    }
  }

  /// Refreshes an expired or stalled stream URL and resumes at the exact position
  Future<void> _refreshStreamAndResume(
    Duration resumePos, {
    bool forceNewExtraction = true,
  }) async {
    if (_currentSong == null) return;
    _streamRefreshCount++;
    _isRefreshingStream = true;
    final cacheAge = AudioStreamExtractor.getCacheAge(_currentSong!.id);
    final bool shouldForceFreshExtract = forceNewExtraction ||
        cacheAge == null ||
        cacheAge >= const Duration(minutes: 2);
    if (shouldForceFreshExtract) {
      AudioStreamExtractor.invalidateCache(_currentSong!.id);
    }
    _errorMessage = null;
    if (_isTest) {
      _pausedAt = null;
      _streamPrewarmedWhilePaused = false;
      _isRefreshingStream = false;
      _streamResolvedAt = DateTime.now();
      _currentPosition = resumePos;
      _isPlaying = true;
      _isLoading = false;
      notifyListeners();
      return;
    }
    await playSong(
      _currentSong!,
      queueIndex: _currentIndex >= 0 ? _currentIndex : null,
      initialPosition: resumePos,
      forceRefreshStream: shouldForceFreshExtract,
    );
  }

  /// Retries loading and playing the currently selected song with position restore
  Future<void> retryCurrentSong() async {
    if (_currentSong != null) {
      final resumePos = _currentPosition;
      await _refreshStreamAndResume(resumePos);
    }
  }

  /// Automatically recovers playback seamlessly from the given position
  /// if a socket drops or an unexpected stream completion event occurs,
  /// using bounded exponential backoff (1s, 2s, 4s) and never overriding an intentional pause.
  Future<void> _autoRecoverPlayback(Duration resumePos) async {
    if (_isAutoRecovering || _currentSong == null || _intentionalPause) return;
    if (_autoRecoveryAttempts >= _maxRecoveryAttempts) {
      AppLogger.networkDisconnect(
        'playerProvider:autoRecover',
        'Max auto-recovery attempts ($_maxRecoveryAttempts) reached for "${_currentSong!.title}"',
        severity: StreamLogSeverity.error,
        category: 'retry_exhausted',
        songId: _currentSong!.id,
        attempt: _autoRecoveryAttempts,
      );
      _isLoading = false;
      _isPlaying = false;
      _errorMessage = 'Connection lost. Tap to retry.';
      notifyListeners();
      return;
    }
    _autoRecoveryAttempts++;
    _isAutoRecovering = true;
    try {
      final backoffSeconds = 1 << (_autoRecoveryAttempts - 1); // 1s, 2s, 4s
      AppLogger.streamEvent(
        StreamLogSeverity.info,
        'recovery',
        'playerProvider:autoRecover',
        'Auto-recovering "${_currentSong!.title}" at ${resumePos.inSeconds}s after ${backoffSeconds}s backoff',
        songId: _currentSong!.id,
        attempt: _autoRecoveryAttempts,
      );
      if (!_isTest) {
        await Future.delayed(Duration(seconds: backoffSeconds));
      }
      if (_intentionalPause || _currentSong == null) return;
      AudioStreamExtractor.invalidateCache(_currentSong!.id);
      _errorMessage = null;
      await playSong(
        _currentSong!,
        queueIndex: _currentIndex,
        initialPosition: resumePos > const Duration(seconds: 1) ? resumePos : null,
        forceRefreshStream: true,
      );
    } catch (e) {
      AppLogger.networkDisconnect(
        'playerProvider:autoRecover',
        'Auto-recovery attempt failed',
        severity: StreamLogSeverity.error,
        songId: _currentSong?.id,
        attempt: _autoRecoveryAttempts,
        error: e,
      );
      _errorMessage = 'Playback paused. Tap to resume.';
    } finally {
      _isAutoRecovering = false;
    }
  }

  void togglePlayPause() {
    if (_currentSong == null) return;
    if (_isPlaying || _isLoading || _isResolvingSong || isDebouncePending) {
      pause();
    } else {
      play();
    }
  }

  void play() {
    if (_currentSong == null) return;
    _intentionalPause = false;
    _errorMessage = null;
    _proactivePauseRefreshTimer?.cancel();

    final now = DateTime.now();
    final bool pauseExpired = (_pausedAt != null &&
            now.difference(_pausedAt!) >= proactivePauseRefreshThreshold) ||
        _streamPrewarmedWhilePaused;
    final bool streamExpired = _streamResolvedAt != null &&
        now.difference(_streamResolvedAt!) >= const Duration(minutes: 5);
    final bool playerNotReady = !_isTest &&
        (_audioPlayer == null ||
            _audioPlayer!.processingState == ProcessingState.idle ||
            _audioPlayer!.processingState == ProcessingState.completed ||
            (!_isPlayingOfflineFile &&
                _audioPlayer!.processingState != ProcessingState.ready));

    final bool wasPrewarmed = _streamPrewarmedWhilePaused;
    _pausedAt = null;
    _streamPrewarmedWhilePaused = false;

    // Reload cleanly if player engine is idle/completed/unready, or proactively refresh expired online streams
    if (playerNotReady || (!_isPlayingOfflineFile && (pauseExpired || streamExpired))) {
      AppLogger.info('Proactive stream refresh on resume at ${_currentPosition.inSeconds}s (pauseExpired: $pauseExpired, streamExpired: $streamExpired, prewarmed: $wasPrewarmed, playerNotReady: $playerNotReady)');
      _isPlaying = true;
      _isLoading = true;
      _isRefreshingStream = true;
      notifyListeners();
      unawaited(
        _refreshStreamAndResume(
          _currentPosition,
          forceNewExtraction: !wasPrewarmed && !_isPlayingOfflineFile,
        ),
      );
      return;
    }

    _isPlaying = true;
    notifyListeners();

    if (_isTest) return;

    final positionAtResume = _currentPosition;
    _resumeStallWatchdog?.cancel();
    if (!_isPlayingOfflineFile) {
      _resumeStallWatchdog = Timer(const Duration(seconds: 6), () {
        if (_isPlaying &&
            !_intentionalPause &&
            (_isLoading || _currentPosition == positionAtResume)) {
          AppLogger.warning('Resume stalled for 6s at ${positionAtResume.inSeconds}s. Refreshing stream URL...');
          unawaited(_refreshStreamAndResume(_currentPosition));
        }
      });
    }

    _audioPlayer?.play().catchError((Object e) {
      AppLogger.warning('Direct play error on resume: $e');
      if (!_intentionalPause && !_isPlayingOfflineFile) {
        unawaited(_refreshStreamAndResume(_currentPosition));
      } else {
        _isPlaying = false;
        _errorMessage = 'Playback error. Tap to retry.';
        notifyListeners();
      }
    });
  }

  void pause() {
    if (_isLoading || _isResolvingSong || isDebouncePending) {
      _playRequestId++;
    }
    _intentionalPause = true;
    _pausedAt = DateTime.now();
    _streamPrewarmedWhilePaused = false;
    _isPlaying = false;
    _isLoading = false;
    _isResolvingSong = false;
    _isRefreshingStream = false;
    _playDebounceTimer?.cancel();
    _playDebounceTimer = null;
    if (_pendingPlayCompleter != null && !_pendingPlayCompleter!.isCompleted) {
      _pendingPlayCompleter!.complete();
    }
    _pendingPlayCompleter = null;
    _loadingWatchdog?.cancel();
    _loadingWatchdog = null;
    _resumeStallWatchdog?.cancel();
    _proactivePauseRefreshTimer?.cancel();

    // Schedule proactive background stream URL refresh if playback remains paused for > 3 minutes
    if (!_isTest && !_isPlayingOfflineFile && _currentSong != null) {
      final pausedSongId = _currentSong!.id;
      final pausedSongTitle = _currentSong!.title;
      final pausedSongArtist = _currentSong!.artist;
      _proactivePauseRefreshTimer = Timer(proactivePauseRefreshThreshold, () async {
        if (!_intentionalPause || _currentSong?.id != pausedSongId || _isPlayingOfflineFile) {
          return;
        }
        AppLogger.info('Playback paused > 3 minutes for "$pausedSongId". Proactively refreshing stream URL in background...');
        AudioStreamExtractor.invalidateCache(pausedSongId);
        try {
          final refreshed = await AudioStreamExtractor.extractAudioStream(
            pausedSongId,
            forceRefresh: true,
            title: pausedSongTitle,
            artist: pausedSongArtist,
          );
          if (refreshed != null && _intentionalPause && _currentSong?.id == pausedSongId) {
            _streamPrewarmedWhilePaused = true;
            _streamResolvedAt = DateTime.now();
            AppLogger.info('Background stream URL pre-warmed for "$pausedSongId" while paused.');
          }
        } catch (e) {
          AppLogger.warning('Background pause stream pre-warm failed: $e');
        }
      });
    }

    notifyListeners();
    _audioPlayer?.pause().catchError((Object e) {
      AppLogger.warning('Direct pause error: $e');
    });
  }

  void stop() {
    _intentionalPause = true;
    _pausedAt = null;
    _streamPrewarmedWhilePaused = false;
    _isPlaying = false;
    _isResolvingSong = false;
    _isRefreshingStream = false;
    _isLoading = false;
    _currentPosition = Duration.zero;
    _playDebounceTimer?.cancel();
    _playDebounceTimer = null;
    if (_pendingPlayCompleter != null && !_pendingPlayCompleter!.isCompleted) {
      _pendingPlayCompleter!.complete();
    }
    _pendingPlayCompleter = null;
    _loadingWatchdog?.cancel();
    _resumeStallWatchdog?.cancel();
    _proactivePauseRefreshTimer?.cancel();
    final stopFuture = _audioPlayer?.stop();
    if (stopFuture != null) {
      unawaited(stopFuture.catchError((_) {}));
    }
    notifyListeners();
  }

  void seekTo(Duration position) {
    final clamped = position < Duration.zero
        ? Duration.zero
        : (_totalDuration > Duration.zero && position > _totalDuration
            ? _totalDuration
            : position);
    _currentPosition = clamped;
    final seekFuture = _audioPlayer?.seek(clamped);
    if (seekFuture != null) {
      unawaited(
        seekFuture.catchError((Object e) {
          AppLogger.networkDisconnect(
            'playerProvider:seek',
            'Seek interrupted safely',
            songId: _currentSong?.id,
            error: e,
          );
        }),
      );
    }
    notifyListeners();
  }

  void onTrackEnded() {
    _errorSkipTimer?.cancel();
    _errorSkipTimer = null;
    if (_isRepeat) {
      seekTo(Duration.zero);
      play();
    } else {
      next();
    }
  }

  Future<void> next() async {
    if (_queue.isEmpty) return;
    if (_isShuffle && _queue.length > 1) {
      final rand = Random();
      int nextIndex = _currentIndex;
      for (int i = 0; i < 5 && nextIndex == _currentIndex; i++) {
        nextIndex = rand.nextInt(_queue.length);
      }
      if (nextIndex == _currentIndex) {
        nextIndex = (_currentIndex + 1) % _queue.length;
      }
      _currentIndex = nextIndex;
      await playSong(_queue[_currentIndex], queueIndex: _currentIndex);
      return;
    }
    if (_currentIndex + 1 < _queue.length) {
      _currentIndex++;
      await playSong(_queue[_currentIndex], queueIndex: _currentIndex);
    } else if (_isRepeat) {
      _currentIndex = 0;
      await playSong(_queue[0], queueIndex: 0);
    } else if (_isAutoplay && _queue.isNotEmpty) {
      // Smart Radio / Autoplay mode: automatically fetch similar tracks with concurrency & cancellation guard
      final autoplayReqId = ++_playRequestId;
      _intentionalPause = false;
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final seedSong = _currentSong;
      try {
        final query = seedSong != null
            ? '${seedSong.title} ${seedSong.artist} music'
            : 'popular music hits';
        final searchResults = await _yt.search.search(query).timeout(const Duration(seconds: 4));
        if (autoplayReqId != _playRequestId || _intentionalPause) return;
        if (searchResults.isNotEmpty) {
          final newTracks = searchResults
              .where((v) => !_queue.any((q) => q.id == v.id.value))
              .map((v) => Song(
                    id: v.id.value,
                    title: v.title,
                    artist: v.author,
                    channelId: v.channelId.value,
                    thumbnailUrl: 'https://i.ytimg.com/vi/${v.id.value}/hqdefault.jpg',
                    durationSeconds: v.duration?.inSeconds ?? 210,
                    durationFormatted: Formatters.formatDuration(v.duration ?? const Duration(seconds: 210)),
                    viewCount: v.engagement.viewCount,
                    publishedAt: v.uploadDate,
                  ))
              .toList();

          if (newTracks.isNotEmpty) {
            _queue.addAll(newTracks.take(5));
            _currentIndex = (_currentIndex + 1).clamp(0, _queue.length - 1);
            await playSong(_queue[_currentIndex], queueIndex: _currentIndex);
            return;
          }
        }
      } catch (e) {
        AppLogger.info('Autoplay related tracks fallback: $e');
      }

      if (autoplayReqId != _playRequestId || _intentionalPause) return;

      try {
        final query = seedSong != null
            ? '${seedSong.title} ${seedSong.artist}'
            : 'trending music hits';
        final tempClient = http.Client();
        try {
          final ytDatasource = YouTubeRemoteDatasource(client: tempClient, apiKey: '');
          final remoteResults = await ytDatasource.searchAll(query).timeout(const Duration(seconds: 5));
          if (autoplayReqId != _playRequestId || _intentionalPause) return;
          final newTracks = remoteResults.songs
              .where((s) => !_queue.any((q) => q.id == s.id || q.isSameTrack(s)))
              .toList();
          if (newTracks.isNotEmpty) {
            _queue.addAll(newTracks.take(5));
            _currentIndex = (_currentIndex + 1).clamp(0, _queue.length - 1);
            await playSong(_queue[_currentIndex], queueIndex: _currentIndex);
            return;
          }
        } finally {
          tempClient.close();
        }
      } catch (e) {
        AppLogger.info('Autoplay repository search fallback: $e');
      }

      if (autoplayReqId != _playRequestId || _intentionalPause) return;

      try {
        final suggestions = await MusicImportService().getViralHitsChart().timeout(const Duration(seconds: 5));
        if (autoplayReqId != _playRequestId || _intentionalPause) return;
        final newTracks = suggestions
            .where((s) => !_queue.any((q) => q.id == s.id || q.isSameTrack(s)))
            .toList();
        if (newTracks.isNotEmpty) {
          _queue.addAll(newTracks.take(5));
          _currentIndex = (_currentIndex + 1).clamp(0, _queue.length - 1);
          await playSong(_queue[_currentIndex], queueIndex: _currentIndex);
          return;
        }
      } catch (e) {
        AppLogger.info('Autoplay dynamic extension fallback: $e');
      }
      if (autoplayReqId != _playRequestId || _intentionalPause || _queue.isEmpty) return;
      _currentIndex = 0;
      await playSong(_queue[0], queueIndex: 0);
    } else {
      _isPlaying = false;
      notifyListeners();
    }
  }

  void previous() {
    if (_queue.isEmpty) return;
    if (_currentPosition.inSeconds > 3) {
      seekTo(Duration.zero);
      return;
    }
    if (_currentIndex > 0) {
      _currentIndex--;
      playSong(_queue[_currentIndex], queueIndex: _currentIndex);
    } else if (_isRepeat && _queue.length > 1) {
      _currentIndex = _queue.length - 1;
      playSong(_queue[_currentIndex], queueIndex: _currentIndex);
    } else {
      seekTo(Duration.zero);
    }
  }

  // --- Spotify Features ---

  void setPlaybackSpeed(double speed) {
    _playbackSpeed = speed;
    final speedFuture = _audioPlayer?.setSpeed(speed);
    if (speedFuture != null) {
      unawaited(speedFuture.catchError((_) {}));
    }
    notifyListeners();
  }

  void setAudioQuality(String quality) {
    _audioQuality = quality;
    LocalStorageService.setString('mt_audio_quality', quality);
    notifyListeners();
  }

  void setEqualizerPreset(String preset) {
    _equalizerPreset = preset;
    LocalStorageService.setString('mt_equalizer_preset', preset);
    notifyListeners();
  }

  void toggleAutoplay({bool? value}) {
    _isAutoplay = value ?? !_isAutoplay;
    LocalStorageService.setBool('mt_autoplay', _isAutoplay);
    notifyListeners();
  }

  void setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    if (duration == null) {
      _sleepTimerEndTime = null;
    } else {
      _sleepTimerEndTime = DateTime.now().add(duration);
      _sleepTimer = Timer(duration, () {
        pause();
        _sleepTimerEndTime = null;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimerEndTime = null;
    notifyListeners();
  }

  // --- Queue Management ---

  void addToQueue(Song song) {
    _queue.add(song);
    notifyListeners();
  }

  void playNext(Song song) {
    if (_currentIndex >= 0 && _currentIndex < _queue.length) {
      _queue.insert(_currentIndex + 1, song);
    } else {
      _queue.add(song);
    }
    notifyListeners();
  }

  void removeFromQueue(int index) {
    if (index >= 0 && index < _queue.length) {
      _queue.removeAt(index);
      if (index < _currentIndex) {
        _currentIndex--;
      } else if (index == _currentIndex) {
        if (_queue.isNotEmpty) {
          _currentIndex = _currentIndex.clamp(0, _queue.length - 1);
          playSong(_queue[_currentIndex], queueIndex: _currentIndex);
        } else {
          _currentSong = null;
          _currentIndex = -1;
          _isPlaying = false;
          _audioPlayer?.stop();
        }
      }
      notifyListeners();
    }
  }

  void reorderItem(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _queue.length) return;
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _queue.removeAt(oldIndex);
    final targetIndex = newIndex.clamp(0, _queue.length);
    _queue.insert(targetIndex, item);
    if (_currentSong != null) {
      if (oldIndex == _currentIndex) {
        _currentIndex = targetIndex;
      } else if (oldIndex < _currentIndex && targetIndex >= _currentIndex) {
        _currentIndex--;
      } else if (oldIndex > _currentIndex && targetIndex <= _currentIndex) {
        _currentIndex++;
      } else {
        _currentIndex = _queue.indexWhere(
          (s) => s.id == _currentSong!.id || s.isSameTrack(_currentSong!),
        );
      }
    }
    notifyListeners();
  }

  void reorderQueue(int oldIndex, int newIndex) {
    reorderItem(oldIndex, newIndex);
  }

  void clearQueue() {
    if (_currentSong != null) {
      _queue = [_currentSong!];
      _currentIndex = 0;
    } else {
      _queue = [];
      _currentIndex = -1;
    }
    notifyListeners();
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    if (_isShuffle && _queue.length > 1) {
      final current = _currentSong;
      _queue.shuffle();
      if (current != null) {
        _queue.removeWhere((s) => s.id == current.id || s.isSameTrack(current));
        _queue.insert(0, current);
        _currentIndex = 0;
      }
    }
    notifyListeners();
  }

  void toggleRepeat() {
    _isRepeat = !_isRepeat;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _playDebounceTimer?.cancel();
    if (_pendingPlayCompleter != null && !_pendingPlayCompleter!.isCompleted) {
      _pendingPlayCompleter!.complete();
    }
    _loadingWatchdog?.cancel();
    _resumeStallWatchdog?.cancel();
    _proactivePauseRefreshTimer?.cancel();
    _errorSkipTimer?.cancel();
    _sleepTimer?.cancel();
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playbackEventSub?.cancel();
    _audioPlayer?.dispose();
    _yt.close();
    super.dispose();
  }
}
