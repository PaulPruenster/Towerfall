class_name AIController
extends Node


enum AIState {
	IDLE,
	APPROACH,
	AIM,
	SHOOT,
	DODGE,
	RETREAT,
}

enum GoalType {
	FIGHT,
	CHEST,
	SWITCH,
	RECOVER,
}

enum ChestReward {
	ARROWS,
	HEALTH,
	EXPLOSIVE,
	RICOCHET,
	STRAIGHT,
	TRIPLE_SHOT,
	RAPID_FIRE,
	EXTRA_DASH,
	ARMOR,
	SPEED,
}

const AI_ROUTE_POINT_SCRIPT = preload("res://scripts/gameplay/ai_route_point.gd")
const AI_ROUTE_LINK_SCRIPT = preload("res://scripts/gameplay/ai_route_link.gd")
const AI_ROUTE_POINT_SCRIPT_PATH := "res://scripts/gameplay/ai_route_point.gd"
const APPROACH_DISTANCE: float = 360.0
const RETREAT_DISTANCE: float = 180.0
const AIM_SIMULATION_STEP: float = 1.0 / 60.0
const AIM_SIMULATION_TIME: float = 1.25
const AIM_ACCEPTABLE_MISS: float = 34.0
const DODGE_SIMULATION_TIME: float = 0.75
const DODGE_THREAT_RADIUS: float = 42.0
const JUMP_TARGET_HEIGHT: float = 96.0
const STUCK_SPEED_THRESHOLD: float = 24.0
const STUCK_JUMP_TIME: float = 0.55
const STUCK_ESCAPE_TIME: float = 1.3
const STUCK_PANIC_TIME: float = 2.4
const FLOOR_PROBE_UP_OFFSET: float = 8.0
const FLOOR_PROBE_DEPTH: float = 140.0
const TAKEOFF_PROBE_DISTANCE: float = 10.0
const FORWARD_BLOCK_CHECK_DISTANCE: float = 26.0
const FORWARD_OBSTACLE_CHECK_DISTANCE: float = 24.0
const FORWARD_OBSTACLE_LOWER_HEIGHT: float = 18.0
const FORWARD_OBSTACLE_UPPER_HEIGHT: float = -12.0
const PAD_STEP_JUMP_MIN_DISTANCE: float = 8.0
const PAD_STEP_JUMP_MAX_DISTANCE: float = 72.0
const PAD_STEP_JUMP_VERTICAL_TOLERANCE: float = 72.0
const JUMP_SCAN_START: float = 48.0
const JUMP_SCAN_END: float = 240.0
const JUMP_SCAN_STEP: float = 16.0
const MAX_SAFE_STEP_DOWN: float = 96.0
const MAX_JUMP_LANDING_RISE: float = 76.0
const MAX_JUMP_LANDING_DROP: float = 200.0
const SPIKES_SCRIPT_PATH := "res://scripts/gameplay/spikes.gd"
const JUMP_PAD_SCRIPT_PATH := "res://scripts/gameplay/jumping_pad.gd"
const JUMP_PAD_SCRIPT = preload("res://scripts/gameplay/jumping_pad.gd")
# If goal is above this many px and a floor-level pad exists, redirect to the pad.
const PAD_GOAL_HEIGHT_THRESHOLD: float = 220.0
const GOAL_REACHED_DISTANCE: float = 28.0
const GOAL_STICK_MIN: float = 0.65
const GOAL_STICK_MAX: float = 1.2
const OPPORTUNISTIC_SHOT_DISTANCE: float = 120.0
const ROUTE_POINT_REACHED_DISTANCE: float = 34.0
const ROUTE_USE_DISTANCE: float = 220.0
const ROUTE_USE_VERTICAL_DISTANCE: float = 92.0
const ROUTE_CANDIDATE_COUNT: int = 3
const ROUTE_DIRECT_ACCESS_VERTICAL_TOLERANCE: float = 56.0
const ROUTE_DIRECT_ACCESS_SAMPLE_STEP: float = 24.0
const ROUTE_DIRECT_ACCESS_EDGE_MARGIN: float = 20.0
const DROP_SEEK_VERTICAL_THRESHOLD: float = 84.0
const DROP_EDGE_SCAN_DISTANCE: float = 420.0
const DROP_EDGE_SCORE_TARGET_WEIGHT: float = 0.65
const CHEST_LOOT_SATURATION_PENALTY: float = 0.7
const CHEST_DISTANCE_LOOT_PENALTY: float = 0.45
const CHEST_GOAL_STICK_BONUS: float = 0.18
const WRAP_ROUTE_EDGE_MARGIN: float = 96.0
const WRAP_ROUTE_VERTICAL_PROGRESS: float = 0.22
const COMBAT_SPACE_SAMPLE_DISTANCE: float = 92.0
const BAD_SPACE_SCORE: float = -0.22
const REPEAT_PENALTY: float = 0.35
const STABLE_AIR_SHOT_SPEED: float = 180.0
const STOMP_VERTICAL_MIN: float = 24.0
const STOMP_VERTICAL_MAX: float = 168.0
const STOMP_HORIZONTAL_RANGE: float = 72.0
const STOMP_ALIGNMENT_LOOKAHEAD: float = 0.18
const STOMP_THREAT_VERTICAL_RANGE: float = 172.0
const STOMP_THREAT_HORIZONTAL_RANGE: float = 86.0
const AIM_SIDE: Vector2 = Vector2.RIGHT
const DIAGONAL_COMPONENT: float = 0.70710677
const AIM_UP_DIAG: Vector2 = Vector2(DIAGONAL_COMPONENT, -DIAGONAL_COMPONENT)
const AIM_UP: Vector2 = Vector2.UP
const AIM_DOWN_DIAG: Vector2 = Vector2(DIAGONAL_COMPONENT, DIAGONAL_COMPONENT)
const AIM_DOWN: Vector2 = Vector2.DOWN

@export var enabled: bool = false
@export_range(0.0, 1.0, 0.01) var difficulty: float = 0.5

var player: Player
var target: Player
var state: int = AIState.IDLE
var current_aim_direction: Vector2 = Vector2.RIGHT
var aim_error_offset: Vector2 = Vector2.ZERO
var aim_hold_left: float = 0.0
var dodge_direction: Vector2 = Vector2.ZERO
var dodge_time_left: float = 0.0
var dodge_reaction_left: float = -1.0
var dodge_dash_pending: bool = false
var pending_threat_id: int = 0
var retreat_time_left: float = 0.0
var stuck_time_left: float = 0.0
var aim_commit_left: float = 0.0
var _escape_dir: int = 0
var cached_base_arrow_speed: float = 1000.0
var has_cached_base_arrow_speed: bool = false
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var action_history: Array[int] = []
var _session_shots_fired: int = 0
var _session_dodges_entered: int = 0
var _session_stuck_total: float = 0.0
var goal_type: int = GoalType.FIGHT
var goal_node: Node2D
var goal_stick_left: float = 0.0
var state_hold_left: float = 0.0
var _committed_lateral_dir: int = 0
var _lateral_commit_left: float = 0.0
var cached_scene_root: Node
var cached_chests: Array[Node2D] = []
var cached_switches: Array[Node2D] = []
var cached_pads: Array[Node2D] = []
var cached_route_points: Array[Node2D] = []
var current_route_path: Array[Node2D] = []
var current_route_step: Dictionary = {}
var debug_snapshot: Dictionary = {}

func _ready() -> void:
	player = get_parent() as Player
	_configure_rng()

func get_control_state(delta: float) -> Dictionary:
	if not enabled:
		_reset_runtime_state()
		return {"active": false}

	if player == null:
		player = get_parent() as Player
	if player == null:
		return {"active": false}

	target = _find_target()
	_refresh_goal_nodes()
	_update_timers(delta)
	_update_goal()
	_update_route_step()
	_update_stuck_timer(delta)
	_update_pending_dodge(delta)
	var aim_result: Dictionary = {}

	if dodge_time_left > 0.0:
		state = AIState.DODGE
	else:
		aim_result = _get_best_aim_result()
		var pre_choose := state
		_choose_state(aim_result)
		# Inertia: prevent frame-rate oscillation between movement states.
		if state != pre_choose:
			var prev_is_move := pre_choose == AIState.IDLE or pre_choose == AIState.APPROACH or pre_choose == AIState.RETREAT
			var new_is_move := state == AIState.IDLE or state == AIState.APPROACH or state == AIState.RETREAT
			if prev_is_move and new_is_move:
				if state_hold_left > 0.0:
					state = pre_choose
				else:
					state_hold_left = 0.45
					_committed_lateral_dir = 0
					_lateral_commit_left = 0.0

	action_history.push_back(state)
	if action_history.size() > 4:
		action_history.pop_front()

	var control_state := _build_control_state()
	_update_debug_snapshot(aim_result, control_state)
	if state == AIState.SHOOT:
		_session_shots_fired += 1
		state = AIState.RETREAT
		retreat_time_left = _get_post_shot_retreat_time()
		aim_hold_left = 0.0

	return control_state

func _reset_runtime_state() -> void:
	state = AIState.IDLE
	aim_hold_left = 0.0
	dodge_time_left = 0.0
	dodge_reaction_left = -1.0
	dodge_dash_pending = false
	pending_threat_id = 0
	retreat_time_left = 0.0
	stuck_time_left = 0.0
	aim_commit_left = 0.0
	_escape_dir = 0
	_committed_lateral_dir = 0
	_lateral_commit_left = 0.0
	goal_type = GoalType.FIGHT
	goal_node = null
	goal_stick_left = 0.0
	state_hold_left = 0.0
	current_route_path.clear()
	current_route_step.clear()
	action_history.clear()
	_session_shots_fired = 0
	_session_dodges_entered = 0
	_session_stuck_total = 0.0
	debug_snapshot = {"enabled": false}

func get_debug_snapshot() -> Dictionary:
	return debug_snapshot.duplicate(true)

func _update_timers(delta: float) -> void:
	aim_hold_left = max(aim_hold_left - delta, 0.0)
	aim_commit_left = max(aim_commit_left - delta, 0.0)
	dodge_time_left = max(dodge_time_left - delta, 0.0)
	retreat_time_left = max(retreat_time_left - delta, 0.0)
	goal_stick_left = max(goal_stick_left - delta, 0.0)
	state_hold_left = max(state_hold_left - delta, 0.0)
	_lateral_commit_left = max(_lateral_commit_left - delta, 0.0)
	if dodge_reaction_left >= 0.0:
		dodge_reaction_left = max(dodge_reaction_left - delta, 0.0)

func _update_stuck_timer(delta: float) -> void:
	if player == null or not _has_navigation_focus():
		stuck_time_left = 0.0
		return

	var target_delta := _get_navigation_delta(player.global_position, _get_navigation_focus_position())
	var is_moving_state := state == AIState.APPROACH or state == AIState.RETREAT
	if is_moving_state and player.is_on_floor() and absf(target_delta.x) > 14.0 and absf(player.velocity.x) < STUCK_SPEED_THRESHOLD:
		stuck_time_left += delta
		_session_stuck_total += delta
		# Pick a random escape direction the moment STUCK_ESCAPE_TIME is breached.
		if stuck_time_left >= STUCK_ESCAPE_TIME and _escape_dir == 0:
			_escape_dir = 1 if rng.randf() > 0.5 else -1
		# After STUCK_PANIC_TIME, force goal re-evaluation so the AI can change its mind.
		if stuck_time_left >= STUCK_PANIC_TIME:
			goal_stick_left = 0.0
	else:
		stuck_time_left = 0.0
		_escape_dir = 0

func _update_pending_dodge(delta: float) -> void:
	if player == null:
		return

	if state == AIState.DODGE and dodge_time_left > 0.0:
		return

	var threat := _find_incoming_arrow()
	if threat.is_empty():
		pending_threat_id = 0
		dodge_reaction_left = -1.0
		return

	var arrow := threat.get("arrow") as Arrow
	if arrow == null:
		return

	var threat_id := arrow.get_instance_id()
	if threat_id != pending_threat_id:
		pending_threat_id = threat_id
		dodge_direction = _choose_dodge_direction(threat)
		dodge_reaction_left = _get_reaction_time()
		return

	if dodge_reaction_left > 0.0:
		return

	_enter_dodge()

