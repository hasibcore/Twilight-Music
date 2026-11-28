// ==========================================================================
// Twilight Music — High-End Modern Landing Experience & Audio Engine
// ==========================================================================

const GITHUB_REPO = 'hasibcore/Twilight-Music';
const GITHUB_API_URL = `https://api.github.com/repos/${GITHUB_REPO}`;

// Sample Preview Playlist for the Floating Glass Audio Player
const PREVIEW_TRACKS = [
  {
    title: 'Obak Bhalobasha',
    artist: 'Warfaze • Coke Studio Bangla',
    duration: '05:24',
    durationSec: 324,
    streamUrl: 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview221/v4/d2/ac/fd/d2acfd00-a355-b90f-0617-407b09854edf/mzaf_4305828433436600036.plus.aac.p.m4a',
  },
  {
    title: 'Shape of You',
    artist: 'Ed Sheeran • ÷ (Divide)',
    duration: '03:54',
    durationSec: 234,
    streamUrl: 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview221/v4/44/c7/4f/44c74f0d-72dc-6143-d4d0-ba14d661ca0d/mzaf_9566898362556366703.plus.aac.p.m4a',
  },
  {
    title: 'Bohemian Rhapsody',
    artist: 'Queen • A Night at the Opera',
    duration: '05:55',
    durationSec: 355,
    streamUrl: 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview221/v4/4b/83/09/4b8309c3-e3b2-10bd-ea80-ec017d832503/mzaf_9752264660400108875.plus.aac.p.m4a',
  },
];

let currentTrackIdx = 0;
let isAudioActive = false;
let audioPlayerInstance = null;
let playbackSeconds = 0;
let trackInterval = null;

document.addEventListener('DOMContentLoaded', () => {
  fetchLiveGitHubStats();
  detectVisitorPlatform();
  initSegmentedTabs();
  initFloatingAudioPlayer();
  initWaveformVisualizer();
});

// 1. Fetch Live Dynamic GitHub Metrics & Release Data
async function fetchLiveGitHubStats() {
  try {
    const res = await fetch(GITHUB_API_URL, { signal: AbortSignal.timeout(4000) });
    if (res.ok) {
      const data = await res.json();
      const stars = data.stargazers_count ?? 12;
      const forks = data.forks_count ?? 4;

      const starCounters = [
        document.getElementById('navStarCounter'),
        document.getElementById('metricStarsLive'),
      ];
      starCounters.forEach((el) => {
        if (el) el.textContent = `★ ${stars}`;
      });

      const forkEl = document.getElementById('metricForksLive');
      if (forkEl) forkEl.textContent = String(forks);
    }
  } catch (e) {
    // Fallback gracefully
  }

  try {
    const relRes = await fetch(`${GITHUB_API_URL}/releases`, { signal: AbortSignal.timeout(4500) });
    if (relRes.ok) {
      const releases = await relRes.json();
      if (Array.isArray(releases) && releases.length > 0) {
        const latest = releases[0];
        const tag = latest.tag_name || 'v3.0.0';

        const tagBadges = [
          document.getElementById('headerVersionTag'),
          document.getElementById('metricReleaseLive'),
        ];
        tagBadges.forEach((el) => {
          if (el) el.textContent = tag;
        });

        // Compute total download count
        let totalCount = 0;
        releases.forEach((r) => {
          if (Array.isArray(r.assets)) {
            r.assets.forEach((a) => {
              totalCount += Number(a.download_count || 0);
            });
          }
        });

        if (totalCount > 0) {
          const formatted = totalCount >= 1000
            ? `${(totalCount / 1000).toFixed(1)}k+`
            : `${totalCount}+`;

          const counter = document.getElementById('heroDownloadsCounter');
          if (counter) counter.textContent = formatted;
        }
      }
    }
  } catch (e) {
    // Fallback gracefully
  }
}

