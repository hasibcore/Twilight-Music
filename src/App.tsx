import React, { useState } from 'react';
import { MusicProvider } from './context/MusicContext';
import { Navigation, NavTab } from './components/Navigation';
import { TopAppBar } from './components/TopAppBar';
import { AudioPlayer } from './components/AudioPlayer';
import { HomeScreen } from './screens/HomeScreen';
import { ExploreScreen } from './screens/ExploreScreen';
import { SearchScreen } from './screens/SearchScreen';
import { LibraryScreen } from './screens/LibraryScreen';
import { ProfileScreen } from './screens/ProfileScreen';
import { LandingScreen } from './screens/LandingScreen';
import { ArtistScreen } from './screens/ArtistScreen';
import { PlaylistModal } from './components/PlaylistModal';
import { Song } from './types';

export const AppContent: React.FC = () => {
  const [currentTab, setCurrentTab] = useState<NavTab>('home');
  const [selectedArtist, setSelectedArtist] = useState<string | null>(null);
  const [searchInitialQuery, setSearchInitialQuery] = useState<string>('');
  const [playlistModalSong, setPlaylistModalSong] = useState<Song | null>(null);

  const handleSelectArtist = (artistName: string) => {
    setSelectedArtist(artistName);
  };

  const handleOpenSearchWithQuery = (query: string = '') => {
    setSelectedArtist(null);
    setSearchInitialQuery(query);
    setCurrentTab('search');
  };

  const handleOpenDownloads = () => {
    setSelectedArtist(null);
    setCurrentTab('landing');
  };

  return (
    <div className="flex h-screen w-screen overflow-hidden bg-slate-950 text-slate-100 font-sans">
      {/* Desktop Sidebar & Mobile Bottom Navigation */}
      <Navigation
        currentTab={currentTab}
        onSelectTab={(tab) => {
          setSelectedArtist(null);
          setCurrentTab(tab);
        }}
      />

      {/* Main Content Area */}
      <div className="flex-1 h-full flex flex-col overflow-hidden min-w-0">
        {/* Top App Bar with Twilight App Name, 2nd Image Logo, and Circular Download Symbol */}
        <TopAppBar
          currentTab={currentTab}
          onSelectTab={(tab) => {
            setSelectedArtist(null);
            setCurrentTab(tab);
          }}
          onOpenDownloads={handleOpenDownloads}
        />

        <main className="flex-1 h-full overflow-y-auto px-4 md:px-10 pt-4 pb-44 md:pb-28">
          <div className="max-w-7xl mx-auto">
            {selectedArtist ? (
              <ArtistScreen artistName={selectedArtist} onBack={() => setSelectedArtist(null)} />
            ) : currentTab === 'home' ? (
              <HomeScreen
                onOpenSearch={() => handleOpenSearchWithQuery('')}
                onOpenPlaylistModal={(song) => setPlaylistModalSong(song)}
                onSelectArtist={handleSelectArtist}
                onOpenLanding={handleOpenDownloads}
              />
            ) : currentTab === 'explore' ? (
              <ExploreScreen
                onSearchGenre={(genre) => handleOpenSearchWithQuery(genre)}
                onSelectArtist={handleSelectArtist}
                onOpenPlaylistModal={(song) => setPlaylistModalSong(song)}
              />
            ) : currentTab === 'search' ? (
              <SearchScreen
                initialQuery={searchInitialQuery}
                onOpenPlaylistModal={(song) => setPlaylistModalSong(song)}
              />
            ) : currentTab === 'library' ? (
              <LibraryScreen onOpenPlaylistModal={(song) => setPlaylistModalSong(song)} />
            ) : currentTab === 'profile' ? (
              <ProfileScreen />
            ) : currentTab === 'landing' ? (
              <LandingScreen onNavigate={(tab) => setCurrentTab(tab)} />
            ) : null}
          </div>
        </main>
      </div>

      {/* Persistent Audio Player (Mini Docked + Full Screen Modal) */}
      <AudioPlayer />

      {/* Global Add-to-Playlist Modal */}
      {playlistModalSong && (
        <PlaylistModal
          song={playlistModalSong}
          isOpen={Boolean(playlistModalSong)}
          onClose={() => setPlaylistModalSong(null)}
        />
      )}
    </div>
  );
};

export const App: React.FC = () => {
  return (
    <MusicProvider>
      <AppContent />
    </MusicProvider>
  );
};

export default App;
