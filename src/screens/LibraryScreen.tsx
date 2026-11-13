import React, { useState } from 'react';
import { Heart, ListMusic, History, Download, Play, Plus, Trash2, ArrowRight, AlertTriangle, RefreshCw, Check, Loader2 } from 'lucide-react';
import { useMusic } from '../context/MusicContext';
import { Playlist } from '../types';

export const LibraryScreen: React.FC = () => {
  const {
    favorites,
    playlists,
    history,
    downloads,
    playSong,
    selectAndPlaySong,
    deletePlaylist,
    createPlaylist,
    removeFromPlaylist,
    downloadSong,
    isDownloaded,
    isDownloading,
    retryDownload,
    removeDownload,
  } = useMusic();

  const [activeTab, setActiveTab] = useState<'favorites' | 'playlists' | 'history' | 'downloads'>('downloads');
  const [selectedPlaylistSnapshot, setSelectedPlaylist] = useState<Playlist | null>(null);
  const selectedPlaylist = selectedPlaylistSnapshot
    ? playlists.find((p) => p.id === selectedPlaylistSnapshot.id) ?? null
    : null;
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [newTitle, setNewTitle] = useState('');
  const [newDesc, setNewDesc] = useState('');

  const handleCreate = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newTitle.trim()) return;
    createPlaylist(newTitle.trim(), newDesc.trim());
    setNewTitle('');
    setNewDesc('');
    setShowCreateModal(false);
  };

  return (
    <div className="space-y-6 pb-12">
      <div>
        <span className="text-xs uppercase font-extrabold tracking-widest text-indigo-400">
          YOUR COLLECTION
        </span>
        <h1 className="text-2xl sm:text-4xl font-black text-white tracking-tight mt-0.5">
          Library
        </h1>
      </div>

      {/* Pinned "Downloaded" Folder Card inside Library */}
      {!selectedPlaylist && activeTab !== 'downloads' && (
        <div
          onClick={() => {
            setSelectedPlaylist(null);
            setActiveTab('downloads');
          }}
          className="group p-4 sm:p-5 rounded-3xl bg-gradient-to-r from-emerald-950/50 via-teal-950/30 to-slate-900 border border-emerald-500/30 hover:border-emerald-400/60 transition-all cursor-pointer flex items-center justify-between shadow-lg"
        >
          <div className="flex items-center gap-4">
            <div className="w-14 h-14 rounded-2xl bg-emerald-500/20 border border-emerald-500/40 flex items-center justify-center text-emerald-400 shrink-0">
              <Download className="w-7 h-7" />
            </div>
            <div>
              <h3 className="text-base sm:text-lg font-black text-white group-hover:text-emerald-300 transition-colors">
                Downloaded
              </h3>
              <p className="text-xs text-emerald-300/80">
                {downloads.length} {downloads.length === 1 ? 'song' : 'songs'} downloaded · Tap to open & play offline
              </p>
            </div>
          </div>
          <div className="flex items-center gap-1.5 text-xs font-bold text-emerald-400 group-hover:translate-x-1 transition-transform">
            <span>Open</span>
            <ArrowRight className="w-4 h-4" />
          </div>
        </div>
      )}

      {/* Tabs inside Library */}
      <div className="flex items-center gap-2 overflow-x-auto pb-2 scrollbar-none border-b border-white/10">
        <button
          onClick={() => {
            setActiveTab('downloads');
            setSelectedPlaylist(null);
          }}
          className={`flex items-center gap-2 px-4 py-2.5 rounded-2xl text-xs font-bold transition-all ${
            activeTab === 'downloads' && !selectedPlaylist
              ? 'bg-emerald-600 text-white shadow-lg shadow-emerald-600/25'
              : 'text-slate-400 hover:text-white hover:bg-white/5'
          }`}
        >
          <Download className="w-4 h-4" />
          <span>Downloaded ({downloads.length})</span>
        </button>

        <button
          onClick={() => {
            setActiveTab('favorites');
            setSelectedPlaylist(null);
          }}
          className={`flex items-center gap-2 px-4 py-2.5 rounded-2xl text-xs font-bold transition-all ${
            activeTab === 'favorites' && !selectedPlaylist
              ? 'bg-rose-500 text-white shadow-lg shadow-rose-500/25'
              : 'text-slate-400 hover:text-white hover:bg-white/5'
          }`}
        >
          <Heart className="w-4 h-4" />
          <span>Favorites ({favorites.length})</span>
        </button>

        <button
          onClick={() => {
            setActiveTab('playlists');
            setSelectedPlaylist(null);
          }}
          className={`flex items-center gap-2 px-4 py-2.5 rounded-2xl text-xs font-bold transition-all ${
            activeTab === 'playlists' || selectedPlaylist
              ? 'bg-indigo-600 text-white shadow-lg shadow-indigo-600/25'
              : 'text-slate-400 hover:text-white hover:bg-white/5'
          }`}
        >
          <ListMusic className="w-4 h-4" />
          <span>Playlists ({playlists.length})</span>
        </button>

        <button
          onClick={() => {
            setActiveTab('history');
            setSelectedPlaylist(null);
          }}
          className={`flex items-center gap-2 px-4 py-2.5 rounded-2xl text-xs font-bold transition-all ${
            activeTab === 'history' && !selectedPlaylist
              ? 'bg-purple-600 text-white shadow-lg shadow-purple-600/25'
              : 'text-slate-400 hover:text-white hover:bg-white/5'
          }`}
        >
          <History className="w-4 h-4" />
          <span>History ({history.length})</span>
        </button>
      </div>

      {/* Selected Playlist Detailed View */}
      {selectedPlaylist ? (
        <div className="space-y-6">
          <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 p-6 rounded-3xl bg-gradient-to-r from-indigo-950/40 via-purple-950/40 to-slate-900 border border-indigo-500/20">
            <div className="flex items-center gap-4">
              <div className="w-20 h-20 rounded-2xl overflow-hidden bg-slate-800 shrink-0">
                <img
                  src={selectedPlaylist.thumbnailUrl}
                  alt={selectedPlaylist.title}
                  className="w-full h-full object-cover"
                />
              </div>
              <div>
                <span className="text-[10px] font-bold text-indigo-400 uppercase tracking-widest">
                  Playlist
                </span>
                <h2 className="text-xl sm:text-2xl font-black text-white">{selectedPlaylist.title}</h2>
                <p className="text-xs text-slate-400 mt-1">{selectedPlaylist.description || 'Custom collection'}</p>
                <span className="text-xs text-slate-500 mt-1 block">
                  {selectedPlaylist.songs.length} tracks
                </span>
              </div>
            </div>

            <div className="flex items-center gap-2">
              {selectedPlaylist.songs.length > 0 && (
                <button
                  onClick={() => selectAndPlaySong(selectedPlaylist.songs[0], selectedPlaylist.songs)}
                  className="px-5 py-2.5 rounded-2xl bg-indigo-600 hover:bg-indigo-500 text-white font-bold text-xs flex items-center gap-2 shadow-lg shadow-indigo-600/30"
                >
                  <Play className="w-4 h-4 fill-white" />
                  <span>Play Playlist</span>
                </button>
              )}
              <button
                onClick={() => setSelectedPlaylist(null)}
                className="px-4 py-2.5 rounded-2xl bg-white/5 hover:bg-white/10 text-xs font-semibold text-slate-300"
              >
                Back to All
              </button>
            </div>
          </div>

          <div className="space-y-2">
            {selectedPlaylist.songs.length === 0 ? (
              <p className="text-sm text-slate-400 py-8 text-center">
                This playlist is currently empty. Use the '+' button on any song or player to add tracks here!
              </p>
            ) : (
              selectedPlaylist.songs.map((song, idx) => {
                const isDown = isDownloaded(song.id);
                const isDownLoading = isDownloading(song.id);
                return (
                  <div
                    key={`pl_song_${song.id}_${idx}`}
                    onClick={() => selectAndPlaySong(song, selectedPlaylist.songs)}
                    className="group flex items-center gap-3.5 p-3 rounded-2xl bg-white/5 hover:bg-white/10 border border-white/5 transition-all cursor-pointer"
                  >
                    <span className="text-xs font-mono text-slate-500 w-5 text-center group-hover:text-indigo-400">
                      {idx + 1}
                    </span>
                    <img src={song.thumbnailUrl} alt={song.title} className="w-10 h-10 rounded-xl object-cover shrink-0" />
                    <div className="min-w-0 flex-1">
                      <h4 className="text-xs font-bold text-white truncate">{song.title}</h4>
                      <p className="text-[11px] text-slate-400 truncate">{song.artist}</p>
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
                    {selectedPlaylist.isCustom && (
                      <button
                        type="button"
                        onClick={(e) => {
                          e.stopPropagation();
                          removeFromPlaylist(selectedPlaylist.id, song.id);
                        }}
                        className="p-2 rounded-xl text-slate-400 hover:text-rose-400 hover:bg-rose-500/10 transition-colors shrink-0"
                        title="Remove from playlist"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    )}
                  </div>
                );
              })
            )}
          </div>
        </div>
      ) : (
        <>
          {/* Favorites List */}
          {activeTab === 'favorites' && (
            <div className="space-y-3">
              {favorites.length === 0 ? (
                <p className="text-sm text-slate-400 py-8 text-center">
                  No favorite songs added yet. Heart any track to save it to your favorites!
                </p>
              ) : (
                favorites.map((song) => {
                  const isDown = isDownloaded(song.id);
                  const isDownLoading = isDownloading(song.id);
                  return (
                    <div
                      key={`fav_${song.id}`}
                      onClick={() => selectAndPlaySong(song, favorites)}
                      className="group flex items-center gap-3.5 p-3 rounded-2xl bg-white/5 hover:bg-white/10 border border-white/5 transition-all cursor-pointer"
                    >
                      <img src={song.thumbnailUrl} alt={song.title} className="w-12 h-12 rounded-xl object-cover shrink-0" />
                      <div className="min-w-0 flex-1">
                        <h4 className="text-sm font-bold text-white truncate group-hover:text-rose-400">{song.title}</h4>
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
                })
              )}
            </div>
          )}

          {/* Playlists Grid */}
          {activeTab === 'playlists' && (
            <div className="space-y-4">
              <div className="flex justify-end">
                <button
                  onClick={() => setShowCreateModal(true)}
                  className="flex items-center gap-2 px-4 py-2 rounded-2xl bg-indigo-600 hover:bg-indigo-500 text-white font-bold text-xs shadow-md shadow-indigo-600/25"
                >
                  <Plus className="w-4 h-4" />
                  <span>Create Playlist</span>
                </button>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                {/* Pinned Downloaded Collection Card */}
                <div
                  onClick={() => {
                    setSelectedPlaylist(null);
                    setActiveTab('downloads');
                  }}
                  className="group p-4 rounded-3xl bg-gradient-to-br from-emerald-950/60 to-slate-900/90 hover:from-emerald-900/60 border border-emerald-500/30 hover:border-emerald-400/60 transition-all cursor-pointer flex flex-col justify-between"
                >
                  <div className="flex items-center gap-3 mb-3">
                    <div className="w-14 h-14 rounded-2xl bg-emerald-500/20 border border-emerald-500/40 flex items-center justify-center text-emerald-400 shrink-0">
                      <Download className="w-6 h-6" />
                    </div>
                    <div className="min-w-0 flex-1">
                      <h4 className="text-sm font-bold text-white truncate group-hover:text-emerald-300">Downloaded</h4>
                      <p className="text-xs text-emerald-300/80 line-clamp-1">Songs downloaded in app</p>
                      <span className="text-[11px] text-slate-400">{downloads.length} songs</span>
                    </div>
                  </div>

                  <div className="flex items-center justify-between pt-2 border-t border-white/5 text-xs">
                    <span className="text-emerald-400 font-semibold flex items-center gap-1 group-hover:translate-x-1 transition-transform">
                      <span>Open Downloaded</span>
                      <ArrowRight className="w-3.5 h-3.5" />
                    </span>
                  </div>
                </div>

                {playlists.map((pl) => (
                  <div
                    key={pl.id}
                    onClick={() => setSelectedPlaylist(pl)}
                    className="group p-4 rounded-3xl bg-slate-900/60 hover:bg-slate-800/80 border border-white/5 hover:border-indigo-500/30 transition-all cursor-pointer flex flex-col justify-between"
                  >
                    <div className="flex items-center gap-3 mb-3">
                      <div className="w-14 h-14 rounded-2xl overflow-hidden bg-slate-800 shrink-0">
                        <img src={pl.thumbnailUrl} alt={pl.title} className="w-full h-full object-cover" />
                      </div>
                      <div className="min-w-0 flex-1">
                        <h4 className="text-sm font-bold text-white truncate group-hover:text-indigo-400">{pl.title}</h4>
                        <p className="text-xs text-slate-400 line-clamp-1">{pl.description || 'Collection'}</p>
                        <span className="text-[11px] text-slate-500">{pl.songs.length} songs</span>
                      </div>
                    </div>

                    <div className="flex items-center justify-between pt-2 border-t border-white/5 text-xs">
                      <span className="text-indigo-400 font-semibold flex items-center gap-1 group-hover:translate-x-1 transition-transform">
                        <span>Open</span>
                        <ArrowRight className="w-3.5 h-3.5" />
                      </span>
                      {pl.isCustom && (
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            deletePlaylist(pl.id);
                          }}
                          className="p-1 rounded-lg text-slate-500 hover:text-rose-400 hover:bg-rose-500/10"
                        >
                          <Trash2 className="w-3.5 h-3.5" />
                        </button>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* History List */}
          {activeTab === 'history' && (
            <div className="space-y-3">
              {history.length === 0 ? (
                <p className="text-sm text-slate-400 py-8 text-center">No listening history recorded yet.</p>
              ) : (
                history.map((song, idx) => {
                  const isDown = isDownloaded(song.id);
                  const isDownLoading = isDownloading(song.id);
                  return (
                    <div
                      key={`hist_${song.id}_${idx}`}
                      onClick={() => selectAndPlaySong(song, history)}
                      className="group flex items-center gap-3.5 p-3 rounded-2xl bg-white/5 hover:bg-white/10 border border-white/5 transition-all cursor-pointer"
                    >
                      <img src={song.thumbnailUrl} alt={song.title} className="w-12 h-12 rounded-xl object-cover shrink-0" />
                      <div className="min-w-0 flex-1">
                        <h4 className="text-sm font-bold text-white truncate group-hover:text-purple-400">{song.title}</h4>
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
                })
              )}
            </div>
          )}

          {/* Downloaded Songs List inside Library -> Downloaded */}
          {activeTab === 'downloads' && (
            <div className="space-y-4">
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 p-5 rounded-3xl bg-gradient-to-r from-emerald-950/50 via-teal-950/30 to-slate-900 border border-emerald-500/30">
                <div className="flex items-center gap-4">
                  <div className="w-14 h-14 rounded-2xl bg-emerald-500/20 border border-emerald-500/40 flex items-center justify-center text-emerald-400 shrink-0">
                    <Download className="w-7 h-7" />
                  </div>
                  <div>
                    <h2 className="text-xl sm:text-2xl font-black text-white">Downloaded</h2>
                    <p className="text-xs text-emerald-300/80 mt-0.5">
                      {downloads.length} {downloads.length === 1 ? 'song' : 'songs'} downloaded
                    </p>
                  </div>
                </div>

                {downloads.filter((d) => d.offlineStatus !== 'missing').length > 0 && (
                  <button
                    onClick={() => {
                      const playable = downloads.filter((d) => d.offlineStatus !== 'missing');
                      if (playable.length > 0) {
                        selectAndPlaySong(playable[0], playable);
                      }
                    }}
                    className="px-5 py-2.5 rounded-2xl bg-emerald-500 hover:bg-emerald-400 text-slate-950 font-extrabold text-xs flex items-center gap-2 self-start sm:self-auto shadow-lg shadow-emerald-500/25"
                  >
                    <Play className="w-4 h-4 fill-slate-950" />
                    <span>Play All Downloaded</span>
                  </button>
                )}
              </div>

              {downloads.length === 0 ? (
                <p className="text-sm text-slate-400 py-8 text-center">
                  No downloaded songs yet. Tap the download icon on any song to save it inside Downloaded!
                </p>
              ) : (
                downloads.map((song) => {
                  const isMissing = song.offlineStatus === 'missing';
                  const isSaving = song.offlineStatus === 'downloading' || isDownloading(song.id);
                  return (
                    <div
                      key={`dl_${song.id}`}
                      onClick={() => {
                        if (isMissing) {
                          retryDownload(song);
                        } else if (!isSaving) {
                          selectAndPlaySong(song, downloads.filter((d) => d.offlineStatus !== 'missing'));
                        }
                      }}
                      className="group flex items-center gap-3.5 p-3 rounded-2xl bg-white/5 hover:bg-white/10 border border-white/5 transition-all cursor-pointer"
                    >
                      <img src={song.thumbnailUrl} alt={song.title} className="w-12 h-12 rounded-xl object-cover shrink-0" />
                      <div className="min-w-0 flex-1">
                        <h4 className="text-sm font-bold text-white truncate group-hover:text-emerald-400">{song.title}</h4>
                        {isMissing ? (
                          <p className="text-xs text-amber-400 font-semibold flex items-center gap-1 mt-0.5">
                            <AlertTriangle className="w-3.5 h-3.5 shrink-0" />
                            <span>File missing · Tap to re-download</span>
                          </p>
                        ) : isSaving ? (
                          <p className="text-xs text-emerald-400 font-semibold flex items-center gap-1 mt-0.5">
                            <RefreshCw className="w-3.5 h-3.5 animate-spin shrink-0" />
                            <span>Re-downloading offline file...</span>
                          </p>
                        ) : (
                          <p className="text-xs text-slate-400 truncate">{song.artist}</p>
                        )}
                      </div>
                      <div className="flex items-center gap-2 shrink-0">
                        {isMissing ? (
                          <button
                            onClick={(e) => {
                              e.stopPropagation();
                              retryDownload(song);
                            }}
                            className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-amber-500/20 hover:bg-amber-500/30 border border-amber-500/30 text-amber-300 text-xs font-bold transition-colors"
                            title="Re-download missing offline file"
                          >
                            <RefreshCw className="w-3.5 h-3.5" />
                            <span>Re-download</span>
                          </button>
                        ) : (
                          <>
                            {!isSaving && (
                              <button
                                onClick={(e) => {
                                  e.stopPropagation();
                                  selectAndPlaySong(song, downloads.filter((d) => d.offlineStatus !== 'missing'));
                                }}
                                className="px-2.5 py-1.5 rounded-xl bg-emerald-500/20 hover:bg-emerald-500/30 border border-emerald-500/30 text-emerald-300 text-xs font-bold flex items-center gap-1 transition-colors"
                                title="Play offline inside app"
                              >
                                <Play className="w-3.5 h-3.5 fill-emerald-300" />
                                <span>Play</span>
                              </button>
                            )}
                          </>
                        )}
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            removeDownload(song.id);
                          }}
                          className="p-2 rounded-xl text-slate-400 hover:text-rose-400 hover:bg-rose-500/10 transition-colors"
                          title="Delete download"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </div>
                    </div>
                  );
                })
              )}
            </div>
          )}
        </>
      )}

      {/* Create Playlist Modal */}
      {showCreateModal && (
        <div className="fixed inset-0 z-50 bg-black/75 backdrop-blur-md flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-white/10 w-full max-w-sm rounded-3xl p-6 shadow-2xl space-y-4">
            <h3 className="font-bold text-white text-base">Create New Playlist</h3>
            <form onSubmit={handleCreate} className="space-y-3">
              <input
                type="text"
                value={newTitle}
                onChange={(e) => setNewTitle(e.target.value)}
                placeholder="Playlist name..."
                autoFocus
                className="w-full px-3.5 py-2.5 rounded-xl bg-white/5 border border-white/10 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-indigo-500"
              />
              <textarea
                value={newDesc}
                onChange={(e) => setNewDesc(e.target.value)}
                placeholder="Description (optional)..."
                rows={2}
                className="w-full px-3.5 py-2.5 rounded-xl bg-white/5 border border-white/10 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-indigo-500 resize-none"
              />
              <div className="flex gap-2 pt-2">
                <button
                  type="submit"
                  className="flex-1 py-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-xs font-semibold text-white"
                >
                  Create
                </button>
                <button
                  type="button"
                  onClick={() => setShowCreateModal(false)}
                  className="px-4 py-2.5 rounded-xl bg-white/5 text-xs text-slate-400 hover:text-white"
                >
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
