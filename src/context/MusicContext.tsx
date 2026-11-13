import React, { createContext, useContext, useState, useEffect, useRef, useMemo } from 'react';
import { Song, Playlist, UserProfile } from '../types';
import { POPULAR_FEATURED_SONGS, MusicApi, isShortPreviewUrl } from '../services/musicApi';
import { StreamLogger } from '../services/streamLogger';
import {
  auth,
  googleProvider,
  signInWithPopup,
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  fbSignOut,
  onAuthStateChanged,
  CloudSyncService,
  setDriveAccessToken,
} from '../services/firebase';
import { GoogleAuthProvider } from 'firebase/auth';

interface MusicContextType {
  currentSong: Song | null;
  queue: Song[];
  currentIndex: number;
  isPlaying: boolean;
  isLoading: boolean;
  isRefreshingStream: boolean;
  streamRefreshCount: number;
  playbackError: string | null;
  currentTime: number;
  duration: number;
  volume: number;
  isShuffle: boolean;
  isRepeat: boolean;
  playbackSpeed: number;
  audioQuality: string;
  favorites: Song[];
  history: Song[];
  frequentTracks: (Song & { playCount: number })[];
  playlists: Playlist[];
  downloads: Song[];
  user: UserProfile;
  sleepTimerRemaining: number | null;
  // Controls
  playSong: (song: Song, newQueue?: Song[], options?: { immediate?: boolean; forceRestart?: boolean }) => void;
  selectAndPlaySong: (song: Song, newQueue?: Song[]) => void;
  stopCurrentBeforeSwitch: () => void;
  pauseSong: () => void;
  resumeSong: () => void;
  retryCurrentSong: () => void;
  nextSong: () => void;
  prevSong: () => void;
  seekTo: (seconds: number) => void;
  setVolume: (vol: number) => void;
  toggleShuffle: () => void;
  toggleRepeat: () => void;
  setPlaybackSpeed: (speed: number) => void;
  setAudioQuality: (q: string) => void;
  setSleepTimer: (minutes: number | null) => void;
  // Library Actions
  toggleFavorite: (song: Song) => void;
  isFavorite: (id: string) => boolean;
  createPlaylist: (title: string, description?: string) => Playlist;
  deletePlaylist: (playlistId: string) => void;
  addToPlaylist: (playlistId: string, song: Song) => void;
  removeFromPlaylist: (playlistId: string, songId: string) => void;
  downloadSong: (song: Song) => void;
  retryDownload: (song: Song) => void;
  removeDownload: (songId: string) => void;
  isDownloaded: (songId: string) => boolean;
  isDownloading: (songId: string) => boolean;
  // Auth
  signInWithGoogle: () => Promise<void>;
  signInWithEmail: (e: string, p: string) => Promise<void>;
  registerWithEmail: (e: string, p: string) => Promise<void>;
  signOut: () => Promise<void>;
  updateUser: (updates: Partial<UserProfile>) => void;
}

const MusicContext = createContext<MusicContextType | null>(null);

const STORAGE_KEYS = {
  FAVORITES: 'twilight_favorites_v2',
  HISTORY: 'twilight_history_v2',
  PLAYLISTS: 'twilight_playlists_v2',
  DOWNLOADS: 'twilight_downloads_v2',
  PLAY_COUNTS: 'twilight_play_counts_v2',
  SETTINGS: 'twilight_settings_v2',
};

export const PROACTIVE_PAUSE_REFRESH_MS = 3 * 60 * 1000; // 3 minutes (180,000ms)
export const STREAM_MAX_AGE_MS = 5 * 60 * 1000; // 5 minutes (300,000ms)
export const SONG_SELECTION_DEBOUNCE_MS = 300; // 300ms debounce window for song selection

const OFFLINE_IDB_NAME = 'twilight_offline_audio_db_v2';
const OFFLINE_IDB_STORE = 'audio_blobs';

function openOfflineAudioDb(): Promise<IDBDatabase | null> {
  if (typeof indexedDB === 'undefined') return Promise.resolve(null);
  return new Promise((resolve) => {
    try {
      const req = indexedDB.open(OFFLINE_IDB_NAME, 1);
      req.onupgradeneeded = () => {
        const db = req.result;
        if (!db.objectStoreNames.contains(OFFLINE_IDB_STORE)) {
          db.createObjectStore(OFFLINE_IDB_STORE);
        }
      };
      req.onsuccess = () => resolve(req.result);
      req.onerror = () => resolve(null);
    } catch {
      resolve(null);
    }
  });
}

async function saveOfflineBlobToIdb(songId: string, blob: Blob): Promise<void> {
  const db = await openOfflineAudioDb();
  if (!db) return;
  return new Promise((resolve) => {
    try {
      const tx = db.transaction(OFFLINE_IDB_STORE, 'readwrite');
      tx.objectStore(OFFLINE_IDB_STORE).put(blob, songId);
      tx.oncomplete = () => resolve();
      tx.onerror = () => resolve();
    } catch {
      resolve();
    }
  });
}

async function getOfflineBlobFromIdb(songId: string): Promise<Blob | null> {
  const db = await openOfflineAudioDb();
  if (!db) return null;
  return new Promise((resolve) => {
    try {
      const tx = db.transaction(OFFLINE_IDB_STORE, 'readonly');
      const req = tx.objectStore(OFFLINE_IDB_STORE).get(songId);
      req.onsuccess = () => {
        const res = req.result;
        resolve(res instanceof Blob && res.size > 1000 ? res : null);
      };
      req.onerror = () => resolve(null);
    } catch {
      resolve(null);
    }
  });
}

async function deleteOfflineBlobFromIdb(songId: string): Promise<void> {
  const db = await openOfflineAudioDb();
  if (!db) return;
  return new Promise((resolve) => {
    try {
      const tx = db.transaction(OFFLINE_IDB_STORE, 'readwrite');
      tx.objectStore(OFFLINE_IDB_STORE).delete(songId);
      tx.oncomplete = () => resolve();
      tx.onerror = () => resolve();
    } catch {
      resolve();
    }
  });
}

async function isHealthyAudioBlob(blob: Blob | null | undefined): Promise<boolean> {
  if (!blob || !(blob instanceof Blob) || blob.size <= 10000) return false;
  try {
    const headText = (await blob.slice(0, 16).text()).trimStart();
    if (
      headText.startsWith('#EXTM3U') ||
      headText.startsWith('<!DOC') ||
      headText.startsWith('<html') ||
      headText.startsWith('<HTML') ||
      headText.startsWith('{')
    ) {
      return false;
    }
    return true;
  } catch {
    return blob.size > 10000;
  }
}

