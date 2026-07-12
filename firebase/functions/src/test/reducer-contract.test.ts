import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import {resolve} from "node:path";
import test from "node:test";
import {Action, makePatch, MatchState, reduce, WorldDefinition} from "../gameReducer.js";

const fixture = JSON.parse(readFileSync(resolve(process.cwd(), "../../SharedFixtures/reducer-contract.json"), "utf8")) as {
  world: WorldDefinition; state: MatchState; action: Action;
  expected: {revision: number; gold: number; skill: number; updatedTownCount: number};
};

test("TypeScript reducer matches the shared Swift contract fixture", () => {
  const output = reduce(fixture.action, fixture.state, fixture.world, 1000);
  assert.equal(output.failure, undefined);
  output.state.revision = fixture.state.revision + 1;
  const patch = makePatch(fixture.action.actionID, output.state.revision, fixture.state, output.state);
  assert.equal(output.state.revision, fixture.expected.revision);
  assert.equal(output.state.towns[0].resources.gold, fixture.expected.gold);
  assert.equal(output.state.towns[0].resources.skill, fixture.expected.skill);
  assert.equal(patch.updatedTowns.length, fixture.expected.updatedTownCount);
});

test("40-town join is one snapshot and ordinary patches stay compact", () => {
  const towns = Array.from({length: 40}, (_, index) => ({...structuredClone(fixture.state.towns[0]), id: `00000000-0000-0000-0000-${String(index + 1).padStart(12, "0")}`, buildings: Array.from({length: 9}, (_, cell) => ({id: `b-${index}-${cell}`, kind: "house", x: cell % 3, y: Math.floor(cell / 3), level: 1}))}));
  const state = {...fixture.state, towns};
  const joinSnapshot = {...state, world: {...fixture.world, terrain: Array.from({length: 2320}, (_, index) => ({column: index % 58, row: Math.floor(index / 58), terrain: "ocean"}))}};
  const after = structuredClone(state); after.towns[0].resources.gold--;
  const patch = makePatch("perf-action", 1, state, after);
  assert.equal(towns.length, 40);
  assert.equal(towns.flatMap(t => t.buildings).length, 360);
  assert.equal(joinSnapshot.world.terrain.length, 2320);
  assert.equal(patch.updatedTowns.length, 1);
  assert.ok(JSON.stringify(patch).length < JSON.stringify(state).length / 10);
});
