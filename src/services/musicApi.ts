import { Song, Artist } from '../types';
import { StreamLogger } from './streamLogger';

export const POPULAR_FEATURED_SONGS: Song[] = [
  {
    id: 'fJ9rUzIMcZQ',
    title: 'Bohemian Rhapsody',
    artist: 'Queen',
    channelId: 'QueenOfficial',
    thumbnailUrl: 'https://i.ytimg.com/vi/fJ9rUzIMcZQ/hqdefault.jpg',
    durationSeconds: 355,
    durationFormatted: '05:55',
    viewCount: 1600000000,
    playCount: 14,
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
    playCount: 9,
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
    playCount: 18,
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
    playCount: 22,
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
    playCount: 12,
  },
  {
    id: 'CevxZvSJLk8',
    title: 'Roar',
    artist: 'Katy Perry',
    channelId: 'KatyPerryVEVO',
    thumbnailUrl: 'https://i.ytimg.com/vi/CevxZvSJLk8/hqdefault.jpg',
    durationSeconds: 223,
    durationFormatted: '03:43',
    viewCount: 3900000000,
    playCount: 8,
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
    playCount: 15,
  },
  {
    id: 'YQHsXMglC9A',
    title: 'Hello',
    artist: 'Adele',
    channelId: 'AdeleVEVO',
    thumbnailUrl: 'https://i.ytimg.com/vi/YQHsXMglC9A/hqdefault.jpg',
    durationSeconds: 295,
    durationFormatted: '04:55',
    viewCount: 3100000000,
    playCount: 11,
  },
];

export const CURATED_BENGALI_AND_GLOBAL_SONGS: Song[] = [
  {
    id: 'Qh_sxMN9UH8',
    title: 'Warfaze - Obak Bhalobasha',
    artist: 'Warfaze',
    channelId: 'WarfazeOfficial',
    thumbnailUrl: 'https://i.ytimg.com/vi/Qh_sxMN9UH8/hqdefault.jpg',
    durationSeconds: 440,
    durationFormatted: '07:20',
    viewCount: 24500000,
  },
  {
    id: '8pgvTBikV9U',
    title: 'Obak Bhalobasha | Coke Studio Bangla | Season 3 | Warfaze',
    artist: 'Coke Studio Bangla',
    channelId: 'CokeStudioBangla',
    thumbnailUrl: 'https://i.ytimg.com/vi/8pgvTBikV9U/hqdefault.jpg',
    durationSeconds: 409,
    durationFormatted: '06:49',
    viewCount: 18500000,
  },
  {
    id: 'PGgcOK7MgoM',
    title: 'Warfaze - Obak Bhalobasha (Full Extended Version)',
    artist: 'Warfaze',
    channelId: 'WarfazeOfficial',
    thumbnailUrl: 'https://i.ytimg.com/vi/PGgcOK7MgoM/hqdefault.jpg',
    durationSeconds: 518,
    durationFormatted: '08:38',
    viewCount: 8200000,
  },
  {
    id: 'NQp3cbSkqbo',
    title: 'LEVEL FIVE - TUMI (Official Lyric Video)',
    artist: 'LEVELFIVEtheband',
    channelId: 'LEVELFIVEtheband',
    thumbnailUrl: 'https://i.ytimg.com/vi/NQp3cbSkqbo/hqdefault.jpg',
    durationSeconds: 239,
    durationFormatted: '03:59',
    viewCount: 11200000,
  },
  {
    id: '8iuZrJumCLo',
    title: 'Amar Hiyar Majhe',
    artist: 'Iman Chakraborty',
    channelId: 'ImanChakraborty',
    thumbnailUrl: 'https://i.ytimg.com/vi/8iuZrJumCLo/hqdefault.jpg',
    durationSeconds: 327,
    durationFormatted: '05:27',
    viewCount: 9400000,
  },
  {
    id: 'rEGYM2DarbQ',
    title: 'Amar Hiyar Majhe (Rabindra Sangeet)',
    artist: 'Jayati Chakraborty',
    channelId: 'JayatiChakraborty',
    thumbnailUrl: 'https://i.ytimg.com/vi/rEGYM2DarbQ/hqdefault.jpg',
    durationSeconds: 317,
    durationFormatted: '05:17',
    viewCount: 6200000,
  },
  ...POPULAR_FEATURED_SONGS,
];

// Pre-verified FULL-LENGTH (3m–8m+) 320kbps AAC CDN & studio master streams (ZERO 30-second previews, ZERO remixes/karaoke)
export const VERIFIED_DIRECT_STREAMS: Record<string, string> = {
  Qh_sxMN9UH8: '/audio/Qh_sxMN9UH8.m4a',
  '8pgvTBikV9U': 'https://aac.saavncdn.com/744/89e8ba380132d45e474dd3b49779f20a_320.mp4',
  PGgcOK7MgoM: '/audio/PGgcOK7MgoM.mp3',
  NQp3cbSkqbo: '/audio/NQp3cbSkqbo.m4a',
  '8iuZrJumCLo': 'https://aac.saavncdn.com/296/ab693f16b6e4708e6fe9763c3fe20329_320.mp4',
  rEGYM2DarbQ: 'https://aac.saavncdn.com/649/d43613a52a0b2f0331a84e2ff9bb65ba_320.mp4',
  fJ9rUzIMcZQ: 'https://aac.saavncdn.com/806/442b9d1e36a4bcef050a32de50a82316_320.mp4',
  kJQP7kiw5Fk: '/audio/kJQP7kiw5Fk.m4a',
  JGwWNGJdvx8: '/audio/JGwWNGJdvx8.m4a',
  '4NRXx6U8ABQ': '/audio/4NRXx6U8ABQ.m4a',
  hT_nvWreIhg: '/audio/hT_nvWreIhg.m4a',
  CevxZvSJLk8: '/audio/CevxZvSJLk8.m4a',
  '09R8_2nJtjg': '/audio/09R8_2nJtjg.m4a',
  YQHsXMglC9A: '/audio/YQHsXMglC9A.m4a',
};

