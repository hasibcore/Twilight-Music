export type StreamLogLevel = 'info' | 'warn' | 'error';

export type StreamEventCategory =
  | 'network_disconnect'
  | 'retry'
  | 'stall'
  | 'media_error'
  | 'recovery'
  | 'offline'
  | 'online'
  | 'proxy_fallback';

export interface StreamDiagnosticEvent {
  timestamp: string;
  level: StreamLogLevel;
  category: StreamEventCategory;
  stage: string;
  message: string;
  songId?: string;
  songTitle?: string;
  statusCode?: number;
  mediaErrorCode?: number;
  attempt?: number;
  maxAttempts?: number;
  positionSec?: number;
  online?: boolean;
  detail?: string;
}

const MAX_LOG_ENTRIES = 120;
const REPORT_THROTTLE_MS = 1200;

class StreamLoggerService {
  private buffer: StreamDiagnosticEvent[] = [];
  private lastReportAt = 0;

  log(
    level: StreamLogLevel,
    category: StreamEventCategory,
    stage: string,
    message: string,
    meta: Omit<StreamDiagnosticEvent, 'timestamp' | 'level' | 'category' | 'stage' | 'message' | 'online'> = {}
  ): StreamDiagnosticEvent {
    const isOnline = typeof navigator !== 'undefined' ? navigator.onLine : true;
    const entry: StreamDiagnosticEvent = {
      timestamp: new Date().toISOString(),
      level,
      category,
      stage,
      message,
      online: isOnline,
      ...meta,
    };

    this.buffer.push(entry);
    if (this.buffer.length > MAX_LOG_ENTRIES) {
      this.buffer.shift();
    }

    const prefix = `[Twilight STREAM][${level.toUpperCase()}][${category}][${stage}]`;
    const contextParts: string[] = [];
    if (entry.songId) contextParts.push(`id=${entry.songId}`);
    if (typeof entry.statusCode === 'number') contextParts.push(`status=${entry.statusCode}`);
    if (typeof entry.mediaErrorCode === 'number') contextParts.push(`mediaErr=${entry.mediaErrorCode}`);
    if (typeof entry.attempt === 'number') {
      contextParts.push(
        typeof entry.maxAttempts === 'number'
          ? `attempt=${entry.attempt}/${entry.maxAttempts}`
          : `attempt=${entry.attempt}`
      );
    }
    if (typeof entry.positionSec === 'number') contextParts.push(`pos=${entry.positionSec.toFixed(1)}s`);
    if (!isOnline) contextParts.push('offline=true');

    const line = `${prefix} ${message}${contextParts.length ? ` (${contextParts.join(', ')})` : ''}`;
    if (level === 'error') {
      console.error(line, entry.detail || '');
    } else if (level === 'warn') {
      console.warn(line, entry.detail || '');
    } else {
      console.info(line);
    }

    // Best-effort non-blocking reporting to backend diagnostics collector for warn/error network drops
    if (
      (level === 'warn' || level === 'error') &&
      typeof window !== 'undefined' &&
      isOnline &&
      typeof fetch === 'function'
    ) {
      const now = Date.now();
      if (now - this.lastReportAt >= REPORT_THROTTLE_MS) {
        this.lastReportAt = now;
        try {
          fetch('/api/diagnostics/stream', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(entry),
            keepalive: true,
          }).catch(() => {});
        } catch {
          // Never throw from diagnostic reporting
        }
      }
    }

    return entry;
  }

  logDisconnect(
    stage: string,
    message: string,
    meta: Omit<StreamDiagnosticEvent, 'timestamp' | 'level' | 'category' | 'stage' | 'message' | 'online'> = {}
  ): StreamDiagnosticEvent {
    return this.log('warn', 'network_disconnect', stage, message, meta);
  }

  logRetry(
    stage: string,
    message: string,
    meta: Omit<StreamDiagnosticEvent, 'timestamp' | 'level' | 'category' | 'stage' | 'message' | 'online'> = {}
  ): StreamDiagnosticEvent {
    return this.log('warn', 'retry', stage, message, meta);
  }

  logRecovery(
    stage: string,
    message: string,
    meta: Omit<StreamDiagnosticEvent, 'timestamp' | 'level' | 'category' | 'stage' | 'message' | 'online'> = {}
  ): StreamDiagnosticEvent {
    return this.log('info', 'recovery', stage, message, meta);
  }

  getRecentEvents(limit = 50): StreamDiagnosticEvent[] {
    return this.buffer.slice(-Math.max(1, limit));
  }

  getDisconnectionStats(): {
    totalEvents: number;
    disconnects: number;
    retries: number;
    stalls: number;
    recoveries: number;
  } {
    let disconnects = 0;
    let retries = 0;
    let stalls = 0;
    let recoveries = 0;
    for (const ev of this.buffer) {
      if (ev.category === 'network_disconnect' || ev.category === 'media_error') disconnects++;
      else if (ev.category === 'retry') retries++;
      else if (ev.category === 'stall') stalls++;
      else if (ev.category === 'recovery') recoveries++;
    }
    return {
      totalEvents: this.buffer.length,
      disconnects,
      retries,
      stalls,
      recoveries,
    };
  }

  clear(): void {
    this.buffer = [];
  }
}

export const StreamLogger = new StreamLoggerService();
