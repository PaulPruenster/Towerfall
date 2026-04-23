class_name Player
extends CharacterBody2D


enum PlayerAnimState {
	IDLE,
	RUN,
	JUMP,
	FALL,
	AIM,
	SHOOT,
	HURT,
	DEATH,
	WALL_SLIDE,
	WALL_JUMP,
}

enum AimBucket {
	SIDE,
	UP_DIAG,
	UP,
	DOWN_DIAG,
	DOWN,
}

const SPEED: float = 300.0
const JUMP_VELOCITY: float = -400.0
const TERMINAL_VELOCITY: float = 1000.0
const DASH_VELOCITY: float = 700.0
const DEFAULT_ARROW_COUNT: int = 5
const COYOTE_TIME: float = 0.12
const JUMP_BUFFER_TIME: float = 0.15
const SHORT_HOP_FACTOR: float = 0.45
const AIM_PREVIEW_LENGTH: float = 80.0
const KNOCKBACK_FORCE: float = 320.0
const HURT_FLASH_TIME: float = 0.12
const HURT_INVULNERABILITY: float = 0.3
const SPEED_BOOST_MULTIPLIER: float = 1.35
const RAPID_FIRE_INTERVAL: float = 0.16
const TRIPLE_SHOT_SPREAD: float = 0.22
const ARROW_SPAWN_DISTANCE: float = 18.0
const AIM_PREVIEW_START_DISTANCE: float = 4.0
const HIT_STOP_DURATION: float = 0.035
const KILL_HIT_STOP_DURATION: float = 0.08
const DASH_READY_FLASH_TIME: float = 0.24
const SHOOT_LOCK_TIME: float = 0.1
const RUN_ANIMATION_THRESHOLD: float = 20.0
const JUMP_ANIMATION_THRESHOLD: float = -30.0
const FALL_ANIMATION_THRESHOLD: float = 30.0
const WALL_JUMP_VELOCITY_X: float = 360.0
const WALL_JUMP_VELOCITY_Y: float = -380.0
const WALL_SLIDE_TIME: float = 0.12
const WALL_JUMP_LOCK_TIME: float = 0.18
const WALL_SLIDE_GRAVITY_FACTOR: float = 0.4
const AIM_DIAGONAL_THRESHOLD_DEGREES: float = 22.5
const AIM_VERTICAL_THRESHOLD_DEGREES: float = 67.5
const PLAYER_ANIM_STATE_NAMES := {
	PlayerAnimState.IDLE: &"idle",
	PlayerAnimState.RUN: &"run",
	PlayerAnimState.JUMP: &"jump",
	PlayerAnimState.FALL: &"fall",
	PlayerAnimState.AIM: &"aim",
	PlayerAnimState.SHOOT: &"shoot",
	PlayerAnimState.HURT: &"hurt",
	PlayerAnimState.DEATH: &"death",
	PlayerAnimState.WALL_SLIDE: &"wall_slide",
	PlayerAnimState.WALL_JUMP: &"wall_jump",
}

signal im_dead
signal shot_fired(projectile, arrow_type, direction)
signal damage_taken(source_type, source_actor, lethal, remaining_health)
signal hud_player_color_changed(player_color: Color)
signal hud_health_changed(current_health: int)
signal hud_ammo_changed(normal_ammo: int, special_arrow_type: int, special_ammo: int, total_ammo: int)
signal hud_dash_changed(available: int, max_count: int, cooldown_remaining: float, cooldown_duration: float)
signal hud_buffs_changed(
	triple_shot_count: int,
	armor_count: int,
	speed_remaining: float,
	speed_duration: float,
	rapid_remaining: float,
	rapid_duration: float,
	extra_dash_remaining: float,
	extra_dash_duration: float
)

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

var dashing: bool = false
var jumping: bool = false
var aiming: bool = false
var coyote_time_left: float = 0.0
var jump_buffer_left: float = 0.0
var rapid_fire_cooldown_left: float = 0.0
var hurt_flash_left: float = 0.0
var hurt_invulnerability_left: float = 0.0
var dash_ready_flash_left: float = 0.0
var last_aim_direction: Vector2 = Vector2.RIGHT
var shoot_lock_left: float = 0.0
var hurt_lock_left: float = 0.0
var facing_sign: int = 1
var is_dying: bool = false
var death_animation_started: bool = false
var death_animation_direction: Vector2 = Vector2.RIGHT
var wall_slide_time_left: float = 0.0
var wall_jump_lock_left: float = 0.0
var last_wall_normal: Vector2 = Vector2.ZERO

