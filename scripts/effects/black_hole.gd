class_name BlackHoleEffect
extends Node2D

enum State {
	CHARGING,
	ACTIVE,
	VANISHING,
	CANCELING,
}

const OVERLAP_GRACE_TIME: float = 0.18
const BASE_PULL_RADIUS: float = 250.0
const BASE_CORE_RADIUS: float = 30.0
const BASE_VISUAL_RADIUS: float = 62.0
const BASE_WARP_FIELD_SIZE: Vector2 = Vector2(360.0, 360.0)
const CENTER_HOLD_TIME: float = 0.7
const CENTER_DAMAGE_COOLDOWN: float = 0.8
const CONTRIBUTOR_BLEND_SPEED: float = 4.0
const PLAYER_PULL_FALLOFF_EXPONENT: float = 0.62
const OBJECT_PULL_FALLOFF_EXPONENT: float = 1.22
const PLAYER_PULL_STRENGTH_MULTIPLIER: float = 2.05

@export var charge_duration: float = 3.0
@export var active_duration: float = 5.0
@export var vanish_duration: float = 3.0
@export var cancel_duration: float = 0.2

@onready var warp_field: ColorRect = $WarpField

var state: int = State.CHARGING
var _state_elapsed: float = 0.0
var _visual_time: float = 0.0
var _cluster_key: String = ""
var _cluster_member_ids: Array = []
var _contributor_count: int = 2
var _target_extra_contributors: float = 0.0
var _smoothed_extra_contributors: float = 0.0
var _has_cluster_profile: bool = false
var _charge_center: Vector2 = Vector2.ZERO
var _refresh_time_left: float = 0.0
var _cancel_start_strength: float = 0.0
var _core_hold_times: Dictionary = {}
var _core_damage_cooldowns: Dictionary = {}
var _warp_material: ShaderMaterial

func _ready() -> void:
	var material := warp_field.material as ShaderMaterial
	if material != null:
		_warp_material = material.duplicate() as ShaderMaterial
		warp_field.material = _warp_material
	set_process(true)
	set_physics_process(true)
	_update_warp_visual()
	queue_redraw()

func configure(cluster_key: String) -> void:
	_cluster_key = cluster_key

func set_cluster_key(cluster_key: String) -> void:
	_cluster_key = cluster_key

func get_cluster_key() -> String:
	return _cluster_key

func can_accept_cluster_update() -> bool:
	return state == State.CHARGING or state == State.ACTIVE

func is_charge_pending() -> bool:
	return state == State.CHARGING

func get_member_overlap_score(member_ids: Array) -> int:
	var overlap_score := 0
	for member_id_variant in member_ids:
		if _cluster_member_ids.has(int(member_id_variant)):
			overlap_score += 1
	return overlap_score

func get_contributor_count() -> int:
	return _contributor_count

func update_cluster(member_ids: Array, member_positions: Array) -> void:
	_cluster_member_ids = member_ids.duplicate()
	_contributor_count = maxi(_cluster_member_ids.size(), 2)
	_target_extra_contributors = float(maxi(_contributor_count - 2, 0))
	if not _has_cluster_profile:
		_smoothed_extra_contributors = _target_extra_contributors
		_has_cluster_profile = true
	var cluster_center := _compute_cluster_center(member_positions)
	if state == State.CHARGING:
		_charge_center = cluster_center
		global_position = cluster_center
		_refresh_time_left = OVERLAP_GRACE_TIME
	_update_warp_visual()

func cancel_charge() -> void:
	if state != State.CHARGING:
		return
	_begin_cancel()

func _process(delta: float) -> void:
	_state_elapsed += delta
	_visual_time += delta
	_update_contributor_profile(delta)

	match state:
		State.CHARGING:
			_refresh_time_left = maxf(_refresh_time_left - delta, 0.0)
			global_position = _charge_center
			if _refresh_time_left <= 0.0:
				_begin_cancel()
			elif _state_elapsed >= charge_duration:
				_begin_active()
		State.ACTIVE:
			if _state_elapsed >= active_duration:
				_begin_vanishing()
		State.VANISHING:
			if _state_elapsed >= vanish_duration:
				queue_free()
				return
		State.CANCELING:
			if _state_elapsed >= cancel_duration:
				queue_free()
				return

	_update_warp_visual()
	queue_redraw()

