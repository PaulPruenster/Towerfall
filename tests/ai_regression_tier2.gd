extends SceneTree

# Tier 2 - Execution Drills
# Run headless:
#   flatpak run org.godotengine.Godot --headless --path /home/matthiase/Github/Towerfall \
#     --script res://tests/ai_regression_tier2.gd

const PLAYER_SCENE := preload("res://scenes/actors/player.tscn")
const SPIKES_SCENE := preload("res://scenes/gameplay/spikes.tscn")
const JUMP_PAD_SCENE := preload("res://scenes/gameplay/jumping_pad.tscn")


class DummyChest:
	extends Node2D
	var lootable: bool = true
	var reward_type: int = 0

	func is_lootable() -> bool:
		return lootable

	func get_reward_type() -> int:
		return reward_type


class DummyGate:
	extends Node2D
	var gate_enabled: bool = false
	var target_gate: Node2D

	func is_gate_enabled() -> bool:
		return gate_enabled

	func set_gate_enabled(is_enabled: bool) -> void:
		gate_enabled = is_enabled

	func get_target_gate() -> Node2D:
		return target_gate


class DummySwitch:
	extends Node2D
	var controlled_gates: Array = []

	func get_controlled_gates() -> Array:
		return controlled_gates

	func controls_disabled_gate() -> bool:
		for gate in controlled_gates:
			if gate != null and gate.has_method("is_gate_enabled") and not bool(gate.call("is_gate_enabled")):
				return true
		return false


var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_t2_pad_to_chest()
	await _test_t2_switch_gate_sequence()
	await _test_t2_wall_blocks_shot_commit()
	await _test_t2_loaded_ai_drops_chest_priority()
	await _test_t2_recover_ammo_disengage()
	await _test_t2_horizontal_wrap_pursuit()
	await _test_t2_vertical_wrap_drop()
	await _test_t2_platform_boarding()
	await _test_t2_avoid_spikes_reach_chest()
	await _test_t2_route_entry_stays_on_reachable_floor()
	await _test_t2_fight_route_exit_stays_on_target_floor()
	await _test_t2_fight_jumps_over_pad_obstacle()
	await _test_t2_fight_drops_to_lower_target_without_route()
	await _test_t2_drop_to_lower_chest_without_route()
	await _test_t2_wrap_fall_to_upper_chest_without_route()
	await _test_t2_stomp_window_conversion()
	await _test_t2_evade_stomp_threat()

	if _failures.is_empty():
		print("ai tier 2 regression passed")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


# T2.01 - Take a pad to a chest
# With a PAD route step injected and the player on the ground at the board point,
# the AI must output approach steering toward the pad helper and not block movement.
# Goal-selection: with empty quiver and a nearby chest the AI must pick CHEST.
func _test_t2_pad_to_chest() -> void:
	var arena := _make_arena()
	_spawn_ground(arena, Vector2(180.0, 290.0), Vector2(360.0, 18.0))
	var ai_player := _spawn_player(arena, Vector2(180.0, 250.0))
	var target_player := _spawn_player(arena, Vector2(420.0, 150.0))
	var chest := DummyChest.new()
	chest.position = Vector2(420.0, 120.0)
	arena.add_child(chest)

	var routes := Node2D.new()
	routes.name = "AIRoutes"
	arena.add_child(routes)
	var helper := Marker2D.new()
	helper.position = Vector2(260.0, 268.0)
	routes.add_child(helper)
	var start_point := _spawn_route_point(routes, "PadBase", Vector2(180.0, 268.0))
	var landing_point := _spawn_route_point(routes, "PadLanding", Vector2(420.0, 120.0))
	var pad_link := _spawn_route_link(start_point, landing_point, AIRouteLink.TraversalType.PAD, 28.0, helper, 0)

	ai_player.arrow_count = 0
	ai_player.special_arrow_count = 0
	var ai := _get_ai(ai_player)
	ai.enabled = true
	await _settle_player_on_floor(ai_player)
	await _settle_player_on_floor(target_player)

	# Verify goal selection: empty AI next to a chest must pick CHEST
	ai.get_control_state(1.0 / 60.0)
	_assert(ai.goal_type == AIController.GoalType.CHEST, "T2.01: Expected CHEST goal with empty quiver and nearby chest")

	# Inject route step at board point and verify PAD approach steering
	ai_player.global_position = start_point.global_position + Vector2(0.0, -18.0)
	ai.current_route_step = {
		"focus_position": landing_point.global_position,
		"source_point": start_point,
		"target_point": landing_point,
		"link": pad_link,
		"traversal_type": AIRouteLink.TraversalType.PAD,
		"activation_distance": 28.0,
		"helper_node": helper,
	}
	var floor_control := ai._build_route_link_control_state()
	_assert(
		_get_control_direction(floor_control).x > 0.0,
		"T2.01: Expected PAD approach steering rightward toward the helper lane"
	)
	await _cleanup_arena(arena)