func _enter_dodge() -> void:
	_session_dodges_entered += 1
	state = AIState.DODGE
	dodge_time_left = rng.randf_range(_get_dodge_duration_range().x, _get_dodge_duration_range().y)
	dodge_dash_pending = true
	pending_threat_id = 0
	dodge_reaction_left = -1.0

func _apply_variety_weight(candidate_state: int, base_score: float) -> float:
	var repeat_count: int = 0
	for past_state in action_history:
		if past_state == candidate_state:
			repeat_count += 1
	return base_score - repeat_count * REPEAT_PENALTY * (1.0 - difficulty)

func _choose_state(aim_result: Dictionary) -> void:
	var pursuing_goal := _has_active_travel_goal() and not _is_goal_reached()
	# When the enemy enters combat range during a chest/switch goal, abandon the goal
	# so _update_goal picks FIGHT next tick. Leaving the goal active causes the AI to
	# fight while still pretending it wants a chest, producing indefinite indecision.
	var enemy_in_range := target != null and _get_wrapped_delta(player.global_position, target.global_position).length() < _get_desired_retreat_distance() * 1.35
	if pursuing_goal and enemy_in_range:
		goal_stick_left = 0.0  # let _update_goal re-evaluate immediately
	if pursuing_goal and not enemy_in_range and not _should_take_opportunistic_shot(aim_result):
		state = AIState.APPROACH
		return

	if goal_type == GoalType.RECOVER and target != null:
		state = AIState.RETREAT
		if retreat_time_left <= 0.0:
			retreat_time_left = _get_post_shot_retreat_time()
		return

	if target == null:
		state = AIState.APPROACH if pursuing_goal else AIState.IDLE
		return

	var target_delta := _get_wrapped_delta(player.global_position, target.global_position)
	var distance := target_delta.length()
	var can_take_shot := _can_commit_to_shot(aim_result)
	var combat_position_safe := _is_combat_position_safe()
	var stomp_threat := _get_stomp_threat()
	var stomp_window := _get_stomp_window()
	var retreat_distance := _get_desired_retreat_distance()
	var approach_distance := _get_desired_approach_distance()

	if state == AIState.DODGE and dodge_time_left > 0.0:
		return

	if bool(stomp_threat.get("urgent", false)):
		aim_hold_left = 0.0
		state = AIState.RETREAT
		if retreat_time_left <= 0.0:
			retreat_time_left = _get_post_shot_retreat_time()
		return

	if _should_prioritize_stomp(stomp_window, aim_result):
		aim_hold_left = 0.0
		state = AIState.APPROACH
		retreat_time_left = 0.0
		return

	if state == AIState.AIM:
		# Hard abort: no ammo or no target — always exit immediately.
		var hard_abort := not player.has_available_ammo() or target == null
		# While aim_commit_left > 0, ignore shot-quality and position flicker.
		# Only a hard abort or a definitively bad shot (viable=false after commit
		# expires) can eject us from AIM.
		var committed := aim_commit_left > 0.0
		if hard_abort or (not committed and (not can_take_shot or not combat_position_safe)):
			aim_hold_left = 0.0
			aim_commit_left = 0.0
			if distance > approach_distance:
				state = AIState.APPROACH
			else:
				state = _get_preferred_close_combat_state(target_delta, distance)
			return
		if not committed:
			current_aim_direction = aim_result.get("direction", current_aim_direction)
		if aim_hold_left <= 0.0:
			state = AIState.SHOOT
		return

	# Allow AIM even inside retreat_distance when a shot is ready — shooting
	# staggers the post-shot timers and naturally breaks pair synchrony.
	if can_take_shot and combat_position_safe:
		if state != AIState.AIM:
			state = AIState.AIM
			current_aim_direction = aim_result.get("direction", current_aim_direction)
			aim_error_offset = _get_aim_error_offset()
			aim_hold_left = _get_aim_hold_time()
			aim_commit_left = rng.randf_range(0.35, 0.6)
		return

	if distance < retreat_distance or retreat_time_left > 0.0:
		state = _get_preferred_close_combat_state(target_delta, distance)
		if retreat_time_left <= 0.0:
			# Use a wider time range than the post-shot retreat so that
			# mirrored AI pairs naturally drift out of phase.
			retreat_time_left = _get_spacing_retreat_time()
		return

	if distance > approach_distance or not player.has_available_ammo():
		var candidate_state: int = AIState.APPROACH
		var weighted: float = _apply_variety_weight(candidate_state, 0.0)
		if weighted < 0.0 and rng.randf() > difficulty:
			candidate_state = AIState.IDLE
		state = candidate_state
		return

	var candidate_state: int = AIState.IDLE
	var weighted: float = _apply_variety_weight(candidate_state, 0.0)
	if weighted < 0.0 and rng.randf() > difficulty:
		candidate_state = AIState.APPROACH
	state = candidate_state

func _build_control_state() -> Dictionary:
	match state:
		AIState.AIM:
			return _make_control_state(current_aim_direction, true, false, false)
		AIState.SHOOT:
			return _make_control_state(current_aim_direction, false, false, false)
		AIState.DODGE:
			var jump_pressed := player.is_on_floor() and dodge_direction.y < 0.0
			var dash_pressed := dodge_dash_pending
			dodge_dash_pending = false
			return _make_control_state(dodge_direction, false, jump_pressed, dash_pressed)
		AIState.RETREAT:
			var retreat_result := _build_safe_movement_state(_get_retreat_direction())
			if stuck_time_left >= STUCK_ESCAPE_TIME and player.is_on_floor():
				retreat_result["dash_pressed"] = true
			return retreat_result
		AIState.APPROACH:
			var approach_result := _build_safe_movement_state(_get_approach_direction())
			if stuck_time_left >= STUCK_ESCAPE_TIME and player.is_on_floor():
				approach_result["dash_pressed"] = true
			return approach_result
		_:
			return _make_control_state(Vector2.ZERO, false, false, false)

func _make_control_state(direction: Vector2, use_pressed: bool, jump_pressed: bool, dash_pressed: bool) -> Dictionary:
	return {
		"active": true,
		"direction": direction,
		"use_pressed": use_pressed,
		"jump_pressed": jump_pressed,
		"dash_pressed": dash_pressed,
	}

func _build_safe_movement_state(base_direction: Vector2) -> Dictionary:
	var route_state := _build_route_link_control_state()
	if not route_state.is_empty():
		return route_state

	var requested_jump := _should_jump(base_direction)
	var movement_plan := _apply_movement_safety(base_direction, requested_jump)
	return _make_control_state(
		movement_plan.get("direction", Vector2.ZERO),
		false,
		bool(movement_plan.get("jump_pressed", false)),
		false
	)

func _apply_movement_safety(base_direction: Vector2, requested_jump: bool) -> Dictionary:
	var safe_direction := _to_digital_direction(base_direction)
	var jump_pressed := requested_jump
	if player == null or safe_direction == Vector2.ZERO:
		return {
			"direction": safe_direction,
			"jump_pressed": jump_pressed,
		}

	var horizontal_sign := int(sign(safe_direction.x))
	if horizontal_sign == 0 or not player.is_on_floor():
		return {
			"direction": safe_direction,
			"jump_pressed": jump_pressed,
		}

	var path_assessment := _assess_forward_path(horizontal_sign)
	var forward_pad := _find_forward_pad(horizontal_sign)
	if forward_pad != null:
		return {
			"direction": Vector2(float(horizontal_sign), 0.0),
			"jump_pressed": true,
		}
	if not bool(path_assessment.get("blocked", false)):
		return {
			"direction": Vector2(float(horizontal_sign), 0.0),
			"jump_pressed": jump_pressed,
		}

	if bool(path_assessment.get("jumpable", false)):
		return {
			"direction": Vector2(float(horizontal_sign), 0.0),
			"jump_pressed": true,
		}

	if _can_commit_to_wrap_route(horizontal_sign, path_assessment):
		return {
			"direction": Vector2(float(horizontal_sign), 0.0),
			"jump_pressed": false,
		}

	# No fall damage and screen wrapping means gaps and drops are safe to walk through.
	# Only hard-block on hazards (spikes).
	if not bool(path_assessment.get("hazard", false)):
		return {
			"direction": Vector2(float(horizontal_sign), 0.0),
			"jump_pressed": false,
		}

	return {
		"direction": Vector2.ZERO,
		"jump_pressed": false,
	}

# Probe the floor in front of the bot so it can tell a normal step from a real gap or hazard.
func _assess_forward_path(horizontal_sign: int) -> Dictionary:
	if player == null or horizontal_sign == 0:
		return {"blocked": false, "jumpable": false, "hazard": false}

	var current_floor := _get_current_floor_info(horizontal_sign)
	if current_floor.is_empty() or not bool(current_floor.get("walkable", false)):
		return {"blocked": false, "jumpable": false, "hazard": false}

	var current_floor_point: Vector2 = current_floor.get("point", player.global_position)
	var current_floor_y := current_floor_point.y
	var is_blocked := true
	var is_hazard := false
	var block_reason := &"gap"
	var forward_obstacle := _probe_forward_obstacle(horizontal_sign)
	if not forward_obstacle.is_empty():
		is_hazard = bool(forward_obstacle.get("hazard", false))
		block_reason = &"hazard" if is_hazard else &"wall"
	else:
		var forward_floor := _probe_floor(float(horizontal_sign) * FORWARD_BLOCK_CHECK_DISTANCE)

		if not forward_floor.is_empty():
			if bool(forward_floor.get("walkable", false)):
				var forward_point: Vector2 = forward_floor.get("point", current_floor_point)
				var step_down := forward_point.y - current_floor_y
				is_blocked = step_down > MAX_SAFE_STEP_DOWN
				if is_blocked:
					block_reason = &"drop"
			elif bool(forward_floor.get("hazard", false)):
				is_blocked = true
				is_hazard = true
				block_reason = &"hazard"

	if not is_blocked:
		return {"blocked": false, "jumpable": false, "hazard": false}

	var landing := _find_jump_landing(horizontal_sign, current_floor_y)
	return {
		"blocked": true,
		"jumpable": not landing.is_empty(),
		"landing": landing,
		"hazard": is_hazard,
		"reason": block_reason,
	}

func _get_current_floor_info(horizontal_sign: int) -> Dictionary:
	var front_floor := _probe_floor(float(horizontal_sign) * TAKEOFF_PROBE_DISTANCE)
	if not front_floor.is_empty() and bool(front_floor.get("walkable", false)):
		return front_floor

	var center_floor := _probe_floor(0.0)
	if not center_floor.is_empty() and bool(center_floor.get("walkable", false)):
		return center_floor

	return _probe_floor(float(-horizontal_sign) * TAKEOFF_PROBE_DISTANCE)

func _find_jump_landing(horizontal_sign: int, current_floor_y: float) -> Dictionary:
	var distance := JUMP_SCAN_START
	while distance <= JUMP_SCAN_END:
		var landing := _probe_floor(float(horizontal_sign) * distance)
		if not landing.is_empty() and bool(landing.get("walkable", false)):
			var landing_point: Vector2 = landing.get("point", player.global_position)
			var rise := current_floor_y - landing_point.y
			# Only treat as a jumpable target when the destination is at or above the
			# current floor (same-level gap jumps and upward jumps). Lower platforms are
			# not jumpable — the non-hazard passthrough lets the AI walk off the edge
			# freely. Marking lower floors as jumpable causes the AI to bounce in place
			# trying to jump down instead of simply stepping off.
			if rise >= -4.0 and rise <= MAX_JUMP_LANDING_RISE:
				landing["distance"] = distance
				return landing
		distance += JUMP_SCAN_STEP

	return {}

func _probe_floor(x_offset: float) -> Dictionary:
	if player == null:
		return {}

	return _probe_floor_from_position(player.global_position, x_offset)