// 2. Intelligent OS Detection & Smart Hero Button Adaptation
function detectVisitorPlatform() {
  const ua = navigator.userAgent || navigator.vendor || window.opera || '';
  const platform = navigator.platform || '';

  const labelEl = document.getElementById('smartBtnLabel');
  const subEl = document.getElementById('smartBtnSub');
  const btnEl = document.getElementById('heroSmartDownloadBtn');

  let targetUrl = '#downloads';

  if (/android/i.test(ua)) {
    targetUrl = 'https://github.com/hasibcore/Twilight-Music/releases/download/v3.6.4/Twilight-Android-v3.6.4.apk';
    highlightPlatformCard('card-android');
    if (labelEl) labelEl.textContent = 'Download for Android (APK)';
    if (subEl) subEl.textContent = 'Free APK • v3.6.4 Official';
  } else if (/iPad|iPhone|iPod/.test(ua) && !window.MSStream) {
    targetUrl = 'https://github.com/hasibcore/Twilight-Music/releases/download/v3.6.4/Twilight-iOS-v3.6.4.ipa';
    highlightPlatformCard('card-ios');
    if (labelEl) labelEl.textContent = 'Download for iOS (IPA)';
    if (subEl) subEl.textContent = 'IPA Sideload & Web PWA';
  } else if (/Win/i.test(platform) || /Windows/i.test(ua)) {
    targetUrl = 'https://github.com/hasibcore/Twilight-Music/releases/download/v3.6.4/Twilight-Windows-x64-v3.6.4.zip';
    highlightPlatformCard('card-windows');
    if (labelEl) labelEl.textContent = 'Download for Windows (x64)';
    if (subEl) subEl.textContent = 'Portable Standalone ZIP & EXE';
  } else if (/Mac/i.test(platform)) {
    targetUrl = '/';
    highlightPlatformCard('card-web');
    if (labelEl) labelEl.textContent = 'Launch Instant Web Player';
    if (subEl) subEl.textContent = 'Zero Install • Works in Safari';
  } else {
    highlightPlatformCard('card-android');
  }

  if (btnEl && targetUrl !== '#downloads') {
    btnEl.href = targetUrl;
    if (targetUrl.endsWith('.apk') || targetUrl.endsWith('.zip') || targetUrl.endsWith('.ipa')) {
      btnEl.setAttribute('download', '');
    }
  }
}

function highlightPlatformCard(cardId) {
  const card = document.getElementById(cardId);
  if (card) {
    card.classList.add('target-highlight');
  }
}

// 3. Segmented Platform Filter Tabs
function initSegmentedTabs() {
  const buttons = document.querySelectorAll('.seg-btn');
  const cards = document.querySelectorAll('.platform-card');

  buttons.forEach((btn) => {
    btn.addEventListener('click', () => {
      buttons.forEach((b) => b.classList.remove('active'));
      btn.classList.add('active');

      const filter = btn.getAttribute('data-filter');

      cards.forEach((card) => {
        if (filter === 'all') {
          card.style.display = 'flex';
        } else {
          const cardPlatform = card.getAttribute('data-platform');
          if (cardPlatform === filter) {
            card.style.display = 'flex';
            card.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
          } else {
            card.style.display = 'none';
          }
        }
      });
    });
  });
}