# T2.02 - Press a switch and then use the opened gate
# Phase 1: AI selects SWITCH goal when gate is disabled and switch is nearby.
# Phase 2: After gate opens (switch pressed), AI transitions away from SWITCH goal.
func _test_t2_switch_gate_sequence() -> void:
	var arena := _make_arena()
	_spawn_ground(arena, Vector2(320.0, 290.0), Vector2(640.0, 18.0))
	var ai_player := _spawn_player(arena, Vector2(120.0, 250.0))
	var target_player := _spawn_player(arena, Vector2(540.0, 250.0))

	var exit_gate := DummyGate.new()
	exit_gate.position = Vector2(490.0, 250.0)
	arena.add_child(exit_gate)
	var entry_gate := DummyGate.new()
	entry_gate.position = Vector2(200.0, 250.0)
	entry_gate.gate_enabled = false
	entry_gate.target_gate = exit_gate
	arena.add_child(entry_gate)
	var switch_node := DummySwitch.new()
	switch_node.position = Vector2(180.0, 250.0)
	switch_node.controlled_gates = [entry_gate]
	arena.add_child(switch_node)

	var ai := _get_ai(ai_player)
	ai.enabled = true
	await _settle_player_on_floor(ai_player)
	await _settle_player_on_floor(target_player)

	# Phase 1: AI should choose SWITCH goal while gate is still disabled
	ai.get_control_state(1.0 / 60.0)
	_assert(
		ai.goal_type == AIController.GoalType.SWITCH,
		"T2.02: Expected SWITCH goal when gate is disabled and switch is nearby"
	)

	# Phase 2: Simulate switch pressed - gate opens, switch no longer controls a disabled gate
	entry_gate.gate_enabled = true
	switch_node.controlled_gates = []
	ai.cached_switches.clear()
	ai.goal_stick_left = 0.0

	ai.get_control_state(1.0 / 60.0)
	_assert(
		ai.goal_type != AIController.GoalType.SWITCH,
		"T2.02: Expected goal transition away from SWITCH after gate is opened"
	)
	await _cleanup_arena(arena)


# T2.03 - Recover ammo and disengage
# With no ammo and one health at close range the AI must choose RECOVER goal
# and enter RETREAT state immediately.
func _test_t2_wall_blocks_shot_commit() -> void:
	var arena := _make_arena()
	_spawn_ground(arena, Vector2(320.0, 290.0), Vector2(760.0, 18.0))
	_spawn_ground(arena, Vector2(320.0, 170.0), Vector2(28.0, 220.0))
	var ai_player := _spawn_player(arena, Vector2(160.0, 250.0))
	var target_player := _spawn_player(arena, Vector2(520.0, 250.0))
	var ai := _get_ai(ai_player)
	ai.enabled = true
	await _settle_player_on_floor(ai_player)
	await _settle_player_on_floor(target_player)

	ai.target = target_player
	var aim_result := ai._get_best_aim_result()
	var shot_decision := ai._get_shot_decision(aim_result)
	_assert(
		not bool(shot_decision.get("allowed", false)),
		"T2.03: Expected shot commitment to fail when a wall blocks the arrow path"
	)
	_assert(
		str(shot_decision.get("reason", "")).contains("blocked"),
		"T2.03: Expected blocked-wall reason when a wall sits between AI and target"
	)
	await _cleanup_arena(arena)


