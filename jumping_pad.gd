extends Node2D

@export var jumping_force_y = -1050

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func apply_effect(player: CharacterBody2D):
	player.velocity.y = jumping_force_y

func _on_area_2d_body_entered(body):
	if body.is_in_group("player"):
		apply_effect(body)
