extends Control
class_name PauseMenu

signal resume_requested
signal restart_requested
signal main_menu_requested

@export var first_focus: Button

@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	hide()

func open(menu_title: String = "Paused", subtitle: String = "Resume the match or change arenas.") -> void:
	title_label.text = menu_title
	subtitle_label.text = subtitle
	show()
	if first_focus:
		first_focus.grab_focus()

func close() -> void:
	hide()

func _on_resume_button_pressed() -> void:
	resume_requested.emit()

func _on_restart_button_pressed() -> void:
	restart_requested.emit()

func _on_main_menu_button_pressed() -> void:
	main_menu_requested.emit()
