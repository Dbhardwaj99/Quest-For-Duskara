import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import {resolve} from "node:path";
import test, {after, before, beforeEach} from "node:test";
import {assertFails, assertSucceeds, initializeTestEnvironment, RulesTestEnvironment} from "@firebase/rules-unit-testing";
import {doc, getDoc, setDoc} from "firebase/firestore";
import {get, ref, set} from "firebase/database";
import {getAuth} from "firebase-admin/auth";
import {getFirestore} from "firebase-admin/firestore";
import {getDatabase} from "firebase-admin/database";
import {deleteApp, getApp} from "firebase-admin/app";
import {CallableRequest} from "firebase-functions/v2/https";
import {createRoomHandler, joinRoomHandler, setReadyHandler, startRoomHandler} from "../roomService.js";
import {fetchCheckpointHandler, submitGameActionHandler} from "../gameReducer.js";
import {joinMatchmakingHandler} from "../matchmaking.js";

const enabled = Boolean(process.env.FIRESTORE_EMULATOR_HOST && process.env.FIREBASE_DATABASE_EMULATOR_HOST);
let rules: RulesTestEnvironment;
const projectId = "quest-for-duskara-test";
const request = (uid: string, data: unknown): CallableRequest => ({auth: {uid, token: {aud: projectId, auth_time: 0, exp: 0, firebase: {identities: {}, sign_in_provider: "anonymous"}, iat: 0, iss: "", sub: uid}, rawToken: "test"}, data, rawRequest: {} as never, acceptsStreaming: false} as unknown as CallableRequest);

before(async () => {
  if (!enabled) return;
  rules = await initializeTestEnvironment({projectId, firestore: {rules: readFileSync(resolve(process.cwd(), "../firestore.rules"), "utf8")}, database: {rules: readFileSync(resolve(process.cwd(), "../database.rules.json"), "utf8")}});
});
beforeEach(async () => {
  if (!enabled) return;
  await rules.clearFirestore();
  await getDatabase().ref().set(null);
  for (const uid of ["u1", "u2", "u3", "u4"]) try { await getAuth().createUser({uid}); } catch { }
});
after(async () => {
  if (!enabled) return;
  await rules.cleanup();
  await deleteApp(getApp());
});

test("Firestore and RTDB rules deny authoritative writes and scope presence", {skip: !enabled}, async () => {
  await rules.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), "rooms/room-1"), {memberIDs: ["u1"]});
    await setDoc(doc(context.firestore(), "rooms/room-1/state/checkpoint"), {revision: 1});
    await set(ref(context.database(), "patches/room-1/000000000001"), {revision: 1});
  });
  const member = rules.authenticatedContext("u1", {rooms: {"room-1": true}}), stranger = rules.authenticatedContext("u2", {rooms: {}});
  await assertSucceeds(getDoc(doc(member.firestore(), "rooms/room-1")));
  await assertFails(getDoc(doc(stranger.firestore(), "rooms/room-1")));
  await assertFails(setDoc(doc(member.firestore(), "rooms/room-1/state/checkpoint"), {revision: 2}));
  await assertFails(setDoc(doc(member.firestore(), "rooms/room-1/members/u2"), {role: "member"}));
  await assertSucceeds(get(ref(member.database(), "patches/room-1")));
  await assertFails(set(ref(member.database(), "patches/room-1/000000000002"), {revision: 2}));
  await assertSucceeds(set(ref(member.database(), "presence/room-1/u1/connections/c1"), {connectedAt: Date.now()}));
  await assertFails(set(ref(stranger.database(), "presence/room-1/u1/connections/c2"), {connectedAt: Date.now()}));
});

test("invite collisions retry and matchmaking room codes remain discovery-only", {skip: !enabled}, async () => {
  const first = await createRoomHandler(request("u1", {visibility: "privateCode"}), () => "AAAAAA");
  let attempts = 0;
  const second = await createRoomHandler(request("u2", {visibility: "privateCode"}), () => attempts++ ? "BBBBBB" : "AAAAAA");
  assert.notEqual(first.room.roomID, second.room.roomID);
  await assert.rejects(joinRoomHandler(request("u3", {roomID: first.room.roomID})), /member/i);
  const joined = await joinRoomHandler(request("u3", {inviteCode: "aa-aa-aa"}));
  assert.equal(joined.room.roomID, first.room.roomID);
});