func _physics_process(delta: float) -> void:
	var phase_strength := _get_force_phase_strength()
	if phase_strength <= 0.0:
		return
	_apply_black_hole_forces(delta, phase_strength)

func _draw() -> void:
	var strength: float = _get_visual_strength()
	if strength <= 0.001:
		return

	var visual_radius: float = BASE_VISUAL_RADIUS * strength * _get_size_multiplier()
	var aura_radius: float = visual_radius * (1.25 + 0.08 * sin(_visual_time * 3.2))
	var ring_radius: float = visual_radius * (0.76 + 0.04 * sin(_visual_time * 5.4))
	var core_radius: float = visual_radius * 0.58
	var ring_width: float = maxf(visual_radius * 0.09, 2.0)
	var swirl_offset: Vector2 = Vector2.RIGHT.rotated(_visual_time * 1.8) * visual_radius * 0.12

	draw_circle(Vector2.ZERO, aura_radius, Color(0.02, 0.02, 0.04, 0.18 * strength))
	draw_circle(swirl_offset, visual_radius * 0.82, Color(0.04, 0.04, 0.06, 0.12 * strength))
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 48, Color(0.78, 0.84, 0.9, 0.34 * strength), ring_width, true)
	draw_circle(Vector2.ZERO, core_radius, Color(0.0, 0.0, 0.0, 0.96))

func _get_visual_strength() -> float:
	match state:
		State.CHARGING:
			var progress: float = clampf(_state_elapsed / maxf(charge_duration, 0.001), 0.0, 1.0)
			return ease(progress, 0.55)
		State.ACTIVE:
			return 1.0
		State.VANISHING:
			var progress: float = clampf(_state_elapsed / maxf(vanish_duration, 0.001), 0.0, 1.0)
			return 1.0 - ease(progress, 1.3)
		State.CANCELING:
			var progress: float = clampf(_state_elapsed / maxf(cancel_duration, 0.001), 0.0, 1.0)
			return _cancel_start_strength * (1.0 - ease(progress, 1.1))
		_:
			return 0.0

func _get_force_phase_strength() -> float:
	match state:
		State.ACTIVE:
			return 1.0
		State.VANISHING:
			return clampf(1.0 - (_state_elapsed / maxf(vanish_duration, 0.001)), 0.0, 1.0)
		_:
			return 0.0

func _begin_active() -> void:
	state = State.ACTIVE
	_state_elapsed = 0.0
	GameSfx.play(self, &"black_hole_birth", global_position, randf_range(0.96, 1.03))
	var scene: Node = get_tree().current_scene
	if scene != null and scene.has_method("trigger_screenshake"):
		scene.trigger_screenshake(8.0, 0.14)

func _begin_vanishing() -> void:
	state = State.VANISHING
	_state_elapsed = 0.0
	GameSfx.play(self, &"black_hole_fade", global_position, randf_range(0.98, 1.04))

func _begin_cancel() -> void:
	if state == State.CANCELING:
		return
	_cancel_start_strength = _get_visual_strength()
	state = State.CANCELING
	_state_elapsed = 0.0

