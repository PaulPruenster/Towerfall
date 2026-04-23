extends Node2D

signal teleported(player, source_gate, target_gate)

const ARRIVAL_IGNORE_TIME: float = 1.0

@export_node_path("Node2D") var target_node: NodePath
@export var starts_enabled: bool = true

@onready var area: Area2D = $Sprite2D/Area2D
@onready var collision_polygon: CollisionPolygon2D = $Sprite2D/Area2D/CollisionPolygon2D
@onready var ap: AnimationPlayer = $AnimationPlayer

var player_in_area: CharacterBody2D
var gate_ready_to_open: bool = true
var ignore_player: CharacterBody2D
var ignore_player_time_left: float = 0.0
var gate_enabled: bool = true

func _ready() -> void:
	gate_enabled = starts_enabled
	gate_ready_to_open = true
	player_in_area = null
	_clear_ignored_player()
	_update_visual_state()
	call_deferred("_refresh_overlap_after_ready")

func set_gate_enabled(is_enabled: bool) -> void:
	gate_enabled = is_enabled
	if not gate_enabled:
		player_in_area = null
	_clear_ignored_player()
	_update_visual_state()
	if gate_enabled:
		call_deferred("_refresh_overlap_after_ready")

func is_gate_enabled() -> bool:
	return gate_enabled

func get_target_gate() -> Node2D:
	return get_node_or_null(target_node) as Node2D

func _update_visual_state() -> void:
	modulate = Color.WHITE if gate_enabled else Color(0.45, 0.45, 0.45, 1.0)

func _refresh_overlap_after_ready() -> void:
	if not is_inside_tree():
		return
	await get_tree().physics_frame
	_refresh_overlapping_player()

func _physics_process(delta: float) -> void:
	if ignore_player != null:
		ignore_player_time_left = max(ignore_player_time_left - delta, 0.0)
		if ignore_player_time_left <= 0.0:
			_clear_ignored_player()

	if player_in_area != null and (not is_instance_valid(player_in_area) or not _is_player_inside_gate(player_in_area)):
		player_in_area = null

	if gate_enabled and gate_ready_to_open:
		_refresh_overlapping_player()

func _refresh_overlapping_player() -> void:
	if area == null:
		return

	if player_in_area != null and is_instance_valid(player_in_area) and _is_player_inside_gate(player_in_area):
		_try_activate_for_player(player_in_area)
		return
	player_in_area = null

	for body in area.get_overlapping_bodies():
		var player := body as CharacterBody2D
		if player == null or not player.is_in_group("player"):
			continue
		_try_activate_for_player(player)
		return

	for player in _find_players_inside_gate():
		_try_activate_for_player(player)
		return

func _find_players_inside_gate() -> Array[CharacterBody2D]:
	var players_inside: Array[CharacterBody2D] = []
	if collision_polygon == null or get_tree() == null:
		return players_inside

	for node in get_tree().get_nodes_in_group("player"):
		var player := node as CharacterBody2D
		if player == null:
			continue
		if _is_player_inside_gate(player):
			players_inside.append(player)

	return players_inside

func _is_player_inside_gate(player: CharacterBody2D) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	if area != null and area.get_overlapping_bodies().has(player):
		return true
	return _is_point_inside_gate(player.global_position)

func _is_point_inside_gate(point: Vector2) -> bool:
	if collision_polygon == null:
		return false

	var global_polygon := PackedVector2Array()
	for polygon_point in collision_polygon.polygon:
		global_polygon.append(collision_polygon.to_global(polygon_point))
	return not global_polygon.is_empty() and Geometry2D.is_point_in_polygon(point, global_polygon)

func _set_ignored_player(player: CharacterBody2D, duration: float = ARRIVAL_IGNORE_TIME) -> void:
	ignore_player = player
	ignore_player_time_left = duration

func _clear_ignored_player() -> void:
	ignore_player = null
	ignore_player_time_left = 0.0

func _accept_arriving_player(player: CharacterBody2D) -> void:
	player_in_area = player
	_set_ignored_player(player)

func _try_activate_for_player(player: CharacterBody2D) -> void:
	if player == null or not is_instance_valid(player):
		return

	player_in_area = player
	if not gate_enabled or not gate_ready_to_open or ignore_player == player:
		return

	GameSfx.play(self, &"gate_open", global_position)
	ap.play("open")
	gate_ready_to_open = false

func _on_area_2d_body_entered(body: Node) -> void:
	var player := body as CharacterBody2D
	if player != null and player.is_in_group("player"):
		_try_activate_for_player(player)

func _on_area_2d_body_exited(body: Node) -> void:
	var player := body as CharacterBody2D
	if player == player_in_area:
		player_in_area = null
	if player == ignore_player:
		_clear_ignored_player()

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "open":
		var target_gate := get_target_gate()
		if player_in_area != null and target_gate != null:
			if target_gate.has_method("_accept_arriving_player"):
				target_gate.call("_accept_arriving_player", player_in_area)
			player_in_area.global_position = target_gate.global_position
			GameSfx.play(self, &"gate_teleport", global_position)
			teleported.emit(player_in_area, self, target_gate)
		ap.play("close")
	if anim_name == "close":
		ap.play("RESET")
		gate_ready_to_open = true
		player_in_area = null
		call_deferred("_refresh_overlap_after_ready")
