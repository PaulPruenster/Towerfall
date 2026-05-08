class_name WarpFieldEffect
extends "res://scripts/effects/arrow_lingering_effect.gd"

const BLACK_HOLE_SCENE: PackedScene = preload("res://scenes/effects/black_hole.tscn")
const OVERLAP_RADIUS_FACTOR: float = 0.42

static var _active_warp_fields: Dictionary = {}
static var _cluster_black_holes: Dictionary = {}

@export var field_size: Vector2 = Vector2(220.0, 220.0)
@export_range(0.0, 1.0, 0.01) var effect_opacity: float = 1.0
@export var decay_duration: float = 0.0
@export_range(0.0, 1.0, 0.01) var grow_amount: float = 0.16

@onready var field: ColorRect = $Field

var _base_scale: Vector2 = Vector2.ONE
var _start_opacity: float = 1.0
var _shader_material: ShaderMaterial

func _ready() -> void:
	_base_scale = scale
	_start_opacity = effect_opacity
	_update_field_rect()
	_register_warp_field()
	set_physics_process(true)

	var material := field.material as ShaderMaterial
	if material != null:
		_shader_material = material.duplicate() as ShaderMaterial
		field.material = _shader_material

	_apply_opacity(effect_opacity)
	super._ready()

	if decay_duration > 0.0:
		release(decay_duration)

func _process(delta: float) -> void:
	super._process(delta)

func _physics_process(_delta: float) -> void:
	_cleanup_invalid_registry_entries()
	if not _owns_cluster_registry_tick():
		return
	_update_black_hole_clusters()

func _exit_tree() -> void:
	_unregister_warp_field()

func set_field_size(new_field_size: Vector2) -> void:
	field_size = new_field_size
	_update_field_rect()

func set_effect_opacity(new_opacity: float) -> void:
	effect_opacity = clampf(new_opacity, 0.0, 1.0)
	_start_opacity = effect_opacity
	_apply_opacity(effect_opacity)

func start_decay(duration: float = decay_duration) -> void:
	release(duration)

func _on_release_started() -> void:
	_start_opacity = effect_opacity

func _on_release_progress(progress: float) -> void:
	_apply_opacity(lerpf(_start_opacity, 0.0, progress))
	scale = _base_scale * lerpf(1.0, 1.0 + grow_amount, progress)

func _apply_opacity(opacity: float) -> void:
	if _shader_material != null:
		_shader_material.set_shader_parameter("effect_opacity", opacity)

func _update_field_rect() -> void:
	if field == null:
		return
	field.position = -field_size * 0.5
	field.size = field_size

func get_effect_radius() -> float:
	var scale_factor: float = maxf(absf(scale.x), absf(scale.y))
	return min(field_size.x, field_size.y) * OVERLAP_RADIUS_FACTOR * scale_factor

func _register_warp_field() -> void:
	_active_warp_fields[get_instance_id()] = self

func _unregister_warp_field() -> void:
	_active_warp_fields.erase(get_instance_id())
	_cleanup_invalid_registry_entries()

func _update_black_hole_clusters() -> void:
	if not is_inside_tree():
		return

	var active_fields := _get_valid_warp_fields()
	var clusters := _build_overlap_clusters(active_fields)
	var seen_cluster_keys: Dictionary = {}
	var matched_black_holes: Dictionary = {}

	for cluster_variant in clusters:
		var cluster := cluster_variant as Array
		if cluster == null or cluster.size() < 2:
			continue

		var member_ids: Array = []
		var member_positions: Array = []
		for field_variant in cluster:
			var field := field_variant as WarpFieldEffect
			if field == null:
				continue
			member_ids.append(field.get_instance_id())
			member_positions.append(field.global_position)

		if member_ids.size() < 2:
			continue

		member_ids.sort()
		var cluster_key := _make_cluster_key(member_ids)
		seen_cluster_keys[cluster_key] = true

		var black_hole := _get_cluster_black_hole(cluster_key)
		if not _can_black_hole_accept_cluster_update(black_hole):
			black_hole = _find_reassignable_black_hole(member_ids, matched_black_holes)
			if black_hole != null:
				_set_black_hole_cluster_key(black_hole, cluster_key)
			else:
				black_hole = _spawn_black_hole(cluster_key)
		if black_hole == null:
			continue

		matched_black_holes[black_hole.get_instance_id()] = true
		if black_hole.has_method("update_cluster"):
			black_hole.call("update_cluster", member_ids, member_positions)

	for cluster_key_variant in _cluster_black_holes.keys():
		var cluster_key := str(cluster_key_variant)
		if seen_cluster_keys.has(cluster_key):
			continue
		var black_hole := _get_cluster_black_hole(cluster_key)
		if black_hole == null:
			continue
		if black_hole.has_method("is_charge_pending") and bool(black_hole.call("is_charge_pending")):
			black_hole.call("cancel_charge")

func _is_overlapping(other_field: WarpFieldEffect) -> bool:
	return global_position.distance_to(other_field.global_position) <= get_effect_radius() + other_field.get_effect_radius()

