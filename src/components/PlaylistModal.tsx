import React, { useState, useEffect } from 'react';
import { X, Plus, ListMusic, Check } from 'lucide-react';
import { Song } from '../types';
import { useMusic } from '../context/MusicContext';

interface PlaylistModalProps {
  song: Song | null;
  isOpen: boolean;
  onClose: () => void;
}

export const PlaylistModal: React.FC<PlaylistModalProps> = ({ song, isOpen, onClose }) => {
  const { playlists, createPlaylist, addToPlaylist } = useMusic();
  const [newTitle, setNewTitle] = useState('');
  const [showCreate, setShowCreate] = useState(false);
  const [addedIds, setAddedIds] = useState<string[]>([]);

  useEffect(() => {
    setAddedIds([]);
    setShowCreate(false);
    setNewTitle('');
  }, [song?.id, isOpen]);

  if (!isOpen || !song) return null;

  const handleCreate = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newTitle.trim()) return;
    const pl = createPlaylist(newTitle.trim());
    addToPlaylist(pl.id, song);
    setNewTitle('');
    setShowCreate(false);
    setAddedIds((prev) => [...prev, pl.id]);
  };

  const handleAdd = (playlistId: string) => {
    addToPlaylist(playlistId, song);
    setAddedIds((prev) => [...prev, playlistId]);
  };

  return (
    <div className="fixed inset-0 z-50 bg-black/75 backdrop-blur-md flex items-center justify-center p-4">
      <div className="bg-slate-900 border border-white/10 w-full max-w-sm rounded-3xl p-6 shadow-2xl animate-in zoom-in-95 duration-200">
        <div className="flex items-center justify-between pb-4 border-b border-white/10">
          <h3 className="font-bold text-white text-base">Add to Playlist</h3>
          <button onClick={onClose} className="p-1.5 rounded-full hover:bg-white/10 text-slate-400 hover:text-white">
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="py-4">
          <div className="flex items-center gap-3 p-2 rounded-xl bg-white/5 mb-4">
            <img src={song.thumbnailUrl} alt={song.title} className="w-10 h-10 rounded-lg object-cover" />
            <div className="min-w-0 flex-1">
              <h4 className="text-xs font-bold text-white truncate">{song.title}</h4>
              <p className="text-[11px] text-slate-400 truncate">{song.artist}</p>
            </div>
          </div>

          {!showCreate ? (
            <button
              onClick={() => setShowCreate(true)}
              className="w-full flex items-center justify-center gap-2 py-2.5 rounded-xl border border-dashed border-indigo-500/40 text-indigo-400 hover:bg-indigo-500/10 text-xs font-semibold mb-4 transition-colors"
            >
              <Plus className="w-4 h-4" />
              <span>Create New Playlist</span>
            </button>
          ) : (
            <form onSubmit={handleCreate} className="space-y-2 mb-4">
              <input
                type="text"
                value={newTitle}
                onChange={(e) => setNewTitle(e.target.value)}
                placeholder="Playlist name..."
                autoFocus
                className="w-full px-3.5 py-2 rounded-xl bg-white/5 border border-white/10 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-indigo-500"
              />
              <div className="flex gap-2">
                <button
                  type="submit"
                  className="flex-1 py-2 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-xs font-semibold text-white"
                >
                  Create & Add
                </button>
                <button
                  type="button"
                  onClick={() => setShowCreate(false)}
                  className="px-3 py-2 rounded-xl bg-white/5 text-xs text-slate-400 hover:text-white"
                >
                  Cancel
                </button>
              </div>
            </form>
          )}

          <div className="max-h-56 overflow-y-auto space-y-1.5 pr-1">
            {playlists.map((pl) => {
              const alreadyHas = pl.songs.some((s) => s.id === song.id) || addedIds.includes(pl.id);
              return (
                <button
                  key={pl.id}
                  onClick={() => !alreadyHas && handleAdd(pl.id)}
                  disabled={alreadyHas}
                  className={`w-full flex items-center justify-between p-2.5 rounded-xl text-left transition-all ${
                    alreadyHas
                      ? 'bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 cursor-default'
                      : 'hover:bg-white/5 text-slate-200'
                  }`}
                >
                  <div className="flex items-center gap-2.5 min-w-0">
                    <ListMusic className="w-4 h-4 text-indigo-400 shrink-0" />
                    <span className="text-xs font-medium truncate">{pl.title}</span>
                  </div>
                  {alreadyHas ? (
                    <Check className="w-4 h-4 text-emerald-400 shrink-0" />
                  ) : (
                    <span className="text-[10px] text-slate-500 shrink-0">{pl.songs.length} songs</span>
                  )}
                </button>
              );
            })}
          </div>
        </div>

        <button
          onClick={onClose}
          className="w-full py-2.5 rounded-xl bg-white/5 hover:bg-white/10 text-xs font-semibold text-slate-300"
        >
          Done
        </button>
      </div>
    </div>
  );
};
