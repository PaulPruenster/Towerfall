extends SceneTree

const GATE_SCENE := preload("res://scenes/gameplay/gate.tscn")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test_gate_activates_for_player_already_inside()
	await _test_gate_activates_when_enabled_under_player()
	await _test_gate_reactivates_for_stationary_player()

	if _failures.is_empty():
		print("gate smoke test passed")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)

func _test_gate_activates_for_player_already_inside() -> void:
	var arena := _make_arena()
	var gates: Array[Node2D] = _spawn_gate_pair(arena, true)
	var source_gate: Node2D = gates[0]
	var target_gate: Node2D = gates[1]
	var player := _spawn_dummy_player(arena, source_gate.global_position)

	await _settle_frames(90)
	_assert(player.global_position.distance_to(target_gate.global_position) < 1.0, "Expected overlapping player to be teleported to the target gate")
	await _cleanup_arena(arena)

func _test_gate_activates_when_enabled_under_player() -> void:
	var arena := _make_arena()
	var gates: Array[Node2D] = _spawn_gate_pair(arena, false)
	var source_gate: Node2D = gates[0]
	var target_gate: Node2D = gates[1]
	var player := _spawn_dummy_player(arena, source_gate.global_position)

	await _settle_frames(4)
	source_gate.call("set_gate_enabled", true)
	await _settle_frames(90)
	_assert(player.global_position.distance_to(target_gate.global_position) < 1.0, "Expected enabled-under-player gate to teleport immediately without re-entry")
	await _cleanup_arena(arena)

func _test_gate_reactivates_for_stationary_player() -> void:
	var arena := _make_arena()
	var gates: Array[Node2D] = _spawn_gate_pair(arena, true)
	var source_gate: Node2D = gates[0]
	var player := _spawn_dummy_player(arena, source_gate.global_position)

	await _settle_frames(220)
	_assert(player.global_position.distance_to(source_gate.global_position) < 1.0, "Expected gate to react again for a player who remains inside without leaving and re-entering")
	await _cleanup_arena(arena)

func _make_arena() -> Node2D:
	var arena := Node2D.new()
	root.add_child(arena)
	current_scene = arena
	return arena

func _spawn_gate_pair(parent: Node, source_starts_enabled: bool) -> Array[Node2D]:
	var source_gate: Node2D = GATE_SCENE.instantiate() as Node2D
	source_gate.name = "GateA"
	source_gate.set("starts_enabled", source_starts_enabled)
	parent.add_child(source_gate)

	var target_gate: Node2D = GATE_SCENE.instantiate() as Node2D
	target_gate.name = "GateB"
	target_gate.set("starts_enabled", true)
	parent.add_child(target_gate)

	source_gate.global_position = Vector2(120.0, 220.0)
	target_gate.global_position = Vector2(360.0, 220.0)
	source_gate.set("target_node", source_gate.get_path_to(target_gate))
	target_gate.set("target_node", target_gate.get_path_to(source_gate))
	return [source_gate, target_gate]

func _spawn_dummy_player(parent: Node, position: Vector2) -> CharacterBody2D:
	var player := CharacterBody2D.new()
	player.add_to_group("player")
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(18.0, 36.0)
	collision.shape = shape
	player.add_child(collision)
	parent.add_child(player)
	player.global_position = position
	return player

func _settle_frames(frame_count: int) -> void:
	for _index in range(frame_count):
		await physics_frame
		await process_frame

func _cleanup_arena(arena: Node) -> void:
	if arena != null and is_instance_valid(arena):
		arena.queue_free()
	current_scene = null
	await process_frame

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