func _probe_floor_from_position(base_position: Vector2, x_offset: float = 0.0) -> Dictionary:
	if player == null:
		return {}

	var ray_origin := base_position + Vector2(x_offset, -FLOOR_PROBE_UP_OFFSET)
	var ray_target := base_position + Vector2(x_offset, FLOOR_PROBE_DEPTH)
	var excluded: Array = [player]
	var fallback_hit: Dictionary = {}

	for _attempt in range(4):
		var hit := _raycast(ray_origin, ray_target, excluded)
		if hit.is_empty():
			return fallback_hit

		var collider: Object = hit.get("collider")
		var floor_info := {
			"point": hit.get("position", base_position),
			"collider": collider,
			"hazard": _is_hazard_collider(collider),
			"walkable": _is_walkable_collider(collider),
		}
		if bool(floor_info.get("hazard", false)) or bool(floor_info.get("walkable", false)):
			return floor_info

		fallback_hit = floor_info
		excluded.append(collider)

	return fallback_hit

func _raycast(origin: Vector2, target_position: Vector2, excluded: Array) -> Dictionary:
	if player == null:
		return {}

	var query := PhysicsRayQueryParameters2D.create(origin, target_position)
	query.exclude = excluded
	query.collide_with_areas = true
	query.collide_with_bodies = true
	return player.get_world_2d().direct_space_state.intersect_ray(query)

func _raycast_bodies_only(origin: Vector2, target_position: Vector2, excluded: Array) -> Dictionary:
	if player == null:
		return {}

	var query := PhysicsRayQueryParameters2D.create(origin, target_position)
	query.exclude = excluded
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return player.get_world_2d().direct_space_state.intersect_ray(query)

func _probe_forward_obstacle(horizontal_sign: int) -> Dictionary:
	if player == null or horizontal_sign == 0:
		return {}

	var excluded: Array = [player]
	if target != null:
		excluded.append(target)

	for sample_height in [FORWARD_OBSTACLE_LOWER_HEIGHT, FORWARD_OBSTACLE_UPPER_HEIGHT]:
		var ray_origin := player.global_position + Vector2(0.0, sample_height)
		var ray_target := ray_origin + Vector2(float(horizontal_sign) * FORWARD_OBSTACLE_CHECK_DISTANCE, 0.0)
		var hit := _raycast_bodies_only(ray_origin, ray_target, excluded)
		if hit.is_empty():
			continue

		var collider: Object = hit.get("collider")
		if _is_player_collider(collider):
			continue

		return {
			"collider": collider,
			"position": hit.get("position", ray_target),
			"hazard": _is_hazard_collider(collider),
			"walkable": _is_walkable_collider(collider),
		}

	return {}

func _is_player_collider(collider: Object) -> bool:
	var node := collider as Node
	return node != null and node.is_in_group("player")

func _is_hazard_collider(collider: Object) -> bool:
	var node := collider as Node
	if node == null:
		return false

	var script: Variant = node.get_script()
	return script != null and str(script.resource_path) == SPIKES_SCRIPT_PATH

func _is_walkable_collider(collider: Object) -> bool:
	var node := collider as Node
	if node == null:
		return false
	if node is Area2D:
		return false
	return not _is_hazard_collider(collider)

func _is_combat_position_safe() -> bool:
	if player == null or target == null or not player.is_on_floor():
		return true

	var target_delta := _get_wrapped_delta(player.global_position, target.global_position)
	var horizontal_sign := int(sign(target_delta.x))
	if horizontal_sign == 0:
		return true

	# At point-blank range the floor probes hit the enemy body and flip frame-to-frame.
	# Skip the path check and only use horizontal space score.
	var close_range := _get_desired_retreat_distance() * 0.7
	if target_delta.length() < close_range:
		return _get_horizontal_space_score(horizontal_sign, false) > BAD_SPACE_SCORE

	var path_assessment := _assess_forward_path(horizontal_sign)
	if bool(path_assessment.get("blocked", false)):
		return false
	return _get_horizontal_space_score(horizontal_sign, false) > BAD_SPACE_SCORE

func _find_best_pad_approach() -> Vector2:
	# Returns the global position of the nearest floor-level JumpPad when the navigation
	# focus is too high to reach by normal jumping. Active only when on the floor and
	# no PAD-type route link is already handling the traversal.
	if player == null or not player.is_on_floor() or cached_pads.is_empty():
		return Vector2.ZERO
	var step_type := int(current_route_step.get("traversal_type", -1))
	if step_type == AI_ROUTE_LINK_SCRIPT.TraversalType.PAD:
		return Vector2.ZERO  # route link already handles pad traversal
	var focus := _get_navigation_focus_position()
	var focus_delta := _get_navigation_delta(player.global_position, focus)
	if focus_delta.y > -PAD_GOAL_HEIGHT_THRESHOLD:
		return Vector2.ZERO  # goal not far enough above
	var best_pad: Node2D = null
	var best_dist := INF
	for pad in cached_pads:
		if pad == null:
			continue
		var pad_delta := _get_navigation_delta(player.global_position, pad.global_position)
		# Only consider pads on roughly the same floor (within 80 px vertically).
		if absf(pad_delta.y) > 80.0:
			continue
		var d := pad_delta.length()
		if d < best_dist:
			best_dist = d
			best_pad = pad
	if best_pad == null:
		return Vector2.ZERO
	return best_pad.global_position

func _find_forward_pad(horizontal_sign: int) -> Node2D:
	if player == null or horizontal_sign == 0 or cached_pads.is_empty() or not _has_navigation_focus():
		return null

	var focus_delta := _get_navigation_delta(player.global_position, _get_navigation_focus_position())
	if int(sign(focus_delta.x)) != horizontal_sign:
		return null

	var best_pad: Node2D = null
	var best_distance: float = INF
	for pad in cached_pads:
		if pad == null:
			continue

		var pad_delta := _get_navigation_delta(player.global_position, pad.global_position)
		if int(sign(pad_delta.x)) != horizontal_sign:
			continue
		var horizontal_distance := absf(pad_delta.x)
		if horizontal_distance < PAD_STEP_JUMP_MIN_DISTANCE or horizontal_distance > PAD_STEP_JUMP_MAX_DISTANCE:
			continue
		if absf(pad_delta.y) > PAD_STEP_JUMP_VERTICAL_TOLERANCE:
			continue
		if horizontal_distance >= absf(focus_delta.x):
			continue
		if horizontal_distance < best_distance:
			best_distance = horizontal_distance
			best_pad = pad

	return best_pad

func _find_drop_edge(direction_sign: int) -> Dictionary:
	if player == null or not player.is_on_floor() or direction_sign == 0:
		return {}

	var current_floor := _get_current_floor_info(direction_sign)
	if current_floor.is_empty() or not bool(current_floor.get("walkable", false)):
		return {}

	var previous_floor_point: Vector2 = current_floor.get("point", player.global_position)
	var distance: float = ROUTE_DIRECT_ACCESS_SAMPLE_STEP
	while distance <= DROP_EDGE_SCAN_DISTANCE:
		var sample_position := player.global_position + Vector2(float(direction_sign) * distance, 0.0)
		var sample_floor := _probe_floor_from_position(sample_position)
		if sample_floor.is_empty():
			return {
				"direction_sign": direction_sign,
				"distance": distance,
				"position": sample_position,
			}
		if bool(sample_floor.get("hazard", false)) or not bool(sample_floor.get("walkable", false)):
			return {}

		var sample_floor_point: Vector2 = sample_floor.get("point", sample_position)
		var rise := previous_floor_point.y - sample_floor_point.y
		if rise > MAX_JUMP_LANDING_RISE:
			return {}

		var drop := sample_floor_point.y - previous_floor_point.y
		if drop > MAX_SAFE_STEP_DOWN:
			return {
				"direction_sign": direction_sign,
				"distance": distance,
				"position": sample_position,
			}

		previous_floor_point = sample_floor_point
		distance += ROUTE_DIRECT_ACCESS_SAMPLE_STEP

	return {}

func _choose_drop_direction(target_position: Vector2) -> int:
	if player == null or not player.is_on_floor():
		return 0

	var best_sign := 0
	var best_score := INF
	for direction_sign in [-1, 1]:
		var edge := _find_drop_edge(direction_sign)
		if edge.is_empty():
			continue

		var edge_position: Vector2 = edge.get("position", player.global_position)
		var walk_distance: float = float(edge.get("distance", INF))
		var target_alignment := absf(_get_wrapped_delta(edge_position, target_position).x)
		var score: float = walk_distance + target_alignment * DROP_EDGE_SCORE_TARGET_WEIGHT
		if score < best_score:
			best_score = score
			best_sign = direction_sign

	return best_sign

func _get_drop_seek_direction(target_position: Vector2, allow_wrap_fallback: bool) -> int:
	if player == null or not player.is_on_floor():
		return 0

	var target_delta := _get_navigation_delta(player.global_position, target_position)
	var wants_drop_down := target_delta.y > DROP_SEEK_VERTICAL_THRESHOLD
	var wants_wrap_drop := allow_wrap_fallback and target_delta.y < -PAD_GOAL_HEIGHT_THRESHOLD
	if not wants_drop_down and not wants_wrap_drop:
		return 0

	return _choose_drop_direction(target_position)

func _get_approach_direction() -> Vector2:
	if player == null or not _has_navigation_focus():
		return Vector2.ZERO

	var target_delta := _get_navigation_delta(player.global_position, _get_navigation_focus_position())

	# If the goal is well above normal jump reach and a pad is on the same floor, use it.
	var pad_waypoint := _find_best_pad_approach()
	if pad_waypoint != Vector2.ZERO:
		target_delta = _get_navigation_delta(player.global_position, pad_waypoint)

	var drop_seek_sign := 0
	if current_route_step.is_empty():
		drop_seek_sign = _get_drop_seek_direction(_get_navigation_focus_position(), pad_waypoint == Vector2.ZERO)

	var horizontal := 0
	if drop_seek_sign != 0:
		horizontal = drop_seek_sign
	elif absf(target_delta.x) > 8.0:
		horizontal = int(sign(target_delta.x))
		if current_route_step.is_empty() and goal_type == GoalType.FIGHT:
			# Escape override before commitment so escape always wins.
			if stuck_time_left >= STUCK_ESCAPE_TIME and _escape_dir != 0:
				horizontal = _escape_dir
				_committed_lateral_dir = horizontal
				_lateral_commit_left = 0.3
			elif _lateral_commit_left > 0.0 and _committed_lateral_dir != 0:
				horizontal = _committed_lateral_dir
			else:
				horizontal = _choose_combat_horizontal_sign(target_delta, false)
				_committed_lateral_dir = horizontal
				_lateral_commit_left = rng.randf_range(0.3, 0.5)

	# Escape override for non-fight goals / route steps (no commitment needed there).
	if stuck_time_left >= STUCK_ESCAPE_TIME and _escape_dir != 0 and not (current_route_step.is_empty() and goal_type == GoalType.FIGHT):
		horizontal = _escape_dir

	var stomp_window := _get_stomp_window()
	if bool(stomp_window.get("available", false)):
		var stomp_delta: Vector2 = stomp_window.get("delta", target_delta)
		if absf(stomp_delta.x) > 10.0:
			horizontal = int(sign(stomp_delta.x))

	var vertical := 0
	if player.is_on_floor() and (target_delta.y < -JUMP_TARGET_HEIGHT or stuck_time_left >= STUCK_JUMP_TIME):
		vertical = -1
	elif not player.is_on_floor() and bool(stomp_window.get("available", false)):
		vertical = 1

	return _to_digital_direction(Vector2(horizontal, vertical))

func _get_retreat_direction() -> Vector2:
	if target == null:
		return Vector2.ZERO

	var target_delta := _get_wrapped_delta(player.global_position, target.global_position)
	var horizontal: int
	if stuck_time_left >= STUCK_ESCAPE_TIME and _escape_dir != 0:
		# Escape override always wins; reset commitment to escape direction.
		horizontal = _escape_dir
		_committed_lateral_dir = horizontal
		_lateral_commit_left = 0.3
	elif _lateral_commit_left > 0.0 and _committed_lateral_dir != 0:
		horizontal = _committed_lateral_dir
	else:
		horizontal = _choose_combat_horizontal_sign(target_delta, true)
		_committed_lateral_dir = horizontal
		_lateral_commit_left = rng.randf_range(0.3, 0.5)

	var vertical := -1 if player.is_on_floor() and stuck_time_left >= STUCK_JUMP_TIME else 0
	return _to_digital_direction(Vector2(horizontal, vertical))