func _test_t2_loaded_ai_drops_chest_priority() -> void:
	var arena := _make_arena()
	_spawn_ground(arena, Vector2(420.0, 290.0), Vector2(920.0, 18.0))
	var ai_player := _spawn_player(arena, Vector2(180.0, 250.0))
	var target_player := _spawn_player(arena, Vector2(700.0, 250.0))
	var chest := DummyChest.new()
	chest.position = Vector2(250.0, 250.0)
	arena.add_child(chest)

	ai_player.arrow_count = 1
	ai_player.special_arrow_count = 0
	ai_player.triple_shot_charges = 2
	ai_player.rapid_fire_time_left = 5.0
	ai_player.extra_dash_time_left = 5.0
	ai_player.speed_boost_time_left = 5.0
	ai_player.armor_hits = 1
	var ai := _get_ai(ai_player)
	ai.enabled = true
	await _settle_player_on_floor(ai_player)
	await _settle_player_on_floor(target_player)

	ai.get_control_state(1.0 / 60.0)
	_assert(
		ai.goal_type == AIController.GoalType.FIGHT,
		"T2.04: Expected loaded AI to deprioritize a nearby chest and re-engage the enemy"
	)
	await _cleanup_arena(arena)


# T2.05 - Recover ammo and disengage
# With no ammo and one health at close range the AI must choose RECOVER goal
# and enter RETREAT state immediately.
func _test_t2_recover_ammo_disengage() -> void:
	var arena := _make_arena()
	_spawn_ground(arena, Vector2(320.0, 290.0), Vector2(640.0, 18.0))
	var ai_player := _spawn_player(arena, Vector2(220.0, 250.0))
	var target_player := _spawn_player(arena, Vector2(270.0, 250.0))
	ai_player.arrow_count = 0
	ai_player.special_arrow_count = 0
	ai_player.health = 1
	var ai := _get_ai(ai_player)
	ai.enabled = true
	await _settle_player_on_floor(ai_player)
	await _settle_player_on_floor(target_player)

	ai.get_control_state(1.0 / 60.0)
	_assert(
		ai.goal_type == AIController.GoalType.RECOVER,
		"T2.03: Expected RECOVER goal when health=1, ammo=0, and enemy is at close range"
	)
	_assert(
		ai.state == AIController.AIState.RETREAT,
		"T2.03: Expected RETREAT state when actively recovering"
	)
	await _cleanup_arena(arena)


# T2.06 - Use horizontal wrap to shorten pursuit
# Near the right viewport edge with a blocked non-hazard gap ahead and a target
# accessible via wrap: the AI must commit to the wrap route and output a rightward
# movement direction instead of stopping.
func _test_t2_horizontal_wrap_pursuit() -> void:
	var arena := _make_arena()
	_spawn_ground(arena, Vector2(320.0, 290.0), Vector2(640.0, 18.0))
	var ai_player := _spawn_player(arena, Vector2(320.0, 250.0))
	var target_player := _spawn_player(arena, Vector2(200.0, 250.0))
	var ai := _get_ai(ai_player)
	ai.enabled = true
	await _settle_player_on_floor(ai_player)
	await _settle_player_on_floor(target_player)

	var viewport_size := ai_player.get_viewport_rect().size
	if viewport_size.x <= 0.0:
		await _cleanup_arena(arena)
		return

	# Place player 50 px from the right wrap edge
	# Target at 35% viewport width gives a wrapped delta.x > 25% of viewport (shorter path)
	ai_player.global_position.x = viewport_size.x - 50.0
	target_player.global_position.x = viewport_size.x * 0.35
	ai.target = target_player
	ai.goal_type = AIController.GoalType.FIGHT
	ai.state = AIController.AIState.APPROACH

	var path_assessment := {"blocked": true, "hazard": false, "jumpable": false}
	_assert(
		ai._can_commit_to_wrap_route(1, path_assessment),
		"T2.04: Expected AI to commit to horizontal wrap route when direct path is blocked and wrap is shorter"
	)

	# Full movement plan must continue right, not stop
	var movement := ai._apply_movement_safety(Vector2.RIGHT, false)
	_assert(
		_get_control_direction(movement).x > 0.0,
		"T2.06: Expected movement direction to remain rightward when committing to horizontal wrap"
	)
	await _cleanup_arena(arena)


