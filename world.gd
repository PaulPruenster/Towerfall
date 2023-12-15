extends Node2D

func _on_player_1_im_dead():
	$Label.text = "Player 2 wins!"
	$Timer.start()

func _on_player_2_im_dead():
	$Label.text = "Player 1 wins!"
	$Timer.start()	

func _on_timer_timeout():
	$Label.text = "Towerfall"
	get_tree().reload_current_scene()