func _should_jump(move_direction: Vector2) -> bool:
	if player == null or not _has_navigation_focus():
		return false
	if not player.is_on_floor():
		return false
	if move_direction == Vector2.ZERO:
		return false

	var target_delta := _get_navigation_delta(player.global_position, _get_navigation_focus_position())
	return target_delta.y < -JUMP_TARGET_HEIGHT or stuck_time_left >= STUCK_JUMP_TIME

func _refresh_goal_nodes() -> void:
	var scene := get_tree().current_scene
	if scene == cached_scene_root:
		return

	cached_scene_root = scene
	cached_chests.clear()
	cached_switches.clear()
	cached_pads.clear()
	cached_route_points.clear()
	if scene == null:
		return

	for node in scene.find_children("*", "", true, false):
		var node_2d := node as Node2D
		if node_2d == null:
			continue
		var node_script: Variant = node.get_script()
		var is_route_point: bool = node.is_class("AIRoutePoint") or node_script == AI_ROUTE_POINT_SCRIPT or (node_script != null and str(node_script.resource_path) == AI_ROUTE_POINT_SCRIPT_PATH)
		var route_point := node_2d if is_route_point else null
		if route_point != null:
			cached_route_points.append(route_point)
			continue
		if node.is_class("JumpPad") or node_script == JUMP_PAD_SCRIPT or (node_script != null and str(node_script.resource_path) == JUMP_PAD_SCRIPT_PATH):
			cached_pads.append(node_2d)
			continue
		if node.has_method("is_lootable") and node.has_method("get_reward_type"):
			cached_chests.append(node_2d)
		elif node.has_method("controls_disabled_gate") and node.has_method("get_controlled_gates"):
			cached_switches.append(node_2d)

	cached_route_points.sort_custom(_sort_route_points)

func _update_goal() -> void:
	if goal_stick_left > 0.0 and _is_current_goal_valid() and not _is_goal_reached():
		return
	_apply_goal(_choose_goal())

func _choose_goal() -> Dictionary:
	var best_goal: Dictionary = {}
	var best_score := -INF

	var fight_score := _score_fight_goal()
	if fight_score > best_score:
		best_score = fight_score
		best_goal = {
			"type": GoalType.FIGHT,
			"score": fight_score,
		}

	for chest in cached_chests:
		if chest == null:
			continue
		var chest_score := _score_chest_goal(chest)
		if chest_score > best_score:
			best_score = chest_score
			best_goal = {
				"type": GoalType.CHEST,
				"node": chest,
				"score": chest_score,
			}

	for switch_node in cached_switches:
		if switch_node == null:
			continue
		var switch_score := _score_switch_goal(switch_node)
		if switch_score > best_score:
			best_score = switch_score
			best_goal = {
				"type": GoalType.SWITCH,
				"node": switch_node,
				"score": switch_score,
			}

	var recover_score := _score_recover_goal()
	if recover_score > best_score:
		best_goal = {
			"type": GoalType.RECOVER,
			"score": recover_score,
		}

	return best_goal

func _apply_goal(goal: Dictionary) -> void:
	if goal.is_empty():
		goal_type = GoalType.FIGHT
		goal_node = null
		goal_stick_left = 0.0
		return

	goal_type = int(goal.get("type", GoalType.FIGHT))
	goal_node = goal.get("node") as Node2D
	goal_stick_left = rng.randf_range(GOAL_STICK_MIN, GOAL_STICK_MAX)

func _is_current_goal_valid() -> bool:
	match goal_type:
		GoalType.CHEST:
			return goal_node != null and goal_node.has_method("is_lootable") and bool(goal_node.call("is_lootable"))
		GoalType.SWITCH:
			return goal_node != null and goal_node.has_method("controls_disabled_gate") and bool(goal_node.call("controls_disabled_gate"))
		GoalType.RECOVER:
			return _score_recover_goal() > -INF
		_:
			return target != null

func _is_goal_reached() -> bool:
	if not _has_active_travel_goal() or goal_node == null or player == null:
		return false
	return _get_navigation_delta(player.global_position, goal_node.global_position).length() <= GOAL_REACHED_DISTANCE

func _has_active_travel_goal() -> bool:
	return (goal_type == GoalType.CHEST or goal_type == GoalType.SWITCH) and goal_node != null and _is_current_goal_valid()

func _has_navigation_focus() -> bool:
	return _has_raw_navigation_goal()

func _get_navigation_focus_position() -> Vector2:
	if not current_route_step.is_empty():
		return current_route_step.get("focus_position", player.global_position if player != null else Vector2.ZERO)
	return _get_raw_navigation_goal_position()

func _has_raw_navigation_goal() -> bool:
	if goal_type == GoalType.RECOVER:
		return target != null
	return _has_active_travel_goal() or target != null

func _get_raw_navigation_goal_position() -> Vector2:
	if goal_type == GoalType.RECOVER and target != null:
		return target.global_position
	if _has_active_travel_goal():
		return goal_node.global_position
	if target != null:
		return target.global_position
	return player.global_position if player != null else Vector2.ZERO

func _sort_route_points(a: Node2D, b: Node2D) -> bool:
	return a.name.naturalnocasecmp_to(b.name) < 0

func _update_route_step() -> void:
	current_route_path.clear()
	current_route_step.clear()

	if player == null or not _has_raw_navigation_goal():
		return

	var goal_position := _get_raw_navigation_goal_position()
	if not _should_use_route(goal_position):
		return

	var route_path := _find_route_path(goal_position)
	if route_path.is_empty():
		return

	current_route_path = route_path
	current_route_step = _build_route_step(route_path)

func _should_use_route(goal_position: Vector2) -> bool:
	if cached_route_points.is_empty() or player == null:
		return false
	if goal_type == GoalType.RECOVER:
		return false

	var goal_delta := _get_navigation_delta(player.global_position, goal_position)
	if goal_type == GoalType.FIGHT and goal_delta.length() <= ROUTE_USE_DISTANCE and absf(goal_delta.y) <= ROUTE_USE_VERTICAL_DISTANCE:
		return false

	return true

func _find_route_path(goal_position: Vector2) -> Array[Node2D]:
	if cached_route_points.size() < 2 or player == null:
		return []

	var start_candidates := _get_route_candidates(player.global_position, true)
	var end_candidates := _get_route_end_candidates(goal_position)
	var best_path: Array[Node2D] = []
	var best_cost: float = INF

	for start_variant in start_candidates:
		var start_point := start_variant.get("point") as Node2D
		if start_point == null:
			continue

		var search: Dictionary = _run_route_search(start_point)
		var distances: Dictionary = search.get("distances", {})
		var previous: Dictionary = search.get("previous", {})
		var entry_cost: float = float(start_variant.get("distance", INF))
		if entry_cost >= INF:
			continue

		for end_variant in end_candidates:
			var end_point := end_variant.get("point") as Node2D
			if end_point == null or not distances.has(end_point):
				continue

			var route_cost: float = float(distances.get(end_point, INF))
			var exit_cost: float = float(end_variant.get("distance", INF))
			if exit_cost >= INF:
				continue
			var total_cost: float = entry_cost + route_cost + exit_cost
			if total_cost >= best_cost:
				continue

			var candidate_path: Array[Node2D] = _reconstruct_route_path(previous, start_point, end_point)
			if candidate_path.is_empty():
				continue

			best_cost = total_cost
			best_path = candidate_path

	return best_path

func _get_route_end_candidates(goal_position: Vector2) -> Array[Dictionary]:
	var anchor_position: Vector2 = _get_route_goal_anchor_position(goal_position)
	var fight_same_floor_candidates := _get_route_candidates(anchor_position, true, goal_type == GoalType.FIGHT and target != null)
	if not fight_same_floor_candidates.is_empty():
		return fight_same_floor_candidates

	var direct_anchor_candidates := _get_route_candidates(anchor_position, true)
	if not direct_anchor_candidates.is_empty():
		return direct_anchor_candidates

	if anchor_position != goal_position:
		var direct_goal_candidates := _get_route_candidates(goal_position, true)
		if not direct_goal_candidates.is_empty():
			return direct_goal_candidates

	var anchor_candidates := _get_route_candidates(anchor_position, false)
	if not anchor_candidates.is_empty():
		return anchor_candidates

	if anchor_position != goal_position:
		var goal_candidates := _get_route_candidates(goal_position, false)
		if not goal_candidates.is_empty():
			return goal_candidates

	return []

func _get_route_goal_anchor_position(goal_position: Vector2) -> Vector2:
	if goal_type != GoalType.FIGHT or target == null:
		return goal_position

	var target_floor := _probe_floor_from_position(target.global_position)
	if target_floor.is_empty() or not bool(target_floor.get("walkable", false)):
		return goal_position
	return target_floor.get("point", goal_position)

func _get_route_candidates(origin: Vector2, require_direct_access: bool = false, require_same_floor: bool = false) -> Array[Dictionary]:
	var scored_points: Array[Dictionary] = []
	for point in cached_route_points:
		var candidate_distance := _get_navigation_delta(origin, point.global_position).length()
		if require_direct_access:
			candidate_distance = _estimate_direct_route_access_cost(origin, point.global_position, require_same_floor)
			if candidate_distance >= INF:
				continue

		scored_points.append({
			"point": point,
			"distance": candidate_distance,
		})

	scored_points.sort_custom(_sort_route_candidate_scores)
	if scored_points.size() > ROUTE_CANDIDATE_COUNT:
		scored_points.resize(ROUTE_CANDIDATE_COUNT)
	return scored_points

func _estimate_direct_route_access_cost(origin: Vector2, destination: Vector2, require_same_floor: bool = false) -> float:
	if player == null:
		return origin.distance_to(destination)

	var probe_destination := _get_route_direct_access_probe_position(origin, destination)
	var travel_delta := probe_destination - origin
	if travel_delta.length() <= ROUTE_POINT_REACHED_DISTANCE:
		return travel_delta.length()
	if absf(travel_delta.y) > ROUTE_DIRECT_ACCESS_VERTICAL_TOLERANCE:
		return INF

	var origin_floor := _probe_floor_from_position(origin)
	if origin_floor.is_empty() or not bool(origin_floor.get("walkable", false)):
		return _get_navigation_delta(origin, destination).length()

	var origin_floor_point: Vector2 = origin_floor.get("point", origin)
	if require_same_floor and probe_destination.y - origin_floor_point.y > ROUTE_DIRECT_ACCESS_SAMPLE_STEP:
		return INF
	var horizontal_distance := absf(travel_delta.x)
	if horizontal_distance <= ROUTE_DIRECT_ACCESS_SAMPLE_STEP * 0.5:
		return horizontal_distance + absf(probe_destination.y - origin_floor_point.y)

	var horizontal_sign: float = sign(travel_delta.x)
	var stop_distance: float = horizontal_distance
	if _is_route_probe_at_horizontal_edge(probe_destination):
		stop_distance = maxf(horizontal_distance - ROUTE_DIRECT_ACCESS_SAMPLE_STEP * 0.5, 0.0)

	var sampled_distance: float = ROUTE_DIRECT_ACCESS_SAMPLE_STEP
	var previous_floor_point: Vector2 = origin_floor_point
	while sampled_distance <= stop_distance:
		var sample_position := origin + Vector2(horizontal_sign * sampled_distance, 0.0)
		var sample_floor := _probe_floor_from_position(sample_position)
		if sample_floor.is_empty() or not bool(sample_floor.get("walkable", false)):
			return INF
		if bool(sample_floor.get("hazard", false)):
			return INF

		var sample_floor_point: Vector2 = sample_floor.get("point", sample_position)
		var rise := previous_floor_point.y - sample_floor_point.y
		var drop := sample_floor_point.y - previous_floor_point.y
		var max_allowed_drop := ROUTE_DIRECT_ACCESS_SAMPLE_STEP if require_same_floor else MAX_SAFE_STEP_DOWN
		if rise > MAX_JUMP_LANDING_RISE or drop > max_allowed_drop:
			return INF

		previous_floor_point = sample_floor_point
		sampled_distance += ROUTE_DIRECT_ACCESS_SAMPLE_STEP

	return horizontal_distance + absf(probe_destination.y - origin_floor_point.y)

