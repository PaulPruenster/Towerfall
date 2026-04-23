class_name AIMatchTelemetry
extends Node


const DEFAULT_SNAPSHOT_INTERVAL: float = 0.2
const LOW_QUALITY_SHOT_THRESHOLD: float = 0.35
const DODGE_SUCCESS_WINDOW: float = 0.9
const ROUTE_SUCCESS_DISTANCE: float = 56.0
const PLATFORM_SUCCESS_TIME: float = 0.2
const MOVING_PLATFORM_SCRIPT_PATH := "res://scripts/gameplay/moving_platform.gd"

var run_config: Dictionary = {}
var world: Node2D
var tracked_players: Array[Player] = []
var player_records: Dictionary = {}
var timeline: Array[Dictionary] = []
var run_time_seconds: float = 0.0
var sample_accumulator: float = 0.0
var snapshot_interval: float = DEFAULT_SNAPSHOT_INTERVAL
var viewport_size: Vector2 = Vector2.ZERO
var match_started: bool = false
var match_finished: bool = false
var final_result: Dictionary = {}
var run_report: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_physics_process(true)

func configure(config: Dictionary) -> void:
	run_config = config.duplicate(true)
	snapshot_interval = max(float(run_config.get("snapshot_interval", DEFAULT_SNAPSHOT_INTERVAL)), 0.05)

func bind_world(new_world: Node) -> void:
	world = new_world as Node2D
	if world == null:
		return

	var setup_callable := Callable(self, "_on_match_setup_complete")
	if world.has_signal("match_setup_complete") and not world.is_connected("match_setup_complete", setup_callable):
		world.connect("match_setup_complete", setup_callable)

	var resolved_callable := Callable(self, "_on_match_resolved")
	if world.has_signal("match_resolved") and not world.is_connected("match_resolved", resolved_callable):
		world.connect("match_resolved", resolved_callable)

func is_finished() -> bool:
	return match_finished

func get_elapsed_seconds() -> float:
	return run_time_seconds

func mark_timeout() -> void:
	if match_finished:
		return

	if sample_accumulator > 0.0:
		var sample_delta := sample_accumulator
		sample_accumulator = 0.0
		_sample_players(sample_delta)
	_resolve_dodge_windows(true)

	final_result = {
		"winner_name": "",
		"winner_slot": -1,
		"winner_role": "",
		"winner_id": "",
		"draw": true,
		"timeout": true,
		"remaining_players": _serialize_alive_players(),
	}
	match_finished = true
	_record_event("match_timeout", {})
	run_report = _build_run_report()

func get_run_report() -> Dictionary:
	if run_report.is_empty():
		run_report = _build_run_report()
	return run_report.duplicate(true)

func _physics_process(delta: float) -> void:
	if not match_started or match_finished:
		return

	run_time_seconds += delta
	sample_accumulator += delta
	_resolve_dodge_windows(false)

	if sample_accumulator < snapshot_interval:
		return

	var sample_delta := sample_accumulator
	sample_accumulator = 0.0
	_sample_players(sample_delta)

func _on_match_setup_complete(players: Array) -> void:
	match_started = true
	match_finished = false
	final_result.clear()
	run_report.clear()
	timeline.clear()
	player_records.clear()
	tracked_players.clear()
	run_time_seconds = 0.0
	sample_accumulator = 0.0
	viewport_size = world.get_viewport_rect().size if world != null else Vector2.ZERO

	for player_variant in players:
		var player := player_variant as Player
		if player == null:
			continue
		tracked_players.append(player)
		_register_player(player)

	_connect_world_events()
	_record_event("match_started", {"players": _serialize_alive_players()})
	_sample_players(0.0)

func _on_match_resolved(result: Dictionary) -> void:
	if match_finished:
		return

	if sample_accumulator > 0.0:
		var sample_delta := sample_accumulator
		sample_accumulator = 0.0
		_sample_players(sample_delta)
	_resolve_dodge_windows(true)

	final_result = result.duplicate(true)
	final_result["timeout"] = bool(final_result.get("timeout", false))
	match_finished = true
	_record_event("match_resolved", {
		"winner_role": str(final_result.get("winner_role", "")),
		"winner_name": str(final_result.get("winner_name", "")),
		"draw": bool(final_result.get("draw", false)),
	})
	run_report = _build_run_report()

func _register_player(player: Player) -> void:
	var player_id := player.get_instance_id()
	var controller := player.get_node_or_null(^"AIController") as AIController
	player_records[player_id] = {
		"player": player,
		"slot": int(player.get_meta(&"match_slot", -1)),
		"label": str(player.get_meta(&"match_display_name", player.name)),
		"role": str(player.get_meta(&"eval_role", "")),
		"eval_id": str(player.get_meta(&"eval_id", "")),
		"is_ai": controller != null and controller.enabled,
		"metrics": _make_metric_template(),
		"last_snapshot": {},
		"last_position": player.global_position,
		"active_route": {},
		"last_pending_threat_id": 0,
		"dodge_windows": [],
		"on_platform": false,
		"platform_contact_time": 0.0,
		"platform_success_counted": false,
		"connected_arrows": {},
	}

	var shot_callable := Callable(self, "_on_player_shot_fired").bind(player_id)
	if not player.is_connected("shot_fired", shot_callable):
		player.connect("shot_fired", shot_callable)

	var damage_callable := Callable(self, "_on_player_damage_taken").bind(player_id)
	if not player.is_connected("damage_taken", damage_callable):
		player.connect("damage_taken", damage_callable)

	var death_callable := Callable(self, "_on_player_died").bind(player_id)
	if not player.is_connected("im_dead", death_callable):
		player.connect("im_dead", death_callable)

func _connect_world_events() -> void:
	if world == null:
		return

	for node in world.find_children("*", "", true, false):
		if node.has_method("get_reward_type") and node.has_signal("opened"):
			var chest_callable := Callable(self, "_on_chest_opened")
			if not node.is_connected("opened", chest_callable):
				node.connect("opened", chest_callable)

		if node.has_method("controls_disabled_gate") and node.has_signal("pressed"):
			var switch_callable := Callable(self, "_on_switch_pressed")
			if not node.is_connected("pressed", switch_callable):
				node.connect("pressed", switch_callable)

		if node.has_signal("teleported"):
			var gate_callable := Callable(self, "_on_gate_teleported")
			if not node.is_connected("teleported", gate_callable):
				node.connect("teleported", gate_callable)

		if node.has_signal("launched"):
			var launch_callable := Callable(self, "_on_jump_pad_launched")
			if not node.is_connected("launched", launch_callable):
				node.connect("launched", launch_callable)

func _sample_players(sample_delta: float) -> void:
	for player_id in player_records.keys():
		var record: Dictionary = player_records[player_id]
		var player := record.get("player") as Player
		if player == null or not is_instance_valid(player):
			continue

		var snapshot := _get_player_snapshot(player)
		_update_state_and_goal_metrics(record, snapshot, sample_delta)
		_update_route_metrics(record, snapshot, player.global_position)
		_update_wrap_metrics(record, player)
		_update_platform_metrics(record, player, sample_delta)
		_update_stuck_metrics(record, snapshot, sample_delta)
		_update_dodge_metrics(record, snapshot)
		record["last_snapshot"] = snapshot
		record["last_position"] = player.global_position

func _get_player_snapshot(player: Player) -> Dictionary:
	var controller := player.get_node_or_null(^"AIController") as AIController
	if controller == null:
		return {}
	return controller.get_debug_snapshot()

