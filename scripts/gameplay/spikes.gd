@tool
extends Area2D

const SPIKE_STRIP_TEXTURE: Texture2D = preload("res://assets/generated/hazards/spikes_strip.png")
const SPIKE_BLOOD_TEXTURE: Texture2D = preload("res://assets/generated/hazards/spike_blood_single.png")
const SPIKE_REGION := Rect2(0, 0, 16, 16)
const SPIKE_VISUAL_Y := -8.0

@export var knockback_force: float = 300.0
@export var hit_direction: Vector2 = Vector2.UP

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visuals: Node2D = $Visuals

var spike_texture: AtlasTexture
var spike_sprites: Array[Sprite2D] = []
var blood_sprites: Array[Sprite2D] = []
var bloodied_spike_indices: Dictionary = {}
var layout_signature: String = ""

func _ready() -> void:
	_ensure_textures()
	_refresh_spikes(true)
	set_process(Engine.is_editor_hint())

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_refresh_spikes()

func _ensure_textures() -> void:
	if spike_texture != null:
		return

	spike_texture = AtlasTexture.new()
	spike_texture.atlas = SPIKE_STRIP_TEXTURE
	spike_texture.region = SPIKE_REGION

func _refresh_spikes(force: bool = false) -> void:
	if collision_shape == null or visuals == null:
		return

	var signature := _get_layout_signature()
	if not force and signature == layout_signature:
		return

	layout_signature = signature
	_rebuild_spikes()

func _get_layout_signature() -> String:
	var rectangle := collision_shape.shape as RectangleShape2D
	if rectangle == null:
		return "missing"
	return "%s|%s" % [rectangle.size, scale]

func _rebuild_spikes() -> void:
	_ensure_textures()
	_clear_visuals()

	var spike_count := _get_spike_count()
	var total_width := _get_total_width()
	var spacing := total_width / float(spike_count)
	visuals.scale = Vector2(_inverse_scale_component(scale.x), _inverse_scale_component(scale.y))

	for spike_index in range(spike_count):
		var spike_position := Vector2(
			-total_width * 0.5 + spacing * (spike_index + 0.5),
			SPIKE_VISUAL_Y
		)

		var spike := Sprite2D.new()
		spike.texture = spike_texture
		spike.centered = true
		spike.position = spike_position
		visuals.add_child(spike)
		spike_sprites.append(spike)

		var blood := Sprite2D.new()
		blood.texture = SPIKE_BLOOD_TEXTURE
		blood.centered = true
		blood.position = spike_position
		blood.visible = bloodied_spike_indices.has(spike_index)
		blood.z_index = 1
		visuals.add_child(blood)
		blood_sprites.append(blood)

func _clear_visuals() -> void:
	for child in visuals.get_children():
		visuals.remove_child(child)
		child.queue_free()
	spike_sprites.clear()
	blood_sprites.clear()

func _get_spike_count() -> int:
	return max(1, ceili(_get_total_width() / SPIKE_REGION.size.x))

func _get_total_width() -> float:
	var rectangle := collision_shape.shape as RectangleShape2D
	if rectangle == null:
		return SPIKE_REGION.size.x
	return max(rectangle.size.x * absf(scale.x), SPIKE_REGION.size.x)

func _inverse_scale_component(value: float) -> float:
	if absf(value) <= 0.001:
		return 1.0
	return 1.0 / value

func _mark_spike_bloodied(spike_index: int) -> void:
	if spike_index < 0 or spike_index >= blood_sprites.size():
		return
	bloodied_spike_indices[spike_index] = true
	blood_sprites[spike_index].show()

func _get_nearest_spike_index(global_hit_position: Vector2) -> int:
	if spike_sprites.is_empty():
		return -1

	var local_hit_position := visuals.to_local(global_hit_position)
	var nearest_index := 0
	var nearest_distance := INF
	for spike_index in range(spike_sprites.size()):
		var distance := absf(local_hit_position.x - spike_sprites[spike_index].position.x)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = spike_index
	return nearest_index

func _on_body_entered(body: Node) -> void:
	var player := body as Player
	if player != null:
		_refresh_spikes()
		GameSfx.play(self, &"hazard", global_position)
		if player.hurt(hit_direction, knockback_force, &"spikes", self):
			_mark_spike_bloodied(_get_nearest_spike_index(player.global_position))
