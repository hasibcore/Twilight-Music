import React, { useState, useEffect } from 'react';
import { ArrowLeft, Play, Radio, Download, Check, Loader2 } from 'lucide-react';
import { Song } from '../types';
import { useMusic } from '../context/MusicContext';
import { MusicApi, POPULAR_FEATURED_SONGS } from '../services/musicApi';

interface ArtistScreenProps {
  artistName: string;
  onBack: () => void;
}

export const ArtistScreen: React.FC<ArtistScreenProps> = ({ artistName, onBack }) => {
  const { selectAndPlaySong, downloadSong, isDownloaded, isDownloading } = useMusic();
  const [songs, setSongs] = useState<Song[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    MusicApi.searchSongs(`${artistName} top tracks hits`)
      .then((res) => {
        if (!cancelled) {
          setSongs(res.length > 0 ? res : POPULAR_FEATURED_SONGS);
        }
      })
      .catch(() => {
        if (!cancelled) {
          setSongs(POPULAR_FEATURED_SONGS);
        }
      })
      .finally(() => {
        if (!cancelled) {
          setLoading(false);
        }
      });
    return () => {
      cancelled = true;
    };
  }, [artistName]);

  return (
    <div className="space-y-6 pb-12">
      <button
        onClick={onBack}
        className="flex items-center gap-2 text-xs font-semibold text-slate-400 hover:text-white transition-colors"
      >
        <ArrowLeft className="w-4 h-4" />
        <span>Back</span>
      </button>

      {/* Artist Hero Banner */}
      <div className="p-8 rounded-3xl bg-gradient-to-r from-indigo-950/60 via-purple-950/60 to-slate-900 border border-indigo-500/20 shadow-2xl flex flex-col sm:flex-row items-center gap-6 text-center sm:text-left">
        <div className="w-28 h-28 sm:w-36 sm:h-36 rounded-full overflow-hidden bg-slate-800 shadow-2xl border-4 border-indigo-500/20 shrink-0">
          <img
            src={songs[0]?.thumbnailUrl || 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&auto=format&fit=crop&q=80'}
            alt={artistName}
            className="w-full h-full object-cover"
          />
        </div>

        <div className="space-y-2 flex-1">
          <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-indigo-500/20 text-indigo-400 text-xs font-bold">
            <Radio className="w-3.5 h-3.5" />
            <span>Verified Artist Station</span>
          </div>

          <h1 className="text-2xl sm:text-4xl font-black text-white tracking-tight">{artistName}</h1>
          <p className="text-xs text-slate-400">Stream all songs, albums & acoustic live sessions</p>

          {songs.length > 0 && (
            <div className="pt-2">
              <button
                onClick={() => selectAndPlaySong(songs[0], songs)}
                className="px-6 py-2.5 rounded-2xl bg-indigo-600 hover:bg-indigo-500 text-white font-bold text-xs flex items-center gap-2 shadow-lg shadow-indigo-600/30 transition-transform active:scale-95"
              >
                <Play className="w-4 h-4 fill-white" />
                <span>Play Artist Radio</span>
              </button>
            </div>
          )}
        </div>
      </div>

      {/* Tracks List */}
      <div className="space-y-4">
        <h3 className="text-lg font-bold text-white tracking-tight">Popular Tracks</h3>

        {loading ? (
          <div className="py-12 flex justify-center">
            <div className="w-8 h-8 border-2 border-indigo-500 border-t-transparent rounded-full animate-spin" />
          </div>
        ) : (
          <div className="space-y-2">
            {songs.map((song, idx) => {
              const isDown = isDownloaded(song.id);
              const isDownLoading = isDownloading(song.id);
              return (
                <div
                  key={`artist_song_${song.id}_${idx}`}
                  onClick={() => selectAndPlaySong(song, songs)}
                  className="group flex items-center gap-3.5 p-3 rounded-2xl bg-white/5 hover:bg-white/10 border border-white/5 transition-all cursor-pointer"
                >
                  <span className="text-xs font-mono text-slate-500 w-5 text-center group-hover:text-indigo-400">
                    {idx + 1}
                  </span>
                  <img src={song.thumbnailUrl} alt={song.title} className="w-12 h-12 rounded-xl object-cover shrink-0" />
                  <div className="min-w-0 flex-1">
                    <h4 className="text-sm font-bold text-white truncate group-hover:text-indigo-400">{song.title}</h4>
                    <p className="text-xs text-slate-400 truncate">{song.artist}</p>
                  </div>
                  <span className="text-xs text-slate-500 font-mono shrink-0">
                    {song.durationFormatted || '03:30'}
                  </span>
                  <button
                    type="button"
                    onClick={(e) => {
                      e.stopPropagation();
                      downloadSong(song);
                    }}
                    disabled={isDownLoading}
                    className={`p-2 rounded-xl border transition-colors shrink-0 ${
                      isDown
                        ? 'text-emerald-400 bg-emerald-500/15 border-emerald-500/30'
                        : isDownLoading
                        ? 'text-indigo-400 bg-indigo-500/15 border-indigo-500/30'
                        : 'text-slate-400 hover:text-white bg-white/5 hover:bg-white/10 border-white/10'
                    }`}
                    title={isDown ? 'Saved Offline' : 'Download Song for Offline Playback'}
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
