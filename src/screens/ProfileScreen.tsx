import React, { useState } from 'react';
import {
  User,
  LogIn,
  LogOut,
  CheckCircle2,
  Sliders,
  AlertCircle,
} from 'lucide-react';
import { useMusic } from '../context/MusicContext';

export const ProfileScreen: React.FC = () => {
  const {
    user,
    signInWithGoogle,
    signInWithEmail,
    registerWithEmail,
    signOut,
    favorites,
    playlists,
    downloads,
    audioQuality,
    setAudioQuality,
    sleepTimerRemaining,
    setSleepTimer,
  } = useMusic();

  const [showAuthModal, setShowAuthModal] = useState(false);
  const [isRegisterMode, setIsRegisterMode] = useState(false);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [authError, setAuthError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleAuthSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!email || !password) return;
    setAuthError(null);
    setIsSubmitting(true);
    try {
      if (isRegisterMode) {
        await registerWithEmail(email, password);
      } else {
        await signInWithEmail(email, password);
      }
      setShowAuthModal(false);
      setEmail('');
      setPassword('');
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Authentication failed';
      setAuthError(message.replace('Firebase: ', ''));
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleGoogleSignIn = async () => {
    setAuthError(null);
    setIsSubmitting(true);
    try {
      await signInWithGoogle();
      setShowAuthModal(false);
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Google sign in failed';
      setAuthError(message.replace('Firebase: ', ''));
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="space-y-8 pb-12">
      <div>
        <span className="text-xs uppercase font-extrabold tracking-widest text-indigo-400">
          ACCOUNT & PREFERENCES
        </span>
        <h1 className="text-2xl sm:text-4xl font-black text-white tracking-tight mt-0.5">
          Profile & Cloud Sync
        </h1>
      </div>

      {/* User Card */}
      <div className="p-6 rounded-3xl bg-slate-900/60 border border-white/10 flex flex-col sm:flex-row sm:items-center justify-between gap-6 shadow-xl">
        <div className="flex items-center gap-4">
          <div className="w-16 h-16 rounded-2xl bg-slate-500/65 border border-white/10 flex items-center justify-center text-white shadow-lg overflow-hidden shrink-0">
            {user.photoURL ? (
              <img src={user.photoURL} alt={user.displayName || 'User'} className="w-full h-full object-cover" />
            ) : (
              <span className="text-2xl font-black tracking-tight">
                {(user.displayName || 'H').trim().charAt(0).toUpperCase()}
              </span>
            )}
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h2 className="text-lg font-black text-white">{user.displayName || 'Guest Listener'}</h2>
              {!user.isGuest && (
                <span className="px-2 py-0.5 rounded-full bg-emerald-500/20 text-emerald-400 text-[10px] font-bold border border-emerald-500/30 flex items-center gap-1">
                  <CheckCircle2 className="w-3 h-3" />
                  Synced
                </span>
              )}
            </div>
            <p className="text-xs text-slate-400 mt-0.5">
              {user.isGuest ? 'Local session • Sign in to sync across devices' : user.email}
            </p>
          </div>
        </div>

        {user.isGuest ? (
          <button
            onClick={() => setShowAuthModal(true)}
            className="flex items-center gap-2 px-5 py-2.5 rounded-2xl bg-indigo-600 hover:bg-indigo-500 text-white font-bold text-xs shadow-lg shadow-indigo-600/30 self-start sm:self-auto transition-transform active:scale-95"
          >
            <LogIn className="w-4 h-4" />
            <span>Sign In / Register</span>
          </button>
        ) : (
          <button
            onClick={() => signOut()}
            className="flex items-center gap-2 px-4 py-2 rounded-2xl bg-white/5 hover:bg-white/10 text-slate-300 hover:text-white text-xs font-semibold self-start sm:self-auto transition-colors"
          >
            <LogOut className="w-4 h-4" />
            <span>Sign Out</span>
          </button>
        )}
      </div>

      {/* Cloud & Library Stats */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="p-4 rounded-2xl bg-white/5 border border-white/5">
          <span className="text-[11px] text-slate-400 font-semibold uppercase tracking-wider block mb-1">
            Favorites
          </span>
          <span className="text-2xl font-black text-white">{favorites.length}</span>
          <span className="text-xs text-indigo-400 block mt-1">Saved tracks</span>
        </div>

        <div className="p-4 rounded-2xl bg-white/5 border border-white/5">
          <span className="text-[11px] text-slate-400 font-semibold uppercase tracking-wider block mb-1">
            Custom Playlists
          </span>
          <span className="text-2xl font-black text-white">{playlists.length}</span>
          <span className="text-xs text-purple-400 block mt-1">Curated collections</span>
        </div>

        <div className="p-4 rounded-2xl bg-white/5 border border-white/5">
          <span className="text-[11px] text-slate-400 font-semibold uppercase tracking-wider block mb-1">
            Offline Storage
          </span>
          <span className="text-2xl font-black text-white">{downloads.length}</span>
          <span className="text-xs text-emerald-400 block mt-1">Cached for offline</span>
        </div>
      </div>

      {/* Streaming & Audio Preferences */}
      <div className="space-y-4">
        <div className="flex items-center gap-2">
          <Sliders className="w-4 h-4 text-indigo-400" />
          <h3 className="text-lg font-bold text-white tracking-tight">Audio & Playback Settings</h3>
        </div>

        <div className="p-5 rounded-3xl bg-slate-900/60 border border-white/10 space-y-4">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 pb-4 border-b border-white/5">
            <div>
              <h4 className="text-sm font-bold text-white">Streaming Audio Quality</h4>
              <p className="text-xs text-slate-400">Controls streaming bitrate and frequency response</p>
            </div>
            <select
              value={audioQuality}
              onChange={(e) => setAudioQuality(e.target.value)}
              className="px-3 py-1.5 rounded-xl bg-white/5 border border-white/10 text-xs text-white focus:outline-none focus:border-indigo-500 font-medium"
            >
              <option value="Very High (320 kbps - Lossless)" className="bg-slate-900">Very High (320 kbps - Lossless)</option>
              <option value="High (256 kbps - Enhanced AAC)" className="bg-slate-900">High (256 kbps - Enhanced AAC)</option>
              <option value="Standard (160 kbps - AAC)" className="bg-slate-900">Standard (160 kbps - AAC)</option>
              <option value="Data Saver (96 kbps - OPUS)" className="bg-slate-900">Data Saver (96 kbps - OPUS)</option>
            </select>
          </div>

          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
            <div>
              <h4 className="text-sm font-bold text-white">Sleep Timer</h4>
              <p className="text-xs text-slate-400">Automatically stop playback after duration</p>
            </div>
            <div className="flex items-center gap-2">
              {[null, 15, 30, 60].map((mins) => {
                const isSelected = mins === null ? sleepTimerRemaining === null : sleepTimerRemaining !== null && Math.ceil(sleepTimerRemaining / 60) === mins;
                return (
                  <button
                    key={mins === null ? 'off' : mins}
                    onClick={() => setSleepTimer(mins)}
                    className={`px-3 py-1.5 rounded-xl text-xs font-semibold transition-all ${
                      isSelected
                        ? 'bg-indigo-600 text-white shadow-md'
                        : 'bg-white/5 hover:bg-white/10 text-slate-300'
                    }`}
                  >
                    {mins === null ? 'Off' : `${mins}m`}
                  </button>
                );
              })}
            </div>
          </div>
        </div>
      </div>

      {/* Authentication Modal */}
      {showAuthModal && (
        <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-md flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-white/10 w-full max-w-sm rounded-3xl p-6 shadow-2xl space-y-4 animate-in zoom-in-95 duration-200">
            <div>
              <h3 className="font-bold text-white text-lg">
                {isRegisterMode ? 'Create Twilight Account' : 'Welcome Back'}
              </h3>
              <p className="text-xs text-slate-400 mt-0.5">
                Sync your favorites, playlists, and taste history
              </p>
            </div>

            {authError && (
              <div className="p-3 rounded-xl bg-rose-500/10 border border-rose-500/20 flex items-start gap-2 text-rose-400 text-xs">
                <AlertCircle className="w-4 h-4 shrink-0 mt-0.5" />
                <span>{authError}</span>
              </div>
            )}

            {/* Google Sign In */}
            <button
              onClick={handleGoogleSignIn}
              disabled={isSubmitting}
              className="w-full py-2.5 rounded-xl bg-white text-slate-950 hover:bg-slate-100 font-bold text-xs flex items-center justify-center gap-2 transition-transform active:scale-98 shadow-md"
            >
              <svg className="w-4 h-4" viewBox="0 0 24 24">
                <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
                <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
                <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.06H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.94l2.85-2.22.81-.63z"/>
                <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.84c.87-2.6 3.3-4.52 6.16-4.52z"/>
              </svg>
              <span>Continue with Google</span>
            </button>

            <div className="flex items-center gap-3 text-slate-500 text-xs">
              <div className="flex-1 h-px bg-white/10" />
              <span>OR</span>
              <div className="flex-1 h-px bg-white/10" />
            </div>

            {/* Email / Password Form */}
            <form onSubmit={handleAuthSubmit} className="space-y-3">
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="Email address"
                required
                className="w-full px-3.5 py-2.5 rounded-xl bg-white/5 border border-white/10 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-indigo-500"
              />
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="Password"
                required
                className="w-full px-3.5 py-2.5 rounded-xl bg-white/5 border border-white/10 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-indigo-500"
              />
              <button
                type="submit"
                disabled={isSubmitting}
                className="w-full py-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white font-bold text-xs shadow-md transition-colors"
              >
                {isSubmitting ? 'Authenticating...' : isRegisterMode ? 'Create Account' : 'Sign In'}
              </button>
            </form>

            <div className="flex items-center justify-between text-xs pt-2">
              <button
                onClick={() => setIsRegisterMode(!isRegisterMode)}
                className="text-indigo-400 hover:underline"
              >
                {isRegisterMode ? 'Already have an account? Sign In' : 'Need an account? Register'}
              </button>
              <button
                onClick={() => setShowAuthModal(false)}
                className="text-slate-400 hover:text-white"
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