func _update_state_and_goal_metrics(record: Dictionary, snapshot: Dictionary, sample_delta: float) -> void:
	var metrics: Dictionary = record.get("metrics", {})
	var last_snapshot: Dictionary = record.get("last_snapshot", {})
	var state_name := str(snapshot.get("state", "inactive"))
	var goal_name := str(snapshot.get("goal", "none"))

	if sample_delta > 0.0:
		_add_time_bucket(metrics.get("state_time_by_type", {}), state_name, sample_delta)
		_add_time_bucket(metrics.get("goal_time_by_type", {}), goal_name, sample_delta)

	if not last_snapshot.is_empty():
		var last_state := str(last_snapshot.get("state", "inactive"))
		if last_state != state_name:
			_record_event("state_change", {
				"player_role": str(record.get("role", "")),
				"player_label": str(record.get("label", "")),
				"from": last_state,
				"to": state_name,
			})

		var last_goal := str(last_snapshot.get("goal", "none"))
		if last_goal != goal_name:
			_record_event("goal_change", {
				"player_role": str(record.get("role", "")),
				"player_label": str(record.get("label", "")),
				"from": last_goal,
				"to": goal_name,
				"goal_node": str(snapshot.get("goal_node", "-")),
			})

func _update_route_metrics(record: Dictionary, snapshot: Dictionary, player_position: Vector2) -> void:
	var route: Variant = snapshot.get("route", {})
	if not (route is Dictionary):
		return

	var route_data: Dictionary = route
	var current_route: Dictionary = record.get("active_route", {})
	var has_next_route := bool(route_data.get("active", false))
	var has_current_route := not current_route.is_empty() and bool(current_route.get("active", false))
	var same_route := has_next_route and has_current_route and str(route_data.get("label", "")) == str(current_route.get("label", ""))

	if has_current_route and not same_route:
		_finish_route(record, current_route, player_position)

	if has_next_route and not same_route:
		_start_route(record, route_data)

	if not has_next_route:
		record["active_route"] = {}

func _start_route(record: Dictionary, route_data: Dictionary) -> void:
	var metrics: Dictionary = record.get("metrics", {})
	var traversal := str(route_data.get("traversal", "unknown"))
	_increment_counter(metrics.get("route_attempts_by_traversal", {}), traversal)
	metrics["route_traversal_attempts"] = int(metrics.get("route_traversal_attempts", 0)) + 1
	record["active_route"] = route_data.duplicate(true)
	_record_event("route_start", {
		"player_role": str(record.get("role", "")),
		"player_label": str(record.get("label", "")),
		"label": str(route_data.get("label", "-")),
		"traversal": traversal,
		"source": str(route_data.get("source", "-")),
		"target": str(route_data.get("target", "-")),
	})

func _finish_route(record: Dictionary, route_data: Dictionary, player_position: Vector2) -> void:
	var metrics: Dictionary = record.get("metrics", {})
	var traversal := str(route_data.get("traversal", "unknown"))
	var focus_position: Vector2 = route_data.get("focus_position", player_position)
	var success := player_position.distance_to(focus_position) <= ROUTE_SUCCESS_DISTANCE

	if success:
		_increment_counter(metrics.get("route_success_by_traversal", {}), traversal)
		metrics["route_traversal_successes"] = int(metrics.get("route_traversal_successes", 0)) + 1
		_record_event("route_success", {
			"player_role": str(record.get("role", "")),
			"player_label": str(record.get("label", "")),
			"label": str(route_data.get("label", "-")),
			"traversal": traversal,
		})
	else:
		metrics["route_failures"] = int(metrics.get("route_failures", 0)) + 1
		_record_event("route_fail", {
			"player_role": str(record.get("role", "")),
			"player_label": str(record.get("label", "")),
			"label": str(route_data.get("label", "-")),
			"traversal": traversal,
		})

func _update_wrap_metrics(record: Dictionary, player: Player) -> void:
	if viewport_size == Vector2.ZERO:
		return

	var last_position: Vector2 = record.get("last_position", player.global_position)
	var delta := player.global_position - last_position
	var wrap_count := 0
	if absf(delta.x) > viewport_size.x * 0.55:
		wrap_count += 1
	if absf(delta.y) > viewport_size.y * 0.55:
		wrap_count += 1
	if wrap_count <= 0:
		return

	var metrics: Dictionary = record.get("metrics", {})
	metrics["wrap_count"] = int(metrics.get("wrap_count", 0)) + wrap_count
	_record_event("wrap", {
		"player_role": str(record.get("role", "")),
		"player_label": str(record.get("label", "")),
		"count": wrap_count,
	})

func _update_platform_metrics(record: Dictionary, player: Player, sample_delta: float) -> void:
	var metrics: Dictionary = record.get("metrics", {})
	var platform := _get_platform_collider(player)

	if platform == null:
		if bool(record.get("on_platform", false)):
			_record_event("platform_left", {
				"player_role": str(record.get("role", "")),
				"player_label": str(record.get("label", "")),
			})
		record["on_platform"] = false
		record["platform_contact_time"] = 0.0
		record["platform_success_counted"] = false
		return

	metrics["platform_ride_time"] = float(metrics.get("platform_ride_time", 0.0)) + sample_delta
	if not bool(record.get("on_platform", false)):
		metrics["platform_board_attempts"] = int(metrics.get("platform_board_attempts", 0)) + 1
		record["on_platform"] = true
		record["platform_contact_time"] = 0.0
		record["platform_success_counted"] = false
		_record_event("platform_boarded", {
			"player_role": str(record.get("role", "")),
			"player_label": str(record.get("label", "")),
		})

	record["platform_contact_time"] = float(record.get("platform_contact_time", 0.0)) + sample_delta
	if not bool(record.get("platform_success_counted", false)) and float(record.get("platform_contact_time", 0.0)) >= PLATFORM_SUCCESS_TIME:
		metrics["platform_board_success"] = int(metrics.get("platform_board_success", 0)) + 1
		record["platform_success_counted"] = true

func _update_stuck_metrics(record: Dictionary, snapshot: Dictionary, sample_delta: float) -> void:
	if sample_delta <= 0.0:
		return

	var metrics: Dictionary = record.get("metrics", {})
	if float(snapshot.get("stuck_time_left", 0.0)) > 0.0:
		metrics["stuck_time_seconds"] = float(metrics.get("stuck_time_seconds", 0.0)) + sample_delta

func _update_dodge_metrics(record: Dictionary, snapshot: Dictionary) -> void:
	var threat_id := int(snapshot.get("pending_threat_id", 0))
	var last_threat_id := int(record.get("last_pending_threat_id", 0))
	var metrics: Dictionary = record.get("metrics", {})
	if threat_id != 0 and threat_id != last_threat_id:
		metrics["dodge_opportunities"] = int(metrics.get("dodge_opportunities", 0)) + 1
		var dodge_windows: Array = record.get("dodge_windows", [])
		dodge_windows.append({
			"threat_id": threat_id,
			"expires_at": run_time_seconds + DODGE_SUCCESS_WINDOW,
			"damaged": false,
			"resolved": false,
		})
		record["dodge_windows"] = dodge_windows
		_record_event("dodge_window", {
			"player_role": str(record.get("role", "")),
			"player_label": str(record.get("label", "")),
			"threat_id": threat_id,
		})

	var last_snapshot: Dictionary = record.get("last_snapshot", {})
	if not last_snapshot.is_empty() and not bool(last_snapshot.get("dodge_active", false)) and bool(snapshot.get("dodge_active", false)):
		_record_event("dodge_start", {
			"player_role": str(record.get("role", "")),
			"player_label": str(record.get("label", "")),
		})
	record["last_pending_threat_id"] = threat_id

func _resolve_dodge_windows(force_complete: bool) -> void:
	for player_id in player_records.keys():
		var record: Dictionary = player_records[player_id]
		var metrics: Dictionary = record.get("metrics", {})
		var dodge_windows: Array = record.get("dodge_windows", [])
		for window_variant in dodge_windows:
			if not (window_variant is Dictionary):
				continue
			var window: Dictionary = window_variant
			if bool(window.get("resolved", false)):
				continue
			if not force_complete and run_time_seconds < float(window.get("expires_at", 0.0)):
				continue
			window["resolved"] = true
			if not bool(window.get("damaged", false)):
				metrics["successful_dodges"] = int(metrics.get("successful_dodges", 0)) + 1
		record["dodge_windows"] = dodge_windows