@export_color_no_alpha var player_color: Color
@export_color_no_alpha var aim_color: Color = Color("#FFF")
@export var left_button: StringName = &"p1_left"
@export var right_button: StringName = &"p1_right"
@export var up_button: StringName = &"p1_up"
@export var down_button: StringName = &"p1_down"
@export var use_button: StringName = &"p1_use"
@export var jump_button: StringName = &"p1_jump"
@export var dash_button: StringName = &"p1_dash"
@export_node_path("Node") var controller_path: NodePath = ^"AIController"

@export var deathParticle: PackedScene
@export var arrow: PackedScene

@export var health: int = 2
@export var arrow_count: int = DEFAULT_ARROW_COUNT

@onready var body_collision: CollisionShape2D = $Body
@onready var character_animator = $CharacterAnimator
@onready var animated_sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D
@onready var player_marker: Polygon2D = $Visuals/PlayerMarker
@onready var landing_particles: GPUParticles2D = $Landing
@onready var arrow_count_label: Label = $ArrowCount
@onready var health_count_label: Label = $HealthCount
@onready var special_ammo_label: Label = $SpecialAmmo
@onready var dash_status_label: Label = $DashStatus
@onready var buff_status_label: Label = $BuffStatus
@onready var aim_preview: Line2D = $AimPreview
@onready var head_area: Area2D = $Area2D
@onready var head_collision: CollisionShape2D = $Area2D/Head
@onready var dash_timer: Timer = $DashTimer
@onready var dash_cooldown: Timer = $DashCooldown
@onready var controller: Node = get_node_or_null(controller_path)

var current_arrow: Arrow
var world_hud_visible: bool = true
var special_arrow_type: int = Arrow.ArrowType.NORMAL
var special_arrow_count: int = 0
var triple_shot_charges: int = 0
var armor_hits: int = 0
var speed_boost_time_left: float = 0.0
var rapid_fire_time_left: float = 0.0
var extra_dash_time_left: float = 0.0
var speed_boost_duration_total: float = 0.0
var rapid_fire_duration_total: float = 0.0
var extra_dash_duration_total: float = 0.0
var available_dashes: int = 1
var _controller_use_pressed: bool = false
var _controller_jump_pressed: bool = false
var _controller_dash_pressed: bool = false
var _using_controller_input: bool = false
var _current_control_direction: Vector2 = Vector2.ZERO

func _ready() -> void:
	if not animated_sprite.animation_finished.is_connected(_on_animated_sprite_2d_animation_finished):
		animated_sprite.animation_finished.connect(_on_animated_sprite_2d_animation_finished)

	available_dashes = get_max_dash_count()
	aim_preview.hide()
	_update_hud()
	_update_visual_state()
	_update_animation(last_aim_direction, true)
	emit_hud_state()

func set_world_hud_visible(is_visible: bool) -> void:
	world_hud_visible = is_visible
	_update_hud()

func emit_hud_state() -> void:
	hud_player_color_changed.emit(player_color)
	_emit_health_changed()
	_emit_ammo_changed()
	_emit_dash_changed()
	_emit_buffs_changed()

func _emit_health_changed() -> void:
	hud_health_changed.emit(health)

func _emit_ammo_changed() -> void:
	hud_ammo_changed.emit(arrow_count, special_arrow_type, special_arrow_count, get_total_arrow_count())

func _emit_dash_changed() -> void:
	hud_dash_changed.emit(available_dashes, get_max_dash_count(), dash_cooldown.time_left, dash_cooldown.wait_time)

func _emit_buffs_changed() -> void:
	hud_buffs_changed.emit(
		triple_shot_charges,
		armor_hits,
		speed_boost_time_left,
		speed_boost_duration_total,
		rapid_fire_time_left,
		rapid_fire_duration_total,
		extra_dash_time_left,
		extra_dash_duration_total
	)

func hurt(
	hit_direction: Vector2 = Vector2.ZERO,
	knockback_strength: float = KNOCKBACK_FORCE,
	source_type: StringName = &"unknown",
	source_actor: Node = null
) -> bool:
	if is_dying or hurt_invulnerability_left > 0.0:
		return false

	if armor_hits > 0:
		armor_hits -= 1
		hurt_flash_left = HURT_FLASH_TIME
		hurt_invulnerability_left = HURT_INVULNERABILITY * 0.5
		_request_screen_shake(4.0, 0.08)
		GameSfx.play(self, &"armor", global_position)
		_emit_buffs_changed()
		return false

	hurt_flash_left = HURT_FLASH_TIME
	hurt_invulnerability_left = HURT_INVULNERABILITY
	_apply_knockback(hit_direction, knockback_strength)
	_request_screen_shake(7.0, 0.1)
	GameSfx.play(self, &"hurt", global_position)

	if health > 1:
		health -= 1
		hurt_lock_left = HURT_FLASH_TIME
		_update_animation(hit_direction, true)
		_request_hit_stop(HIT_STOP_DURATION, 0.08)
		_emit_health_changed()
		damage_taken.emit(source_type, source_actor, false, health)
		return true

	_request_hit_stop(KILL_HIT_STOP_DURATION, 0.04)
	damage_taken.emit(source_type, source_actor, true, 0)
	im_dead.emit()

	if current_arrow:
		current_arrow.queue_free()
		current_arrow = null

	var par := deathParticle.instantiate() as GPUParticles2D
	par.finished.connect(par.queue_free)
	par.global_position = global_position
	par.scale = Vector2(1.2, 1.2)
	var scene_root := get_tree().current_scene
	if scene_root == null:
		scene_root = get_tree().root
	scene_root.add_child(par)
	par.emitting = true
	_request_screen_shake(14.0, 0.18)
	GameSfx.play(self, &"death", global_position)

	_start_death_sequence(hit_direction)
	return true

