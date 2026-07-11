import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {getDatabase} from "firebase-admin/database";
import {Action, makePatch, MatchState, reduce, WorldDefinition} from "./gameReducer.js";

const db = getFirestore(); const rtdb = getDatabase();

export async function advanceRoomDay(roomID: string, nowMillis = Date.now()): Promise<boolean> {
  const room = db.collection("rooms").doc(roomID), checkpointRef = room.collection("state").doc("checkpoint"); let patch;
  await db.runTransaction(async tx => {
    const [roomSnap, checkpointSnap, worldSnap] = await Promise.all([tx.get(room), tx.get(checkpointRef), tx.get(room.collection("world").doc("definition"))]);
    const state = checkpointSnap.data() as MatchState | undefined; if (!state || roomSnap.data()?.status !== "active" || nowMillis < state.dayStartServerMillis + 60_000) return;
    const action: Action = {actionID: `server-day-${state.day + 1}-${state.revision}`, participantID: "server", expectedRevision: state.revision, schemaVersion: 1, rulesVersion: 1, payload: {type: "advanceDay"}};
    const next = reduce(action, state, worldSnap.data() as WorldDefinition, nowMillis).state; next.revision = state.revision + 1; patch = makePatch(action.actionID, next.revision, state, next);
    tx.set(checkpointRef, next); tx.create(room.collection("events").doc(String(next.revision).padStart(12, "0")), {revision: next.revision, actionID: action.actionID, participantID: "server", payload: action.payload, patch, acceptedAt: FieldValue.serverTimestamp()});
  });
  if (patch) await rtdb.ref(`patches/${roomID}/${String((patch as {revision: number}).revision).padStart(12, "0")}`).set(patch);
  return Boolean(patch);
}

export async function advanceDueRooms(): Promise<void> {
  const rooms = await db.collection("rooms").where("status", "==", "active").limit(100).get();
  await Promise.all(rooms.docs.map(room => advanceRoomDay(room.id)));
}