// 4. Interactive Floating Glass Audio Player
function initFloatingAudioPlayer() {
  audioPlayerInstance = new Audio();
  audioPlayerInstance.preload = 'none';

  const playBtn = document.getElementById('ctrlPlayBtn');
  const prevBtn = document.getElementById('ctrlPrevBtn');
  const nextBtn = document.getElementById('ctrlNextBtn');
  const playIcon = document.getElementById('playIconSvg');
  const pauseIcon = document.getElementById('pauseIconSvg');
  const disc = document.getElementById('heroAlbumDisc');
  const trackTitle = document.getElementById('playerTrackTitle');
  const trackArtist = document.getElementById('playerTrackArtist');
  const statusText = document.getElementById('playerStatusText');
  const progressFill = document.getElementById('playerProgressFill');
  const currentTimeEl = document.getElementById('playerCurrentTime');
  const totalTimeEl = document.getElementById('playerTotalTime');
  const progressWrapper = document.getElementById('playerProgressWrapper');

  function renderTrack() {
    const track = PREVIEW_TRACKS[currentTrackIdx];
    if (trackTitle) trackTitle.textContent = track.title;
    if (trackArtist) trackArtist.textContent = track.artist;
    if (totalTimeEl) totalTimeEl.textContent = track.duration;
    playbackSeconds = 0;
    if (progressFill) progressFill.style.width = '0%';
    if (currentTimeEl) currentTimeEl.textContent = '0:00';
  }

  function play() {
    const track = PREVIEW_TRACKS[currentTrackIdx];
    isAudioActive = true;
    if (playIcon) playIcon.style.display = 'none';
    if (pauseIcon) pauseIcon.style.display = 'block';
    if (disc) disc.style.animationPlayState = 'running';
    if (statusText) statusText.textContent = 'Playing Live Stream';

    try {
      if (audioPlayerInstance.src !== track.streamUrl) {
        audioPlayerInstance.src = track.streamUrl;
      }
      audioPlayerInstance.play().catch(() => {});
    } catch {}

    clearInterval(trackInterval);
    trackInterval = setInterval(() => {
      playbackSeconds += 1;
      const totalSec = track.durationSec || 200;
      const pct = Math.min(100, (playbackSeconds / totalSec) * 100);

      if (progressFill) progressFill.style.width = `${pct}%`;

      const mins = Math.floor(playbackSeconds / 60);
      const secs = playbackSeconds % 60;
      if (currentTimeEl) {
        currentTimeEl.textContent = `${mins}:${secs < 10 ? '0' : ''}${secs}`;
      }

      if (playbackSeconds >= totalSec) {
        skipNext();
      }
    }, 1000);
  }

  function pause() {
    isAudioActive = false;
    if (playIcon) playIcon.style.display = 'block';
    if (pauseIcon) pauseIcon.style.display = 'none';
    if (disc) disc.style.animationPlayState = 'paused';
    if (statusText) statusText.textContent = 'Paused';
    if (audioPlayerInstance) audioPlayerInstance.pause();
    clearInterval(trackInterval);
  }

  function skipNext() {
    currentTrackIdx = (currentTrackIdx + 1) % PREVIEW_TRACKS.length;
    renderTrack();
    if (isAudioActive) play();
  }

  function skipPrev() {
    currentTrackIdx = (currentTrackIdx - 1 + PREVIEW_TRACKS.length) % PREVIEW_TRACKS.length;
    renderTrack();
    if (isAudioActive) play();
  }

  if (playBtn) {
    playBtn.addEventListener('click', () => {
      if (isAudioActive) pause();
      else play();
    });
  }

  if (nextBtn) nextBtn.addEventListener('click', skipNext);
  if (prevBtn) prevBtn.addEventListener('click', skipPrev);

  if (progressWrapper) {
    progressWrapper.addEventListener('click', (e) => {
      const rect = progressWrapper.getBoundingClientRect();
      const pos = (e.clientX - rect.left) / rect.width;
      const track = PREVIEW_TRACKS[currentTrackIdx];
      playbackSeconds = Math.floor(pos * track.durationSec);
      if (audioPlayerInstance && audioPlayerInstance.duration) {
        audioPlayerInstance.currentTime = pos * audioPlayerInstance.duration;
      }
      if (progressFill) progressFill.style.width = `${pos * 100}%`;
    });
  }

  renderTrack();
}

