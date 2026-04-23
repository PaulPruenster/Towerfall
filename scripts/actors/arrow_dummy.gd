extends Area2D

const PICKUP_TEXTURE_PATH: String = "res://assets/generated/arrows/arrow_pickup.png"

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	if not ResourceLoader.exists(PICKUP_TEXTURE_PATH, "Texture2D"):
		return

	var texture := load(PICKUP_TEXTURE_PATH) as Texture2D
	if texture == null:
		return

	sprite.texture = texture

func _on_body_entered(body: Node) -> void:
	var player := body as Player
	if player != null:
		player.add_arrows()
		queue_free()