func _get_valid_warp_fields() -> Array:
	var active_fields: Array = []
	for field_id_variant in _active_warp_fields.keys():
		var field = _active_warp_fields.get(int(field_id_variant)) as WarpFieldEffect
		if field != null and is_instance_valid(field):
			active_fields.append(field)
	active_fields.sort_custom(_sort_warp_fields_by_id)
	return active_fields

func _build_overlap_clusters(active_fields: Array) -> Array:
	var clusters: Array = []
	var visited_ids: Dictionary = {}

	for field_variant in active_fields:
		var field := field_variant as WarpFieldEffect
		if field == null:
			continue
		var field_id := field.get_instance_id()
		if visited_ids.has(field_id):
			continue

		var cluster: Array = []
		var stack: Array = [field]
		visited_ids[field_id] = true

		while not stack.is_empty():
			var current := stack.pop_back() as WarpFieldEffect
			if current == null:
				continue
			cluster.append(current)

			for other_variant in active_fields:
				var other_field := other_variant as WarpFieldEffect
				if other_field == null:
					continue
				var other_id := other_field.get_instance_id()
				if visited_ids.has(other_id):
					continue
				if current._is_overlapping(other_field):
					visited_ids[other_id] = true
					stack.append(other_field)

		clusters.append(cluster)

	return clusters

func _spawn_black_hole(cluster_key: String) -> Node2D:
	var black_hole := BLACK_HOLE_SCENE.instantiate() as Node2D
	if black_hole == null:
		return null
	black_hole.top_level = true
	black_hole.z_as_relative = false
	black_hole.z_index = 55
	if black_hole.has_method("configure"):
		black_hole.call("configure", cluster_key)

	var scene_root := get_tree().current_scene
	if scene_root == null:
		scene_root = get_tree().root
	scene_root.add_child(black_hole)
	_cluster_black_holes[cluster_key] = black_hole
	return black_hole

func _find_reassignable_black_hole(member_ids: Array, matched_black_holes: Dictionary) -> Node2D:
	var best_black_hole: Node2D
	var best_overlap_score := 0

	for cluster_key_variant in _cluster_black_holes.keys():
		var black_hole := _get_cluster_black_hole(str(cluster_key_variant))
		if black_hole == null:
			continue
		if matched_black_holes.has(black_hole.get_instance_id()):
			continue
		if not _can_black_hole_accept_cluster_update(black_hole):
			continue
		if not black_hole.has_method("get_member_overlap_score"):
			continue

		var overlap_score := int(black_hole.call("get_member_overlap_score", member_ids))
		if overlap_score <= best_overlap_score:
			continue
		best_overlap_score = overlap_score
		best_black_hole = black_hole

	return best_black_hole if best_overlap_score > 0 else null

func _set_black_hole_cluster_key(black_hole: Node2D, cluster_key: String) -> void:
	if black_hole == null:
		return

	if black_hole.has_method("get_cluster_key"):
		var previous_key := str(black_hole.call("get_cluster_key"))
		if previous_key != "":
			_cluster_black_holes.erase(previous_key)
	if black_hole.has_method("set_cluster_key"):
		black_hole.call("set_cluster_key", cluster_key)
	_cluster_black_holes[cluster_key] = black_hole

func _get_cluster_black_hole(cluster_key: String) -> Node2D:
	var black_hole = _cluster_black_holes.get(cluster_key)
	if black_hole == null:
		return
	if not is_instance_valid(black_hole):
		_cluster_black_holes.erase(cluster_key)
		return null
	return black_hole as Node2D

func _can_black_hole_accept_cluster_update(black_hole: Node2D) -> bool:
	if black_hole == null or not is_instance_valid(black_hole):
		return false
	if not black_hole.has_method("can_accept_cluster_update"):
		return false
	return bool(black_hole.call("can_accept_cluster_update"))

func _cleanup_invalid_registry_entries() -> void:
	for field_id_variant in _active_warp_fields.keys():
		var field_id := int(field_id_variant)
		var field = _active_warp_fields.get(field_id)
		if field == null or not is_instance_valid(field):
			_active_warp_fields.erase(field_id)

	for cluster_key in _cluster_black_holes.keys():
		var black_hole = _cluster_black_holes.get(cluster_key)
		if black_hole == null or not is_instance_valid(black_hole):
			_cluster_black_holes.erase(cluster_key)

func _owns_cluster_registry_tick() -> bool:
	for field_id_variant in _active_warp_fields.keys():
		if int(field_id_variant) < get_instance_id():
			return false
	return true

func _sort_warp_fields_by_id(a: WarpFieldEffect, b: WarpFieldEffect) -> bool:
	return a.get_instance_id() < b.get_instance_id()

func _make_cluster_key(member_ids: Array) -> String:
	var segments: PackedStringArray = []
	for member_id_variant in member_ids:
		segments.append(str(int(member_id_variant)))
	return ":".join(segments)