func _get_route_direct_access_probe_position(origin: Vector2, destination: Vector2) -> Vector2:
	var probe_destination := origin + _get_navigation_delta(origin, destination)
	var viewport_size := player.get_viewport_rect().size if player != null else Vector2.ZERO
	if viewport_size.x > 0.0:
		probe_destination.x = clampf(probe_destination.x, 0.0, viewport_size.x)
	if viewport_size.y > 0.0:
		probe_destination.y = clampf(probe_destination.y, 0.0, viewport_size.y)
	return probe_destination

func _is_route_probe_at_horizontal_edge(position: Vector2) -> bool:
	var viewport_size := player.get_viewport_rect().size if player != null else Vector2.ZERO
	if viewport_size.x <= 0.0:
		return false
	return position.x <= ROUTE_DIRECT_ACCESS_EDGE_MARGIN or viewport_size.x - position.x <= ROUTE_DIRECT_ACCESS_EDGE_MARGIN

func _sort_route_candidate_scores(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("distance", INF)) < float(b.get("distance", INF))

func _run_route_search(start_point: Node2D) -> Dictionary:
	var frontier: Array[Node2D] = [start_point]
	var distances: Dictionary = {start_point: 0.0}
	var previous: Dictionary = {}

	while not frontier.is_empty():
		var best_index := 0
		var current_point: Node2D = frontier[0]
		var current_distance: float = float(distances.get(current_point, INF))
		for index in range(1, frontier.size()):
			var candidate_point: Node2D = frontier[index]
			var candidate_distance: float = float(distances.get(candidate_point, INF))
			if candidate_distance < current_distance:
				best_index = index
				current_point = candidate_point
				current_distance = candidate_distance

		frontier.remove_at(best_index)

		for link in current_point.get_route_links():
			if link == null or not link.is_available():
				continue

			var target_point := link.get_target_point() as Node2D
			if target_point == null:
				continue

			var link_cost: float = link.get_link_cost(current_point.global_position)
			var next_distance: float = current_distance + link_cost
			if next_distance >= float(distances.get(target_point, INF)):
				continue

			distances[target_point] = next_distance
			previous[target_point] = current_point
			if not frontier.has(target_point):
				frontier.append(target_point)

	return {
		"distances": distances,
		"previous": previous,
	}

func _reconstruct_route_path(previous: Dictionary, start_point: Node2D, end_point: Node2D) -> Array[Node2D]:
	var reversed_path: Array[Node2D] = [end_point]
	var cursor: Node2D = end_point

	while cursor != start_point:
		cursor = previous.get(cursor) as Node2D
		if cursor == null:
			return []
		reversed_path.append(cursor)

	reversed_path.reverse()
	return reversed_path

func _build_route_step(route_path: Array[Node2D]) -> Dictionary:
	if route_path.is_empty() or player == null:
		return {}

	var reached_index := -1
	for index in range(route_path.size()):
		var point: Node2D = route_path[index]
		var point_distance: float = _get_navigation_delta(player.global_position, point.global_position).length()
		if point_distance <= ROUTE_POINT_REACHED_DISTANCE:
			reached_index = index

	if reached_index < 0:
		return {
			"focus_position": route_path[0].global_position,
		}

	if reached_index >= route_path.size() - 1:
		return {}

	var source_point: Node2D = route_path[reached_index]
	var target_point: Node2D = route_path[reached_index + 1]
	var link = source_point.call("get_link_to", target_point)
	if link == null:
		return {
			"focus_position": target_point.global_position,
		}

	return {
		"focus_position": target_point.global_position,
		"source_point": source_point,
		"target_point": target_point,
		"link": link,
		"traversal_type": link.traversal_type,
		"activation_distance": link.activation_distance,
		"wall_contact_direction": link.wall_contact_direction,
		"helper_node": link.get_helper_node(),
	}

func _build_route_link_control_state() -> Dictionary:
	if current_route_step.is_empty():
		return {}

	var link = current_route_step.get("link")
	if link == null:
		return {}

	match int(current_route_step.get("traversal_type", AI_ROUTE_LINK_SCRIPT.TraversalType.WALK)):
		AI_ROUTE_LINK_SCRIPT.TraversalType.JUMP:
			return _build_jump_link_state()
		AI_ROUTE_LINK_SCRIPT.TraversalType.DROP:
			return _build_drop_link_state()
		AI_ROUTE_LINK_SCRIPT.TraversalType.WALL_JUMP:
			return _build_wall_jump_link_state()
		AI_ROUTE_LINK_SCRIPT.TraversalType.PAD:
			return _build_pad_link_state()
		AI_ROUTE_LINK_SCRIPT.TraversalType.GATE:
			return _build_gate_link_state()
		_:
			return {}

func _build_jump_link_state() -> Dictionary:
	var source_point := current_route_step.get("source_point") as Node2D
	var target_point := current_route_step.get("target_point") as Node2D
	if source_point == null or target_point == null:
		return {}

	var activation_distance: float = float(current_route_step.get("activation_distance", ROUTE_POINT_REACHED_DISTANCE))
	if player.is_on_floor():
		var source_distance: float = _get_navigation_delta(player.global_position, source_point.global_position).length()
		if source_distance > activation_distance:
			return _build_safe_move_state_toward(source_point.global_position)

	var target_delta := _get_navigation_delta(player.global_position, target_point.global_position)
	var horizontal := int(sign(target_delta.x))
	var direction := Vector2(float(horizontal), 0.0)
	var jump_pressed := player.is_on_floor()
	if not player.is_on_floor():
		direction = _to_digital_direction(target_delta)
		jump_pressed = false

	return _make_control_state(direction, false, jump_pressed, false)

func _build_drop_link_state() -> Dictionary:
	var source_point := current_route_step.get("source_point") as Node2D
	var target_point := current_route_step.get("target_point") as Node2D
	if source_point == null or target_point == null:
		return {}

	var activation_distance: float = float(current_route_step.get("activation_distance", ROUTE_POINT_REACHED_DISTANCE))
	if player.is_on_floor():
		var source_distance: float = _get_navigation_delta(player.global_position, source_point.global_position).length()
		if source_distance > activation_distance:
			return _build_safe_move_state_toward(source_point.global_position)

	var target_delta := _get_navigation_delta(player.global_position, target_point.global_position)
	var horizontal_sign := int(sign(target_delta.x))
	if player.is_on_floor():
		var drop_sign := _choose_drop_direction(target_point.global_position)
		if drop_sign != 0:
			horizontal_sign = drop_sign
	var direction := Vector2(float(horizontal_sign), 0.0)
	if not player.is_on_floor():
		direction = _to_digital_direction(target_delta)

	return _make_control_state(direction, false, false, false)

func _build_wall_jump_link_state() -> Dictionary:
	var source_point := current_route_step.get("source_point") as Node2D
	var target_point := current_route_step.get("target_point") as Node2D
	if source_point == null or target_point == null or player == null:
		return {}

	var activation_distance: float = float(current_route_step.get("activation_distance", ROUTE_POINT_REACHED_DISTANCE))
	var source_distance: float = _get_navigation_delta(player.global_position, source_point.global_position).length()
	if player.is_on_floor() and source_distance > activation_distance:
		return _build_safe_move_state_toward(source_point.global_position)

	var landing_delta := _get_navigation_delta(source_point.global_position, target_point.global_position)
	var landing_sign := int(sign(landing_delta.x))
	if landing_sign == 0:
		landing_sign = int(sign(_get_navigation_delta(player.global_position, target_point.global_position).x))
	if landing_sign == 0:
		landing_sign = 1
	var wall_sign := int(current_route_step.get("wall_contact_direction", 0))
	if wall_sign == 0:
		wall_sign = -landing_sign

	if player.is_on_wall_only() and not player.is_on_floor():
		return _make_control_state(Vector2(float(landing_sign), -1.0), false, true, false)

	if player.wall_slide_time_left > 0.0 and not player.is_on_floor():
		return _make_control_state(Vector2(float(landing_sign), -1.0), false, true, false)

	if player.is_on_floor():
		return _make_control_state(Vector2(float(wall_sign), -1.0), false, true, false)

	return _make_control_state(Vector2(float(wall_sign), 0.0), false, false, false)

func _build_pad_link_state() -> Dictionary:
	var source_point := current_route_step.get("source_point") as Node2D
	var target_point := current_route_step.get("target_point") as Node2D
	if source_point == null or target_point == null:
		return {}

	var helper_node := current_route_step.get("helper_node") as Node2D
	var helper_position: Vector2 = helper_node.global_position if helper_node != null else source_point.global_position
	var activation_distance: float = float(current_route_step.get("activation_distance", ROUTE_POINT_REACHED_DISTANCE))

	if player.is_on_floor():
		var source_distance: float = _get_navigation_delta(player.global_position, source_point.global_position).length()
		if source_distance > activation_distance:
			return _build_safe_move_state_toward(source_point.global_position)

		var helper_delta := _get_navigation_delta(player.global_position, helper_position)
		# The pad plate has a solid base — walk toward it and jump so the AI
		# lands on the top surface from above, entering the trigger area while
		# descending (not blocked by ignore_ascending_bodies).
		return _make_control_state(Vector2(float(int(sign(helper_delta.x))), 0.0), false, true, false)

	var target_delta := _get_navigation_delta(player.global_position, target_point.global_position)
	return _make_control_state(Vector2(float(int(sign(target_delta.x))), 0.0), false, false, false)

func _build_gate_link_state() -> Dictionary:
	var source_point := current_route_step.get("source_point") as Node2D
	if source_point == null:
		return {}

	var helper_node := current_route_step.get("helper_node") as Node2D
	var helper_position: Vector2 = helper_node.global_position if helper_node != null else source_point.global_position
	var activation_distance: float = float(current_route_step.get("activation_distance", ROUTE_POINT_REACHED_DISTANCE))
	var helper_distance: float = _get_navigation_delta(player.global_position, helper_position).length()
	if helper_distance > activation_distance:
		return _build_safe_move_state_toward(source_point.global_position)

	var helper_delta := _get_navigation_delta(player.global_position, helper_position)
	return _make_control_state(Vector2(float(int(sign(helper_delta.x))), 0.0), false, false, false)

func _build_safe_move_state_toward(target_position: Vector2) -> Dictionary:
	var base_direction := _to_digital_direction(_get_navigation_delta(player.global_position, target_position))
	var requested_jump := player.is_on_floor() and base_direction.y < 0.0
	var movement_plan := _apply_movement_safety(base_direction, requested_jump)
	return _make_control_state(
		movement_plan.get("direction", Vector2.ZERO),
		false,
		bool(movement_plan.get("jump_pressed", false)),
		false
	)

func _score_fight_goal() -> float:
	if player == null or target == null:
		return -INF

	var distance := _get_wrapped_delta(player.global_position, target.global_position).length()
	var ammo_ratio: float = clamp(float(player.get_total_arrow_count()) / float(Player.DEFAULT_ARROW_COUNT), 0.0, 1.0)
	var buff_strength: float = _get_player_buff_strength()
	var aggression: float = _get_aggression_level()
	var score: float = 1.0
	score += clamp((APPROACH_DISTANCE - distance) / APPROACH_DISTANCE, -0.15, 0.35)
	score += ammo_ratio * 0.25
	if player.get_total_arrow_count() == 0:
		score -= 0.55
	score += buff_strength * 0.35
	score += aggression * 0.2
	if player.health <= 1:
		score -= 0.3
	if not _is_combat_position_safe():
		score -= 0.2
	if goal_type == GoalType.FIGHT:
		score += 0.2
	return score