export const MusicProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  // Playback state: start with no active song until the user explicitly clicks a track
  const [currentSong, setCurrentSong] = useState<Song | null>(null);
  const [queue, setQueue] = useState<Song[]>(() => POPULAR_FEATURED_SONGS);
  const [currentIndex, setCurrentIndex] = useState<number>(-1);
  const [isPlaying, setIsPlaying] = useState<boolean>(false);
  const [isLoading, setIsLoading] = useState<boolean>(false);
  const [isRefreshingStream, setIsRefreshingStream] = useState<boolean>(false);
  const [streamRefreshCount, setStreamRefreshCount] = useState<number>(0);
  const [playbackError, setPlaybackError] = useState<string | null>(null);
  const [currentTime, setCurrentTime] = useState<number>(0);
  const [duration, setDuration] = useState<number>(0);
  const initialSettings = (() => {
    try {
      const raw = localStorage.getItem(STORAGE_KEYS.SETTINGS);
      return raw ? JSON.parse(raw) : {};
    } catch {
      return {};
    }
  })();

  const [volume, setVolumeState] = useState<number>(() =>
    typeof initialSettings.volume === 'number' ? initialSettings.volume : 0.85
  );
  const [isShuffle, setIsShuffle] = useState<boolean>(() => Boolean(initialSettings.isShuffle));
  const [isRepeat, setIsRepeat] = useState<boolean>(() => Boolean(initialSettings.isRepeat));
  const [playbackSpeed, setPlaybackSpeedState] = useState<number>(() =>
    typeof initialSettings.playbackSpeed === 'number' ? initialSettings.playbackSpeed : 1.0
  );
  const [audioQuality, setAudioQualityState] = useState<string>(() => {
    const q = String(initialSettings.audioQuality || '').toLowerCase();
    if (q.includes('saver') || q.includes('96')) return 'Data Saver (96 kbps - OPUS)';
    if (q.includes('standard') || q.includes('160') || q === 'low') return 'Standard (160 kbps - AAC)';
    if (q.includes('lossless') || q.includes('320')) return 'Very High (320 kbps - Lossless)';
    return 'High (256 kbps - Enhanced AAC)';
  });

  useEffect(() => {
    try {
      localStorage.setItem(
        STORAGE_KEYS.SETTINGS,
        JSON.stringify({
          volume,
          isShuffle,
          isRepeat,
          playbackSpeed,
          audioQuality,
        })
      );
    } catch {}
  }, [volume, isShuffle, isRepeat, playbackSpeed, audioQuality]);

  // Sleep Timer
  const [sleepTimerRemaining, setSleepTimerRemaining] = useState<number | null>(null);

  // User & Collections
  const [user, setUser] = useState<UserProfile>({
    uid: 'usr_hasibul_hasan',
    email: 'gudhulibela031@gmail.com',
    displayName: 'Hasibul Hasan',
    photoURL: null,
    isGuest: false,
  });

  const [favorites, setFavorites] = useState<Song[]>(() => {
    try {
      const saved = localStorage.getItem(STORAGE_KEYS.FAVORITES);
      const list: Song[] = saved ? JSON.parse(saved) : [POPULAR_FEATURED_SONGS[0], POPULAR_FEATURED_SONGS[3]];
      return list.map((s) => {
        const cleaned = isShortPreviewUrl(s.audioUrl) ? { ...s, audioUrl: undefined } : s;
        return cleaned.id && cleaned.id.length === 11 && !cleaned.id.startsWith('sp_')
          ? { ...cleaned, thumbnailUrl: `https://i.ytimg.com/vi/${cleaned.id}/hqdefault.jpg` }
          : cleaned;
      });
    } catch {
      return [];
    }
  });

  const [history, setHistory] = useState<Song[]>(() => {
    try {
      const saved = localStorage.getItem(STORAGE_KEYS.HISTORY);
      const list: Song[] = saved ? JSON.parse(saved) : POPULAR_FEATURED_SONGS.slice(0, 4);
      return list.map((s) => {
        const cleaned = isShortPreviewUrl(s.audioUrl) ? { ...s, audioUrl: undefined } : s;
        return cleaned.id && cleaned.id.length === 11 && !cleaned.id.startsWith('sp_')
          ? { ...cleaned, thumbnailUrl: `https://i.ytimg.com/vi/${cleaned.id}/hqdefault.jpg` }
          : cleaned;
      });
    } catch {
      return [];
    }
  });

  const [playCounts, setPlayCounts] = useState<Record<string, number>>(() => {
    try {
      const saved = localStorage.getItem(STORAGE_KEYS.PLAY_COUNTS);
      return saved ? JSON.parse(saved) : {
        fJ9rUzIMcZQ: 14,
        '4NRXx6U8ABQ': 22,
        JGwWNGJdvx8: 18,
        '09R8_2nJtjg': 15,
      };
    } catch {
      return {};
    }
  });

  const [playlists, setPlaylists] = useState<Playlist[]>(() => {
    try {
      const saved = localStorage.getItem(STORAGE_KEYS.PLAYLISTS);
      if (saved) return JSON.parse(saved);
    } catch {
      // fallback
    }
    return [
      {
        id: 'pl_favorites_default',
        title: 'Twilight Favorites',
        description: 'Your starred all-time top melodic tracks',
        thumbnailUrl: POPULAR_FEATURED_SONGS[0].thumbnailUrl,
        songs: POPULAR_FEATURED_SONGS.slice(0, 3),
        updatedAt: Date.now(),
        isCustom: true,
      },
      {
        id: 'pl_chill_late_night',
        title: 'Midnight Chill Lounge',
        description: 'Smooth rhythms and deep atmospheric frequencies',
        thumbnailUrl: POPULAR_FEATURED_SONGS[3].thumbnailUrl,
        songs: POPULAR_FEATURED_SONGS.slice(2, 6),
        updatedAt: Date.now(),
        isCustom: true,
      },
    ];
  });

  const [downloads, setDownloads] = useState<Song[]>(() => {
    try {
      const saved = localStorage.getItem(STORAGE_KEYS.DOWNLOADS);
      const parsed: Song[] = saved ? JSON.parse(saved) : [];
      return parsed.map((s) => {
        const knownMaster = MusicApi.resolveKnownFullLengthMaster(s);
        const cleanedAudio = knownMaster || (isShortPreviewUrl(s.audioUrl) ? undefined : s.audioUrl);
        return {
          ...s,
          audioUrl: cleanedAudio,
          thumbnailUrl:
            s.id && s.id.length === 11 && !s.id.startsWith('sp_')
              ? `https://i.ytimg.com/vi/${s.id}/hqdefault.jpg`
              : s.thumbnailUrl,
          offlineStatus: s.offlineStatus || 'verified',
        };
      });
    } catch {
      return [];
    }
  });

  // Audio HTML Element, Exact-YouTube IFrame Engine & Playback Lifecycle Refs
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const ytPlayerRef = useRef<any>(null);
  const ytReadyRef = useRef<boolean>(false);
  const activeEngineRef = useRef<'yt' | 'html5'>('html5');
  const ytFallbackWatchdogRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const ytBufferingWatchdogRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const ytProgressIntervalRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const html5FallbackFnRef = useRef<((startPos?: number) => void) | null>(null);
  const loadedMetadataCleanupRef = useRef<(() => void) | null>(null);
  const synthOscRef = useRef<OscillatorNode | null>(null);
  const audioCtxRef = useRef<AudioContext | null>(null);
  const playRequestIdRef = useRef<number>(0);
  const intentionalPauseRef = useRef<boolean>(false);
  const pausedAtRef = useRef<number | null>(null);
  const streamResolvedAtRef = useRef<number | null>(null);
  const resumeWatchdogRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const html5LoadWatchdogRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const proactivePauseTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const playDebounceTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const errorRecoveryTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const streamAbortControllerRef = useRef<AbortController | null>(null);
  const hasInitializedStreamRef = useRef<boolean>(false);
  const isPrimingAudioRef = useRef<boolean>(false);
  const audioUnlockedRef = useRef<boolean>(false);
  const prewarmedStreamRef = useRef<{ songId: string; url: string; resolvedAt: number } | null>(null);
  const recoveryAttemptsRef = useRef<number>(0);
  const activeObjectUrlRef = useRef<string | null>(null);
  const handlersRef = useRef<{
    pauseSong: () => void;
    resumeSong: () => void;
    handleNextSong: () => void;
    handlePrevSong: () => void;
    seekTo: (sec: number) => void;
    retryCurrentSong: () => void;
  } | null>(null);

  // Live state ref so audio event listeners (onended, onerror, mediaSession) never read stale closures
  const stateRef = useRef({
    currentSong,
    queue,
    currentIndex,
    isPlaying,
    isLoading,
    playbackError,
    isRepeat,
    isShuffle,
    currentTime,
    volume,
    playbackSpeed,
  });

  useEffect(() => {
    stateRef.current = {
      currentSong,
      queue,
      currentIndex,
      isPlaying,
      isLoading,
      playbackError,
      isRepeat,
      isShuffle,
      currentTime,
      volume,
      playbackSpeed,
    };
  }, [currentSong, queue, currentIndex, isPlaying, isLoading, playbackError, isRepeat, isShuffle, currentTime, volume, playbackSpeed]);

  const OFFLINE_CACHE_NAME = 'twilight-offline-audio-v3';

  const initialDownloadsRef = useRef<Song[]>(downloads);

  // Verify offline cache integrity on startup and hydrate IndexedDB/CacheStorage
  useEffect(() => {
    const verifyDownloadsIntegrity = async () => {
      try {
        if ('caches' in window) {
          await caches.delete('twilight-offline-audio-v1').catch(() => {});
          await caches.delete('twilight-offline-audio-v2').catch(() => {});
        }
        if (typeof indexedDB !== 'undefined') {
          try {
            indexedDB.deleteDatabase('twilight_offline_audio_db');
          } catch {}
        }
        const initialList = initialDownloadsRef.current;
        if (initialList.length === 0) return;

        const cache = 'caches' in window ? await caches.open(OFFLINE_CACHE_NAME) : null;
        const verifiedList = await Promise.all(
          initialList.map(async (song) => {
            const cacheKey = `/offline-audio/${encodeURIComponent(song.id)}`;
            if (cache) {
              const matched = await cache.match(cacheKey);
              if (matched) {
                const b = await matched.blob().catch(() => null);
                if (b && b.size > 1000) return { ...song, offlineStatus: 'verified' as const };
              }
            }
            const idbBlob = await getOfflineBlobFromIdb(song.id);
            if (idbBlob && idbBlob.size > 1000) {
              if (cache) {
                await cache
                  .put(
                    cacheKey,
                    new Response(idbBlob, {
                      headers: { 'Content-Type': idbBlob.type || 'audio/mp4' },
                    })
                  )
                  .catch(() => {});
              }
              return { ...song, offlineStatus: 'verified' as const };
            }

            // Background-cache the track into offline storage if online
            try {
              const resolvedUrl =
                (await MusicApi.resolveClientDirectStreamUrl(song)) ||
                MusicApi.resolveKnownFullLengthMaster(song) ||
                song.audioUrl ||
                `/api/stream/${encodeURIComponent(song.id)}?title=${encodeURIComponent(song.title)}&artist=${encodeURIComponent(song.artist)}`;
              const blob = await fetchAudioBlobWithRetry(resolvedUrl, 1, 8000);
              if (blob && blob.size > 10000) {
                if (cache) {
                  await cache.put(
                    cacheKey,
                    new Response(blob, {
                      headers: { 'Content-Type': blob.type || 'audio/mp4' },
                    })
                  );
                }
                await saveOfflineBlobToIdb(song.id, blob);
                return { ...song, audioUrl: resolvedUrl, offlineStatus: 'verified' as const };
              }
            } catch {
              // Offline or fetch failed; keep existing status
            }
            return { ...song, offlineStatus: 'missing' as const };
          })
        );

        const verifiedMap = new Map(verifiedList.map((item) => [item.id, item]));
        setDownloads((latest) => latest.map((item) => verifiedMap.get(item.id) || item));
      } catch {}
    };
    verifyDownloadsIntegrity();
  }, []);

  // Initialize Official YouTube IFrame Audio Engine + Single Authoritative HTML5 Audio Element
  useEffect(() => {
    const audio = new Audio();
    audio.volume = volume;
    audio.playbackRate = playbackSpeed;
    audio.preload = 'auto';
    audio.setAttribute('playsinline', 'true');
    audio.setAttribute('webkit-playsinline', 'true');
    audioRef.current = audio;

    // Set up hidden offscreen YouTube IFrame Player for 100% exact YouTube video audio matching
    let container = document.getElementById('twilight-yt-audio-container');
    if (!container) {
      container = document.createElement('div');
      container.id = 'twilight-yt-audio-container';
      container.style.cssText =
        'position:fixed;right:0;bottom:0;width:200px;height:200px;opacity:0.001;pointer-events:none;z-index:-1;overflow:hidden;';
      const inner = document.createElement('div');
      inner.id = 'twilight-yt-player';
      container.appendChild(inner);
      document.body.appendChild(container);
    }

    const initYtPlayer = () => {
      const YT = (window as any).YT;
      if (!YT || !YT.Player || ytPlayerRef.current) return;
      try {
        ytPlayerRef.current = new YT.Player('twilight-yt-player', {
          width: '200',
          height: '200',
          playerVars: {
            autoplay: 0,
            controls: 0,
            disablekb: 1,
            fs: 0,
            iv_load_policy: 3,
            modestbranding: 1,
            playsinline: 1,
            rel: 0,
            origin: window.location.origin,
          },
          events: {
            onReady: (ev: any) => {
              ytReadyRef.current = true;
              try {
                ev.target.setVolume(Math.round(stateRef.current.volume * 100));
                ev.target.setPlaybackRate(stateRef.current.playbackSpeed);
              } catch {}
            },
            onStateChange: (ev: any) => {
              if (activeEngineRef.current !== 'yt') return;
              const state = ev.data;
              // 1 = PLAYING
              if (state === 1) {
                if (intentionalPauseRef.current) {
                  try {
                    ev.target.pauseVideo();
                  } catch {}
                  setIsPlaying(false);
                  return;
                }
                if (ytFallbackWatchdogRef.current) {
                  clearTimeout(ytFallbackWatchdogRef.current);
                  ytFallbackWatchdogRef.current = null;
                }
                if (ytBufferingWatchdogRef.current) {
                  clearTimeout(ytBufferingWatchdogRef.current);
                  ytBufferingWatchdogRef.current = null;
                }
                if (resumeWatchdogRef.current) {
                  clearTimeout(resumeWatchdogRef.current);
                  resumeWatchdogRef.current = null;
                }
                recoveryAttemptsRef.current = 0;
                setPlaybackError(null);
                setIsRefreshingStream(false);
                setIsLoading(false);
                setIsPlaying(true);
                try {
                  const dur = Number(ev.target.getDuration?.() || 0);
                  if (dur > 0) setDuration(dur);
                } catch {}
              } else if (state === 2) {
                // 2 = PAUSED
                if (ytBufferingWatchdogRef.current) {
                  clearTimeout(ytBufferingWatchdogRef.current);
                  ytBufferingWatchdogRef.current = null;
                }
                if (!intentionalPauseRef.current) {
                  // If browser/iframe autoplay policy auto-paused the YT player without user clicking Pause,
                  // attempt immediate playVideo() or hand off to HTML5 <audio> stream without flipping UI to paused
                  try {
                    const pauseReqId = playRequestIdRef.current;
                    const pos = Number(ev.target.getCurrentTime?.() || stateRef.current.currentTime || 0);
                    ev.target.playVideo();
                    setTimeout(async () => {
                      if (
                        pauseReqId !== playRequestIdRef.current ||
                        activeEngineRef.current !== 'yt' ||
                        intentionalPauseRef.current
                      ) {
                        return;
                      }
                      const curState = ev.target.getPlayerState?.();
                      if (curState === 1 || curState === 3) return;
                      const activeSong = stateRef.current.currentSong;
                      const availability = activeSong
                        ? await MusicApi.checkProxyStreamPlayable(activeSong).catch(() => ({ playable: false, url: null }))
                        : { playable: false, url: null };
                      if (
                        pauseReqId !== playRequestIdRef.current ||
                        activeEngineRef.current !== 'yt' ||
                        intentionalPauseRef.current
                      ) {
                        return;
                      }
                      if (availability.playable && html5FallbackFnRef.current) {
                        html5FallbackFnRef.current(pos);
                      } else {
                        setIsLoading(false);
                        setIsPlaying(false);
                      }
                    }, 350);
                  } catch {
                    setIsLoading(false);
                    setIsPlaying(false);
                  }
                  return;
                }
                setIsLoading(false);
                setIsPlaying(false);
              } else if (state === 3) {
                // 3 = BUFFERING — guard against infinite buffering spinner mid-playback
                if (intentionalPauseRef.current) {
                  setIsLoading(false);
                  return;
                }
                setIsLoading(true);
                if (!ytBufferingWatchdogRef.current) {
                  const bufReqId = playRequestIdRef.current;
                  ytBufferingWatchdogRef.current = setTimeout(async () => {
                    ytBufferingWatchdogRef.current = null;
                    if (
                      bufReqId !== playRequestIdRef.current ||
                      activeEngineRef.current !== 'yt' ||
                      intentionalPauseRef.current
                    ) {
                      return;
                    }
                    const curState = ytPlayerRef.current?.getPlayerState?.();
                    if (curState === 1) {
                      setIsLoading(false);
                      return;
                    }
                    if (typeof navigator !== 'undefined' && navigator.onLine === false) {
                      setIsLoading(false);
                      setIsPlaying(false);
                      setPlaybackError('Offline — waiting for connection...');
                      return;
                    }
                    let savedPos = stateRef.current.currentTime || 0;
                    try {
                      const ytPos = Number(ytPlayerRef.current?.getCurrentTime?.() || 0);
                      if (ytPos > 0) savedPos = ytPos;
                    } catch {}
                    const activeSong = stateRef.current.currentSong;
                    const availability = activeSong
                      ? await MusicApi.checkProxyStreamPlayable(activeSong).catch(() => ({ playable: false, url: null }))
                      : { playable: false, url: null };
                    if (
                      bufReqId !== playRequestIdRef.current ||
                      activeEngineRef.current !== 'yt' ||
                      intentionalPauseRef.current
                    ) {
                      return;
                    }
                    if (availability.playable && html5FallbackFnRef.current) {
                      StreamLogger.log('warn', 'stall', 'ytIframe:bufferingWatchdog', 'YouTube IFrame buffered >7s, handing off to HTML5 audio stream', {
                        songId: activeSong?.id,
                        positionSec: savedPos,
                      });
                      html5FallbackFnRef.current(savedPos);
                    } else if (ytPlayerRef.current) {
                      StreamLogger.log('warn', 'stall', 'ytIframe:bufferingWatchdog', 'YouTube IFrame buffered >7s, nudging in-place YT playback (no proxy stream)', {
                        songId: activeSong?.id,
                        positionSec: savedPos,
                      });
                      try {
                        if (savedPos > 1) ytPlayerRef.current.seekTo(savedPos, true);
                        ytPlayerRef.current.playVideo();
                      } catch {
                        setIsLoading(false);
                        setIsPlaying(false);
                        setPlaybackError('Stream stalled. Tap Retry.');
                      }
                    } else {
                      setIsLoading(false);
                      setIsPlaying(false);
                      setPlaybackError('Stream stalled. Tap Retry.');
                    }
                  }, 7000);
                }
              } else if (state === 0) {
                // 0 = ENDED
                if (ytBufferingWatchdogRef.current) {
                  clearTimeout(ytBufferingWatchdogRef.current);
                  ytBufferingWatchdogRef.current = null;
                }
                if (intentionalPauseRef.current) return;
                const { isRepeat: repeatNow } = stateRef.current;
                if (repeatNow) {
                  try {
                    ev.target.seekTo(0, true);
                    ev.target.playVideo();
                  } catch {}
                } else {
                  (handlersRef.current?.handleNextSong || handleNextSong)();
                }
              }
            },
            onError: async (ytErr: any) => {
              // Video is non-embeddable (101/150) or network drop in iframe -> switch to HTML5 <audio> only if playable
              if (activeEngineRef.current !== 'yt' || intentionalPauseRef.current) return;
              const errReqId = playRequestIdRef.current;
              if (ytFallbackWatchdogRef.current) {
                clearTimeout(ytFallbackWatchdogRef.current);
                ytFallbackWatchdogRef.current = null;
              }
              if (ytBufferingWatchdogRef.current) {
                clearTimeout(ytBufferingWatchdogRef.current);
                ytBufferingWatchdogRef.current = null;
              }
              let savedPos = 0;
              try {
                savedPos = Number(ytPlayerRef.current?.getCurrentTime?.() || 0);
              } catch {}
              const activeSong = stateRef.current.currentSong;
              const availability = activeSong
                ? await MusicApi.checkProxyStreamPlayable(activeSong).catch(() => ({ playable: false, url: null }))
                : { playable: false, url: null };
              if (errReqId !== playRequestIdRef.current || activeEngineRef.current !== 'yt' || intentionalPauseRef.current) {
                return;
              }
              if (availability.playable && html5FallbackFnRef.current) {
                StreamLogger.log('warn', 'proxy_fallback', 'ytIframe', 'YouTube IFrame player errored, switching to HTML5 audio stream', {
                  songId: activeSong?.id,
                  positionSec: savedPos,
                  detail: ytErr?.data !== undefined ? `ytCode=${ytErr.data}` : undefined,
                });
                html5FallbackFnRef.current(savedPos);
              } else {
                StreamLogger.logDisconnect('ytIframe', 'YouTube IFrame errored and no proxy fallback stream exists', {
                  songId: activeSong?.id,
                  positionSec: savedPos,
                  detail: ytErr?.data !== undefined ? `ytCode=${ytErr.data}` : undefined,
                });
                setIsLoading(false);
                setIsPlaying(false);
                setPlaybackError('Stream unavailable. Tap Retry.');
              }
            },
          },
        });
      } catch {}
    };

    if ((window as any).YT && (window as any).YT.Player) {
      initYtPlayer();
    } else {
      const prevCallback = (window as any).onYouTubeIframeAPIReady;
      (window as any).onYouTubeIframeAPIReady = () => {
        if (typeof prevCallback === 'function') prevCallback();
        initYtPlayer();
      };
      if (!document.querySelector('script[src*="youtube.com/iframe_api"]')) {
        const tag = document.createElement('script');
        tag.src = 'https://youtube.com/iframe_api';
        tag.async = true;
        document.head.appendChild(tag);
      }
    }

    ytProgressIntervalRef.current = setInterval(() => {
      if (activeEngineRef.current !== 'yt' || !ytPlayerRef.current || !ytReadyRef.current) return;
      try {
        const pState = ytPlayerRef.current.getPlayerState?.();
        if (pState === 1) {
          const cur = Number(ytPlayerRef.current.getCurrentTime?.() || 0);
          if (!isNaN(cur) && cur >= 0) {
            setCurrentTime(cur);
          }
          const dur = Number(ytPlayerRef.current.getDuration?.() || 0);
          if (!isNaN(dur) && dur > 0) {
            setDuration(dur);
          }
        }
      } catch {}
    }, 250);

    audio.ontimeupdate = () => {
      if (isPrimingAudioRef.current || activeEngineRef.current !== 'html5') return;
      setCurrentTime(audio.currentTime);
      if (audio.duration && !isNaN(audio.duration) && audio.duration > 0) {
        setDuration(audio.duration);
      }
      if (audio.currentTime > 0 && !audio.paused) {
        if (html5LoadWatchdogRef.current) {
          clearTimeout(html5LoadWatchdogRef.current);
          html5LoadWatchdogRef.current = null;
        }
        if (resumeWatchdogRef.current) {
          clearTimeout(resumeWatchdogRef.current);
          resumeWatchdogRef.current = null;
        }
        setIsLoading(false);
        setIsRefreshingStream(false);
        setIsPlaying(true);
      }
    };

    const classifyMediaError = (err: MediaError | null): string => {
      if (!err) return 'UNKNOWN_MEDIA_ERROR';
      switch (err.code) {
        case 1:
          return 'MEDIA_ERR_ABORTED';
        case 2:
          return 'MEDIA_ERR_NETWORK';
        case 3:
          return 'MEDIA_ERR_DECODE';
        case 4:
          return 'MEDIA_ERR_SRC_NOT_SUPPORTED';
        default:
          return `MEDIA_ERR_${err.code}`;
      }
    };

    const armBufferWatchdog = (reason: 'waiting' | 'stalled') => {
      if (isPrimingAudioRef.current || activeEngineRef.current !== 'html5' || intentionalPauseRef.current) return;
      const curAttrSrc = audio.getAttribute('src') || '';
      if (!curAttrSrc || curAttrSrc.startsWith('data:audio/wav') || audio.src.startsWith('blob:')) return;
      if (audio.readyState < 3 && !audio.paused) {
        setIsLoading(true);
      }
      if (!html5LoadWatchdogRef.current) {
        const waitReqId = playRequestIdRef.current;
        const activeSong = stateRef.current.currentSong;
        StreamLogger.log('warn', 'stall', `html5:${reason}`, `Audio stream ${reason} while buffering`, {
          songId: activeSong?.id,
          positionSec: audio.currentTime || stateRef.current.currentTime,
          detail: `readyState=${audio.readyState}, networkState=${audio.networkState}`,
        });
        html5LoadWatchdogRef.current = setTimeout(async () => {
          html5LoadWatchdogRef.current = null;
          if (
            waitReqId === playRequestIdRef.current &&
            activeEngineRef.current === 'html5' &&
            !intentionalPauseRef.current &&
            audioRef.current &&
            (audioRef.current.readyState < 3 || audioRef.current.paused)
          ) {
            if (typeof navigator !== 'undefined' && navigator.onLine === false) {
              StreamLogger.log('warn', 'offline', 'html5Watchdog', 'Stream stalled because browser went offline', {
                songId: stateRef.current.currentSong?.id,
                positionSec: audioRef.current.currentTime,
              });
              setIsLoading(false);
              setIsPlaying(false);
              setPlaybackError('Offline — waiting for connection...');
              return;
            }
            const stalledSong = stateRef.current.currentSong;
            if (stalledSong && recoveryAttemptsRef.current < 2) {
              recoveryAttemptsRef.current += 1;
              const savedPos = audioRef.current.currentTime || stateRef.current.currentTime || 0;
              StreamLogger.logRetry('html5Watchdog', 'Recovering stalled HTML5 stream with fresh URL', {
                songId: stalledSong.id,
                attempt: recoveryAttemptsRef.current,
                maxAttempts: 3,
                positionSec: savedPos,
              });
              setIsRefreshingStream(true);
              MusicApi.invalidateClientDirectStreamCache(stalledSong.id);
              const availability = await MusicApi.checkProxyStreamPlayable(stalledSong, true).catch(() => ({
                playable: false,
                url: null,
              }));
              if (
                waitReqId !== playRequestIdRef.current ||
                activeEngineRef.current !== 'html5' ||
                intentionalPauseRef.current ||
                !audioRef.current
              ) {
                return;
              }
              const freshUrl =
                availability.url ||
                (availability.playable ? buildFreshStreamUrl({ ...stalledSong, audioUrl: undefined }) : '');
              if (!freshUrl) {
                setIsLoading(false);
                setIsRefreshingStream(false);
                setIsPlaying(false);
                setPlaybackError('Connection stalled. Tap Retry.');
                return;
              }
              applyAudioSourceWithSeek(audioRef.current, freshUrl, savedPos, waitReqId);
              audioRef.current.play().catch(() => {
                if (waitReqId === playRequestIdRef.current) {
                  setIsLoading(false);
                  setIsRefreshingStream(false);
                  setIsPlaying(false);
                  setPlaybackError('Connection stalled. Tap Retry.');
                }
              });
              return;
            }
            StreamLogger.logDisconnect('html5Watchdog', 'Stream buffer watchdog timed out after retries', {
              songId: stalledSong?.id,
              positionSec: audioRef.current.currentTime,
            });
            setIsLoading(false);
            setIsRefreshingStream(false);
            setIsPlaying(false);
            setPlaybackError('Connection stalled. Tap Retry.');
          }
        }, 12000);
      }
    };

    audio.onwaiting = () => armBufferWatchdog('waiting');
    audio.onstalled = () => armBufferWatchdog('stalled');
    audio.oncanplay = () => {
      if (isPrimingAudioRef.current || activeEngineRef.current !== 'html5') return;
      if (html5LoadWatchdogRef.current) {
        clearTimeout(html5LoadWatchdogRef.current);
        html5LoadWatchdogRef.current = null;
      }
      setIsLoading(false);
      setIsRefreshingStream(false);
    };
    audio.oncanplaythrough = () => {
      if (isPrimingAudioRef.current || activeEngineRef.current !== 'html5') return;
      if (html5LoadWatchdogRef.current) {
        clearTimeout(html5LoadWatchdogRef.current);
        html5LoadWatchdogRef.current = null;
      }
      setIsLoading(false);
      setIsRefreshingStream(false);
    };
    audio.onplaying = () => {
      if (isPrimingAudioRef.current || activeEngineRef.current !== 'html5') return;
      if (intentionalPauseRef.current) {
        audio.pause();
        setIsPlaying(false);
        return;
      }
      if (html5LoadWatchdogRef.current) {
        clearTimeout(html5LoadWatchdogRef.current);
        html5LoadWatchdogRef.current = null;
      }
      if (resumeWatchdogRef.current) {
        clearTimeout(resumeWatchdogRef.current);
        resumeWatchdogRef.current = null;
      }
      if (recoveryAttemptsRef.current > 0) {
        StreamLogger.logRecovery('html5', 'Playback recovered after intermittent disconnection', {
          songId: stateRef.current.currentSong?.id,
          positionSec: audio.currentTime,
        });
      }
      audioUnlockedRef.current = true;
      recoveryAttemptsRef.current = 0;
      setPlaybackError(null);
      setIsRefreshingStream(false);
      setIsLoading(false);
      setIsPlaying(true);
    };
    audio.onpause = () => {
      if (isPrimingAudioRef.current || activeEngineRef.current !== 'html5') return;
      if (!intentionalPauseRef.current && !audio.ended && stateRef.current.isLoading) {
        return;
      }
      setIsPlaying(false);
    };

    audio.onended = () => {
      if (
        isPrimingAudioRef.current ||
        activeEngineRef.current !== 'html5' ||
        intentionalPauseRef.current ||
        !hasInitializedStreamRef.current ||
        (audio.getAttribute('src') || '').startsWith('data:audio/wav')
      ) {
        return;
      }
      const { isRepeat: repeatNow } = stateRef.current;
      if (repeatNow) {
        audio.currentTime = 0;
        audio.play().catch(() => {});
      } else {
        (handlersRef.current?.handleNextSong || handleNextSong)();
      }
    };

    audio.onerror = () => {
      if (
        isPrimingAudioRef.current ||
        activeEngineRef.current !== 'html5' ||
        intentionalPauseRef.current ||
        playDebounceTimerRef.current !== null ||
        !audio.getAttribute('src')
      ) {
        return;
      }
      if (html5LoadWatchdogRef.current) {
        clearTimeout(html5LoadWatchdogRef.current);
        html5LoadWatchdogRef.current = null;
      }
      const mediaErrLabel = classifyMediaError(audio.error);
      if (typeof navigator !== 'undefined' && navigator.onLine === false && !audio.src.startsWith('blob:')) {
        StreamLogger.log('warn', 'offline', 'html5:onerror', 'Audio element failed while device is offline', {
          songId: stateRef.current.currentSong?.id,
          mediaErrorCode: audio.error?.code,
          positionSec: audio.currentTime || stateRef.current.currentTime,
          detail: mediaErrLabel,
        });
        setIsLoading(false);
        setIsRefreshingStream(false);
        setIsPlaying(false);
        setPlaybackError('Offline — waiting for connection...');
        return;
      }
      const { currentSong: activeSong, currentTime: savedPos } = stateRef.current;
      const errReqId = playRequestIdRef.current;
      StreamLogger.log('error', 'media_error', 'html5:onerror', `Audio playback error (${mediaErrLabel})`, {
        songId: activeSong?.id,
        mediaErrorCode: audio.error?.code,
        attempt: recoveryAttemptsRef.current + 1,
        maxAttempts: 3,
        positionSec: savedPos,
        detail: `${mediaErrLabel}: ${(audio.getAttribute('src') || '').split('?')[0]}`,
      });
      if (recoveryAttemptsRef.current < 3 && activeSong) {
        recoveryAttemptsRef.current += 1;
        const attempt = recoveryAttemptsRef.current;
        const backoffMs = attempt === 1 ? 150 : 700 * attempt;
        if (errorRecoveryTimerRef.current) clearTimeout(errorRecoveryTimerRef.current);
        setIsRefreshingStream(true);
        StreamLogger.logRetry('html5:onerror', 'Scheduling automatic stream recovery', {
          songId: activeSong.id,
          attempt,
          maxAttempts: 3,
          positionSec: savedPos,
          detail: `backoff=${backoffMs}ms`,
        });
        errorRecoveryTimerRef.current = setTimeout(async () => {
          errorRecoveryTimerRef.current = null;
          if (
            activeEngineRef.current !== 'html5' ||
            intentionalPauseRef.current ||
            !audioRef.current ||
            errReqId !== playRequestIdRef.current
          ) {
            return;
          }

          MusicApi.invalidateClientDirectStreamCache(activeSong.id);
          const failedSrc = audioRef.current.getAttribute('src') || '';
          if (failedSrc.startsWith('blob:')) {
            try {
              if ('caches' in window) {
                const cache = await caches.open(OFFLINE_CACHE_NAME);
                await cache.delete(`/offline-audio/${encodeURIComponent(activeSong.id)}`);
              }
              await deleteOfflineBlobFromIdb(activeSong.id);
            } catch {}
          }
          const cleanId = (activeSong.id || '').trim();
          const isStdYt =
            cleanId.length === 11 &&
            !cleanId.startsWith('sp_') &&
            !cleanId.startsWith('js_') &&
            /^[a-zA-Z0-9_-]{11}$/.test(cleanId);

          const availability = await MusicApi.checkProxyStreamPlayable(activeSong, true).catch(() => ({
            playable: false,
            url: null,
          }));
          if (
            activeEngineRef.current !== 'html5' ||
            intentionalPauseRef.current ||
            !audioRef.current ||
            errReqId !== playRequestIdRef.current
          ) {
            return;
          }

          let fallbackSrc = '';
          if (availability.url && availability.url !== failedSrc) {
            fallbackSrc = availability.url;
          } else if (availability.playable && !failedSrc.includes('/api/stream/')) {
            fallbackSrc = `/api/stream/${encodeURIComponent(activeSong.id)}?title=${encodeURIComponent(
              activeSong.title
            )}&artist=${encodeURIComponent(activeSong.artist)}&duration=${encodeURIComponent(
              String(activeSong.durationSeconds || 0)
            )}&refresh=1&retry=${Date.now()}`;
          }

          if (
            !fallbackSrc &&
            isStdYt &&
            ytReadyRef.current &&
            ytPlayerRef.current &&
            !document.hidden
          ) {
            try {
              activeEngineRef.current = 'yt';
              audioRef.current.pause();
              ytPlayerRef.current.loadVideoById({
                videoId: cleanId,
                startSeconds: savedPos > 1 ? Math.floor(savedPos) : 0,
              });
              ytPlayerRef.current.playVideo();
              return;
            } catch {
              activeEngineRef.current = 'html5';
            }
          }

          if (!fallbackSrc) {
            if (availability.playable) {
              fallbackSrc = `/api/stream/${encodeURIComponent(activeSong.id)}?title=${encodeURIComponent(
                activeSong.title
              )}&artist=${encodeURIComponent(activeSong.artist)}&duration=${encodeURIComponent(
                String(activeSong.durationSeconds || 0)
              )}&refresh=1&retry=${Date.now()}`;
            } else {
              StreamLogger.logDisconnect('html5:onerror', 'Stopping HTML5 recovery: no playable audio stream resolved', {
                songId: activeSong.id,
                attempt,
                positionSec: savedPos,
              });
              setIsLoading(false);
              setIsRefreshingStream(false);
              setIsPlaying(false);
              setPlaybackError('Stream unavailable. Tap Retry.');
              return;
            }
          }

          applyAudioSourceWithSeek(audioRef.current, fallbackSrc, savedPos, errReqId);
          audioRef.current
            .play()
            .then(() => {
              if (errReqId === playRequestIdRef.current && !intentionalPauseRef.current) {
                StreamLogger.logRecovery('html5:onerror', 'Recovered playback after stream refresh', {
                  songId: activeSong.id,
                  attempt,
                  positionSec: savedPos,
                });
                setPlaybackError(null);
                setIsPlaying(true);
                setIsLoading(false);
                setIsRefreshingStream(false);
              }
            })
            .catch((playErr: any) => {
              StreamLogger.logDisconnect('html5:onerror', 'Recovery play() rejected', {
                songId: activeSong.id,
                attempt,
                maxAttempts: 3,
                detail: playErr?.message || String(playErr),
              });
              if (errReqId === playRequestIdRef.current) {
                setIsLoading(false);
                setIsRefreshingStream(false);
                if (attempt >= 3) {
                  setIsPlaying(false);
                  setPlaybackError('Playback interrupted. Tap Retry.');
                }
              }
            });
        }, backoffMs);
      } else {
        StreamLogger.log('error', 'network_disconnect', 'html5:onerror', 'Stream recovery attempts exhausted', {
          songId: activeSong?.id,
          attempt: recoveryAttemptsRef.current,
          maxAttempts: 3,
          positionSec: savedPos,
        });
        setIsLoading(false);
        setIsRefreshingStream(false);
        setIsPlaying(false);
        setPlaybackError('Stream unavailable. Tap Retry.');
      }
    };

    return () => {
      if (playDebounceTimerRef.current) clearTimeout(playDebounceTimerRef.current);
      if (errorRecoveryTimerRef.current) clearTimeout(errorRecoveryTimerRef.current);
      if (ytFallbackWatchdogRef.current) clearTimeout(ytFallbackWatchdogRef.current);
      if (ytBufferingWatchdogRef.current) clearTimeout(ytBufferingWatchdogRef.current);
      if (ytProgressIntervalRef.current) clearInterval(ytProgressIntervalRef.current);
      if (loadedMetadataCleanupRef.current) {
        loadedMetadataCleanupRef.current();
        loadedMetadataCleanupRef.current = null;
      }
      if (streamAbortControllerRef.current) {
        try {
          streamAbortControllerRef.current.abort();
        } catch {}
      }
      if (resumeWatchdogRef.current) clearTimeout(resumeWatchdogRef.current);
      if (html5LoadWatchdogRef.current) clearTimeout(html5LoadWatchdogRef.current);
      if (proactivePauseTimerRef.current) clearTimeout(proactivePauseTimerRef.current);
      if (activeObjectUrlRef.current) URL.revokeObjectURL(activeObjectUrlRef.current);
      try {
        ytPlayerRef.current?.stopVideo?.();
      } catch {}
      audio.pause();
    };
  }, []);

  // Register Web MediaSession metadata & action handlers per song (not 4x/sec during timeupdate)
  useEffect(() => {
    if (!('mediaSession' in navigator) || !currentSong) return;

    try {
      navigator.mediaSession.metadata = new MediaMetadata({
        title: currentSong.title,
        artist: currentSong.artist,
        album: 'Twilight Music',
        artwork: [
          { src: currentSong.thumbnailUrl, sizes: '96x96', type: 'image/jpeg' },
          { src: currentSong.thumbnailUrl, sizes: '128x128', type: 'image/jpeg' },
          { src: currentSong.thumbnailUrl, sizes: '192x192', type: 'image/jpeg' },
          { src: currentSong.thumbnailUrl, sizes: '256x256', type: 'image/jpeg' },
          { src: currentSong.thumbnailUrl, sizes: '384x384', type: 'image/jpeg' },
          { src: currentSong.thumbnailUrl, sizes: '512x512', type: 'image/jpeg' },
        ],
      });

      navigator.mediaSession.setActionHandler('play', () =>
        (handlersRef.current?.resumeSong || resumeSong)()
      );
      navigator.mediaSession.setActionHandler('pause', () =>
        (handlersRef.current?.pauseSong || pauseSong)()
      );
      navigator.mediaSession.setActionHandler('previoustrack', () =>
        (handlersRef.current?.handlePrevSong || handlePrevSong)()
      );
      navigator.mediaSession.setActionHandler('nexttrack', () =>
        (handlersRef.current?.handleNextSong || handleNextSong)()
      );
      navigator.mediaSession.setActionHandler('seekto', (details) => {
        if (details.seekTime !== undefined) {
          (handlersRef.current?.seekTo || seekTo)(details.seekTime);
        }
      });
    } catch (e) {
      console.warn('MediaSession registration error:', e);
    }
  }, [currentSong]);

  useEffect(() => {
    if (!('mediaSession' in navigator) || !currentSong) return;
    try {
      navigator.mediaSession.playbackState = isPlaying ? 'playing' : 'paused';
    } catch {}
  }, [currentSong, isPlaying]);

  const flooredPositionSec = Math.floor(currentTime);
  useEffect(() => {
    if (!('mediaSession' in navigator) || !currentSong || duration <= 0) return;
    if ('setPositionState' in navigator.mediaSession) {
      try {
        navigator.mediaSession.setPositionState({
          duration: Math.max(duration, 1),
          playbackRate: playbackSpeed,
          position: Math.min(Math.max(flooredPositionSec, 0), duration),
        });
      } catch {}
    }
  }, [currentSong, flooredPositionSec, duration, playbackSpeed]);

  // Keep screen wake lock active while music is playing to prevent OS audio sleep
  useEffect(() => {
    let wakeLock: any = null;
    const requestLock = async () => {
      if ('wakeLock' in navigator && isPlaying) {
        try {
          wakeLock = await (navigator as any).wakeLock.request('screen');
        } catch (_) {}
      }
    };

    if (isPlaying) {
      requestLock();
    } else if (wakeLock) {
      wakeLock.release().catch(() => {});
    }

    return () => {
      if (wakeLock) wakeLock.release().catch(() => {});
    };
  }, [isPlaying]);

  // Continuous background audio guarantee & automatic network recovery on reconnect
  useEffect(() => {
    const handleVisibility = () => {
      if (!document.hidden || !isPlaying || intentionalPauseRef.current) return;
      if (activeEngineRef.current === 'yt' && ytPlayerRef.current && ytReadyRef.current) {
        try {
          ytPlayerRef.current.playVideo();
        } catch {}
      } else if (audioRef.current && audioRef.current.paused) {
        audioRef.current.play().catch(() => {});
      }
    };
    const handleOffline = () => {
      const { currentSong: activeSong } = stateRef.current;
      const isBlobOffline = audioRef.current?.src?.startsWith('blob:') ?? false;
      if (isBlobOffline || !activeSong) return;
      StreamLogger.log('warn', 'offline', 'networkListener', 'Browser connectivity lost during audio session', {
        songId: activeSong.id,
        positionSec: audioRef.current?.currentTime || stateRef.current.currentTime,
      });
      if (errorRecoveryTimerRef.current) {
        clearTimeout(errorRecoveryTimerRef.current);
        errorRecoveryTimerRef.current = null;
      }
    };
    const handleOnline = () => {
      const { currentSong: activeSong, playbackError: activeErr } = stateRef.current;
      StreamLogger.log('info', 'online', 'networkListener', 'Browser connectivity restored', {
        songId: activeSong?.id,
      });
      if (activeSong && activeErr && !intentionalPauseRef.current) {
        recoveryAttemptsRef.current = 0;
        (handlersRef.current?.retryCurrentSong || retryCurrentSong)();
      }
    };
    document.addEventListener('visibilitychange', handleVisibility);
    window.addEventListener('offline', handleOffline);
    window.addEventListener('online', handleOnline);
    return () => {
      document.removeEventListener('visibilitychange', handleVisibility);
      window.removeEventListener('offline', handleOffline);
      window.removeEventListener('online', handleOnline);
    };
  }, [isPlaying]);

  // Sleep Timer countdown
  useEffect(() => {
    if (sleepTimerRemaining === null) return;
    if (sleepTimerRemaining <= 0) {
      (handlersRef.current?.pauseSong || pauseSong)();
      setSleepTimerRemaining(null);
      return;
    }

    const interval = setInterval(() => {
      setSleepTimerRemaining((prev) => (prev !== null && prev > 0 ? prev - 1 : null));
    }, 1000);

    return () => clearInterval(interval);
  }, [sleepTimerRemaining]);

  // Firebase Auth listener
  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (fbUser) => {
      if (fbUser) {
        setUser({
          uid: fbUser.uid,
          email: fbUser.email,
          displayName: fbUser.displayName || fbUser.email?.split('@')[0] || 'User',
          photoURL: fbUser.photoURL,
          isGuest: false,
        });

        // Load user cloud data
        const cloudData = await CloudSyncService.loadUserData(fbUser.uid);
        if (cloudData) {
          if (cloudData.favorites) setFavorites(cloudData.favorites);
          if (cloudData.playlists) setPlaylists(cloudData.playlists);
          if (cloudData.history) setHistory(cloudData.history);
        }
      } else {
        setUser({
          uid: 'usr_hasibul_hasan',
          email: 'gudhulibela031@gmail.com',
          displayName: 'Hasibul Hasan',
          photoURL: null,
          isGuest: false,
        });
      }
    });

    return () => unsubscribe();
  }, []);

  // Sync to LocalStorage & Cloud
  useEffect(() => {
    try {
      localStorage.setItem(STORAGE_KEYS.FAVORITES, JSON.stringify(favorites));
      localStorage.setItem(STORAGE_KEYS.HISTORY, JSON.stringify(history));
      localStorage.setItem(STORAGE_KEYS.PLAYLISTS, JSON.stringify(playlists));
      localStorage.setItem(STORAGE_KEYS.DOWNLOADS, JSON.stringify(downloads));
      localStorage.setItem(STORAGE_KEYS.PLAY_COUNTS, JSON.stringify(playCounts));
    } catch {}

    if (!user.isGuest && user.uid) {
      CloudSyncService.saveUserData(user.uid, { favorites, playlists, history });
    }
  }, [favorites, history, playlists, downloads, playCounts, user.uid, user.isGuest]);

  // Synthetic Ambient Music for bulletproof audio fallback
  const playSyntheticMelody = () => {
    try {
      if (!audioCtxRef.current) {
        const AudioCtx = window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
        audioCtxRef.current = new AudioCtx();
      }
      const ctx = audioCtxRef.current;
      if (ctx.state === 'suspended') {
        ctx.resume();
      }
      if (synthOscRef.current) {
        synthOscRef.current.stop();
        synthOscRef.current.disconnect();
      }
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(261.63, ctx.currentTime); // C4
      gain.gain.setValueAtTime(0.04, ctx.currentTime);
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start();
      synthOscRef.current = osc;
      setIsPlaying(true);
    } catch {}
  };

  const stopSyntheticMelody = () => {
    if (synthOscRef.current) {
      try {
        synthOscRef.current.stop();
        synthOscRef.current.disconnect();
      } catch {}
      synthOscRef.current = null;
    }
  };

  // Resilient audio blob fetcher with bounded exponential backoff for offline caching
  const fetchAudioBlobWithRetry = async (
    url: string,
    retries = 2,
    timeoutMs = 12000
  ): Promise<Blob | null> => {
    const endpointLabel = url.split('?')[0];
    for (let attempt = 0; attempt <= retries; attempt++) {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), timeoutMs);
      try {
        const res = await fetch(url, { signal: controller.signal });
        clearTimeout(timer);
        const ct = (res.headers.get('content-type') || '').toLowerCase();
        if (
          res.ok &&
          !ct.includes('text/html') &&
          !ct.includes('application/json') &&
          !ct.includes('mpegurl')
        ) {
          const blob = await res.blob();
          if (await isHealthyAudioBlob(blob)) {
            return blob;
          }
        }
        if (res.status >= 400 && res.status < 500 && res.status !== 408 && res.status !== 429) {
          StreamLogger.logDisconnect('offlineBlobFetch', `Blob download rejected status ${res.status}`, {
            statusCode: res.status,
            detail: endpointLabel,
          });
          return null;
        }
        if (attempt < retries) {
          StreamLogger.logRetry('offlineBlobFetch', `Retrying blob download after status ${res.status}`, {
            statusCode: res.status,
            attempt: attempt + 1,
            maxAttempts: retries + 1,
            detail: endpointLabel,
          });
        }
      } catch (err: any) {
        clearTimeout(timer);
        if (attempt < retries) {
          StreamLogger.logRetry('offlineBlobFetch', 'Retrying blob download after network error', {
            attempt: attempt + 1,
            maxAttempts: retries + 1,
            detail: err?.message || endpointLabel,
          });
        } else {
          StreamLogger.logDisconnect('offlineBlobFetch', 'Blob download failed after retries', {
            attempt: attempt + 1,
            maxAttempts: retries + 1,
            detail: err?.message || endpointLabel,
          });
        }
      }
      if (attempt < retries) {
        await new Promise((resolve) => setTimeout(resolve, 300 * Math.pow(2, attempt)));
      }
    }
    return null;
  };

  // Build a clean stream URL with exact track metadata (title + artist + duration) for multi-source resolution
  const buildStreamUrl = (song: Song, extraQuery?: string): string => {
    if (song.audioUrl && !isShortPreviewUrl(song.audioUrl)) {
      if (!extraQuery) return song.audioUrl;
      const base = song.audioUrl.split('?')[0];
      return `${base}?${extraQuery}`;
    }
    const base = `/api/stream/${encodeURIComponent(song.id)}?title=${encodeURIComponent(song.title)}&artist=${encodeURIComponent(song.artist)}&duration=${encodeURIComponent(String(song.durationSeconds || 0))}`;
    return extraQuery ? `${base}&${extraQuery}` : base;
  };

  // Build a clean cache-busted stream URL without duplicating query parameters
  const buildFreshStreamUrl = (song: Song): string => {
    return buildStreamUrl(song, `refresh=1&t=${Date.now()}`);
  };

  // Normalize track artwork so YouTube 404 maxresdefault URLs or mismatched thumbnails
  // always resolve to verified HQ track thumbnails (hqdefault.jpg), and strip any 30s preview audioUrl
  const normalizeTrackArtwork = (song: Song): Song => {
    const cleanId = (song.id || '').trim();
    const rawThumb = (song.thumbnailUrl || '').trim();
    const isValidYtId =
      cleanId.length === 11 &&
      !cleanId.startsWith('sp_') &&
      !cleanId.startsWith('js_') &&
      /^[a-zA-Z0-9_-]{11}$/.test(cleanId);

    let verifiedThumb = rawThumb;
    if (isValidYtId) {
      verifiedThumb = `https://i.ytimg.com/vi/${cleanId}/hqdefault.jpg`;
    } else if (!rawThumb || rawThumb.includes('picsum.photos')) {
      verifiedThumb = 'https://i.ytimg.com/vi/fJ9rUzIMcZQ/hqdefault.jpg';
    } else if (rawThumb.includes('ytimg.com/vi/') || rawThumb.includes('img.youtube.com/vi/')) {
      verifiedThumb = rawThumb
        .replace('/maxresdefault.jpg', '/hqdefault.jpg')
        .replace('/sddefault.jpg', '/hqdefault.jpg')
        .replace('img.youtube.com', 'i.ytimg.com');
    }

    const knownMaster = MusicApi.resolveKnownFullLengthMaster(song);
    const sanitizedAudioUrl = knownMaster || (isShortPreviewUrl(song.audioUrl) ? undefined : song.audioUrl);
    if (verifiedThumb === song.thumbnailUrl && sanitizedAudioUrl === song.audioUrl) return song;
    return { ...song, thumbnailUrl: verifiedThumb, audioUrl: sanitizedAudioUrl };
  };

  // Helper to assign HTML5 audio source and reliably restore seek position, volume & speed
  // once media metadata is loaded (preventing browsers from clamping currentTime to 0).
  const applyAudioSourceWithSeek = (
    audio: HTMLAudioElement,
    url: string,
    seekSeconds: number = 0,
    expectedReqId?: number
  ) => {
    if (loadedMetadataCleanupRef.current) {
      loadedMetadataCleanupRef.current();
      loadedMetadataCleanupRef.current = null;
    }
    const safeSeek = Number.isFinite(seekSeconds) && seekSeconds > 0 ? seekSeconds : 0;
    const onLoadedMeta = () => {
      audio.removeEventListener('loadedmetadata', onLoadedMeta);
      if (loadedMetadataCleanupRef.current === cleanup) {
        loadedMetadataCleanupRef.current = null;
      }
      if (expectedReqId !== undefined && expectedReqId !== playRequestIdRef.current) return;
      if (intentionalPauseRef.current) return;
      try {
        audio.playbackRate = stateRef.current.playbackSpeed;
        audio.volume = stateRef.current.volume;
        if (safeSeek > 0) {
          audio.currentTime = safeSeek;
        }
      } catch {}
    };
    const cleanup = () => {
      audio.removeEventListener('loadedmetadata', onLoadedMeta);
    };
    loadedMetadataCleanupRef.current = cleanup;
    audio.addEventListener('loadedmetadata', onLoadedMeta);
    audio.playbackRate = stateRef.current.playbackSpeed;
    audio.volume = stateRef.current.volume;
    audio.src = url;
    if (safeSeek > 0 && audio.readyState >= 1) {
      try {
        audio.currentTime = safeSeek;
      } catch {}
    }
  };

  // Explicit 'stop current' instruction that clears any pending player initialization,
  // cancels active debounce/watchdog timers, and halts both YT and HTML5 audio engines
  // before launching a new track so overlapping audio instances never occur.
  const stopCurrentBeforeSwitch = () => {
    if (playDebounceTimerRef.current) {
      clearTimeout(playDebounceTimerRef.current);
      playDebounceTimerRef.current = null;
    }
    if (errorRecoveryTimerRef.current) {
      clearTimeout(errorRecoveryTimerRef.current);
      errorRecoveryTimerRef.current = null;
    }
    if (ytFallbackWatchdogRef.current) {
      clearTimeout(ytFallbackWatchdogRef.current);
      ytFallbackWatchdogRef.current = null;
    }
    if (ytBufferingWatchdogRef.current) {
      clearTimeout(ytBufferingWatchdogRef.current);
      ytBufferingWatchdogRef.current = null;
    }
    if (loadedMetadataCleanupRef.current) {
      loadedMetadataCleanupRef.current();
      loadedMetadataCleanupRef.current = null;
    }
    if (streamAbortControllerRef.current) {
      try {
        streamAbortControllerRef.current.abort();
      } catch {}
      streamAbortControllerRef.current = null;
    }
    if (resumeWatchdogRef.current) {
      clearTimeout(resumeWatchdogRef.current);
      resumeWatchdogRef.current = null;
    }
    if (html5LoadWatchdogRef.current) {
      clearTimeout(html5LoadWatchdogRef.current);
      html5LoadWatchdogRef.current = null;
    }
    if (proactivePauseTimerRef.current) {
      clearTimeout(proactivePauseTimerRef.current);
      proactivePauseTimerRef.current = null;
    }
    html5FallbackFnRef.current = null;
    prewarmedStreamRef.current = null;
    recoveryAttemptsRef.current = 0;
    hasInitializedStreamRef.current = false;
    isPrimingAudioRef.current = false;
    setIsRefreshingStream(false);
    stopSyntheticMelody();

    if (ytPlayerRef.current && ytReadyRef.current) {
      try {
        ytPlayerRef.current.stopVideo();
      } catch {}
    }

    if (audioRef.current) {
      try {
        audioRef.current.pause();
        audioRef.current.currentTime = 0;
      } catch {}
    }
    setIsPlaying(false);
  };

  // Play a song with immediate optimistic UI update, explicit stopCurrentBeforeSwitch teardown,
  // 300ms debounced stream initialization, and same-track play/pause toggle support
  const playSong = (
    song: Song,
    newQueue?: Song[],
    options?: { immediate?: boolean; forceRestart?: boolean; targetIndex?: number }
  ) => {
    const normalizedSong = normalizeTrackArtwork(song);
    // Confirmed Decision 2: When selecting the song that is already actively playing or cleanly paused,
    // toggle play and pause without restarting playback position. If stuck loading or errored, restart cleanly.
    const isSameTrack =
      stateRef.current.currentSong?.id === normalizedSong.id ||
      stateRef.current.currentSong?.id === song.id;
    if (
      !options?.forceRestart &&
      isSameTrack &&
      !stateRef.current.playbackError
    ) {
      if (
        stateRef.current.isPlaying ||
        stateRef.current.isLoading ||
        playDebounceTimerRef.current !== null
      ) {
        pauseSong();
      } else {
        resumeSong();
      }
      return;
    }

    const unlockAudioSessionSync = () => {
      try {
        const AudioCtx =
          window.AudioContext ||
          (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
        if (AudioCtx) {
          if (!audioCtxRef.current) {
            audioCtxRef.current = new AudioCtx();
          }
          if (audioCtxRef.current.state === 'suspended') {
            audioCtxRef.current.resume().catch(() => {});
          }
        }
      } catch {}
    };

    const reqId = ++playRequestIdRef.current;
    intentionalPauseRef.current = false;
    pausedAtRef.current = null;
    setPlaybackError(null);
    unlockAudioSessionSync();

    // 1. Explicit 'stop current' instruction: clear pending initialization & silence active stream immediately
    stopCurrentBeforeSwitch();

    // Synchronously unlock the persistent HTMLAudioElement inside the user click stack
    // so deferred play() calls after 300ms debounce + async fetch never fail with NotAllowedError.
    if (!audioUnlockedRef.current && audioRef.current) {
      try {
        isPrimingAudioRef.current = true;
        audioRef.current.src =
          'data:audio/wav;base64,UklGRigAAABXQVZFZm10IBIAAAABAAEARKwAAIhYAQACABAAAABkYXRhAgAAAAEA';
        const primePromise = audioRef.current.play();
        if (primePromise && typeof primePromise.then === 'function') {
          primePromise
            .then(() => {
              audioUnlockedRef.current = true;
              if (isPrimingAudioRef.current && audioRef.current) {
                audioRef.current.pause();
                audioRef.current.currentTime = 0;
              }
              isPrimingAudioRef.current = false;
            })
            .catch(() => {
              isPrimingAudioRef.current = false;
            });
        } else {
          isPrimingAudioRef.current = false;
        }
      } catch {
        isPrimingAudioRef.current = false;
      }
    }

    // 2. Confirmed Decision 3: Update UI state immediately on tap (0ms latency) before debounce
    setCurrentSong(normalizedSong);
    setCurrentTime(0);
    setDuration(normalizedSong.durationSeconds || 210);
    setIsLoading(true);

    const activeQueue = (newQueue && newQueue.length > 0 ? newQueue : stateRef.current.queue).map(
      normalizeTrackArtwork
    );
    const hasValidTargetIdx =
      options?.targetIndex !== undefined &&
      options.targetIndex >= 0 &&
      options.targetIndex < activeQueue.length;
    if (newQueue && newQueue.length > 0) {
      setQueue(activeQueue);
      const idx = hasValidTargetIdx
        ? options!.targetIndex!
        : activeQueue.findIndex((s) => s.id === normalizedSong.id);
      setCurrentIndex(idx !== -1 ? idx : 0);
    } else if (hasValidTargetIdx) {
      setQueue(activeQueue);
      setCurrentIndex(options!.targetIndex!);
    } else {
      const existingIdx = activeQueue.findIndex((s) => s.id === normalizedSong.id);
      if (existingIdx === -1) {
        setQueue([normalizedSong, ...activeQueue]);
        setCurrentIndex(0);
      } else {
        setQueue(activeQueue);
        setCurrentIndex(existingIdx);
      }
    }

    const executeStreamInitialization = async () => {
      if (!audioRef.current || reqId !== playRequestIdRef.current || intentionalPauseRef.current) {
        return;
      }

      const abortController = new AbortController();
      streamAbortControllerRef.current = abortController;

      // Update play counts and history once debounce settles on this track
      setPlayCounts((prev) => ({
        ...prev,
        [normalizedSong.id]: (prev[normalizedSong.id] || 0) + 1,
      }));

      setHistory((prev) => {
        const filtered = prev.filter((s) => s.id !== normalizedSong.id);
        return [{ ...normalizedSong, lastPlayedAt: Date.now() }, ...filtered].slice(0, 50);
      });

      let resolvedAudioUrl = buildStreamUrl(normalizedSong);
      let loadedFromOfflineStorage = false;

      // Local-first offline check in CacheStorage + IndexedDB so Airplane Mode plays with zero network calls
      if ('caches' in window) {
        try {
          const cache = await caches.open(OFFLINE_CACHE_NAME);
          const cachePath = `/offline-audio/${encodeURIComponent(normalizedSong.id)}`;
          const cachedRes = await cache.match(cachePath);
          if (cachedRes && !abortController.signal.aborted) {
            const blob = await cachedRes.blob();
            if ((await isHealthyAudioBlob(blob)) && !abortController.signal.aborted) {
              if (activeObjectUrlRef.current) {
                URL.revokeObjectURL(activeObjectUrlRef.current);
              }
              resolvedAudioUrl = URL.createObjectURL(blob);
              activeObjectUrlRef.current = resolvedAudioUrl;
              loadedFromOfflineStorage = true;
            } else if (blob.size <= 10000 || !(await isHealthyAudioBlob(blob))) {
              await cache.delete(cachePath).catch(() => {});
            }
          }
        } catch {}
      }

      if (!loadedFromOfflineStorage && !abortController.signal.aborted) {
        try {
          const idbBlob = await getOfflineBlobFromIdb(normalizedSong.id);
          if (idbBlob && (await isHealthyAudioBlob(idbBlob)) && !abortController.signal.aborted) {
            if (activeObjectUrlRef.current) {
              URL.revokeObjectURL(activeObjectUrlRef.current);
            }
            resolvedAudioUrl = URL.createObjectURL(idbBlob);
            activeObjectUrlRef.current = resolvedAudioUrl;
            loadedFromOfflineStorage = true;
          } else if (idbBlob) {
            await deleteOfflineBlobFromIdb(normalizedSong.id).catch(() => {});
          }
        } catch {}
      }

      let directResolvedUrl: string | null = null;

      const startHtml5StreamPlayback = async (
        startOffsetSeconds: number = 0,
        skipYtFallback: boolean = false
      ) => {
        if (
          !audioRef.current ||
          reqId !== playRequestIdRef.current ||
          abortController.signal.aborted ||
          intentionalPauseRef.current
        ) {
          return;
        }
        if (
          !loadedFromOfflineStorage &&
          !directResolvedUrl &&
          resolvedAudioUrl.startsWith('/api/stream/') &&
          !abortController.signal.aborted
        ) {
          const availability = await MusicApi.checkProxyStreamPlayable(normalizedSong).catch(() => ({
            playable: false,
            url: null,
          }));
          if (
            !audioRef.current ||
            reqId !== playRequestIdRef.current ||
            abortController.signal.aborted ||
            intentionalPauseRef.current
          ) {
            return;
          }
          if (availability.url) {
            resolvedAudioUrl = availability.url;
          } else if (!availability.playable) {
            const cid = (normalizedSong.id || '').trim();
            const isStdYt =
              cid.length === 11 &&
              !cid.startsWith('sp_') &&
              !cid.startsWith('js_') &&
              /^[a-zA-Z0-9_-]{11}$/.test(cid);
            if (!skipYtFallback && isStdYt && ytReadyRef.current && ytPlayerRef.current && !document.hidden) {
              try {
                activeEngineRef.current = 'yt';
                hasInitializedStreamRef.current = true;
                streamResolvedAtRef.current = Date.now();
                ytPlayerRef.current.loadVideoById({
                  videoId: cid,
                  startSeconds: startOffsetSeconds > 1 ? Math.floor(startOffsetSeconds) : 0,
                });
                ytPlayerRef.current.playVideo();
                if (ytFallbackWatchdogRef.current) clearTimeout(ytFallbackWatchdogRef.current);
                ytFallbackWatchdogRef.current = setTimeout(() => {
                  ytFallbackWatchdogRef.current = null;
                  if (
                    reqId !== playRequestIdRef.current ||
                    activeEngineRef.current !== 'yt' ||
                    intentionalPauseRef.current
                  ) {
                    return;
                  }
                  const pState = ytPlayerRef.current?.getPlayerState?.();
                  if (pState !== 1 && pState !== 3) {
                    setIsLoading(false);
                    setIsPlaying(false);
                    setPlaybackError('Tap Play to start audio');
                  }
                }, 4000);
                return;
              } catch {}
            }
            setIsLoading(false);
            setIsRefreshingStream(false);
            setIsPlaying(false);
            setPlaybackError(skipYtFallback ? 'Tap Play to start audio' : 'Stream unavailable. Tap Retry.');
            return;
          }
        }

        activeEngineRef.current = 'html5';
        if (ytPlayerRef.current && ytReadyRef.current) {
          try {
            ytPlayerRef.current.stopVideo();
          } catch {}
        }

        if (
          !audioRef.current ||
          reqId !== playRequestIdRef.current ||
          abortController.signal.aborted ||
          intentionalPauseRef.current
        ) {
          return;
        }

        isPrimingAudioRef.current = false;
        hasInitializedStreamRef.current = true;
        streamResolvedAtRef.current = Date.now();
        setCurrentSong(normalizedSong);
        applyAudioSourceWithSeek(audioRef.current, resolvedAudioUrl, startOffsetSeconds, reqId);
        setDuration(normalizedSong.durationSeconds || 210);

        if (html5LoadWatchdogRef.current) clearTimeout(html5LoadWatchdogRef.current);
        html5LoadWatchdogRef.current = setTimeout(async () => {
          html5LoadWatchdogRef.current = null;
          if (
            reqId !== playRequestIdRef.current ||
            activeEngineRef.current !== 'html5' ||
            intentionalPauseRef.current ||
            !audioRef.current
          ) {
            return;
          }
          const stuck =
            audioRef.current.paused ||
            audioRef.current.readyState < 2 ||
            audioRef.current.currentTime === 0;
          if (!stuck) return;

          MusicApi.invalidateClientDirectStreamCache(normalizedSong.id);
          const freshDirect = await MusicApi.resolveClientDirectStreamUrl(normalizedSong, true).catch(() => null);
          const curSrc = audioRef.current?.getAttribute('src') || '';
          const altUrl =
            freshDirect && freshDirect !== curSrc
              ? freshDirect
              : !curSrc.includes('/api/stream/')
              ? buildFreshStreamUrl({ ...normalizedSong, audioUrl: undefined })
              : '';
          if (
            altUrl &&
            audioRef.current &&
            reqId === playRequestIdRef.current &&
            !intentionalPauseRef.current
          ) {
            const targetSeek = startOffsetSeconds > 0 ? startOffsetSeconds : (audioRef.current.currentTime || 0);
            applyAudioSourceWithSeek(audioRef.current, altUrl, targetSeek, reqId);
            html5LoadWatchdogRef.current = setTimeout(() => {
              html5LoadWatchdogRef.current = null;
              if (
                reqId === playRequestIdRef.current &&
                activeEngineRef.current === 'html5' &&
                !intentionalPauseRef.current &&
                audioRef.current &&
                (audioRef.current.paused || audioRef.current.currentTime === 0)
              ) {
                setIsLoading(false);
                setIsRefreshingStream(false);
                setIsPlaying(false);
                setPlaybackError('Stream timed out. Tap Retry.');
              }
            }, 6000);
            audioRef.current.play().catch(() => {});
          } else {
            setIsLoading(false);
            setIsRefreshingStream(false);
            setIsPlaying(false);
            setPlaybackError('Stream timed out. Tap Retry.');
          }
        }, 8000);

        audioRef.current
          .play()
          .then(() => {
            if (
              reqId !== playRequestIdRef.current ||
              abortController.signal.aborted ||
              intentionalPauseRef.current
            ) {
              audioRef.current?.pause();
              return;
            }
            if (html5LoadWatchdogRef.current) {
              clearTimeout(html5LoadWatchdogRef.current);
              html5LoadWatchdogRef.current = null;
            }
            audioUnlockedRef.current = true;
            setPlaybackError(null);
            setCurrentSong(normalizedSong);
            setIsPlaying(true);
            setIsLoading(false);
          })
          .catch(async (err) => {
            if (
              reqId !== playRequestIdRef.current ||
              abortController.signal.aborted ||
              intentionalPauseRef.current
            ) {
              return;
            }
            if (err && err.name === 'AbortError') {
              return;
            }
            if (html5LoadWatchdogRef.current) {
              clearTimeout(html5LoadWatchdogRef.current);
              html5LoadWatchdogRef.current = null;
            }
            if (err && (err.name === 'NotAllowedError' || String(err.message || '').includes('NotAllowedError'))) {
              setPlaybackError('Tap Play to start audio');
              setIsPlaying(false);
              setIsLoading(false);
              return;
            }

            // If <audio> already raised an error event, let unified audio.onerror recovery handle retries without racing.
            if (errorRecoveryTimerRef.current || audioRef.current?.error) {
              return;
            }

            MusicApi.invalidateClientDirectStreamCache(normalizedSong.id);
            const failedSrc = audioRef.current?.getAttribute('src') || '';
            const availability = await MusicApi.checkProxyStreamPlayable(normalizedSong, true).catch(() => ({
              playable: false,
              url: null,
            }));
            let alternateUrl =
              availability.url && availability.url !== failedSrc ? availability.url : '';
            if (!alternateUrl && availability.playable && !failedSrc.includes('/api/stream/')) {
              alternateUrl = buildFreshStreamUrl({ ...normalizedSong, audioUrl: undefined });
            }

            if (
              alternateUrl &&
              audioRef.current &&
              audioRef.current.src !== alternateUrl &&
              reqId === playRequestIdRef.current &&
              !intentionalPauseRef.current
            ) {
              applyAudioSourceWithSeek(audioRef.current, alternateUrl, startOffsetSeconds, reqId);
              audioRef.current
                .play()
                .then(() => {
                  if (reqId === playRequestIdRef.current && !intentionalPauseRef.current) {
                    audioUnlockedRef.current = true;
                    setPlaybackError(null);
                    setIsPlaying(true);
                    setIsLoading(false);
                  }
                })
                .catch(() => {
                  if (reqId === playRequestIdRef.current) {
                    setIsLoading(false);
                    setIsPlaying(false);
                    setPlaybackError('Stream unavailable. Tap Retry.');
                  }
                });
              return;
            }
            console.warn('Audio play initiated:', err);
            setIsPlaying(false);
            setIsLoading(false);
            setPlaybackError('Stream unavailable. Tap Retry.');
          });
      };

      html5FallbackFnRef.current = (pos?: number) => {
        startHtml5StreamPlayback(pos || 0);
      };

      const cleanId = (normalizedSong.id || '').trim();
      const isStandardYouTubeId =
        cleanId.length === 11 &&
        !cleanId.startsWith('sp_') &&
        !cleanId.startsWith('js_') &&
        /^[a-zA-Z0-9_-]{11}$/.test(cleanId);
      const hasLocalExactFile = Boolean(
        normalizedSong.audioUrl && normalizedSong.audioUrl.startsWith('/audio/')
      );

      // Resolve exact full-length direct stream URL (Studio Master -> 320kbps AAC CDN -> SoundCloud)
      if (!loadedFromOfflineStorage && !abortController.signal.aborted) {
        directResolvedUrl = await MusicApi.resolveClientDirectStreamUrl(normalizedSong);
        if (directResolvedUrl && !abortController.signal.aborted) {
          resolvedAudioUrl = directResolvedUrl;
        }
      }

      if (
        reqId !== playRequestIdRef.current ||
        abortController.signal.aborted ||
        intentionalPauseRef.current
      ) {
        return;
      }

      // Use YouTube IFrame Player API only when no playable backend/CDN audio stream was resolved for this YouTube video ID
      if (
        !loadedFromOfflineStorage &&
        isStandardYouTubeId &&
        !directResolvedUrl &&
        !hasLocalExactFile &&
        !document.hidden &&
        ytReadyRef.current &&
        ytPlayerRef.current
      ) {
        try {
          activeEngineRef.current = 'yt';
          hasInitializedStreamRef.current = true;
          streamResolvedAtRef.current = Date.now();
          if (audioRef.current) {
            audioRef.current.pause();
          }
          ytPlayerRef.current.setVolume(Math.round(stateRef.current.volume * 100));
          ytPlayerRef.current.setPlaybackRate(stateRef.current.playbackSpeed);
          ytPlayerRef.current.loadVideoById({
            videoId: cleanId,
            startSeconds: 0,
          });
          ytPlayerRef.current.playVideo();

          if (ytFallbackWatchdogRef.current) clearTimeout(ytFallbackWatchdogRef.current);
          ytFallbackWatchdogRef.current = setTimeout(() => {
            ytFallbackWatchdogRef.current = null;
            if (
              reqId !== playRequestIdRef.current ||
              activeEngineRef.current !== 'yt' ||
              intentionalPauseRef.current
            ) {
              return;
            }
            const pState = ytPlayerRef.current?.getPlayerState?.();
            if (pState === 1) return;
            if (pState !== 3) {
              try {
                ytPlayerRef.current?.playVideo?.();
              } catch {}
            }
            if (Boolean(directResolvedUrl) && pState !== 3) {
              startHtml5StreamPlayback(0, true);
              return;
            }
            // Give YT buffering/startup an extra 3200ms grace period before switching to HTML5
            ytFallbackWatchdogRef.current = setTimeout(() => {
              ytFallbackWatchdogRef.current = null;
              if (
                reqId !== playRequestIdRef.current ||
                activeEngineRef.current !== 'yt' ||
                intentionalPauseRef.current
              ) {
                return;
              }
              if (ytPlayerRef.current?.getPlayerState?.() !== 1) {
                startHtml5StreamPlayback(0, true);
              }
            }, 3200);
          }, 2000);
          return;
        } catch {
          // Fall through to HTML5 stream playback
        }
      }

      await startHtml5StreamPlayback(0);
    };

    // 3. Confirmed Decision 1: 300ms debounce window before launching new stream initialization
    if (options?.immediate) {
      executeStreamInitialization();
    } else {
      playDebounceTimerRef.current = setTimeout(() => {
        playDebounceTimerRef.current = null;
        executeStreamInitialization();
      }, SONG_SELECTION_DEBOUNCE_MS);
    }
  };

  const selectAndPlaySong = (song: Song, newQueue?: Song[]) => {
    playSong(song, newQueue);
  };

  const pauseSong = () => {
    intentionalPauseRef.current = true;
    const pausedTime = Date.now();
    pausedAtRef.current = pausedTime;
    if (playDebounceTimerRef.current) {
      clearTimeout(playDebounceTimerRef.current);
      playDebounceTimerRef.current = null;
    }
    if (errorRecoveryTimerRef.current) {
      clearTimeout(errorRecoveryTimerRef.current);
      errorRecoveryTimerRef.current = null;
    }
    if (ytFallbackWatchdogRef.current) {
      clearTimeout(ytFallbackWatchdogRef.current);
      ytFallbackWatchdogRef.current = null;
    }
    if (ytBufferingWatchdogRef.current) {
      clearTimeout(ytBufferingWatchdogRef.current);
      ytBufferingWatchdogRef.current = null;
    }
    if (streamAbortControllerRef.current) {
      try {
        streamAbortControllerRef.current.abort();
      } catch {}
      streamAbortControllerRef.current = null;
    }
    if (resumeWatchdogRef.current) {
      clearTimeout(resumeWatchdogRef.current);
      resumeWatchdogRef.current = null;
    }
    if (html5LoadWatchdogRef.current) {
      clearTimeout(html5LoadWatchdogRef.current);
      html5LoadWatchdogRef.current = null;
    }
    if (proactivePauseTimerRef.current) {
      clearTimeout(proactivePauseTimerRef.current);
      proactivePauseTimerRef.current = null;
    }
    stopSyntheticMelody();
    if (activeEngineRef.current === 'yt' && ytPlayerRef.current && ytReadyRef.current) {
      try {
        ytPlayerRef.current.pauseVideo();
      } catch {}
    }
    if (audioRef.current) {
      audioRef.current.pause();
      const attrSrc = audioRef.current.getAttribute('src') || '';
      if (isPrimingAudioRef.current || attrSrc.startsWith('data:audio/wav')) {
        isPrimingAudioRef.current = false;
        try {
          audioRef.current.currentTime = 0;
        } catch {}
      }
    }
    setIsPlaying(false);
    setIsLoading(false);
    setIsRefreshingStream(false);

    // Schedule proactive stream URL pre-warming if playback stays paused for > 3 minutes (180,000ms)
    const activeSong = stateRef.current.currentSong || currentSong;
    const isBlobOffline = audioRef.current?.src?.startsWith('blob:') ?? false;
    if (activeSong && hasInitializedStreamRef.current && !isBlobOffline) {
      const targetSongId = activeSong.id;
      proactivePauseTimerRef.current = setTimeout(async () => {
        if (!intentionalPauseRef.current || stateRef.current.currentSong?.id !== targetSongId) {
          return;
        }
        try {
          const res = await fetch(
            `/api/stream/${encodeURIComponent(targetSongId)}/resolve?title=${encodeURIComponent(activeSong.title)}&artist=${encodeURIComponent(activeSong.artist)}&t=${Date.now()}`,
            {
              cache: 'no-store',
            }
          );
          if (res.ok) {
            const data = await res.json();
            if (data?.streamUrl) {
              prewarmedStreamRef.current = {
                songId: targetSongId,
                url: data.streamUrl,
                resolvedAt: Date.now(),
              };
              return;
            }
          }
        } catch {}
        prewarmedStreamRef.current = {
          songId: targetSongId,
          url: buildFreshStreamUrl(activeSong),
          resolvedAt: Date.now(),
        };
      }, PROACTIVE_PAUSE_REFRESH_MS);
    }
  };

  const resumeSong = () => {
    const activeSong = stateRef.current.currentSong || currentSong;
    if (!activeSong) return;
    intentionalPauseRef.current = false;
    setPlaybackError(null);
    try {
      const AudioCtx =
        window.AudioContext ||
        (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
      if (AudioCtx) {
        if (!audioCtxRef.current) audioCtxRef.current = new AudioCtx();
        if (audioCtxRef.current.state === 'suspended') {
          audioCtxRef.current.resume().catch(() => {});
        }
      }
    } catch {}
    if (proactivePauseTimerRef.current) {
      clearTimeout(proactivePauseTimerRef.current);
      proactivePauseTimerRef.current = null;
    }

    // If the user paused during the 300ms debounce or initial stream resolution (before any engine initialized),
    // run a clean immediate playSong rather than trying to resume an uninitialized or silent primer element.
    const currentAttrSrc = audioRef.current?.getAttribute('src') || '';
    if (
      !hasInitializedStreamRef.current ||
      (activeEngineRef.current === 'html5' && (!currentAttrSrc || currentAttrSrc.startsWith('data:audio/wav')))
    ) {
      pausedAtRef.current = null;
      playSong(activeSong, undefined, { immediate: true, forceRestart: true });
      return;
    }

    const now = Date.now();
    const pausedDurationMs = pausedAtRef.current ? now - pausedAtRef.current : 0;
    const streamAgeMs = streamResolvedAtRef.current ? now - streamResolvedAtRef.current : 0;
    const isBlobOffline = audioRef.current?.src?.startsWith('blob:') ?? false;
    const savedPosition =
      activeEngineRef.current === 'yt'
        ? Number(ytPlayerRef.current?.getCurrentTime?.() || stateRef.current.currentTime || 0)
        : audioRef.current?.currentTime || stateRef.current.currentTime || 0;
    const hasPrewarmedForTrack = prewarmedStreamRef.current?.songId === activeSong.id;
    pausedAtRef.current = null;

    const refreshAndResumeAtPosition = async (pos: number) => {
      const audio = audioRef.current;
      if (!audio) return;
      const reqId = ++playRequestIdRef.current;
      activeEngineRef.current = 'html5';
      setStreamRefreshCount((c) => c + 1);
      setIsRefreshingStream(true);
      setIsLoading(true);

      // Use pre-warmed stream URL if resolved within the last 60s; otherwise verify playable stream before loading proxy
      const prewarmed = prewarmedStreamRef.current;
      let freshUrl =
        prewarmed && prewarmed.songId === activeSong.id && Date.now() - prewarmed.resolvedAt < 60000
          ? prewarmed.url
          : '';
      prewarmedStreamRef.current = null;
      if (!freshUrl) {
        MusicApi.invalidateClientDirectStreamCache(activeSong.id);
        const availability = await MusicApi.checkProxyStreamPlayable(activeSong, true).catch(() => ({
          playable: false,
          url: null,
        }));
        if (reqId !== playRequestIdRef.current || intentionalPauseRef.current || !audioRef.current) {
          setIsLoading(false);
          setIsRefreshingStream(false);
          return;
        }
        if (availability.url) {
          freshUrl = availability.url;
        } else if (availability.playable) {
          freshUrl = buildFreshStreamUrl({ ...activeSong, audioUrl: undefined });
        } else {
          const cid = (activeSong.id || '').trim();
          const isStdYt =
            cid.length === 11 &&
            !cid.startsWith('sp_') &&
            !cid.startsWith('js_') &&
            /^[a-zA-Z0-9_-]{11}$/.test(cid);
          if (isStdYt && ytReadyRef.current && ytPlayerRef.current && !document.hidden) {
            try {
              activeEngineRef.current = 'yt';
              audio.pause();
              setIsRefreshingStream(false);
              ytPlayerRef.current.loadVideoById({
                videoId: cid,
                startSeconds: pos > 1 ? Math.floor(pos) : 0,
              });
              ytPlayerRef.current.playVideo();
              return;
            } catch {}
          }
          setIsLoading(false);
          setIsRefreshingStream(false);
          setIsPlaying(false);
          setPlaybackError('Stream unavailable. Tap Retry.');
          return;
        }
      }
      if (reqId !== playRequestIdRef.current || intentionalPauseRef.current || !audioRef.current) {
        setIsLoading(false);
        setIsRefreshingStream(false);
        return;
      }
      streamResolvedAtRef.current = Date.now();

      applyAudioSourceWithSeek(audio, freshUrl, pos, reqId);
      audio.load();

      // Bounded 8-second refresh watchdog to guarantee resuming never hangs in infinite buffering
      if (resumeWatchdogRef.current) clearTimeout(resumeWatchdogRef.current);
      resumeWatchdogRef.current = setTimeout(() => {
        if (reqId !== playRequestIdRef.current || intentionalPauseRef.current || !audioRef.current) {
          return;
        }
        applyAudioSourceWithSeek(
          audioRef.current,
          buildFreshStreamUrl({ ...activeSong, audioUrl: undefined }),
          pos,
          reqId
        );
        audioRef.current
          .play()
          .then(() => {
            if (reqId !== playRequestIdRef.current || intentionalPauseRef.current) {
              audioRef.current?.pause();
              return;
            }
            setIsPlaying(true);
            setIsLoading(false);
            setIsRefreshingStream(false);
          })
          .catch(() => {
            if (reqId !== playRequestIdRef.current) return;
            setIsLoading(false);
            setIsRefreshingStream(false);
            setIsPlaying(false);
            setPlaybackError('Stream timed out. Tap Retry.');
          });
      }, 8000);

      audio
        .play()
        .then(() => {
          if (reqId !== playRequestIdRef.current || intentionalPauseRef.current) {
            audio.pause();
            return;
          }
          if (resumeWatchdogRef.current) {
            clearTimeout(resumeWatchdogRef.current);
            resumeWatchdogRef.current = null;
          }
          setIsPlaying(true);
          setIsLoading(false);
          setIsRefreshingStream(false);
        })
        .catch((playErr: any) => {
          if (reqId !== playRequestIdRef.current) return;
          if (playErr?.name === 'AbortError') return;
          if (resumeWatchdogRef.current) {
            clearTimeout(resumeWatchdogRef.current);
            resumeWatchdogRef.current = null;
          }
          setIsLoading(false);
          setIsRefreshingStream(false);
          setIsPlaying(false);
          if (
            playErr &&
            (playErr.name === 'NotAllowedError' || String(playErr.message || '').includes('NotAllowedError'))
          ) {
            setPlaybackError('Tap Play to start audio');
          }
        });
    };

    if (activeEngineRef.current === 'yt' && ytPlayerRef.current && ytReadyRef.current) {
      if (document.hidden) {
        refreshAndResumeAtPosition(savedPosition);
        return;
      }
      const ytReqId = ++playRequestIdRef.current;
      try {
        const ytState = ytPlayerRef.current.getPlayerState?.();
        const needsYtReload =
          pausedDurationMs >= PROACTIVE_PAUSE_REFRESH_MS ||
          ytState === -1 ||
          ytState === 0 ||
          ytState === 5 ||
          ytState === undefined;
        if (needsYtReload) {
          ytPlayerRef.current.loadVideoById({
            videoId: (activeSong.id || '').trim(),
            startSeconds: savedPosition > 1 ? Math.floor(savedPosition) : 0,
          });
        }
        setIsLoading(ytState !== 1);
        ytPlayerRef.current.playVideo();

        if (resumeWatchdogRef.current) clearTimeout(resumeWatchdogRef.current);
        resumeWatchdogRef.current = setTimeout(() => {
          resumeWatchdogRef.current = null;
          if (
            ytReqId !== playRequestIdRef.current ||
            activeEngineRef.current !== 'yt' ||
            intentionalPauseRef.current
          ) {
            return;
          }
          const curYtState = ytPlayerRef.current?.getPlayerState?.();
          if (curYtState === 1) {
            setIsLoading(false);
            setIsPlaying(true);
            return;
          }
          if (curYtState === 3) {
            // Still buffering — keep loading and let ytBufferingWatchdog handle stalls
            return;
          }
          MusicApi.checkProxyStreamPlayable(activeSong)
            .then((avail) => {
              if (
                ytReqId !== playRequestIdRef.current ||
                activeEngineRef.current !== 'yt' ||
                intentionalPauseRef.current
              ) {
                return;
              }
              if (avail.playable) {
                refreshAndResumeAtPosition(savedPosition);
              } else {
                setIsLoading(false);
                setIsPlaying(false);
                setPlaybackError('Tap Play to start audio');
              }
            })
            .catch(() => {
              if (ytReqId === playRequestIdRef.current) {
                setIsLoading(false);
                setIsPlaying(false);
                setPlaybackError('Tap Play to start audio');
              }
            });
        }, 3500);
        return;
      } catch {
        // Fall through to HTML5 stream refresh
      }
    }

    // Proactive stream refresh if paused >= 3 minutes (180,000ms), stream age >= 5 minutes (300,000ms), pre-warmed while paused, or previous stream ended/errored/unloaded
    const hasAudioError = Boolean(audioRef.current?.error);
    const isAudioEnded = Boolean(audioRef.current?.ended);
    const isAudioUnloaded = Boolean(
      audioRef.current?.readyState === 0 ||
        audioRef.current?.readyState === 1 ||
        audioRef.current?.networkState === 3
    );
    if (
      !isBlobOffline &&
      (pausedDurationMs >= PROACTIVE_PAUSE_REFRESH_MS ||
        streamAgeMs >= STREAM_MAX_AGE_MS ||
        hasPrewarmedForTrack ||
        hasAudioError ||
        isAudioEnded ||
        isAudioUnloaded)
    ) {
      refreshAndResumeAtPosition(savedPosition);
      return;
    }

    if (audioRef.current && currentAttrSrc) {
      setIsLoading(true);
      // 6-second stall watchdog on resume
      if (resumeWatchdogRef.current) clearTimeout(resumeWatchdogRef.current);
      if (!isBlobOffline) {
        resumeWatchdogRef.current = setTimeout(() => {
          resumeWatchdogRef.current = null;
          if (
            !intentionalPauseRef.current &&
            audioRef.current &&
            (audioRef.current.paused || Math.abs(audioRef.current.currentTime - savedPosition) < 0.2)
          ) {
            refreshAndResumeAtPosition(savedPosition);
          }
        }, 6000);
      }

      audioRef.current
        .play()
        .then(() => {
          if (intentionalPauseRef.current) {
            audioRef.current?.pause();
            return;
          }
          if (resumeWatchdogRef.current) {
            clearTimeout(resumeWatchdogRef.current);
            resumeWatchdogRef.current = null;
          }
          setIsPlaying(true);
          setIsLoading(false);
        })
        .catch((e) => {
          console.warn('Resume retry:', e);
          if (resumeWatchdogRef.current) {
            clearTimeout(resumeWatchdogRef.current);
            resumeWatchdogRef.current = null;
          }
          if (e?.name === 'AbortError') return;
          if (!intentionalPauseRef.current) {
            if (e && (e.name === 'NotAllowedError' || String(e.message || '').includes('NotAllowedError'))) {
              setIsLoading(false);
              setIsPlaying(false);
              setPlaybackError('Tap Play to start audio');
              return;
            }
            refreshAndResumeAtPosition(savedPosition);
          }
        });
    } else {
      playSong(activeSong, undefined, { immediate: true, forceRestart: true });
    }
  };

  const retryCurrentSong = () => {
    const activeSong = stateRef.current.currentSong || currentSong;
    if (!activeSong) return;
    MusicApi.invalidateClientDirectStreamCache(activeSong.id);
    setPlaybackError(null);
    playSong(activeSong, undefined, { immediate: true, forceRestart: true });
  };

  const handleNextSong = () => {
    const { queue: q, currentIndex: idx, isShuffle: shuf } = stateRef.current;
    if (q.length === 0) return;
    let nextIdx = idx + 1;
    if (shuf && q.length > 1) {
      for (let i = 0; i < 5 && nextIdx === idx; i++) {
        nextIdx = Math.floor(Math.random() * q.length);
      }
      if (nextIdx === idx || nextIdx >= q.length) {
        nextIdx = (idx + 1) % q.length;
      }
    } else if (nextIdx >= q.length) {
      nextIdx = 0;
    }
    const next = q[nextIdx] || q[0];
    if (next) {
      playSong(next, q, { immediate: true, forceRestart: true, targetIndex: nextIdx });
    }
  };

  const handlePrevSong = () => {
    const { queue: q, currentIndex: idx, currentTime: curPos } = stateRef.current;
    if (q.length === 0) return;
    if (curPos > 3 || (audioRef.current && audioRef.current.currentTime > 3)) {
      seekTo(0);
      return;
    }
    let prevIdx = idx - 1;
    if (prevIdx < 0) {
      prevIdx = q.length - 1;
    }
    const prev = q[prevIdx] || q[0];
    if (prev) {
      playSong(prev, q, { immediate: true, forceRestart: true, targetIndex: prevIdx });
    }
  };

  const seekTo = (seconds: number) => {
    setCurrentTime(seconds);
    if (activeEngineRef.current === 'yt' && ytPlayerRef.current && ytReadyRef.current) {
      try {
        ytPlayerRef.current.seekTo(seconds, true);
      } catch {}
    } else if (audioRef.current) {
      audioRef.current.currentTime = seconds;
    }
  };

  const setVolume = (vol: number) => {
    const clamped = Math.max(0, Math.min(1, vol));
    setVolumeState(clamped);
    if (audioRef.current) {
      audioRef.current.volume = clamped;
    }
    if (ytPlayerRef.current && ytReadyRef.current) {
      try {
        ytPlayerRef.current.setVolume(Math.round(clamped * 100));
      } catch {}
    }
  };

  const toggleShuffle = () => setIsShuffle((prev) => !prev);
  const toggleRepeat = () => setIsRepeat((prev) => !prev);

  const setPlaybackSpeed = (speed: number) => {
    setPlaybackSpeedState(speed);
    if (audioRef.current) {
      audioRef.current.playbackRate = speed;
    }
    if (ytPlayerRef.current && ytReadyRef.current) {
      try {
        ytPlayerRef.current.setPlaybackRate(speed);
      } catch {}
    }
  };

  const setAudioQuality = (q: string) => {
    setAudioQualityState(q);
  };

  const setSleepTimer = (minutes: number | null) => {
    if (minutes === null) {
      setSleepTimerRemaining(null);
    } else {
      setSleepTimerRemaining(minutes * 60);
    }
  };

  const toggleFavorite = (song: Song) => {
    setFavorites((prev) => {
      const exists = prev.some((s) => s.id === song.id);
      if (exists) {
        return prev.filter((s) => s.id !== song.id);
      } else {
        return [{ ...song, isFavorite: true }, ...prev];
      }
    });
  };

  const isFavorite = (id: string) => favorites.some((s) => s.id === id);

  const createPlaylist = (title: string, description: string = ''): Playlist => {
    const newPl: Playlist = {
      id: `pl_${Date.now()}`,
      title: title.trim() || 'New Playlist',
      description,
      thumbnailUrl: '',
      songs: [],
      updatedAt: Date.now(),
      isCustom: true,
    };
    setPlaylists((prev) => [newPl, ...prev]);
    return newPl;
  };

  const deletePlaylist = (playlistId: string) => {
    setPlaylists((prev) => prev.filter((p) => p.id !== playlistId));
  };

  const addToPlaylist = (playlistId: string, song: Song) => {
    const normalized = normalizeTrackArtwork(song);
    setPlaylists((prev) =>
      prev.map((pl) => {
        if (pl.id !== playlistId) return pl;
        if (pl.songs.some((s) => s.id === normalized.id || s.id === song.id)) return pl;
        return {
          ...pl,
          songs: [...pl.songs, normalized],
          thumbnailUrl: pl.thumbnailUrl || normalized.thumbnailUrl,
          updatedAt: Date.now(),
        };
      })
    );
  };

  const removeFromPlaylist = (playlistId: string, songId: string) => {
    setPlaylists((prev) =>
      prev.map((pl) => {
        if (pl.id !== playlistId) return pl;
        const nextSongs = pl.songs.filter((s) => s.id !== songId);
        return {
          ...pl,
          songs: nextSongs,
          thumbnailUrl: nextSongs.length > 0 ? nextSongs[0].thumbnailUrl : '',
          updatedAt: Date.now(),
        };
      })
    );
  };

  handlersRef.current = {
    pauseSong,
    resumeSong,
    handleNextSong,
    handlePrevSong,
    seekTo,
    retryCurrentSong,
  };

  const persistSongToOfflineCache = async (song: Song) => {
    const normalized = normalizeTrackArtwork(song);
    setDownloads((prev) => {
      const filtered = prev.filter((s) => s.id !== normalized.id);
      return [{ ...normalized, offlineStatus: 'downloading' }, ...filtered];
    });

    try {
      // Check if we already have the verified blob in IndexedDB or CacheStorage
      let audioBlob = await getOfflineBlobFromIdb(normalized.id);
      if (audioBlob && !(await isHealthyAudioBlob(audioBlob))) {
        await deleteOfflineBlobFromIdb(normalized.id).catch(() => {});
        audioBlob = null;
      }
      if (!audioBlob && 'caches' in window) {
        try {
          const cache = await caches.open(OFFLINE_CACHE_NAME);
          const cachePath = `/offline-audio/${encodeURIComponent(normalized.id)}`;
          const matched = await cache.match(cachePath);
          if (matched) {
            const b = await matched.blob();
            if (await isHealthyAudioBlob(b)) {
              audioBlob = b;
            } else {
              await cache.delete(cachePath).catch(() => {});
            }
          }
        } catch {}
      }

      const candidateUrls: string[] = [];
      const explicitProxyStream = `/api/stream/${encodeURIComponent(normalized.id)}?title=${encodeURIComponent(normalized.title)}&artist=${encodeURIComponent(normalized.artist)}&duration=${encodeURIComponent(String(normalized.durationSeconds || 0))}`;
      const knownMaster = MusicApi.resolveKnownFullLengthMaster(normalized);
      if (knownMaster && knownMaster.startsWith('/audio/')) {
        candidateUrls.push(knownMaster);
      }
      candidateUrls.push(explicitProxyStream);
      const resolvedDirect = await MusicApi.resolveClientDirectStreamUrl(normalized);
      if (resolvedDirect && !candidateUrls.includes(resolvedDirect)) {
        candidateUrls.push(resolvedDirect);
      }
      if (knownMaster && !candidateUrls.includes(knownMaster)) {
        candidateUrls.push(knownMaster);
      }
      const proxyStream = buildStreamUrl(normalized);
      if (!candidateUrls.includes(proxyStream)) {
        candidateUrls.push(proxyStream);
      }

      if (!audioBlob) {
        for (const url of candidateUrls) {
          const downloadedBlob = await fetchAudioBlobWithRetry(url, 2, 25000);
          if (downloadedBlob && (await isHealthyAudioBlob(downloadedBlob))) {
            audioBlob = downloadedBlob;
            break;
          }
        }
      }

      const bestAudioUrl = resolvedDirect || knownMaster || normalized.audioUrl;

      if (audioBlob && audioBlob.size > 10000) {
        const mimeType =
          audioBlob.type && !audioBlob.type.includes('text/') ? audioBlob.type : 'audio/mp4';
        const typedBlob =
          audioBlob.type === mimeType ? audioBlob : new Blob([audioBlob], { type: mimeType });

        if ('caches' in window) {
          const cache = await caches.open(OFFLINE_CACHE_NAME);
          await cache.put(
            `/offline-audio/${encodeURIComponent(normalized.id)}`,
            new Response(typedBlob, {
              headers: {
                'Content-Type': mimeType,
                'Content-Length': String(typedBlob.size),
              },
            })
          );
        }
        await saveOfflineBlobToIdb(normalized.id, typedBlob);
      }

      setDownloads((prev) =>
        prev.map((s) =>
          s.id === normalized.id
            ? {
                ...s,
                audioUrl: bestAudioUrl || s.audioUrl,
                offlineStatus: audioBlob && audioBlob.size > 10000 ? 'verified' : 'missing',
              }
            : s
        )
      );
    } catch {
      setDownloads((prev) =>
        prev.map((s) => (s.id === normalized.id ? { ...s, offlineStatus: 'missing' } : s))
      );
    }
  };

  const downloadSong = (song: Song) => {
    if (downloads.some((s) => s.id === song.id && s.offlineStatus === 'verified')) {
      const offlineQueue = downloads.filter((d) => d.offlineStatus === 'verified');
      playSong(song, offlineQueue.length > 0 ? offlineQueue : [song]);
      return;
    }
    persistSongToOfflineCache(song);
  };

  const retryDownload = (song: Song) => {
    persistSongToOfflineCache(song);
  };

  const removeDownload = (songId: string) => {
    setDownloads((prev) => prev.filter((s) => s.id !== songId));
    if ('caches' in window) {
      caches
        .open(OFFLINE_CACHE_NAME)
        .then((cache) => cache.delete(`/offline-audio/${encodeURIComponent(songId)}`))
        .catch(() => {});
    }
    deleteOfflineBlobFromIdb(songId).catch(() => {});
  };

  const isDownloaded = (songId: string) =>
    downloads.some((s) => s.id === songId && s.offlineStatus === 'verified');

  const isDownloading = (songId: string) =>
    downloads.some((s) => s.id === songId && s.offlineStatus === 'downloading');

  // Authentication Handlers
  const signInWithGoogle = async () => {
    const res = await signInWithPopup(auth, googleProvider);
    const credential = GoogleAuthProvider.credentialFromResult(res);
    if (credential?.accessToken) {
      setDriveAccessToken(credential.accessToken);
    }
    setUser({
      uid: res.user.uid,
      email: res.user.email,
      displayName: res.user.displayName || res.user.email?.split('@')[0] || 'User',
      photoURL: res.user.photoURL,
      isGuest: false,
    });
  };

  const signInWithEmail = async (email: string, pass: string) => {
    const res = await signInWithEmailAndPassword(auth, email, pass);
    setUser({
      uid: res.user.uid,
      email: res.user.email,
      displayName: res.user.displayName || email.split('@')[0],
      photoURL: res.user.photoURL,
      isGuest: false,
    });
  };

  const registerWithEmail = async (email: string, pass: string) => {
    const res = await createUserWithEmailAndPassword(auth, email, pass);
    setUser({
      uid: res.user.uid,
      email: res.user.email,
      displayName: email.split('@')[0],
      photoURL: null,
      isGuest: false,
    });
  };

  const signOut = async () => {
    await fbSignOut(auth);
    setUser({
      uid: 'guest_local_user',
      email: null,
      displayName: 'Guest Listener',
      photoURL: null,
      isGuest: true,
    });
  };

  const updateUser = (updates: Partial<UserProfile>) => {
    setUser((prev) => ({ ...prev, ...updates }));
  };

  // Frequent Tracks (sorted by play count descending)
  const frequentTracks = useMemo(() => {
    const songMap = new Map<string, Song>();
    [...POPULAR_FEATURED_SONGS, ...history, ...favorites].forEach((s) => {
      songMap.set(s.id, s);
    });

    return Object.entries(playCounts)
      .map(([id, count]) => {
        const song = songMap.get(id);
        if (!song) return null;
        return {
          ...song,
          playCount: count,
        };
      })
      .filter((s): s is Song & { playCount: number } => s !== null)
      .sort((a, b) => b.playCount - a.playCount)
      .slice(0, 10);
  }, [playCounts, history, favorites]);

  return (
    <MusicContext.Provider
      value={{
        currentSong,
        queue,
        currentIndex,
        isPlaying,
        isLoading,
        isRefreshingStream,
        streamRefreshCount,
        playbackError,
        currentTime,
        duration,
        volume,
        isShuffle,
        isRepeat,
        playbackSpeed,
        audioQuality,
        favorites,
        history,
        frequentTracks,
        playlists,
        downloads,
        user,
        sleepTimerRemaining,
        playSong,
        selectAndPlaySong,
        stopCurrentBeforeSwitch,
        pauseSong,
        resumeSong,
        retryCurrentSong,
        nextSong: handleNextSong,
        prevSong: handlePrevSong,
        seekTo,
        setVolume,
        toggleShuffle,
        toggleRepeat,
        setPlaybackSpeed,
        setAudioQuality,
        setSleepTimer,
        toggleFavorite,
        isFavorite,
        createPlaylist,
        deletePlaylist,
        addToPlaylist,
        removeFromPlaylist,
        downloadSong,
        retryDownload,
        removeDownload,
        isDownloaded,
        isDownloading,
        signInWithGoogle,
        signInWithEmail,
        registerWithEmail,
        signOut,
        updateUser,
      }}
    >
      {children}
    </MusicContext.Provider>
  );
};

export const useMusic = () => {
  const context = useContext(MusicContext);
  if (!context) {
    throw new Error('useMusic must be used within a MusicProvider');
  }
  return context;
};