# T2.07 - Use vertical wrap drop when it is the intended route
# With the player in the lower screen region and the target clearly above,
# the AI must recognise the vertical wrap drop as a viable route option.
func _test_t2_vertical_wrap_drop() -> void:
	var arena := _make_arena()
	_spawn_ground(arena, Vector2(320.0, 290.0), Vector2(640.0, 18.0))
	var ai_player := _spawn_player(arena, Vector2(320.0, 250.0))
	var target_player := _spawn_player(arena, Vector2(320.0, 80.0))
	var ai := _get_ai(ai_player)
	ai.enabled = true
	await _settle_player_on_floor(ai_player)
	await _settle_frames(4)

	var viewport_size := ai_player.get_viewport_rect().size
	if viewport_size.y <= 0.0:
		await _cleanup_arena(arena)
		return

	# Place player in lower 45% of screen (y > 55% of viewport height)
	ai_player.global_position.y = viewport_size.y * 0.62
	# Target near top: direct delta.y is negative and > 22% of viewport height
	target_player.global_position.y = viewport_size.y * 0.18
	ai.target = target_player
	ai.goal_type = AIController.GoalType.FIGHT
	ai.state = AIController.AIState.APPROACH

	# Vertical wrap is not gated on a blocked path; test detection logic directly
	var path_assessment := {"blocked": true, "hazard": false, "jumpable": false}
	_assert(
		ai._can_commit_to_wrap_route(1, path_assessment),
		"T2.07: Expected AI to recognise vertical wrap drop when player is near screen bottom and target is above"
	)
	await _cleanup_arena(arena)


# T2.08 - Board, ride, and leave a moving platform
# With a JUMP route step injected at the platform board point,
# the AI must output jump input and a movement direction toward the platform.
func _test_t2_platform_boarding() -> void:
	var arena := _make_arena()
	_spawn_ground(arena, Vector2(200.0, 290.0), Vector2(240.0, 18.0))
	var ai_player := _spawn_player(arena, Vector2(200.0, 250.0))
	var target_player := _spawn_player(arena, Vector2(480.0, 150.0))
	var chest := DummyChest.new()
	chest.position = Vector2(480.0, 120.0)
	arena.add_child(chest)

	var routes := Node2D.new()
	routes.name = "AIRoutes"
	arena.add_child(routes)
	var board_point := _spawn_route_point(routes, "PlatformBoard", Vector2(240.0, 268.0))
	var ride_point := _spawn_route_point(routes, "PlatformRide", Vector2(480.0, 148.0))
	var jump_link := _spawn_route_link(board_point, ride_point, AIRouteLink.TraversalType.JUMP, 28.0, null, 0)

	ai_player.arrow_count = 0
	ai_player.special_arrow_count = 0
	var ai := _get_ai(ai_player)
	ai.enabled = true
	await _settle_player_on_floor(ai_player)
	# Target is airborne above the ground platform -- settle only the AI player

	# Inject the JUMP route step with the player on the floor (jump_pressed depends on is_on_floor)
	ai.current_route_step = {
		"focus_position": ride_point.global_position,
		"source_point": board_point,
		"target_point": ride_point,
		"link": jump_link,
		"traversal_type": AIRouteLink.TraversalType.JUMP,
		"activation_distance": 28.0,
	}
	_assert(ai_player.is_on_floor(), "T2.08: Player must be on floor for jump-boarding test (physics pre-condition)")
	var control := ai._build_route_link_control_state()
	_assert(
		bool(control.get("jump_pressed", false)),
		"T2.08: Expected jump input issued when executing platform boarding route step"
	)
	_assert(
		_get_control_direction(control).x > 0.0,
		"T2.08: Expected rightward approach direction when boarding platform"
	)
	await _cleanup_arena(arena)


