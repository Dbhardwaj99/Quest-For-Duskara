import {createHash, randomInt} from "node:crypto";
import {getApps, initializeApp} from "firebase-admin/app";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {getDatabase} from "firebase-admin/database";
import {CallableRequest, HttpsError} from "firebase-functions/v2/https";
import {createInitialGame} from "./gameReducer.js";
import {notifyUsers, setRoomClaim} from "./notifications.js";

if (!getApps().length) initializeApp();
const db = getFirestore();
const rtdb = getDatabase();
const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const now = () => Date.now();

export type Participant = {id: string; displayName: string; role: "owner" | "member"; joinedAtMillis: number};
export type RoomSession = {
  roomID: string; visibility: "privateCode" | "publicMatchmaking"; inviteCode?: string;
  localParticipantID: string; participants: Participant[]; status: "lobby" | "active" | "victory" | "defeat" | "abandoned";
};

export function requireUID(request: CallableRequest): string {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in to use multiplayer.");
  return request.auth.uid;
}

export function normalizeCode(value: unknown): string {
  return String(value ?? "").toUpperCase().replace(/[^A-Z0-9]/g, "");
}

export function hashCode(code: string): string {
  return createHash("sha256").update(code).digest("hex");
}

export function generateCode(): string {
  return Array.from({length: 6}, () => alphabet[randomInt(alphabet.length)]).join("");
}

function displayName(value: unknown): string {
  const name = String(value ?? "Wayfarer").trim().slice(0, 32);
  return name || "Wayfarer";
}

function session(roomID: string, data: FirebaseFirestore.DocumentData, uid: string): RoomSession {
  return {...data.publicSession, roomID, localParticipantID: uid};
}

export async function createRoomHandler(request: CallableRequest): Promise<{room: RoomSession}> {
  const uid = requireUID(request);
  const visibility = request.data?.visibility === "publicMatchmaking" ? "publicMatchmaking" : "privateCode";
  const roomRef = db.collection("rooms").doc();
  const participant: Participant = {id: uid, displayName: displayName(request.data?.displayName), role: "owner", joinedAtMillis: now()};

  for (let attempt = 0; attempt < 12; attempt++) {
    const code = visibility === "privateCode" ? generateCode() : undefined;
    const codeRef = code ? db.collection("inviteCodes").doc(hashCode(code)) : undefined;
    try {
      await db.runTransaction(async tx => {
        if (codeRef && (await tx.get(codeRef)).exists) throw new HttpsError("already-exists", "Invite collision.");
        const publicSession = {roomID: roomRef.id, visibility, ...(code ? {inviteCode: code} : {}), localParticipantID: uid, participants: [participant], status: "lobby"};
        tx.create(roomRef, {visibility, ownerID: uid, memberIDs: [uid], status: "lobby", readyParticipantIDs: [], inviteCodeHash: code ? hashCode(code) : null, publicSession, createdAt: FieldValue.serverTimestamp()});
        tx.create(roomRef.collection("members").doc(uid), {...participant, active: true});
        if (codeRef) tx.create(codeRef, {roomID: roomRef.id, createdAt: FieldValue.serverTimestamp()});
      });
      await setRoomClaim(uid, roomRef.id, true);
      return {room: session(roomRef.id, (await roomRef.get()).data()!, uid)};
    } catch (error) {
      if (!(error instanceof HttpsError) || error.code !== "already-exists") throw error;
    }
  }
  throw new HttpsError("resource-exhausted", "Could not allocate an invite code.");
}

export async function joinRoomHandler(request: CallableRequest): Promise<{room: RoomSession}> {
  const uid = requireUID(request);
  let roomID = String(request.data?.roomID ?? "");
  if (!roomID) {
    const code = normalizeCode(request.data?.inviteCode);
    if (code.length !== 6) throw new HttpsError("invalid-argument", "Invalid room code.");
    roomID = String((await db.collection("inviteCodes").doc(hashCode(code)).get()).data()?.roomID ?? "");
  }
  if (!roomID) throw new HttpsError("not-found", "Room not found.");
  await addParticipant(roomID, uid, request.data?.displayName, request.data?.roomID != null);
  await setRoomClaim(uid, roomID, true);
  const roomRef = db.collection("rooms").doc(roomID);
  return {room: session(roomID, (await roomRef.get()).data()!, uid)};
}

