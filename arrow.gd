extends CharacterBody2D

@export var direction = Vector2(0,0)
@export var speed = 1000

@onready var trail_particles = $GPUParticles2D

const arrow_dummy = preload("res://arrow_dummy.tscn")
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var active = false

func shoot():
	active = true
	trail_particles.show()
	
func _physics_process(delta):
	rotation = atan2(direction.x, -direction.y)
	
	if not active:
		return

	var width = ProjectSettings.get_setting("display/window/size/viewport_width", 320)
	var height = ProjectSettings.get_setting("display/window/size/viewport_height", 240)
	if position.y > height: position.y = 0
	if position.x > width: position.x = 0
	if position.y < 0: position.y = height
	if position.x < 0: position.x = width
	
	direction.y += gravity * delta * 0.0002
	
	var collision_info = move_and_collide(direction.normalized() * delta * speed)
	if collision_info:
		if collision_info.get_collider().is_in_group("player"):
			collision_info.get_collider().set_dead()
		else:
			var dummy = arrow_dummy.instantiate()
			dummy.position = position
			dummy.rotation = atan2(direction.x, -direction.y)
			get_parent().add_child(dummy)
		queue_free()