# T2.09 - Avoid spikes while still reaching the objective
# The AI forward-path probe must flag spikes as a hazard.
# With a JUMP route step injected, the AI must execute jump input to cross safely.
func _test_t2_avoid_spikes_reach_chest() -> void:
	var arena := _make_arena()
	_spawn_ground(arena, Vector2(320.0, 290.0), Vector2(640.0, 18.0))
	var spikes := SPIKES_SCENE.instantiate() as Area2D
	spikes.position = Vector2(270.0, 276.0)
	arena.add_child(spikes)

	var ai_player := _spawn_player(arena, Vector2(180.0, 250.0))
	var target_player := _spawn_player(arena, Vector2(450.0, 250.0))
	var chest := DummyChest.new()
	chest.position = Vector2(430.0, 250.0)
	arena.add_child(chest)

	var routes := Node2D.new()
	routes.name = "AIRoutes"
	arena.add_child(routes)
	var before_point := _spawn_route_point(routes, "BeforeSpike", Vector2(200.0, 268.0))
	var after_point := _spawn_route_point(routes, "AfterSpike", Vector2(360.0, 268.0))
	var jump_link := _spawn_route_link(before_point, after_point, AIRouteLink.TraversalType.JUMP, 28.0, null, 0)

	ai_player.arrow_count = 0
	ai_player.special_arrow_count = 0
	var ai := _get_ai(ai_player)
	ai.enabled = true
	await _settle_player_on_floor(ai_player)
	await _settle_player_on_floor(target_player)

	ai_player.global_position = before_point.global_position + Vector2(0.0, -18.0)

	# Hazard detection: forward path toward spikes must flag as hazard
	var path_assessment := ai._assess_forward_path(1)
	_assert(
		bool(path_assessment.get("hazard", false)),
		"T2.09: Expected forward path assessment to detect spike hazard ahead"
	)

	# Route execution: injected JUMP step must produce jump input to cross safely
	ai.current_route_step = {
		"focus_position": after_point.global_position,
		"source_point": before_point,
		"target_point": after_point,
		"link": jump_link,
		"traversal_type": AIRouteLink.TraversalType.JUMP,
		"activation_distance": 28.0,
	}
	var control := ai._build_route_link_control_state()
	_assert(
		bool(control.get("jump_pressed", false)),
		"T2.09: Expected jump input to clear spikes when JUMP route step is active"
	)
	await _cleanup_arena(arena)


# T2.10 - Prefer a reachable route entry over a closer point on another floor
# If the chest route graph contains a point directly below the AI and a usable
# entry point on the current platform, the AI must begin at the reachable top
# point instead of locking onto the lower point and stalling with vertical-only input.
func _test_t2_route_entry_stays_on_reachable_floor() -> void:
	var arena := _make_arena()
	_spawn_ground(arena, Vector2(320.0, 180.0), Vector2(560.0, 18.0))
	_spawn_ground(arena, Vector2(180.0, 420.0), Vector2(280.0, 18.0))
	var ai_player := _spawn_player(arena, Vector2(120.0, 140.0))
	var target_player := _spawn_player(arena, Vector2(520.0, 140.0))
	var chest := DummyChest.new()
	chest.position = Vector2(140.0, 380.0)
	arena.add_child(chest)

	var routes := Node2D.new()
	routes.name = "AIRoutes"
	arena.add_child(routes)
	var top_entry := _spawn_route_point(routes, "TopEntry", Vector2(400.0, 158.0))
	var bottom_goal := _spawn_route_point(routes, "BottomGoal", Vector2(140.0, 398.0))
	_spawn_route_link(top_entry, bottom_goal, AIRouteLink.TraversalType.DROP, 28.0, null, 0)

	ai_player.arrow_count = 0
	ai_player.special_arrow_count = 0
	var ai := _get_ai(ai_player)
	ai.enabled = true
	await _settle_player_on_floor(ai_player)
	await _settle_player_on_floor(target_player)

	ai.get_control_state(1.0 / 60.0)
	_assert(
		ai.goal_type == AIController.GoalType.CHEST and ai.goal_node == chest,
		"T2.10: Expected CHEST goal for the low-ammo route-entry drill"
	)
	_assert(
		not ai.current_route_path.is_empty() and ai.current_route_path[0] == top_entry,
		"T2.10: Expected route to start from the reachable top entry, not the lower chest point"
	)
	_assert(
		ai.current_route_step.get("focus_position", Vector2.ZERO) == top_entry.global_position,
		"T2.10: Expected initial route focus to stay on the current platform"
	)
	await _cleanup_arena(arena)


