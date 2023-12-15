extends CharacterBody2D

@export var direction = Vector2(0,0)
@export var speed = 1000

func _physics_process(delta):
	var width = ProjectSettings.get_setting("display/window/size/viewport_width", 320)
	var height = ProjectSettings.get_setting("display/window/size/viewport_height", 240)
	if position.y > height: position.y = 0
	if position.x > width: position.x = 0
	if position.y < 0: position.y = height
	if position.x < 0: position.x = width
	
	rotation = atan2(direction.x, -direction.y)
	
	var collision_info = move_and_collide(direction.normalized() * delta * speed)
	if collision_info:
		queue_free()
		if collision_info.get_collider().is_in_group("player"):
			collision_info.get_collider().set_dead()
		
