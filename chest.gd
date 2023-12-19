extends Area2D

@export_color_no_alpha var color
@export var timer_lenght = 10

var lootable = true

func _ready():
	set_lootable(true)
	$Regeneration.wait_time = timer_lenght
	
func set_lootable(new_val: bool):
	lootable = new_val
	if new_val:
		$Sprite2D.modulate = color
		$Recharged.emitting = true
	else:
		$Sprite2D.modulate = Color(color, 0.5)
		$Regeneration.start()
	
func apply_effect(player: CharacterBody2D):
	if player.arrow_count < 5:
		player.arrow_count = 5
	else:
		player.health += 1

func _on_body_entered(body):
	if lootable and body.is_in_group("player"):
		apply_effect(body)
		set_lootable(false)

func _on_regeneration_timeout():
	set_lootable(true)