func _score_chest_goal(chest: Node2D) -> float:
	if player == null or chest == null or not chest.has_method("is_lootable") or not bool(chest.call("is_lootable")):
		return -INF

	var chest_distance: float = _get_navigation_delta(player.global_position, chest.global_position).length()
	var ammo_need: float = clamp((float(Player.DEFAULT_ARROW_COUNT) - float(player.get_total_arrow_count())) / float(Player.DEFAULT_ARROW_COUNT), 0.0, 1.0)
	var health_need: float = 1.0 if player.health <= 1 else 0.0
	var buff_strength: float = _get_player_buff_strength()
	var loot_saturation: float = _get_player_loot_saturation()
	var reward_type := int(chest.call("get_reward_type"))
	var reward_desire: float = _get_chest_reward_desire(reward_type, ammo_need, health_need, buff_strength)
	var score: float = 0.15 + ammo_need * 0.9 + health_need * 0.8 + reward_desire
	score -= chest_distance / 560.0
	score -= loot_saturation * CHEST_LOOT_SATURATION_PENALTY
	if target != null:
		var target_distance: float = _get_wrapped_delta(player.global_position, target.global_position).length()
		var separation_factor: float = clamp((target_distance - APPROACH_DISTANCE * 0.85) / APPROACH_DISTANCE, 0.0, 1.25)
		score -= separation_factor * loot_saturation * CHEST_DISTANCE_LOOT_PENALTY
		var contest_distance := _get_wrapped_delta(chest.global_position, target.global_position).length()
		# If the enemy is already at the chest, fight them instead of also going there.
		if contest_distance < 80.0:
			score -= 0.8
		# If the enemy is closer to the chest than we are, de-prioritize — let them have it
		# and attack them while they open it.
		elif contest_distance < chest_distance:
			score -= 0.4
	if goal_type == GoalType.CHEST and goal_node == chest:
		score += CHEST_GOAL_STICK_BONUS + ammo_need * 0.12 + health_need * 0.16
	return score if score >= 0.6 else -INF

func _get_chest_reward_desire(reward_type: int, ammo_need: float, health_need: float, buff_strength: float) -> float:
	match reward_type:
		ChestReward.ARROWS:
			return 0.35 + ammo_need * 1.5
		ChestReward.HEALTH:
			return 0.25 + health_need * 1.6
		ChestReward.EXTRA_DASH, ChestReward.ARMOR, ChestReward.SPEED:
			return 0.35 + (1.0 - buff_strength) * 0.45 + health_need * 0.15
		_:
			return 0.4 + (1.0 - buff_strength) * 0.55 + ammo_need * 0.2

func _score_switch_goal(switch_node: Node2D) -> float:
	if player == null or target == null or switch_node == null:
		return -INF
	if not switch_node.has_method("controls_disabled_gate") or not bool(switch_node.call("controls_disabled_gate")):
		return -INF

	var direct_distance: float = _get_wrapped_delta(player.global_position, target.global_position).length()
	var switch_distance: float = _get_navigation_delta(player.global_position, switch_node.global_position).length()
	var route_total: float = switch_distance + _estimate_switch_route_distance(switch_node, target.global_position)
	if route_total >= INF:
		return -INF

	var gain: float = direct_distance - route_total
	if gain < 80.0 and direct_distance < 360.0:
		return -INF

	var score: float = 0.75 + clamp(gain / 260.0, -0.1, 1.0)
	score -= switch_distance / 720.0
	if goal_type == GoalType.SWITCH and goal_node == switch_node:
		score += 0.4
	return score

func _estimate_switch_route_distance(switch_node: Node2D, target_position: Vector2) -> float:
	if not switch_node.has_method("get_controlled_gates"):
		return INF

	var gate_list_variant: Variant = switch_node.call("get_controlled_gates")
	if not (gate_list_variant is Array):
		return INF

	var best_distance := INF
	for gate_variant in gate_list_variant:
		var gate_node := gate_variant as Node2D
		if gate_node == null or not gate_node.has_method("get_target_gate"):
			continue
		var exit_gate := gate_node.call("get_target_gate") as Node2D
		if exit_gate == null:
			continue

		var route_distance: float = _get_wrapped_delta(exit_gate.global_position, target_position).length()
		best_distance = min(best_distance, route_distance)

	return best_distance

func _score_recover_goal() -> float:
	if player == null or target == null:
		return -INF

	var distance := _get_wrapped_delta(player.global_position, target.global_position).length()
	var score := 0.0
	if player.health <= 1:
		score += 0.9
	if not _is_combat_position_safe():
		score += 0.8
	if player.get_total_arrow_count() == 0:
		score += 0.55
	if distance < APPROACH_DISTANCE * 0.55:
		score += 0.35
	if goal_type == GoalType.RECOVER:
		score += 0.3
	return score if score >= 0.55 else -INF

func _get_player_buff_strength() -> float:
	if player == null:
		return 0.0

	var strength := 0.0
	if player.special_arrow_count > 0:
		strength += 0.2
	if player.triple_shot_charges > 0:
		strength += 0.3
	if player.rapid_fire_time_left > 0.0:
		strength += 0.3
	if player.extra_dash_time_left > 0.0:
		strength += 0.18
	if player.armor_hits > 0:
		strength += 0.22
	if player.speed_boost_time_left > 0.0:
		strength += 0.18
	return clamp(strength, 0.0, 1.0)

func _get_player_loot_saturation() -> float:
	if player == null:
		return 0.0

	var ammo_ratio: float = clamp(float(player.get_total_arrow_count()) / float(Player.DEFAULT_ARROW_COUNT), 0.0, 1.2)
	var health_buffer: float = 1.0 if player.health > 1 else 0.0
	var saturation := ammo_ratio * 0.55
	saturation += _get_player_buff_strength() * 0.9
	saturation += health_buffer * 0.15
	return clamp(saturation, 0.0, 1.35)

func _should_take_opportunistic_shot(aim_result: Dictionary) -> bool:
	if player == null or target == null:
		return false
	if not _can_commit_to_shot(aim_result):
		return false

	var distance := _get_wrapped_delta(player.global_position, target.global_position).length()
	var opportunistic_distance := lerpf(OPPORTUNISTIC_SHOT_DISTANCE * 0.72, OPPORTUNISTIC_SHOT_DISTANCE * 1.2, _get_aggression_level())
	return distance <= opportunistic_distance

func _can_commit_to_wrap_route(horizontal_sign: int, path_assessment: Dictionary) -> bool:
	if player == null or horizontal_sign == 0 or state != AIState.APPROACH:
		return false
	if goal_type == GoalType.RECOVER:
		return false
	if bool(path_assessment.get("hazard", false)):
		return false
	if not _has_navigation_focus():
		return false

	var navigation_delta := _get_wrapped_delta(player.global_position, _get_navigation_focus_position())
	var viewport_size := player.get_viewport_rect().size
	if viewport_size == Vector2.ZERO:
		return false

	var wants_horizontal_wrap := _is_near_horizontal_wrap_edge(horizontal_sign) and int(sign(navigation_delta.x)) == horizontal_sign and absf(navigation_delta.x) > viewport_size.x * 0.06
	var wants_vertical_wrap_drop := player.global_position.y > viewport_size.y * 0.55 and navigation_delta.y < -viewport_size.y * WRAP_ROUTE_VERTICAL_PROGRESS
	return wants_horizontal_wrap or wants_vertical_wrap_drop

func _is_near_horizontal_wrap_edge(horizontal_sign: int) -> bool:
	if player == null:
		return false

	var viewport_size := player.get_viewport_rect().size
	if horizontal_sign > 0:
		return viewport_size.x - player.global_position.x <= WRAP_ROUTE_EDGE_MARGIN
	if horizontal_sign < 0:
		return player.global_position.x <= WRAP_ROUTE_EDGE_MARGIN
	return false

func _get_best_aim_result() -> Dictionary:
	if player == null or target == null or not player.has_available_ammo():
		return {}

	var target_delta := _get_wrapped_delta(player.global_position, target.global_position)
	var horizontal_sign := 1
	if target_delta.x < -4.0:
		horizontal_sign = -1

	var candidates := _get_aim_candidates(horizontal_sign)
	var best_result: Dictionary = {}
	var best_blocked_result: Dictionary = {}
	var best_miss := INF
	var error_offset := aim_error_offset if state == AIState.AIM else _get_aim_error_offset()

	for candidate in candidates:
		if not player.can_shoot(candidate):
			continue
		var evaluation := _simulate_player_shot(candidate, error_offset)
		if evaluation.is_empty():
			continue
		if bool(evaluation.get("blocked", false)):
			if best_blocked_result.is_empty():
				best_blocked_result = evaluation
			continue
		var miss := float(evaluation.get("miss", INF))
		if miss < best_miss:
			best_miss = miss
			best_result = evaluation

	if best_result.is_empty():
		return best_blocked_result

	var required_miss := _get_required_shot_miss(best_result)
	best_result["required_miss"] = required_miss
	best_result["quality"] = 1.0 - min(best_miss / max(required_miss, 1.0), 2.0)
	best_result["viable"] = best_miss <= required_miss
	if not bool(best_result.get("viable", false)) and not best_blocked_result.is_empty():
		return best_blocked_result
	return best_result

func _get_simulated_projectile_collision(segment_start: Vector2, segment_end: Vector2) -> Dictionary:
	return _raycast_bodies_only(segment_start, segment_end, [player])

func _simulate_player_shot(direction: Vector2, error_offset: Vector2) -> Dictionary:
	var arrow_type: int = player.get_loaded_arrow_type()
	var launch_speed: float = Arrow.get_speed_for_type(_get_base_arrow_speed(), arrow_type)
	var gravity_force: float = float(ProjectSettings.get_setting("physics/2d/default_gravity")) * Arrow.get_gravity_scale_for_type(arrow_type)
	var projectile_direction: Vector2 = direction.normalized()
	var projectile_offset: Vector2 = Vector2.ZERO
	var shot_origin: Vector2 = player.get_arrow_spawn_position(direction)
	var target_offset: Vector2 = _get_wrapped_delta(shot_origin, target.global_position) + error_offset
	var lead_scale: float = lerpf(0.35, 0.95, difficulty)
	var best_miss: float = INF
	var best_time := 0.0

	for step in range(int(AIM_SIMULATION_TIME / AIM_SIMULATION_STEP)):
		var time := float(step + 1) * AIM_SIMULATION_STEP

		# Match Arrow._physics_process exactly: gravity bends the arrow's direction vector a bit
		# every step, then movement uses that re-normalized direction at a constant launch speed.
		var previous_offset: Vector2 = projectile_offset
		projectile_direction.y += gravity_force * AIM_SIMULATION_STEP
		projectile_offset += projectile_direction.normalized() * launch_speed * AIM_SIMULATION_STEP
		var segment_start := shot_origin + previous_offset
		var segment_end := shot_origin + projectile_offset
		var collision := _get_simulated_projectile_collision(segment_start, segment_end)
		if not collision.is_empty():
			var collider: Object = collision.get("collider")
			if _is_target_owned_collider(collider, target):
				return {
					"direction": direction,
					"miss": 0.0,
					"time": time,
					"blocked": false,
				}
			return {
				"direction": direction,
				"miss": INF,
				"time": time,
				"blocked": true,
				"block_reason": "trajectory blocked by wall",
			}

		# The target lead uses its current velocity as a simple short-horizon prediction.
		var predicted_target_offset := target_offset + target.velocity * time * lead_scale
		var miss_distance := projectile_offset.distance_to(predicted_target_offset)
		if miss_distance < best_miss:
			best_miss = miss_distance
			best_time = time

	return {
		"direction": direction,
		"miss": best_miss,
		"time": best_time,
	}

func _find_incoming_arrow() -> Dictionary:
	var scene := get_tree().current_scene
	if scene == null or player == null:
		return {}

	var best_threat: Dictionary = {}
	var best_time := INF
	for node in scene.find_children("*", "", true, false):
		var arrow := node as Arrow
		if arrow == null or not arrow.active or arrow.get_shooter() == player:
			continue

		var threat := _simulate_incoming_arrow(arrow)
		if threat.is_empty():
			continue

		var threat_time := float(threat.get("time", INF))
		if threat_time < best_time:
			best_time = threat_time
			best_threat = threat

	return best_threat

