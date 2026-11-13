import React, { useState, useEffect, useCallback, useRef } from 'react';
import { Search as SearchIcon, X, Play, Pause, Loader2, History, Trash2, Download, Check, Plus } from 'lucide-react';
import { useMusic } from '../context/MusicContext';
import { Song } from '../types';
import { MusicApi, POPULAR_FEATURED_SONGS } from '../services/musicApi';

interface SearchScreenProps {
  initialQuery?: string;
  onOpenPlaylistModal: (song: Song) => void;
}

const RECENT_SEARCHES_KEY = 'twilight_recent_searches';

export const SearchScreen: React.FC<SearchScreenProps> = ({ initialQuery = '', onOpenPlaylistModal }) => {
  const {
    currentSong,
    isPlaying,
    isLoading,
    selectAndPlaySong,
    pauseSong,
    downloadSong,
    isDownloaded,
    isDownloading,
  } = useMusic();
  const [query, setQuery] = useState(initialQuery);
  const [results, setResults] = useState<Song[]>([]);
  const [isSearching, setIsSearching] = useState(false);
  const searchRequestIdRef = useRef<number>(0);
  const searchDebounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const [recentSearches, setRecentSearches] = useState<string[]>(() => {
    try {
      const stored = localStorage.getItem(RECENT_SEARCHES_KEY);
      return stored ? JSON.parse(stored) : [];
    } catch {
      return [];
    }
  });

  // Refactored song selection & play handler:
  // - If selecting the song that is already actively playing, toggle play/pause without restarting
  // - Otherwise delegate to selectAndPlaySong which immediately executes stopCurrentBeforeSwitch(),
  //   updates optimistic UI state on tap (0ms), and debounces stream initialization by 300ms
  const handleSelectAndPlaySong = useCallback(
    (song: Song, queueContext: Song[]) => {
      if (currentSong?.id === song.id && isPlaying) {
        pauseSong();
        return;
      }
      selectAndPlaySong(song, queueContext);
    },
    [currentSong?.id, isPlaying, pauseSong, selectAndPlaySong]
  );

  const trendingTags = [
    'Acoustic Pop',
    'Ed Sheeran',
    'The Weeknd',
    'Lo-Fi Study',
    'Bengali Soulful',
    'Midnight Chill',
    'Adele',
    'Queen Rock',
  ];

  const saveRecentSearch = (searchTerm: string) => {
    const term = searchTerm.trim();
    if (!term || term.length < 2) return;

    setRecentSearches((prev) => {
      const filtered = prev.filter((item) => item.toLowerCase() !== term.toLowerCase());
      const updated = [term, ...filtered].slice(0, 10);
      try {
        localStorage.setItem(RECENT_SEARCHES_KEY, JSON.stringify(updated));
      } catch {
        // Ignore storage errors
      }
      return updated;
    });
  };

  const removeRecentSearch = (e: React.MouseEvent, termToRemove: string) => {
    e.stopPropagation();
    setRecentSearches((prev) => {
      const updated = prev.filter((term) => term !== termToRemove);
      try {
        localStorage.setItem(RECENT_SEARCHES_KEY, JSON.stringify(updated));
      } catch {
        // Ignore storage errors
      }
      return updated;
    });
  };

  const clearAllRecentSearches = () => {
    setRecentSearches([]);
    try {
      localStorage.removeItem(RECENT_SEARCHES_KEY);
    } catch {
      // Ignore storage errors
    }
  };

  const handleSearch = async (searchTerm: string, recordToRecent = true) => {
    const term = searchTerm.trim();
    const reqId = ++searchRequestIdRef.current;
    if (!term) {
      setResults([]);
      setIsSearching(false);
      return;
    }

    if (recordToRecent) {
      saveRecentSearch(term);
    }

    setIsSearching(true);
    try {
      const songs = await MusicApi.searchSongs(term);
      if (reqId === searchRequestIdRef.current) {
        setResults(songs);
      }
    } catch {
      if (reqId === searchRequestIdRef.current) {
        setResults(POPULAR_FEATURED_SONGS);
      }
    } finally {
      if (reqId === searchRequestIdRef.current) {
        setIsSearching(false);
      }
    }
  };

  useEffect(() => {
    if (initialQuery) {
      setQuery(initialQuery);
      handleSearch(initialQuery, true);
    }
    return () => {
      if (searchDebounceRef.current) {
        clearTimeout(searchDebounceRef.current);
      }
    };
  }, [initialQuery]);

  const onSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (searchDebounceRef.current) {
      clearTimeout(searchDebounceRef.current);
      searchDebounceRef.current = null;
    }
    handleSearch(query, true);
  };

  const displayedSongs = results.length > 0 ? results : POPULAR_FEATURED_SONGS;

  return (
    <div className="space-y-6 pb-12">
      {/* Search Input Bar */}
      <form onSubmit={onSubmit} className="relative">
        <div className="relative flex items-center">
          <SearchIcon className="absolute left-4 w-5 h-5 text-slate-400" />
          <input
            type="text"
            value={query}
            onChange={(e) => {
              const nextVal = e.target.value;
              setQuery(nextVal);
              if (searchDebounceRef.current) {
                clearTimeout(searchDebounceRef.current);
                searchDebounceRef.current = null;
              }
              if (nextVal.trim().length > 2) {
                searchDebounceRef.current = setTimeout(() => {
                  handleSearch(nextVal, false);
                }, 250);
              } else if (!nextVal.trim()) {
                searchRequestIdRef.current++;
                setResults([]);
                setIsSearching(false);
              }
            }}
            placeholder="Search songs, artists, channels or genres..."
            autoFocus
            className="w-full pl-12 pr-10 py-3.5 rounded-2xl bg-white/5 border border-white/10 text-white placeholder-slate-500 focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 text-sm shadow-xl transition-all"
          />
          {query && (
            <button
              type="button"
              onClick={() => {
                if (searchDebounceRef.current) {
                  clearTimeout(searchDebounceRef.current);
                  searchDebounceRef.current = null;
                }
                searchRequestIdRef.current++;
                setQuery('');
                setResults([]);
                setIsSearching(false);
              }}
              className="absolute right-3.5 p-1 rounded-full text-slate-400 hover:text-white hover:bg-white/10 transition-colors"
            >
              <X className="w-4 h-4" />
            </button>
          )}
        </div>
      </form>

      {/* Recent Searches Section */}
      {recentSearches.length > 0 && (
        <div className="space-y-2 p-3.5 rounded-2xl bg-slate-900/60 border border-slate-800/80 shadow-md">
          <div className="flex items-center justify-between">
            <span className="flex items-center gap-1.5 text-xs font-semibold text-slate-300 tracking-wider uppercase">
              <History className="w-3.5 h-3.5 text-indigo-400" />
              <span>Recent Searches</span>
            </span>
            <button
              type="button"
              onClick={clearAllRecentSearches}
              className="text-[11px] font-medium text-slate-400 hover:text-rose-400 flex items-center gap-1 transition-colors px-2 py-0.5 rounded-md hover:bg-rose-500/10"
            >
              <Trash2 className="w-3 h-3" />
              <span>Clear History</span>
            </button>
          </div>
          <div className="flex flex-wrap gap-2 pt-1">
            {recentSearches.map((term) => (
              <div
                key={term}
                onClick={() => {
                  setQuery(term);
                  handleSearch(term, true);
                }}
                className="group flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-indigo-500/10 hover:bg-indigo-500/20 border border-indigo-500/20 text-xs text-indigo-200 hover:text-white transition-all cursor-pointer shadow-sm"
              >
                <History className="w-3 h-3 text-indigo-400/70 group-hover:text-indigo-300 shrink-0" />
                <span className="truncate max-w-[160px]">{term}</span>
                <button
                  type="button"
                  onClick={(e) => removeRecentSearch(e, term)}
                  className="p-0.5 rounded-full text-indigo-400/60 hover:text-rose-400 hover:bg-rose-500/20 transition-colors ml-0.5"
                  title="Remove query"
                >
                  <X className="w-3 h-3" />
                </button>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Trending Search Chips */}
      <div className="space-y-2">
        <span className="text-xs font-semibold text-slate-400 tracking-wider uppercase">
          Trending Searches
        </span>
        <div className="flex flex-wrap gap-2">
          {trendingTags.map((tag) => (
            <button
              key={tag}
              onClick={() => {
                setQuery(tag);
                handleSearch(tag, true);
              }}
              className="px-3 py-1.5 rounded-xl bg-white/5 hover:bg-white/10 border border-white/5 text-xs text-slate-300 hover:text-white transition-all"
            >
              {tag}
            </button>
          ))}
        </div>
      </div>

      {/* Search Results */}
      <div className="space-y-4">
        <div className="flex items-center justify-between">
          <h3 className="text-lg font-bold text-white tracking-tight">
            {isSearching
              ? 'Searching YouTube...'
              : results.length > 0
              ? `Results for "${query}"`
              : 'Explore Songs'}
          </h3>
          {results.length > 0 && (
            <span className="text-xs text-slate-400">{results.length} songs found</span>
          )}
        </div>

        {isSearching ? (
          <div className="py-12 flex flex-col items-center justify-center gap-3">
            <div className="w-8 h-8 border-2 border-indigo-500 border-t-transparent rounded-full animate-spin" />
            <span className="text-xs text-slate-400">Loading audio streams from YouTube...</span>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            {displayedSongs.map((song) => {
              const isCurrentSong = currentSong?.id === song.id;
              const isDown = isDownloaded(song.id);
              const isDownLoading = isDownloading(song.id);
              return (
                <div
                  key={`search_${song.id}`}
                  onClick={() => handleSelectAndPlaySong(song, displayedSongs)}
                  className={`group flex items-center gap-3.5 p-3 rounded-2xl border transition-all cursor-pointer ${
                    isCurrentSong
                      ? 'bg-indigo-500/15 border-indigo-500/40 shadow-lg shadow-indigo-500/5'
                      : 'bg-white/5 hover:bg-white/10 border-white/5 hover:border-indigo-500/30'
                  }`}
                >
                  <div className="w-12 h-12 rounded-xl overflow-hidden relative shrink-0 bg-slate-800">
                    <img src={song.thumbnailUrl} alt={song.title} className="w-full h-full object-cover" />
                    <div
                      className={`absolute inset-0 bg-black/50 flex items-center justify-center transition-opacity ${
                        isCurrentSong ? 'opacity-100' : 'opacity-0 group-hover:opacity-100'
                      }`}
                    >
                      {isCurrentSong && isLoading ? (
                        <Loader2 className="w-4 h-4 text-indigo-400 animate-spin" />
                      ) : isCurrentSong && isPlaying ? (
                        <Pause className="w-4 h-4 text-indigo-400 fill-indigo-400" />
                      ) : (
                        <Play className="w-4 h-4 text-white fill-white" />
                      )}
                    </div>
                  </div>

                  <div className="min-w-0 flex-1">
                    <h4
                      className={`text-xs font-bold truncate transition-colors ${
                        isCurrentSong ? 'text-indigo-400' : 'text-white group-hover:text-indigo-400'
                      }`}
                    >
                      {song.title}
                    </h4>
                    <p className="text-[11px] text-slate-400 truncate">{song.artist}</p>
                  </div>

                  <span className="text-xs text-slate-500 font-mono tabular-nums shrink-0">
                    {song.durationFormatted || '03:30'}
                  </span>

                  <button
                    type="button"
                    onClick={(e) => {
                      e.stopPropagation();
                      onOpenPlaylistModal(song);
                    }}
                    className="p-2 rounded-xl border border-white/10 text-slate-400 hover:text-white bg-white/5 hover:bg-white/10 transition-colors shrink-0"
                    title="Add to Playlist"
                  >
                    <Plus className="w-4 h-4" />
                  </button>

                  <button
                    type="button"
                    onClick={(e) => {
                      e.stopPropagation();
                      downloadSong(song);
                    }}
                    disabled={isDownLoading}
                    className={`p-2 rounded-xl border transition-colors shrink-0 ${
                      isDown
                        ? 'text-emerald-400 bg-emerald-500/15 border-emerald-500/30 hover:bg-emerald-500/25'
                        : isDownLoading
                        ? 'text-indigo-400 bg-indigo-500/15 border-indigo-500/30'
                        : 'text-slate-400 hover:text-white bg-white/5 hover:bg-white/10 border-white/10'
                    }`}
                    title={
                      isDown
                        ? 'Saved for Offline Playback (Tap to save audio file)'
                        : isDownLoading
                        ? 'Downloading audio...'
                        : 'Download Song for Offline Playback'
                    }
                  >
                    {isDownLoading ? (
                      <Loader2 className="w-4 h-4 animate-spin" />
                    ) : isDown ? (
                      <Check className="w-4 h-4" />
                    ) : (
                      <Download className="w-4 h-4" />
                    )}
                  </button>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
};

