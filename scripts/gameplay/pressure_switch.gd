extends Area2D


@export var active_duration: float = 4.0
@export var target_nodes: Array[NodePath] = []

@onready var indicator: Sprite2D = $Sprite2D
@onready var timer: Timer = $Timer

var up_texture: Texture2D
var down_texture: Texture2D

func _ready() -> void:
	up_texture = indicator.texture
	down_texture = preload("res://assets/0x72_DungeonTilesetII_v1.6/0x72_DungeonTilesetII_v1.6/frames/button_red_down.png")
	timer.wait_time = active_duration
	_set_pressed(false)

func _set_pressed(is_pressed: bool) -> void:
	indicator.texture = down_texture if is_pressed else up_texture

func _set_targets_enabled(is_enabled: bool) -> void:
	for target_path in target_nodes:
		var node := get_node_or_null(target_path)
		if node != null and node.has_method("set_gate_enabled"):
			node.set_gate_enabled(is_enabled)

func _on_body_entered(body: Node) -> void:
	var player := body as Player
	if player == null:
		return

	_set_pressed(true)
	_set_targets_enabled(true)
	timer.start(active_duration)
	GameSfx.play(self, &"switch_press", global_position)

func _on_timer_timeout() -> void:
	_set_pressed(false)
	_set_targets_enabled(false)
