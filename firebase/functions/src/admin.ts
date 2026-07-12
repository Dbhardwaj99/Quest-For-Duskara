import {getApps, initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {getDatabase} from "firebase-admin/database";

if (!getApps().length) initializeApp(process.env.FIREBASE_DATABASE_EMULATOR_HOST ? {
  projectId: process.env.GCLOUD_PROJECT ?? "quest-for-duskara-test",
  databaseURL: `http://${process.env.FIREBASE_DATABASE_EMULATOR_HOST}?ns=${process.env.GCLOUD_PROJECT ?? "quest-for-duskara-test"}`
} : {});

export const db = getFirestore();
export const rtdb = getDatabase();