# T2.10b - Fight routes must exit on the target's reachable floor
func _test_t2_fight_route_exit_stays_on_target_floor() -> void:
	var arena := _make_arena()
	_spawn_ground(arena, Vector2(180.0, 420.0), Vector2(320.0, 18.0))
	_spawn_ground(arena, Vector2(520.0, 240.0), Vector2(140.0, 18.0))
	_spawn_ground(arena, Vector2(520.0, 180.0), Vector2(300.0, 18.0))
	var ai_player := _spawn_player(arena, Vector2(120.0, 380.0))
	var target_player := _spawn_player(arena, Vector2(520.0, 140.0))

	var routes := Node2D.new()
	routes.name = "AIRoutes"
	arena.add_child(routes)
	var start_entry := _spawn_route_point(routes, "FightStart", Vector2(220.0, 398.0))
	var wrong_mid := _spawn_route_point(routes, "FightWrongMid", Vector2(520.0, 218.0))
	var top_exit := _spawn_route_point(routes, "FightTopExit", Vector2(420.0, 158.0))
	_spawn_route_link(start_entry, wrong_mid, AIRouteLink.TraversalType.JUMP, 28.0, null, 0)
	_spawn_route_link(wrong_mid, top_exit, AIRouteLink.TraversalType.JUMP, 28.0, null, 0)

	var ai := _get_ai(ai_player)
	ai.enabled = true
	await _settle_player_on_floor(ai_player)
	await _settle_player_on_floor(target_player)

	ai.get_control_state(1.0 / 60.0)
	_assert(
		ai.goal_type == AIController.GoalType.FIGHT,
		"T2.10b: Expected FIGHT goal for target-platform route exit drill"
	)
	_assert(
		not ai.current_route_path.is_empty() and ai.current_route_path[ai.current_route_path.size() - 1] == top_exit,
		"T2.10b: Expected fight route to end at a route point on the target platform"
	)
	_assert(
		ai.current_route_path.size() >= 2 and ai.current_route_path[ai.current_route_path.size() - 2] == wrong_mid,
		"T2.10b: Expected fight route to continue past the misleading mid platform instead of stopping there"
	)
	await _cleanup_arena(arena)


# T2.10c - Jump over a jump-pad base instead of running into it
func _test_t2_fight_jumps_over_pad_obstacle() -> void:
	var arena := _make_arena()
	_spawn_ground(arena, Vector2(320.0, 290.0), Vector2(640.0, 18.0))
	var ai_player := _spawn_player(arena, Vector2(208.0, 250.0))
	var target_player := _spawn_player(arena, Vector2(420.0, 250.0))

	ai_player.arrow_count = 0
	ai_player.special_arrow_count = 0
	var ai := _get_ai(ai_player)
	ai.enabled = true
	await _settle_player_on_floor(ai_player)
	await _settle_player_on_floor(target_player)

	var floor_info := ai._probe_floor(0.0)
	var jump_pad := JUMP_PAD_SCENE.instantiate() as Node2D
	jump_pad.position = Vector2(260.0, float(floor_info.get("point", ai_player.global_position).y) + 8.0)
	arena.add_child(jump_pad)
	await _settle_player_on_floor(ai_player)

	ai.target = target_player
	ai.cached_pads = [jump_pad]
	ai.enabled = false
	ai_player.global_position.x = 232.0
	await _settle_frames(1)
	var movement_plan := ai._apply_movement_safety(Vector2.RIGHT, false)
	_assert(
		_get_control_direction(movement_plan).x > 0.0 and bool(movement_plan.get("jump_pressed", false)),
		"T2.10c: Expected AI to jump over the jump-pad base instead of running into it"
	)
	await _cleanup_arena(arena)


