import {createHash, randomInt} from "node:crypto";
import {FieldValue} from "firebase-admin/firestore";
import {CallableRequest, HttpsError} from "firebase-functions/v2/https";
import {requireUID} from "./roomService.js";

export type Building = {id: string; kind: string; x: number; y: number; level: number};
export type Town = {id: string; faction: string; armyStrength: number; resources: Record<string, number>; soldiers: Record<string, number>; buildings: Building[]};
export type News = {id: string; day: number; kind: string; message: string};
export type TradeOffer = {id: string; townID: string; partnerID: string; wants: Record<string, number>; gives: Record<string, number>; expiresOnDay: number};
export type MatchState = {roomID: string; revision: number; schemaVersion: number; rulesVersion: number; status: string; day: number; dayStartServerMillis: number; towns: Town[]; news: News[]; tradeOffers: TradeOffer[]; entityCounter: number};
export type WorldDefinition = {schemaVersion: number; seed: number; algorithmVersion: number; templateID: string; mapColumns: number; mapRows: number; aspectRatio: number; playableInset: number; towns: {id: string; name: string; isDuskara: boolean; biomeSides: Record<string, string>}[]; nodes: {townID: string; x: number; y: number}[]; connections: {from: string; to: string}[]; terrain: {column: number; row: number; terrain: string}[]; landmarks: unknown[]; territories: unknown[]; territoryAlgorithmVersion: number};
export type Payload = {type: string; [key: string]: unknown};
export type Action = {actionID: string; participantID: string; expectedRevision: number; schemaVersion: number; rulesVersion: number; payload: Payload};
export type Patch = {revision: number; actionID: string; day: number; dayStartServerMillis: number; status: string; updatedTowns: Town[]; appendedNews: News[]; tradeOffers: TradeOffer[]; entityCounter: number};
export type ActionResult = {actionID: string; status: "accepted" | "rejected" | "duplicate"; revision: number; rejectionReason?: string; patch?: Patch};

import {db, rtdb} from "./admin.js";
const building = {
  house: {cost: {gold: 25, skill: 10}, production: {}, workers: 0, people: 4, capacity: 8, edge: false},
  pier: {cost: {gold: 35, skill: 20}, production: {gold: 8}, workers: 2, people: 0, capacity: 0, edge: true},
  farm: {cost: {gold: 35, skill: 20}, production: {gold: 8, food: 14}, workers: 2, people: 0, capacity: 0, edge: false},
  factory: {cost: {gold: 45, skill: 10}, production: {skill: 7}, workers: 3, people: 0, capacity: 0, edge: false},
  barracks: {cost: {gold: 60, skill: 30}, production: {}, workers: 4, people: 0, capacity: 0, edge: false}
} as const;
const soldier = {archer: {cost: {gold: 20, skill: 5, food: 10}, power: 10, people: 1, upkeep: 2}, knight: {cost: {gold: 45, skill: 15, food: 25}, power: 20, people: 2, upkeep: 4}} as const;
const clone = <T>(value: T): T => structuredClone(value);
const amount = (town: Town, kind: string) => town.resources[kind] ?? 0;
const canSpend = (town: Town, values: Record<string, number>) => Object.entries(values).every(([k, v]) => Number.isInteger(v) && v >= 0 && amount(town, k) >= v);
const spend = (town: Town, values: Record<string, number>) => Object.entries(values).forEach(([k, v]) => town.resources[k] = amount(town, k) - v);
const add = (town: Town, values: Record<string, number>) => Object.entries(values).forEach(([k, v]) => town.resources[k] = Math.max(0, amount(town, k) + v));
const owned = (town: Town | undefined) => town?.faction === "player";
const strength = (roster: Record<string, number>) => (roster.archer ?? 0) * 10 + (roster.knight ?? 0) * 20;
const syncArmy = (town: Town) => { town.armyStrength = strength(town.soldiers); town.resources.soldiers = town.armyStrength; };

