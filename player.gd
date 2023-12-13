extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const TERMINAL_VELOCITY = 1000

signal im_dead

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

@export_color_no_alpha var PlayerColor
@export var left_button = "ui_left"
@export var right_button = "ui_right"
@export var jump_button = "ui_accept"

@export var deathParticle: PackedScene

func _ready():
	$Sprite2D.modulate = PlayerColor

func _physics_process(delta):
	# Add the gravity
	if not is_on_floor() and velocity.y < TERMINAL_VELOCITY:
		velocity.y += gravity * delta	

	# Player wrapping
	var width = ProjectSettings.get_setting("display/window/size/viewport_width", 320)
	var height = ProjectSettings.get_setting("display/window/size/viewport_height", 240)

	if position.y > height and velocity.y > 0: position.y = 0
	if position.x > width and velocity.x > 0: position.x = 0
	if position.y <= 0 and velocity.y < 0: position.y = height
	if position.x <= 0 and velocity.x < 0: position.x = width

	# Handle jump
	if Input.is_action_just_pressed(jump_button) and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	var direction = Input.get_axis(left_button, right_button)
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
	
	if $HeadCast.is_colliding():
		var body = $HeadCast.get_collider()
		if body.is_in_group("player"):
			emit_signal("im_dead")
			
			var par = deathParticle.instantiate()
			par.emitting = true
			par.position = position
			get_tree().current_scene.add_child(par)
			queue_free()
