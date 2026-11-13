import { initializeApp, getApps, getApp } from 'firebase/app';
import {
  getAuth,
  GoogleAuthProvider,
  signInWithPopup,
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  signOut as fbSignOut,
  onAuthStateChanged,
  User as FirebaseUser,
} from 'firebase/auth';
import {
  getFirestore,
  setLogLevel,
  doc,
  setDoc,
  getDoc,
  Firestore,
} from 'firebase/firestore';
import firebaseConfigJson from '../../firebase-applet-config.json';
import { Song, Playlist } from '../types';

// Silence noisy @firebase/firestore offline/WebChannel console warnings when operating in local/offline mode
try {
  setLogLevel('silent');
} catch {}

const app = getApps().length === 0 ? initializeApp(firebaseConfigJson) : getApp();

export const auth = getAuth(app);
export const googleProvider = new GoogleAuthProvider();
googleProvider.addScope('https://www.googleapis.com/auth/drive.file');

// In-memory access token cache for Google Workspace APIs (per security guidelines)
let cachedDriveAccessToken: string | null = null;

export const setDriveAccessToken = (token: string | null) => {
  cachedDriveAccessToken = token;
};

export const getDriveAccessToken = () => cachedDriveAccessToken;

// Clear cached token on sign-out
auth.onAuthStateChanged((user) => {
  if (!user) {
    cachedDriveAccessToken = null;
  }
});

const configuredDatabaseId = (firebaseConfigJson as Record<string, any>).firestoreDatabaseId;
let firestoreInstance: Firestore | null = null;

function getActiveFirestore(): Firestore | null {
  if (!configuredDatabaseId) {
    return null;
  }
  if (!firestoreInstance) {
    firestoreInstance = getFirestore(app, configuredDatabaseId);
  }
  return firestoreInstance;
}

export interface CloudUserData {
  favorites?: Song[];
  playlists?: Playlist[];
  history?: Song[];
  updatedAt?: number;
}

const LOCAL_CLOUD_SYNC_PREFIX = 'twilight_cloud_profile_v1_';

export class CloudSyncService {
  static async saveUserData(
    uid: string,
    data: { favorites?: Song[]; playlists?: Playlist[]; history?: Song[] }
  ): Promise<void> {
    if (!uid) return;
    const cleanPayload = JSON.parse(
      JSON.stringify({
        ...data,
        updatedAt: Date.now(),
      })
    );

    try {
      localStorage.setItem(`${LOCAL_CLOUD_SYNC_PREFIX}${uid}`, JSON.stringify(cleanPayload));
    } catch {}

    const activeDb = getActiveFirestore();
    if (!activeDb || !auth.currentUser || auth.currentUser.uid !== uid) {
      return;
    }

    try {
      const userRef = doc(activeDb, 'users', uid);
      await setDoc(userRef, cleanPayload, { merge: true });
    } catch {
      // Operate seamlessly in local/offline mode
    }
  }

  static async loadUserData(uid: string): Promise<CloudUserData | null> {
    if (!uid) return null;

    const activeDb = getActiveFirestore();
    if (activeDb && auth.currentUser && auth.currentUser.uid === uid) {
      try {
        const userRef = doc(activeDb, 'users', uid);
        const snap = await getDoc(userRef);
        if (snap.exists()) {
          return snap.data() as CloudUserData;
        }
      } catch {
        // Fallback to local profile snapshot
      }
    }

    try {
      const cached = localStorage.getItem(`${LOCAL_CLOUD_SYNC_PREFIX}${uid}`);
      if (cached) {
        return JSON.parse(cached) as CloudUserData;
      }
    } catch {}

    return null;
  }
}

export {
  signInWithPopup,
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  fbSignOut,
  onAuthStateChanged,
};
export type { FirebaseUser };

