import React, { useEffect, useRef, useState } from 'react';
import {
  Download,
  Smartphone,
  Monitor,
  Apple,
  CheckCircle,
  ShieldCheck,
  Zap,
  CloudUpload,
  ExternalLink,
  Loader2,
  AlertCircle,
  Sparkles,
  GitBranch,
  Check,
} from 'lucide-react';
import { TwilightLogo } from '../components/TwilightLogo';
import { GoogleDriveService, DriveUploadResult } from '../services/googleDriveService';

interface LandingScreenProps {
  onNavigate?: (tab: 'home' | 'explore' | 'search' | 'library' | 'profile' | 'landing') => void;
}

export const LandingScreen: React.FC<LandingScreenProps> = ({ onNavigate }) => {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);

  // Google Drive Upload State
  const [showDriveConfirm, setShowDriveConfirm] = useState(false);
  const [isUploadingDrive, setIsUploadingDrive] = useState(false);
  const [driveProgress, setDriveProgress] = useState<{ percent: number; message: string }>({
    percent: 0,
    message: '',
  });
  const [driveResult, setDriveResult] = useState<DriveUploadResult | null>(null);

  // GitHub v3.0.0 Release Publisher Modal State
  const [showGithubModal, setShowGithubModal] = useState(false);
  const [githubRepo, setGithubRepo] = useState('hasibcore/Twilight-Music');
  const [githubToken, setGithubToken] = useState('');
  const [isPublishingGithub, setIsPublishingGithub] = useState(false);
  const [githubResult, setGithubResult] = useState<{
    success: boolean;
    pushedFullRepo?: boolean;
    commitSha?: string;
    releaseUrl?: string;
    actionsUrl?: string;
    error?: string;
  } | null>(null);

  const handleStartDriveUpload = async () => {
    setShowDriveConfirm(false);
    setIsUploadingDrive(true);
    setDriveResult(null);

    const result = await GoogleDriveService.uploadReleaseArchive((percent, message) => {
      setDriveProgress({ percent, message });
    });

    setDriveResult(result);
    setIsUploadingDrive(false);
  };

  const handlePublishGithubRelease = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsPublishingGithub(true);
    setGithubResult(null);

    try {
      const res = await fetch('/api/release/github', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          repo: githubRepo,
          token: githubToken,
          tagName: 'v3.6.3',
        }),
      });
      const data = await res.json();
      if (res.ok && data.success) {
        setGithubResult({
          success: true,
          pushedFullRepo: data.pushedFullRepo,
          commitSha: data.commitSha,
          releaseUrl: data.releaseUrl,
          actionsUrl: data.actionsUrl,
        });
        setShowGithubModal(false);
      } else {
        setGithubResult({
          success: false,
          error: data.error || 'Failed to publish GitHub release.',
        });
      }
    } catch (err: any) {
      setGithubResult({
        success: false,
        error: err?.message || 'Network error while publishing to GitHub.',
      });
    } finally {
      setIsPublishingGithub(false);
    }
  };

  // Dynamic Audio Visualizer Animation
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    let animId: number;
    const barCount = 32;
    const bars = Array.from({ length: barCount }, () => Math.random() * 40 + 10);
    const targets = Array.from({ length: barCount }, () => Math.random() * 40 + 10);

    const render = () => {
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      const barWidth = Math.floor(canvas.width / barCount) - 2;

      for (let i = 0; i < barCount; i++) {
        bars[i] += (targets[i] - bars[i]) * 0.15;
        if (Math.abs(targets[i] - bars[i]) < 1.5) {
          targets[i] = Math.random() * (canvas.height * 0.8) + 5;
        }

        const barHeight = Math.max(3, bars[i]);
        const x = i * (barWidth + 2);
        const y = canvas.height - barHeight;

        const grad = ctx.createLinearGradient(0, y, 0, canvas.height);
        grad.addColorStop(0, '#ec4899');
        grad.addColorStop(0.5, '#a855f7');
        grad.addColorStop(1, '#6366f1');

        ctx.fillStyle = grad;
        ctx.beginPath();
        ctx.roundRect(x, y, barWidth, barHeight, 3);
        ctx.fill();
      }

      animId = requestAnimationFrame(render);
    };

    render();
    return () => cancelAnimationFrame(animId);
  }, []);

  return (
    <div className="space-y-10 pb-16 max-w-4xl mx-auto">
      {/* Hero Section */}
      <div className="text-center space-y-5 pt-4">
        {/* Official App Logo Icon */}
        <div className="flex justify-center">
          <TwilightLogo className="w-24 h-24 sm:w-28 sm:h-28 rounded-3xl shadow-2xl shadow-purple-600/35 ring-2 ring-purple-500/25 hover:scale-105 transition-transform" />
        </div>

        <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-emerald-500/10 border border-emerald-500/25 text-emerald-400 text-xs font-bold">
          <Zap className="w-3.5 h-3.5" />
          <span>Release v3.0.0 • Official Android APK, iOS IPA &amp; Windows PC Release</span>
        </div>

        <h1 className="text-3xl sm:text-5xl font-black text-white tracking-tight leading-tight">
          Your Music, Everywhere. <br />
          <span className="bg-gradient-to-r from-indigo-400 via-purple-400 to-rose-400 bg-clip-text text-transparent">
            Zero Ads. Zero Delays.
          </span>
        </h1>

        <p className="text-sm sm:text-base text-slate-400 max-w-xl mx-auto leading-relaxed">
          Twilight Music v3.0.0 delivers 100% exact YouTube video audio matching (including live concerts &amp; unplugged sessions), clean click-to-play startup, background lockscreen playback, and native builds for Android, iOS, and Windows PC.
        </p>

        {/* Visualizer Canvas */}
        <div className="w-full max-w-md mx-auto h-16 flex items-center justify-center pt-2">
          <canvas ref={canvasRef} width={380} height={60} className="w-full h-full" />
        </div>
      </div>

      {/* Platform Download Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {/* Android Card */}
        <div className="p-6 rounded-3xl bg-slate-900/80 border border-emerald-500/30 shadow-xl flex flex-col justify-between space-y-6 hover:-translate-y-1 transition-transform">
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <div className="w-12 h-12 rounded-2xl bg-emerald-500/20 text-emerald-400 flex items-center justify-center">
                <Smartphone className="w-6 h-6" />
              </div>
              <span className="px-2.5 py-1 rounded-full bg-emerald-500/15 border border-emerald-500/30 text-emerald-300 text-[10px] font-extrabold uppercase tracking-wider">
                v3.6.3 APK
              </span>
            </div>
            <h3 className="text-lg font-bold text-white">Android (APK)</h3>
            <p className="text-xs text-slate-400 leading-relaxed">
              Native Android 7.0+ APK (v3.6.3+63) with exact YouTube playback, full playlists, Unicode search &amp; offline downloads.
            </p>
          </div>

          <div className="flex flex-col gap-2">
            <a
              href="https://github.com/hasibcore/Twilight-Music/releases/download/v3.6.3/Twilight-Android-v3.6.3.apk"
              download="Twilight-Android-v3.6.3.apk"
              className="w-full py-3 rounded-2xl bg-gradient-to-r from-emerald-600 to-teal-500 hover:from-emerald-500 hover:to-teal-400 text-white font-bold text-xs flex items-center justify-center gap-2 shadow-lg shadow-emerald-600/30 transition-all text-center cursor-pointer"
            >
              <Download className="w-4 h-4" />
              <span>Download Android APK (v3.6.3)</span>
            </a>
            <button
              onClick={() => (onNavigate ? onNavigate('home') : (window.location.href = '/'))}
              className="w-full py-2.5 rounded-2xl bg-slate-800 hover:bg-slate-700 text-slate-200 font-semibold text-xs flex items-center justify-center gap-2 border border-slate-700/60 transition-all text-center cursor-pointer"
            >
              <Sparkles className="w-3.5 h-3.5 text-emerald-400" />
              <span>Open Web / PWA Player</span>
            </button>
            <a
              href="https://github.com/hasibcore/Twilight-Music/releases/tag/v3.6.3"
              target="_blank"
              rel="noopener noreferrer"
              className="w-full py-1.5 rounded-2xl text-slate-400 hover:text-slate-200 font-medium text-[11px] flex items-center justify-center gap-1.5 transition-colors"
            >
              <ExternalLink className="w-3 h-3" />
              <span>View v3.6.3 on GitHub Releases</span>
            </a>
          </div>
        </div>

        {/* Windows Card */}
        <div className="p-6 rounded-3xl bg-slate-900/80 border border-indigo-500/30 shadow-xl flex flex-col justify-between space-y-6 hover:-translate-y-1 transition-transform">
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <div className="w-12 h-12 rounded-2xl bg-indigo-500/20 text-indigo-400 flex items-center justify-center">
                <Monitor className="w-6 h-6" />
              </div>
              <span className="px-2.5 py-1 rounded-full bg-indigo-500/15 border border-indigo-500/30 text-indigo-300 text-[10px] font-extrabold uppercase tracking-wider">
                v3.6.3 x64
              </span>
            </div>
            <h3 className="text-lg font-bold text-white">Windows PC</h3>
            <p className="text-xs text-slate-400 leading-relaxed">
              Portable Windows 10/11 (64-bit) desktop build (`Twilight.exe`) with native high-bitrate audio engine &amp; local cache.
            </p>
          </div>

          <div className="flex flex-col gap-2">
            <a
              href="https://github.com/hasibcore/Twilight-Music/releases/download/v3.6.3/Twilight-Windows-x64-v3.6.3.zip"
              download="Twilight-Windows-x64-v3.6.3.zip"
              className="w-full py-3 rounded-2xl bg-indigo-600 hover:bg-indigo-500 text-white font-bold text-xs flex items-center justify-center gap-2 shadow-lg shadow-indigo-600/30 transition-all text-center"
            >
              <Download className="w-4 h-4" />
              <span>Download Windows x64 (.zip)</span>
            </a>
            <a
              href="https://github.com/hasibcore/Twilight-Music/releases/tag/v3.6.3"
              target="_blank"
              rel="noopener noreferrer"
              className="w-full py-1.5 rounded-2xl text-slate-400 hover:text-slate-200 font-medium text-[11px] flex items-center justify-center gap-1.5 transition-colors"
            >
              <ExternalLink className="w-3 h-3" />
              <span>View Windows Release Notes</span>
            </a>
          </div>
        </div>

        {/* iOS Card */}
        <div className="p-6 rounded-3xl bg-slate-900/80 border border-rose-500/30 shadow-xl flex flex-col justify-between space-y-6 hover:-translate-y-1 transition-transform">
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <div className="w-12 h-12 rounded-2xl bg-rose-500/20 text-rose-400 flex items-center justify-center">
                <Apple className="w-6 h-6" />
              </div>
              <span className="px-2.5 py-1 rounded-full bg-rose-500/15 border border-rose-500/30 text-rose-300 text-[10px] font-extrabold uppercase tracking-wider">
                v3.6.3 IPA
              </span>
            </div>
            <h3 className="text-lg font-bold text-white">Apple iOS</h3>
            <p className="text-xs text-slate-400 leading-relaxed">
              Unsigned iOS IPA package (`Twilight-iOS-v3.6.3.ipa`) for AltStore, Sideloadly, Scarlet, or TrollStore.
            </p>
          </div>

          <div className="flex flex-col gap-2">
            <a
              href="https://github.com/hasibcore/Twilight-Music/releases/download/v3.6.3/Twilight-iOS-v3.6.3.ipa"
              download="Twilight-iOS-v3.6.3.ipa"
              className="w-full py-3 rounded-2xl bg-rose-600 hover:bg-rose-500 text-white font-bold text-xs flex items-center justify-center gap-2 shadow-lg shadow-rose-600/30 transition-all text-center"
            >
              <Download className="w-4 h-4" />
              <span>Download iOS Package (.ipa)</span>
            </a>
            <a
              href="https://github.com/hasibcore/Twilight-Music/releases/tag/v3.6.3"
              target="_blank"
              rel="noopener noreferrer"
              className="w-full py-1.5 rounded-2xl text-slate-400 hover:text-slate-200 font-medium text-[11px] flex items-center justify-center gap-1.5 transition-colors"
            >
              <ExternalLink className="w-3 h-3" />
              <span>View iOS Release Notes</span>
            </a>
          </div>
        </div>
      </div>

      {/* GitHub & Google Drive Whole Project v3.0.0 Package Card */}
      <div className="p-6 rounded-3xl bg-gradient-to-r from-indigo-950/60 via-purple-950/60 to-slate-900 border border-indigo-500/30 shadow-2xl flex flex-col md:flex-row items-center justify-between gap-6">
        <div className="space-y-2 text-center md:text-left">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-indigo-500/20 text-indigo-400 text-xs font-bold">
            <ShieldCheck className="w-4 h-4" />
            <span>Live Multi-Platform Codebase • v3.0.0 Production Release</span>
          </div>
          <h3 className="text-xl font-bold text-white">Export v3.0.0 Release to GitHub &amp; Google Drive</h3>
          <p className="text-xs text-slate-400 max-w-xl">
            Download the live <strong>Twilight Music v3.0.0</strong> full project archive containing the Android, iOS, Windows &amp; React Web codebases plus <code>.github/workflows/build-apk.yml</code>, or publish directly to GitHub Releases.
          </p>
        </div>

        <div className="flex flex-col sm:flex-row flex-wrap items-center gap-3 w-full md:w-auto shrink-0">
          <button
            onClick={() => {
              setGithubResult(null);
              setShowGithubModal(true);
            }}
            className="w-full sm:w-auto px-5 py-3 rounded-2xl bg-emerald-500/20 hover:bg-emerald-500/30 border border-emerald-500/40 text-emerald-300 font-bold text-xs flex items-center justify-center gap-2 transition-all cursor-pointer"
          >
            <GitBranch className="w-4 h-4" />
            <span>Publish v3.0.0 to GitHub</span>
          </button>

          <a
            href="/api/release/project-archive"
            download="Twilight-Music-v3.0.0-Full-Project.tar.gz"
            className="w-full sm:w-auto px-5 py-3 rounded-2xl bg-white/10 hover:bg-white/20 text-white font-bold text-xs flex items-center justify-center gap-2 transition-all"
          >
            <Download className="w-4 h-4" />
            <span>Download v3.0.0 Project Archive</span>
          </a>

          <button
            onClick={() => setShowDriveConfirm(true)}
            disabled={isUploadingDrive}
            className="w-full sm:w-auto px-6 py-3.5 rounded-2xl bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-500 hover:to-purple-500 disabled:opacity-50 text-white font-bold text-xs flex items-center justify-center gap-2 shadow-xl shadow-indigo-600/30 hover:scale-102 active:scale-98 transition-all cursor-pointer"
          >
            {isUploadingDrive ? (
              <>
                <Loader2 className="w-4 h-4 animate-spin" />
                <span>Uploading... ({driveProgress.percent}%)</span>
              </>
            ) : (
              <>
                <CloudUpload className="w-4 h-4" />
                <span>Save v3.0.0 to Google Drive</span>
              </>
            )}
          </button>
        </div>
      </div>

      {/* GitHub Publish Result Banner */}
      {githubResult && (
        <div
          className={`p-5 rounded-2xl border text-xs flex items-start justify-between gap-4 ${
            githubResult.success
              ? 'bg-emerald-950/40 border-emerald-500/30 text-emerald-200'
              : 'bg-rose-950/40 border-rose-500/30 text-rose-200'
          }`}
        >
          <div className="flex items-start gap-3">
            {githubResult.success ? (
              <CheckCircle className="w-5 h-5 text-emerald-400 shrink-0 mt-0.5" />
            ) : (
              <AlertCircle className="w-5 h-5 text-rose-400 shrink-0 mt-0.5" />
            )}
            <div>
              <p className="font-bold text-sm">
                {githubResult.success
                  ? `Pushed Full App & Published Twilight Music v3.0.0 to GitHub${githubResult.commitSha ? ` (commit ${githubResult.commitSha})` : ''}!`
                  : 'GitHub Release publish status'}
              </p>
              <p className="text-slate-300 mt-1">
                {githubResult.success
                  ? 'Pushed full repository to main, tagged v3.0.0, and triggered GitHub Actions builds for Android APK, iOS IPA, and Windows x64 ZIP.'
                  : githubResult.error}
              </p>
            </div>
          </div>

          {githubResult.releaseUrl && (
            <a
              href={githubResult.releaseUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="px-4 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-xs flex items-center gap-1.5 shrink-0 transition-colors"
            >
              <span>Open GitHub Release</span>
              <ExternalLink className="w-3.5 h-3.5" />
            </a>
          )}
        </div>
      )}

      {/* Google Drive Upload Result Banner */}
      {driveResult && (
        <div
          className={`p-5 rounded-2xl border text-xs flex items-start justify-between gap-4 ${
            driveResult.success
              ? 'bg-emerald-950/40 border-emerald-500/30 text-emerald-200'
              : 'bg-rose-950/40 border-rose-500/30 text-rose-200'
          }`}
        >
          <div className="flex items-start gap-3">
            {driveResult.success ? (
              <CheckCircle className="w-5 h-5 text-emerald-400 shrink-0 mt-0.5" />
            ) : (
              <AlertCircle className="w-5 h-5 text-rose-400 shrink-0 mt-0.5" />
            )}
            <div>
              <p className="font-bold text-sm">
                {driveResult.success
                  ? 'Successfully saved v3.0.0 to Google Drive!'
                  : 'Google Drive upload failed'}
              </p>
              <p className="text-slate-300 mt-1">
                {driveResult.success
                  ? `Saved as '${driveResult.fileName}' in your Google Drive 'Twilight Music Releases' folder.`
                  : driveResult.error}
              </p>
            </div>
          </div>

          {driveResult.webViewLink && (
            <a
              href={driveResult.webViewLink}
              target="_blank"
              rel="noopener noreferrer"
              className="px-4 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-xs flex items-center gap-1.5 shrink-0 transition-colors"
            >
              <span>Open in Drive</span>
              <ExternalLink className="w-3.5 h-3.5" />
            </a>
          )}
        </div>
      )}

      {/* What's Fixed in v3.0.0 Production Release Summary */}
      <div className="p-6 rounded-3xl bg-slate-900/70 border border-white/10 space-y-4">
        <div className="flex items-center justify-between flex-wrap gap-2">
          <div className="flex items-center gap-2.5">
            <span className="w-8 h-8 rounded-xl bg-emerald-500/20 border border-emerald-500/30 flex items-center justify-center text-emerald-400">
              <Check className="w-4 h-4" />
            </span>
            <div>
              <h3 className="text-sm sm:text-base font-bold text-white">
                v3.0.0 Multi-Platform Release &amp; Exact YouTube Audio Changelog
              </h3>
              <p className="text-[11px] text-slate-400">
                Included across Android APK, Apple iOS IPA, Windows PC x64 ZIP, and Web Player
              </p>
            </div>
          </div>
          <span className="px-3 py-1 rounded-full bg-white/5 border border-white/10 text-[11px] font-mono text-slate-300">
            version: 3.0.0+30
          </span>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-3 text-xs text-slate-300">
          <div className="p-3.5 rounded-2xl bg-white/5 border border-white/5 space-y-1">
            <div className="font-bold text-white">1. 100% Exact YouTube Video Audio (`videoId`)</div>
            <p className="text-[11px] text-slate-400">
              Directly streams the selected YouTube video&apos;s exact audio stream first across Android, iOS, Windows, and Web so live concerts, unplugged versions, and remixes always match YouTube.
            </p>
          </div>
          <div className="p-3.5 rounded-2xl bg-white/5 border border-white/5 space-y-1">
            <div className="font-bold text-white">2. Clean Click-to-Play Startup</div>
            <p className="text-[11px] text-slate-400">
              No track is pre-selected or pre-loaded when opening the app; playback and the bottom mini player bar only activate after you click a song.
            </p>
          </div>
          <div className="p-3.5 rounded-2xl bg-white/5 border border-white/5 space-y-1">
            <div className="font-bold text-white">3. Native Android, iOS &amp; Windows Builds</div>
            <p className="text-[11px] text-slate-400">
              Automated GitHub Actions CI/CD compiles <code>Twilight-Android-v3.0.0.apk</code>, <code>Twilight-iOS-v3.0.0.ipa</code>, and <code>Twilight-Windows-x64-v3.0.0.zip</code> in parallel.
            </p>
          </div>
          <div className="p-3.5 rounded-2xl bg-white/5 border border-white/5 space-y-1">
            <div className="font-bold text-white">4. Verified Offline Downloads &amp; Background Audio</div>
            <p className="text-[11px] text-slate-400">
              Zero-stall offline caching, monochrome status-bar notification icon, and continuous lockscreen playback.
            </p>
          </div>
        </div>
      </div>

      {/* GitHub v3.0.0 Release Publisher Modal */}
      {showGithubModal && (
        <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-md flex items-center justify-center p-4">
          <form
            onSubmit={handlePublishGithubRelease}
            className="bg-slate-900 border border-white/10 w-full max-w-md rounded-3xl p-6 shadow-2xl space-y-4 animate-in zoom-in-95 duration-200"
          >
            <div className="w-12 h-12 rounded-2xl bg-emerald-500/20 text-emerald-400 flex items-center justify-center">
              <GitBranch className="w-6 h-6" />
            </div>

            <div>
              <h3 className="font-bold text-white text-lg">Publish v3.0.0 Release to GitHub</h3>
              <p className="text-xs text-slate-300 mt-1 leading-relaxed">
                This will sync <code>.github/workflows/build-apk.yml</code>, create the <strong>v3.0.0</strong> GitHub Release on your repository, and trigger the Android APK, iOS IPA, and Windows x64 builds.
              </p>
            </div>

            <div className="space-y-3">
              <div>
                <label className="block text-[11px] font-semibold text-slate-400 mb-1">
                  GitHub Repository (owner/repo)
                </label>
                <input
                  type="text"
                  value={githubRepo}
                  onChange={(e) => setGithubRepo(e.target.value)}
                  placeholder="hasibcore/Twilight-Music"
                  required
                  className="w-full px-3.5 py-2.5 rounded-xl bg-slate-950 border border-white/10 text-xs text-white focus:outline-none focus:border-emerald-500"
                />
              </div>

              <div>
                <label className="block text-[11px] font-semibold text-slate-400 mb-1">
                  GitHub Personal Access Token (repo write permission)
                </label>
                <input
                  type="password"
                  value={githubToken}
                  onChange={(e) => setGithubToken(e.target.value)}
                  placeholder="ghp_xxxxxxxxxxxxxxxxxxxx"
                  required
                  className="w-full px-3.5 py-2.5 rounded-xl bg-slate-950 border border-white/10 text-xs text-white focus:outline-none focus:border-emerald-500"
                />
              </div>
            </div>

            <div className="flex items-center justify-end gap-3 pt-2">
              <button
                type="button"
                onClick={() => setShowGithubModal(false)}
                className="px-4 py-2.5 rounded-xl bg-white/10 hover:bg-white/15 text-slate-300 text-xs font-semibold transition-colors"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={isPublishingGithub}
                className="px-5 py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 disabled:opacity-50 text-white text-xs font-bold shadow-lg shadow-emerald-600/30 transition-all flex items-center gap-2"
              >
                {isPublishingGithub ? (
                  <>
                    <Loader2 className="w-3.5 h-3.5 animate-spin" />
                    <span>Publishing v3.0.0...</span>
                  </>
                ) : (
                  <span>Publish v3.0.0 Release</span>
                )}
              </button>
            </div>
          </form>
        </div>
      )}

      {/* Google Drive Upload Confirmation Modal */}
      {showDriveConfirm && (
        <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-md flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-white/10 w-full max-w-md rounded-3xl p-6 shadow-2xl space-y-4 animate-in zoom-in-95 duration-200">
            <div className="w-12 h-12 rounded-2xl bg-indigo-500/20 text-indigo-400 flex items-center justify-center">
              <CloudUpload className="w-6 h-6" />
            </div>

            <div>
              <h3 className="font-bold text-white text-lg">Save v3.0.0 Release to Google Drive</h3>
              <p className="text-xs text-slate-300 mt-1 leading-relaxed">
                This will save the complete <strong>Twilight Music v3.0.0 Production Release Package</strong> into a dedicated <code>Twilight Music Releases</code> folder in your personal Google Drive.
              </p>
            </div>

            <div className="p-3 rounded-2xl bg-white/5 border border-white/5 space-y-1 text-[11px] text-slate-400">
              <div>• Package: <code>Twilight-Music-v3.0.0-Full-Project.tar.gz</code></div>
              <div>• Destination: Google Drive &gt; Twilight Music Releases</div>
              <div>• Permission: Authorized with your Google Account</div>
            </div>

            <div className="flex items-center justify-end gap-3 pt-2">
              <button
                type="button"
                onClick={() => setShowDriveConfirm(false)}
                className="px-4 py-2.5 rounded-xl bg-white/10 hover:bg-white/15 text-slate-300 text-xs font-semibold transition-colors"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleStartDriveUpload}
                className="px-5 py-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-bold shadow-lg shadow-indigo-600/30 transition-all"
              >
                Confirm &amp; Save to Drive
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Feature Highlights Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-4 gap-4 pt-2">
        <div className="p-4 rounded-2xl bg-white/5 border border-white/5 space-y-1.5">
          <CheckCircle className="w-5 h-5 text-emerald-400" />
          <h4 className="text-xs font-bold text-white">256 kbps Enhanced AAC</h4>
          <p className="text-[11px] text-slate-400">High bitrate studio reference acoustic fidelity</p>
        </div>

        <div className="p-4 rounded-2xl bg-white/5 border border-white/5 space-y-1.5">
          <CheckCircle className="w-5 h-5 text-indigo-400" />
          <h4 className="text-xs font-bold text-white">Background Lockscreen</h4>
          <p className="text-[11px] text-slate-400">Audio continues with screen off and notifications</p>
        </div>

        <div className="p-4 rounded-2xl bg-white/5 border border-white/5 space-y-1.5">
          <CheckCircle className="w-5 h-5 text-purple-400" />
          <h4 className="text-xs font-bold text-white">Firebase Cloud Sync</h4>
          <p className="text-[11px] text-slate-400">Synchronized playlists across mobile &amp; PC</p>
        </div>

        <div className="p-4 rounded-2xl bg-white/5 border border-white/5 space-y-1.5">
          <CheckCircle className="w-5 h-5 text-rose-400" />
          <h4 className="text-xs font-bold text-white">Zero Commercials</h4>
          <p className="text-[11px] text-slate-400">Pure music streaming without audio interruptions</p>
        </div>
      </div>
    </div>
  );
};