// Known stale remix/karaoke URLs that must never be used
const STALE_REMIX_OR_KARAOKE_URLS = new Set([
  'https://aac.saavncdn.com/215/a732af558d442556236cfa8445a95fc1_320.mp4',
  'https://aac.saavncdn.com/444/c72a75582084c9e31a0e8f60339da41e_320.mp4',
  'https://aac.saavncdn.com/341/9872b384f066988e9bd957d6d68ee394_320.mp4',
  'https://aac.saavncdn.com/171/6d2e390fbaa2bab69f688e1ab2768f12_320.mp4',
  'https://aac.saavncdn.com/087/e5e0df72c64ca032f6337e71cef19b26_320.mp4',
  'https://aac.saavncdn.com/213/6a4b5178283bbaf1258ee19e44f9c4dc_320.mp4',
  'https://aac.saavncdn.com/581/13ad754e4466d5c6ea19f291505afc13_320.mp4',
]);

export function isShortPreviewUrl(url?: string | null): boolean {
  if (!url) return false;
  if (STALE_REMIX_OR_KARAOKE_URLS.has(url)) return true;
  return /itunes\.apple\.com|AudioPreview|mzaf_|cf-preview-media\.sndcdn\.com|\/preview\/0\/30\//i.test(url);
}

const clientDirectStreamCache = new Map<string, string>();
const backendPlayableStatusCache = new Map<string, { playable: boolean; url: string | null; checkedAt: number }>();
const inFlightClientDirectResolutions = new Map<string, Promise<string | null>>();
const clientSearchCache = new Map<string, { songs: Song[]; cachedAt: number }>();
const inFlightClientSearches = new Map<string, Promise<Song[]>>();
let clientTrendingCache: { songs: Song[]; cachedAt: number } | null = null;
let inFlightClientTrending: Promise<Song[]> | null = null;
const clientDynamicMixCache = new Map<string, { songs: Song[]; cachedAt: number }>();
const inFlightClientDynamicMix = new Map<string, Promise<Song[]>>();
const saavnDirectJsonCache = new Map<string, { items: any[]; cachedAt: number }>();
const inFlightSaavnJsonRequests = new Map<string, Promise<any[] | null>>();
let saavnDirectCooldownUntil = 0;

const CLIENT_SEARCH_CACHE_TTL_MS = 2 * 60 * 1000;
const CLIENT_TRENDING_CACHE_TTL_MS = 3 * 60 * 1000;
const SAAVN_COOLDOWN_MS = 45 * 1000;
const CLIENT_RETRYABLE_STATUSES = new Set([408, 425, 429, 500, 502, 503, 504]);

function createClientTimeoutSignal(timeoutMs: number): { signal: AbortSignal; cancel: () => void } {
  if (typeof AbortSignal !== 'undefined' && typeof AbortSignal.timeout === 'function') {
    return { signal: AbortSignal.timeout(timeoutMs), cancel: () => {} };
  }
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(new DOMException('signal timed out', 'TimeoutError')), timeoutMs);
  return {
    signal: controller.signal,
    cancel: () => clearTimeout(timer),
  };
}

async function clientFetchWithRetry(
  url: string,
  init: RequestInit = {},
  options: { retries?: number; timeoutMs?: number; baseDelayMs?: number } = {}
): Promise<Response> {
  const retries = options.retries ?? 1;
  const timeoutMs = options.timeoutMs ?? 8500;
  const baseDelayMs = options.baseDelayMs ?? 240;
  const endpointLabel = url.split('?')[0];

  let lastErr: unknown;
  for (let attempt = 0; attempt <= retries; attempt++) {
    const { signal, cancel } = createClientTimeoutSignal(timeoutMs);
    try {
      const res = await fetch(url, {
        ...init,
        signal,
      });
      cancel();
      if (!CLIENT_RETRYABLE_STATUSES.has(res.status) || attempt === retries) {
        if (CLIENT_RETRYABLE_STATUSES.has(res.status) && attempt === retries) {
          StreamLogger.logDisconnect('musicApi', `Exhausted retries for ${endpointLabel}`, {
            statusCode: res.status,
            attempt: attempt + 1,
            maxAttempts: retries + 1,
          });
        }
        return res;
      }
      const delayMs = Math.min(2000, baseDelayMs * Math.pow(2, attempt) + Math.floor(Math.random() * 100));
      StreamLogger.logRetry('musicApi', `Retrying ${endpointLabel} after HTTP ${res.status}`, {
        statusCode: res.status,
        attempt: attempt + 1,
        maxAttempts: retries + 1,
        detail: `delay=${delayMs}ms`,
      });
      await new Promise((resolve) => setTimeout(resolve, delayMs));
    } catch (err: any) {
      cancel();
      lastErr = err;
      if (attempt === retries) {
        StreamLogger.logDisconnect('musicApi', `Network request failed for ${endpointLabel}`, {
          attempt: attempt + 1,
          maxAttempts: retries + 1,
          detail: err?.message || String(err),
        });
        throw err;
      }
      const delayMs = Math.min(2000, baseDelayMs * Math.pow(2, attempt) + Math.floor(Math.random() * 100));
      StreamLogger.logRetry('musicApi', `Retrying ${endpointLabel} after connection error`, {
        attempt: attempt + 1,
        maxAttempts: retries + 1,
        detail: `${err?.message || String(err)} (delay=${delayMs}ms)`,
      });
      await new Promise((resolve) => setTimeout(resolve, delayMs));
    }
  }
  throw lastErr instanceof Error ? lastErr : new Error('Client fetch failed after retries');
}

