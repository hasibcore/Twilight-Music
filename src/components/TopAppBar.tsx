import React from 'react';
import { User } from 'lucide-react';
import { NavTab } from './Navigation';
import { TwilightLogo } from './TwilightLogo';
import { useMusic } from '../context/MusicContext';

interface TopAppBarProps {
  currentTab: NavTab;
  onSelectTab: (tab: NavTab) => void;
  onOpenDownloads?: () => void;
}

export const TopAppBar: React.FC<TopAppBarProps> = ({
  currentTab,
  onSelectTab,
}) => {
  const { user } = useMusic();

  return (
    <header className="sticky top-0 left-0 right-0 h-14 sm:h-16 bg-slate-950/85 backdrop-blur-xl border-b border-white/5 z-30 px-4 sm:px-8 flex items-center justify-between select-none">
      {/* Brand & Exact Uploaded Logo Icon */}
      <button
        onClick={() => onSelectTab('home')}
        className="flex items-center gap-2.5 sm:gap-3 group focus:outline-none"
      >
        <TwilightLogo size={40} className="rounded-2xl group-hover:scale-105 transition-transform" />
        <div className="flex items-baseline gap-1.5 text-left">
          <span className="text-lg sm:text-xl font-black tracking-tight text-white group-hover:text-indigo-200 transition-colors">
            Twilight
          </span>
          <span className="hidden sm:inline text-[10px] uppercase font-bold tracking-widest text-indigo-400">
            Music
          </span>
        </div>
      </button>

      {/* Right Side Actions */}
      <div className="flex items-center gap-2 sm:gap-3">
        {/* Profile Avatar Button */}
        <button
          onClick={() => onSelectTab('profile')}
          title="User Profile & Settings"
          className={`w-9 h-9 sm:w-10 sm:h-10 rounded-full overflow-hidden border transition-all active:scale-95 flex items-center justify-center bg-slate-500/50 text-white font-bold text-sm ${
            currentTab === 'profile'
              ? 'border-indigo-500 ring-2 ring-indigo-500/30'
              : 'border-white/15 hover:border-white/25'
          }`}
        >
          {user.photoURL ? (
            <img src={user.photoURL} alt={user.displayName || 'Profile'} className="w-full h-full object-cover" />
          ) : (
            <span>{(user.displayName || 'H').trim().charAt(0).toUpperCase()}</span>
          )}
        </button>
      </div>
    </header>
  );
};
