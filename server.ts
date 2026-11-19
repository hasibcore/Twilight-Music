import express from 'express';
import type { Request, Response } from 'express';
import cors from 'cors';
import path from 'path';
import fs from 'fs';
import os from 'os';
import { execFileSync } from 'child_process';
import { fileURLToPath } from 'url';
import ytdl from '@distube/ytdl-core';
import dns from 'node:dns';

dns.setDefaultResultOrder('ipv4first');

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const PORT = parseInt(process.env.TWILIGHT_PORT || '3000', 10);

app.use(cors());
app.use(express.json());

// Serve static native app downloads & audio streams
app.use('/landing', express.static(path.resolve(__dirname, 'landing')));
app.use('/downloads', express.static(path.resolve(__dirname, 'landing/downloads')));
app.use('/landing/downloads', express.static(path.resolve(__dirname, 'landing/downloads')));
app.use('/assets', express.static(path.resolve(__dirname, 'assets')));
app.use('/landing/assets', express.static(path.resolve(__dirname, 'landing/assets')));
app.use('/audio', express.static(path.resolve(__dirname, 'public/audio')));

// Explicit CSS and JS assets for public landing page
app.get(['/styles.css', '/landing/styles.css', '*/styles.css', '/download/styles.css'], (_req: Request, res: Response) => {
  res.setHeader('Content-Type', 'text/css; charset=utf-8');
  res.sendFile(path.resolve(__dirname, 'landing', 'styles.css'));
});

app.get(['/app.js', '/landing/app.js', '*/app.js', '/download/app.js'], (_req: Request, res: Response) => {
  res.setHeader('Content-Type', 'application/javascript; charset=utf-8');
  res.sendFile(path.resolve(__dirname, 'landing', 'app.js'));
});

// Direct Public Downloads & Landing Page Routes
app.get(['/download', '/download/', '/downloads-hub', '/site', '/site/', '/downloads-page'], (_req: Request, res: Response) => {
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.sendFile(path.resolve(__dirname, 'landing', 'index.html'));
});

// Resilient direct binary download fallback: if binary is not on disk, 302 redirect to official GitHub Release
app.get('/downloads/:filename', (req: Request, res: Response) => {
  const filename = req.params.filename;
  const localFile = path.resolve(__dirname, 'landing/downloads', filename);
  if (fs.existsSync(localFile)) {
    return res.download(localFile);
  }
  const GITHUB_DOWNLOADS: Record<string, string> = {
    'Twilight-Android-v3.6.1.apk': 'https://github.com/hasibcore/Twilight-Music/releases/download/v3.6.1/Twilight-Android-v3.6.1.apk',
    'app-release.apk': 'https://github.com/hasibcore/Twilight-Music/releases/download/v3.6.1/Twilight-Android-v3.6.1.apk',
    'Twilight-Android-v3.0.0.apk': 'https://github.com/hasibcore/Twilight-Music/releases/download/v3.6.1/Twilight-Android-v3.6.1.apk',
    'Twilight-Windows-x64.zip': 'https://github.com/hasibcore/Twilight-Music/releases/download/v3.6.1/Twilight-Windows-x64-v3.6.1.zip',
    'Twilight-Windows-x64-v3.6.1.zip': 'https://github.com/hasibcore/Twilight-Music/releases/download/v3.6.1/Twilight-Windows-x64-v3.6.1.zip',
    'Twilight-Windows-x64-v3.0.0.zip': 'https://github.com/hasibcore/Twilight-Music/releases/download/v3.6.1/Twilight-Windows-x64-v3.6.1.zip',
    'Twilight-iOS.ipa': 'https://github.com/hasibcore/Twilight-Music/releases/download/v3.6.1/Twilight-iOS-v3.6.1.ipa',
    'Twilight-iOS-v3.6.1.ipa': 'https://github.com/hasibcore/Twilight-Music/releases/download/v3.6.1/Twilight-iOS-v3.6.1.ipa',
    'Twilight-iOS-v3.0.0.ipa': 'https://github.com/hasibcore/Twilight-Music/releases/download/v3.6.1/Twilight-iOS-v3.6.1.ipa',
  };
  if (GITHUB_DOWNLOADS[filename]) {
    return res.redirect(302, GITHUB_DOWNLOADS[filename]);
  }
  return res.redirect(302, 'https://github.com/hasibcore/Twilight-Music/releases/latest');
});

// Predefined catalog for instant loading & resilience
const FALLBACK_POPULAR = [
  {
    id: 'fJ9rUzIMcZQ',
    title: 'Bohemian Rhapsody',
    artist: 'Queen',
    channelId: 'QueenOfficial',
    thumbnailUrl: 'https://i.ytimg.com/vi/fJ9rUzIMcZQ/hqdefault.jpg',
    durationSeconds: 355,
    durationFormatted: '05:55',
    viewCount: 1600000000,
  },
  {
    id: 'kJQP7kiw5Fk',
    title: 'Despacito',
    artist: 'Luis Fonsi ft. Daddy Yankee',
    channelId: 'LuisFonsiVEVO',
    thumbnailUrl: 'https://i.ytimg.com/vi/kJQP7kiw5Fk/hqdefault.jpg',
    durationSeconds: 282,
    durationFormatted: '04:42',
    viewCount: 8400000000,
  },
  {
    id: 'JGwWNGJdvx8',
    title: 'Shape of You',
    artist: 'Ed Sheeran',
    channelId: 'EdSheeran',
    thumbnailUrl: 'https://i.ytimg.com/vi/JGwWNGJdvx8/hqdefault.jpg',
    durationSeconds: 234,
    durationFormatted: '03:54',
    viewCount: 6200000000,
  },
  {
    id: '4NRXx6U8ABQ',
    title: 'Blinding Lights',
    artist: 'The Weeknd',
    channelId: 'TheWeekndVEVO',
    thumbnailUrl: 'https://i.ytimg.com/vi/4NRXx6U8ABQ/hqdefault.jpg',
    durationSeconds: 200,
    durationFormatted: '03:20',
    viewCount: 3000000000,
  },
  {
    id: 'hT_nvWreIhg',
    title: 'Counting Stars',
    artist: 'OneRepublic',
    channelId: 'OneRepublicVEVO',
    thumbnailUrl: 'https://i.ytimg.com/vi/hT_nvWreIhg/hqdefault.jpg',
    durationSeconds: 257,
    durationFormatted: '04:17',
    viewCount: 3900000000,
  },
  {
    id: '09R8_2nJtjg',
    title: 'Sugar',
    artist: 'Maroon 5',
    channelId: 'Maroon5VEVO',
    thumbnailUrl: 'https://i.ytimg.com/vi/09R8_2nJtjg/hqdefault.jpg',
    durationSeconds: 235,
    durationFormatted: '03:55',
    viewCount: 3900000000,
  },
];

const FALLBACK_BANGLA_BAND = [
  {
    id: 'XlNSOUfO-NA',
    title: 'Icche Ghuri',
    artist: 'Shironamhin',
    channelId: 'Shironamhin',
    thumbnailUrl: 'https://i.ytimg.com/vi/XlNSOUfO-NA/hqdefault.jpg',
    durationSeconds: 287,
    durationFormatted: '04:47',
    viewCount: 15000000,
  },
  {
    id: '8pgvTBikV9U',
    title: 'Obak Bhalobasha',
    artist: 'Warfaze',
    channelId: 'CokeStudioBangla',
    thumbnailUrl: 'https://i.ytimg.com/vi/8pgvTBikV9U/hqdefault.jpg',
    durationSeconds: 409,
    durationFormatted: '06:49',
    viewCount: 25000000,
  },
  {
    id: '60M4NlUuSD0',
    title: 'Hashimukh',
    artist: 'Shironamhin',
    channelId: 'Shironamhin',
    thumbnailUrl: 'https://i.ytimg.com/vi/60M4NlUuSD0/hqdefault.jpg',
    durationSeconds: 336,
    durationFormatted: '05:36',
    viewCount: 22000000,
  },
  {
    id: 'sFZPMjcsBoQ',
    title: 'Bondho Janala',
    artist: 'Shironamhin',
    channelId: 'Shironamhin',
    thumbnailUrl: 'https://i.ytimg.com/vi/sFZPMjcsBoQ/hqdefault.jpg',
    durationSeconds: 242,
    durationFormatted: '04:02',
    viewCount: 18000000,
  },
  {
    id: 'wsENMyoabFw',
    title: 'Omimangshito',
    artist: 'Mizan ft. Ahmed Razeeb',
    channelId: 'G Series Music',
    thumbnailUrl: 'https://i.ytimg.com/vi/wsENMyoabFw/hqdefault.jpg',
    durationSeconds: 235,
    durationFormatted: '03:55',
    viewCount: 4500000,
  },
  {
    id: 'GPJ6WxtUuBQ',
    title: 'Pakhi',
    artist: 'Shironamhin',
    channelId: 'Shironamhin',
    thumbnailUrl: 'https://i.ytimg.com/vi/GPJ6WxtUuBQ/hqdefault.jpg',
    durationSeconds: 256,
    durationFormatted: '04:16',
    viewCount: 12000000,
  },
  {
    id: 'l9o3eOf0AJ0',
    title: 'Cafetaria',
    artist: 'Shironamhin',
    channelId: 'Shironamhin',
    thumbnailUrl: 'https://i.ytimg.com/vi/l9o3eOf0AJ0/hqdefault.jpg',
    durationSeconds: 259,
    durationFormatted: '04:19',
    viewCount: 10000000,
  },
  {
    id: 'js_3-s2hqsd',
    title: 'Anmone',
    artist: 'Artcell',
    channelId: 'Artcell',
    thumbnailUrl: 'https://c.saavncdn.com/385/Neel-Bhalobasha-Bengali-2025-20250109100903-500x500.jpg',
    durationSeconds: 307,
    durationFormatted: '05:07',
    viewCount: 9000000,
  },
  {
    id: 'js_fOuybpG_',
    title: 'Oniket Prantor',
    artist: 'Artcell',
    channelId: 'Artcell',
    thumbnailUrl: 'https://c.saavncdn.com/865/Aniket-Prantor-Bengali-2006-20230316051320-500x500.jpg',
    durationSeconds: 980,
    durationFormatted: '16:20',
    viewCount: 14000000,
  },
  {
    id: 's8Qk0eMxsLA',
    title: 'Dhushor Shomoy',
    artist: 'Artcell',
    channelId: 'Artcell',
    thumbnailUrl: 'https://i.ytimg.com/vi/s8Qk0eMxsLA/hqdefault.jpg',
    durationSeconds: 407,
    durationFormatted: '06:47',
    viewCount: 7500000,
  },
];

const FALLBACK_HINDI = [
  {
    id: 'BddP6PYo2gs',
    title: 'Kesariya',
    artist: 'Arijit Singh, Pritam',
    channelId: 'SonyMusicIndia',
    thumbnailUrl: 'https://i.ytimg.com/vi/BddP6PYo2gs/hqdefault.jpg',
    durationSeconds: 268,
    durationFormatted: '04:28',
    viewCount: 500000000,
  },
  {
    id: 'IJq0cfTOvd8',
    title: 'Tum Hi Ho',
    artist: 'Arijit Singh',
    channelId: 'TSeries',
    thumbnailUrl: 'https://i.ytimg.com/vi/IJq0cfTOvd8/hqdefault.jpg',
    durationSeconds: 262,
    durationFormatted: '04:22',
    viewCount: 800000000,
  },
  {
    id: '284VoJ-4G_8',
    title: 'Channa Mereya',
    artist: 'Arijit Singh',
    channelId: 'SonyMusicIndia',
    thumbnailUrl: 'https://i.ytimg.com/vi/284VoJ-4G_8/hqdefault.jpg',
    durationSeconds: 289,
    durationFormatted: '04:49',
    viewCount: 600000000,
  },
  {
    id: 'gvyUuxdRdR4',
    title: 'Raataan Lambiyan',
    artist: 'Jubin Nautiyal, Asees Kaur',
    channelId: 'SonyMusicIndia',
    thumbnailUrl: 'https://i.ytimg.com/vi/gvyUuxdRdR4/hqdefault.jpg',
    durationSeconds: 230,
    durationFormatted: '03:50',
    viewCount: 750000000,
  },
];

// Cache canonical song metadata (title, artist, durationSeconds) by videoId for exact-track resolution
const songMetaCache = new Map<string, { title: string; artist: string; durationSeconds?: number }>();
for (const s of [...FALLBACK_POPULAR, ...FALLBACK_BANGLA_BAND, ...FALLBACK_HINDI]) {
  songMetaCache.set(s.id, { title: s.title, artist: s.artist, durationSeconds: s.durationSeconds });
}

interface ResolvedStreamEntry {
  url: string;
  mimeType: string;
  buffer?: Buffer;
  headers?: Record<string, string>;
  resolvedAt: number;
}

// Cache resolved direct CDN stream URLs or assembled fMP4 buffers by videoId (10-minute TTL)
const resolvedStreamCache = new Map<string, ResolvedStreamEntry>();
const inFlightStreamResolutions = new Map<string, Promise<ResolvedStreamEntry | null>>();
const STREAM_CACHE_TTL_MS = 10 * 60 * 1000;

const RETRYABLE_HTTP_STATUSES = new Set([408, 425, 429, 500, 502, 503, 504]);

interface ServerStreamDiagnostic {
  timestamp: string;
  level: 'info' | 'warn' | 'error';
  category: string;
  stage: string;
  message: string;
  videoId?: string;
  statusCode?: number;
  attempt?: number;
  bytesSent?: number;
  detail?: string;
}

const MAX_STREAM_DIAGNOSTICS = 200;
const streamDiagnosticsBuffer: ServerStreamDiagnostic[] = [];

function logStreamDiagnostic(
  level: 'info' | 'warn' | 'error',
  category: string,
  stage: string,
  message: string,
  meta: Omit<ServerStreamDiagnostic, 'timestamp' | 'level' | 'category' | 'stage' | 'message'> = {}
): ServerStreamDiagnostic {
  const entry: ServerStreamDiagnostic = {
    timestamp: new Date().toISOString(),
    level,
    category,
    stage,
    message,
    ...meta,
  };
  streamDiagnosticsBuffer.push(entry);
  if (streamDiagnosticsBuffer.length > MAX_STREAM_DIAGNOSTICS) {
    streamDiagnosticsBuffer.shift();
  }
  const tag = `[Twilight STREAM][${level.toUpperCase()}][${category}][${stage}]`;
  const parts: string[] = [];
  if (entry.videoId) parts.push(`id=${entry.videoId}`);
  if (typeof entry.statusCode === 'number') parts.push(`status=${entry.statusCode}`);
  if (typeof entry.attempt === 'number') parts.push(`attempt=${entry.attempt}`);
  if (typeof entry.bytesSent === 'number') parts.push(`bytes=${entry.bytesSent}`);
  const line = `${tag} ${message}${parts.length ? ` (${parts.join(', ')})` : ''}`;
  if (level === 'error' || level === 'warn') console.info(line, entry.detail || '');
  return entry;
}

function safeUrlLabel(rawUrl: string): string {
  try {
    const parsed = new URL(rawUrl);
    return `${parsed.hostname}${parsed.pathname}`;
  } catch {
    return rawUrl.split('?')[0].slice(0, 80);
  }
}

interface FetchRetryOptions {
  retries?: number;
  timeoutMs?: number;
  baseDelayMs?: number;
  signal?: AbortSignal;
}

async function fetchWithRetry(
  url: string,
  init: RequestInit = {},
  options: FetchRetryOptions = {}
): Promise<globalThis.Response> {
  const retries = options.retries ?? 2;
  const timeoutMs = options.timeoutMs ?? 4000;
  const baseDelayMs = options.baseDelayMs ?? 220;
  const externalSignal = options.signal;
  const label = safeUrlLabel(url);

  let lastError: unknown;
  for (let attempt = 0; attempt <= retries; attempt++) {
    if (externalSignal?.aborted) {
      throw externalSignal.reason || new DOMException('Aborted', 'AbortError');
    }

    const connectAbortController = new AbortController();
    let connectTimer: ReturnType<typeof setTimeout> | null = setTimeout(() => {
      connectAbortController.abort(new DOMException('Connection timeout', 'TimeoutError'));
    }, timeoutMs);

    const onExternalAbort = () => {
      connectAbortController.abort(externalSignal?.reason);
    };
    if (externalSignal) {
      externalSignal.addEventListener('abort', onExternalAbort, { once: true });
    }

    try {
      const res = await fetch(url, { ...init, signal: connectAbortController.signal });
      if (connectTimer) {
        clearTimeout(connectTimer);
        connectTimer = null;
      }
      if (externalSignal) {
        externalSignal.removeEventListener('abort', onExternalAbort);
      }

      if (!RETRYABLE_HTTP_STATUSES.has(res.status) || attempt === retries) {
        if (RETRYABLE_HTTP_STATUSES.has(res.status) && attempt === retries) {
          logStreamDiagnostic('warn', 'retry_exhausted', 'fetchWithRetry', `Upstream ${label} returned retryable status`, {
            statusCode: res.status,
            attempt: attempt + 1,
          });
        }
        return res;
      }

      const retryAfterRaw = res.headers.get('retry-after');
      try {
        await res.body?.cancel();
      } catch {}

      let delayMs = Math.min(2500, baseDelayMs * Math.pow(2, attempt) + Math.floor(Math.random() * 120));
      if (retryAfterRaw) {
        const parsedSec = Number(retryAfterRaw);
        if (!Number.isNaN(parsedSec) && parsedSec > 0) {
          delayMs = Math.min(2500, Math.round(parsedSec * 1000));
        }
      }
      logStreamDiagnostic('warn', 'upstream_retry', 'fetchWithRetry', `Retrying ${label} after HTTP ${res.status}`, {
        statusCode: res.status,
        attempt: attempt + 1,
        detail: `delay=${delayMs}ms`,
      });
      await new Promise((resolve) => setTimeout(resolve, delayMs));
    } catch (err: any) {
      if (connectTimer) {
        clearTimeout(connectTimer);
        connectTimer = null;
      }
      if (externalSignal) {
        externalSignal.removeEventListener('abort', onExternalAbort);
      }
      lastError = err;
      if (externalSignal?.aborted || attempt === retries) {
        if (!externalSignal?.aborted) {
          logStreamDiagnostic('warn', 'network_disconnect', 'fetchWithRetry', `Upstream ${label} disconnected`, {
            attempt: attempt + 1,
            detail: err?.name ? `${err.name}: ${err.message || ''}` : String(err),
          });
        }
        throw err;
      }
      const delayMs = Math.min(2500, baseDelayMs * Math.pow(2, attempt) + Math.floor(Math.random() * 120));
      logStreamDiagnostic('warn', 'network_disconnect', 'fetchWithRetry', `Retrying ${label} after connection drop`, {
        attempt: attempt + 1,
        detail: `${err?.name || 'Error'}: ${err?.message || ''} (delay=${delayMs}ms)`,
      });
      await new Promise((resolve) => setTimeout(resolve, delayMs));
    }
  }

  throw lastError instanceof Error ? lastError : new Error('Upstream fetch failed after retries');
}

let cachedSoundCloudClientId = '39AVoiZVrdvJEMFLH8T0c5WGshQaAPRJ';
let lastScClientIdCheck = 0;

async function getSoundCloudClientId(forceRefresh = false): Promise<string> {
  if (!forceRefresh && cachedSoundCloudClientId && Date.now() - lastScClientIdCheck < 30 * 60 * 1000) {
    return cachedSoundCloudClientId;
  }
  try {
    const homeRes = await fetchWithRetry(
      'https://soundcloud.com',
      { headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' } },
      { retries: 1, timeoutMs: 2500 }
    );
    const homeHtml = await homeRes.text();
    const scriptMatches = Array.from(
      homeHtml.matchAll(/src="(https:\/\/a-v2\.sndcdn\.com\/assets\/[^"]+\.js)"/g)
    ).map((m) => m[1]);
    for (const scriptUrl of scriptMatches.slice(-3)) {
      const jsRes = await fetchWithRetry(scriptUrl, {}, { retries: 1, timeoutMs: 2500 });
      const js = await jsRes.text();
      const m = js.match(/client_id\s*:\s*"([a-zA-Z0-9]{32})"/);
      if (m && m[1]) {
        cachedSoundCloudClientId = m[1];
        lastScClientIdCheck = Date.now();
        return cachedSoundCloudClientId;
      }
    }
  } catch {
    // use fallback client_id
  }
  lastScClientIdCheck = Date.now();
  return cachedSoundCloudClientId;
}

