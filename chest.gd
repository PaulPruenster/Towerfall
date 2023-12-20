extends Area2D

@export_color_no_alpha var color
@export var timer_length = 5

@onready var sprite = $Sprite2D
@onready var timer = $Regeneration
@onready var particles = $Recharged
@onready var progress = $ProgressBar

var lootable = true

func _ready():
	set_lootable(true)
	timer.wait_time = timer_length
	
func _physics_process(delta):
	progress.value = (timer_length - timer.time_left)/timer_length * 100

func set_lootable(new_val: bool):
	lootable = new_val
	if new_val:
		sprite.modulate = color
		particles.emitting = true
		progress.hide()
	else:
		sprite.modulate = Color(color, 0.5)
		timer.start()
		progress.show()
	
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