func can_shoot(direction: Vector2) -> bool:
	if direction.y > 0 and is_on_floor():
		return false
	return direction != Vector2.ZERO and has_available_ammo()

func has_available_ammo() -> bool:
	return get_total_arrow_count() > 0

func get_total_arrow_count() -> int:
	return arrow_count + special_arrow_count

func add_arrows(amount: int = 1) -> void:
	if amount <= 0:
		return
	arrow_count += amount
	_emit_ammo_changed()

func restore_arrows() -> void:
	arrow_count = max(arrow_count, DEFAULT_ARROW_COUNT)
	_emit_ammo_changed()

func heal(amount: int = 1) -> void:
	health += amount
	_emit_health_changed()

func grant_special_arrows(new_arrow_type: int, charges: int) -> void:
	if charges <= 0:
		return
	if special_arrow_type == new_arrow_type:
		special_arrow_count += charges
	else:
		special_arrow_type = new_arrow_type
		special_arrow_count = charges
	_emit_ammo_changed()

func grant_triple_shot(charges: int) -> void:
	if charges <= 0:
		return
	triple_shot_charges += charges
	_emit_buffs_changed()

func grant_rapid_fire(duration: float) -> void:
	rapid_fire_time_left = max(rapid_fire_time_left, duration)
	rapid_fire_duration_total = max(rapid_fire_duration_total, rapid_fire_time_left, duration)
	_emit_buffs_changed()

func grant_extra_dash(duration: float) -> void:
	extra_dash_time_left = max(extra_dash_time_left, duration)
	extra_dash_duration_total = max(extra_dash_duration_total, extra_dash_time_left, duration)
	available_dashes = get_max_dash_count()
	_emit_buffs_changed()
	_emit_dash_changed()

func grant_armor(hits: int) -> void:
	if hits <= 0:
		return
	armor_hits += hits
	_emit_buffs_changed()

func grant_speed_boost(duration: float) -> void:
	speed_boost_time_left = max(speed_boost_time_left, duration)
	speed_boost_duration_total = max(speed_boost_duration_total, speed_boost_time_left, duration)
	_emit_buffs_changed()

func launch_from_pad(launch_velocity: Vector2, inherit_horizontal_velocity: bool = true) -> void:
	dashing = false

	var new_velocity := launch_velocity
	if inherit_horizontal_velocity:
		new_velocity.x += velocity.x

	velocity = new_velocity
	jumping = true

func get_loaded_arrow_type() -> int:
	if special_arrow_count > 0:
		return special_arrow_type
	return Arrow.ArrowType.NORMAL

func get_arrow_spawn_position(direction: Vector2) -> Vector2:
	var normalized_direction := direction.normalized()
	if normalized_direction == Vector2.ZERO:
		normalized_direction = last_aim_direction if last_aim_direction != Vector2.ZERO else Vector2.RIGHT
	return global_position + _get_bow_anchor_offset(normalized_direction) + normalized_direction * ARROW_SPAWN_DISTANCE

func get_max_dash_count() -> int:
	if extra_dash_time_left > 0.0:
		return 2
	return 1

func get_current_speed() -> float:
	if speed_boost_time_left > 0.0:
		return SPEED * SPEED_BOOST_MULTIPLIER
	return SPEED

func _consume_special_arrow() -> void:
	if special_arrow_count <= 0:
		return
	special_arrow_count -= 1
	if special_arrow_count <= 0:
		special_arrow_count = 0
		special_arrow_type = Arrow.ArrowType.NORMAL

func consume_loaded_arrow(loaded_arrow_type: int) -> void:
	if loaded_arrow_type != Arrow.ArrowType.NORMAL and special_arrow_count > 0:
		_consume_special_arrow()
		_emit_ammo_changed()
		return

	if arrow_count > 0:
		arrow_count -= 1
	_emit_ammo_changed()

func _apply_knockback(hit_direction: Vector2, knockback_strength: float) -> void:
	var direction := hit_direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.UP
	velocity = direction * knockback_strength
	velocity.y = min(velocity.y, -abs(knockback_strength * 0.45))