func _on_player_shot_fired(projectile: Variant, arrow_type: int, direction: Vector2, player_id: int) -> void:
	var record: Dictionary = player_records.get(player_id, {})
	if record.is_empty():
		return

	var metrics: Dictionary = record.get("metrics", {})
	metrics["shots_fired"] = int(metrics.get("shots_fired", 0)) + 1
	var snapshot: Dictionary = record.get("last_snapshot", {})
	var shot_quality := float(snapshot.get("shot_quality", -1.0))
	var shot_allowed := bool(snapshot.get("shot_allowed", false))
	if not shot_allowed or shot_quality < LOW_QUALITY_SHOT_THRESHOLD:
		metrics["low_quality_shots"] = int(metrics.get("low_quality_shots", 0)) + 1

	_record_event("shot_fired", {
		"player_role": str(record.get("role", "")),
		"player_label": str(record.get("label", "")),
		"arrow_type": Arrow.get_arrow_name(arrow_type),
		"shot_quality": shot_quality,
		"shot_allowed": shot_allowed,
		"direction": _vector_to_dict(direction),
	})

	var arrow := projectile as Arrow
	if arrow == null:
		return

	var connected_arrows: Dictionary = record.get("connected_arrows", {})
	if connected_arrows.has(arrow.get_instance_id()):
		return
	connected_arrows[arrow.get_instance_id()] = true
	record["connected_arrows"] = connected_arrows

	var hit_callable := Callable(self, "_on_arrow_hit_player").bind(player_id)
	if not arrow.is_connected("hit_player", hit_callable):
		arrow.connect("hit_player", hit_callable)

	var wall_callable := Callable(self, "_on_arrow_hit_wall").bind(player_id)
	if not arrow.is_connected("hit_wall", wall_callable):
		arrow.connect("hit_wall", wall_callable)

	var explosion_callable := Callable(self, "_on_arrow_exploded").bind(player_id)
	if not arrow.is_connected("exploded", explosion_callable):
		arrow.connect("exploded", explosion_callable)

func _on_arrow_hit_player(target: Player, _shooter: Player, arrow_type: int, shooter_id: int) -> void:
	var record: Dictionary = player_records.get(shooter_id, {})
	if record.is_empty():
		return
	var metrics: Dictionary = record.get("metrics", {})
	metrics["shots_hit"] = int(metrics.get("shots_hit", 0)) + 1
	_record_event("shot_hit", {
		"player_role": str(record.get("role", "")),
		"player_label": str(record.get("label", "")),
		"target_role": str(target.get_meta(&"eval_role", "")) if target != null else "",
		"target_label": str(target.get_meta(&"match_display_name", target.name)) if target != null else "",
		"arrow_type": Arrow.get_arrow_name(arrow_type),
	})

func _on_arrow_hit_wall(_shooter: Player, arrow_type: int, shooter_id: int) -> void:
	var record: Dictionary = player_records.get(shooter_id, {})
	if record.is_empty():
		return
	_record_event("shot_wall", {
		"player_role": str(record.get("role", "")),
		"player_label": str(record.get("label", "")),
		"arrow_type": Arrow.get_arrow_name(arrow_type),
	})

func _on_arrow_exploded(_shooter: Player, arrow_type: int, hit_players: Array, shooter_id: int) -> void:
	var record: Dictionary = player_records.get(shooter_id, {})
	if record.is_empty():
		return
	var metrics: Dictionary = record.get("metrics", {})
	metrics["shots_hit"] = int(metrics.get("shots_hit", 0)) + hit_players.size()
	_record_event("shot_exploded", {
		"player_role": str(record.get("role", "")),
		"player_label": str(record.get("label", "")),
		"arrow_type": Arrow.get_arrow_name(arrow_type),
		"hit_count": hit_players.size(),
	})

func _on_player_damage_taken(source_type: Variant, source_actor: Node, lethal: bool, remaining_health: int, player_id: int) -> void:
	var record: Dictionary = player_records.get(player_id, {})
	if record.is_empty():
		return

	var metrics: Dictionary = record.get("metrics", {})
	var damage_type := str(source_type)
	var dodge_windows: Array = record.get("dodge_windows", [])
	for window_variant in dodge_windows:
		if not (window_variant is Dictionary):
			continue
		var window: Dictionary = window_variant
		if bool(window.get("resolved", false)):
			continue
		if run_time_seconds <= float(window.get("expires_at", 0.0)) and damage_type in ["arrow", "explosion", "body"]:
			window["damaged"] = true
	record["dodge_windows"] = dodge_windows

	if lethal:
		metrics["death_cause"] = damage_type
		if damage_type == "spikes":
			metrics["self_hazard_deaths"] = int(metrics.get("self_hazard_deaths", 0)) + 1

	var attacker := source_actor as Player
	if damage_type == "body" and attacker != null:
		var attacker_record: Dictionary = player_records.get(attacker.get_instance_id(), {})
		if not attacker_record.is_empty():
			var attacker_metrics: Dictionary = attacker_record.get("metrics", {})
			attacker_metrics["stomp_attempts"] = int(attacker_metrics.get("stomp_attempts", 0)) + 1
			attacker_metrics["successful_stomps"] = int(attacker_metrics.get("successful_stomps", 0)) + 1

	_record_event("damage", {
		"player_role": str(record.get("role", "")),
		"player_label": str(record.get("label", "")),
		"source_type": damage_type,
		"source_role": str(attacker.get_meta(&"eval_role", "")) if attacker != null else "",
		"source_label": str(attacker.get_meta(&"match_display_name", attacker.name)) if attacker != null else "",
		"lethal": lethal,
		"remaining_health": remaining_health,
	})

func _on_player_died(player_id: int) -> void:
	var record: Dictionary = player_records.get(player_id, {})
	if record.is_empty():
		return
	_record_event("player_died", {
		"player_role": str(record.get("role", "")),
		"player_label": str(record.get("label", "")),
		"death_cause": str(record.get("metrics", {}).get("death_cause", "")),
	})

func _on_chest_opened(player: Player, reward_type: int) -> void:
	var record: Dictionary = player_records.get(player.get_instance_id(), {})
	if record.is_empty():
		return
	var metrics: Dictionary = record.get("metrics", {})
	metrics["chest_opens"] = int(metrics.get("chest_opens", 0)) + 1
	_record_event("chest_opened", {
		"player_role": str(record.get("role", "")),
		"player_label": str(record.get("label", "")),
		"reward_type": reward_type,
	})

func _on_switch_pressed(player: Player) -> void:
	var record: Dictionary = player_records.get(player.get_instance_id(), {})
	if record.is_empty():
		return
	var metrics: Dictionary = record.get("metrics", {})
	metrics["switch_presses"] = int(metrics.get("switch_presses", 0)) + 1
	_record_event("switch_pressed", {
		"player_role": str(record.get("role", "")),
		"player_label": str(record.get("label", "")),
	})

func _on_gate_teleported(player: CharacterBody2D, _source_gate: Node2D, _target_gate: Node2D) -> void:
	var actual_player := player as Player
	if actual_player == null:
		return
	var record: Dictionary = player_records.get(actual_player.get_instance_id(), {})
	if record.is_empty():
		return
	var metrics: Dictionary = record.get("metrics", {})
	metrics["gate_uses"] = int(metrics.get("gate_uses", 0)) + 1
	_record_event("gate_used", {
		"player_role": str(record.get("role", "")),
		"player_label": str(record.get("label", "")),
	})

