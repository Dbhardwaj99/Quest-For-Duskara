# Lane battle: production prompts (Phases 0–3)

Paste these prompts, one at a time and in order, into a coding agent (Claude
Code or Codex) working in this repo on branch `claude/lane-assault`. Every
prompt depends on the **Shared spec** below. Each prompt tells the agent to
read it first, so keep this file in the repo.

**Order:** 1 → 2 → **review gate** → 3 → 4 → 5 → 6 → 7 → 8 → 9. Each prompt
ends with acceptance checks; don't start the next one until they pass.

---

## Shared spec

### What exists
- The rules: `Models/LaneBattle.swift`. A pure value type with 3 lanes and
  positions from 0 (shore) to 1 (gate). It advances in fixed `LaneBattle.tick`
  steps and emits `events`. Tests live in `Tests/GameplayTests.swift`.
- The prototype view: `Views/LaneBattleView.swift`. A SpriteKit scene
  (`LaneBattleScene`) inside SwiftUI (`LaneBattleView`), drawn with
  placeholder shapes.
- `GameViewModel.assault` and `finishAssault`, plus `GameRules.assault` and
  `GameRules.conclude`. These are the game hooks; don't change their meaning.
- Art: `Tools/generate_settlement_models.py`. A Blender script that builds
  low-poly "soft clay" buildings from bevelled primitives, with the `COLORS`
  palette and the `material()`, `soften()` and `box()` helpers. The battle art
  **must** reuse this palette and these helpers so it matches the town.
- UI tokens: `Views/Components/Theme.swift` (`DuskaraTheme`: Avenir Next
  Condensed, dark warm panels, parchment ink, `accent` orange, `warmGold`).
  Buttons use `Views/Buttons/DuskaraButtonStyle.swift`.
- World themes: `WorldTheme` has village, desert, mountains and forest
  (`Views/3D/World3DTheme.swift`).
- Debug entry: launch a Debug build with `-battleSandbox` to go straight into
  a battle. It saves to a temporary folder.

### Camera: "F1 broadcast" side view
- The battlefield runs **horizontally**: the beach is on the left, the
  fortress on the right, and attackers move left to right. The three lanes are
  stacked in depth (lane 0 farthest from the camera, lane 2 nearest).
- One fixed view angle for **every** render (units, props, backdrops):
  - orthographic;
  - looking along Blender **+Y** (camera on the −Y side);
  - tilted **30° down** from horizontal;
  - no roll or yaw.
  The field runs along +X, depth is +Y, and up is +Z.
- Sprites are pre-rendered at that angle. Depth on screen comes from that
  pitch plus a small scale-down for the far lane (far lane 0.9×, near lane
  1.0×) and draw order (nearer units drawn on top). The player can pan and
  zoom but can never rotate or tilt the camera.

### Scale and resolution
- 1 Blender unit (BU) = 64 pt on screen at zoom 1.0. Everything renders at
  @2x, so 1 BU = 128 px.
- A knight is about 1.15 BU tall (≈74 pt) and an archer about 1.0 BU.
- The playable field is 24 BU long (shore to gate). The beach adds 4 BU on the
  left and the fortress 7 BU on the right. Lanes are spaced 1.6 BU apart in
  depth.
- Sprite frames are 192×192 px with the character's feet at a fixed anchor:
  50% across, 18% up from the bottom. The SpriteKit `anchorPoint` matches, so
  a node's position is where the feet touch the ground.

### Look
- The same soft-clay style as the settlement models: bevelled primitives,
  smooth shading, `roughness ≈ 0.88`, no textures, no outlines.
- Palette: `COLORS` from the settlement generator, plus two team colours:
  - `teamBlue` (0.36, 0.56, 0.86): the player;
  - `teamRed` (0.78, 0.33, 0.28): enemies (close to the existing `bannerRed`).
  Team colour goes only on cloth: tabard, hood, plume and banner. Both team
  variants are **baked** in Blender; there's no runtime tinting.
- Lighting is identical for every render:
  - one Sun from the upper left in front of the field (azimuth −35°,
    elevation 50°), strength ≈ 3, soft shadow (angle 8°);
  - world ambient ≈ 0.6 in a warm grey (0.62, 0.60, 0.56);
  - characters cast no shadow into their own frame. SpriteKit draws a blob
    shadow under them.