func _request_screen_shake(intensity: float, duration: float) -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("trigger_screenshake"):
		scene.trigger_screenshake(intensity, duration)

func _request_hit_stop(duration: float, slow_scale: float) -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("trigger_hit_stop"):
		scene.trigger_hit_stop(duration, slow_scale)

func _update_timed_states(delta: float) -> void:
	coyote_time_left = max(coyote_time_left - delta, 0.0)
	jump_buffer_left = max(jump_buffer_left - delta, 0.0)
	rapid_fire_cooldown_left = max(rapid_fire_cooldown_left - delta, 0.0)
	hurt_flash_left = max(hurt_flash_left - delta, 0.0)
	hurt_invulnerability_left = max(hurt_invulnerability_left - delta, 0.0)
	dash_ready_flash_left = max(dash_ready_flash_left - delta, 0.0)
	shoot_lock_left = max(shoot_lock_left - delta, 0.0)
	hurt_lock_left = max(hurt_lock_left - delta, 0.0)
	wall_slide_time_left = max(wall_slide_time_left - delta, 0.0)
	wall_jump_lock_left = max(wall_jump_lock_left - delta, 0.0)

	var previous_max_dashes := get_max_dash_count()
	var previous_available_dashes := available_dashes
	var had_speed_boost := speed_boost_time_left > 0.0
	var had_rapid_fire := rapid_fire_time_left > 0.0
	var had_extra_dash := extra_dash_time_left > 0.0
	speed_boost_time_left = max(speed_boost_time_left - delta, 0.0)
	rapid_fire_time_left = max(rapid_fire_time_left - delta, 0.0)
	extra_dash_time_left = max(extra_dash_time_left - delta, 0.0)

	if available_dashes > get_max_dash_count():
		available_dashes = get_max_dash_count()
	elif previous_max_dashes < get_max_dash_count():
		available_dashes = get_max_dash_count()

	var buffs_changed := false
	if had_speed_boost and speed_boost_time_left <= 0.0:
		speed_boost_duration_total = 0.0
		buffs_changed = true
	if had_rapid_fire and rapid_fire_time_left <= 0.0:
		rapid_fire_duration_total = 0.0
		buffs_changed = true
	if had_extra_dash and extra_dash_time_left <= 0.0:
		extra_dash_duration_total = 0.0
		buffs_changed = true

	if previous_available_dashes != available_dashes or previous_max_dashes != get_max_dash_count():
		_emit_dash_changed()

	if buffs_changed:
		_emit_buffs_changed()

func _update_visual_state() -> void:
	if hurt_flash_left > 0.0:
		animated_sprite.modulate = Color.WHITE
	else:
		animated_sprite.modulate = Color.WHITE

	var marker_color := player_color
	if hurt_flash_left > 0.0:
		marker_color = Color.WHITE
	elif aiming and not is_dying:
		marker_color = player_color.lerp(aim_color, 0.25)
	elif is_dying:
		marker_color = player_color.darkened(0.35)

	player_marker.color = marker_color
	player_marker.scale = Vector2.ONE * (1.12 if aiming and not is_dying else 1.0)

func _update_hud() -> void:
	arrow_count_label.text = str(get_total_arrow_count())
	health_count_label.text = str(health)

	if not world_hud_visible:
		arrow_count_label.hide()
		health_count_label.hide()
		special_ammo_label.hide()
		dash_status_label.hide()
		buff_status_label.hide()
		return

	if special_arrow_count > 0:
		special_ammo_label.text = "Next: %s x%d" % [Arrow.get_arrow_name(special_arrow_type), special_arrow_count]
		special_ammo_label.modulate = Arrow.get_arrow_color(special_arrow_type)
		special_ammo_label.show()
	else:
		special_ammo_label.hide()

	if available_dashes > 0:
		dash_status_label.text = "Dash %d/%d" % [available_dashes, get_max_dash_count()]
		if dash_ready_flash_left > 0.0:
			dash_status_label.modulate = Color.WHITE
		else:
			dash_status_label.modulate = Color("#8ff06d")
	else:
		dash_status_label.text = "Dash %.1fs" % dash_cooldown.time_left
		dash_status_label.modulate = Color("#ffb84d")

	var buff_statuses: Array[String] = []
	if triple_shot_charges > 0:
		buff_statuses.append("x3 %d" % triple_shot_charges)
	if armor_hits > 0:
		buff_statuses.append("Armor %d" % armor_hits)
	if speed_boost_time_left > 0.0:
		buff_statuses.append("Speed %.1f" % speed_boost_time_left)
	if rapid_fire_time_left > 0.0:
		buff_statuses.append("Rapid %.1f" % rapid_fire_time_left)
	if extra_dash_time_left > 0.0:
		buff_statuses.append("Dash+ %.1f" % extra_dash_time_left)

	if buff_statuses.is_empty():
		buff_status_label.hide()
	else:
		buff_status_label.text = " | ".join(buff_statuses)
		buff_status_label.show()