# T2.10d - Fight fallback must step off ledges for lower targets even without authored routes
func _test_t2_fight_drops_to_lower_target_without_route() -> void:
	var arena := _make_arena()
	_spawn_ground(arena, Vector2(320.0, 180.0), Vector2(560.0, 18.0))
	_spawn_ground(arena, Vector2(180.0, 420.0), Vector2(280.0, 18.0))
	var ai_player := _spawn_player(arena, Vector2(220.0, 140.0))
	var target_player := _spawn_player(arena, Vector2(120.0, 380.0))
	var ai := _get_ai(ai_player)
	ai.enabled = true
	await _settle_player_on_floor(ai_player)
	await _settle_player_on_floor(target_player)

	ai.target = target_player
	var approach_direction := ai._get_approach_direction()
	_assert(
		approach_direction.x < 0.0,
		"T2.10d: Expected fight approach to move toward the left drop edge for a lower target"
	)
	await _cleanup_arena(arena)


# T2.11 - Step off a ledge for a lower chest even without authored routes
func _test_t2_drop_to_lower_chest_without_route() -> void:
	var arena := _make_arena()
	_spawn_ground(arena, Vector2(320.0, 180.0), Vector2(560.0, 18.0))
	_spawn_ground(arena, Vector2(180.0, 420.0), Vector2(280.0, 18.0))
	var ai_player := _spawn_player(arena, Vector2(220.0, 140.0))
	var target_player := _spawn_player(arena, Vector2(520.0, 140.0))
	var chest := DummyChest.new()
	chest.position = Vector2(120.0, 380.0)
	arena.add_child(chest)

	ai_player.arrow_count = 0
	ai_player.special_arrow_count = 0
	var ai := _get_ai(ai_player)
	ai.enabled = true
	await _settle_player_on_floor(ai_player)
	await _settle_player_on_floor(target_player)

	var control := ai.get_control_state(1.0 / 60.0)
	_assert(
		ai.goal_type == AIController.GoalType.CHEST and ai.goal_node == chest,
		"T2.11: Expected CHEST goal in the lower-ledge fallback drill"
	)
	_assert(
		_get_control_direction(control).x < 0.0,
		"T2.11: Expected AI to move toward the left drop edge for the lower chest"
	)
	await _cleanup_arena(arena)


# T2.12 - Use a wrap-fall backup for an upper chest when no route or pad exists
func _test_t2_wrap_fall_to_upper_chest_without_route() -> void:
	var arena := _make_arena()
	_spawn_ground(arena, Vector2(320.0, 560.0), Vector2(560.0, 18.0))
	var ai_player := _spawn_player(arena, Vector2(240.0, 520.0))
	var target_player := _spawn_player(arena, Vector2(520.0, 520.0))
	var chest := DummyChest.new()
	chest.position = Vector2(120.0, 120.0)
	arena.add_child(chest)

	ai_player.arrow_count = 0
	ai_player.special_arrow_count = 0
	var ai := _get_ai(ai_player)
	ai.enabled = true
	await _settle_player_on_floor(ai_player)
	await _settle_player_on_floor(target_player)

	var control := ai.get_control_state(1.0 / 60.0)
	_assert(
		ai.goal_type == AIController.GoalType.CHEST and ai.goal_node == chest,
		"T2.12: Expected CHEST goal in the wrap-fall fallback drill"
	)
	_assert(
		_get_control_direction(control).x < 0.0,
		"T2.12: Expected AI to move toward the left edge to fall and vertical-wrap upward"
	)
	await _cleanup_arena(arena)


# T2.13 - Convert a clean stomp window
# When the AI player is directly above the enemy within stomp range and no
# disciplined shot is available, the AI must choose APPROACH state to pursue
# the stomp rather than aiming a low-quality shot or idling.
func _test_t2_stomp_window_conversion() -> void:
	var arena := _make_arena()
	_spawn_ground(arena, Vector2(320.0, 290.0), Vector2(640.0, 18.0))
	var ai_player := _spawn_player(arena, Vector2(220.0, 140.0))
	var target_player := _spawn_player(arena, Vector2(230.0, 268.0))
	var ai := _get_ai(ai_player)
	ai.enabled = true
	await _settle_player_on_floor(target_player)
	await _settle_frames(2)

	# No ammo forces stomp as the only offensive option
	ai_player.arrow_count = 0
	ai_player.special_arrow_count = 0
	ai.target = target_player

	ai.get_control_state(1.0 / 60.0)
	var stomp_window := ai._get_stomp_window()
	_assert(
		bool(stomp_window.get("available", false)),
		"T2.13: Expected stomp window to be available with AI directly above grounded enemy"
	)
	_assert(
		ai.state == AIController.AIState.APPROACH,
		"T2.13: Expected APPROACH state when stomp window is open and no shot alternatives exist"
	)
	await _cleanup_arena(arena)