- Colour management: View Transform **Standard** (not AgX or Filmic), so
  rendered colours match the palette numbers and the SwiftUI theme.

### Compute budgets (hard limits)
- **Blender:**
  - **EEVEE** only (never Cycles); 16 render samples; no raytracing, bloom,
    motion blur or volumetrics; transparent film for sprites.
  - Low-poly: ≤ 3k triangles per character and ≤ 20k per backdrop scene.
  - Scripts run headless: `Blender -b --python <script> -- <args>`.
  - The full character set renders in **< 3 min** on an M4, and each theme's
    backdrop in **< 2 min**.
  - Scripts **skip work whose inputs haven't changed**: hash each job's
    parameters plus the script source and keep a `.manifest.json` beside the
    output.
- **Animation without rigs:** characters are separate parts (torso, head,
  arms, legs, weapon, shield) parented to pivot empties. Motion is keyframed
  procedurally in Python (sine curves on those pivots). No armatures, no
  weights, no physics.
- **Runtime:**
  - The battle renders at ≤ 60 fps (`preferredFramesPerSecond = 60`). The
    town's 3D view stays paused during a battle.
  - No `SKShapeNode` and no `SKEffectNode` in anything drawn every frame;
    use textured `SKSpriteNode`s only.
  - ≤ 300 nodes on screen.
  - Textures come from `.spriteatlas` folders in `Assets/Assets.xcassets`,
    loaded once per battle and released afterwards. Only the current theme's
    backdrop is in memory.
  - SwiftUI gets battle state at most when a displayed value changes, and no
    more than 4 times a second. Per-frame SwiftUI updates re-render the whole
    window: measured at 2–4 ms each.
  - Target: battle GPU time ≤ 4 ms/frame and main-thread CPU ≤ 25% of one
    core on an M4.

### Asset layout
- Scripts: `Tools/battle/`. Raw renders: `/tmp/duskara-battle/` (not committed).
- Shipped images: `Assets/Assets.xcassets/Battle*.spriteatlas/<name>.imageset`.
- Frame naming: `<unit>_<team>_<anim>_<frame:02>`, e.g. `knight_blue_walk_03`.
- Animations, with frames at 12 fps:

  | Animation | Frames | Loops? |
  |---|---|---|
  | idle | 4 | yes |
  | walk | 8 | yes |
  | attack | 6 | no; the hit lands on frame 3 |
  | death | 6 | no; holds the last frame |

---

## Phase 0: art spike

### Prompt 1: Blender knight and walk cycle

```text
Read Tools/lane-battle-prompts.md, the "Shared spec" section, first. It is binding.

Goal: prove the battle sprite pipeline with ONE character before we build the rest.

1. Make Tools/generate_settlement_models.py importable without side effects:
   move its module-level export loop into `def export_all()` and call it only
   under `if __name__ == "__main__":`. Running it as before must still export
   every model. Don't change any model or colour.
2. Create Tools/battle/generate_battle_sprites.py. Load the settlement
   generator with importlib under a different module name, so its export
   doesn't run, and reuse its COLORS, material(), soften() and box(). Add the
   teamBlue/teamRed colours locally.
3. Build a Knight from separate bevelled parts parented to pivot empties:
   torso, head with helmet and plume (team colour), two arms, two legs,
   sword, kite shield (team colour face). It faces +X (to the right). Keep it
   at 3k triangles or fewer, and print the count.
4. Keyframe an 8-frame walk loop procedurally (opposite leg/arm swing, a
   small torso bob). Render the blue team only, with the spec's camera,
   lighting, colour management, EEVEE settings and 192×192 frames with the
   foot anchor.
5. Copy the frames into Assets/Assets.xcassets/BattleKnight.spriteatlas as
   knight_blue_walk_00…07.
6. Add the input-hash skip from the spec. A second run with no changes must
   finish in under 5 seconds without rendering.

Acceptance:
- `/Applications/Blender.app/Contents/MacOS/Blender -b --python Tools/battle/generate_battle_sprites.py`
  completes; report the wall-clock time and triangle count.
- Re-running the settlement generator still exports identical models.
- Show me a contact sheet of the 8 frames (montage them into one PNG in the
  scratchpad).
```