func _wrap_to_viewport() -> void:
	var size: Vector2 = get_viewport_rect().size
	position.x = wrapf(position.x, 0.0, size.x)
	position.y = wrapf(position.y, 0.0, size.y)

func _is_aim_locked() -> bool:
	return aiming or current_arrow != null

func get_input_direction_raw() -> Vector2:
	if _using_controller_input:
		return _current_control_direction
	return Input.get_vector(left_button, right_button, up_button, down_button)

func _reset_controller_input_state() -> void:
	_controller_use_pressed = false
	_controller_jump_pressed = false
	_controller_dash_pressed = false

func _read_human_control_state() -> Dictionary:
	_reset_controller_input_state()
	return {
		"direction": Input.get_vector(left_button, right_button, up_button, down_button),
		"use_pressed": Input.is_action_pressed(use_button),
		"use_just_pressed": Input.is_action_just_pressed(use_button),
		"use_just_released": Input.is_action_just_released(use_button),
		"jump_pressed": Input.is_action_pressed(jump_button),
		"jump_just_pressed": Input.is_action_just_pressed(jump_button),
		"jump_just_released": Input.is_action_just_released(jump_button),
		"dash_pressed": Input.is_action_pressed(dash_button),
		"dash_just_pressed": Input.is_action_just_pressed(dash_button),
	}

func _read_controller_control_state(delta: float) -> Dictionary:
	if controller == null or not controller.has_method("get_control_state"):
		return {}

	var raw_state_variant: Variant = controller.call("get_control_state", delta)
	if not (raw_state_variant is Dictionary):
		return {}

	var raw_state: Dictionary = raw_state_variant
	if not bool(raw_state.get("active", false)):
		return {}

	var direction_value: Variant = raw_state.get("direction", Vector2.ZERO)
	var direction: Vector2 = direction_value if direction_value is Vector2 else Vector2.ZERO
	var use_pressed: bool = bool(raw_state.get("use_pressed", false))
	var jump_pressed: bool = bool(raw_state.get("jump_pressed", false))
	var dash_pressed: bool = bool(raw_state.get("dash_pressed", false))

	var use_just_pressed: bool = use_pressed and not _controller_use_pressed
	var use_just_released: bool = not use_pressed and _controller_use_pressed
	var jump_just_pressed: bool = jump_pressed and not _controller_jump_pressed
	var jump_just_released: bool = not jump_pressed and _controller_jump_pressed
	var dash_just_pressed: bool = dash_pressed and not _controller_dash_pressed

	_controller_use_pressed = use_pressed
	_controller_jump_pressed = jump_pressed
	_controller_dash_pressed = dash_pressed

	return {
		"direction": direction,
		"use_pressed": use_pressed,
		"use_just_pressed": use_just_pressed,
		"use_just_released": use_just_released,
		"jump_pressed": jump_pressed,
		"jump_just_pressed": jump_just_pressed,
		"jump_just_released": jump_just_released,
		"dash_pressed": dash_pressed,
		"dash_just_pressed": dash_just_pressed,
	}

func _read_control_state(delta: float) -> Dictionary:
	var control_state := _read_controller_control_state(delta)
	_using_controller_input = not control_state.is_empty()
	if control_state.is_empty():
		control_state = _read_human_control_state()
		_using_controller_input = false

	var direction: Vector2 = control_state.get("direction", Vector2.ZERO)
	direction = direction.limit_length(1.0)
	control_state["direction"] = direction
	_current_control_direction = direction
	return control_state

func _get_input_direction(raw_direction: Vector2) -> Vector2:
	var direction := raw_direction
	if direction != Vector2.ZERO:
		last_aim_direction = direction.normalized()
	return direction

func _get_shoot_direction(input_direction: Vector2) -> Vector2:
	if input_direction != Vector2.ZERO:
		return input_direction.normalized()
	if _is_aim_locked():
		return last_aim_direction
	return input_direction

func _get_bow_anchor_offset(direction: Vector2) -> Vector2:
	var horizontal_sign := facing_sign
	if direction.x > 0.0:
		horizontal_sign = 1
	elif direction.x < 0.0:
		horizontal_sign = -1

	match _resolve_aim_bucket(direction):
		AimBucket.UP:
			return Vector2(0.0, -18.0)
		AimBucket.UP_DIAG:
			return Vector2(10.0 * horizontal_sign, -14.0)
		AimBucket.DOWN_DIAG:
			return Vector2(10.0 * horizontal_sign, 2.0)
		AimBucket.DOWN:
			return Vector2(0.0, 6.0)
		_:
			return Vector2(14.0 * horizontal_sign, -4.0)

