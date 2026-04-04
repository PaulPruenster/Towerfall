class_name Arrow
extends CharacterBody2D

enum ArrowType {
	NORMAL,
	EXPLOSIVE,
	RICOCHET,
	STRAIGHT,
}

enum ArrowVisualState {
	FLIGHT,
	HIT_WALL,
	HIT_ENEMY,
}

const ARROW_DUMMY: PackedScene = preload("res://scenes/actors/arrow_dummy.tscn")
const EXPLOSION_EFFECT: PackedScene = preload("res://scenes/effects/explosion.tscn")
const NORMAL_TEXTURE_PATH: String = "res://assets/generated/arrows/arrow_normal.png"
const EXPLOSIVE_TEXTURE_PATH: String = "res://assets/generated/arrows/arrow_bomb.png"
const RICOCHET_TEXTURE_PATH: String = "res://assets/generated/arrows/arrow_bounce.png"
const STRAIGHT_TEXTURE_PATH: String = "res://assets/generated/arrows/arrow_normal.png"
const ARROW_ASSET_DIR: String = "res://assets/generated/arrows"
const ARROW_PLACEHOLDER_SIZE: Vector2i = Vector2i(12, 24)
const EXPLOSION_RADIUS: float = 80.0
const EXPLOSION_SCALE: Vector2 = Vector2(0.45, 0.45)
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
		_:
			return Color.WHITE

func _ready() -> void:
	if not animated_sprite.animation_finished.is_connected(_on_animated_sprite_2d_animation_finished):
		animated_sprite.animation_finished.connect(_on_animated_sprite_2d_animation_finished)
	_apply_visuals(true)

func configure(new_owner: Player, new_arrow_type: int) -> void:
	var type_changed := arrow_type != new_arrow_type
	var previous_owner := shooter
	var owner_changed := previous_owner != new_owner
	if previous_owner != null and previous_owner != new_owner:
		remove_collision_exception_with(previous_owner)
	shooter = new_owner
	arrow_type = new_arrow_type
	shooter_collision_armed = false

	if shooter != null:
		add_collision_exception_with(shooter)

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
	if shooter != null:
		add_collision_exception_with(shooter)
	trail_particles.show()
	collision.disabled = false
	_play_visual_state(ArrowVisualState.FLIGHT, true)

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
	match arrow_type:
		ArrowType.EXPLOSIVE:
			return 0.00035
		ArrowType.RICOCHET:
			return 0.00012
		ArrowType.STRAIGHT:
			return 0.0
		_:
			return 0.0002

func _get_speed() -> float:
	match arrow_type:
		ArrowType.EXPLOSIVE:
			return speed * 0.85
		ArrowType.RICOCHET:
			return speed * 1.1
		_:
			return speed

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

func _explode() -> void:
	_spawn_explosion_effect()
	GameSfx.play(self, &"explosion", global_position, randf_range(0.96, 1.03))
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("trigger_screenshake"):
		scene.trigger_screenshake(10.0, 0.12)
	for node in get_tree().get_nodes_in_group("player"):
		var player := node as Player
		if player == null or player == shooter:
			continue
		if player.global_position.distance_to(global_position) <= EXPLOSION_RADIUS:
			player.hurt((player.global_position - global_position).normalized(), 360.0)
	queue_free()

func _begin_impact(new_state: int, spawn_dummy: bool) -> void:
	active = false
	collision.disabled = true
	trail_particles.hide()
	if spawn_dummy:
		_spawn_dummy()
	_play_visual_state(new_state, true)

func _arm_shooter_collision() -> void:
	if shooter_collision_armed or shooter == null:
		return
	if global_position.distance_to(shooter.global_position) < SHOOTER_COLLISION_ARM_DISTANCE:
		return
	remove_collision_exception_with(shooter)
	shooter_collision_armed = true

func _handle_collision(collision_info: KinematicCollision2D) -> void:
	global_position = collision_info.get_position()

	var collider := collision_info.get_collider()
	var player := collider as Player
	if player != null:
		if player == shooter and not shooter_collision_armed:
			return
		if arrow_type == ArrowType.EXPLOSIVE:
			_explode()
			return
		GameSfx.play(self, &"arrow_hit", global_position, randf_range(0.95, 1.05))
		player.hurt(direction.normalized(), 360.0)
		_begin_impact(ArrowVisualState.HIT_ENEMY, false)
		return

	if arrow_type == ArrowType.RICOCHET and ricochets_left > 0:
		ricochets_left -= 1
		direction = direction.bounce(collision_info.get_normal()).normalized()
		global_position += collision_info.get_normal() * 14.0
		GameSfx.play(self, &"ricochet", global_position, randf_range(0.96, 1.06))
		return

	if arrow_type == ArrowType.EXPLOSIVE:
		_explode()
		return

	GameSfx.play(self, &"arrow_hit", global_position, randf_range(0.9, 1.0))
	_begin_impact(ArrowVisualState.HIT_WALL, true)

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