### Prompt 2: knight sprite in the prototype

```text
Read Tools/lane-battle-prompts.md ("Shared spec") first.

Goal: see the Phase 0 knight in motion inside the real battle, to judge the art direction.

In Views/LaneBattleView.swift (LaneBattleScene), draw attacker knights with
the BattleKnight atlas's walk animation instead of the placeholder square:
- Use SKAction.animate(with:timePerFrame: 1/12), repeating forever.
- Set the anchorPoint to the spec's foot anchor.
- Load the atlas once per scene.
- Defender knights mirror the same frames (xScale = -1) for now.
- Leave everything else as it is.

Acceptance:
- Build with xcodebuild; all tests pass.
- Launch a Debug build with -battleSandbox, land two knights and take a
  screenshot of them walking.
- Don't refactor anything else; this is a throwaway spike for the review gate.
```

**Review gate:** look at the screenshot and contact sheet. Adjust proportions,
colours or the camera pitch in the spec *now*, before Phase 1 multiplies the
work.

---

## Phase 1: characters

### Prompt 3: full character set and effects in Blender

```text
Read Tools/lane-battle-prompts.md ("Shared spec") first. Build on Tools/battle/generate_battle_sprites.py from Phase 0.

Goal: every battle sprite the game needs, rendered by one cheap, cached script.

1. Characters (≤3k tris each, separate parts on pivot empties, facing +X):
   - Knight: refine from Phase 0, keeping its look.
   - Archer: hood and tabard (team colour), short bow, quiver, lighter build,
     about 1.0 BU tall.
2. Procedural animations for each character, per the spec's frame table:
   - idle: breathing bob and a weapon sway;
   - walk;
   - attack. Knight: sword wind-up, then the strike on frame 3. Archer: draw,
     then release on frame 3, then recover;
   - death: topple backwards and settle; hold the last frame.
3. Bake both teams by swapping the team material colour between renders. The
   geometry stays the same. Output 2 units × 2 teams × 24 frames.
   Defenders face LEFT, so render the red team with the character rotated
   180° about Z. Don't mirror in SpriteKit: the lighting must stay consistent.
4. Portraits: render each unit per team, waist-up, 3/4 front, same lighting,
   256×256, for the HUD cards (knight_blue_portrait, …).
5. Effects, same lighting and transparent film:
   - arrow: one frame, pointing +X, 64×16;
   - dust puff: 4 frames, 96×96;
   - hit spark: 3 frames, 64×64, warmGold;
   - blob shadow: one soft dark ellipse, 128×48 (may be drawn procedurally).
6. Outputs:
   - BattleKnight.spriteatlas, BattleArcher.spriteatlas, BattleFX.spriteatlas;
   - portraits in a plain imageset group, BattlePortraits/, not an atlas.
   Follow the spec's naming. Delete the Phase 0 frames this replaces.
7. CLI: `-- --only knight|archer|fx|portraits` renders a subset, and
   `--force` ignores the cache.

Acceptance:
- A full run takes under 3 minutes on this M4. Report the time, frame counts
  and total size of the atlases (aim for < 6 MB).
- A cached re-run takes under 5 seconds.
- Make a contact sheet per unit and team (every animation in a row) and show
  it to me.
- Check that the foot anchor stays put across walk frames: the feet's lowest
  opaque pixel row must be within ±2 px in every frame.
```

### Prompt 4: sprite animation layer in SpriteKit

