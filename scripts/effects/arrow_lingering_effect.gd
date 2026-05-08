class_name ArrowLingeringEffect
extends Node2D

var _follow_target: Node2D
var _follow_rotation: bool = true
var _follow_offset: Vector2 = Vector2.ZERO
var _release_duration: float = 0.0
var _release_time_left: float = 0.0
var _is_releasing: bool = false

func _ready() -> void:
	if _follow_target != null:
		_sync_to_target()
	set_process(_follow_target != null or _is_releasing)

func attach_to_target(target: Node2D, follow_rotation: bool = true, local_offset: Vector2 = Vector2.ZERO) -> void:
	_follow_target = target
	_follow_rotation = follow_rotation
	_follow_offset = local_offset
	_sync_to_target()
	set_process(true)

func release(duration: float = 0.0) -> void:
	_sync_to_target()
	_follow_target = null
	if duration <= 0.0:
		queue_free()
		return

	_release_duration = duration
	_release_time_left = duration
	_is_releasing = true
	_on_release_started()
	_on_release_progress(0.0)
	set_process(true)

func _process(delta: float) -> void:
	var keep_processing := false

	if _follow_target != null:
		if is_instance_valid(_follow_target):
			_sync_to_target()
			keep_processing = true
		else:
			_follow_target = null

	if _is_releasing:
		_release_time_left = max(_release_time_left - delta, 0.0)
		var progress := 1.0 - (_release_time_left / _release_duration)
		_on_release_progress(progress)
		keep_processing = true
		if _release_time_left <= 0.0:
			_is_releasing = false
			_on_release_finished()
			queue_free()
			return

	set_process(keep_processing)

func _sync_to_target() -> void:
	if _follow_target == null or not is_instance_valid(_follow_target):
		return
	global_position = _follow_target.to_global(_follow_offset)
	if _follow_rotation:
		global_rotation = _follow_target.global_rotation

func _on_release_started() -> void:
	pass

func _on_release_progress(_progress: float) -> void:
	pass

func _on_release_finished() -> void:
	pass
