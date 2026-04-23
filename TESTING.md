# TESTING

This project is tested with Godot `4.6.1` through Flatpak.

## Requirements

- Godot command:
  `flatpak run org.godotengine.Godot`
- Project path:
  `/home/matthiase/Github/Towerfall`

In restricted environments, Flatpak runs may require escalated permissions.

## Fast Load Check

Use this to confirm the project loads and current scripts/scenes parse:

```bash
flatpak run org.godotengine.Godot --headless --path /home/matthiase/Github/Towerfall --quit-after 2
```

This check should now complete without parser warnings.

## Logic Smoke Tests

For targeted logic validation:

1. Create a temporary script in the repo root that extends `SceneTree`.
2. Instantiate the relevant scene or script objects.
3. Use assertions with clear `PASS` / `FAIL` output.
4. Run it with:

```bash
flatpak run org.godotengine.Godot --headless --path /home/matthiase/Github/Towerfall --script res://your_test.gd
```

5. Delete the temporary test script after the run unless it is meant to stay in the repository.

## Permanent AI Smoke Test

The repository now includes a permanent AI smoke test that covers:

- impossible-gap stopping
- simple-gap jumping
- chest priority when empty
- switch priority
- wall-jump route selection
- pad steering after launch routing
- stomp choice in a vertical duel
- spike avoidance

Run it with:

```bash
flatpak run org.godotengine.Godot --headless --path /home/matthiase/Github/Towerfall --script res://tests/ai_smoke_test.gd
```

## Manual Gameplay Checklist

After gameplay changes, verify the following in-editor:

- The project boots into the menu without parser errors.
- Each level can be entered from the menu.
- Both players can move, jump, aim, shoot, and dash.
- Winner text and restart flow still work after death.
- Press `F8` in an arena to toggle the AI debug overlay and confirm goal, route, probe, shot, and stomp reasons are updating.

### Ammo And Pickup Checklist

- A player can shoot with normal arrows.
- A player can shoot with only special arrows when normal arrows are `0`.
- Recovering a stuck arrow increases normal ammo and allows shooting again.
- Arrow refill rewards never reduce a player who already has more than `5` arrows.
- The on-player ammo label matches actual firing behavior.

### Special Arrow Checklist

- `Bomb` arrows explode on impact.
- `Bomb` arrows damage nearby opponents.
- `Bomb` arrows do not damage the firing player unless that behavior is intentionally changed later.
- `Bounce` arrows ricochet off walls.
- `Bounce` arrows eventually expire after their allowed ricochets are spent.
- Chest labels show the reward type clearly.

### Feel And Interaction Checklist

- Coyote time and jump buffering make late jumps still register cleanly.
- Releasing jump early produces a shorter hop.
- Dash cooldown feedback becomes visible when dash charges return.
- Hit-stop and screen shake trigger on strong hits and kills without getting stuck.
- Jump pads launch players consistently from above, ignore upward side-entry noise, and recover after cooldown.
- Level 2 pressure switch enables both gates for a short window, then disables them again.
- Spikes, moving platforms, and gate interactions all load and behave without scene errors.

## Files To Recheck After Combat Changes

- [player.gd](/home/matthiase/Github/Towerfall/scripts/actors/player.gd)
- [arrow.gd](/home/matthiase/Github/Towerfall/scripts/actors/arrow.gd)
- [arrow_dummy.gd](/home/matthiase/Github/Towerfall/scripts/actors/arrow_dummy.gd)
- [chest.gd](/home/matthiase/Github/Towerfall/scripts/gameplay/chest.gd)
- [player.tscn](/home/matthiase/Github/Towerfall/scenes/actors/player.tscn)
- [chest.tscn](/home/matthiase/Github/Towerfall/scenes/gameplay/chest.tscn)
- [world.gd](/home/matthiase/Github/Towerfall/scripts/gameplay/world.gd)
- [game_sfx.gd](/home/matthiase/Github/Towerfall/scripts/systems/game_sfx.gd)
- [pressure_switch.gd](/home/matthiase/Github/Towerfall/scripts/gameplay/pressure_switch.gd)
- [scenes/level_2.tscn](/home/matthiase/Github/Towerfall/scenes/levels/level_2.tscn)

## Bug Report Template

When reporting a bug, include:

- Scene or level
- Which player
- Inputs used
- Expected behavior
- Actual behavior
- Any Godot console output
- Whether the issue appears only in-editor, only headless, or both
