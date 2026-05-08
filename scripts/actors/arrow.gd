class_name Arrow
extends CharacterBody2D

signal hit_player(target, shooter, arrow_type)
signal hit_wall(shooter, arrow_type)
signal ricocheted(shooter, remaining_ricochets)
signal exploded(shooter, arrow_type, hit_players)

enum ArrowType {
	NORMAL,
	EXPLOSIVE,
	RICOCHET,
	STRAIGHT,
	WARP,
}

enum ArrowVisualState {
	FLIGHT,
	HIT_WALL,
	HIT_ENEMY,
}

const ARROW_DUMMY: PackedScene = preload("res://scenes/actors/arrow_dummy.tscn")
const EXPLOSION_EFFECT: PackedScene = preload("res://scenes/effects/explosion.tscn")
const WARP_FIELD_EFFECT: PackedScene = preload("res://scenes/effects/warp_field_effect.tscn")
const NORMAL_TEXTURE_PATH: String = "res://assets/generated/arrows/arrow_normal.png"
const EXPLOSIVE_TEXTURE_PATH: String = "res://assets/generated/arrows/arrow_bomb.png"
const RICOCHET_TEXTURE_PATH: String = "res://assets/generated/arrows/arrow_bounce.png"
const STRAIGHT_TEXTURE_PATH: String = "res://assets/generated/arrows/arrow_normal.png"
const ARROW_ASSET_DIR: String = "res://assets/generated/arrows"
const ARROW_PLACEHOLDER_SIZE: Vector2i = Vector2i(12, 24)
const EXPLOSION_RADIUS: float = 80.0
const EXPLOSION_SCALE: Vector2 = Vector2(0.45, 0.45)
const SCREEN_EFFECT_Z_INDEX: int = 50
const WARP_FLIGHT_FIELD_SIZE: Vector2 = Vector2(220.0, 220.0)
const WARP_IMPACT_FIELD_SIZE: Vector2 = Vector2(260.0, 260.0)
const WARP_IMPACT_DURATION: float = 5.0
const WARP_IMPACT_GROW_AMOUNT: float = 0.22
const BLACK_HOLE_PULL_FORCE: float = 6.0
const MAX_RICOCHETS: int = 4
const SHOOTER_COLLISION_ARM_DISTANCE: float = 48.0
const FLIGHT_FRAME_COUNT: int = 4
const HIT_WALL_FRAME_COUNT: int = 2
const HIT_ENEMY_FRAME_COUNT: int = 3
const FLIGHT_ANIMATION_SPEED: float = 16.0
const HIT_WALL_ANIMATION_SPEED: float = 12.0
const HIT_ENEMY_ANIMATION_SPEED: float = 18.0
const ARROW_ANIMATION_NAMES := {
	ArrowVisualState.FLIGHT: &"flight",
	ArrowVisualState.HIT_WALL: &"hit_wall",
	ArrowVisualState.HIT_ENEMY: &"hit_enemy",
}
const ARROW_VARIANT_NAMES := {
	ArrowType.NORMAL: "normal",
	ArrowType.EXPLOSIVE: "bomb",
	ArrowType.RICOCHET: "bounce",
	ArrowType.STRAIGHT: "normal",
	ArrowType.WARP: "normal",
}

@export var direction: Vector2 = Vector2.ZERO
@export var speed: float = 1000.0

@onready var trail_particles: GPUParticles2D = $GPUParticles2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var visuals: Node2D = $Visuals
@onready var animated_sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

var active: bool = false
var arrow_type: int = ArrowType.NORMAL
var shooter: Player
var ricochets_left: int = 0
var shooter_collision_armed: bool = false
var visual_state: int = ArrowVisualState.FLIGHT
var warp_field_effect: WarpFieldEffect

static var _texture_cache: Dictionary = {}
static var _sprite_frames_cache: Dictionary = {}
static var _placeholder_texture: Texture2D

static func get_arrow_name(new_arrow_type: int) -> String:
	match new_arrow_type:
		ArrowType.EXPLOSIVE:
			return "Bomb"
		ArrowType.RICOCHET:
			return "Bounce"
		ArrowType.STRAIGHT:
			return "Straight"
		ArrowType.WARP:
			return "Warp"
		_:
			return "Normal"

static func get_arrow_color(new_arrow_type: int) -> Color:
	match new_arrow_type:
		ArrowType.EXPLOSIVE:
			return Color("#ff8a1f")
		ArrowType.RICOCHET:
			return Color("#45e0ff")
		ArrowType.STRAIGHT:
			return Color("#c8ff72")
		ArrowType.WARP:
			return Color("#8ff7ff")
		_:
			return Color.WHITE

