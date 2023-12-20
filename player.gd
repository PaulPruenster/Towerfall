extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const TERMINAL_VELOCITY = 1000

signal im_dead

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var jumping = false
var aiming = false
var crouching = false

@export_color_no_alpha var player_color
@export_color_no_alpha var aim_color = Color("#FFF")
@export var left_button = "p1_left"
@export var right_button = "p1_right"
@export var up_button = "p1_up"
@export var down_button = "p1_down"
@export var use_button = "p1_use"
@export var jump_button = "p1_jump"

@export var deathParticle: PackedScene
@export var arrow: PackedScene

@export var health = 2
@export var arrow_count = 5

var current_arrow: CharacterBody2D
	
func hurt():
	if health > 1:
		health -= 1
		return

	# Die a death of dead
	emit_signal("im_dead")
	
	if current_arrow:
		current_arrow.queue_free()
	
	var par = deathParticle.instantiate()
	par.emitting = true
	par.position = position
	get_tree().current_scene.add_child(par)
	
	queue_free()
	
func can_shoot(direction: Vector2):
	if direction.y > 0 and is_on_floor():
		return false
	return direction != Vector2.ZERO and arrow_count > 0
	
func set_crouching(crouching_val: bool):
	if crouching != crouching_val:
		$Body.scale.y *= 0.5 if crouching_val else 2.0
		$Sprite2D.scale.y *= 0.5 if crouching_val else 2.0
		crouching = crouching_val

func _physics_process(delta):
	# Add the gravity
	if not is_on_floor() and velocity.y < TERMINAL_VELOCITY:
		if crouching:
			velocity.y += 2 * gravity * delta
		else:
			velocity.y += gravity * delta
		
	aiming = Input.is_action_pressed(use_button)
	if Input.is_action_just_pressed(use_button):
		set_crouching(false)
		
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
	if Input.is_action_just_pressed(jump_button) and is_on_floor() and not aiming:
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	var direction = Input.get_vector(left_button, right_button, up_button, down_button)
	if direction != Vector2.ZERO and not aiming:
		velocity.x = direction.x * SPEED
		

	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	move_and_slide()
	
	# Crouch
	if not aiming and Input.is_action_just_pressed(down_button):
		set_crouching(true)
	if  Input.is_action_just_released(down_button):
		set_crouching(false)
	
	# Aim and shoot (np hard)
	if aiming:
		$Sprite2D.modulate = aim_color
		
		if can_shoot(direction):
			# spawn arrow
			if not current_arrow:
				current_arrow = arrow.instantiate() as CharacterBody2D
				get_parent().add_child(current_arrow)
			# update arrow position and rotation
			current_arrow.position.x = position.x + 20 * sign(direction.x)
			current_arrow.position.y = position.y + 40 * sign(direction.y)
			current_arrow.direction = direction
		elif current_arrow:
			# delete arrow
			current_arrow.queue_free()
			current_arrow =null

	if current_arrow and Input.is_action_just_released(use_button):
		if can_shoot(direction):
			current_arrow.shoot()
			arrow_count -= 1
		else:
			current_arrow.queue_free()
		current_arrow = null
			

	$ArrowCount.text = str(arrow_count)
	$HealthCount.text = str(health)

func _on_area_2d_body_entered(body: Node):
	if body != self and body.is_in_group("player"):
		hurt()
