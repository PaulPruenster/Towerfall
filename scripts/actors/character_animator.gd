class_name CharacterAnimator
extends Node


const CONFIG_BASE_PATH := "base_path"
const CONFIG_ANIMATIONS_DIR := "animations_dir"
const CONFIG_ROTATIONS_DIR := "rotations_dir"
const CONFIG_DIRECTIONS := "directions"
const CONFIG_DEFAULT_DIRECTION := "default_direction"
const CONFIG_DISPLAY_SCALE := "display_scale"
const CONFIG_DISPLAY_OFFSET := "display_offset"
const CONFIG_ANIMATIONS := "animations"

const ANIM_SOURCE := "source"
const ANIM_FRAME_COUNT := "frame_count"
const ANIM_FPS := "fps"
const ANIM_LOOP := "loop"
const ANIM_DIRECTIONS := "directions"

const REQUIRED_DIRECTION_NAMES := ["east", "west"]

@export_node_path("AnimatedSprite2D") var animated_sprite_path: NodePath = ^"../Visuals/AnimatedSprite2D"
@export var character_config: Dictionary = {
	"base_path": "res://assets/Tiny_retro_fantasy_pixel_art_character_sprite_24px",
	"animations_dir": "animations",
	"rotations_dir": "rotations",
	"directions": PackedStringArray([
		"north",
		"north-east",
		"east",
		"south-east",
		"south",
		"south-west",
		"west",
		"north-west",
	]),
	"default_direction": "east",
	"display_scale": Vector2(1.7, 1.7),
	"display_offset": Vector2.ZERO,
	"animations": {
		"idle": {
			"source": "breathing-idle",
			"frame_count": 4,
			"fps": 4.0,
			"loop": true,
			"directions": PackedStringArray(["east", "south", "west"]),
		},
		"run": {
			"source": "running-8-frames",
			"frame_count": 8,
			"fps": 12.0,
			"loop": true,
			"directions": PackedStringArray(["east", "west"]),
		},
		"jump": {
			"source": "jumping-1",
			"frame_count": 9,
			"fps": 14.0,
			"loop": false,
			"directions": PackedStringArray(["east", "west"]),
		},
		"fall": {
			"source": "running-jump",
			"frame_count": 8,
			"fps": 12.0,
			"loop": false,
			"directions": PackedStringArray(["east", "west"]),
		},
		"aim": {
			"source": "breathing-idle",
			"frame_count": 4,
			"fps": 4.0,
			"loop": true,
			"directions": PackedStringArray(["east", "south", "west"]),
		},
		"shoot": {
			"source": "pushing",
			"frame_count": 6,
			"fps": 18.0,
			"loop": false,
			"directions": PackedStringArray(["east", "west"]),
		},
		"hurt": {
			"source": "taking-punch",
			"frame_count": 6,
			"fps": 16.0,
			"loop": false,
			"directions": PackedStringArray(["east", "west"]),
		},
		"death": {
			"source": "falling-back-death",
			"frame_count": 7,
			"fps": 10.0,
			"loop": false,
			"directions": PackedStringArray(["east", "west"]),
		},
		"wall_slide": {
			"source": "wallgrinding",
			"frame_count": 9,
			"fps": 10.0,
			"loop": false,
			"directions": PackedStringArray(["east", "west"]),
		},
		"wall_jump": {
			"source": "jumping-from-wall",
			"frame_count": 9,
			"fps": 14.0,
			"loop": false,
			"directions": PackedStringArray(["east", "west"]),
		},
	},
}

static var _sprite_frames_cache: Dictionary = {}
static var _missing_texture: Texture2D

var current_animation_name: StringName = &""
var current_direction_name: StringName = &""

@onready var animated_sprite: AnimatedSprite2D = get_node_or_null(animated_sprite_path) as AnimatedSprite2D


func _ready() -> void:
	if animated_sprite == null:
		push_error("CharacterAnimator could not find AnimatedSprite2D at %s" % [str(animated_sprite_path)])
		return

	animated_sprite.sprite_frames = _get_sprite_frames()
	_apply_visual_config()


func play(animation_name: String, direction: String, force_replay: bool = false) -> void:
	if animated_sprite == null:
		return

	var semantic_animation := StringName(animation_name.strip_edges().to_lower())
	var normalized_direction := _normalize_direction_name(direction)
	if normalized_direction.is_empty():
		normalized_direction = _get_default_direction()

	var semantic_direction := StringName(normalized_direction)
	var runtime_animation := _compose_runtime_animation_name(semantic_animation, semantic_direction)

	if animated_sprite.sprite_frames == null or not animated_sprite.sprite_frames.has_animation(runtime_animation):
		var fallback_direction := StringName(_get_default_direction())
		runtime_animation = _compose_runtime_animation_name(semantic_animation, fallback_direction)
		if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(runtime_animation):
			semantic_direction = fallback_direction
		else:
			push_warning("CharacterAnimator missing animation %s for direction %s" % [animation_name, direction])
			return

	current_animation_name = semantic_animation
	current_direction_name = semantic_direction

	if force_replay or animated_sprite.animation != runtime_animation:
		if force_replay:
			animated_sprite.stop()
		animated_sprite.play(runtime_animation)