```text
Read Tools/lane-battle-prompts.md ("Shared spec") first.

Goal: units in the battle scene are animated sprites driven by the battle rules, with a clean visual-only seam.

1. Rule hooks in Models/LaneBattle.swift, as small as possible and with no
   change to the balance:
   - Add `Event.struck(attackerID: Int, targetID: Int?)`, emitted whenever a
     unit lands a hit; targetID is nil for gate hits.
   - Change `.fell` to carry the unit's id and kind.
   - `.shot` stays for the tower.
   The existing tests must still pass unchanged. Add one test that a melee hit
   emits `.struck` with the right ids.
2. Add Views/Battle/BattleSprites.swift: loads the BattleKnight, BattleArcher
   and BattleFX atlases once (preload, then a completion callback), and
   exposes frame arrays per (unit, team, animation) plus the portraits.
3. Add Views/Battle/UnitSpriteNode.swift: an SKSpriteNode with a blob-shadow
   child.
   - States: walk while moving, idle while waiting at the hold line,
     attack on `.struck`, death on `.fell`.
   - The death animation plays, then the node fades out over 0.4 s and is
     removed. The rules have already removed the unit, so the scene keeps the
     node until the animation finishes.
   - Animation changes swap SKActions only when the state changes, never
     every frame.
4. Archers: on `.struck`, spawn an arrow sprite that flies in an arc (a
   parabola with ~0.6 BU apex) to the target's current position over 0.25 s,
   rotated along its path. This is visual only; damage has already happened
   in the rules.
5. Hit sparks and dust puffs come from the FX atlas, pooled: reuse nodes,
   never allocate per hit after warm-up.
6. Remove every SKShapeNode from the per-frame unit path in LaneBattleScene.

Acceptance:
- All tests pass.
- Run -battleSandbox, record a 10-second screen capture or a sequence of
  screenshots showing walking, fighting, arrows and deaths, and show it to me.
- Count the scene's nodes during a full 14-unit fight and report the peak
  (must be ≤ 300).
```

---

## Phase 2: battlefield and camera

### Prompt 5: themed battlefield backdrops in Blender

```text
Read Tools/lane-battle-prompts.md ("Shared spec") first.

Goal: one pre-rendered battlefield per WorldTheme (village, desert, mountains, forest), matching the town's look, rendered cheaply.

1. Add Tools/battle/generate_battlefields.py, reusing the settlement helpers
   and palette as in Prompt 3. For each theme, build one low-poly scene
   (≤20k tris) along +X:
   - sea and surf on the far left;
   - a 4 BU beach with two beached landing boats (reuse the existing boat
     style);
   - 24 BU of field: three dirt lanes at Y = 0, 1.6 and 3.2 BU with soft
     edges, and the ground between and around them in the theme's grass or
     sand or rock;
   - a 7 BU fortress plot on the right, left EMPTY: the fortress is
     assembled at runtime;
   - props kept to the field edges, never on lanes: trees, rocks and fences
     for village and forest; dunes and palms for desert; boulders and pines
     for mountains.
   Theme ground colours should match the town's WorldPalette for that theme
   (read Views/3D/WorldPalette.swift).
2. Render with the spec camera and light, in three layers so the game can
   parallax:
   - far: sky gradient plus distant sea and hills. Opaque, 0.4× parallax,
     rendered at half resolution.
   - ground: the field itself. Opaque, 1.0×.
   - front: a few foreground occluders (grass tufts, a rock) along the near
     edge. Transparent, 1.15×.
3. Slice each layer into tiles at most 2048 px wide, so only visible tiles
   need to stay resident. Opaque layers as HEIC (quality 0.8) or JPEG 85;
   transparent ones as PNG.
4. Output to Assets/Assets.xcassets/Battlefield<Theme>/ plus a small JSON per
   theme listing the tiles, their pixel offsets and each lane's screen-space
   Y at zoom 1. The game reads lane placement from this JSON, not from magic
   numbers.
5. Cache like Prompt 3, with `--only <theme>` and `--force`.

Acceptance:
- Each theme renders in under 2 minutes on this M4; report times and the
  on-disk size per theme (aim for < 8 MB).
- Make a stitched preview PNG of each theme's ground layer and show it to me.
```

### Prompt 6: fortress kit