func _simulate_incoming_arrow(arrow: Arrow) -> Dictionary:
	var target_offset: Vector2 = _get_wrapped_delta(arrow.global_position, player.global_position)
	if target_offset.length() > 420.0:
		return {}

	var simulated_direction: Vector2 = arrow.direction
	if simulated_direction == Vector2.ZERO:
		return {}

	var arrow_heading: Vector2 = simulated_direction.normalized()
	if arrow_heading.dot(target_offset.normalized()) < 0.1:
		return {}

	var launch_speed: float = Arrow.get_speed_for_type(arrow.speed, arrow.arrow_type)
	var gravity_force: float = arrow.gravity * Arrow.get_gravity_scale_for_type(arrow.arrow_type)
	var projectile_offset: Vector2 = Vector2.ZERO
	var best_miss: float = INF
	var best_time := 0.0

	for step in range(int(DODGE_SIMULATION_TIME / AIM_SIMULATION_STEP)):
		var time := float(step + 1) * AIM_SIMULATION_STEP
		simulated_direction.y += gravity_force * AIM_SIMULATION_STEP
		projectile_offset += simulated_direction.normalized() * launch_speed * AIM_SIMULATION_STEP
		var predicted_player_offset := target_offset + player.velocity * time * 0.25
		var miss_distance := projectile_offset.distance_to(predicted_player_offset)
		if miss_distance < best_miss:
			best_miss = miss_distance
			best_time = time

	if best_miss > DODGE_THREAT_RADIUS:
		return {}

	return {
		"arrow": arrow,
		"time": best_time,
		"miss": best_miss,
	}

func _choose_dodge_direction(threat: Dictionary) -> Vector2:
	var arrow := threat.get("arrow") as Arrow
	if arrow == null:
		return Vector2.ZERO

	var arrow_direction := arrow.direction.normalized()
	var away := -arrow_direction
	if player.is_on_floor():
		if absf(arrow_direction.x) >= absf(arrow_direction.y):
			return _to_digital_direction(Vector2(away.x, -1.0))
		return _to_digital_direction(Vector2(sign(away.x), 0.0))

	var perpendicular := Vector2(-arrow_direction.y, arrow_direction.x)
	var toward_target := _get_wrapped_delta(player.global_position, target.global_position) if target != null else Vector2.RIGHT
	if perpendicular.dot(toward_target) < 0.0:
		perpendicular *= -1.0
	return _to_digital_direction(perpendicular)

func _find_target() -> Player:
	if player == null:
		return null

	var best_target: Player
	var best_distance := INF
	for node in get_tree().get_nodes_in_group("player"):
		var candidate := node as Player
		if candidate == null or candidate == player or candidate.is_dying:
			continue

		var distance := _get_wrapped_delta(player.global_position, candidate.global_position).length()
		if distance < best_distance:
			best_distance = distance
			best_target = candidate

	return best_target

func _get_aim_candidates(horizontal_sign: int) -> Array[Vector2]:
	var candidates: Array[Vector2] = [
		Vector2(float(horizontal_sign), 0.0),
		Vector2(AIM_UP_DIAG.x * horizontal_sign, AIM_UP_DIAG.y),
		AIM_UP,
	]

	if not player.is_on_floor():
		candidates.append(Vector2(AIM_DOWN_DIAG.x * horizontal_sign, AIM_DOWN_DIAG.y))
		candidates.append(AIM_DOWN)

	return candidates

func _get_base_arrow_speed() -> float:
	if has_cached_base_arrow_speed:
		return cached_base_arrow_speed

	has_cached_base_arrow_speed = true
	if player == null or player.arrow == null:
		return cached_base_arrow_speed

	var arrow_probe := player.arrow.instantiate() as Arrow
	if arrow_probe == null:
		return cached_base_arrow_speed

	cached_base_arrow_speed = arrow_probe.speed
	arrow_probe.free()
	return cached_base_arrow_speed

func _get_aim_error_offset() -> Vector2:
	var error_radius := lerpf(90.0, 8.0, difficulty)
	return Vector2(
		rng.randf_range(-error_radius, error_radius),
		rng.randf_range(-error_radius, error_radius)
	)

func _get_aim_hold_time() -> float:
	var aggression := _get_aggression_level()
	return rng.randf_range(lerpf(0.38, 0.14, aggression), lerpf(0.66, 0.24, aggression))

func _get_reaction_time() -> float:
	return rng.randf_range(lerpf(0.24, 0.06, difficulty), lerpf(0.38, 0.14, difficulty))

func _get_dodge_duration_range() -> Vector2:
	return Vector2(lerpf(0.16, 0.1, difficulty), lerpf(0.28, 0.18, difficulty))

func _get_post_shot_retreat_time() -> float:
	var aggression := _get_aggression_level()
	return rng.randf_range(lerpf(0.32, 0.08, aggression), lerpf(0.54, 0.18, aggression))

func _get_spacing_retreat_time() -> float:
	# Wider range than post-shot retreat so mirrored AI pairs drift out of phase.
	return rng.randf_range(0.2, 0.8)

func _get_aggression_level() -> float:
	if player == null:
		return clamp(difficulty, 0.0, 1.0)

	var aggression := lerpf(0.25, 0.95, difficulty)
	aggression += _get_player_buff_strength() * 0.18
	if player.health <= 1:
		aggression -= 0.22
	if not player.has_available_ammo():
		aggression -= 0.4
	if goal_type == GoalType.RECOVER:
		aggression -= 0.25
	return clamp(aggression, 0.0, 1.0)

func _get_desired_approach_distance() -> float:
	return lerpf(APPROACH_DISTANCE * 0.78, APPROACH_DISTANCE * 1.15, _get_aggression_level())

func _get_desired_retreat_distance() -> float:
	return lerpf(RETREAT_DISTANCE * 1.2, RETREAT_DISTANCE * 0.82, _get_aggression_level())

func _get_required_shot_miss(aim_result: Dictionary) -> float:
	if player == null or target == null:
		return AIM_ACCEPTABLE_MISS

	var target_delta := _get_wrapped_delta(player.global_position, target.global_position)
	var distance := target_delta.length()
	var threshold := lerpf(38.0, 22.0, difficulty)
	if distance > APPROACH_DISTANCE:
		threshold *= 0.82
	elif distance < RETREAT_DISTANCE:
		threshold *= 0.92
	if target.velocity.length() > 220.0:
		threshold *= 0.86
	if not player.is_on_floor():
		threshold *= 0.72
	if absf(target_delta.y) > 132.0:
		threshold *= 0.9
	var shot_direction: Vector2 = aim_result.get("direction", Vector2.ZERO)
	if shot_direction.y > 0.0:
		threshold *= 0.9
	return clamp(threshold, 14.0, AIM_ACCEPTABLE_MISS * 1.15)

func _can_commit_to_shot(aim_result: Dictionary) -> bool:
	return bool(_get_shot_decision(aim_result).get("allowed", false))

func _has_stable_shot_footing(aim_result: Dictionary) -> bool:
	return bool(_get_shot_footing_decision(aim_result).get("allowed", false))

func _is_point_blank_self_trap() -> bool:
	return not bool(_get_escape_space_decision().get("allowed", true))

func _get_preferred_close_combat_state(target_delta: Vector2, distance: float) -> int:
	var retreat_sign := _choose_combat_horizontal_sign(target_delta, true)
	var retreat_score := _get_horizontal_space_score(retreat_sign, false) if retreat_sign != 0 else BAD_SPACE_SCORE - 0.1
	var aggression := _get_aggression_level()
	if retreat_sign == 0 and distance < _get_desired_retreat_distance():
		return AIState.APPROACH
	if retreat_score <= BAD_SPACE_SCORE and aggression >= 0.42:
		return AIState.APPROACH
	return AIState.RETREAT

func _choose_combat_horizontal_sign(target_delta: Vector2, prefer_away: bool) -> int:
	var desired_sign := int(sign(target_delta.x))
	var best_sign := 0
	var best_score := -INF

	for candidate_sign in [-1, 0, 1]:
		var score := 0.0
		if candidate_sign == 0:
			score = 0.12 if absf(target_delta.x) <= 18.0 else -0.28
		else:
			score += _get_horizontal_space_score(candidate_sign, false)
			if desired_sign != 0:
				if prefer_away:
					score += 0.65 if candidate_sign == -desired_sign else -0.35
				else:
					score += 0.62 if candidate_sign == desired_sign else -0.22
			else:
				score += 0.18 if candidate_sign == -player.facing_sign else 0.0

		if score > best_score:
			best_score = score
			best_sign = candidate_sign

	return best_sign

func _get_horizontal_space_score(horizontal_sign: int, allow_wrap: bool) -> float:
	if player == null or horizontal_sign == 0:
		return 0.0

	var score := 0.0
	var current_floor := _get_current_floor_info(horizontal_sign)
	var path_assessment := _assess_forward_path(horizontal_sign)
	if bool(path_assessment.get("blocked", false)):
		if bool(path_assessment.get("hazard", false)):
			score -= 2.0
		elif bool(path_assessment.get("jumpable", false)):
			score -= 0.22
		elif allow_wrap and _can_commit_to_wrap_route(horizontal_sign, path_assessment):
			score -= 0.08
		else:
			score -= 1.0

	if not current_floor.is_empty() and bool(current_floor.get("walkable", false)):
		var future_floor := _probe_floor(float(horizontal_sign) * COMBAT_SPACE_SAMPLE_DISTANCE)
		var current_floor_point: Vector2 = current_floor.get("point", player.global_position)
		if future_floor.is_empty():
			score -= 0.65
		elif bool(future_floor.get("hazard", false)):
			score -= 1.35
		elif bool(future_floor.get("walkable", false)):
			var future_floor_point: Vector2 = future_floor.get("point", current_floor_point)
			if future_floor_point.y - current_floor_point.y > MAX_JUMP_LANDING_DROP * 0.5:
				score -= 0.5

	var viewport_size := player.get_viewport_rect().size
	if viewport_size.x > 0.0:
		var future_x := wrapf(player.global_position.x + float(horizontal_sign) * COMBAT_SPACE_SAMPLE_DISTANCE, 0.0, viewport_size.x)
		var center_offset: float = absf(future_x - viewport_size.x * 0.5) / max(viewport_size.x * 0.5, 1.0)
		score += (1.0 - center_offset) * 0.45
		if _is_near_horizontal_wrap_edge(horizontal_sign):
			score -= 0.35

	return score

func _get_stomp_window() -> Dictionary:
	if player == null or target == null:
		return {}

	var target_delta := _get_wrapped_delta(player.global_position, target.global_position)
	if target_delta.y < STOMP_VERTICAL_MIN or target_delta.y > STOMP_VERTICAL_MAX:
		return {}
	if player.is_on_floor() and target_delta.y < 46.0:
		return {}

	var predicted_delta := target_delta + target.velocity * STOMP_ALIGNMENT_LOOKAHEAD
	if absf(predicted_delta.x) > STOMP_HORIZONTAL_RANGE:
		return {}
	if not _is_clear_path_to_target(target):
		return {}

	var score := 0.55
	score += clamp((STOMP_HORIZONTAL_RANGE - absf(predicted_delta.x)) / STOMP_HORIZONTAL_RANGE, 0.0, 1.0) * 0.25
	if not player.is_on_floor():
		score += 0.18
	if target.is_on_floor():
		score += 0.08

	return {
		"available": true,
		"delta": predicted_delta,
		"score": score,
	}

func _get_stomp_threat() -> Dictionary:
	if player == null or target == null:
		return {}

	var target_delta := _get_wrapped_delta(player.global_position, target.global_position)
	if target_delta.y > -24.0 or target_delta.y < -STOMP_THREAT_VERTICAL_RANGE:
		return {}
	if target.is_on_floor():
		return {}

	var predicted_delta := target_delta + target.velocity * STOMP_ALIGNMENT_LOOKAHEAD
	if absf(predicted_delta.x) > STOMP_THREAT_HORIZONTAL_RANGE:
		return {}

	var score := 0.45
	score += clamp((STOMP_THREAT_HORIZONTAL_RANGE - absf(predicted_delta.x)) / STOMP_THREAT_HORIZONTAL_RANGE, 0.0, 1.0) * 0.25
	if target.velocity.y > 0.0:
		score += 0.2
	if player.is_on_floor():
		score += 0.08

	return {
		"urgent": score >= 0.72,
		"score": score,
	}

func _should_prioritize_stomp(stomp_window: Dictionary, aim_result: Dictionary) -> bool:
	return bool(_get_stomp_priority_decision(stomp_window, aim_result).get("allowed", false))

