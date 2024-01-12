extends Area2D

@export var timer_length = 5

@onready var timer = $Regeneration
@onready var particles = $Recharged
@onready var progress = $ProgressBar
@onready var animated_sprite = $AnimatedSprite2D

var lootable = true

func _ready():
	set_lootable(true)
	timer.wait_time = timer_length
	
func _physics_process(delta):
	progress.value = (timer_length - timer.time_left)/timer_length * 100

func set_lootable(new_val: bool):
	lootable = new_val
	if new_val:
		animated_sprite.frame = 0
		particles.emitting = true
		progress.hide()
	else:
		animated_sprite.frame = 1
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
