extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const TERMINAL_VELOCITY = 1000

signal im_dead

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var jumping = false
var aiming = false

@export_color_no_alpha var player_color
@export_color_no_alpha var aim_color = Color("#FFF")
@export var left_button = "p1_left"
@export var right_button = "p1_right"
@export var up_button = "p1_up"
@export var down_button = "p1_down"
@export var use_button = "p1_use"

@export var deathParticle: PackedScene
@export var arrow: PackedScene

@export var arrow_count = 5

func other_player_on_head():
	for cast in $Casts.get_children():
		var ray = cast as RayCast2D
		ray.force_raycast_update()
		if ray.is_colliding() and ray.get_collider().is_in_group("player"):
			var other_player = ray.get_collider() as CharacterBody2D
			if other_player.velocity.y > 0:
				return true
	return false
	
func set_dead():
	emit_signal("im_dead")
	
	var par = deathParticle.instantiate()
	par.emitting = true
	par.position = position
	get_tree().current_scene.add_child(par)
	queue_free()

func _physics_process(delta):
	# Add the gravity
	if not is_on_floor() and velocity.y < TERMINAL_VELOCITY:
		velocity.y += gravity * delta
		
	aiming = Input.is_action_pressed(use_button)
	$Sprite2D.modulate = player_color
		
	if jumping and is_on_floor():
		$Landing.emitting = true
	jumping = not is_on_floor()

	# Player wrapping
	var width = ProjectSettings.get_setting("display/window/size/viewport_width", 320)
	var height = ProjectSettings.get_setting("display/window/size/viewport_height", 240)

	if position.y > height: position.y = 0
	if position.x > width: position.x = 0
	if position.y < 0: position.y = height
	if position.x < 0: position.x = width

	# Handle jump
	if Input.is_action_just_pressed(up_button) and is_on_floor() and not aiming:
		velocity.y = JUMP_VELOCITY
		
	if other_player_on_head():
		set_dead()

	# Get the input direction and handle the movement/deceleration.
	var direction = Input.get_vector(left_button, right_button, up_button, down_button)
	if direction != Vector2.ZERO and not aiming:
		velocity.x = direction.x * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	move_and_slide()
	
	if aiming and direction != Vector2.ZERO:
		$Sprite2D.modulate = aim_color

	# Shoot arrow
	if Input.is_action_just_released(use_button):
		if direction != Vector2.ZERO and arrow_count > 0:
			var arr = arrow.instantiate() as CharacterBody2D
			arr.position.x = position.x + 10 * sign(direction.x)
			arr.position.y = position.y + 30 * sign(direction.y)
			arr.direction = direction
			get_parent().add_child(arr)
			arrow_count -= 1
		
	# Arrow pickup
	$ArrowCount.text = str(arrow_count)
	for index in range(get_slide_collision_count()):
		var collision = get_slide_collision(index).get_collider()
		if collision.is_in_group("arrow"):
			arrow_count += 1
			collision.queue_free()
			