func _on_jump_pad_launched(body: CharacterBody2D) -> void:
	var player := body as Player
	if player == null:
		return
	var record: Dictionary = player_records.get(player.get_instance_id(), {})
	if record.is_empty():
		return
	var metrics: Dictionary = record.get("metrics", {})
	metrics["jump_pad_launches"] = int(metrics.get("jump_pad_launches", 0)) + 1
	_record_event("jump_pad_launched", {
		"player_role": str(record.get("role", "")),
		"player_label": str(record.get("label", "")),
	})

func _get_platform_collider(player: Player) -> Object:
	for collision_index in range(player.get_slide_collision_count()):
		var collision := player.get_slide_collision(collision_index)
		if collision == null:
			continue
		var collider := collision.get_collider()
		if _is_moving_platform(collider):
			return collider
	return null

func _is_moving_platform(collider: Object) -> bool:
	var node := collider as Node
	if node == null:
		return false
	var script: Variant = node.get_script()
	if script is Script and str((script as Script).resource_path) == MOVING_PLATFORM_SCRIPT_PATH:
		return true
	return node.name == "MovingPlatform"

func _build_run_report() -> Dictionary:
	var candidate: Dictionary = _build_role_summary("candidate")
	var opponent: Dictionary = _build_role_summary("opponent")
	var verdict_flags: Array[String] = _build_verdict_flags(candidate, opponent)
	return {
		"run_id": str(run_config.get("run_id", "")),
		"battery_profile": str(run_config.get("battery_profile", "adhoc")),
		"tier": str(run_config.get("tier", "phase2")),
		"arena_name": str(run_config.get("arena_name", "")),
		"level_path": str(run_config.get("level_path", "")),
		"seed": int(run_config.get("seed", -1)),
		"spawn_swap_index": int(run_config.get("spawn_swap_index", 0)),
		"candidate_id": str(run_config.get("candidate_id", "")),
		"opponent_id": str(run_config.get("opponent_id", "")),
		"duration_seconds": snappedf(run_time_seconds, 0.001),
		"result": "timeout" if bool(final_result.get("timeout", false)) else "resolved",
		"winner": str(final_result.get("winner_name", "")),
		"winner_role": str(final_result.get("winner_role", "")),
		"timeout": bool(final_result.get("timeout", false)),
		"candidate": candidate,
		"opponent": opponent,
		"comparison": _build_role_comparison(candidate, opponent),
		"timeline": timeline.duplicate(true),
		"verdict_flags": verdict_flags,
		"metadata": run_config.duplicate(true),
	}

func _build_role_summary(role: String) -> Dictionary:
	for player_id in player_records.keys():
		var record: Dictionary = player_records[player_id]
		if str(record.get("role", "")) == role:
			return _build_player_summary(record)
	return _empty_player_summary(role)

func _build_player_summary(record: Dictionary) -> Dictionary:
	var metrics: Dictionary = record.get("metrics", {})
	var route_attempts: Dictionary = metrics.get("route_attempts_by_traversal", {})
	var route_successes: Dictionary = metrics.get("route_success_by_traversal", {})
	var total_route_attempts: int = _sum_counter_values(route_attempts)
	var total_route_successes: int = _sum_counter_values(route_successes)
	var chest_opens: int = int(metrics.get("chest_opens", 0))
	var switch_presses: int = int(metrics.get("switch_presses", 0))
	var gate_uses: int = int(metrics.get("gate_uses", 0))
	var jump_pad_launches: int = int(metrics.get("jump_pad_launches", 0))
	var platform_attempts: int = int(metrics.get("platform_board_attempts", 0))
	var platform_success: int = int(metrics.get("platform_board_success", 0))
	var mechanic_successes: int = chest_opens + switch_presses + gate_uses + jump_pad_launches + platform_success
	var mechanic_opportunities: int = chest_opens + switch_presses + gate_uses + jump_pad_launches + platform_attempts
	var shots_fired: int = int(metrics.get("shots_fired", 0))
	var shots_hit: int = int(metrics.get("shots_hit", 0))
	var low_quality_shots: int = int(metrics.get("low_quality_shots", 0))
	var dodge_opportunities: int = int(metrics.get("dodge_opportunities", 0))
	var successful_dodges: int = int(metrics.get("successful_dodges", 0))
	var stomp_attempts: int = int(metrics.get("stomp_attempts", 0))
	var successful_stomps: int = int(metrics.get("successful_stomps", 0))
	var platform_ride_time: float = snappedf(float(metrics.get("platform_ride_time", 0.0)), 0.001)
	var stuck_time_seconds: float = snappedf(float(metrics.get("stuck_time_seconds", 0.0)), 0.001)
	return {
		"role": str(record.get("role", "")),
		"label": str(record.get("label", "")),
		"eval_id": str(record.get("eval_id", "")),
		"slot": int(record.get("slot", -1)),
		"shots_fired": shots_fired,
		"shots_hit": shots_hit,
		"low_quality_shots": low_quality_shots,
		"accuracy_rate": snappedf(float(shots_hit) / max(shots_fired, 1), 0.001),
		"shot_discipline_rate": snappedf(1.0 - float(low_quality_shots) / max(shots_fired, 1), 0.001),
		"dodge_opportunities": dodge_opportunities,
		"successful_dodges": successful_dodges,
		"dodge_success_rate": snappedf(float(successful_dodges) / max(dodge_opportunities, 1), 0.001),
		"stomp_attempts": stomp_attempts,
		"successful_stomps": successful_stomps,
		"stomp_success_rate": snappedf(float(successful_stomps) / max(stomp_attempts, 1), 0.001),
		"goal_time_by_type": _rounded_dictionary(metrics.get("goal_time_by_type", {})),
		"state_time_by_type": _rounded_dictionary(metrics.get("state_time_by_type", {})),
		"route_attempts_by_traversal": route_attempts.duplicate(true),
		"route_success_by_traversal": route_successes.duplicate(true),
		"route_traversal_attempts": total_route_attempts,
		"route_traversal_successes": total_route_successes,
		"route_success_rate": snappedf(float(total_route_successes) / max(total_route_attempts, 1), 0.001),
		"route_failures": int(metrics.get("route_failures", 0)),
		"wrap_count": int(metrics.get("wrap_count", 0)),
		"platform_board_attempts": platform_attempts,
		"platform_board_success": platform_success,
		"platform_board_rate": snappedf(float(platform_success) / max(platform_attempts, 1), 0.001),
		"platform_ride_time": platform_ride_time,
		"stuck_time_seconds": stuck_time_seconds,
		"death_cause": str(metrics.get("death_cause", "")),
		"self_hazard_deaths": int(metrics.get("self_hazard_deaths", 0)),
		"chest_opens": chest_opens,
		"switch_presses": switch_presses,
		"gate_uses": gate_uses,
		"jump_pad_launches": jump_pad_launches,
		"mechanic_successes": mechanic_successes,
		"mechanic_opportunities": mechanic_opportunities,
		"mechanic_success_rate": snappedf(float(mechanic_successes) / max(mechanic_opportunities, 1), 0.001),
		"mechanic_breakdown": {
			"chest_opens": chest_opens,
			"switch_presses": switch_presses,
			"gate_uses": gate_uses,
			"jump_pad_launches": jump_pad_launches,
			"moving_platform": {
				"board_attempts": platform_attempts,
				"board_success": platform_success,
				"board_rate": snappedf(float(platform_success) / max(platform_attempts, 1), 0.001),
				"ride_time": platform_ride_time,
			},
		},
	}

