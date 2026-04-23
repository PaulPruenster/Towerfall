extends Area2D

signal pressed(player)
signal targets_toggled(is_enabled)


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

func get_controlled_gates() -> Array[Node2D]:
	var gates: Array[Node2D] = []
	for target_path in target_nodes:
		var gate := get_node_or_null(target_path) as Node2D
		if gate != null:
			gates.append(gate)
	return gates

func controls_disabled_gate() -> bool:
	for gate in get_controlled_gates():
		if gate != null and gate.has_method("is_gate_enabled") and not gate.call("is_gate_enabled"):
			return true
	return false

func _set_targets_enabled(is_enabled: bool) -> void:
	for target_path in target_nodes:
		var node := get_node_or_null(target_path)
		if node != null and node.has_method("set_gate_enabled"):
			node.set_gate_enabled(is_enabled)
	targets_toggled.emit(is_enabled)

func _on_body_entered(body: Node) -> void:
	var player := body as Player
	if player == null:
		return

	_set_pressed(true)
	_set_targets_enabled(true)
	timer.start(active_duration)
	GameSfx.play(self, &"switch_press", global_position)
	pressed.emit(player)

func _on_timer_timeout() -> void:
	_set_pressed(false)
	_set_targets_enabled(false)