```text
Read Tools/lane-battle-prompts.md ("Shared spec") first.

Goal: the fortress at the right end of the battlefield is built from the target town's real buildings, using sprites rendered from the existing settlement models.

1. In Tools/battle/generate_fortress.py (same importlib reuse as Prompt 3):
   a. Render every model in the settlement generator's MODELS from the
      battle camera as a single sprite. It becomes `settlement_<name>`;
      cropped to its alpha bounds; foot anchor at the bottom centre of the
      footprint, recorded in a JSON sidecar.
   b. Model and render a fortification kit in the same clay style
      (fortifiedClay, stone, timber, bannerRed swapped for team colour):
      - wall segment, plus a wall end cap;
      - gate in three damage states (intact, cracked, breaking) and an open
        or broken final state;
      - watchtower with a firing slit (the tower's arrows spawn from it);
      - banner pole in both team colours.
2. Output BattleFortress.spriteatlas, plus a JSON describing the anchors.
3. In Swift, add a function that builds the fortress for a Town:
   - Map the town's BuildingKinds to settlement pieces. Reuse the existing
     mapping the 3D town uses; find it in Views/3D, don't invent a new one.
   - Place up to 5 of them behind the wall, larger buildings at the back.
     The layout is deterministic from the town id.
   - The wall and gate span all three lanes; the watchtower sits behind the
     middle lane.
   - Duskara gets a taller tower and its own banner.

Acceptance:
- Render time under 90 s, cached re-run under 5 s.
- Show me screenshots of a fortress built for a starting town, a mid-game
  town and Duskara.
```

### Prompt 7: battle camera, world layering and the full scene

```text
Read Tools/lane-battle-prompts.md ("Shared spec") first. Prompts 4–6 are done.

Goal: the battle plays on the themed battlefield, with the "F1 broadcast" side camera the player can pan and zoom.

1. World: rebuild LaneBattleScene around a world node and an SKCameraNode.
   Layers:
   - far, ground and front backdrop tiles, parallaxing by the spec's factors
     against the camera's X;
   - the fortress;
   - units and FX;
   - world-space UI: gate health banner and lane highlight.
   Map a battle position (lane, 0…1) to world space using the battlefield
   JSON's lane Y values; far lanes get the spec's 0.9 scale. Nearer units
   always draw on top: set zPosition from world Y once per frame, not by
   re-sorting children.
2. Camera controls:
   - Pan left/right only, clamped to the beach's left edge and the
     fortress's right edge. Use the left/right arrow keys (smooth,
     accelerating to ~900 pt/s), A/D are NOT used (A selects archers).
     Two-finger horizontal scroll or the mouse wheel also pans.
   - Click-drag pans. A left click that moves less than 6 pt is still a
     "land unit" click; dragging further pans and never lands a unit.
   - Zoom with trackpad pinch (magnify), ⌘-scroll, and the +/− keys. Range:
     from "whole field fits the width" up to 2.0×, about the cursor (or the
     view centre for keys).
   - Keep the vertical framing fixed. The camera never tilts or rotates; it
     only moves along X and scales.
   - Default view: zoomed so the beach and the first third of the field fill
     the screen. After landing units, the camera may ease toward the frontmost
     attacker if the player hasn't panned in the last 3 s. Respect Reduce
     Motion: no easing, just stay put.
   - Key handling: SpriteView doesn't reliably become first responder, so
     route keys from SwiftUI with .onKeyPress on the battle view (or a small
     NSViewRepresentable key catcher) to scene methods.
3. Landing: clicking anywhere in a lane's band on the beach side of the
   field, or pressing 1/2/3, lands the selected unit in that lane. Hovering
   highlights the lane band (a sprite, not a shape).
4. The fortress gate shows the damage state matching health (>66%, >33%,
   >0, broken). The tower's `.shot` spawns an arrow from the tower's slit.
   When the gate falls: brief camera shake (skipped under Reduce Motion) and
   a dust burst.
5. Pick the theme from the target town's world theme (WorldTheme.current if
   towns don't carry one).
6. Delete everything the prototype drew with SKShapeNode. Keep the scene's
   rules wiring exactly as it is (fixed LaneBattle.tick stepping and event
   draining).

Acceptance:
- All tests pass.
- Run -battleSandbox and show me:
  - screenshots at minimum zoom, default zoom and maximum zoom;
  - a pan to the fortress using arrow keys and using drag;
  - a full battle to the end.
- Profile 30 s of battle with xctrace (no sudo; delete any
  instruments*.ktrace it leaves behind). Report average GPU ms per frame,
  main-thread CPU %, and frame rate. They must meet the spec's runtime
  targets.
```