function deterministicUUID(seed: number, stream: number): string {
  const bytes = createHash("sha256").update(`${seed}:${stream}`).digest().subarray(0, 16);
  bytes[6] = (bytes[6] & 15) | 64; bytes[8] = (bytes[8] & 63) | 128;
  const hex = bytes.toString("hex"); return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

function record(state: MatchState, kind: string, message: string) {
  state.news.unshift({id: deterministicUUID(state.entityCounter, state.entityCounter + 0x1d0000), day: state.day, kind, message});
  state.entityCounter++; state.news = state.news.slice(0, 40);
}

function buildAction(payload: Payload, state: MatchState): string | undefined {
  const town = state.towns.find(t => t.id === payload.townID); const def = building[String(payload.kind) as keyof typeof building];
  const x = Number(payload.x), y = Number(payload.y);
  if (!town || !owned(town)) return "That town is not under your control.";
  if (!def || !Number.isInteger(x) || !Number.isInteger(y)) return "Malformed command.";
  if (x < 0 || y < 0 || x >= 3 || y >= 3) return "That plot is outside the town grid.";
  if (town.buildings.some(b => b.x === x && b.y === y)) return "That plot is already occupied.";
  if (payload.kind === "pier" && town.buildings.some(b => b.kind === "pier")) return "This town already has a Pier.";
  if (def.edge && x !== 0 && y !== 0 && x !== 2 && y !== 2) return "This building must be placed on the town's edge, by the water.";
  if (!canSpend(town, def.cost)) return "Not enough resources.";
  const workers = town.buildings.reduce((n, b) => n + (building[b.kind as keyof typeof building]?.workers ?? 0), 0);
  if (amount(town, "people") - workers < def.workers) return "Not enough free people.";
  spend(town, def.cost); add(town, {people: def.people});
  town.buildings.push({id: deterministicUUID(state.entityCounter++, state.entityCounter + 0x1d0000), kind: String(payload.kind), x, y, level: 1});
  record(state, "buildingConstruction", `You built ${String(payload.kind)}.`); return undefined;
}

function upgradeAction(payload: Payload, state: MatchState): string | undefined {
  const town = state.towns.find(t => t.id === payload.townID); if (!town || !owned(town)) return "That town is not under your control.";
  const item = town.buildings.find(b => b.id === payload.buildingID); const def = item && building[item.kind as keyof typeof building];
  if (!item || !def) return "Missing building definition."; if (item.level >= 3) return "This building is already fully upgraded.";
  const cost = Object.fromEntries(Object.entries(def.cost).map(([k, v]) => [k, v * (item.level + 1)]));
  if (!canSpend(town, cost)) return "Not enough resources."; spend(town, cost); item.level++; add(town, {people: def.people * item.level}); return undefined;
}

function trainAction(payload: Payload, state: MatchState): string | undefined {
  const town = state.towns.find(t => t.id === payload.townID); const def = soldier[String(payload.soldier) as keyof typeof soldier];
  if (!town || !owned(town)) return "That town is not under your control."; if (!def) return "Malformed command.";
  if (!town.buildings.some(b => b.kind === "barracks")) return "Build a barracks before training soldiers.";
  if (!canSpend(town, def.cost)) return "Not enough resources to train that soldier.";
  const workers = town.buildings.reduce((n, b) => n + (building[b.kind as keyof typeof building]?.workers ?? 0), 0);
  if (amount(town, "people") - workers < def.people) return "Not enough free people to train that soldier.";
  const capacity = town.buildings.reduce((n, b) => n + (building[b.kind as keyof typeof building]?.capacity ?? 0) * b.level, 0);
  const manpower = (town.soldiers.archer ?? 0) + (town.soldiers.knight ?? 0) * 2;
  if (manpower + def.people > Math.max(1, capacity)) return "Army size is at the population cap for this town.";
  spend(town, def.cost); add(town, {people: -def.people}); town.soldiers[String(payload.soldier)] = (town.soldiers[String(payload.soldier)] ?? 0) + 1; syncArmy(town);
  record(state, "soldierTraining", `You trained ${String(payload.soldier)}.`); return undefined;
}

function transferAction(payload: Payload, state: MatchState): string | undefined {
  const from = state.towns.find(t => t.id === payload.fromTownID), to = state.towns.find(t => t.id === payload.toTownID);
  if (from === to) return "Choose two different towns."; if (!from || !owned(from)) return "Source town is not controlled."; if (!to || !owned(to)) return "Destination town is not controlled.";
  const values = payload.amounts as Record<string, number>; if (!values || Object.values(values).some(v => !Number.isInteger(v) || v <= 0)) return "Malformed command.";
  const requested = values.soldiers;
  if (requested) {
    if (from.armyStrength < requested) return "The source town cannot send that much.";
    let remaining = requested; const moved: Record<string, number> = {};
    for (const kind of ["knight", "archer"] as const) { const count = Math.min(from.soldiers[kind] ?? 0, Math.floor(remaining / soldier[kind].power)); if (count) { moved[kind] = count; remaining -= count * soldier[kind].power; } }
    if (!Object.keys(moved).length) { const kind = (from.soldiers.archer ?? 0) ? "archer" : "knight"; moved[kind] = 1; }
    for (const [kind, count] of Object.entries(moved)) { from.soldiers[kind] -= count; to.soldiers[kind] = (to.soldiers[kind] ?? 0) + count; }
    syncArmy(from); syncArmy(to);
  } else { if (!canSpend(from, values)) return "The source town cannot send that much."; spend(from, values); add(to, values); }
  record(state, "resourceTransfer", "You transferred resources."); return undefined;
}

function distances(source: string, world: WorldDefinition) {
  const result = new Map<string, number>([[source, 0]]), queue = [source];
  for (let i = 0; i < queue.length; i++) for (const edge of world.connections) { const next = edge.from === queue[i] ? edge.to : edge.to === queue[i] ? edge.from : ""; if (next && !result.has(next)) { result.set(next, result.get(queue[i])! + 1); queue.push(next); } }
  return result;
}

function attackAction(payload: Payload, state: MatchState, world: WorldDefinition): string | undefined {
  const from = state.towns.find(t => t.id === payload.fromTownID), target = state.towns.find(t => t.id === payload.targetTownID);
  if (!from || !owned(from) || !target || owned(target)) return "Attack failed. Your committed soldiers were lost.";
  const definition = world.towns.find(t => t.id === target.id), duskara = world.towns.find(t => t.isDuskara)!;
  const graph = distances(duskara.id, world), max = Math.max(...graph.values(), 1);
  let defense = target.armyStrength + Math.round(target.armyStrength * .35) + (definition?.isDuskara ? 55 : target.faction === "enemy" ? 18 : 0) + Math.max(0, max - (graph.get(target.id) ?? 0)) * 4;
  if (from.armyStrength <= defense) return "Attack failed. Your committed soldiers were lost.";
  const survivors = Math.max(1, from.armyStrength - defense - Math.max(1, Math.round((from.armyStrength - defense) * .25)));
  from.soldiers = {}; syncArmy(from); target.resources.gold = Math.floor(amount(target, "gold") * .5); target.resources.skill = Math.floor(amount(target, "skill") * .5);
  target.faction = "player"; target.soldiers = {knight: Math.floor(survivors / 20)}; if (survivors % 20) target.soldiers.archer = 1; syncArmy(target);
  record(state, "cityCapture", "You captured a town."); if (definition?.isDuskara) { state.status = "victory"; record(state, "duskaraAttack", "You conquered Duskara"); }
  return undefined;
}

function tradeAction(payload: Payload, state: MatchState, accept: boolean): string | undefined {
  const town = state.towns.find(t => t.id === payload.townID), index = state.tradeOffers.findIndex(o => o.id === payload.offerID && o.townID === payload.townID);
  if (!town || !owned(town)) return "That town is not under your control.";
  if (index < 0) return "That trade ship has already sailed.";
  const offer = state.tradeOffers[index];
  if (accept) { if (!canSpend(town, offer.wants)) return "Not enough resources for this trade."; spend(town, offer.wants); add(town, offer.gives); record(state, "resourceTransfer", "You completed a trade."); }
  state.tradeOffers.splice(index, 1); return undefined;
}

function advanceDay(state: MatchState, world: WorldDefinition, nowMillis: number) {
  state.day++;
  for (const town of state.towns) {
    for (const item of town.buildings) { const def = building[item.kind as keyof typeof building]; if (def) add(town, Object.fromEntries(Object.entries(def.production).map(([k, v]) => [k, v * item.level]))); }
    let need = (town.soldiers.archer ?? 0) * 2 + (town.soldiers.knight ?? 0) * 4;
    if (amount(town, "food") >= need) add(town, {food: -need}); else { town.resources.food = 0; while (need > 0 && town.armyStrength > 0) { const kind = (town.soldiers.knight ?? 0) ? "knight" : "archer"; town.soldiers[kind]--; add(town, {people: soldier[kind].people}); need -= soldier[kind].upkeep; } syncArmy(town); }
  }
  const scheduled = state.dayStartServerMillis + 60_000; state.dayStartServerMillis = state.dayStartServerMillis ? Math.min(nowMillis, scheduled) : nowMillis;
  state.tradeOffers = state.tradeOffers.filter(o => o.expiresOnDay > state.day);
  for (const town of state.towns.filter(t => owned(t) && t.buildings.some(b => b.kind === "pier"))) {
    if (state.tradeOffers.some(o => o.townID === town.id)) continue;
    const edge = world.connections.find(e => e.from === town.id || e.to === town.id), partnerID = edge?.from === town.id ? edge.to : edge?.from;
    if (partnerID && state.towns.find(t => t.id === partnerID)?.faction === "neutral") state.tradeOffers.push({id: `trade-${state.day}-${town.id}`, townID: town.id, partnerID, wants: {gold: 15}, gives: {food: 20}, expiresOnDay: state.day + 1});
  }
}

export function reduce(action: Action, input: MatchState, world: WorldDefinition, nowMillis: number): {state: MatchState; failure?: string} {
  const state = clone(input); let failure: string | undefined;
  switch (action.payload.type) {
    case "build": failure = buildAction(action.payload, state); break;
    case "upgradeBuilding": failure = upgradeAction(action.payload, state); break;
    case "trainSoldier": failure = trainAction(action.payload, state); break;
    case "transferResources": failure = transferAction(action.payload, state); break;
    case "attack": failure = attackAction(action.payload, state, world); break;
    case "acceptTrade": failure = tradeAction(action.payload, state, true); break;
    case "declineTrade": failure = tradeAction(action.payload, state, false); break;
    case "advanceDay": advanceDay(state, world, nowMillis); break;
    default: failure = "Malformed command.";
  }
  return failure ? {state: input, failure} : {state};
}

export function makePatch(actionID: string, revision: number, before: MatchState, after: MatchState): Patch {
  const old = new Map(before.towns.map(t => [t.id, JSON.stringify(t)]));
  return {revision, actionID, day: after.day, dayStartServerMillis: after.dayStartServerMillis, status: after.status, updatedTowns: after.towns.filter(t => old.get(t.id) !== JSON.stringify(t)), appendedNews: after.news.slice(0, Math.max(0, after.news.length - before.news.length)), tradeOffers: after.tradeOffers, entityCounter: after.entityCounter};
}

function rejected(action: Action, revision: number, reason: string): ActionResult { return {actionID: action.actionID, status: "rejected", revision, rejectionReason: reason}; }

export async function submitGameActionHandler(request: CallableRequest): Promise<ActionResult> {
  const uid = requireUID(request), roomID = String(request.data?.roomID ?? ""), action = request.data?.action as Action;
  if (!action || !/^[A-Za-z0-9-]{8,80}$/.test(action.actionID ?? "")) throw new HttpsError("invalid-argument", "Invalid action.");
  const roomRef = db.collection("rooms").doc(roomID), checkpointRef = roomRef.collection("state").doc("checkpoint"), processedRef = roomRef.collection("processedActions").doc(action.actionID);
  let outcome!: ActionResult;
  await db.runTransaction(async tx => {
    const [roomSnap, checkpointSnap, processedSnap, worldSnap] = await Promise.all([tx.get(roomRef), tx.get(checkpointRef), tx.get(processedRef), tx.get(roomRef.collection("world").doc("definition"))]);
    const room = roomSnap.data(), checkpoint = checkpointSnap.data() as MatchState | undefined;
    if (!(room?.memberIDs as string[] | undefined)?.includes(uid)) throw new HttpsError("permission-denied", "Not an active room member.");
    if (processedSnap.exists) { outcome = processedSnap.data()!.outcome as ActionResult; return; }
    if (!checkpoint || room?.status !== "active") throw new HttpsError("failed-precondition", "The match is not active.");
    if (action.schemaVersion !== 1 || action.rulesVersion !== 1) outcome = rejected(action, checkpoint.revision, "This command needs a newer version of the game.");
    else if (action.expectedRevision !== checkpoint.revision) outcome = rejected(action, checkpoint.revision, "Out of date. Try again.");
    else {
      action.participantID = uid;
      const reduced = reduce(action, checkpoint, worldSnap.data() as WorldDefinition, Date.now());
      if (reduced.failure) outcome = rejected(action, checkpoint.revision, reduced.failure);
      else {
        reduced.state.revision = checkpoint.revision + 1; const patch = makePatch(action.actionID, reduced.state.revision, checkpoint, reduced.state);
        outcome = {actionID: action.actionID, status: "accepted", revision: reduced.state.revision, patch};
        tx.set(checkpointRef, reduced.state); tx.create(roomRef.collection("events").doc(String(reduced.state.revision).padStart(12, "0")), {revision: reduced.state.revision, actionID: action.actionID, participantID: uid, payload: action.payload, patch, acceptedAt: FieldValue.serverTimestamp()});
      }
    }
    tx.create(processedRef, {participantID: uid, outcome, processedAt: FieldValue.serverTimestamp()});
  });
  if (outcome.patch) await rtdb.ref(`patches/${roomID}/${String(outcome.revision).padStart(12, "0")}`).set(outcome.patch);
  return outcome;
}

export async function fetchCheckpointHandler(request: CallableRequest): Promise<{room: unknown; world: WorldDefinition; checkpoint: MatchState; serverNowMillis: number}> {
  const uid = requireUID(request), roomID = String(request.data?.roomID ?? ""), roomRef = db.collection("rooms").doc(roomID);
  const [room, world, checkpoint] = await Promise.all([roomRef.get(), roomRef.collection("world").doc("definition").get(), roomRef.collection("state").doc("checkpoint").get()]);
  if (!(room.data()?.memberIDs as string[] | undefined)?.includes(uid)) throw new HttpsError("permission-denied", "Not a room member.");
  if (!world.exists || !checkpoint.exists) throw new HttpsError("failed-precondition", "The campaign has not started.");
  return {room: {...room.data()!.publicSession, localParticipantID: uid}, world: world.data() as WorldDefinition, checkpoint: checkpoint.data() as MatchState, serverNowMillis: Date.now()};
}

export function createInitialGame(roomID: string, seed = randomInt(1_000_000), nowMillis = Date.now()): {world: WorldDefinition; state: MatchState} {
  const names = ["Hearthglen", "Green Hollow", "Ironridge", "Mosswatch", "Ashbarrow", "Pinefall", "Stonewake", "Rivergate", "Brindle Keep", "Oakmere", "Frostford", "Briarwall", "Duskwatch", "Sunreach", "Valehold", "Cinder Pass", "Deepwood", "Crownhill", "Greyfen", "Moonford", "Westmere", "Northbarrow", "Dawnfield", "Elderwick", "Foxgrove", "Highmere", "Willowdeep", "Amberfall", "Ravenford", "Thornwatch", "Glasswater", "Kingsford", "Mistvale", "Barrowmere", "Emberwick", "Wolfscar", "Blackfen", "Grimhaven", "Redspire", "Duskara"];
  const townDefs = names.map((name, i) => ({id: deterministicUUID(seed, i), name, isDuskara: i === 39, biomeSides: {left: i % 2 ? "forest" : "mountain", right: "forest", top: "mountain", bottom: "forest"}}));
  const towns: Town[] = townDefs.map((t, i) => ({id: t.id, faction: i === 0 ? "player" : i === 39 ? "duskara" : i >= 35 ? "enemy" : "neutral", armyStrength: i === 0 ? 0 : i === 39 ? 180 : 10 + i, resources: {gold: i ? 60 + i * 6 : 600, skill: i ? 20 + i : 300, food: i ? 30 : 100, people: i ? 4 : 12, soldiers: i === 0 ? 0 : 10 + i}, soldiers: i === 0 ? {} as Record<string, number> : {archer: Math.ceil((10 + i) / 10)}, buildings: [{id: deterministicUUID(seed, 1000 + i * 2), kind: "house", x: 1, y: 1, level: 1}, {id: deterministicUUID(seed, 1001 + i * 2), kind: "pier", x: 1, y: 2, level: 1}]}));
  towns.forEach(t => syncArmy(t));
  const connections = townDefs.slice(1).map((town, i) => ({from: townDefs[i].id, to: town.id}));
  const terrain = Array.from({length: 2320}, (_, i) => ({column: i % 58, row: Math.floor(i / 58), terrain: i % 7 ? "ocean" : "grassland"}));
  const world: WorldDefinition = {schemaVersion: 1, seed, algorithmVersion: 1, templateID: "server-coop-v1", mapColumns: 58, mapRows: 40, aspectRatio: 1.45, playableInset: .04, towns: townDefs, nodes: townDefs.map((t, i) => ({townID: t.id, x: (i % 8 + 1) / 9, y: (Math.floor(i / 8) + 1) / 6})), connections, terrain, landmarks: [], territories: [], territoryAlgorithmVersion: 1};
  return {world, state: {roomID, revision: 0, schemaVersion: 1, rulesVersion: 1, status: "active", day: 1, dayStartServerMillis: nowMillis, towns, news: [], tradeOffers: [], entityCounter: 10_000}};
}
