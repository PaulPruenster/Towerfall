# AGENTS

This repository is a small Godot 4.6.1 local multiplayer arena game inspired by TowerFall.

## Project Basics

- Engine version: `Godot 4.6.1`
- Primary launch command:
  `flatpak run org.godotengine.Godot`
- The main scene is configured in [project.godot](/home/matthiase/Github/Towerfall/project.godot).
- Reusable game scenes live under `scenes/actors/`, `scenes/gameplay/`, `scenes/effects/`, and `scenes/audio/`.
- Level scenes live under `scenes/levels/`.
- Gameplay logic lives under `scripts/actors/`, `scripts/gameplay/`, and `scripts/systems/`.

## Folder Guide

- `scenes/actors/`: player and arrow scenes
- `scenes/gameplay/`: chests, gates, jump pads, hazards, platforms
- `scenes/effects/`: one-shot effects
- `scenes/audio/`: reusable audio scenes
- `scenes/levels/`: playable arenas
- `scenes/ui/`: menu scenes
- `scripts/actors/`: actor behavior
- `scripts/gameplay/`: gameplay object and level-flow behavior
- `scripts/systems/`: shared helpers such as procedural SFX
- `scripts/ui/`: menu logic

## What Future Agents Should Know

- In this environment, Godot is available through Flatpak, not through a plain `godot` binary.
- Headless Godot runs may require escalated execution outside the default sandbox.
- A fast project-load validation command is:
  `flatpak run org.godotengine.Godot --headless --path /home/matthiase/Github/Towerfall --quit-after 2`

## Gameplay Notes

- Players use [player.gd](/home/matthiase/Github/Towerfall/scripts/actors/player.gd).
- Arrows use [arrow.gd](/home/matthiase/Github/Towerfall/scripts/actors/arrow.gd).
- Recoverable stuck arrows use [arrow_dummy.gd](/home/matthiase/Github/Towerfall/scripts/actors/arrow_dummy.gd).
- Chests use [chest.gd](/home/matthiase/Github/Towerfall/scripts/gameplay/chest.gd).
- Level reset and winner text use [world.gd](/home/matthiase/Github/Towerfall/scripts/gameplay/world.gd).

Current ammo behavior:

- `arrow_count` is normal ammo.
- `special_arrow_count` is standalone special ammo, not just a modifier.
- A player may fire special arrows even when normal arrows are `0`.
- The main on-player arrow counter currently shows total available shots.
- Recovered wall arrows add back normal ammo.

Current special arrow types:

- `Bomb`
- `Bounce`

Current feel and interaction systems:

- Players have coyote time, jump buffering, short-hop release, a visible aim preview, dash charge UI, and temporary buffs.
- Levels currently include spikes, a moving platform, and a timed pressure switch that can unlock gates.
- Moment-to-moment feedback now includes screen shake, hit-stop, hit flash, knockback, and lightweight procedural gameplay SFX from [game_sfx.gd](/home/matthiase/Github/Towerfall/scripts/systems/game_sfx.gd).

## When Changing Gameplay Code

If you touch the combat or pickup loop, inspect these files together:

- [player.gd](/home/matthiase/Github/Towerfall/scripts/actors/player.gd)
- [arrow.gd](/home/matthiase/Github/Towerfall/scripts/actors/arrow.gd)
- [arrow_dummy.gd](/home/matthiase/Github/Towerfall/scripts/actors/arrow_dummy.gd)
- [chest.gd](/home/matthiase/Github/Towerfall/scripts/gameplay/chest.gd)
- [player.tscn](/home/matthiase/Github/Towerfall/scenes/actors/player.tscn)
- [chest.tscn](/home/matthiase/Github/Towerfall/scenes/gameplay/chest.tscn)

Common failure mode:

- UI counters say a player has ammo, but `can_shoot()` logic blocks firing because the actual ammo model is inconsistent.

## Preferred Validation Workflow

1. Run the headless load check from `TESTING.md`.
2. If the change is logic-heavy, add a short temporary smoke test script that extends `SceneTree`, run it with:
   `flatpak run org.godotengine.Godot --headless --path /home/matthiase/Github/Towerfall --script res://your_test.gd`
3. Delete temporary test scripts after validation unless the repository intentionally keeps them.
4. Ask for or perform a manual gameplay check when the change affects game feel, UI placement, or input timing.

## Information An Agent May Need From The User

- Confirmation that Flatpak Godot runs are allowed.
- Exact reproduction steps for gameplay bugs.
- Whether manual in-editor playtesting is available.
- Expected behavior when changing pickups, ammo rules, or match flow.