static func get_gravity_scale_for_type(new_arrow_type: int) -> float:
	match new_arrow_type:
		ArrowType.EXPLOSIVE:
			return 0.00035
		ArrowType.RICOCHET:
			return 0.00012
		ArrowType.STRAIGHT:
			return 0.0
		ArrowType.WARP:
			return 0.00008
		_:
			return 0.0002

static func get_speed_for_type(base_speed: float, new_arrow_type: int) -> float:
	match new_arrow_type:
		ArrowType.EXPLOSIVE:
			return base_speed * 0.85
		ArrowType.RICOCHET:
			return base_speed * 1.1
		ArrowType.WARP:
			return base_speed * 0.38
		_:
			return base_speed

func _ready() -> void:
	if not animated_sprite.animation_finished.is_connected(_on_animated_sprite_2d_animation_finished):
		animated_sprite.animation_finished.connect(_on_animated_sprite_2d_animation_finished)
	_apply_visuals(true)

func configure(new_owner: Player, new_arrow_type: int) -> void:
	var type_changed := arrow_type != new_arrow_type
	var previous_owner := get_shooter()
	var owner_changed := previous_owner != new_owner
	if previous_owner != null and previous_owner != new_owner:
		remove_collision_exception_with(previous_owner)
	shooter = new_owner
	arrow_type = new_arrow_type
	shooter_collision_armed = false

	var current_shooter := get_shooter()
	if current_shooter != null:
		add_collision_exception_with(current_shooter)

	if arrow_type == ArrowType.RICOCHET:
		ricochets_left = MAX_RICOCHETS
	else:
		ricochets_left = 0

	if type_changed or owner_changed:
		_apply_visuals(true)

func shoot() -> void:
	active = true
	visual_state = ArrowVisualState.FLIGHT
	shooter_collision_armed = false
	var current_shooter := get_shooter()
	if current_shooter != null:
		add_collision_exception_with(current_shooter)
	trail_particles.show()
	collision.disabled = false
	_ensure_flight_effect()
	_play_visual_state(ArrowVisualState.FLIGHT, true)

func get_shooter() -> Player:
	if shooter == null:
		return null
	if is_instance_valid(shooter):
		return shooter
	shooter = null
	shooter_collision_armed = true
	return null

func _wrap_to_viewport() -> void:
	var size: Vector2 = get_viewport_rect().size
	position.x = wrapf(position.x, 0.0, size.x)
	position.y = wrapf(position.y, 0.0, size.y)

func _apply_visuals(force_replay: bool = false) -> void:
	animated_sprite.sprite_frames = _get_sprite_frames_for_type(arrow_type)
	trail_particles.modulate = get_arrow_color(arrow_type)
	animated_sprite.modulate = Color.WHITE
	_play_visual_state(visual_state, force_replay)

func _get_sprite_frames_for_type(new_arrow_type: int) -> SpriteFrames:
	if _sprite_frames_cache.has(new_arrow_type):
		return _sprite_frames_cache[new_arrow_type]

	var sprite_frames := SpriteFrames.new()
	_add_arrow_animation(
		sprite_frames,
		ARROW_ANIMATION_NAMES[ArrowVisualState.FLIGHT],
		_load_arrow_sequence("arrow_%s_flight" % ARROW_VARIANT_NAMES[new_arrow_type], FLIGHT_FRAME_COUNT, _get_texture_for_type(new_arrow_type)),
		FLIGHT_ANIMATION_SPEED,
		true
	)
	_add_arrow_animation(
		sprite_frames,
		ARROW_ANIMATION_NAMES[ArrowVisualState.HIT_WALL],
		_load_arrow_sequence("arrow_hit_wall", HIT_WALL_FRAME_COUNT, _get_texture_for_type(new_arrow_type)),
		HIT_WALL_ANIMATION_SPEED,
		false
	)
	_add_arrow_animation(
		sprite_frames,
		ARROW_ANIMATION_NAMES[ArrowVisualState.HIT_ENEMY],
		_load_arrow_sequence("arrow_hit_enemy", HIT_ENEMY_FRAME_COUNT, _get_texture_for_type(new_arrow_type)),
		HIT_ENEMY_ANIMATION_SPEED,
		false
	)

	_sprite_frames_cache[new_arrow_type] = sprite_frames
	return sprite_frames

func _add_arrow_animation(
	sprite_frames: SpriteFrames,
	animation_name: StringName,
	frames: Array[Texture2D],
	animation_speed: float,
	looping: bool
) -> void:
	sprite_frames.add_animation(animation_name)
	sprite_frames.set_animation_speed(animation_name, animation_speed)
	sprite_frames.set_animation_loop(animation_name, looping)
	for texture in frames:
		sprite_frames.add_frame(animation_name, texture)