func _empty_player_summary(role: String) -> Dictionary:
	return {
		"role": role,
		"label": "",
		"eval_id": "",
		"slot": -1,
		"shots_fired": 0,
		"shots_hit": 0,
		"low_quality_shots": 0,
		"accuracy_rate": 0.0,
		"shot_discipline_rate": 0.0,
		"dodge_opportunities": 0,
		"successful_dodges": 0,
		"dodge_success_rate": 0.0,
		"stomp_attempts": 0,
		"successful_stomps": 0,
		"stomp_success_rate": 0.0,
		"goal_time_by_type": {},
		"state_time_by_type": {},
		"route_attempts_by_traversal": {},
		"route_success_by_traversal": {},
		"route_traversal_attempts": 0,
		"route_traversal_successes": 0,
		"route_success_rate": 0.0,
		"route_failures": 0,
		"wrap_count": 0,
		"platform_board_attempts": 0,
		"platform_board_success": 0,
		"platform_board_rate": 0.0,
		"platform_ride_time": 0.0,
		"stuck_time_seconds": 0.0,
		"death_cause": "",
		"self_hazard_deaths": 0,
		"chest_opens": 0,
		"switch_presses": 0,
		"gate_uses": 0,
		"jump_pad_launches": 0,
		"mechanic_successes": 0,
		"mechanic_opportunities": 0,
		"mechanic_success_rate": 0.0,
		"mechanic_breakdown": {
			"chest_opens": 0,
			"switch_presses": 0,
			"gate_uses": 0,
			"jump_pad_launches": 0,
			"moving_platform": {
				"board_attempts": 0,
				"board_success": 0,
				"board_rate": 0.0,
				"ride_time": 0.0,
			},
		},
	}

func _build_role_comparison(candidate: Dictionary, opponent: Dictionary) -> Dictionary:
	return {
		"winner_delta": _winner_delta(),
		"candidate_minus_opponent": _build_metric_delta(candidate, opponent),
	}

func _winner_delta() -> int:
	var winner_role := str(final_result.get("winner_role", ""))
	if winner_role == "candidate":
		return 1
	if winner_role == "opponent":
		return -1
	return 0

func _build_metric_delta(candidate: Dictionary, opponent: Dictionary) -> Dictionary:
	return {
		"shots_fired": int(candidate.get("shots_fired", 0)) - int(opponent.get("shots_fired", 0)),
		"shots_hit": int(candidate.get("shots_hit", 0)) - int(opponent.get("shots_hit", 0)),
		"low_quality_shots": int(candidate.get("low_quality_shots", 0)) - int(opponent.get("low_quality_shots", 0)),
		"accuracy_rate": snappedf(float(candidate.get("accuracy_rate", 0.0)) - float(opponent.get("accuracy_rate", 0.0)), 0.001),
		"shot_discipline_rate": snappedf(float(candidate.get("shot_discipline_rate", 0.0)) - float(opponent.get("shot_discipline_rate", 0.0)), 0.001),
		"dodge_success_rate": snappedf(float(candidate.get("dodge_success_rate", 0.0)) - float(opponent.get("dodge_success_rate", 0.0)), 0.001),
		"stomp_success_rate": snappedf(float(candidate.get("stomp_success_rate", 0.0)) - float(opponent.get("stomp_success_rate", 0.0)), 0.001),
		"route_success_rate": snappedf(float(candidate.get("route_success_rate", 0.0)) - float(opponent.get("route_success_rate", 0.0)), 0.001),
		"route_failures": int(candidate.get("route_failures", 0)) - int(opponent.get("route_failures", 0)),
		"wrap_count": int(candidate.get("wrap_count", 0)) - int(opponent.get("wrap_count", 0)),
		"platform_board_rate": snappedf(float(candidate.get("platform_board_rate", 0.0)) - float(opponent.get("platform_board_rate", 0.0)), 0.001),
		"platform_ride_time": snappedf(float(candidate.get("platform_ride_time", 0.0)) - float(opponent.get("platform_ride_time", 0.0)), 0.001),
		"stuck_time_seconds": snappedf(float(candidate.get("stuck_time_seconds", 0.0)) - float(opponent.get("stuck_time_seconds", 0.0)), 0.001),
		"self_hazard_deaths": int(candidate.get("self_hazard_deaths", 0)) - int(opponent.get("self_hazard_deaths", 0)),
		"chest_opens": int(candidate.get("chest_opens", 0)) - int(opponent.get("chest_opens", 0)),
		"switch_presses": int(candidate.get("switch_presses", 0)) - int(opponent.get("switch_presses", 0)),
		"gate_uses": int(candidate.get("gate_uses", 0)) - int(opponent.get("gate_uses", 0)),
		"jump_pad_launches": int(candidate.get("jump_pad_launches", 0)) - int(opponent.get("jump_pad_launches", 0)),
		"mechanic_success_rate": snappedf(float(candidate.get("mechanic_success_rate", 0.0)) - float(opponent.get("mechanic_success_rate", 0.0)), 0.001),
	}

func _build_verdict_flags(candidate: Dictionary, opponent: Dictionary) -> Array[String]:
	var flags: Array[String] = []
	if bool(final_result.get("timeout", false)):
		flags.append("timeout")
	if int(candidate.get("self_hazard_deaths", 0)) > 0 or int(opponent.get("self_hazard_deaths", 0)) > 0:
		flags.append("hazard_suicide")
	if int(candidate.get("route_failures", 0)) > 2 or int(opponent.get("route_failures", 0)) > 2:
		flags.append("route_loop")
	if (int(candidate.get("platform_board_attempts", 0)) > 0 and int(candidate.get("platform_board_success", 0)) == 0) or (int(opponent.get("platform_board_attempts", 0)) > 0 and int(opponent.get("platform_board_success", 0)) == 0):
		flags.append("platform_fail")
	if int(candidate.get("shots_fired", 0)) >= 4 and int(candidate.get("low_quality_shots", 0)) * 2 > int(candidate.get("shots_fired", 0)):
		flags.append("low_discipline_fire")
	return flags

func _serialize_alive_players() -> Array[Dictionary]:
	var alive_players: Array[Dictionary] = []
	for player in tracked_players:
		if player == null or not is_instance_valid(player):
			continue
		alive_players.append({
			"name": str(player.get_meta(&"match_display_name", player.name)),
			"slot": int(player.get_meta(&"match_slot", -1)),
			"role": str(player.get_meta(&"eval_role", "")),
			"eval_id": str(player.get_meta(&"eval_id", "")),
		})
	return alive_players

func _record_event(event_name: String, data: Dictionary) -> void:
	var event := {
		"time": snappedf(run_time_seconds, 0.001),
		"event": event_name,
	}
	event.merge(data, true)
	timeline.append(event)

func _make_metric_template() -> Dictionary:
	return {
		"shots_fired": 0,
		"shots_hit": 0,
		"low_quality_shots": 0,
		"dodge_opportunities": 0,
		"successful_dodges": 0,
		"stomp_attempts": 0,
		"successful_stomps": 0,
		"goal_time_by_type": {},
		"state_time_by_type": {},
		"route_attempts_by_traversal": {},
		"route_success_by_traversal": {},
		"route_traversal_attempts": 0,
		"route_traversal_successes": 0,
		"route_failures": 0,
		"wrap_count": 0,
		"platform_board_attempts": 0,
		"platform_board_success": 0,
		"platform_ride_time": 0.0,
		"stuck_time_seconds": 0.0,
		"death_cause": "",
		"self_hazard_deaths": 0,
		"chest_opens": 0,
		"switch_presses": 0,
		"gate_uses": 0,
		"jump_pad_launches": 0,
	}

func _increment_counter(counter: Dictionary, key: String, amount: int = 1) -> void:
	counter[key] = int(counter.get(key, 0)) + amount

func _add_time_bucket(counter: Dictionary, key: String, amount: float) -> void:
	counter[key] = float(counter.get(key, 0.0)) + amount

func _sum_counter_values(counter: Dictionary) -> int:
	var total := 0
	for value in counter.values():
		total += int(value)
	return total

func _rounded_dictionary(counter: Dictionary) -> Dictionary:
	var rounded: Dictionary = {}
	for key in counter.keys():
		rounded[key] = snappedf(float(counter[key]), 0.001)
	return rounded

func _vector_to_dict(value: Vector2) -> Dictionary:
	return {
		"x": snappedf(value.x, 0.001),
		"y": snappedf(value.y, 0.001),
	}

