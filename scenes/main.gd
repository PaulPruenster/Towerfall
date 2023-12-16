extends Control

@onready var level1 = preload("res://scenes/level_1.tscn")
@onready var level2 = preload("res://scenes/level_2.tscn")
@onready var level3 = preload("res://scenes/level_3.tscn")
@export var first_focus: Button

func _ready():
	first_focus.grab_focus()

func _on_level_1_pressed():
	get_tree().change_scene_to_packed(level1)

func _on_level_2_pressed():
	get_tree().change_scene_to_packed(level2)

func _on_level_3_pressed():
	get_tree().change_scene_to_packed(level3)
