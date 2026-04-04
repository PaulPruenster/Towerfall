extends Node2D

@export_node_path("Node2D") var target_node: NodePath
@export var starts_enabled: bool = true
@onready var _target_node: Node2D = get_node(target_node) as Node2D

@onready var ap: AnimationPlayer = $AnimationPlayer

var player_in_area: CharacterBody2D
var gate_ready_to_open: bool = true
var ignore_player: CharacterBody2D
var gate_enabled: bool = true

func _ready() -> void:
	gate_enabled = starts_enabled
	_update_visual_state()

func set_gate_enabled(is_enabled: bool) -> void:
	gate_enabled = is_enabled
	_update_visual_state()

func _update_visual_state() -> void:
	modulate = Color.WHITE if gate_enabled else Color(0.45, 0.45, 0.45, 1.0)

func _on_area_2d_body_entered(body: Node) -> void:
	var player := body as CharacterBody2D
	if player and player.is_in_group("player") and gate_enabled and gate_ready_to_open and ignore_player != player:
		GameSfx.play(self, &"gate_open", global_position)
		ap.play("open")
		gate_ready_to_open = false
		player_in_area = player

func _on_area_2d_body_exited(body: Node) -> void:
	var player := body as CharacterBody2D
	if player == player_in_area:
		player_in_area = null
	if player == ignore_player:
		ignore_player = null

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "open":
		if player_in_area != null:
			_target_node.ignore_player = player_in_area
			player_in_area.global_position = _target_node.global_position
			GameSfx.play(self, &"gate_teleport", global_position)
		ap.play("close")
	if anim_name == "close":
		ap.play("RESET")
		gate_ready_to_open = true
