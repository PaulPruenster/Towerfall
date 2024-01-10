extends Node2D

@export_node_path var target_node
@onready var _target_node = get_node(target_node)

@onready var ap = $AnimationPlayer

var player_in_area = null
var gate_ready_to_open = true
var ignore_player = null

func _on_area_2d_body_entered(body):
	if body.is_in_group("player") and gate_ready_to_open == true and ignore_player != body:
		ap.play("open")
		gate_ready_to_open = false
		player_in_area = body

func _on_area_2d_body_exited(body):
	player_in_area = null
	if ignore_player == body:
		ignore_player = null

func _on_animation_player_animation_finished(anim_name):
	if anim_name == "open":
		if player_in_area != null:
			_target_node.ignore_player = player_in_area 
			player_in_area.position = _target_node.position
		ap.play("close")
	if anim_name == "close":
		ap.play("RESET")
		gate_ready_to_open = true