static func build_batch_summary(run_reports: Array[Dictionary], batch_metadata: Dictionary = {}) -> Dictionary:
	var per_tier: Dictionary = {}
	var per_level: Dictionary = {}
	var flag_counts: Dictionary = {}
	var flag_examples: Dictionary = {}
	var candidate_totals := _make_batch_role_bucket()
	var opponent_totals := _make_batch_role_bucket()
	var total_runs: int = run_reports.size()

	for report in run_reports:
		var candidate: Dictionary = report.get("candidate", {})
		var opponent: Dictionary = report.get("opponent", {})
		var tier: String = str(report.get("tier", "unknown"))
		var arena_name: String = str(report.get("arena_name", "unknown"))
		var seed: int = int(report.get("seed", -1))
		var timed_out := bool(report.get("timeout", false))
		var winner_role: String = str(report.get("winner_role", ""))
		var duration_seconds := float(report.get("duration_seconds", 0.0))

		_accumulate_batch_role_bucket(candidate_totals, candidate, winner_role == "candidate", winner_role == "opponent", timed_out, duration_seconds)
		_accumulate_batch_role_bucket(opponent_totals, opponent, winner_role == "opponent", winner_role == "candidate", timed_out, duration_seconds)

		if not per_tier.has(tier):
			per_tier[tier] = {
				"candidate": _make_batch_role_bucket(),
				"opponent": _make_batch_role_bucket(),
			}
		var tier_summary: Dictionary = per_tier[tier]
		_accumulate_batch_role_bucket(tier_summary.get("candidate", {}), candidate, winner_role == "candidate", winner_role == "opponent", timed_out, duration_seconds)
		_accumulate_batch_role_bucket(tier_summary.get("opponent", {}), opponent, winner_role == "opponent", winner_role == "candidate", timed_out, duration_seconds)

		if not per_level.has(arena_name):
			per_level[arena_name] = {
				"level_name": arena_name,
				"candidate": _make_batch_role_bucket(),
				"opponent": _make_batch_role_bucket(),
				"candidate_death_cause_breakdown": {},
				"opponent_death_cause_breakdown": {},
				"worst_seeds": [],
			}
		var level_summary: Dictionary = per_level[arena_name]
		_accumulate_batch_role_bucket(level_summary.get("candidate", {}), candidate, winner_role == "candidate", winner_role == "opponent", timed_out, duration_seconds)
		_accumulate_batch_role_bucket(level_summary.get("opponent", {}), opponent, winner_role == "opponent", winner_role == "candidate", timed_out, duration_seconds)
		_increment_optional_counter(level_summary.get("candidate_death_cause_breakdown", {}), str(candidate.get("death_cause", "")))
		_increment_optional_counter(level_summary.get("opponent_death_cause_breakdown", {}), str(opponent.get("death_cause", "")))
		if timed_out or winner_role == "opponent" or int(candidate.get("self_hazard_deaths", 0)) > 0:
			var worst_seeds: Array = level_summary.get("worst_seeds", [])
			if not worst_seeds.has(seed):
				worst_seeds.append(seed)
				worst_seeds.sort()
				level_summary["worst_seeds"] = worst_seeds

		for flag_variant in report.get("verdict_flags", []):
			var flag: String = str(flag_variant)
			flag_counts[flag] = int(flag_counts.get(flag, 0)) + 1
			if not flag_examples.has(flag):
				flag_examples[flag] = []
			var examples: Array = flag_examples.get(flag, [])
			if not examples.has(seed):
				examples.append(seed)
				examples.sort()
				flag_examples[flag] = examples

	var candidate_summary := _finalize_batch_role_bucket(candidate_totals)
	var opponent_summary := _finalize_batch_role_bucket(opponent_totals)
	var overall_batch_score := _score_role_summary(candidate_summary)
	var opponent_batch_score := _score_role_summary(opponent_summary)
	var comparison := {
		"overall_batch_score_delta": snappedf(overall_batch_score - opponent_batch_score, 0.001),
		"candidate_minus_opponent": _build_summary_delta(candidate_summary, opponent_summary),
	}

	var tier_summaries: Array[Dictionary] = []
	var tier_keys: Array = per_tier.keys()
	tier_keys.sort()
	for tier_key_variant in tier_keys:
		var tier_key := str(tier_key_variant)
		var tier_summary: Dictionary = per_tier[tier_key]
		var tier_candidate := _finalize_batch_role_bucket(tier_summary.get("candidate", {}))
		var tier_opponent := _finalize_batch_role_bucket(tier_summary.get("opponent", {}))
		tier_summaries.append({
			"tier": tier_key,
			"runs": int(tier_candidate.get("runs", 0)),
			"wins": int(tier_candidate.get("wins", 0)),
			"losses": int(tier_candidate.get("losses", 0)),
			"timeouts": int(tier_candidate.get("timeouts", 0)),
			"self_hazard_deaths": int(tier_candidate.get("self_hazard_deaths", 0)),
			"low_quality_shot_rate": float(tier_candidate.get("shot_discipline_rate", 0.0)),
			"route_success_rate": float(tier_candidate.get("route_success_rate", 0.0)),
			"mechanic_success_rate": float(tier_candidate.get("mechanic_success_rate", 0.0)),
			"mean_stuck_time": float(tier_candidate.get("mean_stuck_time", 0.0)),
			"candidate": tier_candidate,
			"opponent": tier_opponent,
			"delta": _build_summary_delta(tier_candidate, tier_opponent),
		})

	var level_summaries: Array[Dictionary] = []
	var level_keys: Array = per_level.keys()
	level_keys.sort()
	for level_key_variant in level_keys:
		var level_key := str(level_key_variant)
		var level_summary: Dictionary = per_level[level_key]
		var level_candidate := _finalize_batch_role_bucket(level_summary.get("candidate", {}))
		var level_opponent := _finalize_batch_role_bucket(level_summary.get("opponent", {}))
		level_summaries.append({
			"level_name": str(level_summary.get("level_name", level_key)),
			"win_rate": float(level_candidate.get("win_rate", 0.0)),
			"timeout_rate": float(level_candidate.get("timeout_rate", 0.0)),
			"death_cause_breakdown": level_summary.get("candidate_death_cause_breakdown", {}).duplicate(true),
			"chest_conversion": int(level_candidate.get("chest_opens", 0)),
			"switch_conversion": int(level_candidate.get("switch_presses", 0)),
			"gate_usage": int(level_candidate.get("gate_uses", 0)),
			"jump_pad_usage": int(level_candidate.get("jump_pad_launches", 0)),
			"wrap_usage": int(level_candidate.get("wrap_count", 0)),
			"moving_platform_usage": int(level_candidate.get("platform_board_success", 0)),
			"worst_seeds": level_summary.get("worst_seeds", []).duplicate(),
			"candidate": level_candidate,
			"opponent": level_opponent,
			"candidate_death_cause_breakdown": level_summary.get("candidate_death_cause_breakdown", {}).duplicate(true),
			"opponent_death_cause_breakdown": level_summary.get("opponent_death_cause_breakdown", {}).duplicate(true),
			"delta": _build_summary_delta(level_candidate, level_opponent),
		})

	var failure_clusters: Array[Dictionary] = []
	var flag_keys: Array = flag_counts.keys()
	flag_keys.sort()
	for flag_key_variant in flag_keys:
		var flag_key := str(flag_key_variant)
		failure_clusters.append({
			"flag": flag_key,
			"count": int(flag_counts.get(flag_key, 0)),
			"example_seeds": flag_examples.get(flag_key, []).duplicate(),
		})
	failure_clusters.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var count_a := int(a.get("count", 0))
		var count_b := int(b.get("count", 0))
		if count_a == count_b:
			return str(a.get("flag", "")) < str(b.get("flag", ""))
		return count_a > count_b
	)
	if failure_clusters.size() > 3:
		failure_clusters.resize(3)

	return {
		"candidate_id": str(batch_metadata.get("candidate_id", run_reports[0].get("candidate_id", "") if total_runs > 0 else "")),
		"baseline_id": str(batch_metadata.get("baseline_id", run_reports[0].get("opponent_id", "") if total_runs > 0 else "")),
		"battery_profile": str(batch_metadata.get("battery_profile", run_reports[0].get("battery_profile", "") if total_runs > 0 else "")),
		"seed_pack": batch_metadata.get("seed_pack", []),
		"generated_at_unix": int(Time.get_unix_time_from_system()),
		"regression_status": {
			"completed_runs": total_runs,
			"timeouts": int(candidate_summary.get("timeouts", 0)),
		},
		"overall_batch_score": snappedf(overall_batch_score, 0.001),
		"opponent_batch_score": snappedf(opponent_batch_score, 0.001),
		"promotion_verdict": "manual_review_required",
		"per_tier_summaries": tier_summaries,
		"per_level_summaries": level_summaries,
		"failure_clusters": failure_clusters,
		"opponent_summary_metrics": opponent_summary,
		"comparison": comparison,
		"summary_metrics": {
			"win_rate": float(candidate_summary.get("win_rate", 0.0)),
			"no_timeout_rate": float(candidate_summary.get("no_timeout_rate", 0.0)),
			"no_self_hazard_rate": float(candidate_summary.get("no_self_hazard_rate", 0.0)),
			"shot_discipline_rate": float(candidate_summary.get("shot_discipline_rate", 0.0)),
			"route_success_rate": float(candidate_summary.get("route_success_rate", 0.0)),
			"mechanic_success_rate": float(candidate_summary.get("mechanic_success_rate", 0.0)),
			"mean_stuck_time": float(candidate_summary.get("mean_stuck_time", 0.0)),
		},
	}

