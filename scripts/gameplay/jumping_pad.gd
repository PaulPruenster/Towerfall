class_name JumpPad
extends Node2D


signal launched(body: CharacterBody2D)

const BASE_TEXTURE_PATH: String = "res://assets/generated/jump_pad/jump_pad_base.png"
const READY_PLATE_TEXTURE_PATH: String = "res://assets/generated/jump_pad/jump_pad_plate_ready.png"
const COOLDOWN_PLATE_TEXTURE_PATH: String = "res://assets/generated/jump_pad/jump_pad_plate_cooldown.png"
const GLOW_TEXTURE_PATH: String = "res://assets/generated/jump_pad/jump_pad_glow.png"
const BURST_TEXTURE_PATH: String = "res://assets/generated/jump_pad/jump_pad_burst.png"
const READY_GLOW_MODULATE: Color = Color(1.0, 1.0, 1.0, 0.95)
const COOLDOWN_GLOW_MODULATE: Color = Color(0.7, 0.8, 0.95, 0.3)

@export_group("Launch")
@export var launch_velocity: Vector2 = Vector2(0.0, -1050.0)
@export var inherit_horizontal_velocity: bool = true
@export var ignore_ascending_bodies: bool = true
@export_range(0.0, 64.0, 1.0) var max_horizontal_entry_offset: float = 26.0

@export_group("Timing")
@export_range(0.0, 1.0, 0.01) var cooldown_time: float = 0.5
@export_range(0.01, 0.3, 0.01) var compress_duration: float = 0.07
@export_range(0.01, 0.4, 0.01) var rebound_duration: float = 0.16
@export_range(1.0, 1.4, 0.01) var compress_scale_x: float = 1.26
@export_range(0.08, 1.0, 0.01) var compress_scale_y: float = 0.1
@export_range(1.0, 1.4, 0.01) var base_compress_scale_x: float = 1.16
@export_range(0.2, 1.0, 0.01) var base_compress_scale_y: float = 0.38

@export_group("Feedback")
@export_range(0.0, 24.0, 0.1) var shake_intensity: float = 2.2
@export_range(0.0, 0.5, 0.01) var shake_duration: float = 0.05

@onready var base: Sprite2D = $Base
@onready var plate: Sprite2D = $Plate
@onready var glow: Sprite2D = $Glow
@onready var base_compressed_pose: Marker2D = $BaseCompressedPose
@onready var plate_compressed_pose: Marker2D = $PlateCompressedPose
@onready var glow_compressed_pose: Marker2D = $GlowCompressedPose
@onready var trigger_area: Area2D = $TriggerArea
@onready var cooldown_timer: Timer = $CooldownTimer
@onready var burst_particles: GPUParticles2D = $BurstParticles

var is_ready: bool = true
var _base_rest_position: Vector2
var _base_rest_scale: Vector2
var _plate_rest_position: Vector2
var _plate_rest_scale: Vector2
var _glow_rest_position: Vector2
var _glow_rest_scale: Vector2
var _plate_tween: Tween

static var _texture_cache: Dictionary = {}

func _ready() -> void:
	base.texture = _load_texture(BASE_TEXTURE_PATH)
	glow.texture = _load_texture(GLOW_TEXTURE_PATH)
	burst_particles.texture = _load_texture(BURST_TEXTURE_PATH)
	_base_rest_position = base.position
	_base_rest_scale = base.scale
	_plate_rest_position = plate.position
	_plate_rest_scale = plate.scale
	_glow_rest_position = glow.position
	_glow_rest_scale = glow.scale
	cooldown_timer.wait_time = cooldown_time
	_set_ready_state(true)

func _set_ready_state(new_value: bool) -> void:
	is_ready = new_value
	plate.texture = _load_texture(READY_PLATE_TEXTURE_PATH if is_ready else COOLDOWN_PLATE_TEXTURE_PATH)
	glow.modulate = READY_GLOW_MODULATE if is_ready else COOLDOWN_GLOW_MODULATE

func _load_texture(path: String) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache[path]

	if not ResourceLoader.exists(path, "Texture2D"):
		return null

	var texture := load(path) as Texture2D
	if texture == null:
		return null

	_texture_cache[path] = texture
	return texture

