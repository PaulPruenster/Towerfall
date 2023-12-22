extends Node2D

@export var jumping_force_y = -1050

func apply_effect(player: CharacterBody2D):
	player.velocity.y = jumping_force_y

func _on_area_2d_body_entered(body):
	if body.is_in_group("player"):
		apply_effect(body)
