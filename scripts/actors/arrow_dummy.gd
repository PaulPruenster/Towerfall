extends Area2D

const PICKUP_TEXTURE_PATH: String = "res://assets/generated/arrows/arrow_pickup.png"

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	var image := Image.new()
	if image.load(PICKUP_TEXTURE_PATH) != OK:
		return
	sprite.texture = ImageTexture.create_from_image(image)

func _on_body_entered(body: Node) -> void:
	var player := body as Player
	if player != null:
		player.add_arrows()
		queue_free()
