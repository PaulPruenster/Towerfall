extends SceneTree

const PLAYER_SCENE := preload("res://scenes/actors/player.tscn")
const SPIKES_SCENE := preload("res://scenes/gameplay/spikes.tscn")

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
	await _test_impossible_gap_stop()
	await _test_simple_gap_jump()
	await _test_chest_priority_when_empty()
	await _test_switch_priority()
	await _test_wall_jump_route()
	await _test_pad_route_steering()
	await _test_stomp_choice()
	await _test_spike_avoidance()
	await _test_special_arrow_availability()
	await _test_recover_goal_priority()
	await _test_wrap_side_choice()

	if _failures.is_empty():
		print("ai smoke test passed")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)

func _test_impossible_gap_stop() -> void:
	var arena := _make_arena()
	_spawn_ground(arena, Vector2(140.0, 290.0), Vector2(160.0, 18.0))
	_spawn_ground(arena, Vector2(470.0, 290.0), Vector2(120.0, 18.0))
	var ai_player := _spawn_player(arena, Vector2(195.0, 250.0))
	var target_player := _spawn_player(arena, Vector2(470.0, 250.0))
	ai_player.arrow_count = 0
	ai_player.special_arrow_count = 0
	var ai := _get_ai(ai_player)
	ai.enabled = true
	await _settle_player_on_floor(ai_player)
	await _settle_player_on_floor(target_player)

	ai_player.global_position.x = 196.0
	var movement_plan := ai._apply_movement_safety(Vector2.RIGHT, false)
	var direction := _get_control_direction(movement_plan)
	_assert(direction == Vector2.ZERO and not bool(movement_plan.get("jump_pressed", false)), "Expected AI to stop at an impossible gap")
	await _cleanup_arena(arena)

func _test_simple_gap_jump() -> void:
	var arena := _make_arena()
	_spawn_ground(arena, Vector2(120.0, 290.0), Vector2(160.0, 18.0))
	_spawn_ground(arena, Vector2(360.0, 290.0), Vector2(160.0, 18.0))
	var ai_player := _spawn_player(arena, Vector2(194.0, 250.0))
	var target_player := _spawn_player(arena, Vector2(380.0, 250.0))
	ai_player.arrow_count = 0
	ai_player.special_arrow_count = 0
	var ai := _get_ai(ai_player)
	ai.enabled = true
	await _settle_player_on_floor(ai_player)
	await _settle_player_on_floor(target_player)

	ai_player.global_position.x = 196.0
	var movement_plan := ai._apply_movement_safety(Vector2.RIGHT, false)
	var direction := _get_control_direction(movement_plan)
	_assert(direction.x > 0.0 and bool(movement_plan.get("jump_pressed", false)), "Expected AI to jump a simple gap toward the target")
	await _cleanup_arena(arena)

func _test_chest_priority_when_empty() -> void:
	var arena := _make_arena()
	_spawn_ground(arena, Vector2(320.0, 290.0), Vector2(640.0, 18.0))
	var ai_player := _spawn_player(arena, Vector2(180.0, 250.0))
	var target_player := _spawn_player(arena, Vector2(520.0, 250.0))
	var chest := DummyChest.new()
	chest.position = Vector2(240.0, 250.0)
	arena.add_child(chest)
	ai_player.arrow_count = 0
	ai_player.special_arrow_count = 0
	var ai := _get_ai(ai_player)
	ai.enabled = true
	await _settle_player_on_floor(ai_player)
	await _settle_player_on_floor(target_player)

	ai.get_control_state(1.0 / 60.0)
	_assert(ai.goal_type == AIController.GoalType.CHEST and ai.goal_node == chest, "Expected empty AI to prioritize a nearby chest")
	await _cleanup_arena(arena)

func _test_switch_priority() -> void:
	var arena := _make_arena()
	_spawn_ground(arena, Vector2(320.0, 290.0), Vector2(640.0, 18.0))
	var ai_player := _spawn_player(arena, Vector2(100.0, 250.0))
	var target_player := _spawn_player(arena, Vector2(500.0, 250.0))
	var exit_gate := DummyGate.new()
	exit_gate.position = Vector2(460.0, 250.0)
	arena.add_child(exit_gate)
	var entry_gate := DummyGate.new()
	entry_gate.position = Vector2(180.0, 250.0)
	entry_gate.target_gate = exit_gate
	entry_gate.gate_enabled = false
	arena.add_child(entry_gate)
	var switch_node := DummySwitch.new()
	switch_node.position = Vector2(160.0, 250.0)
	switch_node.controlled_gates = [entry_gate]
	arena.add_child(switch_node)
	var ai := _get_ai(ai_player)
	ai.enabled = true
	await _settle_player_on_floor(ai_player)
	await _settle_player_on_floor(target_player)

	ai.get_control_state(1.0 / 60.0)
	_assert(ai.goal_type == AIController.GoalType.SWITCH and ai.goal_node == switch_node, "Expected AI to prioritize a useful switch route")
	await _cleanup_arena(arena)