func _get_default_direction() -> String:
	return _normalize_direction_name(str(character_config.get(CONFIG_DEFAULT_DIRECTION, "east")))


func _apply_visual_config() -> void:
	var configured_scale: Variant = character_config.get(CONFIG_DISPLAY_SCALE, Vector2.ONE)
	if configured_scale is Vector2:
		animated_sprite.scale = configured_scale
	else:
		var uniform_scale := float(configured_scale)
		animated_sprite.scale = Vector2.ONE * uniform_scale

	var configured_offset: Variant = character_config.get(CONFIG_DISPLAY_OFFSET, Vector2.ZERO)
	if configured_offset is Vector2:
		animated_sprite.offset = configured_offset


func _get_sprite_frames() -> SpriteFrames:
	var cache_key := JSON.stringify(character_config)
	if _sprite_frames_cache.has(cache_key):
		return _sprite_frames_cache[cache_key] as SpriteFrames

	var sprite_frames := _build_sprite_frames()
	_sprite_frames_cache[cache_key] = sprite_frames
	return sprite_frames


func _build_sprite_frames() -> SpriteFrames:
	var sprite_frames := SpriteFrames.new()
	var base_path := str(character_config.get(CONFIG_BASE_PATH, ""))
	var directions := _to_string_array(character_config.get(CONFIG_DIRECTIONS, PackedStringArray()))
	var animations: Dictionary = character_config.get(CONFIG_ANIMATIONS, {})

	for animation_key in animations.keys():
		var semantic_animation := StringName(str(animation_key).to_lower())
		var spec: Dictionary = animations[animation_key]
		var animation_directions := _to_string_array(spec.get(ANIM_DIRECTIONS, PackedStringArray()))

		if not _has_required_directions(animation_directions):
			push_error("CharacterAnimator config for %s must include east and west." % [str(semantic_animation)])
			continue

		var source_animation := str(spec.get(ANIM_SOURCE, semantic_animation))
		var frame_count: int = maxi(1, int(spec.get(ANIM_FRAME_COUNT, 1)))
		var fps: float = maxf(0.01, float(spec.get(ANIM_FPS, 1.0)))
		var looping := bool(spec.get(ANIM_LOOP, true))

		for direction in directions:
			var runtime_animation := _compose_runtime_animation_name(semantic_animation, StringName(direction))
			sprite_frames.add_animation(runtime_animation)
			sprite_frames.set_animation_speed(runtime_animation, fps)
			sprite_frames.set_animation_loop(runtime_animation, looping)

			var textures := _resolve_textures_for_direction(base_path, source_animation, frame_count, animation_directions, direction)
			for texture in textures:
				sprite_frames.add_frame(runtime_animation, texture)

	return sprite_frames


func _resolve_textures_for_direction(
	base_path: String,
	source_animation: String,
	frame_count: int,
	animation_directions: PackedStringArray,
	direction: String
) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []

	if animation_directions.has(direction):
		for frame_index in range(frame_count):
			var frame_path := "%s/%s/%s/%s/frame_%03d.png" % [
				base_path,
				str(character_config.get(CONFIG_ANIMATIONS_DIR, "animations")),
				source_animation,
				direction,
				frame_index,
			]
			var texture := _load_texture(frame_path)
			if texture == null:
				textures.clear()
				break
			textures.append(texture)

	if not textures.is_empty():
		return textures

	var fallback_texture := _load_texture(_get_rotation_path(base_path, direction))
	if fallback_texture != null:
		return [fallback_texture]

	push_warning("CharacterAnimator missing animation and rotation fallback for %s/%s." % [source_animation, direction])
	return [_get_missing_texture()]


func _get_rotation_path(base_path: String, direction: String) -> String:
	return "%s/%s/%s.png" % [
		base_path,
		str(character_config.get(CONFIG_ROTATIONS_DIR, "rotations")),
		direction,
	]


func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _compose_runtime_animation_name(animation_name: StringName, direction: StringName) -> StringName:
	return StringName("%s__%s" % [str(animation_name), str(direction)])


func _normalize_direction_name(direction: String) -> String:
	return direction.strip_edges().to_lower().replace("_", "-")


func _to_string_array(value: Variant) -> PackedStringArray:
	var result := PackedStringArray()

	if value is PackedStringArray:
		for entry in value:
			result.append(_normalize_direction_name(str(entry)))
	elif value is Array:
		for entry in value:
			result.append(_normalize_direction_name(str(entry)))

	return result


func _has_required_directions(directions: PackedStringArray) -> bool:
	for required_direction in REQUIRED_DIRECTION_NAMES:
		if not directions.has(required_direction):
			return false
	return true


func _get_missing_texture() -> Texture2D:
	if _missing_texture != null:
		return _missing_texture

	var image := Image.create(36, 36, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.9, 0.0, 0.8, 0.45))
	image.fill_rect(Rect2i(8, 8, 20, 20), Color.BLACK)
	_missing_texture = ImageTexture.create_from_image(image)
	return _missing_texture
