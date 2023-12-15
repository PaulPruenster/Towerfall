extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const TERMINAL_VELOCITY = 1000

signal im_dead

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var jumping = false

@export_color_no_alpha var PlayerColor
@export var left_button = "ui_left"
@export var right_button = "ui_right"
@export var jump_button = "ui_accept"

@export var deathParticle: PackedScene

func other_player_on_head():
	for cast in $Casts.get_children():
		var ray = cast as RayCast2D
		ray.force_raycast_update()
		if ray.is_colliding() and ray.get_collider().is_in_group("player"):
			var other_player = ray.get_collider() as CharacterBody2D
			if other_player.velocity.y > 0:
				return true
	return false

func _ready():
	$Sprite2D.modulate = PlayerColor

func _physics_process(delta):
	# Add the gravity
	if not is_on_floor() and velocity.y < TERMINAL_VELOCITY:
		velocity.y += gravity * delta
	
	if jumping and is_on_floor():
		$Landing.emitting = true
	
	jumping = not is_on_floor()

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

	if other_player_on_head():
		emit_signal("im_dead")
		
		var par = deathParticle.instantiate()
		par.emitting = true
		par.position = position
		get_tree().current_scene.add_child(par)
		queue_free()