func _apply_black_hole_forces(delta: float, phase_strength: float) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return

	var size_multiplier := _get_size_multiplier()
	var pull_radius: float = BASE_PULL_RADIUS * size_multiplier * maxf(phase_strength, 0.35)
	var core_radius: float = BASE_CORE_RADIUS * size_multiplier * maxf(phase_strength, 0.6)
	var force_multiplier := _get_force_multiplier()
	_tick_core_damage_cooldowns(delta)

	for node in tree.get_nodes_in_group("black_hole_pullable"):
		if node == null or not is_instance_valid(node):
			continue
		if not (node is Node2D):
			continue

		var actor: Node2D = node as Node2D
		var distance: float = actor.global_position.distance_to(global_position)
		if distance > pull_radius:
			_decay_core_exposure(actor.get_instance_id(), delta)
			continue

		var falloff: float = 1.0 - (distance / maxf(pull_radius, 0.001))
		var is_player := actor.is_in_group("player")
		var falloff_exponent := PLAYER_PULL_FALLOFF_EXPONENT if is_player else OBJECT_PULL_FALLOFF_EXPONENT
		var pull_strength: float = pow(falloff, falloff_exponent) * force_multiplier * phase_strength
		if is_player:
			pull_strength *= PLAYER_PULL_STRENGTH_MULTIPLIER
		if actor.has_method("apply_black_hole_pull"):
			actor.call("apply_black_hole_pull", global_position, pull_strength, delta)

		if is_player:
			_update_player_core_exposure(actor, distance <= core_radius, delta)

func _tick_core_damage_cooldowns(delta: float) -> void:
	for player_id_variant in _core_damage_cooldowns.keys():
		var player_id := int(player_id_variant)
		var cooldown: float = maxf(float(_core_damage_cooldowns[player_id]) - delta, 0.0)
		if cooldown <= 0.0:
			_core_damage_cooldowns.erase(player_id)
		else:
			_core_damage_cooldowns[player_id] = cooldown

func _decay_core_exposure(player_id: int, delta: float) -> void:
	if not _core_hold_times.has(player_id):
		return
	var exposure: float = maxf(float(_core_hold_times[player_id]) - delta * 2.0, 0.0)
	if exposure <= 0.0:
		_core_hold_times.erase(player_id)
	else:
		_core_hold_times[player_id] = exposure

func _update_player_core_exposure(player: Node2D, in_core: bool, delta: float) -> void:
	var player_id := player.get_instance_id()
	if not in_core:
		_decay_core_exposure(player_id, delta)
		return

	var exposure: float = float(_core_hold_times.get(player_id, 0.0)) + delta
	_core_hold_times[player_id] = exposure
	if exposure < CENTER_HOLD_TIME:
		return
	if float(_core_damage_cooldowns.get(player_id, 0.0)) > 0.0:
		return

	var knockback_direction: Vector2 = (player.global_position - global_position).normalized()
	if player.has_method("hurt") and bool(player.call("hurt", knockback_direction, 380.0, &"black_hole", self)):
		GameSfx.play(self, &"hazard", player.global_position, randf_range(0.94, 1.0))
	_core_hold_times[player_id] = 0.0
	_core_damage_cooldowns[player_id] = CENTER_DAMAGE_COOLDOWN

func _compute_cluster_center(member_positions: Array) -> Vector2:
	if member_positions.is_empty():
		return global_position

	var center := Vector2.ZERO
	for position_variant in member_positions:
		center += position_variant as Vector2
	return center / float(member_positions.size())

func _update_contributor_profile(delta: float) -> void:
	if not _has_cluster_profile:
		return
	_smoothed_extra_contributors = move_toward(
		_smoothed_extra_contributors,
		_target_extra_contributors,
		CONTRIBUTOR_BLEND_SPEED * delta
	)

func _get_size_multiplier() -> float:
	return 1.0 + minf(_smoothed_extra_contributors * 0.45, 1.1)

func _get_force_multiplier() -> float:
	return 1.45 + minf(_smoothed_extra_contributors * 0.32, 0.95)

func _update_warp_visual() -> void:
	if warp_field == null:
		return

	var strength := _get_visual_strength()
	if strength <= 0.001:
		warp_field.visible = false
		return

	warp_field.visible = true
	var field_size := BASE_WARP_FIELD_SIZE * _get_size_multiplier() * lerpf(0.58, 1.0, strength)
	warp_field.position = -field_size * 0.5
	warp_field.size = field_size

	if _warp_material == null:
		return

	_warp_material.set_shader_parameter("effect_opacity", 0.92 * strength)
	_warp_material.set_shader_parameter(
		"distortion_strength",
		lerpf(0.028, 0.05, strength) * (0.95 + (_get_size_multiplier() - 1.0) * 0.35)
	)
