extends Node2D

@onready var timer = $RestartTimer
@onready var status = $Label
@onready var default = $Label.text

func _on_player_1_im_dead():
	status.text = "Player 2 wins!"
	timer.start()

func _on_player_2_im_dead():
	status.text = "Player 1 wins!"
	timer.start()

func _on_timer_timeout():
	status.text = default
	get_tree().reload_current_scene()