test("concurrent matchmaking attempts assign one shared room", {skip: !enabled}, async () => {
  await Promise.allSettled([
    joinMatchmakingHandler(request("u3", {displayName: "Three"})),
    joinMatchmakingHandler(request("u4", {displayName: "Four"}))
  ]);
  let snapshots = await Promise.all([getFirestore().collection("matchmakingTickets").doc("u3").get(), getFirestore().collection("matchmakingTickets").doc("u4").get()]);
  if (!snapshots.every(ticket => ticket.data()?.status === "assigned")) {
    await Promise.allSettled([joinMatchmakingHandler(request("u3", {})), joinMatchmakingHandler(request("u4", {}))]);
  }
  const tickets = await Promise.all([
    getFirestore().collection("matchmakingTickets").doc("u3").get(),
    getFirestore().collection("matchmakingTickets").doc("u4").get()
  ]);
  assert.equal(tickets[0].data()?.roomID, tickets[1].data()?.roomID);
  assert.equal(tickets[0].data()?.status, "assigned");
  assert.equal(tickets[1].data()?.status, "assigned");
});

test("two clients converge across build, upgrade, train, trade, attack, day, and reconnect", {skip: !enabled}, async () => {
  const created = await createRoomHandler(request("u1", {visibility: "privateCode", displayName: "One"}), () => "COOP22");
  const roomID = created.room.roomID;
  await joinRoomHandler(request("u2", {inviteCode: "coop22", displayName: "Two"}));
  await setReadyHandler(request("u1", {roomID, ready: true})); await setReadyHandler(request("u2", {roomID, ready: true}));
  await startRoomHandler(request("u1", {roomID}));

  const submit = async (uid: string, payload: Record<string, unknown>, actionID: string) => {
    const checkpoint = (await fetchCheckpointHandler(request(uid, {roomID}))).checkpoint;
    return submitGameActionHandler(request(uid, {roomID, action: {actionID, participantID: "spoofed", expectedRevision: checkpoint.revision, schemaVersion: 1, rulesVersion: 1, payload}}));
  };
  const initial = (await fetchCheckpointHandler(request("u1", {roomID}))).checkpoint, home = initial.towns[0].id;
  const built = await submit("u1", {type: "build", townID: home, kind: "farm", x: 0, y: 0}, "action-build-0001");
  assert.equal(built.status, "accepted");
  const duplicate = await submitGameActionHandler(request("u1", {roomID, action: {actionID: "action-build-0001", participantID: "other", expectedRevision: 0, schemaVersion: 1, rulesVersion: 1, payload: {type: "advanceDay"}}}));
  assert.equal(duplicate.revision, built.revision);
  const stale = await submitGameActionHandler(request("u2", {roomID, action: {actionID: "action-stale-001", participantID: "u1", expectedRevision: 0, schemaVersion: 1, rulesVersion: 1, payload: {type: "advanceDay"}}}));
  assert.equal(stale.status, "rejected");
  const farm = built.patch!.updatedTowns[0].buildings.find(b => b.kind === "farm")!;
  await submit("u2", {type: "upgradeBuilding", townID: home, buildingID: farm.id}, "action-upgrade-01");
  await submit("u1", {type: "build", townID: home, kind: "barracks", x: 2, y: 0}, "action-barracks-1");
  for (let i = 0; i < 4; i++) await submit(i % 2 ? "u2" : "u1", {type: "trainSoldier", townID: home, soldier: "archer"}, `action-train-000${i}`);
  await submit("u2", {type: "advanceDay"}, "action-day-000001");
  let checkpoint = (await fetchCheckpointHandler(request("u1", {roomID}))).checkpoint;
  assert.equal(checkpoint.tradeOffers.length, 1);
  await submit("u1", {type: "acceptTrade", townID: home, offerID: checkpoint.tradeOffers[0].id}, "action-trade-0001");
  checkpoint = (await fetchCheckpointHandler(request("u2", {roomID}))).checkpoint;
  const target = checkpoint.towns[1].id;
  await submit("u2", {type: "attack", fromTownID: home, targetTownID: target}, "action-attack-001");
  await submit("u1", {type: "transferResources", fromTownID: home, toTownID: target, amounts: {gold: 10}}, "action-transfer-1");

  await set(ref(rules.authenticatedContext("u1", {rooms: {[roomID]: true}}).database(), `presence/${roomID}/u1/connections/reconnect`), {connectedAt: Date.now()});
  await set(ref(rules.authenticatedContext("u1", {rooms: {[roomID]: true}}).database(), `presence/${roomID}/u1/connections/reconnect`), null);
  const one = await fetchCheckpointHandler(request("u1", {roomID})), two = await fetchCheckpointHandler(request("u2", {roomID}));
  assert.deepEqual(one.checkpoint, two.checkpoint);
  assert.equal(one.checkpoint.revision, 11);
  assert.equal(one.checkpoint.towns[1].faction, "player");
  const patches = await getDatabase().ref(`patches/${roomID}`).get();
  assert.equal(patches.numChildren(), 11);
});