---

## Phase 3: battle UI in the game's design language

### Prompt 8: HUD, briefing and battle report

```text
Read Tools/lane-battle-prompts.md ("Shared spec") first. Phase 2 is done.

Goal: the battle's interface looks and feels like the rest of Quest for Duskara.

1. HUD (SwiftUI over the SpriteView), using DuskaraTheme fonts and colours,
   DuskaraButtonStyle, and hudFill or glassStroke panels like
   Views/Components/HUDViews.swift:
   - Top-left panel: "Assault on <town>", with your power vs. the garrison
     and the fortification under it.
   - Top-centre: a timer pill (mm:ss, turning accent-red under 15 s).
   - Bottom-centre: unit cards, one per unit kind. Each has the portrait
     (BattlePortraits), the count left, the command cost as pips, a selected
     state, and is dimmed when unaffordable or empty. The A/K shortcuts are
     shown on the card.
   - Above the cards: the command meter as 10 warmGold pips that fill.
   - Bottom-right: Withdraw (Esc), with a confirmation popover the first
     time in a session.
   - A small "1 2 3 lanes · ←/→ pan · pinch zoom" hint that fades after the
     first landing.
   Update rule (from the spec): the scene pushes a small Equatable HUD state
   (whole command points, seconds left, unit counts, affordability) only
   when it changes, throttled to ≤ 4 Hz. Nothing in SwiftUI observes per-frame
   values.
2. Briefing: tapping Attack on the world map no longer jumps straight in.
   Show a briefing panel instead:
   - your army by unit with portraits, against the garrison;
   - the gate strength and tower strength;
   - a plain-language odds line: "Outmatched" / "Even fight" / "Favoured" /
     "Overwhelming", from your power ÷ the displayed defense with
     thresholds 0.85 / 1.1 / 1.5. These come from the simulated balance:
     below 0.85× even good play loses; from 1.1× even sloppy play wins;
     from 1.5× losses are light;
   - buttons: Attack, Cancel. Auto-resolve is not part of this phase.
   It's a SwiftUI view in the same style as BuildingDetailsSheetView. The
   game clock pauses while it's open.
3. Battle report: replace the end-of-battle toast with a report panel:
   - outcome banner (Captured / Repelled / Withdrew);
   - losses vs. survivors per unit kind, both sides;
   - plunder on capture;
   - time taken;
   - Continue.
   GameViewModel.finishAssault keeps applying the result; the panel only
   shows it. Keep the news-feed entries.
4. Sound: add GameSound cases for land, hit, gate-break and victory/defeat,
   using system sounds for now. Respect the existing mute setting. Throttle
   hit sounds to at most 6 per second.
5. Accessibility:
   - VoiceOver labels for every control, plus a spoken summary of the HUD
     state when it changes (lanes and counts).
   - Every action reachable by keyboard.
   - Reduce Motion is respected everywhere.
   - Contrast holds in both appearances (the theme's colours are explicit;
     keep it that way).

Acceptance:
- All tests pass. Add tests for the odds-label thresholds and for the HUD
  state only changing when values change.
- Show me screenshots of: the briefing, the HUD mid-battle, a capture
  report and a repelled report.
- Profile as in Prompt 7: the HUD must not add more than 0.5 ms per frame or
  any SwiftUI rendering while values are unchanged.
```

### Prompt 9: end-of-phase review

```text
Read Tools/lane-battle-prompts.md ("Shared spec") first.

Review everything changed for Phases 0–3 on this branch against the spec:
- Correctness: the rules are unchanged except the event hooks; tests pass;
  no gameplay value is hard-coded in views.
- Budgets: Blender render times, asset sizes, node counts, fps/GPU/CPU,
  SwiftUI update rate. Re-measure; don't trust earlier reports.
- Leftovers: any SKShapeNode or SKEffectNode left in per-frame paths, dead
  prototype code, debug prints, and uncached Blender work.
- Consistency: palette, lighting, camera angle and the foot anchor are the
  same across units, fortress and backdrops (put screenshots side by side).
Fix what's clearly wrong, list anything that needs my decision, and finish
with a short report of the measurements.
```