function decodeHtmlEntitiesServer(str: string): string {
  return (str || '')
    .replace(/&quot;/gi, '"')
    .replace(/&#0*39;|&apos;/gi, "'")
    .replace(/&amp;/gi, '&')
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>');
}

const METADATA_SEGMENT_REGEX =
  /^(?:#.*|coke\s+studio(?:\s+bangla|\s+india|\s+pakistan|\s+global|\s+tamil|\s+bharat)?|season\s*\d+|episode\s*\d+|ep\s*\.?\s*\d+|s\d+\s*e\d+|official.*|lyric(?:al)?.*|full\s+(?:song|video|audio|album).*|audio\s+song.*|video\s+song.*|music\s+video.*|original\s+(?:track|song|audio|video).*|art\s+track.*|official\s+art\s+track.*|audio\s+track.*|track\s+\d+.*|visualizer.*|.*anniversary\s+concert.*|.*live\s+concert.*|rabindra\s+sangeet.*|tagore\s+song.*|nazrul\s+geeti.*|bangla\s+(?:new\s+song|latest\s+song|gaan|song|music|band|lofi|natok).*|new\s+(?:bangla|bengali|hindi|punjabi)?\s*song.*|hd|4k|hq|remaster(?:ed)?|live(?:\s+performance|\s+session|\s+in\s+concert)?|unplugged|mtv\s+unplugged.*|t-series.*|sony\s+music.*|zee\s+music.*|svf.*|sangeet\s+bangla.*|soundtek.*|laser\s+vision.*|cd\s+choice.*|eagle\s+music.*|gaanchill.*|bhavna\s+records.*|g-series.*|g\s+series.*|agniveena.*|saregama.*|times\s+music.*|tips\s+official.*|yrf.*|speed\s+records.*|satv\s+music.*)$/i;

const CORE_TITLE_STOP_WORDS = new Set([
  'the', 'and', 'for', 'with', 'from', 'feat', 'ft', 'of', 'in', 'on', 'to', 'at', 'by', 'is', 'it', 'my', 'me',
  'official', 'music', 'video', 'audio', 'song', 'songs', 'full', 'lyric', 'lyrics', 'lyrical',
  'hd', '4k', 'hq', 'live', 'session', 'studio', 'coke', 'bangla', 'bengali', 'hindi', 'english',
  'season', 'episode', 'version', 'unplugged', 'rabindra', 'sangeet', 'tagore', 'records', 'creations',
  'track', 'original', 'remastered', 'remaster', 'concert', 'anniversary', 'album', 'movie', 'film',
  'ost', 'soundtrack', 'title', 'theme', 'natok', 'drama', 'telefilm', 'new', 'hit', 'hits', 'single',
]);

function normalizePhoneticToken(str: string): string {
  return (str || '')
    .toLowerCase()
    .replace(/bh/g, 'v')
    .replace(/sh/g, 's')
    .replace(/ph/g, 'f')
    .replace(/kh/g, 'k')
    .replace(/gh/g, 'g')
    .replace(/chh/g, 'ch')
    .replace(/aa/g, 'a')
    .replace(/ee/g, 'i')
    .replace(/oo/g, 'u')
    .replace(/ou/g, 'o');
}

function tokenMatchesText(token: string, text: string): boolean {
  if (!token || !text) return false;
  const tLower = token.toLowerCase();
  const textLower = text.toLowerCase();
  if (textLower.includes(tLower)) return true;
  const pToken = normalizePhoneticToken(tLower);
  const pText = normalizePhoneticToken(textLower);
  return pToken.length >= 2 && pText.includes(pToken);
}

function stripParentheticalAndEntities(raw: string): string {
  return decodeHtmlEntitiesServer(raw || '')
    .replace(/\([^)]*\)/g, ' ')
    .replace(/\[[^\]]*\]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function hasForeignSongTitleWords(
  candTitle: string,
  coreTokens: string[],
  artistTokens: string[],
  extraAllowedText = ''
): boolean {
  if (!candTitle || coreTokens.length === 0) return false;
  const baseCand = stripParentheticalAndEntities(candTitle).toLowerCase();

  // If the candidate title uses "Artist - Song" or "Song - Artist/Album", check if one side is the artist
  // and the other side is a clean match for coreTokens. Meanwhile, if a hyphenated title has a different
  // song on the other side (e.g. "Valobashar Magh Shironamhin -Bondho janala"), reject it!
  const extraTokens = stripParentheticalAndEntities(extraAllowedText)
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, ' ')
    .split(/\s+/)
    .filter((w) => w.length >= 2);

  const candWords = baseCand
    .replace(/[^a-z0-9\s]/g, ' ')
    .split(/\s+/)
    .filter((w) => w.length >= 2 && !/^\d+$/.test(w));

  for (const w of candWords) {
    if (CORE_TITLE_STOP_WORDS.has(w)) continue;
    const matchesCore = coreTokens.some((ct) => tokenMatchesText(ct, w) || tokenMatchesText(w, ct));
    if (matchesCore) continue;
    const matchesArtist = artistTokens.some(
      (at) => tokenMatchesText(at, w) || tokenMatchesText(w, at)
    );
    if (matchesArtist) continue;
    const matchesExtra = extraTokens.some(
      (et) => tokenMatchesText(et, w) || tokenMatchesText(w, et)
    );
    if (matchesExtra) continue;
    // Found an unrelated song title word (e.g., "valobashar" or "magh" or short foreign syllable like "na"/"re")
    return true;
  }
  return false;
}

function getCoreTitleTokens(coreTitle: string): string[] {
  const allTokens = stripParentheticalAndEntities(coreTitle || '')
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, ' ')
    .split(/\s+/)
    .filter((t) => t.length >= 2);
  const filtered = allTokens.filter((t) => !CORE_TITLE_STOP_WORDS.has(t));
  return filtered.length > 0 ? filtered : allTokens;
}

function cleanTrackQueryText(input: string): string {
  return decodeHtmlEntitiesServer(input || '')
    .replace(/#\S+/g, ' ')
    .replace(/\(\s*[^\x00-\x7F]+\s*\)/g, ' ')
    .replace(/\[\s*[^\x00-\x7F]+\s*\]/g, ' ')
    .replace(
      /\([^)]*(?:official|video|audio|lyric|lyrics|visualizer|hd|4k|hq|remaster|live|mv|full\s+song|coke\s+studio|season\s*\d+|from\s+|feat\.?\s+|ft\.?\s+|original\s+motion|soundtrack|ost|film|movie|natok|drama|telefilm)[^)]*\)/gi,
      ' '
    )
    .replace(/\([^a-zA-Z0-9]*\)/g, ' ')
    .replace(
      /\[[^\]]*(?:official|video|audio|lyric|lyrics|visualizer|hd|4k|hq|remaster|live|mv|full\s+song|coke\s+studio|season\s*\d+|from\s+|feat\.?\s+|ft\.?\s+|original\s+motion|soundtrack|ost|film|movie|natok|drama|telefilm)[^\]]*\]/gi,
      ' '
    )
    .replace(/\[[^a-zA-Z0-9]*\]/g, ' ')
    .replace(
      /\b(?:official\s+music\s+video|official\s+video|official\s+audio|lyric(?:al)?\s+video|full\s+video|full\s+audio|full\s+song|4k\s+remaster|audio\s+song|video\s+song|original\s+track)\b/gi,
      ' '
    )
    .replace(/\s*[-|â€¢Â·]\s*(?:official|topic|vevo).*$/gi, ' ')
    .replace(/\b(?:VEVO|Topic)\b/gi, ' ')
    .replace(/[|â€¢Â·"â€œâ€â€˜â€™]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

export function extractCoreTrackAndArtist(
  rawTitle: string,
  rawArtist?: string
): { coreTitle: string; primaryArtist: string; secondaryArtist: string } {
  const cleanedChannelArtist = cleanTrackQueryText(rawArtist || '')
    .replace(
      /\b(?:sony\s+music(?:\s+india|\s+south|\s+east)?|sony\s+india|zeee?\s+music(?:\s+company|\s+bangla)?|t-series(?:\s+bangla|\s+regional)?|saregama(?:\s+bengali|\s+music|\s+india)?|maddock\s+films|anupam\s+movie\s+songs|dhruba\s+music(?:\s+station)?|red\s+flag\s+gamer|eagle\s+music|cd\s+choice|coke\s+studio(?:\s+bangla|\s+india|\s+pakistan)?|svf(?:\s+music)?|sangeet\s+bangla|soundtek|laser\s+vision|gaanchill(?:\s+music)?|bhavna\s+records|yrf|tips\s+official|speed\s+records|times\s+music|agniveena|g-series|g\s+series|satv(?:\s+music)?)\b/gi,
      ' '
    )
    .replace(/(?:theband|official|vevo|topic|music|records|channel|band|world\s+music)$/i, ' ')
    .replace(/\b(?:official|vevo|topic|music|records|channel|various\s+artists|world|satv|g\s+series)\b/gi, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  const isChannelGenericOrShow =
    !cleanedChannelArtist || METADATA_SEGMENT_REGEX.test(cleanedChannelArtist);

  const rawSegments = decodeHtmlEntitiesServer(String(rawTitle || ''))
    .split(/(?:\s*\|\|\s*|\s*[|â€¢Â·]\s*|\s+\/\/\s+)/)
    .map((s) => cleanTrackQueryText(s))
    .filter(Boolean);

  const meaningfulSegments = rawSegments.filter((s) => !METADATA_SEGMENT_REGEX.test(s));
  const candidateSegments =
    meaningfulSegments.length > 0 ? meaningfulSegments : [cleanTrackQueryText(rawTitle)];

  const compactChannel = cleanedChannelArtist.toLowerCase().replace(/[^a-z0-9]/g, '');

  const latinSegments = candidateSegments.filter((s) => /[a-zA-Z]/.test(s));
  // Never pick a segment that is identical to the channel/artist name as coreTitle if another Latin segment exists
  const nonArtistLatinSegments = latinSegments.filter((s) => {
    const segCompact = s.toLowerCase().replace(/[^a-z0-9]/g, '');
    if (!compactChannel || !segCompact) return true;
    return segCompact !== compactChannel;
  });

  // If the leading segment is non-Latin script (e.g., Bengali/Hindi title "à¦†à¦®à¦¿ à¦¤à§‹à¦®à¦¾à¦•à§‡ | Artist Name"),
  // do NOT promote a lone trailing Latin artist/channel segment into coreTitle.
  const firstSegment = candidateSegments[0] || '';
  const firstSegHasLatin = /[a-zA-Z]/.test(firstSegment);
  const useNonLatinFirstSegment =
    Boolean(firstSegment) &&
    !firstSegHasLatin &&
    (nonArtistLatinSegments.length === 0 || (latinSegments.length === 1 && candidateSegments.length >= 2));

  const primarySeg = useNonLatinFirstSegment
    ? firstSegment
    : nonArtistLatinSegments[0] || latinSegments[0] || candidateSegments[0] || '';

  let coreTitle = primarySeg;
  let extractedArtist = '';

  // If one of the segments matched the channel artist, record it
  const matchedArtistSeg = latinSegments.find((s) => {
    const segCompact = s.toLowerCase().replace(/[^a-z0-9]/g, '');
    return compactChannel && segCompact === compactChannel;
  });
  if (matchedArtistSeg && matchedArtistSeg !== primarySeg) {
    extractedArtist = matchedArtistSeg;
  }

  let featArtist = '';
  const featMatch = rawTitle.match(/[\(\[](?:feat\.?|ft\.?)\s+([^\)\]]+)[\)\]]/i);
  if (featMatch) {
    featArtist = featMatch[1].trim();
  }

  let cleanedPrimarySeg = primarySeg
    .replace(/[\(\[](?:feat\.?|ft\.?)\s+([^\)\]]+)[\)\]]/gi, '')
    .replace(/[\(\[][^\)\]]*(?:lyrics?|lyrical|video|audio|version|master|24bits|48khz|art\s+track|official|hd|4k)[^\)\]]*[\)\]]/gi, '')
    .replace(/\s+-\s+(?:single|ep|album|remastered|remaster|official|audio|video|lyrics?)\b/gi, '')
    .replace(/\s+/g, ' ')
    .trim();

  if (cleanedPrimarySeg.includes('-') || cleanedPrimarySeg.includes('â€“') || cleanedPrimarySeg.includes('â€”')) {
    const rawHyphenParts = cleanedPrimarySeg
      .split(/\s*[-â€“â€”]\s*/)
      .map((p) => p.trim())
      .filter(Boolean);
    const hyphenParts = rawHyphenParts.filter((p, idx) => {
      if (idx === 0) return true;
      return !/^(?:single|ep|album|lyrics?|lyrical(?:\s+video)?|official(?:\s+(?:audio|video|track))?|art\s+track|audio|video|4k|hd|24bits.*)$/i.test(p.trim());
    });
    if (hyphenParts.length === 2) {
      const [left, right] = hyphenParts;
      const leftCompact = left.toLowerCase().replace(/[^a-z0-9]/g, '');
      const rightCompact = right.toLowerCase().replace(/[^a-z0-9]/g, '');

      if (
        compactChannel &&
        leftCompact &&
        (leftCompact === compactChannel ||
          compactChannel.includes(leftCompact) ||
          leftCompact.includes(compactChannel))
      ) {
        coreTitle = right;
        extractedArtist = left;
      } else if (
        compactChannel &&
        rightCompact &&
        (rightCompact === compactChannel ||
          compactChannel.includes(rightCompact) ||
          rightCompact.includes(compactChannel))
      ) {
        coreTitle = left;
        extractedArtist = right;
      } else if (/\s+[-â€“â€”]\s+/.test(cleanedPrimarySeg)) {
        const isTrailingVersionDescriptor =
          /^(?:female(?:\s+version)?|male(?:\s+version)?|sad(?:\s+version)?|unplugged|acoustic|reprise|remix|lofi|lo-fi|slowed(?:\s*(?:&|\+|and|n)\s*reverb)?|reverb|extended|duet(?:\s+version)?|title\s+track|version|instrumental|from\s+.+)$/i.test(
            right
          );
        if (METADATA_SEGMENT_REGEX.test(right) || rawSegments.length >= 3 || isTrailingVersionDescriptor) {
          // Multi-pipe or suffix descriptor format: "Song - Female" or "Song - Movie | Cast | Singer"
          coreTitle = left;
        } else {
          coreTitle = right;
          extractedArtist = left;
        }
      }
    }
  }

  const otherLatinSegments = latinSegments.filter(
    (s) => s !== primarySeg && !METADATA_SEGMENT_REGEX.test(s)
  );
  if (!extractedArtist && otherLatinSegments.length > 0) {
    // In YouTube multi-segment titles (Title | Bengali Script | Artist | Label/Album),
    // the first segment following the title is the actual artist (e.g. "Ahmed Razeeb Feat. Mizan")
    extractedArtist = otherLatinSegments[0];
  }

  // Prefer human-spaced extractedArtist (e.g. "LEVEL FIVE", "Shironamhin", "Mizan") when channel is generic,
  // a glued handle, or an unrelated third-party uploader/fan channel
  const preferExtracted =
    Boolean(extractedArtist) &&
    (isChannelGenericOrShow ||
      (!cleanedChannelArtist.includes(' ') && extractedArtist.includes(' ')) ||
      compactChannel === extractedArtist.toLowerCase().replace(/[^a-z0-9]/g, '') ||
      Boolean(extractedArtist && !compactChannel.includes(extractedArtist.toLowerCase().replace(/[^a-z0-9]/g, ''))));

  const primaryArtist = preferExtracted
    ? extractedArtist || cleanedChannelArtist
    : cleanedChannelArtist || extractedArtist;
  const baseSecondary =
    primaryArtist === extractedArtist ? cleanedChannelArtist : extractedArtist;
  const tailArtists =
    rawSegments.length >= 3 && otherLatinSegments.length > 1
      ? otherLatinSegments.slice(-2).join(' ')
      : '';
  let secondaryArtist =
    tailArtists && !primaryArtist.toLowerCase().includes(tailArtists.toLowerCase())
      ? `${baseSecondary} ${tailArtists}`.trim()
      : baseSecondary;
  if (featArtist && !primaryArtist.toLowerCase().includes(featArtist.toLowerCase()) && !secondaryArtist.toLowerCase().includes(featArtist.toLowerCase())) {
    secondaryArtist = `${secondaryArtist} ${featArtist}`.trim();
  }

  const finalCoreTitle = stripParentheticalAndEntities(coreTitle.trim() || cleanTrackQueryText(rawTitle));

  return {
    coreTitle: finalCoreTitle || coreTitle.trim() || cleanTrackQueryText(rawTitle),
    primaryArtist: primaryArtist.trim(),
    secondaryArtist: secondaryArtist.trim(),
  };
}

async function resolveCanonicalSongMeta(
  videoId: string,
  rawTitle?: string,
  rawArtist?: string,
  rawDurationSec?: number
): Promise<{
  title: string;
  artist: string;
  secondaryArtist: string;
  rawTitle: string;
  rawArtist: string;
  durationSeconds: number;
}> {
  const cleanId = (videoId || '').trim();
  const cached = songMetaCache.get(cleanId);
  const resolvedDuration =
    (rawDurationSec && rawDurationSec > 0 ? rawDurationSec : cached?.durationSeconds) || 0;

  if (rawTitle && rawTitle.trim().length > 0) {
    const { coreTitle, primaryArtist, secondaryArtist } = extractCoreTrackAndArtist(
      rawTitle,
      rawArtist
    );
    if (cleanId) {
      songMetaCache.set(cleanId, {
        title: rawTitle,
        artist: rawArtist || primaryArtist,
        durationSeconds: resolvedDuration || cached?.durationSeconds,
      });
    }
    return {
      title: coreTitle,
      artist: primaryArtist,
      secondaryArtist,
      rawTitle,
      rawArtist: rawArtist || '',
      durationSeconds: resolvedDuration,
    };
  }

  if (cached && cached.title) {
    const { coreTitle, primaryArtist, secondaryArtist } = extractCoreTrackAndArtist(
      cached.title,
      cached.artist
    );
    return {
      title: coreTitle,
      artist: primaryArtist,
      secondaryArtist,
      rawTitle: cached.title,
      rawArtist: cached.artist,
      durationSeconds: resolvedDuration,
    };
  }

  if (cleanId.length === 11 && !cleanId.startsWith('custom_')) {
    try {
      const oembedUrl = `https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=${encodeURIComponent(
        cleanId
      )}&format=json`;
      const res = await fetchWithRetry(oembedUrl, {}, { retries: 1, timeoutMs: 2200 });
      if (res.ok) {
        const data: any = await res.json();
        const oembedTitle = String(data?.title || '');
        const oembedAuthor = String(data?.author_name || '');
        const { coreTitle, primaryArtist, secondaryArtist } = extractCoreTrackAndArtist(
          oembedTitle,
          oembedAuthor
        );
        if (coreTitle) {
          songMetaCache.set(cleanId, {
            title: oembedTitle,
            artist: oembedAuthor || primaryArtist,
            durationSeconds: resolvedDuration,
          });
          return {
            title: coreTitle,
            artist: primaryArtist,
            secondaryArtist,
            rawTitle: oembedTitle,
            rawArtist: oembedAuthor,
            durationSeconds: resolvedDuration,
          };
        }
      }
    } catch {
      // ignore oembed timeout
    }
  }

  return {
    title: '',
    artist: '',
    secondaryArtist: '',
    rawTitle: rawTitle || '',
    rawArtist: rawArtist || '',
    durationSeconds: resolvedDuration,
  };
}

const knownDirectCdnMap: Record<string, string> = {
  '8pgvTBikV9U': 'https://aac.saavncdn.com/744/89e8ba380132d45e474dd3b49779f20a_320.mp4',
  '8iuZrJumCLo': 'https://aac.saavncdn.com/296/ab693f16b6e4708e6fe9763c3fe20329_320.mp4',
  rEGYM2DarbQ: 'https://aac.saavncdn.com/649/d43613a52a0b2f0331a84e2ff9bb65ba_320.mp4',
  fJ9rUzIMcZQ: 'https://aac.saavncdn.com/806/442b9d1e36a4bcef050a32de50a82316_320.mp4',
  JirEG9LIJTU: 'https://aac.saavncdn.com/000/8a81a552431793831c58e09f3d7fde01_320.mp4',
  sFZPMjcsBoQ: 'https://aac.saavncdn.com/000/8a81a552431793831c58e09f3d7fde01_320.mp4',
  'XlNSOUfO-NA': 'https://aac.saavncdn.com/720/0d0bec146254bfcd0c8d61a72d784bd9_320.mp4',
  hLb5UPeROkc: 'https://aac.saavncdn.com/720/0d0bec146254bfcd0c8d61a72d784bd9_320.mp4',
  js_lDF3u96b: 'https://aac.saavncdn.com/720/0d0bec146254bfcd0c8d61a72d784bd9_320.mp4',
  '60M4NlUuSD0': 'https://aac.saavncdn.com/260/f0d33fd85842ea3360c137c890849e76_320.mp4',
  GPJ6WxtUuBQ: 'https://aac.saavncdn.com/720/7427d48dd875e1346f5469b76808f0a9_320.mp4',
  js_ssDY7xnd: 'https://aac.saavncdn.com/720/7427d48dd875e1346f5469b76808f0a9_320.mp4',
  l9o3eOf0AJ0: 'https://aac.saavncdn.com/720/cedb3c7eadacffc6d9f9207ab880c887_320.mp4',
  js_meprHaFX: 'https://aac.saavncdn.com/720/cedb3c7eadacffc6d9f9207ab880c887_320.mp4',
  'js_3-s2hqsd': 'https://aac.saavncdn.com/385/081d326c688c1476cbf2d0c240e71890_320.mp4',
  js_fOuybpG_: 'https://aac.saavncdn.com/865/7e7b53bcbf1e22f821e8ff27d666be5b_320.mp4',
  pUUZuINHba0: 'https://aac.saavncdn.com/865/7e7b53bcbf1e22f821e8ff27d666be5b_320.mp4',
  js_BQme9DJF: 'https://aac.saavncdn.com/865/f3d8c00186344c17e7b7b4d98995303f_320.mp4',
  s8Qk0eMxsLA: 'https://aac.saavncdn.com/865/f3d8c00186344c17e7b7b4d98995303f_320.mp4',
  wsENMyoabFw: 'https://aac.saavncdn.com/476/99042b8f14da26038f9bdddfe94b81db_320.mp4',
  sIkPfQKODGg: 'https://aac.saavncdn.com/476/99042b8f14da26038f9bdddfe94b81db_320.mp4',
  '51SvVPPwTFI': 'https://aac.saavncdn.com/476/99042b8f14da26038f9bdddfe94b81db_320.mp4',
  wltb62pGT10: 'https://aac.saavncdn.com/476/99042b8f14da26038f9bdddfe94b81db_320.mp4',
  js_1Xfub2IJ: 'https://aac.saavncdn.com/476/99042b8f14da26038f9bdddfe94b81db_320.mp4',
};

