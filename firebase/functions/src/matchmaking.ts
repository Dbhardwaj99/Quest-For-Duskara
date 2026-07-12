import {FieldValue} from "firebase-admin/firestore";
import {CallableRequest, HttpsError} from "firebase-functions/v2/https";
import {addParticipant, createRoomHandler, joinRoomHandler, requireUID, RoomSession} from "./roomService.js";
import {setRoomClaim} from "./notifications.js";

import {db} from "./admin.js";

export async function joinMatchmakingHandler(request: CallableRequest): Promise<{room?: RoomSession}> {
  const uid = requireUID(request); const ticket = db.collection("matchmakingTickets").doc(uid);
  const existing = await ticket.get();
  if (existing.data()?.roomID) return joinRoomHandler({...request, data: {roomID: existing.data()!.roomID}} as CallableRequest);

  const waiting = await db.collection("matchmakingTickets").where("status", "==", "waiting").limit(8).get();
  const opponent = waiting.docs.find(doc => doc.id !== uid);
  if (!opponent) {
    await ticket.set({participantID: uid, displayName: String(request.data?.displayName ?? "Wayfarer").slice(0, 32), status: "waiting", createdAt: FieldValue.serverTimestamp()});
    return {};
  }

  let room: RoomSession | undefined;
  await db.runTransaction(async tx => {
    const [ownSnap, opponentSnap] = await Promise.all([tx.get(ticket), tx.get(opponent.ref)]);
    if ((ownSnap.exists && ownSnap.data()?.status !== "waiting") || opponentSnap.data()?.status !== "waiting") {
      throw new HttpsError("aborted", "Matchmaking race; retry.");
    }
    tx.set(ticket, {participantID: uid, displayName: String(request.data?.displayName ?? "Wayfarer").slice(0, 32), status: "matching", createdAt: FieldValue.serverTimestamp()}, {merge: true});
    tx.update(opponent.ref, {status: "matching"});
  });
  try {
    room = (await createRoomHandler({...request, data: {visibility: "publicMatchmaking", displayName: request.data?.displayName}} as CallableRequest)).room;
    await addParticipant(room.roomID, opponent.id, opponent.data().displayName);
    await setRoomClaim(opponent.id, room.roomID, true);
    await Promise.all([
      ticket.set({participantID: uid, status: "assigned", roomID: room.roomID, assignedAt: FieldValue.serverTimestamp()}),
      opponent.ref.set({status: "assigned", roomID: room.roomID, assignedAt: FieldValue.serverTimestamp()}, {merge: true})
    ]);
    return {room: (await joinRoomHandler({...request, data: {roomID: room.roomID}} as CallableRequest)).room};
  } catch (error) {
    await opponent.ref.set({status: "waiting"}, {merge: true});
    throw error;
  }
}

export async function cancelMatchmakingHandler(request: CallableRequest): Promise<{}> {
  const uid = requireUID(request); const ref = db.collection("matchmakingTickets").doc(uid); const snap = await ref.get();
  if (snap.data()?.status === "assigned") throw new HttpsError("failed-precondition", "A room is already assigned.");
  await ref.delete(); return {};
}