async function fetchSaavnDirectItemsCoalesced(
  saavnUrl: string,
  timeoutMs = 8500
): Promise<{ items: any[]; networkFailed: boolean }> {
  const cached = saavnDirectJsonCache.get(saavnUrl);
  if (cached && Date.now() - cached.cachedAt < CLIENT_SEARCH_CACHE_TTL_MS) {
    return { items: cached.items, networkFailed: false };
  }
  if (Date.now() < saavnDirectCooldownUntil) {
    return { items: [], networkFailed: true };
  }

  const existing = inFlightSaavnJsonRequests.get(saavnUrl);
  if (existing) {
    const items = await existing;
    return { items: items ?? [], networkFailed: items === null };
  }

  let sawNetworkFailure = false;
  const pending = (async (): Promise<any[] | null> => {
    try {
      const res = await clientFetchWithRetry(saavnUrl, {}, { retries: 1, timeoutMs });
      if (!res.ok) return [];
      const data = await res.json();
      const items: any[] = Array.isArray(data?.data?.results) ? data.data.results : [];
      saavnDirectJsonCache.set(saavnUrl, { items, cachedAt: Date.now() });
      return items;
    } catch {
      sawNetworkFailure = true;
      saavnDirectCooldownUntil = Date.now() + SAAVN_COOLDOWN_MS;
      return null;
    }
  })().finally(() => {
    if (inFlightSaavnJsonRequests.get(saavnUrl) === pending) {
      inFlightSaavnJsonRequests.delete(saavnUrl);
    }
  });

  inFlightSaavnJsonRequests.set(saavnUrl, pending);
  const items = await pending;
  return { items: items ?? [], networkFailed: sawNetworkFailure || items === null };
}

export const FEATURED_ARTISTS: Artist[] = [
  { id: 'art_edsheeran', name: 'Ed Sheeran', thumbnailUrl: 'https://i.ytimg.com/vi/JGwWNGJdvx8/hqdefault.jpg', subscribers: '54M' },
  { id: 'art_theweeknd', name: 'The Weeknd', thumbnailUrl: 'https://i.ytimg.com/vi/4NRXx6U8ABQ/hqdefault.jpg', subscribers: '35M' },
  { id: 'art_queen', name: 'Queen', thumbnailUrl: 'https://i.ytimg.com/vi/fJ9rUzIMcZQ/hqdefault.jpg', subscribers: '18M' },
  { id: 'art_adele', name: 'Adele', thumbnailUrl: 'https://i.ytimg.com/vi/YQHsXMglC9A/hqdefault.jpg', subscribers: '31M' },
  { id: 'art_maroon5', name: 'Maroon 5', thumbnailUrl: 'https://i.ytimg.com/vi/09R8_2nJtjg/hqdefault.jpg', subscribers: '37M' },
  { id: 'art_warfaze', name: 'Warfaze', thumbnailUrl: 'https://i.ytimg.com/vi/8pgvTBikV9U/hqdefault.jpg', subscribers: '1.2M' },
];

export function normalizePhoneticSearchQuery(rawQuery: string): string {
  const q = rawQuery.trim();
  const lower = q.toLowerCase();
  if (lower.includes('obak valo') || lower.includes('obak bhalo')) {
    return 'Obak Bhalobasha Warfaze';
  }
  if (
    lower.includes('tmi hiyar') ||
    lower.includes('tumi hiyar') ||
    lower.includes('hiyar majh') ||
    lower.includes('amar hiyar')
  ) {
    return 'Amar Hiyar Majhe';
  }
  if (lower === 'tmi' || lower === 'tumi' || lower.includes('level five')) {
    return 'LEVEL FIVE TUMI';
  }
  return q;
}

function formatDurationSeconds(seconds: number): string {
  const safe = Math.max(0, Math.floor(seconds || 0));
  const mins = Math.floor(safe / 60);
  const secs = safe % 60;
  return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
}

