import React, { useEffect, useState, useMemo } from 'react';
import { X, Music2, Loader2 } from 'lucide-react';
import { Song } from '../types';
import { useMusic } from '../context/MusicContext';
import { MusicApi } from '../services/musicApi';

interface LyricsModalProps {
  song: Song | null;
  isOpen: boolean;
  onClose: () => void;
}

interface ParsedLyricLine {
  timeSec: number | null;
  text: string;
}

function parseLyricsPayload(plainLyrics: string, syncedLyrics: string): ParsedLyricLine[] {
  if (syncedLyrics && syncedLyrics.trim()) {
    const rawLines = syncedLyrics.split(/\r?\n/);
    const parsed: ParsedLyricLine[] = [];
    const timeRegex = /\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]/;
    for (const raw of rawLines) {
      const m = timeRegex.exec(raw);
      const text = raw.replace(/\[\d{1,2}:\d{2}(?:\.\d{1,3})?\]/g, '').trim();
      if (m) {
        const mins = parseInt(m[1], 10) || 0;
        const secs = parseInt(m[2], 10) || 0;
        const frac = m[3] ? parseInt(m[3].padEnd(3, '0'), 10) / 1000 : 0;
        parsed.push({
          timeSec: mins * 60 + secs + frac,
          text: text || '♪',
        });
      } else if (text) {
        parsed.push({ timeSec: null, text });
      }
    }
    if (parsed.length > 0) return parsed;
  }

  if (plainLyrics && plainLyrics.trim()) {
    return plainLyrics.split(/\r?\n/).map((line) => ({
      timeSec: null,
      text: line.trim(),
    }));
  }

  return [];
}

export const LyricsModal: React.FC<LyricsModalProps> = ({ song, isOpen, onClose }) => {
  const { currentTime } = useMusic();
  const [lines, setLines] = useState<ParsedLyricLine[]>([]);
  const [loading, setLoading] = useState<boolean>(false);

  useEffect(() => {
    if (!isOpen || !song) return;
    let cancelled = false;
    setLoading(true);

    const fetchSongLyrics = async () => {
      try {
        const params = new URLSearchParams({
          title: song.title || '',
          artist: song.artist || '',
        });
        const res = await fetch(`/api/lyrics?${params.toString()}`, {
          signal: AbortSignal.timeout(4500),
        });
        if (res.ok) {
          const data = await res.json();
          if (!cancelled && (data?.plainLyrics || data?.syncedLyrics)) {
            setLines(parseLyricsPayload(String(data.plainLyrics || ''), String(data.syncedLyrics || '')));
            setLoading(false);
            return;
          }
        }
      } catch {
        // Fallback to direct LRCLIB client fetch
      }

      try {
        const { coreTitle, primaryArtist } = MusicApi.extractCoreSongTitleAndArtist(
          song.title || '',
          song.artist || ''
        );
        const q = primaryArtist ? `${coreTitle} ${primaryArtist}` : coreTitle;
        const directRes = await fetch(
          `https://lrclib.net/api/search?q=${encodeURIComponent(q.trim())}`,
          { signal: AbortSignal.timeout(4500) }
        );
        if (directRes.ok) {
          const list = await directRes.json();
          if (!cancelled && Array.isArray(list) && list.length > 0) {
            const hit = list.find((item: any) => item?.plainLyrics || item?.syncedLyrics);
            if (hit) {
              setLines(
                parseLyricsPayload(String(hit.plainLyrics || ''), String(hit.syncedLyrics || ''))
              );
              setLoading(false);
              return;
            }
          }
        }
      } catch {
        // Ignore network errors
      }

      if (!cancelled) {
        setLines([]);
        setLoading(false);
      }
    };

    fetchSongLyrics();
    return () => {
      cancelled = true;
    };
  }, [isOpen, song?.id, song?.title, song?.artist]);

  const activeLineIndex = useMemo(() => {
    let idx = -1;
    for (let i = 0; i < lines.length; i++) {
      const t = lines[i].timeSec;
      if (t !== null && currentTime >= t) {
        idx = i;
      }
    }
    return idx;
  }, [lines, currentTime]);

  if (!isOpen || !song) return null;

  return (
    <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-xl flex items-center justify-center p-4">
      <div className="bg-slate-900 border border-white/10 w-full max-w-lg rounded-3xl p-6 shadow-2xl flex flex-col max-h-[85vh] animate-in fade-in zoom-in-95 duration-200">
        <div className="flex items-center justify-between pb-4 border-b border-white/10">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl overflow-hidden bg-slate-800">
              <img src={song.thumbnailUrl} alt={song.title} className="w-full h-full object-cover" />
            </div>
            <div>
              <h3 className="font-bold text-white text-sm line-clamp-1">{song.title}</h3>
              <p className="text-xs text-indigo-400 line-clamp-1">{song.artist}</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-2 rounded-full hover:bg-white/10 text-slate-400 hover:text-white transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="overflow-y-auto py-6 space-y-3 text-center my-auto px-2">
          <div className="inline-flex items-center gap-2 text-xs font-semibold px-3 py-1 rounded-full bg-indigo-500/10 text-indigo-400 mb-2">
            <Music2 className="w-3.5 h-3.5" />
            <span>Synced Studio Lyrics</span>
          </div>

          {loading ? (
            <div className="py-12 flex flex-col items-center justify-center gap-3 text-slate-400">
              <Loader2 className="w-6 h-6 animate-spin text-indigo-400" />
              <span className="text-xs font-medium">Loading lyrics for {song.title}...</span>
            </div>
          ) : lines.length > 0 ? (
            lines.map((line, idx) => {
              const isActive = idx === activeLineIndex;
              return (
                <p
                  key={idx}
                  className={`transition-all leading-relaxed ${
                    line.text === ''
                      ? 'h-2'
                      : isActive
                      ? 'text-indigo-300 font-bold text-base scale-105'
                      : line.text.startsWith('♪')
                      ? 'text-indigo-400 font-semibold italic text-xs'
                      : 'text-slate-200 hover:text-white font-medium text-sm'
                  }`}
                >
                  {line.text}
                </p>
              );
            })
          ) : (
            <div className="py-10 space-y-2 text-slate-400">
              <p className="text-sm font-semibold text-white">{song.title}</p>
              <p className="text-xs text-indigo-400">{song.artist}</p>
              <p className="text-xs text-slate-400 pt-2">
                ♪ Instrumental or studio track — synced lyrics not yet indexed for this version ♪
              </p>
            </div>
          )}
        </div>

        <div className="pt-4 border-t border-white/10 text-center">
          <button
            onClick={onClose}
            className="w-full py-2.5 rounded-xl bg-white/5 hover:bg-white/10 text-xs font-medium text-slate-300"
          >
            Close Lyrics
          </button>
        </div>
      </div>
    </div>
  );
};