async function resolveExactTrackStreamUrl(
  videoId: string,
  rawTitle?: string,
  rawArtist?: string,
  forceRefresh = false,
  targetDurationSec?: number
): Promise<ResolvedStreamEntry | null> {
  const cleanId = (videoId || '').trim();
  const meta = await resolveCanonicalSongMeta(cleanId, rawTitle, rawArtist, targetDurationSec);
  const { title, artist, secondaryArtist, durationSeconds } = meta;
  const effectiveDuration = targetDurationSec && targetDurationSec > 0 ? targetDurationSec : durationSeconds;
  const cacheKey = cleanId
    ? `${cleanId}::${title.toLowerCase()}::${artist.toLowerCase()}::${effectiveDuration}`
    : '';

  if (forceRefresh && cleanId) {
    for (const key of resolvedStreamCache.keys()) {
      if (key.startsWith(`${cleanId}::`)) {
        resolvedStreamCache.delete(key);
      }
    }
  }

  if (!forceRefresh && cacheKey) {
    const cached = resolvedStreamCache.get(cacheKey);
    if (cached && Date.now() - cached.resolvedAt < STREAM_CACHE_TTL_MS) {
      return cached;
    }
    const pending = inFlightStreamResolutions.get(cacheKey);
    if (pending) {
      return pending;
    }
  }

  const runResolution = async (): Promise<ResolvedStreamEntry | null> => {

  const coreTokens = getCoreTitleTokens(title);
  const normCoreTitle = stripParentheticalAndEntities(title)
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  const combinedArtistText = `${artist} ${secondaryArtist}`
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  const artistTokens = Array.from(
    new Set(
      combinedArtistText
        .split(/\s+/)
        .filter((t) => t.length >= 3 && !CORE_TITLE_STOP_WORDS.has(t))
    )
  );
  const rawContextLower = `${meta.rawTitle} ${meta.rawArtist}`.toLowerCase();
  const wantsCokeStudio = rawContextLower.includes('coke studio') || cleanId === '8pgvTBikV9U';
  const wantsLofiOrRemix = /\b(?:lofi|lo-fi|remix|mashup|slowed|reverb|cover|unplugged|acoustic|piano|guitar|fingerstyle|instrumental|karaoke|tribute|parody|bgm)\b/.test(
    rawContextLower
  );

  // Tier 0: Verified Full-Length Studio & Direct 320kbps AAC Masters (0ms resolution, zero 30s previews, zero remixes)
  const isObak =
    normCoreTitle.includes('obak bhalobasha') ||
    normCoreTitle.includes('obak valobasha') ||
    rawContextLower.includes('obak bhalobasha') ||
    rawContextLower.includes('obak valobasha');
  const isWarfaze = combinedArtistText.includes('warfaze') || rawContextLower.includes('warfaze');

  if (cleanId && /^[a-zA-Z0-9_-]{8,15}$/.test(cleanId)) {
    const localM4a = path.resolve(__dirname, 'public/audio', `${cleanId}.m4a`);
    if (fs.existsSync(localM4a)) {
      const resolved: ResolvedStreamEntry = {
        url: `/audio/${cleanId}.m4a`,
        mimeType: 'audio/mp4',
        resolvedAt: Date.now(),
      };
      if (cacheKey) resolvedStreamCache.set(cacheKey, resolved);
      return resolved;
    }
    const localMp3 = path.resolve(__dirname, 'public/audio', `${cleanId}.mp3`);
    if (fs.existsSync(localMp3)) {
      const resolved: ResolvedStreamEntry = {
        url: `/audio/${cleanId}.mp3`,
        mimeType: 'audio/mpeg',
        resolvedAt: Date.now(),
      };
      if (cacheKey) resolvedStreamCache.set(cacheKey, resolved);
      return resolved;
    }
  }

  if (!forceRefresh && cleanId && knownDirectCdnMap[cleanId]) {
    const resolved: ResolvedStreamEntry = {
      url: knownDirectCdnMap[cleanId],
      mimeType: 'audio/mp4',
      resolvedAt: Date.now(),
    };
    if (cacheKey) resolvedStreamCache.set(cacheKey, resolved);
    return resolved;
  }

  const wantsLiveOrConcert =
    /\b(?:concert|live|anniversary|unplugged|acoustic|reprise|cover|mashup|piano|guitar|fingerstyle|slowed|reverb|karaoke|instrumental|tribute)\b/i.test(
      rawContextLower
    );

  const isExplicitLiveQuery = /\b(?:live|concert|unplugged|acoustic|cover)\b/i.test(meta.title);

  const matchKnownTitleMaster = (): { url: string; mimeType: string } | null => {
    if (isExplicitLiveQuery) return null;
    if (
      (normCoreTitle === 'icche ghuri' || normCoreTitle.includes('icche ghuri')) &&
      (rawContextLower.includes('shironamhin') || combinedArtistText.includes('shironamhin'))
    ) {
      return {
        url: 'https://aac.saavncdn.com/720/0d0bec146254bfcd0c8d61a72d784bd9_320.mp4',
        mimeType: 'audio/mp4',
      };
    }
    if (
      (normCoreTitle === 'hashimukh' || normCoreTitle === 'abar hashimukh' || normCoreTitle.includes('hashimukh')) &&
      (rawContextLower.includes('shironamhin') || combinedArtistText.includes('shironamhin'))
    ) {
      return {
        url: 'https://aac.saavncdn.com/260/f0d33fd85842ea3360c137c890849e76_320.mp4',
        mimeType: 'audio/mp4',
      };
    }
    if (
      (normCoreTitle === 'bondho janala' || normCoreTitle.includes('bondho janala')) &&
      (rawContextLower.includes('shironamhin') || combinedArtistText.includes('shironamhin')) &&
      !normCoreTitle.includes('bhalobasha') &&
      !normCoreTitle.includes('valobasha')
    ) {
      return {
        url: 'https://aac.saavncdn.com/000/8a81a552431793831c58e09f3d7fde01_320.mp4',
        mimeType: 'audio/mp4',
      };
    }
    if (
      (normCoreTitle === 'pakhi' || normCoreTitle.includes('pakhi')) &&
      (rawContextLower.includes('shironamhin') || combinedArtistText.includes('shironamhin'))
    ) {
      return {
        url: 'https://aac.saavncdn.com/720/7427d48dd875e1346f5469b76808f0a9_320.mp4',
        mimeType: 'audio/mp4',
      };
    }
    if (
      (normCoreTitle === 'cafetaria' || normCoreTitle.includes('cafetaria')) &&
      (rawContextLower.includes('shironamhin') || combinedArtistText.includes('shironamhin'))
    ) {
      return {
        url: 'https://aac.saavncdn.com/720/cedb3c7eadacffc6d9f9207ab880c887_320.mp4',
        mimeType: 'audio/mp4',
      };
    }
    if (
      (normCoreTitle === 'anmone' || normCoreTitle.includes('anmone')) &&
      (rawContextLower.includes('artcell') || combinedArtistText.includes('artcell'))
    ) {
      return {
        url: 'https://aac.saavncdn.com/385/081d326c688c1476cbf2d0c240e71890_320.mp4',
        mimeType: 'audio/mp4',
      };
    }
    if (
      (normCoreTitle === 'aniket prantor' || normCoreTitle === 'oniket prantor' || normCoreTitle.includes('aniket prantor') || normCoreTitle.includes('oniket prantor')) &&
      (rawContextLower.includes('artcell') || combinedArtistText.includes('artcell'))
    ) {
      return {
        url: 'https://aac.saavncdn.com/865/7e7b53bcbf1e22f821e8ff27d666be5b_320.mp4',
        mimeType: 'audio/mp4',
      };
    }
    if (
      (normCoreTitle === 'dhushor shomoy' || normCoreTitle.includes('dhushor shomoy')) &&
      (rawContextLower.includes('artcell') || combinedArtistText.includes('artcell'))
    ) {
      return {
        url: 'https://aac.saavncdn.com/865/f3d8c00186344c17e7b7b4d98995303f_320.mp4',
        mimeType: 'audio/mp4',
      };
    }
    if (
      (normCoreTitle === 'omimangshito' || normCoreTitle.includes('omimangshito')) &&
      (rawContextLower.includes('mizan') || combinedArtistText.includes('mizan') || rawContextLower.includes('razeeb') || combinedArtistText.includes('razeeb') || rawContextLower.includes('g series'))
    ) {
      return {
        url: 'https://aac.saavncdn.com/476/99042b8f14da26038f9bdddfe94b81db_320.mp4',
        mimeType: 'audio/mp4',
      };
    }
    if (normCoreTitle.includes('despacito') && (rawContextLower.includes('fonsi') || rawContextLower.includes('yankee'))) {
      return { url: '/audio/kJQP7kiw5Fk.m4a', mimeType: 'audio/mp4' };
    }
    if (normCoreTitle.includes('shape of you') && rawContextLower.includes('sheeran')) {
      return { url: '/audio/JGwWNGJdvx8.m4a', mimeType: 'audio/mp4' };
    }
    if (normCoreTitle.includes('blinding lights') && rawContextLower.includes('weeknd')) {
      return { url: '/audio/4NRXx6U8ABQ.m4a', mimeType: 'audio/mp4' };
    }
    if (normCoreTitle.includes('counting stars') && rawContextLower.includes('onerepublic')) {
      return { url: '/audio/hT_nvWreIhg.m4a', mimeType: 'audio/mp4' };
    }
    if (normCoreTitle === 'roar' && rawContextLower.includes('perry')) {
      return { url: '/audio/CevxZvSJLk8.m4a', mimeType: 'audio/mp4' };
    }
    if (normCoreTitle === 'sugar' && rawContextLower.includes('maroon')) {
      return { url: '/audio/09R8_2nJtjg.m4a', mimeType: 'audio/mp4' };
    }
    if (normCoreTitle === 'hello' && rawContextLower.includes('adele')) {
      return { url: '/audio/YQHsXMglC9A.m4a', mimeType: 'audio/mp4' };
    }
    if (normCoreTitle.includes('bohemian rhapsody') && rawContextLower.includes('queen')) {
      return {
        url: 'https://aac.saavncdn.com/806/442b9d1e36a4bcef050a32de50a82316_320.mp4',
        mimeType: 'audio/mp4',
      };
    }
    return null;
  };

  if (!wantsLofiOrRemix) {
    const knownTitleMaster = matchKnownTitleMaster();
    if (knownTitleMaster) {
      const resolved: ResolvedStreamEntry = {
        url: knownTitleMaster.url,
        mimeType: knownTitleMaster.mimeType,
        resolvedAt: Date.now(),
      };
      if (cacheKey) resolvedStreamCache.set(cacheKey, resolved);
      return resolved;
    }
  }

  if (cleanId === '8pgvTBikV9U' || (isObak && wantsCokeStudio)) {
    const resolved: ResolvedStreamEntry = {
      url: 'https://aac.saavncdn.com/744/89e8ba380132d45e474dd3b49779f20a_320.mp4',
      mimeType: 'audio/mp4',
      resolvedAt: Date.now(),
    };
    if (cacheKey) resolvedStreamCache.set(cacheKey, resolved);
    return resolved;
  }

  if (cleanId === 'PGgcOK7MgoM' || (isObak && isWarfaze && !wantsCokeStudio && effectiveDuration >= 485)) {
    const extPath = path.resolve(__dirname, 'public/audio', 'PGgcOK7MgoM.mp3');
    if (fs.existsSync(extPath)) {
      const resolved: ResolvedStreamEntry = {
        url: '/audio/PGgcOK7MgoM.mp3',
        mimeType: 'audio/mpeg',
        resolvedAt: Date.now(),
      };
      if (cacheKey) resolvedStreamCache.set(cacheKey, resolved);
      return resolved;
    }
  }

  if (cleanId === 'Qh_sxMN9UH8' || (isObak && isWarfaze && !wantsCokeStudio && effectiveDuration < 485)) {
    const origPath = path.resolve(__dirname, 'public/audio', 'Qh_sxMN9UH8.m4a');
    if (fs.existsSync(origPath)) {
      const resolved: ResolvedStreamEntry = {
        url: '/audio/Qh_sxMN9UH8.m4a',
        mimeType: 'audio/mp4',
        resolvedAt: Date.now(),
      };
      if (cacheKey) resolvedStreamCache.set(cacheKey, resolved);
      return resolved;
    }
  }

  if (
    cleanId === 'NQp3cbSkqbo' ||
    (normCoreTitle === 'tumi' &&
      !wantsLiveOrConcert &&
      (combinedArtistText.includes('level five') ||
        combinedArtistText.includes('levelfive') ||
        rawContextLower.includes('level five') ||
        rawContextLower.includes('levelfive')))
  ) {
    const tumiPath = path.resolve(__dirname, 'public/audio', 'NQp3cbSkqbo.m4a');
    if (fs.existsSync(tumiPath)) {
      const resolved: ResolvedStreamEntry = {
        url: '/audio/NQp3cbSkqbo.m4a',
        mimeType: 'audio/mp4',
        resolvedAt: Date.now(),
      };
      if (cacheKey) resolvedStreamCache.set(cacheKey, resolved);
      return resolved;
    }
  }

  // Tier 0b: Direct JioSaavn ID fast-path (js_<pid>) bypassing fragile title-search heuristics
  const rawJioSaavnId = cleanId.startsWith('js_') ? cleanId.slice(3).trim() : '';
  let fallbackSearchTitle = title;
  let fallbackSearchArtist = artist;
  let fallbackSearchDuration = effectiveDuration;
  if (rawJioSaavnId) {
    try {
      const detailsUrl = `https://www.jiosaavn.com/api.php?__call=song.getDetails&pids=${encodeURIComponent(
        rawJioSaavnId
      )}&_format=json&_marker=0&api_version=4&ctx=web6dot0`;
      const detailsRes = await fetchWithRetry(
        detailsUrl,
        { headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' } },
        { retries: 1, timeoutMs: 2600 }
      );
      if (detailsRes.ok) {
        const detailsData: any = await detailsRes.json();
        const songItem =
          detailsData?.[rawJioSaavnId] ||
          (Array.isArray(detailsData?.songs) ? detailsData.songs[0] : null);
        if (songItem) {
          const itemTitle = decodeHtmlEntitiesServer(String(songItem?.title || songItem?.song || '')).trim();
          const itemSub = decodeHtmlEntitiesServer(String(songItem?.subtitle || songItem?.more_info?.singers || '')).trim();
          const itemDur = Number(songItem?.more_info?.duration || songItem?.duration || 0);
          if (!fallbackSearchTitle && itemTitle) {
            const parsed = extractCoreTrackAndArtist(itemTitle, itemSub);
            fallbackSearchTitle = parsed.coreTitle || itemTitle;
            if (!fallbackSearchArtist) fallbackSearchArtist = parsed.primaryArtist || itemSub;
          }
          if (!fallbackSearchDuration && itemDur > 0) fallbackSearchDuration = itemDur;
        }
        const encMediaUrl =
          songItem?.more_info?.encrypted_media_url || songItem?.encrypted_media_url;
        if (encMediaUrl) {
          const authUrl = `https://www.jiosaavn.com/api.php?__call=song.generateAuthToken&url=${encodeURIComponent(
            encMediaUrl
          )}&bitrate=320&api_version=4&_format=json&ctx=web6dot0&_marker=0`;
          const authRes = await fetchWithRetry(
            authUrl,
            { headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' } },
            { retries: 1, timeoutMs: 2400 }
          );
          if (authRes.ok) {
            const authData: any = await authRes.json();
            const rawAuthUrl = String(authData?.auth_url || '');
            if (rawAuthUrl) {
              const directCdnUrl = rawAuthUrl
                .replace(/^https?:\/\/web\.saavncdn\.com/i, 'https://aac.saavncdn.com')
                .split('?')[0];
              let rejectedByCdn = false;
              try {
                const probeRes = await fetchWithRetry(
                  directCdnUrl,
                  {
                    method: 'HEAD',
                    headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' },
                  },
                  { retries: 0, timeoutMs: 1400 }
                );
                await probeRes.body?.cancel().catch(() => {});
                if (probeRes.status >= 400) rejectedByCdn = true;
              } catch {
                // Accept freshly minted JioSaavn auth URL on transient CDN probe timeout
              }
              if (!rejectedByCdn) {
                const resolved: ResolvedStreamEntry = {
                  url: directCdnUrl,
                  mimeType: 'audio/mp4',
                  resolvedAt: Date.now(),
                };
                if (cacheKey) resolvedStreamCache.set(cacheKey, resolved);
                return resolved;
              }
            }
          }
        }
      }
    } catch {
      // Fall through to saavn.sumit.co song ID backup
    }
    try {
      const sumitDirectRes = await fetchWithRetry(
        `https://saavn.sumit.co/api/songs/${encodeURIComponent(rawJioSaavnId)}`,
        { headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' } },
        { retries: 0, timeoutMs: 2200 }
      );
      if (sumitDirectRes.ok) {
        const sumitJson: any = await sumitDirectRes.json();
        const item = Array.isArray(sumitJson?.data) ? sumitJson.data[0] : sumitJson?.data;
        if (item && !fallbackSearchTitle) {
          const parsed = extractCoreTrackAndArtist(String(item?.name || ''), '');
          fallbackSearchTitle = parsed.coreTitle || String(item?.name || '');
        }
        const dls: any[] = Array.isArray(item?.downloadUrl) ? item.downloadUrl : [];
        const fullUrl = String(dls[dls.length - 1]?.url || '');
        if (fullUrl) {
          let sumitRejected = false;
          try {
            const sumitProbe = await fetchWithRetry(
              fullUrl,
              { method: 'HEAD', headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' } },
              { retries: 0, timeoutMs: 1400 }
            );
            await sumitProbe.body?.cancel().catch(() => {});
            if (sumitProbe.status >= 400) sumitRejected = true;
          } catch {}
          if (!sumitRejected) {
            const resolved: ResolvedStreamEntry = {
              url: fullUrl,
              mimeType: 'audio/mp4',
              resolvedAt: Date.now(),
            };
            if (cacheKey) resolvedStreamCache.set(cacheKey, resolved);
            return resolved;
          }
        }
      }
    } catch {
      // Fall through to multi-source resolution tiers
    }
  }

  // Tier 1: Exact-Track 320kbps AAC Direct CDN Resolver (JioSaavn Official API)
  // Enforces strict title, artist, version (Coke Studio vs Album, Live/Concert vs Studio), and duration gates
  const resolveTier1JioSaavn = async (): Promise<ResolvedStreamEntry | null> => {
    if (!title || coreTokens.length === 0) return null;
    if (normCoreTitle && combinedArtistText && normCoreTitle === combinedArtistText) return null;
    const queries = Array.from(
      new Set(
        [
          artist && !title.toLowerCase().includes(artist.toLowerCase())
            ? `${title} ${artist}`
            : title,
          secondaryArtist && !title.toLowerCase().includes(secondaryArtist.toLowerCase())
            ? `${title} ${secondaryArtist}`
            : '',
          title,
        ].filter((q) => q && q.trim().length > 0)
      )
    );

    const isDistinctiveCoreTitle =
      coreTokens.length >= 2 || (coreTokens.length === 1 && normCoreTitle.length >= 6);

    for (const q of queries) {
      try {
        const searchUrl = `https://www.jiosaavn.com/api.php?p=1&q=${encodeURIComponent(
          q.trim()
        )}&_format=json&_marker=0&api_version=4&ctx=web6dot0&n=10&__call=search.getResults`;
        const searchRes = await fetchWithRetry(
          searchUrl,
          { headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' } },
          { retries: 1, timeoutMs: 2800 }
        );
        if (!searchRes.ok) continue;
        const searchData: any = await searchRes.json();
        const results: any[] = Array.isArray(searchData?.results) ? searchData.results : [];
        if (results.length === 0) continue;

        let bestMatch: any = null;
        let bestScore = -999;

        for (let i = 0; i < results.length; i++) {
          const item = results[i];
          const moreInfo = item?.more_info || {};
          const encUrl = moreInfo?.encrypted_media_url;
          if (!encUrl) continue;

          const candTitleRaw = decodeHtmlEntitiesServer(String(item?.title || '')).toLowerCase();
          const candTitle = stripParentheticalAndEntities(candTitleRaw).toLowerCase();
          const candSub = decodeHtmlEntitiesServer(String(item?.subtitle || '')).toLowerCase();
          const candAlbum = decodeHtmlEntitiesServer(String(moreInfo?.album || '')).toLowerCase();
          const combined = `${candTitleRaw} ${candSub} ${candAlbum}`;
          const candDurSec = Number(moreInfo?.duration || 0);
          if (candDurSec > 0 && candDurSec <= 45) continue;

          const candNormFull = candTitle.replace(/[^a-z0-9\s]/g, ' ').replace(/\s+/g, ' ').trim();
          const candNormBase = candTitle
            .split('|')[0]
            .replace(/[^a-z0-9\s]/g, ' ')
            .replace(/\s+/g, ' ')
            .trim();

          // 1. STRICT CORE-TITLE MATCH GATE:
          let artistMatched = false;
          if (hasForeignSongTitleWords(candTitle, coreTokens, artistTokens, candSub)) {
            continue;
          }
          let matchedCoreCount = 0;
          for (const ct of coreTokens) {
            if (tokenMatchesText(ct, candTitle)) {
              matchedCoreCount += 1;
            }
          }
          const minRequired =
            coreTokens.length <= 3
              ? coreTokens.length
              : Math.max(2, Math.ceil(coreTokens.length * 0.75));
          artistMatched =
            artistTokens.length > 0 && artistTokens.some((at) => tokenMatchesText(at, combined));
          const hasDistinctiveTokenAndArtist =
            coreTokens.length >= 2 &&
            matchedCoreCount >= minRequired - 1 &&
            artistMatched &&
            coreTokens.some((ct) => ct.length >= 7 && tokenMatchesText(ct, candTitle));

          if (matchedCoreCount < minRequired && !hasDistinctiveTokenAndArtist) {
            continue;
          }

          const maxExactTitleDurDiff = isObak ? 18 : 20;
          const exactDistinctiveTitleMatch =
            isDistinctiveCoreTitle &&
            coreTokens.length >= 2 &&
            (candNormFull === normCoreTitle || candNormBase === normCoreTitle) &&
            effectiveDuration > 0 &&
            candDurSec > 0 &&
            Math.abs(candDurSec - effectiveDuration) <= maxExactTitleDurDiff;

          if (artistTokens.length > 0 && !artistMatched && !exactDistinctiveTitleMatch) {
            continue;
          }

          // 3. STRICT VERSION GATE (Coke Studio vs Original Studio Album, Live/Concert vs Studio):
          const candIsCokeStudio = combined.includes('coke studio');
          if (isObak && wantsCokeStudio !== candIsCokeStudio) {
            continue;
          }
          if (!wantsCokeStudio && candIsCokeStudio) {
            continue;
          }

          const isExactCoreTrackMatch =
            (candNormFull === normCoreTitle || candNormBase === normCoreTitle) && artistMatched;

          if (!isExactCoreTrackMatch) {
            const candIsLiveOrConcert =
              /\b(?:concert|live|anniversary|unplugged|acoustic|reprise|cover|mashup|piano|guitar|fingerstyle)\b/i.test(
                combined
              );
            if (wantsLiveOrConcert !== candIsLiveOrConcert) {
              if (
                !wantsLiveOrConcert ||
                (effectiveDuration > 0 && candDurSec > 0 && Math.abs(candDurSec - effectiveDuration) > 18)
              ) {
                continue;
              }
            }

            // 4. DURATION GATE (allows up to 65s for Coke Studio music video intros/credits when artist & Coke Studio match, 32s otherwise):
            if (effectiveDuration > 0 && candDurSec > 0) {
              const durDiff = Math.abs(candDurSec - effectiveDuration);
              const maxAllowedDurDiff = isObak
                ? 25
                : wantsCokeStudio && candIsCokeStudio
                ? 65
                : 32;
              if (durDiff > maxAllowedDurDiff) {
                continue;
              }
            }
          } else if (effectiveDuration > 0 && candDurSec > 0) {
            // For exact title + artist match, allow up to 95s difference to accommodate concert video intros/outros
            const durDiff = Math.abs(candDurSec - effectiveDuration);
            if (durDiff > 95) {
              continue;
            }
          }

          let score = 20 - i * 2;
          if (candNormFull === normCoreTitle) score += 35;
          else if (candNormBase === normCoreTitle) score += 25;

          for (const ct of coreTokens) {
            if (tokenMatchesText(ct, candTitle)) score += 20;
          }
          for (const at of artistTokens) {
            if (tokenMatchesText(at, combined)) score += 18;
          }
          if (effectiveDuration > 0 && candDurSec > 0) {
            const durDiff = Math.abs(candDurSec - effectiveDuration);
            if (durDiff <= 5) score += 45;
            else if (durDiff <= 15) score += 25;
            else if (durDiff <= 45) score += 10;
          }
          if (wantsCokeStudio && candIsCokeStudio) score += 40;

          const candIsLofiOrRemix = /\b(?:lofi|lo-fi|remix|mashup|slowed|reverb|cover)\b/.test(candTitleRaw);
          if (wantsLofiOrRemix && candIsLofiOrRemix) score += 25;
          else if (!wantsLofiOrRemix && candIsLofiOrRemix) score -= 30;

          if (
            (candTitleRaw.includes('karaoke') ||
              candTitleRaw.includes('instrumental') ||
              candSub.includes('sound tower')) &&
            !normCoreTitle.includes('karaoke') &&
            !normCoreTitle.includes('instrumental') &&
            !wantsLofiOrRemix
          ) {
            score -= 40;
          }

          if (score > bestScore) {
            bestScore = score;
            bestMatch = item;
          }
        }

        const encMediaUrl = bestMatch?.more_info?.encrypted_media_url;
        if (!encMediaUrl) continue;

        const authUrl = `https://www.jiosaavn.com/api.php?__call=song.generateAuthToken&url=${encodeURIComponent(
          encMediaUrl
        )}&bitrate=320&api_version=4&_format=json&ctx=web6dot0&_marker=0`;
        const authRes = await fetchWithRetry(
          authUrl,
          { headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' } },
          { retries: 1, timeoutMs: 2400 }
        );
        if (!authRes.ok) continue;
        const authData: any = await authRes.json();
        const rawAuthUrl = String(authData?.auth_url || '');
        if (!rawAuthUrl) continue;

        const directCdnUrl = rawAuthUrl
          .replace(/^https?:\/\/web\.saavncdn\.com/i, 'https://aac.saavncdn.com')
          .split('?')[0];

        let rejectedByCdn = false;
        try {
          const headCheck = await fetchWithRetry(
            directCdnUrl,
            {
              method: 'GET',
              headers: {
                Range: 'bytes=0-63',
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
              },
            },
            { retries: 0, timeoutMs: 2600 }
          );
          await headCheck.body?.cancel().catch(() => {});
          if (headCheck.status >= 400) {
            rejectedByCdn = true;
          }
        } catch {
          // Transient CDN probe timeout should not discard a freshly minted JioSaavn auth URL
        }
        if (!rejectedByCdn) {
          return {
            url: directCdnUrl,
            mimeType: 'audio/mp4',
            resolvedAt: Date.now(),
          };
        }
      } catch {
        // continue
      }
    }
    return null;
  };

  // Helper: Find top scored SoundCloud candidates once and reuse across fast progressive + bounded HLS
  let scCandidatesCachePromise: Promise<{ scClientId: string; candidates: Array<{ item: any; score: number }> }> | null = null;
  const getSoundCloudCandidates = () => {
    if (scCandidatesCachePromise) return scCandidatesCachePromise;
    scCandidatesCachePromise = (async () => {
      if (!title || coreTokens.length === 0) return { scClientId: '', candidates: [] };
      if (normCoreTitle && combinedArtistText && normCoreTitle === combinedArtistText) {
        return { scClientId: '', candidates: [] };
      }
      try {
        let scClientId = await getSoundCloudClientId();
        const scQueries = Array.from(
          new Set(
            [
              artist ? `${title} ${artist}` : title,
              secondaryArtist && secondaryArtist !== artist ? `${title} ${secondaryArtist}` : '',
              title,
            ].filter((q) => q && q.trim().length > 0)
          )
        );
        const isDistinctiveCoreTitle =
          coreTokens.length >= 2 || (coreTokens.length === 1 && normCoreTitle.length >= 6);

        for (const scQ of scQueries.slice(0, 3)) {
          const scSearchUrl = `https://api-v2.soundcloud.com/search/tracks?q=${encodeURIComponent(
            scQ.trim()
          )}&client_id=${encodeURIComponent(scClientId)}&limit=12`;
          let scRes = await fetchWithRetry(
            scSearchUrl,
            { headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' } },
            { retries: 1, timeoutMs: 2600 }
          );
          if (scRes.status === 401 || scRes.status === 403) {
            scClientId = await getSoundCloudClientId(true);
            scRes = await fetchWithRetry(
              `https://api-v2.soundcloud.com/search/tracks?q=${encodeURIComponent(
                scQ.trim()
              )}&client_id=${encodeURIComponent(scClientId)}&limit=12`,
              { headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' } },
              { retries: 1, timeoutMs: 2600 }
            );
          }
          if (!scRes.ok) continue;
          const scData: any = await scRes.json();
          const collection: any[] = Array.isArray(scData?.collection) ? scData.collection : [];
          if (collection.length === 0) continue;

          const scoredCandidates: Array<{ item: any; score: number }> = [];
          for (let i = 0; i < collection.length; i++) {
            const item = collection[i];
            if (String(item?.policy || '').toUpperCase() === 'SNIP') continue;
            const transcodings: any[] = Array.isArray(item?.media?.transcodings)
              ? item.media.transcodings
              : [];
            if (transcodings.length === 0) continue;

            const candTitleRaw = decodeHtmlEntitiesServer(String(item?.title || '')).toLowerCase();
            const candTitle = stripParentheticalAndEntities(candTitleRaw).toLowerCase();
            const candUser = decodeHtmlEntitiesServer(String(item?.user?.username || '')).toLowerCase();
            const combined = `${candTitleRaw} ${candUser}`;
            const candDurSec = Math.round(Number(item?.duration || 0) / 1000);
            if (candDurSec <= 45) continue;

            let candSongSegment = candTitle;
            if (candTitle.includes('-') || candTitle.includes('â€“') || candTitle.includes('â€”')) {
              const hParts = candTitle
                .split(/\s*[-â€“â€”]\s*/)
                .map((p) => p.trim())
                .filter(Boolean);
              if (hParts.length >= 2) {
                let bestPart = hParts[0];
                let bestCount = -1;
                for (const part of hParts) {
                  const mCount = coreTokens.filter((ct) => tokenMatchesText(ct, part)).length;
                  if (mCount > bestCount) {
                    bestCount = mCount;
                    bestPart = part;
                  }
                }
                if (bestCount > 0) {
                  candSongSegment = bestPart;
                }
              }
            }

            const isBilingualPrefixMatch =
              coreTokens.length >= 2 &&
              /[^\x00-\x7F]/.test(meta.rawTitle) &&
              candTitle
                .replace(/[^a-z0-9\s]/g, ' ')
                .replace(/\s+/g, ' ')
                .trim()
                .startsWith(normCoreTitle);

            const hasForeignFull = hasForeignSongTitleWords(candTitle, coreTokens, artistTokens, candUser);
            const hasForeignSeg = isBilingualPrefixMatch
              ? false
              : hasForeignSongTitleWords(candSongSegment, coreTokens, artistTokens, candUser);
            const isMedleyOrOtherAlbumTrack =
              candTitle.includes('valobashar magh') ||
              (hasForeignFull &&
                hasForeignSeg &&
                artistTokens.length > 0 &&
                artistTokens.some((at) => tokenMatchesText(at, candTitle)));
            if (isMedleyOrOtherAlbumTrack || (hasForeignFull && hasForeignSeg)) continue;
            let matchedCoreCount = 0;
            for (const ct of coreTokens) {
              if (tokenMatchesText(ct, candTitle)) matchedCoreCount += 1;
            }
            const minRequired =
              coreTokens.length <= 3 ? coreTokens.length : Math.ceil(coreTokens.length * 0.75);
            if (matchedCoreCount < minRequired) continue;

            const artistMatched =
              artistTokens.length === 0 || artistTokens.some((at) => tokenMatchesText(at, combined));
            const candSegNorm = candSongSegment.replace(/[^a-z0-9\s]/g, ' ').replace(/\s+/g, ' ').trim();
            const exactDistinctiveTitleMatch =
              isDistinctiveCoreTitle &&
              coreTokens.length >= 2 &&
              (candSegNorm === normCoreTitle || isBilingualPrefixMatch) &&
              effectiveDuration > 0 &&
              candDurSec > 0 &&
              Math.abs(candDurSec - effectiveDuration) <= 25;

            if (!artistMatched && !exactDistinctiveTitleMatch) continue;

            if (effectiveDuration > 0 && candDurSec > 0) {
              const durDiff = Math.abs(candDurSec - effectiveDuration);
              const maxScDiff = isObak || rawContextLower.includes('extended') ? 35 : artistMatched ? 45 : 25;
              if (durDiff > maxScDiff) continue;
            }

            const candIsCoverOrRemix =
              /\b(?:cover|remix|karaoke|instrumental|nightcore|slowed|reverb|lofi|lo-fi|mashup|piano|guitar|fingerstyle|tribute|parody|bgm|concert|live|unplugged|acoustic)\b/.test(
                candTitleRaw
              );
            if (!wantsLofiOrRemix && !wantsLiveOrConcert && candIsCoverOrRemix) continue;

            const candIsCokeStudio = combined.includes('coke studio');
            if (isObak && wantsCokeStudio !== candIsCokeStudio) continue;
            if (!wantsCokeStudio && candIsCokeStudio) continue;

            let score = 20 - i;
            for (const ct of coreTokens) {
              if (tokenMatchesText(ct, candTitle)) score += 20;
            }
            for (const at of artistTokens) {
              if (tokenMatchesText(at, combined)) score += 18;
            }
            if (effectiveDuration > 0 && candDurSec > 0) {
              const durDiff = Math.abs(candDurSec - effectiveDuration);
              if (durDiff <= 2) score += 80;
              else if (durDiff <= 6) score += 55;
              else if (durDiff <= 15) score += 30;
            }
            if (transcodings.some((tr) => tr?.format?.protocol === 'progressive')) score += 10;

            scoredCandidates.push({ item, score });
          }

          scoredCandidates.sort((a, b) => b.score - a.score);
          if (scoredCandidates.length > 0) {
            return { scClientId, candidates: scoredCandidates.slice(0, 3) };
          }
        }
      } catch {
        // ignore
      }
      return { scClientId: '', candidates: [] };
    })();
    return scCandidatesCachePromise;
  };

  // Tier 2a: Fast SoundCloud progressive MP3 resolution
  const resolveTier2SoundCloudProg = async (): Promise<ResolvedStreamEntry | null> => {
    const { scClientId, candidates } = await getSoundCloudCandidates();
    for (const cand of candidates) {
      try {
        const transcodings: any[] = cand.item.media.transcodings;
        const progTr = transcodings.find((tr) => tr?.format?.protocol === 'progressive' && !tr?.snipped);
        if (progTr?.url) {
          const sep = String(progTr.url).includes('?') ? '&' : '?';
          const infoRes = await fetchWithRetry(
            `${progTr.url}${sep}client_id=${encodeURIComponent(scClientId)}`,
            {},
            { retries: 1, timeoutMs: 2000 }
          );
          if (infoRes.ok) {
            const infoData: any = await infoRes.json();
            const candProgUrl = String(infoData?.url || '');
            if (
              candProgUrl &&
              !/cf-preview-media\.sndcdn\.com|\/preview\/0\/30\//i.test(candProgUrl)
            ) {
              return {
                url: candProgUrl,
                mimeType: 'audio/mpeg',
                resolvedAt: Date.now(),
              };
            }
          }
        }
      } catch {}
    }
    return null;
  };

  // Tier 2b: Bounded SoundCloud HLS buffer assembly (only executed if fast tiers miss)
  const resolveTier2SoundCloudHls = async (): Promise<ResolvedStreamEntry | null> => {
    const { scClientId, candidates } = await getSoundCloudCandidates();
    const assembleTask = (async (): Promise<ResolvedStreamEntry | null> => {
      for (const cand of candidates) {
        try {
          const transcodings: any[] = cand.item.media.transcodings;
          const hlsMp3Tr = transcodings.find(
            (tr) =>
              tr?.format?.protocol === 'hls' &&
              String(tr?.format?.mime_type || '').includes('audio/mpeg')
          );
          if (hlsMp3Tr?.url) {
            const sep = String(hlsMp3Tr.url).includes('?') ? '&' : '?';
            const infoRes = await fetchWithRetry(
              `${hlsMp3Tr.url}${sep}client_id=${encodeURIComponent(scClientId)}`,
              {},
              { retries: 1, timeoutMs: 2000 }
            );
            if (infoRes.ok) {
              const infoData: any = await infoRes.json();
              if (infoData?.url) {
                const m3u8Text = await fetchWithRetry(String(infoData.url), {}, { retries: 1, timeoutMs: 2000 }).then((r) => r.text());
                const segUrls = m3u8Text
                  .split('\n')
                  .map((l) => l.trim())
                  .filter((l) => l.startsWith('https://'));
                if (segUrls.length > 0) {
                  const segmentBuffers = await Promise.all(
                    segUrls.map((u) =>
                      fetchWithRetry(u, {}, { retries: 2, timeoutMs: 3500, baseDelayMs: 180 })
                        .then((r) => {
                          if (!r.ok) throw new Error(`seg ${r.status}`);
                          return r.arrayBuffer();
                        })
                        .then((ab) => Buffer.from(ab))
                    )
                  );
                  const fullBuffer = Buffer.concat(segmentBuffers);
                  if (fullBuffer.length > 50000) {
                    return {
                      url: `sc-buffer://${cleanId || 'track'}`,
                      mimeType: 'audio/mpeg',
                      buffer: fullBuffer,
                      resolvedAt: Date.now(),
                    };
                  }
                }
              }
            }
          }

          const fmp4Tr = transcodings.find((tr) =>
            String(tr?.format?.mime_type || '').includes('audio/mp4')
          );
          if (fmp4Tr?.url) {
            const sep = String(fmp4Tr.url).includes('?') ? '&' : '?';
            const infoRes = await fetchWithRetry(
              `${fmp4Tr.url}${sep}client_id=${encodeURIComponent(scClientId)}`,
              {},
              { retries: 1, timeoutMs: 2000 }
            );
            if (infoRes.ok) {
              const infoData: any = await infoRes.json();
              if (infoData?.url) {
                const m3u8Text = await fetchWithRetry(String(infoData.url), {}, { retries: 1, timeoutMs: 2000 }).then((r) => r.text());
                const mapMatch = m3u8Text.match(/#EXT-X-MAP:URI="([^"]+)"/);
                const segUrls = m3u8Text
                  .split('\n')
                  .map((l) => l.trim())
                  .filter((l) => l.startsWith('https://'));
                if (mapMatch?.[1] && segUrls.length > 0) {
                  const allSegmentUrls = [mapMatch[1], ...segUrls];
                  const segmentBuffers = await Promise.all(
                    allSegmentUrls.map((u) =>
                      fetchWithRetry(u, {}, { retries: 2, timeoutMs: 3500, baseDelayMs: 180 })
                        .then((r) => {
                          if (!r.ok) throw new Error(`seg ${r.status}`);
                          return r.arrayBuffer();
                        })
                        .then((ab) => Buffer.from(ab))
                    )
                  );
                  const rawConcatenated = Buffer.concat(segmentBuffers);
                  const fullBuffer = normalizeAssembledFmp4Buffer(rawConcatenated);
                  if (fullBuffer.length > 50000) {
                    return {
                      url: `sc-buffer://${cleanId || 'track'}`,
                      mimeType: 'audio/mp4',
                      buffer: fullBuffer,
                      resolvedAt: Date.now(),
                    };
                  }
                }
              }
            }
          }
        } catch {}
      }
      return null;
    })();

    return Promise.race([
      assembleTask,
      new Promise<null>((resolve) => setTimeout(() => resolve(null), 6500)),
    ]);
  };

  // Tier 3: Direct YouTube dynamic stream if 11 chars standard YouTube id
  const resolveTier3Ytdl = async (): Promise<ResolvedStreamEntry | null> => {
    if (cleanId.length !== 11 || cleanId.startsWith('custom_') || cleanId.startsWith('js_') || cleanId.startsWith('sp_')) {
      return null;
    }
    try {
      const videoUrl = `https://www.youtube.com/watch?v=${cleanId}`;
      const timeoutPromise = new Promise((_, reject) =>
        setTimeout(() => reject(new Error('ytdl-timeout')), 6000)
      );
      const infoPromise = ytdl.getInfo(videoUrl);
      const info: any = await Promise.race([infoPromise, timeoutPromise]);
      const audioFormats = ytdl.filterFormats(info.formats, 'audioonly');

      if (audioFormats.length > 0) {
        const bestAudio = audioFormats.reduce((prev, curr) => {
          return (curr.audioBitrate || 0) > (prev.audioBitrate || 0) ? curr : prev;
        });

        if (bestAudio.url) {
          const candUrl = String(bestAudio.url);
          const probe = await fetchWithRetry(
            candUrl,
            { headers: { Range: 'bytes=0-511' } },
            { retries: 1, timeoutMs: 1600, baseDelayMs: 150 }
          ).catch(() => null);
          if (probe && (probe.ok || probe.status === 206)) {
            try {
              await probe.body?.cancel();
            } catch {}
            return {
              url: candUrl,
              mimeType: bestAudio.mimeType?.split(';')[0] || 'audio/mp4',
              resolvedAt: Date.now(),
            };
          }
        }
      }
    } catch {
      // continue
    } finally {
      try {
        for (const f of fs.readdirSync(process.cwd())) {
          if (f.endsWith('-watch.html') || f.endsWith('-player-script.js')) {
            fs.unlinkSync(path.join(process.cwd(), f));
          }
        }
      } catch {}
    }
    return null;
  };

  // Tier 4: Full-Length 320kbps AAC Fallback via saavn.sumit.co (scored best match, strictly rejects <=45s previews)
  const resolveTier4SaavnSumit = async (): Promise<ResolvedStreamEntry | null> => {
    if (!title || coreTokens.length === 0) return null;
    if (normCoreTitle && combinedArtistText && normCoreTitle === combinedArtistText) return null;
    try {
      const isDistinctiveCoreTitle =
        coreTokens.length >= 2 || (coreTokens.length === 1 && normCoreTitle.length >= 6);
      const q = artist ? `${title} ${artist}` : title;
      const saavnUrl = `https://saavn.sumit.co/api/search/songs?query=${encodeURIComponent(
        q.trim()
      )}&limit=10`;
      const saavnRes = await fetchWithRetry(saavnUrl, {}, { retries: 0, timeoutMs: 1200 });
      if (!saavnRes.ok) return null;
      const saavnData: any = await saavnRes.json();
      const items: any[] = Array.isArray(saavnData?.data?.results) ? saavnData.data.results : [];

      let bestItem: any = null;
      let bestScore = -999;

      for (let i = 0; i < items.length; i++) {
        const item = items[i];
        const downloadUrls: any[] = Array.isArray(item?.downloadUrl) ? item.downloadUrl : [];
        const dlUrl =
          downloadUrls.length > 0 ? String(downloadUrls[downloadUrls.length - 1]?.url || '') : '';
        const durSec = Number(item?.duration || 0);
        if (!dlUrl || durSec <= 45) continue;
        const candTitleRaw = decodeHtmlEntitiesServer(String(item?.name || '')).toLowerCase();
        const candTitle = stripParentheticalAndEntities(candTitleRaw).toLowerCase();
        const candArtist = Array.isArray(item?.artists?.primary)
          ? item.artists.primary
              .map((a: any) => decodeHtmlEntitiesServer(String(a?.name || '')))
              .filter(Boolean)
              .join(' ')
              .toLowerCase()
          : '';
        const combinedCand = `${candTitleRaw} ${candArtist}`;
        if (
          !wantsLofiOrRemix &&
          !wantsLiveOrConcert &&
          /\b(?:karaoke|instrumental|nightcore|remix|cover|tribute|parody|zzang|cheesyfox|mashup|piano|guitar|fingerstyle|slowed|reverb|bgm|concert|live|unplugged|acoustic)\b/i.test(
            combinedCand
          )
        ) {
          continue;
        }
        const candIsCokeStudio = combinedCand.includes('coke studio');
        if (wantsCokeStudio !== candIsCokeStudio) {
          continue;
        }
        if (effectiveDuration > 0 && durSec > 0) {
          const durDiff = Math.abs(durSec - effectiveDuration);
          const maxTier4Diff = isObak ? 25 : wantsCokeStudio && candIsCokeStudio ? 65 : 32;
          if (durDiff > maxTier4Diff) continue;
        }
        if (hasForeignSongTitleWords(candTitle, coreTokens, artistTokens, candArtist)) {
          continue;
        }
        let matched = 0;
        for (const ct of coreTokens) {
          if (tokenMatchesText(ct, candTitle)) matched += 1;
        }
        const minReq =
          coreTokens.length <= 3 ? coreTokens.length : Math.ceil(coreTokens.length * 0.75);
        if (matched < minReq) continue;
        const candNorm = candTitle.replace(/[^a-z0-9\s]/g, ' ').replace(/\s+/g, ' ').trim();
        const artistMatched =
          artistTokens.length === 0 ||
          artistTokens.some((at) => tokenMatchesText(at, combinedCand));
        const exactDistinctive =
          isDistinctiveCoreTitle &&
          coreTokens.length >= 2 &&
          candNorm === normCoreTitle &&
          effectiveDuration > 0 &&
          durSec > 0 &&
          Math.abs(durSec - effectiveDuration) <= 20;
        if (!artistMatched && !exactDistinctive) {
          continue;
        }

        let score = 20 - i;
        if (candNorm === normCoreTitle) score += 35;
        if (artistMatched) score += 20;
        if (effectiveDuration > 0 && durSec > 0) {
          const durDiff = Math.abs(durSec - effectiveDuration);
          if (durDiff <= 5) score += 45;
          else if (durDiff <= 18) score += 25;
        }
        if (score > bestScore) {
          bestScore = score;
          bestItem = item;
        }
      }

      if (bestItem) {
        const downloadUrls: any[] = Array.isArray(bestItem.downloadUrl)
          ? bestItem.downloadUrl
          : [];
        const fullUrl = String(downloadUrls[downloadUrls.length - 1]?.url || '');
        if (fullUrl) {
          let tier4Rejected = false;
          try {
            const tier4Probe = await fetchWithRetry(
              fullUrl,
              { method: 'HEAD', headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' } },
              { retries: 0, timeoutMs: 1400 }
            );
            await tier4Probe.body?.cancel().catch(() => {});
            if (tier4Probe.status >= 400) tier4Rejected = true;
          } catch {}
          if (!tier4Rejected) {
            return {
              url: fullUrl,
              mimeType: 'audio/mp4',
              resolvedAt: Date.now(),
            };
          }
        }
      }
    } catch {
      // continue
    }
    return null;
  };

    // Race all fast external tiers concurrently with priority settlement.
    // For non-curated standard 11-char YouTube IDs, exact Tier 3 YouTube audio (t3Val) takes priority
    // over text-search guesses (t1/t2/t4) when ytdl probes cleanly, preventing wrong-song substitution.
    const isStdYtId =
      cleanId.length === 11 &&
      !cleanId.startsWith('custom_') &&
      !cleanId.startsWith('js_') &&
      !cleanId.startsWith('sp_');
    const t1Promise = resolveTier1JioSaavn();
    const t2ProgPromise = resolveTier2SoundCloudProg();
    const t3Promise = resolveTier3Ytdl();
    const t4Promise = resolveTier4SaavnSumit();

    const fastWinner = await new Promise<ResolvedStreamEntry | null>((resolve) => {
      let settledCount = 0;
      let resolved = false;
      let t1Done = false;
      let t2Done = false;
      let t3Done = false;
      let t1Val: ResolvedStreamEntry | null = null;
      let t2Val: ResolvedStreamEntry | null = null;
      let t4Val: ResolvedStreamEntry | null = null;
      let t3Val: ResolvedStreamEntry | null = null;
      let graceTimer: ReturnType<typeof setTimeout> | null = null;

      const finish = (val: ResolvedStreamEntry | null) => {
        if (resolved) return;
        resolved = true;
        if (graceTimer) {
          clearTimeout(graceTimer);
          graceTimer = null;
        }
        resolve(val);
      };

      const pickPriorityWinner = () =>
        isStdYtId ? t3Val || t1Val || t2Val || t4Val : t1Val || t2Val || t4Val || t3Val;

      const onAnySettled = () => {
        settledCount++;
        if (resolved) return;
        if (isStdYtId && t3Done && t3Val) {
          finish(t3Val);
          return;
        }
        if (!isStdYtId && t1Done && t1Val) {
          finish(t1Val);
          return;
        }
        const fastFallback = isStdYtId ? t1Val || t2Val || t4Val : t2Val || t4Val;
        if (fastFallback) {
          if ((isStdYtId && t3Done) || (!isStdYtId && t1Done)) {
            finish(pickPriorityWinner());
            return;
          }
          if (!graceTimer) {
            graceTimer = setTimeout(() => {
              finish(pickPriorityWinner());
            }, isStdYtId ? 950 : 350);
          }
        } else if (t1Done && t2Done && (!isStdYtId || t3Done) && !graceTimer) {
          // Verified fast tiers settled without a hit;
          // do not block SoundCloud HLS assembly waiting on slow fallbacks.
          graceTimer = setTimeout(() => {
            finish(pickPriorityWinner());
          }, 200);
        }
        if (settledCount >= 4) {
          finish(pickPriorityWinner());
        }
      };

      t1Promise
        .then((v) => {
          t1Done = true;
          t1Val = v;
        })
        .catch(() => {
          t1Done = true;
        })
        .finally(onAnySettled);

      t2ProgPromise
        .then((v) => {
          t2Done = true;
          t2Val = v;
        })
        .catch(() => {
          t2Done = true;
        })
        .finally(onAnySettled);

      t4Promise
        .then((v) => {
          t4Val = v;
        })
        .catch(() => {})
        .finally(onAnySettled);

      t3Promise
        .then((v) => {
          t3Done = true;
          t3Val = v;
        })
        .catch(() => {
          t3Done = true;
        })
        .finally(onAnySettled);
    });

    if (fastWinner) {
      if (cacheKey) {
        resolvedStreamCache.set(cacheKey, fastWinner);
      }
      return fastWinner;
    }

    // Last dynamic resort: bounded SoundCloud HLS assembly
    const hlsWinner = await resolveTier2SoundCloudHls();
    if (hlsWinner) {
      if (cacheKey) {
        resolvedStreamCache.set(cacheKey, hlsWinner);
      }
      return hlsWinner;
    }

    // Final exact-track YouTube fallback for external catalog IDs (js_* / sp_*) whose CDN audio was 404/geo-restricted
    const ytFallbackTitle = fallbackSearchTitle || title;
    const ytFallbackTokens = getCoreTitleTokens(ytFallbackTitle);
    if (!isStdYtId && ytFallbackTitle && ytFallbackTokens.length > 0) {
      try {
        const ytQuery = `${ytFallbackTitle} ${fallbackSearchArtist || artist || ''}`.trim();
        const ytCandidates = await searchYouTube(ytQuery, {
          retries: 0,
          timeoutMs: 2200,
          skipSaavnFallback: true,
        });
        for (const cand of ytCandidates.slice(0, 5)) {
          const candId = String(cand?.id || '');
          if (candId.length !== 11) continue;
          const candTitleNorm = stripParentheticalAndEntities(String(cand?.title || '')).toLowerCase();
          const candDur = Number(cand?.durationSeconds || 0);
          if (candDur > 0 && candDur <= 45) continue;
          if (
            fallbackSearchDuration > 0 &&
            candDur > 0 &&
            Math.abs(candDur - fallbackSearchDuration) > 40
          ) {
            continue;
          }
          if (!ytFallbackTokens.every((ct) => tokenMatchesText(ct, candTitleNorm))) continue;
          const info: any = await Promise.race([
            ytdl.getInfo(`https://www.youtube.com/watch?v=${candId}`),
            new Promise((_, reject) => setTimeout(() => reject(new Error('ytdl-timeout')), 2800)),
          ]).catch(() => null);
          if (!info) continue;
          const audioFormats = ytdl.filterFormats(info.formats, 'audioonly');
          if (audioFormats.length === 0) continue;
          const bestAudio = audioFormats.reduce((prev, curr) =>
            (curr.audioBitrate || 0) > (prev.audioBitrate || 0) ? curr : prev
          );
          if (!bestAudio?.url) continue;
          const probe = await fetchWithRetry(
            String(bestAudio.url),
            { headers: { Range: 'bytes=0-511' } },
            { retries: 0, timeoutMs: 1500 }
          ).catch(() => null);
          if (probe && (probe.ok || probe.status === 206)) {
            await probe.body?.cancel().catch(() => {});
            const resolvedYt: ResolvedStreamEntry = {
              url: String(bestAudio.url),
              mimeType: bestAudio.mimeType?.split(';')[0] || 'audio/mp4',
              resolvedAt: Date.now(),
            };
            if (cacheKey) resolvedStreamCache.set(cacheKey, resolvedYt);
            return resolvedYt;
          }
        }
      } catch {}
    }

    return null;
  };

  if (!cacheKey) {
    return runResolution();
  }

  const promise = runResolution().finally(() => {
    if (inFlightStreamResolutions.get(cacheKey) === promise) {
      inFlightStreamResolutions.delete(cacheKey);
    }
  });
  inFlightStreamResolutions.set(cacheKey, promise);
  return promise;
}

function normalizeAssembledFmp4Buffer(input: Buffer): Buffer {
  try {
    let off = 0;
    const boxes: Array<{ tp: string; sz: number; data: Buffer }> = [];
    let totalSubsegDur = 0;
    let sidxTimescale = 44100;

    while (off + 8 <= input.length) {
      const sz = input.readUInt32BE(off);
      const tp = input.subarray(off + 4, off + 8).toString('ascii');
      if (sz < 8 || off + sz > input.length) break;
      const data = input.subarray(off, off + sz);
      boxes.push({ tp, sz, data });
      if (tp === 'sidx' && sz >= 44) {
        const ver = data[8];
        sidxTimescale = data.readUInt32BE(16) || 44100;
        const subsegDur = data.readUInt32BE(ver === 0 ? 36 : 44);
        totalSubsegDur += subsegDur;
      }
      off += sz;
    }

    if (boxes.length === 0 || totalSubsegDur <= 0) return input;
    const durSec = sidxTimescale > 0 ? totalSubsegDur / sidxTimescale : 0;

    const patchMoovDurations = (bufSlice: Buffer) => {
      let p = 0;
      while (p + 8 <= bufSlice.length) {
        const bsz = bufSlice.readUInt32BE(p);
        const btp = bufSlice.subarray(p + 4, p + 8).toString('ascii');
        if (bsz < 8 || p + bsz > bufSlice.length) break;
        if (['moov', 'trak', 'mdia', 'minf', 'stbl', 'mvex'].includes(btp)) {
          patchMoovDurations(bufSlice.subarray(p + 8, p + bsz));
        } else if (btp === 'mvhd' || btp === 'mdhd') {
          const ver = bufSlice[p + 8];
          const ts = bufSlice.readUInt32BE(p + (ver === 0 ? 20 : 28));
          if (ts > 0) {
            const targetDur = Math.round(durSec * ts);
            if (ver === 0) bufSlice.writeUInt32BE(targetDur, p + 24);
            else bufSlice.writeBigUInt64BE(BigInt(targetDur), p + 32);
          }
        } else if (btp === 'tkhd') {
          const ver = bufSlice[p + 8];
          const targetDur = Math.round(durSec * 1000);
          if (ver === 0) bufSlice.writeUInt32BE(targetDur, p + 28);
          else bufSlice.writeBigUInt64BE(BigInt(targetDur), p + 36);
        }
        p += bsz;
      }
    };

    const outChunks: Buffer[] = [];
    for (const b of boxes) {
      if (b.tp === 'styp' || b.tp === 'sidx') continue;
      if (b.tp === 'moov' && durSec > 0) {
        const moovCopy = Buffer.from(b.data);
        patchMoovDurations(moovCopy);
        outChunks.push(moovCopy);
      } else {
        outChunks.push(b.data);
      }
    }
    return Buffer.concat(outChunks);
  } catch {
    return input;
  }
}

function normalizeServerPhoneticQuery(raw: string): string {
  const q = (raw || '').trim();
  const lower = q.toLowerCase();
  if (lower.includes('obak valo') || lower.includes('obak bhalo')) {
    return 'Obak Bhalobasha Warfaze';
  }
  if (
    lower.includes('tmi hiyar') ||
    lower.includes('tumi hiyar') ||
    lower.includes('hiyar majh')
  ) {
    return 'Amar Hiyar Majhe';
  }
  return q;
}

const SEARCH_CACHE_TTL_MS = 3 * 60 * 1000;
const TRENDING_CACHE_TTL_MS = 5 * 60 * 1000;
const searchResponseCache = new Map<string, { songs: any[]; cachedAt: number }>();
const inFlightSearchQueries = new Map<string, Promise<any[]>>();

function withSoftDeadline<T>(promise: Promise<T>, deadlineMs: number, fallback: T): Promise<T> {
  return new Promise<T>((resolve) => {
    let settled = false;
    const timer = setTimeout(() => {
      if (!settled) {
        settled = true;
        resolve(fallback);
      }
    }, deadlineMs);
    promise
      .then((value) => {
        if (!settled) {
          settled = true;
          clearTimeout(timer);
          resolve(value);
        }
      })
      .catch(() => {
        if (!settled) {
          settled = true;
          clearTimeout(timer);
          resolve(fallback);
        }
      });
  });
}

function getStaticFallbackMatches(query: string): any[] {
  const qLower = query.toLowerCase();
  const matched = FALLBACK_POPULAR.filter(
    (s) => s.title.toLowerCase().includes(qLower) || s.artist.toLowerCase().includes(qLower)
  );
  return matched.length > 0 ? matched : FALLBACK_POPULAR;
}

// Helper: Search live full-length 320kbps AAC catalog via official JioSaavn API (with saavn.sumit.co fallback)
async function searchSaavnFallback(
  query: string,
  options: { retries?: number; timeoutMs?: number } = {}
): Promise<any[]> {
  const timeoutMs = options.timeoutMs ?? 2800;
  const retries = options.retries ?? 1;
  const songs: any[] = [];
  const seen = new Set<string>();
  const wantsRemix = /\b(?:remix|karaoke|instrumental|nightcore|cover)\b/i.test(query);
  const wantsLofiOrChill = /\b(?:lofi|lo-fi|chill|study|beats|ambient|relax|instrumental)\b/i.test(query);

  // 1. Primary: Official JioSaavn API (direct & Cloudflare-immune)
  try {
    const officialUrl = `https://www.jiosaavn.com/api.php?p=1&q=${encodeURIComponent(
      query.trim()
    )}&_format=json&_marker=0&api_version=4&ctx=web6dot0&n=15&__call=search.getResults`;
    const offRes = await withSoftDeadline(
      fetchWithRetry(
        officialUrl,
        { headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' } },
        { retries, timeoutMs }
      ),
      timeoutMs * (retries + 1) + 400,
      null as any
    );
    if (offRes && offRes.ok) {
      const offData: any = await offRes.json();
      const offItems: any[] = Array.isArray(offData?.results) ? offData.results : [];
      for (const item of offItems) {
        const rawId = String(item?.id || '').trim();
        const trackId = rawId ? `js_${rawId}` : '';
        const title = decodeHtmlEntitiesServer(String(item?.title || '').trim());
        const moreInfo = item?.more_info || {};
        const primaryArtists = Array.isArray(moreInfo?.artistMap?.primary_artists)
          ? moreInfo.artistMap.primary_artists
              .map((a: any) => a?.name)
              .filter(Boolean)
              .join(', ')
          : '';
        const subtitle = decodeHtmlEntitiesServer(String(item?.subtitle || '').trim());
        const artist = decodeHtmlEntitiesServer(
          String(primaryArtists || subtitle.split(' - ')[0] || 'Various Artists').trim()
        );
        const durSec = Math.round(Number(moreInfo?.duration || 0));
        const encUrl = String(moreInfo?.encrypted_media_url || '').trim();

        if (!trackId || !title || !encUrl || durSec <= 45) continue;
        const rejectRegex = wantsLofiOrChill
          ? /\b(?:karaoke|nightcore|tribute|parody|zzang|cheesyfox)\b/i
          : /\b(?:karaoke|instrumental|nightcore|remix|cover|tribute|parody|zzang|cheesyfox)\b/i;
        if (!wantsRemix && rejectRegex.test(`${title} ${artist}`)) {
          continue;
        }
        if (seen.has(trackId)) continue;
        seen.add(trackId);

        const mins = Math.floor(durSec / 60);
        const secs = durSec % 60;
        const rawImg = String(item?.image || '').trim();
        const highResArt = rawImg
          ? rawImg.replace(/150x150|50x50/g, '500x500')
          : 'https://i.ytimg.com/vi/fJ9rUzIMcZQ/hqdefault.jpg';

        songMetaCache.set(trackId, { title, artist, durationSeconds: durSec });
        songs.push({
          id: trackId,
          title,
          artist,
          channelId: trackId,
          thumbnailUrl: highResArt,
          durationSeconds: durSec,
          durationFormatted: `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`,
          viewCount: Number(item?.play_count || 250000),
        });
      }
      if (songs.length > 0) return songs;
    }
  } catch {
    // Fall through to saavn.sumit.co backup
  }

  // 2. Secondary backup: saavn.sumit.co
  try {
    const saavnUrl = `https://saavn.sumit.co/api/search/songs?query=${encodeURIComponent(
      query.trim()
    )}&limit=15`;
    const res = await withSoftDeadline(
      fetchWithRetry(saavnUrl, {}, { retries: 0, timeoutMs: 2200 }),
      2500,
      null as any
    );
    if (!res || !res.ok) return [];
    const data: any = await res.json();
    const items: any[] = Array.isArray(data?.data?.results) ? data.data.results : [];

    for (const item of items) {
      const trackId = item?.id ? `js_${item.id}` : '';
      const title = decodeHtmlEntitiesServer(String(item?.name || '').trim());
      const primaryArtists = Array.isArray(item?.artists?.primary)
        ? item.artists.primary.map((a: any) => a?.name).filter(Boolean).join(', ')
        : '';
      const artist = decodeHtmlEntitiesServer(String(primaryArtists || item?.label || 'Various Artists').trim());
      const downloadUrls: any[] = Array.isArray(item?.downloadUrl) ? item.downloadUrl : [];
      const bestDl = downloadUrls.length > 0 ? downloadUrls[downloadUrls.length - 1] : null;
      const fullStreamUrl = String(bestDl?.url || '').trim();
      const durSec = Math.round(Number(item?.duration || 0));

      if (!trackId || !title || !fullStreamUrl || durSec <= 45) continue;
      const rejectRegex = wantsLofiOrChill
        ? /\b(?:karaoke|nightcore|tribute|parody|zzang|cheesyfox)\b/i
        : /\b(?:karaoke|instrumental|nightcore|remix|cover|tribute|parody|zzang|cheesyfox)\b/i;
      if (!wantsRemix && rejectRegex.test(`${title} ${artist}`)) {
        continue;
      }
      if (seen.has(trackId)) continue;
      seen.add(trackId);

      const mins = Math.floor(durSec / 60);
      const secs = durSec % 60;
      const images: any[] = Array.isArray(item?.image) ? item.image : [];
      const highResArt =
        (images.length > 0 ? String(images[images.length - 1]?.url || '') : '') ||
        'https://i.ytimg.com/vi/fJ9rUzIMcZQ/hqdefault.jpg';

      songMetaCache.set(trackId, { title, artist, durationSeconds: durSec });
      songs.push({
        id: trackId,
        title,
        artist,
        channelId: trackId,
        thumbnailUrl: highResArt,
        durationSeconds: durSec,
        durationFormatted: `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`,
        viewCount: Number(item?.playCount || 250000),
      });
    }
    return songs;
  } catch {
    return [];
  }
}

// Helper: YouTube Search via InnerTube with hard timeout & live catalog fallback
async function searchYouTube(
  rawQuery: string,
  options: { retries?: number; timeoutMs?: number; skipSaavnFallback?: boolean } = {}
) {
  const query = normalizeServerPhoneticQuery(rawQuery);
  const timeoutMs = options.timeoutMs ?? 2800;
  const retries = options.retries ?? 0;
  try {
    const res = await withSoftDeadline(
      fetchWithRetry(
        'https://www.youtube.com/youtubei/v1/search',
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
          body: JSON.stringify({
            context: {
              client: {
                clientName: 'WEB',
                clientVersion: '2.20240920.01.00',
                hl: 'en',
                gl: 'US',
              },
            },
            query,
          }),
        },
        { retries, timeoutMs }
      ),
      timeoutMs * (retries + 1) + 400,
      null as any
    );

    if (res && res.ok) {
      const data = await res.json();
      const songs: any[] = [];
      const seenIds = new Set<string>();

      const extractText = (node: any): string => {
        if (!node) return '';
        if (typeof node === 'string') return node;
        if (node.simpleText) return node.simpleText;
        if (Array.isArray(node.runs)) {
          return node.runs.map((r: any) => r.text || '').join('');
        }
        return '';
      };

      const parseDuration = (formatted: string): number => {
        const parts = formatted.split(':').map((p) => parseInt(p, 10));
        if (parts.length === 2) return (parts[0] || 0) * 60 + (parts[1] || 0);
        if (parts.length === 3) return (parts[0] || 0) * 3600 + (parts[1] || 0) * 60 + (parts[2] || 0);
        return 210;
      };

      const traverse = (node: any) => {
        if (!node || typeof node !== 'object') return;
        const wantsLiveStreamQuery = /\b(?:live\s+stream|livestream|24\/7|radio)\b/i.test(query);
        if (node.videoRenderer) {
          const vr = node.videoRenderer;
          const videoId = vr.videoId;
          const title = extractText(vr.title);
          const author = extractText(vr.ownerText) || extractText(vr.shortBylineText) || 'Various Artists';
          const rawLengthText = extractText(vr.lengthText);
          const hasLiveBadge = Array.isArray(vr.badges)
            ? vr.badges.some((b: any) =>
                String(b?.metadataBadgeRenderer?.style || '').includes('LIVE') ||
                String(b?.metadataBadgeRenderer?.label || '').toUpperCase() === 'LIVE'
              )
            : false;
          const isLiveBroadcast = !rawLengthText || hasLiveBadge;
          const durationFormatted = rawLengthText || '03:30';

          if (
            videoId &&
            title &&
            videoId.length === 11 &&
            !seenIds.has(videoId) &&
            (!isLiveBroadcast || wantsLiveStreamQuery)
          ) {
            seenIds.add(videoId);
            const durSec = parseDuration(durationFormatted);
            songMetaCache.set(videoId, {
              title,
              artist: author,
              durationSeconds: durSec,
            });
            songs.push({
              id: videoId,
              title,
              artist: author,
              channelId: `yt_${videoId}`,
              thumbnailUrl: `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`,
              durationSeconds: durSec,
              durationFormatted,
              viewCount: 150000,
            });
          }
        }
        for (const key of Object.keys(node)) {
          traverse(node[key]);
        }
      };

      traverse(data);
      if (songs.length > 0) return songs;
    }
  } catch (err) {
    console.error('YouTube search error:', err);
  }

  if (!options.skipSaavnFallback) {
    // Live full-length catalog fallback when YouTube search fails or times out
    const liveSaavn = await searchSaavnFallback(query, { retries: 0, timeoutMs: 2500 });
    if (liveSaavn.length > 0) return liveSaavn;
  }

  // Final static fallback filtering
  return options.skipSaavnFallback ? [] : getStaticFallbackMatches(query);
}

const COMPILATION_MIX_REGEX =
  /\b(?:jukebox|non[-\s]?stop|mega[-\s]?mix|mashup\s+mix|all\s+songs|top\s+\d+\s+hits|best\s+of\s+20\d{2}|viral\s+songs\s+mix|full\s+album|\d+\s*(?:hr|hour|hours)|bollywood\s+mix)\b/i;

function mergeSingleAndCatalogTracks(ytSongs: any[], saavnSongs: any[], wantsMix: boolean, limit: number): any[] {
  const filteredYt = wantsMix
    ? ytSongs
    : ytSongs.filter(
        (s) =>
          (s.durationSeconds || 0) <= 720 &&
          !COMPILATION_MIX_REGEX.test(String(s.title || ''))
      );

  const boundedFallbackYt = wantsMix
    ? ytSongs
    : ytSongs.filter((s) => (s.durationSeconds || 0) <= 900);

  const combined: any[] = [];
  const seenKeys = new Set<string>();
  for (const item of [...filteredYt, ...saavnSongs, ...boundedFallbackYt, ...FALLBACK_POPULAR]) {
    if (!item?.id || seenKeys.has(item.id)) continue;
    const dedupeTitle = `${String(item.title || '').toLowerCase().trim()}|${item.durationSeconds || 0}`;
    if (seenKeys.has(dedupeTitle)) continue;
    seenKeys.add(item.id);
    seenKeys.add(dedupeTitle);
    combined.push(item);
    if (combined.length >= limit) break;
  }
  return combined;
}

// Search API Endpoint
app.get('/api/search', async (req: Request, res: Response) => {
  const query = ((req.query.q as string) || '').trim();
  if (!query) {
    res.json({ success: true, songs: [] });
    return;
  }

  const cacheKey = `search:${normalizeServerPhoneticQuery(query).toLowerCase()}`;
  const cached = searchResponseCache.get(cacheKey);
  if (cached && Date.now() - cached.cachedAt < SEARCH_CACHE_TTL_MS && cached.songs.length > 0) {
    res.json({ success: true, query, songs: cached.songs });
    return;
  }

  let pending = inFlightSearchQueries.get(cacheKey);
  if (!pending) {
    const wantsMix = /\b(?:mix|jukebox|playlist|mashup|nonstop|non-stop|hour|album)\b/i.test(query);
    pending = withSoftDeadline(
      Promise.all([
        searchYouTube(query, { retries: 0, timeoutMs: 1800, skipSaavnFallback: !wantsMix }),
        wantsMix ? Promise.resolve([]) : searchSaavnFallback(query, { retries: 0, timeoutMs: 1800 }),
      ]).then(([ytSongs, saavnSongs]) => {
        const merged = mergeSingleAndCatalogTracks(ytSongs, saavnSongs, wantsMix, 24);
        return merged.length > 0 ? merged : getStaticFallbackMatches(query);
      }),
      2200,
      getStaticFallbackMatches(query)
    )
      .then((songs) => {
        if (songs.length > 0) {
          searchResponseCache.set(cacheKey, { songs, cachedAt: Date.now() });
        }
        return songs;
      })
      .finally(() => {
        if (inFlightSearchQueries.get(cacheKey) === pending) {
          inFlightSearchQueries.delete(cacheKey);
        }
      });
    inFlightSearchQueries.set(cacheKey, pending);
  }

  const combined = await pending;
  res.json({ success: true, query, songs: combined });
});

// Trending Songs API Endpoint â€” guarantees real playable single tracks (no unplayable 2-hour mixes)
app.get('/api/trending', async (_req: Request, res: Response) => {
  const cacheKey = 'trending:global';
  const cached = searchResponseCache.get(cacheKey);
  if (cached && Date.now() - cached.cachedAt < TRENDING_CACHE_TTL_MS && cached.songs.length > 0) {
    res.json({ success: true, songs: cached.songs });
    return;
  }

  let pending = inFlightSearchQueries.get(cacheKey);
  if (!pending) {
    pending = withSoftDeadline(
      Promise.all([
        searchYouTube('Top Global Music Hits Official Audio', {
          retries: 0,
          timeoutMs: 1800,
          skipSaavnFallback: true,
        }),
        searchSaavnFallback('Trending Hits', { retries: 0, timeoutMs: 1800 }),
      ]).then(([ytTrending, saavnTrending]) => {
        const singleYt = ytTrending.filter(
          (s) =>
            (s.durationSeconds || 0) >= 60 &&
            (s.durationSeconds || 0) <= 600 &&
            !COMPILATION_MIX_REGEX.test(String(s.title || ''))
        );
        const songs: any[] = [];
        const seen = new Set<string>();
        for (const s of [...saavnTrending, ...singleYt, ...FALLBACK_POPULAR]) {
          if (!s?.id || seen.has(s.id)) continue;
          seen.add(s.id);
          songs.push(s);
          if (songs.length >= 16) break;
        }
        return songs.length > 0 ? songs : FALLBACK_POPULAR;
      }),
      2200,
      FALLBACK_POPULAR
    )
      .then((songs) => {
        if (songs.length > 0) {
          searchResponseCache.set(cacheKey, { songs, cachedAt: Date.now() });
        }
        return songs;
      })
      .finally(() => {
        if (inFlightSearchQueries.get(cacheKey) === pending) {
          inFlightSearchQueries.delete(cacheKey);
        }
      });
    inFlightSearchQueries.set(cacheKey, pending);
  }

  const songs = await pending;
  res.json({ success: true, songs: songs.length > 0 ? songs : FALLBACK_POPULAR });
});

// Dynamic Taste Recommendations API Endpoint
app.post('/api/recommendations/dynamic', async (req: Request, res: Response) => {
  try {
    const { artists, vibe } = req.body || {};
    const queries: string[] = [];

    if (vibe) {
      const lowerV = String(vibe).toLowerCase();
      if (lowerV.includes('bengali') || lowerV.includes('bangla')) {
        queries.push('bangla trending songs hits', 'bengali acoustic soulful hits', 'anupam roy arijit bangla');
      } else if (lowerV.includes('lofi') || lowerV.includes('lo-fi')) {
        queries.push('lofi chill beats study', 'lo-fi acoustic relaxing');
      } else if (lowerV.includes('romantic')) {
        queries.push('romantic acoustic love songs', 'heartfelt love ballads');
      } else {
        queries.push(String(vibe));
      }
    }

    if (Array.isArray(artists) && artists.length > 0) {
      queries.push(`${artists[0]} best songs`);
      if (artists[1]) queries.push(`${artists[1]} hits`);
    }

    if (queries.length === 0) {
      queries.push('Top Acoustic Pop Hits 2024');
    }

    const targetQuery = queries[Math.floor(Math.random() * queries.length)];
    const cacheKey = `dynamic:${normalizeServerPhoneticQuery(targetQuery).toLowerCase()}`;
    const cached = searchResponseCache.get(cacheKey);
    if (cached && Date.now() - cached.cachedAt < SEARCH_CACHE_TTL_MS && cached.songs.length > 0) {
      res.json({
        success: true,
        queryUsed: targetQuery,
        songs: cached.songs,
      });
      return;
    }

    let pending = inFlightSearchQueries.get(cacheKey);
    if (!pending) {
      pending = withSoftDeadline(
        Promise.all([
          searchYouTube(targetQuery, { retries: 0, timeoutMs: 2600, skipSaavnFallback: true }),
          searchSaavnFallback(targetQuery, { retries: 0, timeoutMs: 2600 }),
        ]).then(([ytSongs, saavnSongs]) => {
          const merged = mergeSingleAndCatalogTracks(ytSongs, saavnSongs, false, 18);
          return merged.length > 0 ? merged : FALLBACK_POPULAR;
        }),
        3200,
        FALLBACK_POPULAR
      )
        .then((songs) => {
          if (songs.length > 0) {
            searchResponseCache.set(cacheKey, { songs, cachedAt: Date.now() });
          }
          return songs;
        })
        .finally(() => {
          if (inFlightSearchQueries.get(cacheKey) === pending) {
            inFlightSearchQueries.delete(cacheKey);
          }
        });
      inFlightSearchQueries.set(cacheKey, pending);
    }

    const songs = await pending;
    res.json({
      success: true,
      queryUsed: targetQuery,
      songs: songs.length > 0 ? songs : FALLBACK_POPULAR,
    });
  } catch {
    res.status(500).json({ success: false, error: 'Could not generate dynamic mix' });
  }
});

// ===== Smart Radio API â€” YouTube-style "Up Next" based on song language/artist/genre =====
app.get('/api/radio', async (req: Request, res: Response) => {
  let categoryFallback = FALLBACK_POPULAR;
  try {
    const title = String(req.query.title || '').trim();
    const artist = String(req.query.artist || '').trim();
    const currentId = String(req.query.currentId || '').trim();

    // 1. Detect language / category from title + artist
    const combined = `${title} ${artist}`.toLowerCase();
    const isBengali =
      /[\u0980-\u09FF]/.test(combined) ||
      /\b(bangla|bengali|rabindra|nazrul|baul|coke\s*studio\s*bangla|anupam\s*roy|arijit\s*singh|artcell|warfaze|miles|shironamhin|fossils|black|cactus|chandrabindoo|lakkhichhara|bappa\s*mazumder|nachiketa|iman\s*chakraborty|rupam\s*islam|tahsan|habib\s*wahid|minar|hridoy\s*khan|arnob|chandrabindoo|shunno|nemesis|cryptic\s*fate|powersurge|avoid\s*rafa|de\s*facto|mizan|razeeb|level\s*five)\b/i.test(combined);
    const isHindi =
      /[\u0900-\u097F]/.test(combined) ||
      /\b(hindi|bollywood|arijit|atif\s*aslam|shreya\s*ghoshal|kumar\s*sanu|sonu\s*nigam|kishore\s*kumar|lata\s*mangeshkar|neha\s*kakkar|jubin\s*nautiyal|b\s*praak|darshan\s*raval|armaan\s*malik|badshah|yo\s*yo\s*honey|shankar\s*mahadevan|ar\s*rahman|amit\s*trivedi|vishal\s*mishra|anuv\s*jain|sachin-jigar|tanishk|pritam)\b/i.test(combined);
    const isKorean =
      /[\uAC00-\uD7AF]/.test(combined) ||
      /\b(k-?pop|bts|blackpink|twice|stray\s*kids|enhypen|txt|ateez|aespa|itzy|newjeans|seventeen|exo|red\s*velvet|nct)\b/i.test(combined);
    const isJapanese =
      /[\u3040-\u309F\u30A0-\u30FF]/.test(combined) ||
      /\b(j-?pop|j-?rock|yoasobi|ado|fujii\s*kaze|kenshi\s*yonezu|lisa|one\s*ok\s*rock)\b/i.test(combined);
    const isSpanish =
      /\b(reggaeton|latin|bad\s*bunny|j\s*balvin|ozuna|daddy\s*yankee|shakira|maluma|karol\s*g|rosalia|rauw\s*alejandro)\b/i.test(combined);

    categoryFallback = isBengali ? FALLBACK_BANGLA_BAND : isHindi ? FALLBACK_HINDI : FALLBACK_POPULAR;

    if (!title && !artist) {
      res.json({ success: true, songs: categoryFallback });
      return;
    }

    // 2. Detect genre/mood
    const isRock = /\b(rock|metal|band|grunge|punk|alternative|classic\s*rock|hard\s*rock)\b/i.test(combined);
    const isLofi = /\b(lofi|lo-fi|chill\s*beats|study\s*beats|chillhop)\b/i.test(combined);
    const isRomantic = /\b(romantic|love|pyaar|prem|valobasha|ishq|valentine)\b/i.test(combined);
    const isRap = /\b(rap|hip\s*hop|trap|drill|eminem|kanye|drake|kendrick|j\s*cole|travis)\b/i.test(combined);
    const isEDM = /\b(edm|electronic|house|techno|trance|dubstep|martin\s*garrix|avicii|marshmello|alan\s*walker)\b/i.test(combined);

    // 3. Build smart search queries for radio
    const queries: string[] = [];
    const { coreTitle, primaryArtist } = extractCoreTrackAndArtist(title, artist);
    const cleanArtist = primaryArtist || artist;

    // Always start with artist radio
    if (cleanArtist && cleanArtist.length > 1) {
      queries.push(`${cleanArtist} best songs`);
      queries.push(`${cleanArtist} top hits`);
    }

    // Language-specific radio queries
    if (isBengali) {
      queries.push('best bangla songs', 'bangla band songs hits', 'bengali acoustic soulful hits', 'bengali modern songs trending');
      if (isRock) queries.push('bangla rock band songs artcell warfaze miles', 'bengali band hits');
      if (isRomantic) queries.push('bengali romantic songs hits', 'bangla love songs best');
    } else if (isHindi) {
      queries.push('hindi hits songs', 'bollywood best songs', 'new hindi songs trending');
      if (isRomantic) queries.push('hindi romantic songs best', 'bollywood love songs hits');
      if (isRap) queries.push('hindi rap songs trending');
    } else if (isKorean) {
      queries.push('kpop hits songs', 'best kpop songs trending', 'kpop new releases');
    } else if (isJapanese) {
      queries.push('jpop hits songs', 'japanese popular songs', 'anime openings best');
    } else if (isSpanish) {
      queries.push('latin hits songs', 'reggaeton trending hits', 'spanish music popular');
    } else {
      // Default: English / global
      queries.push('top pop songs hits', 'best english songs trending');
      if (isRock) queries.push('rock hits songs best', 'alternative rock popular');
      if (isLofi) queries.push('lofi chill beats study relax', 'lo-fi hip hop chill');
      if (isRomantic) queries.push('love songs best romantic hits', 'romantic acoustic songs');
      if (isRap) queries.push('hip hop rap hits trending', 'rap songs best');
      if (isEDM) queries.push('edm electronic dance hits', 'electronic music popular');
    }

    // Also add a mix query combining artist + genre context
    if (cleanArtist && cleanArtist.length > 1) {
      if (isBengali) queries.push(`${cleanArtist} bangla songs`);
      else if (isHindi) queries.push(`${cleanArtist} hindi songs`);
      else queries.push(`${cleanArtist} similar songs`);
    }

    // 4. Pick queries: q1 targets the artist specifically, q2 targets the category/genre/language
    const artistQuery = cleanArtist && cleanArtist.length > 1 ? `${cleanArtist} best songs` : null;
    const categoryQueries = queries.filter((q) => q !== artistQuery).sort(() => Math.random() - 0.5);
    const q1 = artistQuery || categoryQueries[0] || 'top music hits';
    const q2 = categoryQueries[0] || categoryQueries[1] || `${cleanArtist || 'music'} popular songs`;

    const cacheKey = `radio:${normalizeServerPhoneticQuery(`${cleanArtist}|${isBengali ? 'bn' : isHindi ? 'hi' : isKorean ? 'ko' : 'en'}|${isRock ? 'rock' : 'pop'}`).toLowerCase()}`;
    const cached = searchResponseCache.get(cacheKey);
    if (cached && Date.now() - cached.cachedAt < SEARCH_CACHE_TTL_MS && cached.songs.length > 0) {
      // Filter out the currently playing song and return
      const filtered = cached.songs.filter((s: any) => s.id !== currentId);
      const shuffledSongs = filtered.sort(() => Math.random() - 0.5);
      res.json({ success: true, songs: shuffledSongs.length > 0 ? shuffledSongs : cached.songs });
      return;
    }

    const fetchTasks: Promise<any[]>[] = [
      searchYouTube(q1, { retries: 0, timeoutMs: 2800, skipSaavnFallback: true }),
      searchYouTube(q2, { retries: 0, timeoutMs: 2800, skipSaavnFallback: true }),
    ];
    // Only invoke Saavn for Bengali or Hindi tracks â€” never for English, K-Pop, etc.
    if (isBengali || isHindi) {
      const saavnQuery = cleanArtist && cleanArtist.length > 1 ? cleanArtist : q1;
      fetchTasks.push(searchSaavnFallback(saavnQuery, { retries: 0, timeoutMs: 2400 }));
    }

    const results = await withSoftDeadline(
      Promise.all(fetchTasks).then(([yt1, yt2, saavn = []]) => {
        // Prioritize official studio tracks from Saavn over live/concert YouTube videos
        const all = [...(saavn || []), ...(yt1 || []), ...(yt2 || [])];
        // Deduplicate by id, filter out current song, and limit to single tracks
        const seen = new Set<string>();
        const singles: any[] = [];
        for (const s of all) {
          if (!s?.id || seen.has(s.id) || s.id === currentId) continue;
          if ((s.durationSeconds || 0) < 60 || (s.durationSeconds || 0) > 600) continue;
          if (COMPILATION_MIX_REGEX.test(String(s.title || ''))) continue;
          seen.add(s.id);
          singles.push(s);
          if (singles.length >= 25) break;
        }
        return singles;
      }),
      4500,
      categoryFallback.filter((s: any) => s.id !== currentId)
    );

    if (results.length > 0) {
      searchResponseCache.set(cacheKey, { songs: results, cachedAt: Date.now() });
    }

    // Shuffle for variety on each request
    const shuffledResult = results.sort(() => Math.random() - 0.5);
    res.json({ success: true, songs: shuffledResult.length > 0 ? shuffledResult : categoryFallback });
  } catch (err) {
    console.error('Radio API error:', err);
    res.json({ success: true, songs: categoryFallback });
  }
});

// Real Synced & Plain Lyrics API Endpoint (mirrors lib/core/services/lyrics_service.dart)
app.get('/api/lyrics', async (req: Request, res: Response) => {
  const rawTitle = String(req.query.title || '').trim();
  const rawArtist = String(req.query.artist || '').trim();
  if (!rawTitle) {
    res.status(400).json({ success: false, error: 'Missing song title' });
    return;
  }

  const { coreTitle, primaryArtist } = extractCoreTrackAndArtist(rawTitle, rawArtist);
  const cleanTitle = stripParentheticalAndEntities(coreTitle || rawTitle).trim();
  const cleanArtist = stripParentheticalAndEntities(primaryArtist || rawArtist).trim();

  try {
    // 1. Exact get
    if (cleanTitle && cleanArtist) {
      const getUrl = `https://lrclib.net/api/get?track_name=${encodeURIComponent(
        cleanTitle
      )}&artist_name=${encodeURIComponent(cleanArtist)}`;
      const getRes = await fetch(getUrl, {
        headers: { 'User-Agent': 'TwilightMusic/3.6.1' },
        signal: AbortSignal.timeout(3500),
      });
      if (getRes.ok) {
        const data: any = await getRes.json();
        const plain = String(data?.plainLyrics || '').trim();
        const synced = String(data?.syncedLyrics || '').trim();
        if (plain || synced) {
          res.json({
            success: true,
            title: cleanTitle,
            artist: cleanArtist,
            plainLyrics: plain,
            syncedLyrics: synced,
          });
          return;
        }
      }
    }

    // 2. Search fallback
    const searchQueries = Array.from(
      new Set([
        cleanArtist ? `${cleanTitle} ${cleanArtist}` : cleanTitle,
        cleanTitle,
      ].filter(Boolean))
    );

    for (const q of searchQueries) {
      const searchUrl = `https://lrclib.net/api/search?q=${encodeURIComponent(q)}`;
      const searchRes = await fetch(searchUrl, {
        headers: { 'User-Agent': 'TwilightMusic/3.6.1' },
        signal: AbortSignal.timeout(3500),
      });
      if (!searchRes.ok) continue;
      const list: any[] = await searchRes.json();
      if (Array.isArray(list) && list.length > 0) {
        const hit = list.find((item) => item?.plainLyrics || item?.syncedLyrics);
        if (hit) {
          res.json({
            success: true,
            title: String(hit.trackName || cleanTitle),
            artist: String(hit.artistName || cleanArtist),
            plainLyrics: String(hit.plainLyrics || '').trim(),
            syncedLyrics: String(hit.syncedLyrics || '').trim(),
          });
          return;
        }
      }
    }
  } catch {
    // ignore network timeout
  }

  res.json({
    success: false,
    title: cleanTitle,
    artist: cleanArtist,
    plainLyrics: '',
    syncedLyrics: '',
  });
});

// Stream Disconnection & Diagnostics Telemetry Collector Endpoints
app.post('/api/diagnostics/stream', (req: Request, res: Response) => {
  const body = (req.body || {}) as Partial<ServerStreamDiagnostic> & { songId?: string };
  const category = String(body.category || 'client_event').slice(0, 64);
  const stage = String(body.stage || 'client').slice(0, 64);
  const message = String(body.message || 'Client stream diagnostic').slice(0, 240);
  const level = body.level === 'error' || body.level === 'warn' ? body.level : 'info';

  logStreamDiagnostic(level, category, `client:${stage}`, message, {
    videoId: body.songId ? String(body.songId).slice(0, 64) : undefined,
    statusCode: typeof body.statusCode === 'number' ? body.statusCode : undefined,
    attempt: typeof body.attempt === 'number' ? body.attempt : undefined,
    detail: body.detail ? String(body.detail).slice(0, 240) : undefined,
  });

  res.status(202).json({ accepted: true });
});

app.get('/api/diagnostics/stream', (_req: Request, res: Response) => {
  const summary = {
    totalEvents: streamDiagnosticsBuffer.length,
    disconnects: streamDiagnosticsBuffer.filter(
      (e) => e.category.includes('disconnect') || e.category === 'media_error' || e.category === 'proxy_exhausted'
    ).length,
    retries: streamDiagnosticsBuffer.filter((e) => e.category.includes('retry')).length,
    events: streamDiagnosticsBuffer.slice(-50),
  };
  res.json(summary);
});

// Proactive Stream URL Resolver Endpoint (returns a fresh, validated stream URL after extended pause)
app.get('/api/stream/:videoId/resolve', async (req: Request, res: Response) => {
  const videoId = req.params.videoId;
  if (!videoId) {
    res.status(400).json({ success: false, error: 'Invalid YouTube video ID' });
    return;
  }

  const rawTitle = (req.query.title as string) || '';
  const rawArtist = (req.query.artist as string) || '';
  const rawDuration = Number(req.query.duration || 0) || undefined;
  const isRefresh = Boolean(req.query.refresh);
  const resolved = await resolveExactTrackStreamUrl(
    videoId,
    rawTitle,
    rawArtist,
    isRefresh,
    rawDuration
  );

  res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate');
  const now = Date.now();
  const params = new URLSearchParams({
    ...(isRefresh ? { refresh: '1' } : {}),
    t: String(now),
    ...(rawTitle ? { title: rawTitle } : {}),
    ...(rawArtist ? { artist: rawArtist } : {}),
    ...(rawDuration ? { duration: String(rawDuration) } : {}),
  });
  const freshStreamUrl = `/api/stream/${encodeURIComponent(videoId)}?${params.toString()}`;
  const isGooglevideo = Boolean(resolved?.url && resolved.url.includes('googlevideo.com'));
  const isLocalStudioAudio = Boolean(resolved?.url && resolved.url.startsWith('/audio/'));
  const isDirectHttpOrAudio = Boolean(
    resolved?.url && !isGooglevideo && (resolved.url.startsWith('https://') || isLocalStudioAudio)
  );

  res.json({
    success: true,
    videoId,
    exactMaster: Boolean(isLocalStudioAudio || knownDirectCdnMap[videoId]),
    playable: Boolean(isDirectHttpOrAudio || isGooglevideo || (resolved?.buffer && resolved.buffer.length > 0)),
    streamUrl: freshStreamUrl,
    directCdnUrl: isLocalStudioAudio
      ? resolved!.url
      : isDirectHttpOrAudio || isGooglevideo || (resolved?.buffer && resolved.buffer.length > 0)
      ? freshStreamUrl
      : null,
    resolvedAt: now,
    proactiveRefreshThresholdMs: 180000,
  });
});

// Audio Stream API Endpoint â€” Resolves & proxies the exact clicked track with HTTP byte-range support
app.get('/api/stream/:videoId', async (req: Request, res: Response) => {
  const videoId = req.params.videoId;
  if (!videoId) {
    res.status(400).json({ error: 'Invalid YouTube video ID' });
    return;
  }

  const isForceRefresh = Boolean(req.query.refresh || req.query.retry);
  if (isForceRefresh) {
    res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate');
  }

  const rawTitle = (req.query.title as string) || '';
  const rawArtist = (req.query.artist as string) || '';
  const rawDuration = Number(req.query.duration || 0) || undefined;

  // Resolve exact track stream URL via multi-source resolver (Studio Masters -> 320kbps AAC CDN -> SoundCloud -> YouTube)
  const resolvedStream = await resolveExactTrackStreamUrl(
    videoId,
    rawTitle,
    rawArtist,
    isForceRefresh,
    rawDuration
  );

  // Serve local full-length studio master file directly with HTTP byte-range support
  if (resolvedStream?.url && resolvedStream.url.startsWith('/audio/')) {
    const relAudioFile = resolvedStream.url.replace(/^\/audio\//, '');
    const masterFilePath = path.resolve(__dirname, 'public/audio', relAudioFile);
    if (fs.existsSync(masterFilePath)) {
      res.sendFile(
        masterFilePath,
        {
          headers: {
            'Content-Type': resolvedStream.mimeType || 'audio/mp4',
            'Accept-Ranges': 'bytes',
            'Cache-Control': isForceRefresh ? 'no-store, no-cache, must-revalidate' : 'public, max-age=86400',
          },
        },
        (sendErr: any) => {
          if (sendErr && !res.headersSent) {
            res.status(sendErr.statusCode || sendErr.status || 500).end();
          }
        }
      );
      return;
    }
  }

  let clientClosed = false;
  const clientAbortController = new AbortController();
  req.on('close', () => {
    clientClosed = true;
    try {
      clientAbortController.abort();
    } catch {}
  });
  res.on('error', (sockErr: any) => {
    clientClosed = true;
    logStreamDiagnostic('warn', 'client_socket_error', 'proxyStream', 'Client response socket error', {
      videoId,
      detail: sockErr?.code || sockErr?.message || String(sockErr),
    });
    try {
      clientAbortController.abort();
    } catch {}
  });

  const serveInMemoryBuffer = (resolvedBuf: ResolvedStreamEntry): boolean => {
    if (!resolvedBuf.buffer || resolvedBuf.buffer.length === 0) return false;
    const buf = resolvedBuf.buffer;
    const total = buf.length;
    res.setHeader('Content-Type', resolvedBuf.mimeType || 'audio/mp4');
    res.setHeader('Accept-Ranges', 'bytes');
    res.setHeader(
      'Cache-Control',
      isForceRefresh ? 'no-store, no-cache, must-revalidate' : 'public, max-age=3600'
    );

    const rangeHeader = req.headers.range;
    if (rangeHeader) {
      const m = /bytes=(\d*)-(\d*)/.exec(String(rangeHeader));
      const rawStart = m && m[1] ? parseInt(m[1], 10) : 0;
      if (rawStart >= total) {
        res.status(416);
        res.setHeader('Content-Range', `bytes */${total}`);
        res.end();
        return true;
      }
      const start = Math.max(0, rawStart);
      const end = m && m[2] ? Math.min(parseInt(m[2], 10), total - 1) : total - 1;
      if (start <= end) {
        const chunk = buf.subarray(start, end + 1);
        res.status(206);
        res.setHeader('Content-Range', `bytes ${start}-${end}/${total}`);
        res.setHeader('Content-Length', String(chunk.length));
        res.end(chunk);
        return true;
      }
    }

    res.status(200);
    res.setHeader('Content-Length', String(total));
    res.end(buf);
    return true;
  };

  // Serve assembled in-memory fMP4 buffer with full HTTP 206 Partial Content byte-range support
  if (resolvedStream && serveInMemoryBuffer(resolvedStream)) {
    return;
  }

  let activeResolved = resolvedStream;
  const maxProxyAttempts = 3;
  for (let proxyAttempt = 0; proxyAttempt < maxProxyAttempts && !clientClosed; proxyAttempt++) {
    let shouldForceRefresh = false;

    if (activeResolved?.url && activeResolved.url.startsWith('/audio/')) {
      const relAudioFile = activeResolved.url.replace(/^\/audio\//, '');
      const masterFilePath = path.resolve(__dirname, 'public/audio', relAudioFile);
      if (fs.existsSync(masterFilePath)) {
        res.sendFile(
          masterFilePath,
          {
            headers: {
              'Content-Type': activeResolved.mimeType || 'audio/mp4',
              'Accept-Ranges': 'bytes',
              'Cache-Control': isForceRefresh ? 'no-store, no-cache, must-revalidate' : 'public, max-age=86400',
            },
          },
          (sendErr: any) => {
            if (sendErr && !res.headersSent) {
              res.status(sendErr.statusCode || sendErr.status || 500).end();
            }
          }
        );
        return;
      }
    }

    if (activeResolved && serveInMemoryBuffer(activeResolved)) {
      return;
    }

    if (activeResolved?.url && activeResolved.url.startsWith('https://')) {
      try {
        const upstreamHeaders: Record<string, string> = {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
          Accept: '*/*',
          ...(activeResolved.headers || {}),
        };
        if (req.headers.range) {
          upstreamHeaders['Range'] = String(req.headers.range);
        }

        const upstreamRes = await fetchWithRetry(
          activeResolved.url,
          { headers: upstreamHeaders },
          { retries: 1, timeoutMs: 8500, baseDelayMs: 250, signal: clientAbortController.signal }
        );

        if (upstreamRes.status === 401 || upstreamRes.status === 403 || upstreamRes.status === 404 || upstreamRes.status === 410) {
          try {
            await upstreamRes.body?.cancel();
          } catch {}
          logStreamDiagnostic('warn', 'upstream_expired_status', 'proxyStream', `Upstream URL rejected request`, {
            videoId,
            statusCode: upstreamRes.status,
            attempt: proxyAttempt + 1,
          });
          shouldForceRefresh = true;
        } else if (upstreamRes.ok || upstreamRes.status === 206) {
          if (upstreamRes.body) {
            const reader = upstreamRes.body.getReader();
            const onAbort = () => reader.cancel().catch(() => {});
            clientAbortController.signal.addEventListener('abort', onAbort, { once: true });
            let headersFlushed = false;
            let bytesSent = 0;

            const flushUpstreamHeaders = () => {
              if (headersFlushed || res.headersSent) return;
              headersFlushed = true;
              res.status(upstreamRes.status);
              res.setHeader(
                'Content-Type',
                upstreamRes.headers.get('content-type') || activeResolved?.mimeType || 'audio/mp4'
              );
              res.setHeader('Accept-Ranges', 'bytes');
              const contentLen = upstreamRes.headers.get('content-length');
              if (contentLen) res.setHeader('Content-Length', contentLen);
              const contentRange = upstreamRes.headers.get('content-range');
              if (contentRange) res.setHeader('Content-Range', contentRange);
              res.setHeader(
                'Cache-Control',
                isForceRefresh ? 'no-store, no-cache, must-revalidate' : 'public, max-age=3600'
              );
            };

            let streamFailedBeforeFirstByte = false;
            try {
              while (!clientClosed) {
                const readPromise = reader.read();
                let chunkTimer: ReturnType<typeof setTimeout> | null = null;
                const timeoutPromise = new Promise<{ done: boolean; value?: Uint8Array }>((_, reject) => {
                  chunkTimer = setTimeout(() => reject(new Error('Stream read timeout')), 45000);
                });
                let readResult: { done: boolean; value?: Uint8Array };
                try {
                  readResult = await Promise.race([readPromise, timeoutPromise]);
                } finally {
                  if (chunkTimer) {
                    clearTimeout(chunkTimer);
                    chunkTimer = null;
                  }
                }
                const { done, value } = readResult;
                if (done) break;
                if (value && value.byteLength > 0) {
                  flushUpstreamHeaders();
                  bytesSent += value.byteLength;
                  const canContinue = res.write(Buffer.from(value));
                  if (!canContinue && !clientClosed) {
                    await new Promise<void>((resolve) => {
                      const cleanup = () => {
                        res.removeListener('drain', cleanup);
                        res.removeListener('close', cleanup);
                        res.removeListener('error', cleanup);
                        resolve();
                      };
                      res.once('drain', cleanup);
                      res.once('close', cleanup);
                      res.once('error', cleanup);
                    });
                  }
                }
              }
              if (!headersFlushed && !clientClosed) {
                flushUpstreamHeaders();
              }
            } catch (streamErr: any) {
              if (!headersFlushed && !clientClosed) {
                streamFailedBeforeFirstByte = true;
                shouldForceRefresh = true;
                logStreamDiagnostic('warn', 'pre_byte_disconnect', 'proxyStream', 'Upstream disconnected before first byte', {
                  videoId,
                  attempt: proxyAttempt + 1,
                  bytesSent,
                  detail: streamErr?.message || String(streamErr),
                });
              } else if (!clientClosed) {
                logStreamDiagnostic('warn', 'mid_stream_disconnect', 'proxyStream', 'Upstream disconnected mid-stream after headers flushed', {
                  videoId,
                  attempt: proxyAttempt + 1,
                  bytesSent,
                  detail: streamErr?.message || String(streamErr),
                });
              }
            } finally {
              clientAbortController.signal.removeEventListener('abort', onAbort);
              reader.cancel().catch(() => {});
            }

            if (streamFailedBeforeFirstByte) {
              // Fall through to re-resolve/retry or reach final 502 error response since headers were not sent
            } else {
              if (!res.writableEnded) {
                res.end();
              }
              return;
            }
          }
        } else if (upstreamRes.status === 416) {
          const contentRange = upstreamRes.headers.get('content-range') || 'bytes */*';
          upstreamRes.body?.cancel().catch(() => {});
          if (!clientClosed && !res.headersSent) {
            res.status(416);
            res.setHeader('Content-Range', contentRange);
            res.end();
          }
          return;
        } else {
          upstreamRes.body?.cancel().catch(() => {});
          logStreamDiagnostic('warn', 'upstream_http_error', 'proxyStream', 'Unexpected upstream HTTP status during proxy', {
            videoId,
            statusCode: upstreamRes.status,
            attempt: proxyAttempt + 1,
          });
          shouldForceRefresh = true;
        }
      } catch (proxyErr: any) {
        if (clientClosed) return;
        logStreamDiagnostic('warn', 'proxy_attempt_disconnect', 'proxyStream', 'Proxy upstream fetch threw disconnection error', {
          videoId,
          attempt: proxyAttempt + 1,
          detail: proxyErr?.message || String(proxyErr),
        });
        shouldForceRefresh = true;
      }
    } else {
      if (proxyAttempt >= 1) {
        break;
      }
      shouldForceRefresh = true;
    }

    if (proxyAttempt < maxProxyAttempts - 1 && !clientClosed) {
      const backoffMs = Math.min(1200, 220 * Math.pow(2, proxyAttempt));
      await new Promise((resolve) => setTimeout(resolve, backoffMs));
      if (clientClosed) return;
      if (shouldForceRefresh || !activeResolved) {
        activeResolved = await resolveExactTrackStreamUrl(
          videoId,
          rawTitle,
          rawArtist,
          true,
          rawDuration
        );
      }
    }
  }

  if (!clientClosed && !res.headersSent) {
    logStreamDiagnostic('error', 'proxy_exhausted', 'proxyStream', 'All proxy attempts exhausted returning HTTP 502', {
      videoId,
      statusCode: 502,
      attempt: maxProxyAttempts,
    });
    res.status(502).json({ error: 'Audio stream unavailable' });
  } else if (!res.writableEnded) {
    res.end();
  }
});

// Audio File Download API Endpoint (Instant high-speed download of the exact song with Content-Disposition attachment)
app.get('/api/download/:videoId', async (req: Request, res: Response) => {
  const videoId = req.params.videoId;
  if (!videoId) {
    res.status(400).json({ error: 'Invalid video ID' });
    return;
  }

  const rawTitle = (req.query.title as string) || 'Twilight_Track';
  const rawArtist = (req.query.artist as string) || '';
  const rawDuration = Number(req.query.duration || 0) || undefined;
  const cleanTitle = rawTitle.replace(/[^\w\s\-\(\)\[\]\.]/gi, '').trim() || 'Track';

  const resolvedStream = await resolveExactTrackStreamUrl(
    videoId,
    rawTitle,
    rawArtist,
    false,
    rawDuration
  );
  if (resolvedStream?.url && resolvedStream.url.startsWith('/audio/')) {
    const relAudioFile = resolvedStream.url.replace(/^\/audio\//, '');
    const masterFilePath = path.resolve(__dirname, 'public/audio', relAudioFile);
    if (fs.existsSync(masterFilePath)) {
      const ext = resolvedStream.mimeType.includes('mp4') ? 'm4a' : 'mp3';
      res.setHeader(
        'Content-Disposition',
        `attachment; filename="${encodeURIComponent(`${cleanTitle}.${ext}`)}"`
      );
      res.sendFile(masterFilePath, {
        headers: {
          'Content-Type': resolvedStream.mimeType || 'audio/mp4',
        },
      });
      return;
    }
  }

  if (resolvedStream?.buffer && resolvedStream.buffer.length > 0) {
    const ext = resolvedStream.mimeType.includes('mp4') ? 'm4a' : 'mp3';
    res.setHeader(
      'Content-Disposition',
      `attachment; filename="${encodeURIComponent(`${cleanTitle}.${ext}`)}"`
    );
    res.setHeader('Content-Type', resolvedStream.mimeType || 'audio/mp4');
    res.setHeader('Content-Length', String(resolvedStream.buffer.length));
    res.end(resolvedStream.buffer);
    return;
  }

  if (resolvedStream?.url && resolvedStream.url.startsWith('https://')) {
    try {
      const upstreamRes = await fetch(resolvedStream.url, {
        headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' },
        signal: AbortSignal.timeout(15000),
      });
      if (upstreamRes.ok && upstreamRes.body) {
        const ext = resolvedStream.mimeType.includes('mp4') ? 'm4a' : 'mp3';
        res.setHeader(
          'Content-Disposition',
          `attachment; filename="${encodeURIComponent(`${cleanTitle}.${ext}`)}"`
        );
        res.setHeader('Content-Type', resolvedStream.mimeType || 'audio/mp4');
        const contentLen = upstreamRes.headers.get('content-length');
        if (contentLen) res.setHeader('Content-Length', contentLen);

        const reader = upstreamRes.body.getReader();
        while (true) {
          const { done, value } = await reader.read();
          if (done) break;
          if (value) res.write(Buffer.from(value));
        }
        res.end();
        return;
      }
    } catch {
      // fallback below
    }
  }

  res.status(502).json({ error: 'Audio download unavailable' });
});

// Helper: Build live v3.0.0 project release archive (.tar.gz) containing current AI Studio codebase
function buildProjectReleaseArchive(): string {
  const archivePath = path.join(os.tmpdir(), 'Twilight-Music-v3.0.0-Full-Project.tar.gz');
  execFileSync(
    'tar',
    [
      '-czf',
      archivePath,
      '--exclude=./node_modules',
      '--exclude=./dist',
      '--exclude=./build',
      '--exclude=./.git',
      '--exclude=./.dart_tool',
      '--exclude=./.aistudio',
      '--exclude=./public/assets/aistudio',
      '-C',
      __dirname,
      '.',
    ],
    { stdio: 'ignore' }
  );
  return archivePath;
}

// Helper: Commit & push full app repository (Flutter + React + Express + audio masters + workflows) to GitHub
function pushFullAppRepositoryToGitHub(cleanRepo: string, ghToken: string, tagName: string): { pushedBranch: boolean; commitSha?: string; gitMessage?: string } {
  try {
    const tmpGitDir = path.join(os.tmpdir(), 'twilight_release_git');
    const baseArgs = [`--git-dir=${tmpGitDir}`, `--work-tree=${__dirname}`];
    const gitOpts = { cwd: __dirname, stdio: 'pipe' as const };
    if (!fs.existsSync(tmpGitDir)) {
      execFileSync('git', ['init', '--bare', '-b', 'main', tmpGitDir], gitOpts);
    }
    execFileSync('git', [...baseArgs, 'config', 'user.name', 'Hasibul Hasan'], gitOpts);
    execFileSync('git', [...baseArgs, 'config', 'user.email', 'gudhulibela031@gmail.com'], gitOpts);
    execFileSync('git', [...baseArgs, 'add', '-A'], gitOpts);
    execFileSync(
      'git',
      [...baseArgs, 'commit', '--allow-empty', '-m', `release: Twilight Music ${tagName} â€” Full App Production Release`],
      gitOpts
    );
    execFileSync('git', [...baseArgs, 'tag', '-f', tagName], gitOpts);
    const commitSha = execFileSync('git', [...baseArgs, 'rev-parse', '--short', 'HEAD'], gitOpts)
      .toString()
      .trim();

    const authRemoteUrl = `https://x-access-token:${encodeURIComponent(ghToken)}@github.com/${cleanRepo}.git`;
    execFileSync(
      'git',
      [
        ...baseArgs,
        'push',
        '--force',
        authRemoteUrl,
        'HEAD:refs/heads/main',
        `refs/tags/${tagName}:refs/tags/${tagName}`,
      ],
      { cwd: __dirname, stdio: 'pipe', timeout: 60000 }
    );
    return { pushedBranch: true, commitSha };
  } catch (err: any) {
    const rawMsg = String(err?.stderr ? err.stderr.toString() : err?.message || 'git push failed');
    const safeMsg = rawMsg.replace(/x-access-token:[^@]+@/g, 'x-access-token:***@');
    return { pushedBranch: false, gitMessage: safeMsg };
  }
}

// Release Metadata API Endpoint
app.get('/api/release/info', (_req: Request, res: Response) => {
  res.json({
    version: 'v3.6.1',
    legacyTag: 'v3.0.0',
    buildNumber: 61,
    releaseDate: new Date().toISOString().slice(0, 10),
    title: 'Twilight Music v3.6.1 â€” New Official Android APK, iOS IPA & Windows PC Release',
    highlights: [
      '100% Exact YouTube Video Audio Stream (videoId First): Prioritizes direct YouTube videoId streams across Android, iOS, Windows, and Web so live concerts, unplugged versions, and remixes always match YouTube',
      'Clean Click-to-Play Startup: Starts with currentSong = null so no track is pre-selected or shown in the player bar until clicked',
      'Native Multi-Platform Releases: Automated CI/CD builds for Android APK (Twilight-Android-v3.6.1.apk), Apple iOS IPA (Twilight-iOS-v3.6.1.ipa), and Windows x64 ZIP (Twilight-Windows-x64-v3.6.1.zip)',
      'Pause/Resume & Stall Recovery: Proactive stream URL refresh after >3 min pause with exact playback position preservation and bounded retry recovery',
      'Uninterrupted Background Playback: Android WAKE_LOCK + FOREGROUND_SERVICE_MEDIA_PLAYBACK permissions, AudioSession interruption/becoming-noisy handlers, and ongoing notification persistence',
      'Offline Downloads Integrity: Real file verification, one-tap Re-download badge for missing/corrupted files, and local AudioSource.file playback',
      'Monochrome Notification Icon: Added drawable/ic_stat_music.xml vector icon to fix the white square in Android status bar & notification shade',
      'Single Authoritative Audio Session: Monotonic playRequestId sequencing to eliminate overlapping audio on rapid track switches',
    ],
  });
});

// Live Full Project Release Archive Endpoint (always serves the latest AI Studio codebase)
app.get(
  [
    '/api/release/project-archive',
    '/landing/downloads/Twilight-Music-v3.0.0-Full-Project.tar.gz',
    '/landing/downloads/Twilight-Music-v2.4.0-Full-Project.tar.gz',
    '/landing/downloads/Twilight-Music-v1.0.3-Full-Project.zip',
  ],
  (_req: Request, res: Response) => {
    try {
      const archivePath = buildProjectReleaseArchive();
      res.setHeader(
        'Content-Disposition',
        'attachment; filename="Twilight-Music-v3.0.0-Full-Project.tar.gz"'
      );
      res.setHeader('Content-Type', 'application/gzip');
      res.sendFile(archivePath);
    } catch (err: any) {
      res.status(500).json({
        error: err?.message || 'Failed to package release archive',
      });
    }
  }
);

// Push Full App Codebase to GitHub & Publish v3.0.0 Release + Upload Archive directly to GitHub Releases
app.post('/api/release/github', async (req: Request, res: Response) => {
  try {
    const { repo = 'hasibcore/Twilight-Music', token, tagName = 'v3.0.0' } = req.body || {};
    const ghToken = (token || process.env.GITHUB_TOKEN || '').trim();

    if (!ghToken) {
      res.status(400).json({
        success: false,
        error: 'Please enter a GitHub Personal Access Token (with repo/contents write permission) to push the full app and publish the release to GitHub.',
      });
      return;
    }

    const cleanRepo = String(repo)
      .replace(/^https?:\/\/github\.com\//i, '')
      .replace(/\.git$/i, '')
      .trim();

    if (!/^[a-zA-Z0-9_.-]+\/[a-zA-Z0-9_.-]+$/.test(cleanRepo)) {
      res.status(400).json({
        success: false,
        error: 'Invalid repository format. Use owner/repo (e.g. hasibcore/Twilight).',
      });
      return;
    }

    const headers: Record<string, string> = {
      Authorization: `Bearer ${ghToken}`,
      Accept: 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
      'User-Agent': 'Twilight-Music-Release-Publisher',
    };

    // 1. Push full app git repository (main branch + v2.4.0 tag) directly to GitHub
    const gitPushStatus = pushFullAppRepositoryToGitHub(cleanRepo, ghToken, tagName);

    // 1b. Also ensure .github/workflows/build-apk.yml is synced via Contents API if git push was blocked
    const workflowLocalPath = path.resolve(__dirname, '.github/workflows/build-apk.yml');
    if (!gitPushStatus.pushedBranch && fs.existsSync(workflowLocalPath)) {
      const workflowContentBase64 = fs.readFileSync(workflowLocalPath).toString('base64');
      const workflowApiUrl = `https://api.github.com/repos/${cleanRepo}/contents/.github/workflows/build-apk.yml`;

      let existingSha: string | undefined;
      const checkWf = await fetch(workflowApiUrl, { headers });
      if (checkWf.ok) {
        const wfData: any = await checkWf.json();
        existingSha = wfData?.sha;
      }

      await fetch(workflowApiUrl, {
        method: 'PUT',
        headers: { ...headers, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          message: `ci: update GitHub Actions APK & Release workflow to ${tagName}`,
          content: workflowContentBase64,
          ...(existingSha ? { sha: existingSha } : {}),
        }),
      }).catch(() => null);
    }

    // 2. Check if release tag already exists or create a new GitHub Release
    const releaseBody = [
      `### ðŸŒ™ Twilight Music ${tagName} â€” Official Multi-Platform Production Release`,
      '',
      `#### âœ… Fixed Bugs, Verified Audio Masters & Synced UI in ${tagName}`,
      `- **Full App Source Code Pushed (\`main\` + \`${tagName}\`)**: Complete Flutter (\`lib/\`, \`android/\`, \`ios/\`, \`windows/\`, \`web/\`) + React/Express (\`src/\`, \`server.ts\`, \`public/audio/\`) codebase.`,
      '- **Exact Clicked-Song Guarantee**: Eliminated wrong-song playback bugs across Web, Express Proxy, and Flutter by enforcing `videoId`-first direct YouTube audio matching, strict foreign/variant title token gating, and normalized track-title matching.',
      '- **Reliable Play/Pause & Post-Download Playback**: Fixed post-download playback freezes, retry stalls, and pause/resume URL refreshes with single-session request sequencing (`playRequestId`).',
      '- **Verified Full-Length Studio Masters & Zero Remix/Karaoke Mismatch**: Added verified full-length studio audio masters and strict filtering so displayed songs always play their exact original studio track.',
      '- **In-App Offline Audio Downloads (`Library -> Downloaded`)**: One-tap download on any song card or player bar with persistent offline playback inside the app.',
      '- **UI Parity (AI Studio â†” Android APK)**: Synced MiniPlayer widget (gradient progress bar, live time counter, favorite heart toggle, circular white play/pause button, queue drawer) and Home Screen (`DYNAMIC TASTE ENGINE` greeting + `ON HEAVY REPEAT` section).',
      '- **Uninterrupted Background Playback**: Added Android `WAKE_LOCK` & `FOREGROUND_SERVICE_MEDIA_PLAYBACK` permissions, `AudioSession` interruption/becoming-noisy handlers, and ongoing foreground notification persistence.',
      '- **Monochrome Notification Icon**: Added `drawable/ic_stat_music.xml` vector icon to eliminate the white square in the Android status bar and notification shade.',
      '- **Full Automated Test Coverage**: Verified across all 29 TypeScript QA scenarios and all 6 Dart unit & widget test suites (`flutter test`).',
    ].join('\n');

    let releaseData: any = null;
    const existingRelRes = await fetch(
      `https://api.github.com/repos/${cleanRepo}/releases/tags/${encodeURIComponent(tagName)}`,
      { headers }
    );

    if (existingRelRes.ok) {
      const existingRel: any = await existingRelRes.json();
      const updateRes = await fetch(
        `https://api.github.com/repos/${cleanRepo}/releases/${existingRel.id}`,
        {
          method: 'PATCH',
          headers: { ...headers, 'Content-Type': 'application/json' },
          body: JSON.stringify({
            tag_name: tagName,
            name: `Twilight Music ${tagName} â€” Production Audio & UI Sync Release`,
            body: releaseBody,
            draft: false,
            prerelease: false,
          }),
        }
      );
      releaseData = await updateRes.json();
    } else {
      const createRes = await fetch(`https://api.github.com/repos/${cleanRepo}/releases`, {
        method: 'POST',
        headers: { ...headers, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          tag_name: tagName,
          name: `Twilight Music ${tagName} â€” Production Audio & UI Sync Release`,
          body: releaseBody,
          draft: false,
          prerelease: false,
        }),
      });

      if (!createRes.ok) {
        const errJson: any = await createRes.json().catch(() => ({}));
        res.status(createRes.status).json({
          success: false,
          error: errJson?.message || `GitHub API returned ${createRes.status}`,
        });
        return;
      }
      releaseData = await createRes.json();
    }

    // 3. Upload the live v2.4.0 Full Project Archive as a Release Asset (replace existing asset if present)
    const archivePath = buildProjectReleaseArchive();
    const archiveBuffer = fs.readFileSync(archivePath);
    const assetName = `Twilight-Music-${tagName}-Full-Project.tar.gz`;

    if (Array.isArray(releaseData?.assets)) {
      const oldAsset = releaseData.assets.find((a: any) => a?.name === assetName);
      if (oldAsset?.id) {
        await fetch(
          `https://api.github.com/repos/${cleanRepo}/releases/assets/${oldAsset.id}`,
          { method: 'DELETE', headers }
        ).catch(() => null);
      }
    }

    if (releaseData?.upload_url) {
      const uploadUrlBase = String(releaseData.upload_url).replace(/\{\?name,label\}$/, '');
      await fetch(`${uploadUrlBase}?name=${encodeURIComponent(assetName)}`, {
        method: 'POST',
        headers: {
          ...headers,
          'Content-Type': 'application/gzip',
          'Content-Length': String(archiveBuffer.length),
        },
        body: archiveBuffer,
      }).catch(() => null);
    }

    // 4. Trigger GitHub Actions APK Build Workflow (workflow_dispatch on main)
    await fetch(
      `https://api.github.com/repos/${cleanRepo}/actions/workflows/build-apk.yml/dispatches`,
      {
        method: 'POST',
        headers: { ...headers, 'Content-Type': 'application/json' },
        body: JSON.stringify({ ref: 'main' }),
      }
    ).catch(() => null);

    res.json({
      success: true,
      pushedFullRepo: gitPushStatus.pushedBranch,
      commitSha: gitPushStatus.commitSha,
      releaseUrl: releaseData?.html_url || `https://github.com/${cleanRepo}/releases/tag/${tagName}`,
      repoUrl: `https://github.com/${cleanRepo}`,
      actionsUrl: `https://github.com/${cleanRepo}/actions`,
      tagName,
      repo: cleanRepo,
      assetName,
    });
  } catch (err: any) {
    res.status(500).json({
      success: false,
      error: err?.message || 'Failed to push and publish GitHub release',
    });
  }
});

// Setup Vite middleware in dev or static serving in production
async function startServer() {
  const isProd = process.env.NODE_ENV === 'production';

  if (!isProd) {
    const { createServer } = await import('vite');
    const vite = await createServer({
      server: { middlewareMode: true, host: '0.0.0.0', port: PORT },
      appType: 'spa',
    });
    // Prevent stale 304 Not Modified responses and immutable cache poisoning across /src/* and /node_modules/.vite*
    app.use((req, res, next) => {
      if (req.url.startsWith('/node_modules/.vite/deps/')) {
        req.url = req.url.replace('/node_modules/.vite/deps/', '/node_modules/.vite-v240/deps/');
      }
      if (req.url === '/' || req.url.startsWith('/index.html')) {
        res.setHeader('Clear-Site-Data', '"cache"');
      }
      if (
        req.url.startsWith('/src/') ||
        req.url.startsWith('/node_modules/.vite') ||
        req.url === '/' ||
        req.url.startsWith('/index.html') ||
        req.url.startsWith('/@')
      ) {
        delete req.headers['if-none-match'];
        delete req.headers['if-modified-since'];
        const origSetHeader = res.setHeader.bind(res);
        res.setHeader = ((name: string, value: any) => {
          const lower = String(name).toLowerCase();
          if (lower === 'cache-control') {
            return origSetHeader('Cache-Control', 'no-store, no-cache, must-revalidate');
          }
          if (lower === 'etag' || lower === 'last-modified') {
            return res;
          }
          return origSetHeader(name, value);
        }) as typeof res.setHeader;
        origSetHeader('Cache-Control', 'no-store, no-cache, must-revalidate');
      }
      if (req.url.startsWith('/src/')) {
        const origEnd = res.end.bind(res);
        res.end = ((chunk?: any, encoding?: any, cb?: any) => {
          if (chunk && (typeof chunk === 'string' || Buffer.isBuffer(chunk))) {
            const text = typeof chunk === 'string' ? chunk : chunk.toString('utf-8');
            if (text.includes('/src/')) {
              const rewritten = text.replace(
                /from\s+(['"])(\/src\/[^'"?]+)\1/g,
                'from $1$2?v=2416$1'
              );
              const outBuf = Buffer.from(rewritten, 'utf-8');
              res.setHeader('Content-Length', String(outBuf.byteLength));
              return origEnd(outBuf, encoding, cb);
            }
          }
          return origEnd(chunk, encoding, cb);
        }) as typeof res.end;
      }
      next();
    });
    app.use(vite.middlewares);
  } else {
    app.use(express.static(path.resolve(__dirname, 'dist')));
    app.get('*', (_req: Request, res: Response) => {
      res.sendFile(path.resolve(__dirname, 'dist', 'index.html'));
    });
  }

  app.listen(PORT, '0.0.0.0', () => {
    console.log(`ðŸŒ™ Twilight Music server running at http://0.0.0.0:${PORT}`);
  });
}

const isRunningUnderTest =
  Boolean(process.env.VITEST) ||
  Boolean(process.env.NODE_TEST_CONTEXT) ||
  process.argv.some((arg) => arg.includes('--test') || arg.endsWith('.test.ts'));

if (!isRunningUnderTest) {
  startServer();
}