# T2.14 - Evade an overhead stomp threat
# When the enemy player is directly above within stomp threat range and
# descending, the AI must recognise the urgent threat and enter RETREAT state.
func _test_t2_evade_stomp_threat() -> void:
	var arena := _make_arena()
	_spawn_ground(arena, Vector2(320.0, 290.0), Vector2(640.0, 18.0))
	var ai_player := _spawn_player(arena, Vector2(220.0, 268.0))
	var target_player := _spawn_player(arena, Vector2(228.0, 100.0))
	var ai := _get_ai(ai_player)
	ai.enabled = true
	await _settle_player_on_floor(ai_player)
	await _settle_frames(2)

	# Target is airborne above the AI and descending — prime stomp threat conditions
	target_player.velocity = Vector2(0.0, 400.0)
	ai.target = target_player

	ai.get_control_state(1.0 / 60.0)
	var stomp_threat := ai._get_stomp_threat()
	_assert(
		not stomp_threat.is_empty(),
		"T2.14: Expected stomp threat detected when enemy is directly above and descending"
	)
	_assert(
		ai.state == AIController.AIState.RETREAT,
		"T2.14: Expected RETREAT state when urgent stomp threat is overhead"
	)
	await _cleanup_arena(arena)


# ---------------------------------------------------------------------------
# Shared helpers (mirrors ai_smoke_test.gd)
# ---------------------------------------------------------------------------

func _make_arena() -> Node2D:
	var arena := Node2D.new()
	root.add_child(arena)
	current_scene = arena
	return arena


func _spawn_ground(parent: Node, position: Vector2, size: Vector2) -> StaticBody2D:
	var ground := StaticBody2D.new()
	ground.position = position
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	ground.add_child(collision)
	parent.add_child(ground)
	return ground


func _spawn_player(parent: Node, position: Vector2) -> Player:
	var player := PLAYER_SCENE.instantiate() as Player
	parent.add_child(player)
	player.global_position = position
	player.set_world_hud_visible(false)
	return player


func _get_ai(player: Player) -> AIController:
	return player.get_node(^"AIController") as AIController


func _spawn_route_point(parent: Node, point_name: String, position: Vector2) -> AIRoutePoint:
	var point := AIRoutePoint.new()
	point.name = point_name
	point.position = position
	parent.add_child(point)
	return point


func _spawn_route_link(
	source: AIRoutePoint,
	target: AIRoutePoint,
	traversal_type: int,
	activation_distance: float,
	helper_node: Node2D,
	wall_contact_direction: int
) -> AIRouteLink:
	var link := AIRouteLink.new()
	source.add_child(link)
	link.target_point_path = link.get_path_to(target)
	link.traversal_type = traversal_type
	link.activation_distance = activation_distance
	link.wall_contact_direction = wall_contact_direction
	if helper_node != null:
		link.helper_node_path = link.get_path_to(helper_node)
	return link


func _settle_frames(frame_count: int) -> void:
	for _index in range(frame_count):
		await physics_frame
		await process_frame


func _settle_player_on_floor(player: Player, max_frames: int = 90) -> void:
	for _index in range(max_frames):
		if player.is_on_floor():
			return
		await _settle_frames(1)


func _cleanup_arena(arena: Node) -> void:
	if arena != null and is_instance_valid(arena):
		arena.queue_free()
	current_scene = null
	await process_frame


func _get_control_direction(control: Dictionary) -> Vector2:
	var direction: Variant = control.get("direction", Vector2.ZERO)
	if direction is Vector2:
		return direction
	return Vector2.ZERO


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