func _update_aim_preview(direction: Vector2) -> void:
	if not aiming or direction == Vector2.ZERO or not has_available_ammo():
		aim_preview.hide()
		return

	var normalized_direction := direction.normalized()
	var preview_origin := _get_bow_anchor_offset(normalized_direction) + normalized_direction * AIM_PREVIEW_START_DISTANCE
	aim_preview.show()
	aim_preview.default_color = Arrow.get_arrow_color(get_loaded_arrow_type())
	aim_preview.width = 4.0 if get_loaded_arrow_type() != Arrow.ArrowType.NORMAL or triple_shot_charges > 0 else 2.0
	aim_preview.points = PackedVector2Array([
		preview_origin,
		preview_origin + normalized_direction * AIM_PREVIEW_LENGTH,
	])

func _clear_preview_arrow() -> void:
	if current_arrow:
		current_arrow.queue_free()
		current_arrow = null

func _position_arrow(projectile: Arrow, direction: Vector2) -> void:
	var normalized_direction := direction.normalized()
	projectile.global_position = get_arrow_spawn_position(normalized_direction)
	projectile.direction = normalized_direction

func _get_shot_directions(direction: Vector2) -> Array[Vector2]:
	if triple_shot_charges <= 0:
		return [direction.normalized()]

	var normalized := direction.normalized()
	return [
		normalized.rotated(-TRIPLE_SHOT_SPREAD),
		normalized,
		normalized.rotated(TRIPLE_SHOT_SPREAD),
	]

func _trigger_shoot_animation(direction: Vector2) -> void:
	shoot_lock_left = SHOOT_LOCK_TIME
	_update_animation(direction, true)

func _fire_shot(direction: Vector2, preview_arrow: Arrow = null) -> void:
	var shot_directions := _get_shot_directions(direction)
	var loaded_arrow_type := get_loaded_arrow_type()
	var middle_index := shot_directions.size() / 2
	GameSfx.play(self, &"arrow_shot", global_position, randf_range(0.96, 1.06))

	for index in range(shot_directions.size()):
		var projectile: Arrow
		if preview_arrow != null and index == middle_index:
			projectile = preview_arrow
		else:
			projectile = arrow.instantiate() as Arrow
			get_parent().add_child(projectile)

		projectile.configure(self, loaded_arrow_type)
		_position_arrow(projectile, shot_directions[index])
		projectile.shoot()
		shot_fired.emit(projectile, loaded_arrow_type, shot_directions[index])

	consume_loaded_arrow(loaded_arrow_type)
	_trigger_shoot_animation(direction)

	if triple_shot_charges > 0:
		triple_shot_charges -= 1
		_emit_buffs_changed()

	current_arrow = null

func _get_animation_direction(preferred_direction: Vector2) -> Vector2:
	if _is_aim_locked() and last_aim_direction != Vector2.ZERO:
		return last_aim_direction
	if preferred_direction != Vector2.ZERO:
		return preferred_direction.normalized()
	if last_aim_direction != Vector2.ZERO:
		return last_aim_direction
	if velocity.x != 0.0:
		return Vector2(sign(velocity.x), 0.0)
	return Vector2.RIGHT * facing_sign

func _resolve_side_direction(direction: Vector2) -> Vector2:
	if direction.x > 0.0:
		return Vector2.RIGHT
	if direction.x < 0.0:
		return Vector2.LEFT
	if velocity.x > 0.0:
		return Vector2.RIGHT
	if velocity.x < 0.0:
		return Vector2.LEFT
	if last_aim_direction.x > 0.0:
		return Vector2.RIGHT
	if last_aim_direction.x < 0.0:
		return Vector2.LEFT
	return Vector2.RIGHT * facing_sign

func _resolve_death_animation_direction(hit_direction: Vector2) -> Vector2:
	if hit_direction != Vector2.ZERO:
		return _resolve_side_direction(-hit_direction.normalized())
	return _resolve_side_direction(_get_animation_direction(last_aim_direction))

func _update_facing(direction: Vector2) -> void:
	# During wall slide/jump, face toward the wall surface
	if wall_slide_time_left > 0.0 and last_wall_normal != Vector2.ZERO:
		facing_sign = -int(sign(last_wall_normal.x))
		return
	if direction.x > 0.0:
		facing_sign = 1
	elif direction.x < 0.0:
		facing_sign = -1
	elif velocity.x > 0.0:
		facing_sign = 1
	elif velocity.x < 0.0:
		facing_sign = -1