function decodeHtmlEntities(str: string): string {
  return (str || '')
    .replace(/&quot;/g, '"')
    .replace(/&#039;|&apos;/g, "'")
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>');
}

export class MusicApi {
  static async searchSongsClientDirect(query: string): Promise<Song[]> {
    const normalized = normalizePhoneticSearchQuery(query);
    const searchTerms = normalized !== query.trim() ? [normalized, query.trim()] : [normalized];
    const results: Song[] = [];
    const seen = new Set<string>();

    // 1. Include matching curated full-length tracks first (e.g., Obak Bhalobasha 7:20, 6:49, 8:38, LEVEL FIVE - TUMI 3:59)
    const qLower = query.trim().toLowerCase();
    const normLower = normalized.toLowerCase();
    for (const curated of CURATED_BENGALI_AND_GLOBAL_SONGS) {
      const titleLower = curated.title.toLowerCase();
      const artistLower = curated.artist.toLowerCase();
      if (
        titleLower.includes(qLower) ||
        artistLower.includes(qLower) ||
        titleLower.includes(normLower.split(' ')[0]) ||
        normLower.includes(titleLower)
      ) {
        if (!seen.has(curated.id)) {
          seen.add(curated.id);
          results.push(curated);
        }
      }
    }

    // 2. Query CORS-enabled full-length 320kbps AAC catalog (saavn.sumit.co — returns full 3m–8m songs, never 30s previews)
    for (const term of searchTerms) {
      if (!term) continue;
      if (Date.now() < saavnDirectCooldownUntil) break;
      try {
        const saavnUrl = `https://saavn.sumit.co/api/search/songs?query=${encodeURIComponent(
          term
        )}&limit=20`;
        const { items, networkFailed } = await fetchSaavnDirectItemsCoalesced(saavnUrl, 8500);
        if (networkFailed) break;
        if (items.length === 0) continue;

        const wantsRemixOrKaraoke = /\b(?:remix|karaoke|instrumental|nightcore|slowed|reverb|cover|lofi|lo-fi)\b/i.test(
          term
        );
        for (const item of items) {
          const trackId = item?.id ? `js_${item.id}` : '';
          const title = decodeHtmlEntities(String(item?.name || '').trim());
          const primaryArtists = Array.isArray(item?.artists?.primary)
            ? item.artists.primary.map((a: any) => a?.name).filter(Boolean).join(', ')
            : '';
          const artist = decodeHtmlEntities(String(primaryArtists || item?.label || 'Unknown Artist').trim());
          const downloadUrls: any[] = Array.isArray(item?.downloadUrl) ? item.downloadUrl : [];
          const bestDl = downloadUrls.length > 0 ? downloadUrls[downloadUrls.length - 1] : null;
          const fullStreamUrl = String(bestDl?.url || '').trim();
          const durationSec = Math.round(Number(item?.duration || 0));

          if (!trackId || !title || !fullStreamUrl || durationSec <= 35 || isShortPreviewUrl(fullStreamUrl)) continue;
          if (
            !wantsRemixOrKaraoke &&
            /\b(?:karaoke|instrumental|nightcore|remix|cover|tribute|parody|zzang|cheesyfox)\b/i.test(
              `${title} ${artist}`
            )
          ) {
            continue;
          }

          const dedupeKey = `${title.toLowerCase()}|${artist.toLowerCase()}|${Math.round(durationSec / 10)}`;
          if (seen.has(trackId) || seen.has(dedupeKey)) continue;
          seen.add(trackId);
          seen.add(dedupeKey);

          const images: any[] = Array.isArray(item?.image) ? item.image : [];
          const highResArt =
            (images.length > 0 ? String(images[images.length - 1]?.url || '') : '') ||
            'https://i.ytimg.com/vi/fJ9rUzIMcZQ/hqdefault.jpg';

          clientDirectStreamCache.set(trackId, fullStreamUrl);
          results.push({
            id: trackId,
            title,
            artist,
            channelId: trackId,
            thumbnailUrl: highResArt,
            durationSeconds: durationSec,
            durationFormatted: formatDurationSeconds(durationSec),
            viewCount: Number(item?.playCount || 250000),
            audioUrl: fullStreamUrl,
          });
        }
        if (results.length >= 6) break;
      } catch {
        // continue
      }
    }

    return results;
  }

  static extractCoreSongTitleAndArtist(
    rawTitle: string,
    rawArtist?: string
  ): { coreTitle: string; primaryArtist: string } {
    const metadataRegex =
      /^(?:coke\s+studio.*|season\s*\d+|episode\s*\d+|ep\s*\.?\s*\d+|official.*|lyric(?:al)?.*|full\s+(?:song|video|audio|extended).*|audio\s+song.*|video\s+song.*|rabindra\s+sangeet.*|tagore\s+song.*|bangla\s+(?:gaan|song|music|natok).*|\d+(?:st|nd|rd|th)\s+anniversary.*|anniversary\s+concert.*|concert.*|hd|4k|hq|remaster.*|live.*|unplugged.*|t-series.*|sony\s+music.*|zee\s+music.*|svf.*|sangeet\s+bangla.*|soundtek.*|laser\s+vision.*|bhavna\s+records.*)$/i;
    const cleanText = (s: string) =>
      decodeHtmlEntities(s || '')
        .replace(/#\S+/g, ' ')
        .replace(/\(\s*[^\x00-\x7F]+\s*\)/g, ' ')
        .replace(/\[\s*[^\x00-\x7F]+\s*\]/g, ' ')
        .replace(
          /\([^)]*(?:official|video|audio|lyric|lyrics|visualizer|hd|4k|hq|remaster|live|mv|full\s+song|full\s+extended|coke\s+studio|season\s*\d+|mix|vibes|concert|anniversary|from\s+|feat\.?\s+|ft\.?\s+|original\s+motion|soundtrack|ost|film|movie|natok|drama|telefilm)[^)]*\)/gi,
          ' '
        )
        .replace(/\[[^\]]*\]/g, ' ')
        .replace(
          /\b(?:VEVO|Topic|Official\s+Music\s+Video|Official\s+Video|Official\s+Audio|Lyrical\s+Video|Full\s+Song)\b/gi,
          ' '
        )
        .replace(/\s+/g, ' ')
        .trim();

    const cleanedChannel = cleanText(rawArtist || '')
      .replace(/(?:theband|official|vevo|topic|music|records|channel|band)$/i, ' ')
      .replace(/\b(?:official|vevo|topic|music|records|channel|various\s+artists)\b/gi, ' ')
      .replace(/\s+/g, ' ')
      .trim();
    const isGenericChannel = !cleanedChannel || metadataRegex.test(cleanedChannel);
    const compactChannel = cleanedChannel.toLowerCase().replace(/[^a-z0-9]/g, '');

    const rawSegments = decodeHtmlEntities(String(rawTitle || ''))
      .split(/(?:\s*\|\|\s*|\s*[|•·]\s*|\s+\/\/\s+)/)
      .map(cleanText)
      .filter(Boolean);
    const meaningful = rawSegments.filter((s) => !metadataRegex.test(s));
    const candidates = meaningful.length > 0 ? meaningful : [cleanText(rawTitle)];
    const latinCandidates = candidates.filter((s) => /[a-zA-Z]/.test(s));
    const nonArtistLatinCandidates =
      compactChannel.length >= 3 && latinCandidates.length > 1
        ? latinCandidates.filter((s) => {
            const c = s.toLowerCase().replace(/[^a-z0-9]/g, '');
            return c !== compactChannel;
          })
        : latinCandidates;

    const primarySeg =
      nonArtistLatinCandidates[0] || latinCandidates[0] || candidates[0] || '';

    let coreTitle = primarySeg;
    let extractedArtist = '';

    if (primarySeg.includes('-') || primarySeg.includes('–') || primarySeg.includes('—')) {
      const parts = primarySeg
        .split(/\s*[-–—]\s*/)
        .map((p) => p.trim())
        .filter(Boolean);
      if (parts.length === 2) {
        const [left, right] = parts;
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
        } else if (/\s+[-–—]\s+/.test(primarySeg)) {
          coreTitle = metadataRegex.test(right) ? left : right;
          extractedArtist = metadataRegex.test(right) ? '' : left;
        }
      }
    }

    if (!extractedArtist) {
      const others = candidates.filter(
        (s) => s !== primarySeg && /[a-zA-Z]/.test(s) && !metadataRegex.test(s)
      );
      if (others.length > 0) {
        const channelMatchedSeg =
          compactChannel.length >= 3
            ? others.find((s) => s.toLowerCase().replace(/[^a-z0-9]/g, '') === compactChannel)
            : undefined;
        extractedArtist = channelMatchedSeg || others[others.length - 1];
      }
    }

    const preferExtracted =
      Boolean(extractedArtist) &&
      (isGenericChannel ||
        (!cleanedChannel.includes(' ') && extractedArtist.includes(' ')) ||
        compactChannel === extractedArtist.toLowerCase().replace(/[^a-z0-9]/g, ''));

    const primaryArtist = preferExtracted
      ? extractedArtist || cleanedChannel
      : cleanedChannel || extractedArtist;

    const finalCoreTitle = (coreTitle.trim() || cleanText(rawTitle))
      .replace(/\([^)]*\)/g, ' ')
      .replace(/\[[^\]]*\]/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();

    return {
      coreTitle: finalCoreTitle || coreTitle.trim() || cleanText(rawTitle),
      primaryArtist: primaryArtist.trim(),
    };
  }

  static resolveKnownFullLengthMaster(song: Song): string | null {
    const cleanId = (song.id || '').trim();
    if (VERIFIED_DIRECT_STREAMS[cleanId]) {
      return VERIFIED_DIRECT_STREAMS[cleanId];
    }
    const { coreTitle, primaryArtist } = MusicApi.extractCoreSongTitleAndArtist(
      song.title || '',
      song.artist || ''
    );
    const titleLower = coreTitle.toLowerCase();
    const rawLower = `${song.title || ''} ${song.artist || ''} ${primaryArtist}`.toLowerCase();
    const dur = song.durationSeconds || 0;
    const wantsSpecialVersion =
      /\b(?:concert|live|anniversary|unplugged|acoustic|cover|remix|lofi|lo-fi|slowed|reverb|mashup|reprise)\b/i.test(
        rawLower
      );

    if (
      !wantsSpecialVersion &&
      titleLower.includes('bondho janala') &&
      rawLower.includes('shironamhin') &&
      !titleLower.includes('bhalobasha') &&
      !titleLower.includes('valobasha') &&
      (dur === 0 || Math.abs(dur - 243) <= 22)
    ) {
      return 'https://aac.saavncdn.com/000/8a81a552431793831c58e09f3d7fde01_320.mp4';
    }

    if (
      !wantsSpecialVersion &&
      (titleLower.includes('obak bhalobasha') || titleLower.includes('obak valobasha')) &&
      rawLower.includes('warfaze')
    ) {
      if (rawLower.includes('coke studio') || (dur > 0 && Math.abs(dur - 409) <= 14)) {
        return VERIFIED_DIRECT_STREAMS['8pgvTBikV9U'];
      }
      if (dur >= 485) {
        return VERIFIED_DIRECT_STREAMS.PGgcOK7MgoM;
      }
      return VERIFIED_DIRECT_STREAMS.Qh_sxMN9UH8;
    }

    if (
      !wantsSpecialVersion &&
      titleLower === 'tumi' &&
      (rawLower.includes('level five') || rawLower.includes('levelfive')) &&
      (dur === 0 || Math.abs(dur - 239) <= 22)
    ) {
      return VERIFIED_DIRECT_STREAMS.NQp3cbSkqbo;
    }

    if (!wantsSpecialVersion && titleLower.includes('despacito') && (rawLower.includes('fonsi') || rawLower.includes('yankee'))) {
      return VERIFIED_DIRECT_STREAMS.kJQP7kiw5Fk;
    }
    if (!wantsSpecialVersion && titleLower.includes('shape of you') && rawLower.includes('sheeran')) {
      return VERIFIED_DIRECT_STREAMS.JGwWNGJdvx8;
    }
    if (!wantsSpecialVersion && titleLower.includes('blinding lights') && rawLower.includes('weeknd')) {
      return VERIFIED_DIRECT_STREAMS['4NRXx6U8ABQ'];
    }
    if (!wantsSpecialVersion && titleLower.includes('counting stars') && rawLower.includes('onerepublic')) {
      return VERIFIED_DIRECT_STREAMS.hT_nvWreIhg;
    }
    if (!wantsSpecialVersion && titleLower === 'roar' && rawLower.includes('katy perry')) {
      return VERIFIED_DIRECT_STREAMS.CevxZvSJLk8;
    }
    if (!wantsSpecialVersion && titleLower === 'sugar' && rawLower.includes('maroon')) {
      return VERIFIED_DIRECT_STREAMS['09R8_2nJtjg'];
    }
    if (!wantsSpecialVersion && titleLower === 'hello' && rawLower.includes('adele')) {
      return VERIFIED_DIRECT_STREAMS.YQHsXMglC9A;
    }
    if (!wantsSpecialVersion && titleLower.includes('bohemian rhapsody') && rawLower.includes('queen')) {
      return VERIFIED_DIRECT_STREAMS.fJ9rUzIMcZQ;
    }

    return null;
  }

  static invalidateClientDirectStreamCache(songId?: string): void {
    if (songId) {
      const cleanId = songId.trim();
      clientDirectStreamCache.delete(cleanId);
      backendPlayableStatusCache.delete(cleanId);
    } else {
      clientDirectStreamCache.clear();
      backendPlayableStatusCache.clear();
    }
  }

  static async checkProxyStreamPlayable(
    song: Song,
    forceRefresh = false
  ): Promise<{ playable: boolean; url: string | null }> {
    const cleanId = (song.id || '').trim();
    if (!forceRefresh && cleanId) {
      const known = backendPlayableStatusCache.get(cleanId);
      if (known && Date.now() - known.checkedAt < 60000) {
        return { playable: known.playable, url: known.url };
      }
    }
    const directUrl = await MusicApi.resolveClientDirectStreamUrl(song, forceRefresh);
    if (directUrl) {
      return { playable: true, url: directUrl };
    }
    const updatedStatus = cleanId ? backendPlayableStatusCache.get(cleanId) : undefined;
    return { playable: Boolean(updatedStatus?.playable), url: updatedStatus?.url ?? null };
  }

  static async resolveClientDirectStreamUrl(
    song: Song,
    forceRefresh = false
  ): Promise<string | null> {
    if (!song) return null;

    // 1. Check verified full-length studio masters by ID or Title+Artist+Duration FIRST (0ms, exact match)
    const knownMaster = MusicApi.resolveKnownFullLengthMaster(song);
    const cleanId = (song.id || '').trim();
    if (knownMaster) {
      if (cleanId) clientDirectStreamCache.set(cleanId, knownMaster);
      return knownMaster;
    }

    if (
      !forceRefresh &&
      song.audioUrl &&
      !isShortPreviewUrl(song.audioUrl) &&
      (song.audioUrl.startsWith('https://') || song.audioUrl.startsWith('/audio/'))
    ) {
      return song.audioUrl;
    }

    if (forceRefresh && cleanId) {
      clientDirectStreamCache.delete(cleanId);
    }

    const cachedUrl = !forceRefresh ? clientDirectStreamCache.get(cleanId) : undefined;
    if (cachedUrl && !isShortPreviewUrl(cachedUrl)) {
      return cachedUrl;
    }

    if (!forceRefresh && cleanId) {
      const existingPending = inFlightClientDirectResolutions.get(cleanId);
      if (existingPending) {
        return existingPending;
      }
    }

    const executeResolve = async (): Promise<string | null> => {
      // 2. Resolve the exact track & version stream from backend multi-source resolver
      let backendRespondedOk = false;
      if (cleanId) {
        try {
          const params = new URLSearchParams({
            ...(song.title ? { title: song.title } : {}),
            ...(song.artist ? { artist: song.artist } : {}),
            ...(song.durationSeconds ? { duration: String(song.durationSeconds) } : {}),
            ...(forceRefresh ? { refresh: '1', t: String(Date.now()) } : {}),
          });
          const res = await clientFetchWithRetry(
            `/api/stream/${encodeURIComponent(cleanId)}/resolve?${params.toString()}`,
            {},
            { retries: 1, timeoutMs: 9500, baseDelayMs: 220 }
          );
          const contentType = res.headers.get('content-type') || '';
          if (res.ok && contentType.includes('application/json')) {
            backendRespondedOk = true;
            const data = await res.json();
            const resolvedUrl = String(data?.directCdnUrl || '');
            const validResolvedUrl =
              resolvedUrl &&
              !isShortPreviewUrl(resolvedUrl) &&
              (resolvedUrl.startsWith('https://') ||
                resolvedUrl.startsWith('/api/stream/') ||
                resolvedUrl.startsWith('/audio/'))
                ? resolvedUrl
                : null;
            const isPlayable = Boolean((data?.playable ?? Boolean(validResolvedUrl)) && (!resolvedUrl || validResolvedUrl));
            backendPlayableStatusCache.set(cleanId, {
              playable: isPlayable,
              url: validResolvedUrl,
              checkedAt: Date.now(),
            });
            if (validResolvedUrl) {
              clientDirectStreamCache.set(cleanId, validResolvedUrl);
              return validResolvedUrl;
            }
          }
        } catch (err: any) {
          StreamLogger.logDisconnect('resolveClientDirectStreamUrl', 'Backend resolver unreachable, falling back to direct CDN search', {
            songId: cleanId,
            songTitle: song.title,
            detail: err?.message || String(err),
          });
        }
      }

      // If the backend already ran full multi-source resolution and confirmed no external CDN audio master exists,
      // immediately hand off to YT IFrame / HTML5 playback instead of blocking another 5-9s on redundant searches.
      if (backendRespondedOk && !forceRefresh) {
        return null;
      }

    // 3. Direct client-side full-length 320kbps AAC resolution via saavn.sumit.co (CORS-enabled)
    const { coreTitle, primaryArtist } = MusicApi.extractCoreSongTitleAndArtist(
      song.title || '',
      song.artist || ''
    );
    const wantsRemixOrKaraoke = /\b(?:remix|karaoke|instrumental|nightcore|slowed|reverb|cover|lofi|lo-fi)\b/i.test(
      `${song.title || ''} ${song.artist || ''}`
    );
    const stopWords = new Set([
      'the', 'and', 'for', 'with', 'from', 'feat', 'ft', 'of', 'in', 'on', 'to', 'at', 'by',
      'official', 'music', 'video', 'audio', 'song', 'songs', 'full', 'lyric', 'lyrics', 'coke', 'studio', 'bangla', 'season',
      'anniversary', 'concert', 'live', 'version', 'album', 'movie', 'film', 'ost', 'soundtrack', 'title', 'theme', 'natok', 'drama',
    ]);
    const normalizePhonetic = (s: string) =>
      s
        .toLowerCase()
        .replace(/bh/g, 'v')
        .replace(/sh/g, 's')
        .replace(/ph/g, 'f')
        .replace(/kh/g, 'k')
        .replace(/gh/g, 'g')
        .replace(/aa/g, 'a')
        .replace(/ee/g, 'i')
        .replace(/oo/g, 'u');
    const tokenMatches = (tok: string, text: string) => {
      const tL = tok.toLowerCase();
      const txL = text.toLowerCase();
      return txL.includes(tL) || normalizePhonetic(txL).includes(normalizePhonetic(tL));
    };

    const rawTokens = coreTitle
      .toLowerCase()
      .replace(/[^a-z0-9\s]/g, ' ')
      .split(/\s+/)
      .filter((t) => t.length >= 2);
    const coreTokens = rawTokens.filter((t) => !stopWords.has(t));
    const effectiveTokens = coreTokens.length > 0 ? coreTokens : rawTokens;
    const normCoreTitle = coreTitle
      .toLowerCase()
      .replace(/[^a-z0-9\s]/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
    const isDistinctiveCoreTitle =
      effectiveTokens.length >= 2 || (effectiveTokens.length === 1 && normCoreTitle.length >= 6);
    const artistTokens = primaryArtist
      .toLowerCase()
      .replace(/[^a-z0-9\s]/g, ' ')
      .split(/\s+/)
      .filter((t) => t.length >= 3 && !stopWords.has(t));

    const queries = Array.from(
      new Set(
        [
          primaryArtist ? `${coreTitle} ${primaryArtist}` : coreTitle,
          coreTitle,
        ].filter(Boolean)
      )
    );

    for (const q of queries) {
      if (Date.now() < saavnDirectCooldownUntil) break;
      try {
        const saavnUrl = `https://saavn.sumit.co/api/search/songs?query=${encodeURIComponent(
          q
        )}&limit=10`;
        const { items, networkFailed } = await fetchSaavnDirectItemsCoalesced(saavnUrl, 8500);
        if (networkFailed) break;
        if (items.length === 0) continue;
        let bestMatch: any = null;
        let bestScore = -999;

        for (let idx = 0; idx < items.length; idx++) {
          const i = items[idx];
          const downloadUrls: any[] = Array.isArray(i?.downloadUrl) ? i.downloadUrl : [];
          const dlUrl = downloadUrls.length > 0 ? String(downloadUrls[downloadUrls.length - 1]?.url || '') : '';
          const durSec = Number(i?.duration || 0);
          if (!dlUrl || durSec <= 45 || isShortPreviewUrl(dlUrl)) continue;

          const candTitleRaw = decodeHtmlEntities(String(i?.name || '')).toLowerCase();
          const candTitle = candTitleRaw
            .replace(/\([^)]*\)/g, ' ')
            .replace(/\[[^\]]*\]/g, ' ')
            .replace(/\s+/g, ' ')
            .trim();
          const candArtists = Array.isArray(i?.artists?.primary)
            ? i.artists.primary
                .map((a: any) => decodeHtmlEntities(String(a?.name || '')))
                .filter(Boolean)
                .join(' ')
                .toLowerCase()
            : '';
          const candArtistTokens = candArtists
            .replace(/[^a-z0-9\s]/g, ' ')
            .split(/\s+/)
            .filter((w: string) => w.length >= 3);

          // Reject karaoke, nightcore, covers, or remixes unless explicitly requested
          if (
            !wantsRemixOrKaraoke &&
            /\b(?:karaoke|instrumental|nightcore|remix|cover|tribute|parody|zzang|cheesyfox)\b/i.test(
              `${candTitleRaw} ${candArtists}`
            )
          ) {
            continue;
          }

          if (effectiveTokens.length > 0) {
            const candWords = candTitle
              .replace(/[^a-z0-9\s]/g, ' ')
              .split(/\s+/)
              .filter((w) => w.length >= 3 && !stopWords.has(w) && !/^\d+$/.test(w));
            const hasForeignWord = candWords.some(
              (cw) =>
                !effectiveTokens.some((ct) => tokenMatches(ct, cw) || tokenMatches(cw, ct)) &&
                !artistTokens.some((at) => tokenMatches(at, cw) || tokenMatches(cw, at)) &&
                !candArtistTokens.some((cat: string) => tokenMatches(cat, cw) || tokenMatches(cw, cat))
            );
            if (hasForeignWord) continue;

            let matched = 0;
            for (const ct of effectiveTokens) {
              if (tokenMatches(ct, candTitle)) matched += 1;
            }
            const minReq =
              effectiveTokens.length <= 2
                ? effectiveTokens.length
                : Math.ceil(effectiveTokens.length * 0.6);
            if (matched < minReq) continue;
          }
          const candNorm = candTitle.replace(/[^a-z0-9\s]/g, ' ').replace(/\s+/g, ' ').trim();
          const artistMatched =
            artistTokens.length === 0 ||
            artistTokens.some((at) => tokenMatches(at, `${candTitleRaw} ${candArtists}`));
          const exactDistinctive =
            isDistinctiveCoreTitle &&
            candNorm === normCoreTitle &&
            (!song.durationSeconds || Math.abs(durSec - song.durationSeconds) <= 25);

          if (!artistMatched && !exactDistinctive) {
            continue;
          }

          let score = 20 - idx;
          if (candNorm === normCoreTitle) score += 35;
          if (artistMatched) score += 20;
          if (song.durationSeconds && song.durationSeconds > 0 && durSec > 0) {
            const durDiff = Math.abs(durSec - song.durationSeconds);
            if (durDiff <= 5) score += 45;
            else if (durDiff <= 18) score += 25;
            else if (durDiff > 35) score -= 20;
          }
          if (score > bestScore) {
            bestScore = score;
            bestMatch = i;
          }
        }

        if (bestMatch) {
          const downloadUrls: any[] = Array.isArray(bestMatch.downloadUrl) ? bestMatch.downloadUrl : [];
          const streamUrl = String(downloadUrls[downloadUrls.length - 1]?.url || '');
          if (streamUrl) {
            if (cleanId) clientDirectStreamCache.set(cleanId, streamUrl);
            return streamUrl;
          }
        }
      } catch {
        // continue
      }
    }

      return null;
    };

    if (!cleanId || forceRefresh) {
      return executeResolve();
    }

    const pending = executeResolve().finally(() => {
      if (inFlightClientDirectResolutions.get(cleanId) === pending) {
        inFlightClientDirectResolutions.delete(cleanId);
      }
    });
    inFlightClientDirectResolutions.set(cleanId, pending);
    return pending;
  }

  static async searchSongs(query: string): Promise<Song[]> {
    if (!query.trim()) return [];
    const normalizedQuery = normalizePhoneticSearchQuery(query);
    const cacheKey = normalizedQuery.toLowerCase();

    const cached = clientSearchCache.get(cacheKey);
    if (cached && Date.now() - cached.cachedAt < CLIENT_SEARCH_CACHE_TTL_MS && cached.songs.length > 0) {
      return cached.songs;
    }

    const existing = inFlightClientSearches.get(cacheKey);
    if (existing) {
      return existing;
    }

    const pending = (async (): Promise<Song[]> => {
      try {
        const res = await clientFetchWithRetry(
          `/api/search?q=${encodeURIComponent(normalizedQuery)}`,
          {},
          { retries: 1, timeoutMs: 9000 }
        );
        const contentType = res.headers.get('content-type') || '';
        if (res.ok && contentType.includes('application/json')) {
          const data = await res.json();
          if (Array.isArray(data.songs) && data.songs.length > 0) {
            const seen = new Set<string>();
            const deduped = (data.songs as Song[]).filter((s) => {
              if (!s?.id || seen.has(s.id)) return false;
              seen.add(s.id);
              return true;
            });
            if (deduped.length > 0) {
              clientSearchCache.set(cacheKey, { songs: deduped, cachedAt: Date.now() });
              return deduped;
            }
          }
        }
      } catch {
        // Backend proxy unreachable or redirected in standalone PWA mode -> use direct client-side full-length search
      }

      // Direct client-side full-length search (CORS-enabled 320kbps AAC + Curated Bengali/Global full catalog)
      const directResults = await MusicApi.searchSongsClientDirect(query);
      if (directResults.length > 0) {
        clientSearchCache.set(cacheKey, { songs: directResults, cachedAt: Date.now() });
        return directResults;
      }

      return CURATED_BENGALI_AND_GLOBAL_SONGS;
    })().finally(() => {
      if (inFlightClientSearches.get(cacheKey) === pending) {
        inFlightClientSearches.delete(cacheKey);
      }
    });

    inFlightClientSearches.set(cacheKey, pending);
    return pending;
  }

  static async getTrendingSongs(): Promise<Song[]> {
    if (
      clientTrendingCache &&
      Date.now() - clientTrendingCache.cachedAt < CLIENT_TRENDING_CACHE_TTL_MS &&
      clientTrendingCache.songs.length > 0
    ) {
      return clientTrendingCache.songs;
    }
    if (inFlightClientTrending) {
      return inFlightClientTrending;
    }

    const pending = (async (): Promise<Song[]> => {
      try {
        const res = await clientFetchWithRetry('/api/trending', {}, { retries: 1, timeoutMs: 8500 });
        const contentType = res.headers.get('content-type') || '';
        if (res.ok && contentType.includes('application/json')) {
          const data = await res.json();
          if (Array.isArray(data.songs) && data.songs.length > 0) {
            clientTrendingCache = { songs: data.songs, cachedAt: Date.now() };
            return data.songs;
          }
        }
      } catch {
        // fallback
      }
      const direct = await MusicApi.searchSongsClientDirect('Trending Global Hits');
      const finalSongs = direct.length > 0 ? direct : CURATED_BENGALI_AND_GLOBAL_SONGS;
      clientTrendingCache = { songs: finalSongs, cachedAt: Date.now() };
      return finalSongs;
    })().finally(() => {
      if (inFlightClientTrending === pending) {
        inFlightClientTrending = null;
      }
    });

    inFlightClientTrending = pending;
    return pending;
  }

  static async getDynamicMix(params: {
    artists: string[];
    genres: string[];
    historyIds: string[];
    vibe: string;
  }): Promise<Song[]> {
    const cacheKey = `${(params.vibe || '').trim().toLowerCase()}|${(params.artists || [])
      .slice(0, 2)
      .join(',')
      .toLowerCase()}`;
    const cached = clientDynamicMixCache.get(cacheKey);
    if (cached && Date.now() - cached.cachedAt < CLIENT_SEARCH_CACHE_TTL_MS && cached.songs.length > 0) {
      return cached.songs;
    }
    const existing = inFlightClientDynamicMix.get(cacheKey);
    if (existing) {
      return existing;
    }

    const pending = (async (): Promise<Song[]> => {
      try {
        const res = await clientFetchWithRetry(
          '/api/recommendations/dynamic',
          {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(params),
          },
          { retries: 1, timeoutMs: 8500 }
        );
        const contentType = res.headers.get('content-type') || '';
        if (res.ok && contentType.includes('application/json')) {
          const data = await res.json();
          if (Array.isArray(data.songs) && data.songs.length > 0) {
            clientDynamicMixCache.set(cacheKey, { songs: data.songs, cachedAt: Date.now() });
            return data.songs;
          }
        }
      } catch {
        // fallback
      }

      const fallbackQuery = params.vibe || params.artists?.[0] || '';
      if (fallbackQuery) {
        const direct = await MusicApi.searchSongsClientDirect(fallbackQuery);
        if (direct.length > 0) {
          clientDynamicMixCache.set(cacheKey, { songs: direct, cachedAt: Date.now() });
          return direct;
        }
      }
      return [...CURATED_BENGALI_AND_GLOBAL_SONGS];
    })().finally(() => {
      if (inFlightClientDynamicMix.get(cacheKey) === pending) {
        inFlightClientDynamicMix.delete(cacheKey);
      }
    });

    inFlightClientDynamicMix.set(cacheKey, pending);
    return pending;
  }

  static getAudioStreamUrl(songId: string): string {
    return `/api/stream/${encodeURIComponent(songId)}`;
  }
}
