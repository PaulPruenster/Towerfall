extends Control

@onready var level1 = preload("res://scenes/level1.tscn")

func _ready():
	$HBoxContainer/Level1.grab_focus()

func _on_level_1_pressed():
	get_tree().change_scene_to_packed(level1)

func _on_level_2_pressed():
	pass # Replace with function body.

func _on_level_3_pressed():
	pass # Replace with function body.