func _test_wall_jump_route() -> void:
	var arena := _make_arena()
	_spawn_ground(arena, Vector2(200.0, 290.0), Vector2(240.0, 18.0))
	var ai_player := _spawn_player(arena, Vector2(220.0, 250.0))
	var chest := DummyChest.new()
	chest.position = Vector2(340.0, 150.0)
	arena.add_child(chest)
	var routes := Node2D.new()
	routes.name = "AIRoutes"
	arena.add_child(routes)
	var start_point := _spawn_route_point(routes, "Start", Vector2(220.0, 268.0))
	var top_point := _spawn_route_point(routes, "Top", Vector2(340.0, 150.0))
	var wall_jump_link := _spawn_route_link(start_point, top_point, AIRouteLink.TraversalType.WALL_JUMP, 26.0, null, 1)
	var ai := _get_ai(ai_player)
	await _settle_player_on_floor(ai_player)

	ai_player.global_position = start_point.global_position
	ai.current_route_step = {
		"focus_position": top_point.global_position,
		"source_point": start_point,
		"target_point": top_point,
		"link": wall_jump_link,
		"traversal_type": AIRouteLink.TraversalType.WALL_JUMP,
		"activation_distance": 26.0,
		"wall_contact_direction": 1,
	}
	var control := ai._build_route_link_control_state()
	var direction := _get_control_direction(control)
	_assert(ai.current_route_step.get("link") == wall_jump_link, "Expected wall-jump route selection")
	_assert(direction.x > 0.0 and direction.y < 0.0 and bool(control.get("jump_pressed", false)), "Expected wall-jump execution input")
	await _cleanup_arena(arena)

func _test_pad_route_steering() -> void:
	var arena := _make_arena()
	var ground := _spawn_ground(arena, Vector2(140.0, 290.0), Vector2(180.0, 18.0))
	var ai_player := _spawn_player(arena, Vector2(180.0, 250.0))
	var chest := DummyChest.new()
	chest.position = Vector2(420.0, 160.0)
	arena.add_child(chest)
	var routes := Node2D.new()
	routes.name = "AIRoutes"
	arena.add_child(routes)
	var helper := Marker2D.new()
	helper.position = Vector2(240.0, 268.0)
	routes.add_child(helper)
	var start_point := _spawn_route_point(routes, "PadStart", Vector2(180.0, 268.0))
	var landing_point := _spawn_route_point(routes, "PadLanding", Vector2(420.0, 160.0))
	var pad_link := _spawn_route_link(start_point, landing_point, AIRouteLink.TraversalType.PAD, 28.0, helper, 0)
	var ai := _get_ai(ai_player)
	await _settle_player_on_floor(ai_player)

	ai_player.global_position = start_point.global_position
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
	_assert(_get_control_direction(floor_control).x > 0.0, "Expected pad approach steering toward the helper lane")

	var air_player := _spawn_player(arena, Vector2(300.0, 140.0))
	var air_ai := _get_ai(air_player)
	await _settle_player_off_floor(air_player)
	air_ai.current_route_step = {
		"focus_position": landing_point.global_position,
		"source_point": start_point,
		"target_point": landing_point,
		"link": pad_link,
		"traversal_type": AIRouteLink.TraversalType.PAD,
		"activation_distance": 28.0,
		"helper_node": helper,
	}
	var air_control := air_ai._build_route_link_control_state()
	_assert(_get_control_direction(air_control).x > 0.0, "Expected airborne pad steering toward the landing point")
	await _cleanup_arena(arena)

func _test_stomp_choice() -> void:
	var arena := _make_arena()
	_spawn_ground(arena, Vector2(320.0, 290.0), Vector2(640.0, 18.0))
	var ai_player := _spawn_player(arena, Vector2(220.0, 170.0))
	var target_player := _spawn_player(arena, Vector2(230.0, 268.0))
	var ai := _get_ai(ai_player)
	await _settle_player_on_floor(target_player)
	await _settle_frames(2)

	ai.target = target_player
	var stomp_window := ai._get_stomp_window()
	_assert(bool(stomp_window.get("available", false)), "Expected a stomp window in a simple vertical duel")
	_assert(ai._should_prioritize_stomp(stomp_window, {}), "Expected stomp choice when no disciplined shot is available")
	await _cleanup_arena(arena)

