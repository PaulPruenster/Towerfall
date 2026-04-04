extends Node2D

@onready var timer: Timer = $RestartTimer
@onready var status: Label = $Label
@onready var default: String = status.text

var shake_time_left: float = 0.0
var shake_strength: float = 0.0
var base_canvas_transform: Transform2D
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var hit_stop_request_id: int = 0

func _ready() -> void:
	base_canvas_transform = get_viewport().canvas_transform
	rng.randomize()
	Engine.time_scale = 1.0

func _process(delta: float) -> void:
	if shake_time_left <= 0.0:
		if get_viewport().canvas_transform != base_canvas_transform:
			get_viewport().canvas_transform = base_canvas_transform
		return

	shake_time_left = max(shake_time_left - delta, 0.0)
	var offset := Vector2(
		rng.randf_range(-shake_strength, shake_strength),
		rng.randf_range(-shake_strength, shake_strength)
	)
	get_viewport().canvas_transform = base_canvas_transform.translated(offset)
	shake_strength = lerpf(shake_strength, 0.0, delta * 10.0)

func trigger_screenshake(intensity: float = 8.0, duration: float = 0.12) -> void:
	shake_time_left = max(shake_time_left, duration)
	shake_strength = max(shake_strength, intensity)

func trigger_hit_stop(duration: float = 0.05, slow_scale: float = 0.08) -> void:
	hit_stop_request_id += 1
	var request_id := hit_stop_request_id
	Engine.time_scale = min(Engine.time_scale, slow_scale)
	await get_tree().create_timer(duration, true, false, true).timeout
	if request_id == hit_stop_request_id:
		Engine.time_scale = 1.0

func _on_player_1_im_dead() -> void:
	status.text = "Player 2 wins!"
	timer.start()

func _on_player_2_im_dead() -> void:
	status.text = "Player 1 wins!"
	timer.start()

func _on_timer_timeout() -> void:
	status.text = default
	get_tree().reload_current_scene()

func _exit_tree() -> void:
	Engine.time_scale = 1.0
	if is_inside_tree():
		get_viewport().canvas_transform = base_canvas_transform