func _get_shot_decision(aim_result: Dictionary) -> Dictionary:
	if player == null or target == null:
		return {"allowed": false, "reason": "no target"}
	if aim_result.is_empty():
		return {"allowed": false, "reason": "no aim solution"}
	if bool(aim_result.get("blocked", false)):
		return {"allowed": false, "reason": str(aim_result.get("block_reason", "trajectory blocked"))}

	var miss: float = float(aim_result.get("miss", INF))
	var required_miss: float = float(aim_result.get("required_miss", AIM_ACCEPTABLE_MISS))
	if not bool(aim_result.get("viable", false)):
		return {"allowed": false, "reason": "miss %.0f > %.0f" % [miss, required_miss]}

	if bool(_get_stomp_threat().get("urgent", false)):
		return {"allowed": false, "reason": "enemy overhead stomp threat"}

	var footing := _get_shot_footing_decision(aim_result)
	if not bool(footing.get("allowed", false)):
		return footing

	var escape := _get_escape_space_decision()
	if not bool(escape.get("allowed", false)):
		return escape

	return {"allowed": true, "reason": "commit shot"}

func _get_shot_footing_decision(aim_result: Dictionary) -> Dictionary:
	if player == null or target == null:
		return {"allowed": false, "reason": "no footing context"}

	if player.is_on_floor():
		if not _is_combat_position_safe():
			return {"allowed": false, "reason": "unsafe edge or hazard"}
		var target_delta := _get_wrapped_delta(player.global_position, target.global_position)
		var target_sign := int(sign(target_delta.x))
		if target_sign != 0 and _get_horizontal_space_score(target_sign, false) <= BAD_SPACE_SCORE:
			return {"allowed": false, "reason": "bad firing lane"}
		return {"allowed": true, "reason": "stable floor shot"}

	if difficulty < 0.72:
		return {"allowed": false, "reason": "low diff avoids air shots"}
	if absf(player.velocity.y) > STABLE_AIR_SHOT_SPEED:
		return {"allowed": false, "reason": "falling too fast"}

	var distance := _get_wrapped_delta(player.global_position, target.global_position).length()
	if distance > APPROACH_DISTANCE * 0.72:
		return {"allowed": false, "reason": "air shot too far"}

	var miss := float(aim_result.get("miss", INF))
	var required_miss := float(aim_result.get("required_miss", AIM_ACCEPTABLE_MISS))
	if miss > required_miss * 0.72:
		return {"allowed": false, "reason": "air shot too loose"}
	return {"allowed": true, "reason": "stable air shot"}

func _get_escape_space_decision() -> Dictionary:
	if player == null or target == null:
		return {"allowed": true, "reason": "no escape check"}

	var target_delta := _get_wrapped_delta(player.global_position, target.global_position)
	if target_delta.length() > RETREAT_DISTANCE * 0.72:
		return {"allowed": true, "reason": "enough spacing"}

	var retreat_sign := _choose_combat_horizontal_sign(target_delta, true)
	if retreat_sign == 0:
		return {"allowed": false, "reason": "no escape lane"}
	if _get_horizontal_space_score(retreat_sign, false) <= BAD_SPACE_SCORE:
		return {"allowed": false, "reason": "retreat lane trapped"}
	return {"allowed": true, "reason": "escape lane open"}

func _get_stomp_priority_decision(stomp_window: Dictionary, aim_result: Dictionary) -> Dictionary:
	if player == null or target == null:
		return {"allowed": false, "reason": "no target"}
	if not bool(stomp_window.get("available", false)):
		return {"allowed": false, "reason": "no stomp window"}
	if goal_type != GoalType.FIGHT and not current_route_step.is_empty():
		return {"allowed": false, "reason": "stay on route"}

	var stomp_score := float(stomp_window.get("score", 0.0))
	if player.health <= 1:
		stomp_score -= 0.12

	var shot_decision := _get_shot_decision(aim_result)
	if not bool(shot_decision.get("allowed", false)):
		if stomp_score >= 0.48:
			return {"allowed": true, "reason": "stomp %.2f beats %s" % [stomp_score, str(shot_decision.get("reason", "no shot"))]}
		return {"allowed": false, "reason": "stomp window too weak"}

	var shot_quality: float = clamp(float(aim_result.get("quality", 0.0)), -1.0, 1.0)
	if stomp_score > shot_quality + 0.16:
		return {"allowed": true, "reason": "stomp %.2f > shot %.2f" % [stomp_score, shot_quality]}
	return {"allowed": false, "reason": "shot %.2f cleaner than stomp %.2f" % [shot_quality, stomp_score]}

func _is_clear_path_to_target(target_player: Player) -> bool:
	if player == null or target_player == null:
		return false

	var hit := _raycast(player.global_position, target_player.global_position, [player])
	if hit.is_empty():
		return true

	var collider: Object = hit.get("collider")
	return _is_target_owned_collider(collider, target_player)

func _is_target_owned_collider(collider: Object, target_player: Player) -> bool:
	var node := collider as Node
	while node != null:
		if node == target_player:
			return true
		node = node.get_parent()
	return false

func _update_debug_snapshot(aim_result: Dictionary, control_state: Dictionary) -> void:
	if player == null:
		debug_snapshot = {"enabled": false}
		return

	var movement_direction: Vector2 = control_state.get("direction", Vector2.ZERO)
	var probe_sign := 0
	if absf(movement_direction.x) > 0.0:
		probe_sign = int(sign(movement_direction.x))
	elif _has_navigation_focus():
		probe_sign = int(sign(_get_wrapped_delta(player.global_position, _get_navigation_focus_position()).x))

	var path_assessment: Dictionary = {}
	if probe_sign != 0:
		path_assessment = _assess_forward_path(probe_sign)

	var landing_point := Vector2.ZERO
	var landing_available := false
	var landing: Variant = path_assessment.get("landing", {})
	if landing is Dictionary and not landing.is_empty():
		landing_point = landing.get("point", Vector2.ZERO)
		landing_available = true

	var shot_decision := _get_shot_decision(aim_result)
	var stomp_window := _get_stomp_window()
	var stomp_threat := _get_stomp_threat()
	var stomp_decision := _get_stomp_priority_decision(stomp_window, aim_result)

	debug_snapshot = {
		"enabled": enabled,
		"difficulty": difficulty,
		"state": _get_state_name(state),
		"goal": _get_goal_name(goal_type),
		"goal_node": goal_node.name if goal_node != null else "-",
		"target": target.name if target != null else "-",
		"target_distance": _get_wrapped_delta(player.global_position, target.global_position).length() if target != null else -1.0,
		"probe_sign": probe_sign,
		"probe_blocked": bool(path_assessment.get("blocked", false)),
		"probe_hazard": bool(path_assessment.get("hazard", false)),
		"probe_jumpable": bool(path_assessment.get("jumpable", false)),
		"probe_reason": str(path_assessment.get("reason", "clear")),
		"landing_available": landing_available,
		"landing_point": landing_point,
		"route": _get_route_debug_summary(),
		"shot_allowed": bool(shot_decision.get("allowed", false)),
		"shot_reason": str(shot_decision.get("reason", "")),
		"shot_quality": float(aim_result.get("quality", -1.0)),
		"stomp_available": bool(stomp_window.get("available", false)),
		"stomp_allowed": bool(stomp_decision.get("allowed", false)),
		"stomp_reason": str(stomp_decision.get("reason", "")),
		"stomp_threat": bool(stomp_threat.get("urgent", false)),
		"stuck_time_left": stuck_time_left,
		"state_hold_left": snappedf(state_hold_left, 0.01),
		"aim_commit_left": snappedf(aim_commit_left, 0.01),
		"escape_dir": _escape_dir,
		"dodge_active": state == AIState.DODGE and dodge_time_left > 0.0,
		"dodge_pending": pending_threat_id != 0,
		"pending_threat_id": pending_threat_id,
		"control_direction": movement_direction,
		"jump_pressed": bool(control_state.get("jump_pressed", false)),
		"use_pressed": bool(control_state.get("use_pressed", false)),
		"dash_pressed": bool(control_state.get("dash_pressed", false)),
		"session_shots_fired": _session_shots_fired,
		"session_dodges_entered": _session_dodges_entered,
		"session_stuck_total": snappedf(_session_stuck_total, 0.1),
		"action_history_names": action_history.map(func(s: int) -> String: return _get_state_name(s)),
	}

func _get_route_debug_summary() -> Dictionary:
	if current_route_step.is_empty():
		return {
			"active": false,
			"label": "-",
		}

	var source_point := current_route_step.get("source_point") as Node2D
	var target_point := current_route_step.get("target_point") as Node2D
	var traversal_type := int(current_route_step.get("traversal_type", AI_ROUTE_LINK_SCRIPT.TraversalType.WALK))
	var label := _get_traversal_name(traversal_type)
	if source_point != null and target_point != null:
		label = "%s %s -> %s" % [label, source_point.name, target_point.name]

	return {
		"active": true,
		"label": label,
		"traversal": _get_traversal_name(traversal_type),
		"source": source_point.name if source_point != null else "-",
		"target": target_point.name if target_point != null else "-",
		"focus_position": current_route_step.get("focus_position", Vector2.ZERO),
	}

func _configure_rng() -> void:
	var match_settings = get_node_or_null("/root/MatchSettings")
	if match_settings != null and match_settings.has_method("build_rng"):
		var player_name := player.name if player != null else name
		rng = match_settings.call("build_rng", "ai:%s" % player_name)
	else:
		rng.randomize()

func _get_state_name(ai_state: int) -> String:
	match ai_state:
		AIState.IDLE:
			return "idle"
		AIState.APPROACH:
			return "approach"
		AIState.AIM:
			return "aim"
		AIState.SHOOT:
			return "shoot"
		AIState.DODGE:
			return "dodge"
		AIState.RETREAT:
			return "retreat"
		_:
			return "unknown"

func _get_goal_name(ai_goal: int) -> String:
	match ai_goal:
		GoalType.FIGHT:
			return "fight"
		GoalType.CHEST:
			return "chest"
		GoalType.SWITCH:
			return "switch"
		GoalType.RECOVER:
			return "recover"
		_:
			return "unknown"

func _get_traversal_name(traversal_type: int) -> String:
	match traversal_type:
		AI_ROUTE_LINK_SCRIPT.TraversalType.WALK:
			return "walk"
		AI_ROUTE_LINK_SCRIPT.TraversalType.JUMP:
			return "jump"
		AI_ROUTE_LINK_SCRIPT.TraversalType.DROP:
			return "drop"
		AI_ROUTE_LINK_SCRIPT.TraversalType.WALL_JUMP:
			return "wall_jump"
		AI_ROUTE_LINK_SCRIPT.TraversalType.PAD:
			return "pad"
		AI_ROUTE_LINK_SCRIPT.TraversalType.GATE:
			return "gate"
		_:
			return "unknown"

func _get_wrapped_delta(origin: Vector2, destination: Vector2) -> Vector2:
	var delta := destination - origin
	var viewport_size := player.get_viewport_rect().size if player != null else Vector2.ZERO

	if viewport_size.x > 0.0 and absf(delta.x) > viewport_size.x * 0.5:
		delta.x -= sign(delta.x) * viewport_size.x
	if viewport_size.y > 0.0 and absf(delta.y) > viewport_size.y * 0.5:
		delta.y -= sign(delta.y) * viewport_size.y

	return delta

func _get_navigation_delta(origin: Vector2, destination: Vector2) -> Vector2:
	var delta := _get_wrapped_delta(origin, destination)
	delta.y = destination.y - origin.y
	return delta

func _to_digital_direction(direction: Vector2) -> Vector2:
	if direction == Vector2.ZERO:
		return Vector2.ZERO

	var digital := Vector2.ZERO
	if direction.x > 0.2:
		digital.x = 1.0
	elif direction.x < -0.2:
		digital.x = -1.0

	if direction.y > 0.2:
		digital.y = 1.0
	elif direction.y < -0.2:
		digital.y = -1.0

	if digital == Vector2.ZERO:
		return Vector2.ZERO
	return digital.normalized()