func _load_arrow_sequence(base_name: String, frame_count: int, fallback_texture: Texture2D) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	for frame_index in range(frame_count):
		var path := "%s/%s_%02d.png" % [ARROW_ASSET_DIR, base_name, frame_index]
		var texture := _load_texture(path)
		frames.append(texture if texture != null else fallback_texture)
	return frames

func _get_texture_for_type(new_arrow_type: int) -> Texture2D:
	match new_arrow_type:
		ArrowType.EXPLOSIVE:
			return _load_texture_with_fallback(EXPLOSIVE_TEXTURE_PATH)
		ArrowType.RICOCHET:
			return _load_texture_with_fallback(RICOCHET_TEXTURE_PATH)
		ArrowType.STRAIGHT:
			return _load_texture_with_fallback(STRAIGHT_TEXTURE_PATH)
		ArrowType.WARP:
			return _load_texture_with_fallback(NORMAL_TEXTURE_PATH)
		_:
			return _load_texture_with_fallback(NORMAL_TEXTURE_PATH)

func _load_texture_with_fallback(path: String) -> Texture2D:
	var texture := _load_texture(path)
	if texture != null:
		return texture
	return _get_placeholder_texture()

func _load_texture(path: String) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache[path]

	if not ResourceLoader.exists(path):
		return null

	var texture := load(path) as Texture2D
	_texture_cache[path] = texture
	return texture

func _get_placeholder_texture() -> Texture2D:
	if _placeholder_texture != null:
		return _placeholder_texture

	var image := Image.create(
		ARROW_PLACEHOLDER_SIZE.x,
		ARROW_PLACEHOLDER_SIZE.y,
		false,
		Image.FORMAT_RGBA8
	)
	image.fill(Color(0, 0, 0, 0))
	image.fill_rect(Rect2i(4, 1, 4, 18), Color.WHITE)
	image.fill_rect(Rect2i(2, 0, 8, 3), Color.WHITE)
	image.fill_rect(Rect2i(0, 18, 12, 6), Color.WHITE)
	_placeholder_texture = ImageTexture.create_from_image(image)
	return _placeholder_texture

func _play_visual_state(new_state: int, force_replay: bool = false) -> void:
	visual_state = new_state
	var animation_name: StringName = ARROW_ANIMATION_NAMES[new_state]
	if force_replay or animated_sprite.animation != animation_name:
		animated_sprite.stop()
		animated_sprite.play(animation_name)

func _get_gravity_scale() -> float:
	return get_gravity_scale_for_type(arrow_type)

func _get_speed() -> float:
	return get_speed_for_type(speed, arrow_type)

func apply_black_hole_pull(center: Vector2, normalized_strength: float, delta: float) -> void:
	if not active or normalized_strength <= 0.0:
		return

	var offset := center - global_position
	var distance := offset.length()
	if distance <= 0.001:
		return

	direction += (offset / distance) * BLACK_HOLE_PULL_FORCE * normalized_strength * delta

func _spawn_dummy() -> void:
	var dummy := ARROW_DUMMY.instantiate() as Area2D
	dummy.global_position = global_position
	dummy.rotation = atan2(direction.x, -direction.y)
	get_parent().add_child(dummy)

func _spawn_explosion_effect() -> void:
	var explosion := EXPLOSION_EFFECT.instantiate() as GPUParticles2D
	explosion.finished.connect(explosion.queue_free)
	explosion.global_position = global_position
	explosion.scale = EXPLOSION_SCALE
	var scene_root := get_tree().current_scene
	if scene_root == null:
		scene_root = get_tree().root
	scene_root.add_child(explosion)
	explosion.emitting = true

func _spawn_scene_effect(effect_scene: PackedScene, effect_z_index: int = SCREEN_EFFECT_Z_INDEX) -> Node2D:
	var effect := effect_scene.instantiate() as Node2D
	if effect == null:
		return null
	effect.top_level = true
	effect.z_as_relative = false
	effect.z_index = effect_z_index
	var scene_root := get_tree().current_scene
	if scene_root == null:
		scene_root = get_tree().root
	scene_root.add_child(effect)
	return effect

func _ensure_flight_effect() -> void:
	if arrow_type != ArrowType.WARP:
		return
	if warp_field_effect != null and is_instance_valid(warp_field_effect):
		return

	warp_field_effect = _spawn_scene_effect(WARP_FIELD_EFFECT) as WarpFieldEffect
	if warp_field_effect == null:
		return
	warp_field_effect.set_field_size(WARP_FLIGHT_FIELD_SIZE)
	warp_field_effect.set_effect_opacity(1.0)
	warp_field_effect.grow_amount = WARP_IMPACT_GROW_AMOUNT
	warp_field_effect.attach_to_target(self)

