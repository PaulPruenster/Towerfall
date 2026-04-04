# Visual Asset Checklist

The runtime loaders in [player.gd](/home/matthiase/Github/Towerfall/scripts/actors/player.gd) and [arrow.gd](/home/matthiase/Github/Towerfall/scripts/actors/arrow.gd) expect these files.

## Player

Directory: `res://assets/generated/player/`

- `player_idle_00.png` to `player_idle_05.png` - `48x48`, 6 frames
- `player_run_00.png` to `player_run_07.png` - `48x48`, 8 frames
- `player_jump_00.png` to `player_jump_01.png` - `48x48`, 2 frames
- `player_fall_00.png` to `player_fall_01.png` - `48x48`, 2 frames
- `player_hurt_00.png` to `player_hurt_01.png` - `48x48`, 2 frames
- `player_death_00.png` to `player_death_04.png` - `48x48`, 5 frames
- `player_aim_side_00.png` to `player_aim_side_03.png` - `48x48`, 4 frames
- `player_aim_up_diag_00.png` to `player_aim_up_diag_03.png` - `48x48`, 4 frames
- `player_aim_up_00.png` to `player_aim_up_03.png` - `48x48`, 4 frames
- `player_aim_down_diag_00.png` to `player_aim_down_diag_03.png` - `48x48`, 4 frames
- `player_aim_down_00.png` to `player_aim_down_03.png` - `48x48`, 4 frames
- `player_shoot_side_00.png` to `player_shoot_side_02.png` - `48x48`, 3 frames
- `player_shoot_up_diag_00.png` to `player_shoot_up_diag_02.png` - `48x48`, 3 frames
- `player_shoot_up_00.png` to `player_shoot_up_02.png` - `48x48`, 3 frames
- `player_shoot_down_diag_00.png` to `player_shoot_down_diag_02.png` - `48x48`, 3 frames
- `player_shoot_down_00.png` to `player_shoot_down_02.png` - `48x48`, 3 frames

## Arrows

Directory: `res://assets/generated/arrows/`

- Keep existing fallback statics:
  - `arrow_normal.png`
  - `arrow_bomb.png`
  - `arrow_bounce.png`
  - `arrow_pickup.png`
- `arrow_normal_flight_00.png` to `arrow_normal_flight_03.png` - recommended `12x24`, 4 frames
- `arrow_bomb_flight_00.png` to `arrow_bomb_flight_03.png` - recommended `12x24`, 4 frames
- `arrow_bounce_flight_00.png` to `arrow_bounce_flight_03.png` - recommended `12x24`, 4 frames
- `arrow_hit_wall_00.png` to `arrow_hit_wall_01.png` - recommended `16x24`, 2 frames
- `arrow_hit_enemy_00.png` to `arrow_hit_enemy_02.png` - recommended `16x24`, 3 frames

## Effects

Directory: `res://assets/generated/effects/`

- `land_dust_00.png` to `land_dust_03.png` - `24x16`, 4 frames
- `impact_flash_00.png` to `impact_flash_02.png` - `24x24`, 3 frames
- `death_burst_00.png` to `death_burst_04.png` - `32x32`, 5 frames, optional
