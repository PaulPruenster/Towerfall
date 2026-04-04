extends AnimatableBody2D

@export var move_offset: Vector2 = Vector2(220.0, 0.0)
@export_range(0.2, 10.0, 0.1) var travel_time: float = 2.0
@export_range(0.0, 3.0, 0.1) var pause_time: float = 0.2

var start_position: Vector2
var progress: float = 0.0
var direction: int = 1
var pause_timer: float = 0.0

func _ready() -> void:
	start_position = position

func _physics_process(delta: float) -> void:
	if pause_timer > 0.0:
		pause_timer = max(pause_timer - delta, 0.0)
		return

	progress += direction * delta / max(travel_time, 0.01)
	if progress >= 1.0:
		progress = 1.0
		direction = -1
		pause_timer = pause_time
	elif progress <= 0.0:
		progress = 0.0
		direction = 1
		pause_timer = pause_time

	position = start_position.lerp(start_position + move_offset, progress)