func _test_spike_avoidance() -> void:
	var arena := _make_arena()
	_spawn_ground(arena, Vector2(320.0, 290.0), Vector2(640.0, 18.0))
	var spikes := SPIKES_SCENE.instantiate() as Area2D
	spikes.position = Vector2(250.0, 276.0)
	arena.add_child(spikes)
	var ai_player := _spawn_player(arena, Vector2(200.0, 250.0))
	var target_player := _spawn_player(arena, Vector2(470.0, 250.0))
	ai_player.arrow_count = 0
	ai_player.special_arrow_count = 0
	var ai := _get_ai(ai_player)
	ai.enabled = true
	await _settle_player_on_floor(ai_player)
	await _settle_player_on_floor(target_player)

	ai_player.global_position.x = 208.0
	var path_assessment := ai._assess_forward_path(1)
	var movement_plan := ai._apply_movement_safety(Vector2.RIGHT, false)
	_assert(bool(path_assessment.get("hazard", false)) and bool(path_assessment.get("blocked", false)), "Expected hazard probing to detect spikes ahead")
	_assert(not (_get_control_direction(movement_plan).x > 0.0 and not bool(movement_plan.get("jump_pressed", false))), "Expected AI to avoid blindly charging into spikes")
	await _cleanup_arena(arena)

func _test_special_arrow_availability() -> void:
	var arena := _make_arena()
	_spawn_ground(arena, Vector2(320.0, 290.0), Vector2(640.0, 18.0))
	var ai_player := _spawn_player(arena, Vector2(180.0, 250.0))
	var target_player := _spawn_player(arena, Vector2(460.0, 250.0))
	ai_player.arrow_count = 0
	ai_player.special_arrow_count = 2
	ai_player.special_arrow_type = Arrow.ArrowType.EXPLOSIVE
	var ai := _get_ai(ai_player)
	ai.enabled = true
	await _settle_player_on_floor(ai_player)
	await _settle_player_on_floor(target_player)

	_assert(ai_player.has_available_ammo(), "Expected has_available_ammo() true when only special ammo remains")
	_assert(ai_player.get_total_arrow_count() == 2, "Expected total arrow count to include special arrows when normal ammo is 0")
	ai.get_control_state(1.0 / 60.0)
	_assert(ai.goal_type != AIController.GoalType.RECOVER, "Expected AI not to choose RECOVER goal when special ammo is available")
	await _cleanup_arena(arena)

func _test_recover_goal_priority() -> void:
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
	_assert(ai.goal_type == AIController.GoalType.RECOVER, "Expected RECOVER goal when health=1, ammo=0, and target is at close range")
	await _cleanup_arena(arena)

func _test_wrap_side_choice() -> void:
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

	# Position player near right wrap edge so the wrap route to target is shorter
	ai_player.global_position.x = viewport_size.x - 50.0
	# Target at ~35% of viewport width: wrapped delta.x is positive and > 25% of viewport
	target_player.global_position.x = viewport_size.x * 0.35
	ai.target = target_player
	ai.goal_type = AIController.GoalType.FIGHT
	ai.state = AIController.AIState.APPROACH

	var path_assessment := {"blocked": true, "hazard": false, "jumpable": false}
	var can_wrap := ai._can_commit_to_wrap_route(1, path_assessment)
	_assert(can_wrap, "Expected AI to commit to right-edge wrap route when direct path is blocked and wrap route is shorter")
	await _cleanup_arena(arena)

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

func _spawn_route_link(source: AIRoutePoint, target: AIRoutePoint, traversal_type: int, activation_distance: float, helper_node: Node2D, wall_contact_direction: int) -> AIRouteLink:
	var link := AIRouteLink.new()
	source.add_child(link)
	link.target_point_path = source.get_path_to(target)
	link.traversal_type = traversal_type
	link.activation_distance = activation_distance
	link.wall_contact_direction = wall_contact_direction
	if helper_node != null:
		link.helper_node_path = source.get_path_to(helper_node)
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

func _settle_player_off_floor(player: Player, max_frames: int = 12) -> void:
	for _index in range(max_frames):
		await _settle_frames(1)
		if not player.is_on_floor():
			return

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
