import { UserProfile } from '../types';

const ACCOUNTS_KEY = 'twilight_auth_accounts_v1';
const ACTIVE_SESSION_KEY = 'twilight_active_local_session_v1';

interface StoredLocalAccount {
  uid: string;
  email: string;
  displayName: string;
  salt: string;
  passwordHash: string;
  createdAt: number;
}

export const GUEST_USER_PROFILE: UserProfile = {
  uid: 'guest_local_user',
  email: null,
  displayName: 'Guest Listener',
  photoURL: null,
  isGuest: true,
};

function bytesToHex(bytes: Uint8Array): string {
  return Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

function generateSalt(): string {
  if (typeof crypto !== 'undefined' && typeof crypto.getRandomValues === 'function') {
    const arr = new Uint8Array(16);
    crypto.getRandomValues(arr);
    return bytesToHex(arr);
  }
  return `${Date.now().toString(16)}_${Math.random().toString(16).slice(2)}`;
}

async function hashPassword(password: string, salt: string): Promise<string> {
  const input = `${salt}:${password}`;
  if (typeof crypto !== 'undefined' && crypto.subtle) {
    const enc = new TextEncoder();
    const keyMaterial = await crypto.subtle.importKey(
      'raw',
      enc.encode(password),
      { name: 'PBKDF2' },
      false,
      ['deriveBits']
    );
    const derived = await crypto.subtle.deriveBits(
      {
        name: 'PBKDF2',
        salt: enc.encode(salt),
        iterations: 100000,
        hash: 'SHA-256',
      },
      keyMaterial,
      256
    );
    return bytesToHex(new Uint8Array(derived));
  }
  // Fallback deterministic digest for non-WebCrypto test runtimes
  let hash = 2166136261;
  for (let i = 0; i < input.length; i++) {
    hash ^= input.charCodeAt(i);
    hash = Math.imul(hash, 16777619);
  }
  return (hash >>> 0).toString(16).padStart(8, '0');
}

function readAccounts(): StoredLocalAccount[] {
  try {
    const raw = localStorage.getItem(ACCOUNTS_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeAccounts(accounts: StoredLocalAccount[]): void {
  localStorage.setItem(ACCOUNTS_KEY, JSON.stringify(accounts));
}

function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

export function validateEmailAndPassword(email: string, password: string): void {
  const cleanEmail = normalizeEmail(email);
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(cleanEmail)) {
    throw new Error('Please enter a valid email address.');
  }
  if (!password || password.length < 6) {
    throw new Error('Password must be at least 6 characters long.');
  }
}

export const LocalAuthService = {
  getActiveSession(): UserProfile | null {
    try {
      const raw = localStorage.getItem(ACTIVE_SESSION_KEY);
      if (!raw) return null;
      const parsed = JSON.parse(raw) as UserProfile;
      if (parsed && parsed.uid && !parsed.isGuest && parsed.email) {
        return parsed;
      }
    } catch {}
    return null;
  },

  saveActiveSession(user: UserProfile): void {
    try {
      localStorage.setItem(ACTIVE_SESSION_KEY, JSON.stringify(user));
    } catch {}
  },

  clearActiveSession(): void {
    try {
      localStorage.removeItem(ACTIVE_SESSION_KEY);
    } catch {}
  },

  async register(email: string, password: string, displayName?: string): Promise<UserProfile> {
    validateEmailAndPassword(email, password);
    const cleanEmail = normalizeEmail(email);
    const accounts = readAccounts();

    if (accounts.some((acc) => normalizeEmail(acc.email) === cleanEmail)) {
      throw new Error('An account with this email already exists. Please sign in instead.');
    }

    const salt = generateSalt();
    const passwordHash = await hashPassword(password, salt);
    const uid = `usr_${salt.slice(0, 12)}_${Date.now().toString(36)}`;
    const cleanName = (displayName || '').trim() || cleanEmail.split('@')[0] || 'Listener';

    const newAccount: StoredLocalAccount = {
      uid,
      email: cleanEmail,
      displayName: cleanName,
      salt,
      passwordHash,
      createdAt: Date.now(),
    };

    accounts.push(newAccount);
    writeAccounts(accounts);

    const profile: UserProfile = {
      uid: newAccount.uid,
      email: newAccount.email,
      displayName: newAccount.displayName,
      photoURL: null,
      isGuest: false,
    };
    this.saveActiveSession(profile);
    return profile;
  },

  async signIn(email: string, password: string): Promise<UserProfile> {
    validateEmailAndPassword(email, password);
    const cleanEmail = normalizeEmail(email);
    const accounts = readAccounts();
    const existing = accounts.find((acc) => normalizeEmail(acc.email) === cleanEmail);

    if (!existing) {
      throw new Error('No account found with this email. Please create an account first.');
    }

    const candidateHash = await hashPassword(password, existing.salt);
    if (candidateHash !== existing.passwordHash) {
      throw new Error('Incorrect password. Please try again.');
    }

    const profile: UserProfile = {
      uid: existing.uid,
      email: existing.email,
      displayName: existing.displayName,
      photoURL: null,
      isGuest: false,
    };
    this.saveActiveSession(profile);
    return profile;
  },
};