export async function addParticipant(roomID: string, uid: string, nameValue: unknown, rejoinOnly = false): Promise<void> {
  const roomRef = db.collection("rooms").doc(roomID);
  await db.runTransaction(async tx => {
    const snap = await tx.get(roomRef);
    if (!snap.exists) throw new HttpsError("not-found", "Room not found.");
    const data = snap.data()!;
    const existing = (data.memberIDs as string[]).includes(uid);
    if (rejoinOnly && !existing) throw new HttpsError("permission-denied", "You are not a member of this room.");
    if (!existing) {
      if (data.status !== "lobby") throw new HttpsError("failed-precondition", "The campaign has started.");
      if ((data.memberIDs as string[]).length >= 2) throw new HttpsError("resource-exhausted", "Room is full.");
      const participant: Participant = {id: uid, displayName: displayName(nameValue), role: "member", joinedAtMillis: now()};
      const participants = [...data.publicSession.participants, participant];
      tx.set(roomRef.collection("members").doc(uid), {...participant, active: true});
      tx.update(roomRef, {memberIDs: FieldValue.arrayUnion(uid), "publicSession.participants": participants});
    }
  });
}

export async function leaveRoomHandler(request: CallableRequest): Promise<{}> {
  const uid = requireUID(request); const roomID = String(request.data?.roomID ?? "");
  const roomRef = db.collection("rooms").doc(roomID);
  await db.runTransaction(async tx => {
    const snap = await tx.get(roomRef); if (!snap.exists) return;
    const data = snap.data()!; if (!(data.memberIDs as string[]).includes(uid)) return;
    const participants = (data.publicSession.participants as Participant[]).filter(p => p.id !== uid);
    const ownerID = data.ownerID === uid ? participants[0]?.id ?? "" : data.ownerID;
    if (participants[0] && data.ownerID === uid) participants[0].role = "owner";
    const status = participants.length ? data.status : "abandoned";
    tx.delete(roomRef.collection("members").doc(uid));
    tx.update(roomRef, {memberIDs: FieldValue.arrayRemove(uid), ownerID, status, readyParticipantIDs: FieldValue.arrayRemove(uid), "publicSession.participants": participants, "publicSession.status": status});
  });
  await rtdb.ref(`presence/${roomID}/${uid}`).remove();
  await setRoomClaim(uid, roomID, false);
  return {};
}

export async function setReadyHandler(request: CallableRequest): Promise<{}> {
  const uid = requireUID(request); const roomID = String(request.data?.roomID ?? ""); const ready = request.data?.ready === true;
  const roomRef = db.collection("rooms").doc(roomID); const snap = await roomRef.get();
  if (!(snap.data()?.memberIDs as string[] | undefined)?.includes(uid)) throw new HttpsError("permission-denied", "Not a room member.");
  await roomRef.update({readyParticipantIDs: ready ? FieldValue.arrayUnion(uid) : FieldValue.arrayRemove(uid)});
  await rtdb.ref(`lobbies/${roomID}/ready/${uid}`).set(ready || null);
  return {};
}

export async function startRoomHandler(request: CallableRequest): Promise<{room: RoomSession}> {
  const uid = requireUID(request); const roomID = String(request.data?.roomID ?? ""); const roomRef = db.collection("rooms").doc(roomID);
  const initial = createInitialGame(roomID);
  await db.runTransaction(async tx => {
    const snap = await tx.get(roomRef); if (!snap.exists) throw new HttpsError("not-found", "Room not found.");
    const data = snap.data()!; const members = data.memberIDs as string[]; const ready = data.readyParticipantIDs as string[];
    if (data.ownerID !== uid) throw new HttpsError("permission-denied", "Only the lobby owner can start.");
    if (members.length !== 2 || !members.every(id => ready.includes(id))) throw new HttpsError("failed-precondition", "Both players must be ready.");
    tx.create(roomRef.collection("world").doc("definition"), initial.world);
    tx.create(roomRef.collection("state").doc("checkpoint"), initial.state);
    tx.update(roomRef, {status: "active", "publicSession.status": "active", startedAt: FieldValue.serverTimestamp()});
  });
  const members = (await roomRef.get()).data()!.memberIDs as string[];
  await notifyUsers(members.filter(id => id !== uid), "Quest for Duskara", "Your cooperative campaign is ready.", {kind: "roomInvite", roomID});
  return {room: session(roomID, (await roomRef.get()).data()!, uid)};
}