// 5. Canvas Waveform Audio Visualizer
function initWaveformVisualizer() {
  const canvas = document.getElementById('heroVisualizerCanvas');
  if (!canvas) return;
  const ctx = canvas.getContext('2d');
  const width = canvas.width;
  const height = canvas.height;

  const barCount = 38;
  const barWidth = Math.floor(width / barCount) - 2;

  let heights = Array.from({ length: barCount }, () => Math.random() * (height * 0.35) + 4);
  let targets = Array.from({ length: barCount }, () => Math.random() * (height * 0.35) + 4);

  function draw() {
    ctx.clearRect(0, 0, width, height);

    const multiplier = isAudioActive ? 0.95 : 0.22;

    for (let i = 0; i < barCount; i++) {
      heights[i] += (targets[i] - heights[i]) * 0.15;
      if (Math.abs(targets[i] - heights[i]) < 1.2) {
        targets[i] = (Math.random() * (height * multiplier)) + 3;
      }

      const barHeight = Math.max(2, heights[i]);
      const x = i * (barWidth + 2);
      const y = height - barHeight;

      const grad = ctx.createLinearGradient(0, y, 0, height);
      grad.addColorStop(0, '#EC4899');
      grad.addColorStop(0.5, '#A855F7');
      grad.addColorStop(1, '#6366F1');

      ctx.fillStyle = grad;
      ctx.beginPath();
      ctx.roundRect(x, y, barWidth, barHeight, 2);
      ctx.fill();
    }

    requestAnimationFrame(draw);
  }

  draw();
}

// 6. Mobile QR Code Modal
function triggerQrModal(url, title = 'Direct APK') {
  const backdrop = document.getElementById('qrModalBackdrop');
  const titleEl = document.getElementById('modalQrTitle');
  const urlInput = document.getElementById('qrDirectUrlInput');
  const canvas = document.getElementById('qrCanvas');

  if (titleEl) titleEl.textContent = `Scan to Download ${title}`;
  if (urlInput) urlInput.value = url;

  if (canvas) {
    const ctx = canvas.getContext('2d');
    const size = canvas.width;
    ctx.fillStyle = '#FFFFFF';
    ctx.fillRect(0, 0, size, size);

    const img = new Image();
    img.crossOrigin = 'anonymous';
    img.onload = () => {
      ctx.drawImage(img, 10, 10, size - 20, size - 20);
    };
    img.src = `https://api.qrserver.com/v1/create-qr-code/?size=200x200&margin=4&data=${encodeURIComponent(url)}`;
  }

  if (backdrop) backdrop.classList.add('open');
}

function closeQrModal() {
  const backdrop = document.getElementById('qrModalBackdrop');
  if (backdrop) backdrop.classList.remove('open');
}

function copyDirectQrUrl() {
  const input = document.getElementById('qrDirectUrlInput');
  if (input) {
    navigator.clipboard.writeText(input.value);
    displayToast('✓ Download link copied to clipboard!');
  }
}

// 7. Terminal Snippet Clipboard Copy
function copyTerminalSnippet() {
  const cmd = 'git clone https://github.com/hasibcore/Twilight-Music.git';
  navigator.clipboard.writeText(cmd).then(() => {
    const status = document.getElementById('copyBtnStatus');
    if (status) {
      status.textContent = 'Copied!';
      setTimeout(() => {
        status.textContent = 'Copy';
      }, 2500);
    }
    displayToast('✓ Copied: git clone https://github.com/hasibcore/Twilight-Music.git');
  }).catch(() => {
    displayToast('Command copied');
  });
}

function displayToast(msg) {
  const hub = document.getElementById('toastHub');
  if (!hub) return;

  const toast = document.createElement('div');
  toast.className = 'toast-msg';
  toast.textContent = msg;

  hub.appendChild(toast);

  setTimeout(() => toast.classList.add('show'), 10);
  setTimeout(() => {
    toast.classList.remove('show');
    setTimeout(() => toast.remove(), 260);
  }, 3000);
}

window.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') closeQrModal();
});
