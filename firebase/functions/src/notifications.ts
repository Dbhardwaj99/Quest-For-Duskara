import {getAuth} from "firebase-admin/auth";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {CallableRequest, HttpsError} from "firebase-functions/v2/https";

const db = getFirestore();

export async function setRoomClaim(uid: string, roomID: string, allowed: boolean): Promise<void> {
  const user = await getAuth().getUser(uid), rooms = {...(user.customClaims?.rooms as Record<string, boolean> | undefined)};
  if (allowed) rooms[roomID] = true; else delete rooms[roomID];
  await getAuth().setCustomUserClaims(uid, {...user.customClaims, rooms});
}

export async function registerNotificationTokenHandler(request: CallableRequest): Promise<{}> {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in first.");
  const uid = request.auth.uid, token = String(request.data?.token ?? "");
  if (token.length < 32 || token.length > 4096) throw new HttpsError("invalid-argument", "Invalid notification token.");
  const id = Buffer.from(token).toString("base64url").slice(0, 500);
  await db.collection("notificationTokens").doc(uid).collection("tokens").doc(id).set({token, platform: String(request.data?.platform ?? "apple"), updatedAt: FieldValue.serverTimestamp()});
  return {};
}

export async function notifyUsers(uids: string[], title: string, body: string, data: Record<string, string>): Promise<void> {
  const snapshots = await Promise.all(uids.map(uid => db.collection("notificationTokens").doc(uid).collection("tokens").get()));
  const tokens = snapshots.flatMap(s => s.docs.map(d => String(d.data().token))).filter(Boolean);
  if (tokens.length) await getMessaging().sendEachForMulticast({tokens, notification: {title, body}, data});
}

export async function reconnectPrompt(roomID: string, uid: string): Promise<void> {
  const connections = await (await import("firebase-admin/database")).getDatabase().ref(`presence/${roomID}/${uid}/connections`).get();
  if (!connections.exists()) await notifyUsers([uid], "Connection lost", "Reconnect to converge on the shared campaign.", {kind: "reconnect", roomID});
}