static func build_batch_diff(run_reports: Array[Dictionary], batch_metadata: Dictionary = {}) -> Dictionary:
	var summary := build_batch_summary(run_reports, batch_metadata)
	var per_tier_deltas: Array[Dictionary] = []
	for tier_variant in summary.get("per_tier_summaries", []):
		var tier_summary: Dictionary = tier_variant
		per_tier_deltas.append({
			"tier": str(tier_summary.get("tier", "")),
			"delta": tier_summary.get("delta", {}).duplicate(true),
		})

	var per_level_deltas: Array[Dictionary] = []
	for level_variant in summary.get("per_level_summaries", []):
		var level_summary: Dictionary = level_variant
		per_level_deltas.append({
			"level_name": str(level_summary.get("level_name", "")),
			"delta": level_summary.get("delta", {}).duplicate(true),
		})

	return {
		"candidate_id": str(summary.get("candidate_id", "")),
		"baseline_id": str(summary.get("baseline_id", "")),
		"battery_profile": str(summary.get("battery_profile", "")),
		"seed_pack": summary.get("seed_pack", []).duplicate(),
		"generated_at_unix": int(summary.get("generated_at_unix", 0)),
		"overall_batch_score_delta": float(summary.get("comparison", {}).get("overall_batch_score_delta", 0.0)),
		"candidate_minus_opponent": summary.get("comparison", {}).get("candidate_minus_opponent", {}).duplicate(true),
		"per_tier_deltas": per_tier_deltas,
		"per_level_deltas": per_level_deltas,
		"failure_clusters": summary.get("failure_clusters", []).duplicate(true),
	}

static func _make_batch_role_bucket() -> Dictionary:
	return {
		"runs": 0,
		"wins": 0,
		"losses": 0,
		"timeouts": 0,
		"shots_fired": 0,
		"shots_hit": 0,
		"low_quality_shots": 0,
		"dodge_opportunities": 0,
		"successful_dodges": 0,
		"stomp_attempts": 0,
		"successful_stomps": 0,
		"route_traversal_attempts": 0,
		"route_traversal_successes": 0,
		"route_failures": 0,
		"wrap_count": 0,
		"platform_board_attempts": 0,
		"platform_board_success": 0,
		"platform_ride_time": 0.0,
		"stuck_time_seconds": 0.0,
		"self_hazard_deaths": 0,
		"chest_opens": 0,
		"switch_presses": 0,
		"gate_uses": 0,
		"jump_pad_launches": 0,
		"mechanic_successes": 0,
		"mechanic_opportunities": 0,
		"duration_seconds": 0.0,
	}

static func _accumulate_batch_role_bucket(bucket: Dictionary, summary: Dictionary, won: bool, lost: bool, timed_out: bool, duration_seconds: float) -> void:
	bucket["runs"] = int(bucket.get("runs", 0)) + 1
	bucket["wins"] = int(bucket.get("wins", 0)) + (1 if won else 0)
	bucket["losses"] = int(bucket.get("losses", 0)) + (1 if lost else 0)
	bucket["timeouts"] = int(bucket.get("timeouts", 0)) + (1 if timed_out else 0)
	bucket["shots_fired"] = int(bucket.get("shots_fired", 0)) + int(summary.get("shots_fired", 0))
	bucket["shots_hit"] = int(bucket.get("shots_hit", 0)) + int(summary.get("shots_hit", 0))
	bucket["low_quality_shots"] = int(bucket.get("low_quality_shots", 0)) + int(summary.get("low_quality_shots", 0))
	bucket["dodge_opportunities"] = int(bucket.get("dodge_opportunities", 0)) + int(summary.get("dodge_opportunities", 0))
	bucket["successful_dodges"] = int(bucket.get("successful_dodges", 0)) + int(summary.get("successful_dodges", 0))
	bucket["stomp_attempts"] = int(bucket.get("stomp_attempts", 0)) + int(summary.get("stomp_attempts", 0))
	bucket["successful_stomps"] = int(bucket.get("successful_stomps", 0)) + int(summary.get("successful_stomps", 0))
	bucket["route_traversal_attempts"] = int(bucket.get("route_traversal_attempts", 0)) + int(summary.get("route_traversal_attempts", 0))
	bucket["route_traversal_successes"] = int(bucket.get("route_traversal_successes", 0)) + int(summary.get("route_traversal_successes", 0))
	bucket["route_failures"] = int(bucket.get("route_failures", 0)) + int(summary.get("route_failures", 0))
	bucket["wrap_count"] = int(bucket.get("wrap_count", 0)) + int(summary.get("wrap_count", 0))
	bucket["platform_board_attempts"] = int(bucket.get("platform_board_attempts", 0)) + int(summary.get("platform_board_attempts", 0))
	bucket["platform_board_success"] = int(bucket.get("platform_board_success", 0)) + int(summary.get("platform_board_success", 0))
	bucket["platform_ride_time"] = float(bucket.get("platform_ride_time", 0.0)) + float(summary.get("platform_ride_time", 0.0))
	bucket["stuck_time_seconds"] = float(bucket.get("stuck_time_seconds", 0.0)) + float(summary.get("stuck_time_seconds", 0.0))
	bucket["self_hazard_deaths"] = int(bucket.get("self_hazard_deaths", 0)) + int(summary.get("self_hazard_deaths", 0))
	bucket["chest_opens"] = int(bucket.get("chest_opens", 0)) + int(summary.get("chest_opens", 0))
	bucket["switch_presses"] = int(bucket.get("switch_presses", 0)) + int(summary.get("switch_presses", 0))
	bucket["gate_uses"] = int(bucket.get("gate_uses", 0)) + int(summary.get("gate_uses", 0))
	bucket["jump_pad_launches"] = int(bucket.get("jump_pad_launches", 0)) + int(summary.get("jump_pad_launches", 0))
	bucket["mechanic_successes"] = int(bucket.get("mechanic_successes", 0)) + int(summary.get("mechanic_successes", 0))
	bucket["mechanic_opportunities"] = int(bucket.get("mechanic_opportunities", 0)) + int(summary.get("mechanic_opportunities", 0))
	bucket["duration_seconds"] = float(bucket.get("duration_seconds", 0.0)) + duration_seconds