func _can_launch_body(body: CharacterBody2D) -> bool:
	if not is_ready:
		return false
	if not body.is_in_group("player"):
		return false
	if ignore_ascending_bodies and body.velocity.y < 0.0:
		return false

	var local_position := to_local(body.global_position)
	return absf(local_position.x) <= max_horizontal_entry_offset

func _launch_body(body: CharacterBody2D) -> void:
	if body is Player:
		(body as Player).launch_from_pad(launch_velocity, inherit_horizontal_velocity)
	else:
		var final_velocity := launch_velocity
		if inherit_horizontal_velocity:
			final_velocity.x += body.velocity.x
		body.velocity = final_velocity

	_set_ready_state(false)
	cooldown_timer.start()
	_play_activation_feedback()
	_request_screen_shake()
	GameSfx.play(self, &"jump_pad", global_position, randf_range(0.96, 1.04))
	launched.emit(body)

func _play_activation_feedback() -> void:
	if _plate_tween != null:
		_plate_tween.kill()

	base.position = _base_rest_position
	base.scale = _base_rest_scale
	plate.position = _plate_rest_position
	plate.scale = _plate_rest_scale
	glow.position = _glow_rest_position
	glow.scale = _glow_rest_scale

	_plate_tween = create_tween()
	_plate_tween.set_parallel(false)
	_plate_tween.tween_property(plate, "position", plate_compressed_pose.position, compress_duration)
	_plate_tween.parallel().tween_property(plate, "scale:x", _plate_rest_scale.x * compress_scale_x, compress_duration)
	_plate_tween.parallel().tween_property(plate, "scale:y", _plate_rest_scale.y * compress_scale_y, compress_duration)
	_plate_tween.parallel().tween_property(base, "position", base_compressed_pose.position, compress_duration)
	_plate_tween.parallel().tween_property(base, "scale:x", _base_rest_scale.x * base_compress_scale_x, compress_duration)
	_plate_tween.parallel().tween_property(base, "scale:y", _base_rest_scale.y * base_compress_scale_y, compress_duration)
	_plate_tween.parallel().tween_property(glow, "position", glow_compressed_pose.position, compress_duration)
	_plate_tween.parallel().tween_property(glow, "scale:x", _glow_rest_scale.x * 1.1, compress_duration)
	_plate_tween.parallel().tween_property(glow, "scale:y", _glow_rest_scale.y * 0.72, compress_duration)
	_plate_tween.parallel().tween_property(glow, "modulate:a", READY_GLOW_MODULATE.a * 0.55, compress_duration)
	_plate_tween.tween_property(plate, "position", _plate_rest_position, rebound_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_plate_tween.parallel().tween_property(base, "position", _base_rest_position, rebound_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_plate_tween.parallel().tween_property(base, "scale:x", _base_rest_scale.x, rebound_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_plate_tween.parallel().tween_property(base, "scale:y", _base_rest_scale.y, rebound_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_plate_tween.parallel().tween_property(plate, "scale:x", _plate_rest_scale.x, rebound_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_plate_tween.parallel().tween_property(plate, "scale:y", _plate_rest_scale.y, rebound_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_plate_tween.parallel().tween_property(glow, "position", _glow_rest_position, rebound_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_plate_tween.parallel().tween_property(glow, "scale:x", _glow_rest_scale.x, rebound_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_plate_tween.parallel().tween_property(glow, "scale:y", _glow_rest_scale.y, rebound_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_plate_tween.parallel().tween_property(glow, "modulate:a", READY_GLOW_MODULATE.a if is_ready else COOLDOWN_GLOW_MODULATE.a, rebound_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	burst_particles.restart()
	burst_particles.emitting = true

func _request_screen_shake() -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("trigger_screenshake"):
		scene.trigger_screenshake(shake_intensity, shake_duration)

func _on_trigger_area_body_entered(body: Node) -> void:
	var character := body as CharacterBody2D
	if character == null or not _can_launch_body(character):
		return

	_launch_body(character)

func _physics_process(_delta: float) -> void:
	# body_entered is ignored for ascending bodies (ignore_ascending_bodies = true).
	# Poll every frame so a body that jumped in while going up still gets launched
	# once it lands on the plate with velocity.y >= 0.
	if not is_ready:
		return
	for body in trigger_area.get_overlapping_bodies():
		var character := body as CharacterBody2D
		if character != null and _can_launch_body(character):
			_launch_body(character)
			return

func _on_cooldown_timer_timeout() -> void:
	_set_ready_state(true)