func _release_lingering_effect(effect: Node2D, duration: float) -> void:
	if effect == null or not is_instance_valid(effect):
		return
	if effect.has_method("release"):
		effect.call("release", duration)
		return
	if effect.has_method("start_decay"):
		effect.call("start_decay", duration)
		return
	effect.queue_free()

func _release_warp_field() -> void:
	if warp_field_effect == null or not is_instance_valid(warp_field_effect):
		warp_field_effect = null
		return
	warp_field_effect.set_field_size(WARP_IMPACT_FIELD_SIZE)
	_release_lingering_effect(warp_field_effect, WARP_IMPACT_DURATION)
	warp_field_effect = null

func _clear_warp_field() -> void:
	if warp_field_effect == null or not is_instance_valid(warp_field_effect):
		warp_field_effect = null
		return
	warp_field_effect.queue_free()
	warp_field_effect = null

func _explode() -> void:
	_clear_warp_field()
	_spawn_explosion_effect()
	GameSfx.play(self, &"explosion", global_position, randf_range(0.96, 1.03))
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("trigger_screenshake"):
		scene.trigger_screenshake(10.0, 0.12)
	var current_shooter := get_shooter()
	var hit_players: Array[Player] = []
	for node in get_tree().get_nodes_in_group("player"):
		var player := node as Player
		if player == null or player == current_shooter:
			continue
		if player.global_position.distance_to(global_position) <= EXPLOSION_RADIUS:
			if player.hurt((player.global_position - global_position).normalized(), 360.0, &"explosion", current_shooter):
				hit_players.append(player)
	exploded.emit(current_shooter, arrow_type, hit_players)
	queue_free()

func _begin_impact(new_state: int, spawn_dummy: bool, leave_lingering_effect: bool = false) -> void:
	active = false
	collision.disabled = true
	trail_particles.hide()
	if leave_lingering_effect:
		_release_warp_field()
	else:
		_clear_warp_field()
	if spawn_dummy:
		_spawn_dummy()
	_play_visual_state(new_state, true)

func _arm_shooter_collision() -> void:
	var current_shooter := get_shooter()
	if shooter_collision_armed or current_shooter == null:
		return
	if global_position.distance_to(current_shooter.global_position) < SHOOTER_COLLISION_ARM_DISTANCE:
		return
	remove_collision_exception_with(current_shooter)
	shooter_collision_armed = true

func _handle_collision(collision_info: KinematicCollision2D) -> void:
	global_position = collision_info.get_position()

	var collider := collision_info.get_collider()
	var current_shooter := get_shooter()
	var player := collider as Player
	if player != null:
		if player == current_shooter and not shooter_collision_armed:
			return
		if arrow_type == ArrowType.EXPLOSIVE:
			_explode()
			return
		GameSfx.play(self, &"arrow_hit", global_position, randf_range(0.95, 1.05))
		if player.hurt(direction.normalized(), 360.0, &"arrow", current_shooter):
			hit_player.emit(player, current_shooter, arrow_type)
		_begin_impact(ArrowVisualState.HIT_ENEMY, false, false)
		return

	if arrow_type == ArrowType.RICOCHET and ricochets_left > 0:
		ricochets_left -= 1
		direction = direction.bounce(collision_info.get_normal()).normalized()
		global_position += collision_info.get_normal() * 14.0
		GameSfx.play(self, &"ricochet", global_position, randf_range(0.96, 1.06))
		ricocheted.emit(current_shooter, ricochets_left)
		return

	if arrow_type == ArrowType.EXPLOSIVE:
		_explode()
		return

	GameSfx.play(self, &"arrow_hit", global_position, randf_range(0.9, 1.0))
	hit_wall.emit(current_shooter, arrow_type)
	_begin_impact(ArrowVisualState.HIT_WALL, true, arrow_type == ArrowType.WARP)

func _physics_process(delta: float) -> void:
	rotation = atan2(direction.x, -direction.y)

	if not active:
		return

	_wrap_to_viewport()
	_arm_shooter_collision()

	direction.y += gravity * delta * _get_gravity_scale()
	var collision_info := move_and_collide(direction.normalized() * delta * _get_speed())
	_wrap_to_viewport()
	if collision_info:
		_handle_collision(collision_info)

func _on_animated_sprite_2d_animation_finished() -> void:
	if visual_state == ArrowVisualState.HIT_WALL or visual_state == ArrowVisualState.HIT_ENEMY:
		queue_free()

func _exit_tree() -> void:
	_clear_warp_field()