static func _finalize_batch_role_bucket(bucket: Dictionary) -> Dictionary:
	var runs: int = max(int(bucket.get("runs", 0)), 0)
	var shots_fired: int = max(int(bucket.get("shots_fired", 0)), 0)
	var dodge_opportunities: int = max(int(bucket.get("dodge_opportunities", 0)), 0)
	var stomp_attempts: int = max(int(bucket.get("stomp_attempts", 0)), 0)
	var route_attempts: int = max(int(bucket.get("route_traversal_attempts", 0)), 0)
	var platform_attempts: int = max(int(bucket.get("platform_board_attempts", 0)), 0)
	var mechanic_opportunities: int = max(int(bucket.get("mechanic_opportunities", 0)), 0)
	return {
		"runs": runs,
		"wins": int(bucket.get("wins", 0)),
		"losses": int(bucket.get("losses", 0)),
		"timeouts": int(bucket.get("timeouts", 0)),
		"win_rate": snappedf(float(bucket.get("wins", 0)) / max(runs, 1), 0.001),
		"timeout_rate": snappedf(float(bucket.get("timeouts", 0)) / max(runs, 1), 0.001),
		"no_timeout_rate": snappedf(1.0 - float(bucket.get("timeouts", 0)) / max(runs, 1), 0.001),
		"shots_fired": shots_fired,
		"shots_hit": int(bucket.get("shots_hit", 0)),
		"low_quality_shots": int(bucket.get("low_quality_shots", 0)),
		"accuracy_rate": snappedf(float(bucket.get("shots_hit", 0)) / max(shots_fired, 1), 0.001),
		"shot_discipline_rate": snappedf(1.0 - float(bucket.get("low_quality_shots", 0)) / max(shots_fired, 1), 0.001),
		"dodge_opportunities": dodge_opportunities,
		"successful_dodges": int(bucket.get("successful_dodges", 0)),
		"dodge_success_rate": snappedf(float(bucket.get("successful_dodges", 0)) / max(dodge_opportunities, 1), 0.001),
		"stomp_attempts": stomp_attempts,
		"successful_stomps": int(bucket.get("successful_stomps", 0)),
		"stomp_success_rate": snappedf(float(bucket.get("successful_stomps", 0)) / max(stomp_attempts, 1), 0.001),
		"route_traversal_attempts": route_attempts,
		"route_traversal_successes": int(bucket.get("route_traversal_successes", 0)),
		"route_success_rate": snappedf(float(bucket.get("route_traversal_successes", 0)) / max(route_attempts, 1), 0.001),
		"route_failures": int(bucket.get("route_failures", 0)),
		"wrap_count": int(bucket.get("wrap_count", 0)),
		"platform_board_attempts": platform_attempts,
		"platform_board_success": int(bucket.get("platform_board_success", 0)),
		"platform_board_rate": snappedf(float(bucket.get("platform_board_success", 0)) / max(platform_attempts, 1), 0.001),
		"platform_ride_time": snappedf(float(bucket.get("platform_ride_time", 0.0)), 0.001),
		"mean_stuck_time": snappedf(float(bucket.get("stuck_time_seconds", 0.0)) / max(runs, 1), 0.001),
		"stuck_time_seconds": snappedf(float(bucket.get("stuck_time_seconds", 0.0)), 0.001),
		"self_hazard_deaths": int(bucket.get("self_hazard_deaths", 0)),
		"no_self_hazard_rate": snappedf(1.0 - float(bucket.get("self_hazard_deaths", 0)) / max(runs, 1), 0.001),
		"chest_opens": int(bucket.get("chest_opens", 0)),
		"switch_presses": int(bucket.get("switch_presses", 0)),
		"gate_uses": int(bucket.get("gate_uses", 0)),
		"jump_pad_launches": int(bucket.get("jump_pad_launches", 0)),
		"mechanic_successes": int(bucket.get("mechanic_successes", 0)),
		"mechanic_opportunities": mechanic_opportunities,
		"mechanic_success_rate": snappedf(float(bucket.get("mechanic_successes", 0)) / max(mechanic_opportunities, 1), 0.001),
		"mean_duration_seconds": snappedf(float(bucket.get("duration_seconds", 0.0)) / max(runs, 1), 0.001),
	}

static func _score_role_summary(summary: Dictionary) -> float:
	return snappedf(100.0 * (
		0.40 * float(summary.get("win_rate", 0.0)) +
		0.15 * float(summary.get("no_timeout_rate", 0.0)) +
		0.15 * float(summary.get("no_self_hazard_rate", 0.0)) +
		0.10 * float(summary.get("shot_discipline_rate", 0.0)) +
		0.10 * float(summary.get("route_success_rate", 0.0)) +
		0.10 * float(summary.get("mechanic_success_rate", 0.0))
	), 0.001)

static func _build_summary_delta(candidate: Dictionary, opponent: Dictionary) -> Dictionary:
	return {
		"wins": int(candidate.get("wins", 0)) - int(opponent.get("wins", 0)),
		"losses": int(candidate.get("losses", 0)) - int(opponent.get("losses", 0)),
		"timeouts": int(candidate.get("timeouts", 0)) - int(opponent.get("timeouts", 0)),
		"win_rate": snappedf(float(candidate.get("win_rate", 0.0)) - float(opponent.get("win_rate", 0.0)), 0.001),
		"timeout_rate": snappedf(float(candidate.get("timeout_rate", 0.0)) - float(opponent.get("timeout_rate", 0.0)), 0.001),
		"accuracy_rate": snappedf(float(candidate.get("accuracy_rate", 0.0)) - float(opponent.get("accuracy_rate", 0.0)), 0.001),
		"shot_discipline_rate": snappedf(float(candidate.get("shot_discipline_rate", 0.0)) - float(opponent.get("shot_discipline_rate", 0.0)), 0.001),
		"dodge_success_rate": snappedf(float(candidate.get("dodge_success_rate", 0.0)) - float(opponent.get("dodge_success_rate", 0.0)), 0.001),
		"stomp_success_rate": snappedf(float(candidate.get("stomp_success_rate", 0.0)) - float(opponent.get("stomp_success_rate", 0.0)), 0.001),
		"route_success_rate": snappedf(float(candidate.get("route_success_rate", 0.0)) - float(opponent.get("route_success_rate", 0.0)), 0.001),
		"route_failures": int(candidate.get("route_failures", 0)) - int(opponent.get("route_failures", 0)),
		"platform_board_rate": snappedf(float(candidate.get("platform_board_rate", 0.0)) - float(opponent.get("platform_board_rate", 0.0)), 0.001),
		"mean_stuck_time": snappedf(float(candidate.get("mean_stuck_time", 0.0)) - float(opponent.get("mean_stuck_time", 0.0)), 0.001),
		"self_hazard_deaths": int(candidate.get("self_hazard_deaths", 0)) - int(opponent.get("self_hazard_deaths", 0)),
		"chest_opens": int(candidate.get("chest_opens", 0)) - int(opponent.get("chest_opens", 0)),
		"switch_presses": int(candidate.get("switch_presses", 0)) - int(opponent.get("switch_presses", 0)),
		"gate_uses": int(candidate.get("gate_uses", 0)) - int(opponent.get("gate_uses", 0)),
		"jump_pad_launches": int(candidate.get("jump_pad_launches", 0)) - int(opponent.get("jump_pad_launches", 0)),
		"wrap_count": int(candidate.get("wrap_count", 0)) - int(opponent.get("wrap_count", 0)),
		"mechanic_success_rate": snappedf(float(candidate.get("mechanic_success_rate", 0.0)) - float(opponent.get("mechanic_success_rate", 0.0)), 0.001),
	}

static func _increment_optional_counter(counter: Dictionary, key: String) -> void:
	if key.is_empty():
		return
	counter[key] = int(counter.get(key, 0)) + 1
