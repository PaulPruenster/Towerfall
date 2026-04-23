# AI Evaluation Levels

This directory holds frozen scene files used exclusively by the Tier 4 arena ladder
in `plan/ai_evaluation_pipeline.md`. The rules below apply permanently to every file
in this directory.

---

## 1. Separation Rule

**Evaluation levels and game levels are different files and must never be the same files.**

| Location | Purpose | Edit policy |
|---|---|---|
| `tests/ai_evaluation_levels/` | AI battery targets | Frozen after the freeze date |
| `scenes/levels/` | Authored game content | Edited freely |

Tier 4 of the battery targets the files in `tests/ai_evaluation_levels/`, not the
files in `scenes/levels/`. Once an evaluation level is frozen, it is treated as an
immutable artifact. A game-level redesign has no effect on historical batch scores.

The `scenes/levels/` files remain available as an optional authored-level smoke column
(see Section 6).

---

## 2. One Level Per Mechanic Cluster

Each evaluation level covers exactly the mechanic set required by one Tier 4 cluster.
Use these canonical names:

| File | Mechanic cluster |
|---|---|
| `eval_level_chest_gate.tscn` | chest contest, gate usage, jump-pad routing |
| `eval_level_switch_wrap.tscn` | switch-gate route choice, spikes, moving-platform usage, wrap routing |
| `eval_level_platform_spike.tscn` | wrap routing, spikes, moving-platform usage, vertical space control |

These names correspond to the required-mechanics columns already frozen in
`plan/ai_evaluation_pipeline.md` under **Tier 4 - Authored Arena Ladder**.

Do not bundle more than one cluster into one level. A level that tests everything
produces scores that are harder to diagnose when a metric regresses.

---

## 3. Freeze Protocol

When a level is added to the battery:

1. Record a freeze date in the **Frozen Level Registry** table below.
2. Do not modify the `.tscn` file after that date under any circumstances.
3. If the mechanic the level tests changes in the engine (e.g. jump-pad physics
   retuned, wrap boundary shifted), create a new versioned file:
   `eval_level_chest_gate_v2.tscn`.
4. Rebaseline all affected batch scores against the new version before retiring the
   old file.
5. Keep the old versioned file in this directory until all historical reports that
   reference it have been archived. Then move it to `tests/ai_evaluation_levels/retired/`.

**Never silently edit a frozen level.** A silent edit breaks the continuity of every
batch score ever recorded against that file.

### Frozen Level Registry

| File | Freeze date | Mechanic cluster | Engine version frozen against | Notes |
|---|---|---|---|---|
| *(none yet)* | | | | |

---

## 4. Minimal Design

Evaluation levels are not playable game content.

- Use the simplest geometry that reliably exercises the target mechanic.
- No decorative nodes (`TextureRect`, `Sprite2D`, background art, particle emitters).
- No `SongPlayer` child node.
- No `HUD` or `LevelOverlay` child node.
- Static collision bodies and `Marker2D` spawn points are sufficient.
- Use `StaticBody2D` + `CollisionShape2D` with primitive shapes only.
- Do not reference tile sets or tile map layers; they require asset files that may
  drift independently of this directory.

The duel slice scenes in `scenes/levels/` (`duel_open.tscn`, `duel_platform.tscn`,
`duel_wrap.tscn`) and their shared script `scripts/gameplay/duel_world.gd` are the
established pattern to follow. Evaluation levels use the same `duel_world.gd` script.

---

## 5. Headless Safe

Every evaluation level must pass the existing headless smoke test with zero warnings:

```sh
flatpak run org.godotengine.Godot --headless \
  --path /path/to/Towerfall \
  --quit-after 2
```

Rules:

- Do not load textures at node instantiation time. Where a visual aid is unavoidable
  use the placeholder pattern already established in `scripts/actors/arrow_dummy.gd`
  and `scripts/gameplay/jumping_pad.gd`: define a `@export` texture property, leave
  it `null` by default, and guard every access with a null check.
- Do not use `preload()` on image files inside any script attached to an evaluation
  level node.
- Do not add audio nodes. `AudioStreamPlayer` and `AudioStreamPlayer2D` nodes in
  headless mode produce warnings when streams are unset.
- The `duel_world.gd` script already suppresses `trigger_screenshake` and
  `trigger_hit_stop` as no-ops, so player and arrow scripts will not crash when
  they call those methods on their world parent.

---

## 6. Update Rule for ai_evaluation_pipeline.md

When an evaluation level is frozen and added to the battery, update
`plan/ai_evaluation_pipeline.md` as follows:

1. In the **Tier 4 - Authored Arena Ladder** scope table, replace the
   `scenes/levels/` path with the `tests/ai_evaluation_levels/` path.
2. Add a new column labeled **authored level smoke** that retains the original
   `scenes/levels/` path. This column is optional; its purpose is to catch
   regressions introduced by a game-level redesign before the level ships to players.
3. Update the **Frozen Battery Profiles** section to reference the new path in both
   quick and full battery definitions.
4. Record the freeze date in the **Frozen Level Registry** table above.

Example diff to the Tier 4 table (do not apply until the first level is frozen):

```
Before:
  - `scenes/levels/level_1.tscn`  ← chest contest, gate usage, jump-pad routing

After:
  Evaluation level (battery):  tests/ai_evaluation_levels/eval_level_chest_gate.tscn
  Authored level smoke (opt):  scenes/levels/level_1.tscn
```
