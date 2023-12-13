extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_player_1_im_dead():
	$Label.text = "Player 2 wins!"
	$Timer.start()

func _on_player_2_im_dead():
	$Label.text = "Player 1 wins!"
	$Timer.start()	

func _on_timer_timeout():
	$Label.text = "Towerfall"
	get_tree().reload_current_scene()