func _resolve_aim_bucket(direction: Vector2) -> int:
	if direction == Vector2.ZERO:
		return AimBucket.SIDE

	var normalized := direction.normalized()
	var angle := rad_to_deg(atan2(-normalized.y, absf(normalized.x)))
	if angle >= AIM_VERTICAL_THRESHOLD_DEGREES:
		return AimBucket.UP
	if angle >= AIM_DIAGONAL_THRESHOLD_DEGREES:
		return AimBucket.UP_DIAG
	if angle <= -AIM_VERTICAL_THRESHOLD_DEGREES:
		return AimBucket.DOWN
	if angle <= -AIM_DIAGONAL_THRESHOLD_DEGREES:
		return AimBucket.DOWN_DIAG
	return AimBucket.SIDE

func _resolve_player_anim_state(direction: Vector2) -> int:
	if is_dying:
		if not death_animation_started:
			return PlayerAnimState.FALL
		return PlayerAnimState.DEATH
	if hurt_lock_left > 0.0:
		return PlayerAnimState.HURT
	if shoot_lock_left > 0.0:
		return PlayerAnimState.SHOOT
	if _is_aim_locked():
		return PlayerAnimState.AIM
	if wall_jump_lock_left > 0.0:
		return PlayerAnimState.WALL_JUMP
	if wall_slide_time_left > 0.0 and not is_on_floor():
		return PlayerAnimState.WALL_SLIDE
	if not is_on_floor():
		if velocity.y < JUMP_ANIMATION_THRESHOLD:
			return PlayerAnimState.JUMP
		if velocity.y > FALL_ANIMATION_THRESHOLD:
			return PlayerAnimState.FALL
		return PlayerAnimState.JUMP
	if absf(velocity.x) >= RUN_ANIMATION_THRESHOLD:
		return PlayerAnimState.RUN
	return PlayerAnimState.IDLE

func _resolve_animation_direction_name(direction: Vector2) -> StringName:
	if direction == Vector2.ZERO:
		return &"east" if facing_sign >= 0 else &"west"

	var angle := fposmod(rad_to_deg(atan2(direction.y, direction.x)) + 360.0, 360.0)
	if angle < 22.5 or angle >= 337.5:
		return &"east"
	if angle < 67.5:
		return &"south-east"
	if angle < 112.5:
		return &"south"
	if angle < 157.5:
		return &"south-west"
	if angle < 202.5:
		return &"west"
	if angle < 247.5:
		return &"north-west"
	if angle < 292.5:
		return &"north"
	return &"north-east"

func _update_animation(direction: Vector2, force_replay: bool = false) -> void:
	var animation_direction := _get_animation_direction(direction)

	var state := _resolve_player_anim_state(animation_direction)
	if state == PlayerAnimState.DEATH:
		animation_direction = death_animation_direction

	_update_facing(animation_direction)

	var animation_name: StringName = PLAYER_ANIM_STATE_NAMES[state]
	var direction_name := _resolve_animation_direction_name(animation_direction)
	character_animator.play(str(animation_name), str(direction_name), force_replay)

func _begin_ground_death_animation(direction: Vector2) -> void:
	if death_animation_started:
		return

	death_animation_started = true
	velocity = Vector2.ZERO
	body_collision.disabled = true
	set_collision_layer(0)
	set_collision_mask(0)
	_update_animation(direction, true)

func _start_death_sequence(hit_direction: Vector2) -> void:
	is_dying = true
	death_animation_started = false
	death_animation_direction = _resolve_death_animation_direction(hit_direction)
	aiming = false
	dashing = false
	hurt_flash_left = 0.0
	hurt_invulnerability_left = 0.0
	hurt_lock_left = 0.0
	shoot_lock_left = 0.0
	dash_timer.stop()
	dash_cooldown.stop()
	_clear_preview_arrow()
	aim_preview.hide()
	landing_particles.emitting = false
	head_collision.disabled = true
	head_area.monitoring = false
	head_area.monitorable = false

	if is_on_floor():
		_begin_ground_death_animation(death_animation_direction)
	else:
		velocity.y = max(velocity.y, 0.0)
		_update_animation(death_animation_direction, true)

func _physics_process(delta: float) -> void:
	_update_timed_states(delta)

	if is_dying:
		if not death_animation_started:
			if velocity.y < TERMINAL_VELOCITY:
				velocity.y += gravity * delta
			velocity.x = move_toward(velocity.x, 0.0, get_current_speed() * delta * 2.5)
			move_and_slide()
			_wrap_to_viewport()
			if is_on_floor():
				_begin_ground_death_animation(death_animation_direction)
		_update_hud()
		_update_visual_state()
		_update_animation(death_animation_direction)
		return

	if not is_on_floor() and not dashing and velocity.y < TERMINAL_VELOCITY:
		velocity.y += gravity * delta

	# Wall slide detection — triggers on any wall contact while airborne
	if is_on_wall_only() and not is_on_floor() and not dashing:
		var wall_normal := get_wall_normal()
		last_wall_normal = wall_normal
		wall_slide_time_left = WALL_SLIDE_TIME
		if velocity.y > 0.0:
			velocity.y += gravity * delta * (WALL_SLIDE_GRAVITY_FACTOR - 1.0)

	var control_state := _read_control_state(delta)
	var input_direction: Vector2 = control_state.get("direction", Vector2.ZERO)
	var use_pressed := bool(control_state.get("use_pressed", false))
	var use_just_released := bool(control_state.get("use_just_released", false))
	var jump_just_pressed := bool(control_state.get("jump_just_pressed", false))
	var jump_just_released := bool(control_state.get("jump_just_released", false))
	var dash_just_pressed := bool(control_state.get("dash_just_pressed", false))

	aiming = use_pressed

	if is_on_floor():
		coyote_time_left = COYOTE_TIME

	if jump_just_pressed and not aiming:
		jump_buffer_left = JUMP_BUFFER_TIME

	if jump_just_released and velocity.y < 0.0:
		velocity.y *= SHORT_HOP_FACTOR

	var direction := _get_input_direction(input_direction)
	var shoot_direction := _get_shoot_direction(direction)

	# Wall jump — runs before ground jump so both share jump_buffer_left
	if jump_buffer_left > 0.0 and wall_slide_time_left > 0.0 and not is_on_floor() and not aiming:
		velocity.x = last_wall_normal.x * WALL_JUMP_VELOCITY_X
		velocity.y = WALL_JUMP_VELOCITY_Y
		wall_jump_lock_left = WALL_JUMP_LOCK_TIME
		wall_slide_time_left = 0.0
		jump_buffer_left = 0.0
		jumping = true
		GameSfx.play(self, &"jump", global_position)

	if jump_buffer_left > 0.0 and coyote_time_left > 0.0 and not aiming:
		velocity.y = JUMP_VELOCITY
		jump_buffer_left = 0.0
		coyote_time_left = 0.0

	if available_dashes > 0 and dash_just_pressed and direction != Vector2.ZERO:
		dashing = true
		available_dashes -= 1
		dash_timer.start()
		if available_dashes < get_max_dash_count() and dash_cooldown.is_stopped():
			dash_cooldown.start()
		_emit_dash_changed()

	if direction != Vector2.ZERO and not aiming and wall_jump_lock_left <= 0.0:
		if dashing:
			velocity.x = direction.x * DASH_VELOCITY
			velocity.y = direction.y * DASH_VELOCITY * 0.7
		else:
			velocity.x = direction.x * get_current_speed()
	else:
		if not dashing:
			velocity.x = move_toward(velocity.x, 0.0, get_current_speed() / 5.0)

	move_and_slide()
	_wrap_to_viewport()

	if jumping and is_on_floor():
		landing_particles.amount = 70
		landing_particles.emitting = true
	jumping = not is_on_floor()

	_update_aim_preview(shoot_direction)

	if aiming and rapid_fire_time_left > 0.0:
		_clear_preview_arrow()
		if rapid_fire_cooldown_left <= 0.0 and can_shoot(shoot_direction):
			_fire_shot(shoot_direction)
			rapid_fire_cooldown_left = RAPID_FIRE_INTERVAL
	elif aiming:
		if can_shoot(shoot_direction):
			if not current_arrow:
				current_arrow = arrow.instantiate() as Arrow
				get_parent().add_child(current_arrow)
			current_arrow.configure(self, get_loaded_arrow_type())
			_position_arrow(current_arrow, shoot_direction)
		else:
			_clear_preview_arrow()
	else:
		aim_preview.hide()

	if current_arrow and use_just_released:
		if can_shoot(shoot_direction):
			_fire_shot(shoot_direction, current_arrow)
		else:
			_clear_preview_arrow()

	_update_hud()
	_update_visual_state()
	_update_animation(shoot_direction)

func _on_area_2d_body_entered(body: Node) -> void:
	if body != self and body.is_in_group("player"):
		hurt(global_position - (body as Node2D).global_position, KNOCKBACK_FORCE, &"body", body)

func _on_dash_timer_timeout() -> void:
	dashing = false

func _on_dash_cooldown_timeout() -> void:
	var was_empty := available_dashes == 0
	available_dashes = min(available_dashes + 1, get_max_dash_count())
	if was_empty and available_dashes > 0:
		dash_ready_flash_left = DASH_READY_FLASH_TIME
		GameSfx.play(self, &"dash_ready", global_position)
	if available_dashes < get_max_dash_count():
		dash_cooldown.start()
	_emit_dash_changed()

func _on_animated_sprite_2d_animation_finished() -> void:
	if is_dying and character_animator.current_animation_name == PLAYER_ANIM_STATE_NAMES[PlayerAnimState.DEATH]:
		queue_free()
