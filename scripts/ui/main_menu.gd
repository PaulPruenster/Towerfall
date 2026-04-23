extends Control

const LEVEL_1: PackedScene = preload("res://scenes/levels/level_1.tscn")
const LEVEL_2: PackedScene = preload("res://scenes/levels/level_2.tscn")
const LEVEL_3: PackedScene = preload("res://scenes/levels/level_3.tscn")
const MATCH_SETTINGS_SCRIPT = preload("res://scripts/systems/match_settings.gd")
const WATCH_LEVELS_DIR := "res://scenes/levels"
const WATCH_LEVEL_OVERRIDES := {
	"res://scenes/levels/duel_open.tscn": {
		"title": "Duel - Open",
		"description": "Flat open arena for fast duels.",
		"details": "Open field",
	},
	"res://scenes/levels/duel_platform.tscn": {
		"title": "Duel - Platform",
		"description": "Tiered platforms for vertical combat.",
		"details": "Platforms",
	},
	"res://scenes/levels/duel_wrap.tscn": {
		"title": "Duel - Wrap",
		"description": "Screen-wrapping arena.",
		"details": "Wrap",
	},
	"res://scenes/levels/level_1.tscn": {
		"title": "High Courtyard",
		"description": "Open lanes and a jump pad.",
		"details": "Jump pad  |  gates",
	},
	"res://scenes/levels/level_2.tscn": {
		"title": "Trap Circuit",
		"description": "Hazards and tighter timing.",
		"details": "Switch  |  spikes  |  platform",
	},
	"res://scenes/levels/level_3.tscn": {
		"title": "Split Tower",
		"description": "Vertical fights and recovery reads.",
		"details": "Vertical  |  split start  |  lift",
	},
}

enum MenuPage {
	HOME,
	PLAY,
	CONTROLS,
	WATCH,
}

@export var first_focus: Button

@onready var shell: Control = %Shell
@onready var accent_glow_top: ColorRect = %AccentGlowTop
@onready var accent_glow_bottom: ColorRect = %AccentGlowBottom
@onready var home_nav_button: Button = %HomeNavButton
@onready var play_nav_button: Button = %PlayNavButton
@onready var controls_nav_button: Button = %ControlsNavButton
@onready var home_panel: Control = %HomePanel
@onready var play_panel: Control = %PlayPanel
@onready var controls_panel: Control = %ControlsPanel
@onready var home_primary_button: Button = %HomePrimaryButton
@onready var home_secondary_button: Button = %HomeSecondaryButton
@onready var controls_back_button: Button = %ControlsBackButton
@onready var controls_play_button: Button = %ControlsPlayButton
@onready var play_back_button: Button = %PlayBackButton
@onready var start_arena_button: Button = %StartArenaButton
@onready var level_1_button: Button = %Level1Button
@onready var level_2_button: Button = %Level2Button
@onready var level_3_button: Button = %Level3Button
@onready var players_down_button: Button = %PlayersDownButton
@onready var players_up_button: Button = %PlayersUpButton
@onready var ai_down_button: Button = %AIDownButton
@onready var ai_up_button: Button = %AIUpButton
@onready var players_value: Label = %PlayersValue
@onready var ai_value: Label = %AIValue
@onready var roster_summary: Label = %RosterSummary
@onready var arena_name: Label = %ArenaName
@onready var arena_description: Label = %ArenaDescription
@onready var arena_details: Label = %ArenaDetails
@onready var watch_panel: Control = %WatchPanel
@onready var watch_nav_button: Button = %WatchNavButton
@onready var watch_back_button: Button = %WatchBackButton
@onready var watch_start_button: Button = %WatchStartButton
@onready var watch_arena_buttons: VBoxContainer = $OuterMargin/CenterContainer/Shell/ShellMargin/Layout/ContentCard/ContentMargin/Pages/WatchPanel/WatchArenaButtons
@onready var watch_duel_open_button: Button = %WatchDuelOpenButton
@onready var watch_duel_platform_button: Button = %WatchDuelPlatformButton
@onready var watch_duel_wrap_button: Button = %WatchDuelWrapButton
@onready var watch_level_1_button: Button = %WatchLevel1Button
@onready var watch_level_2_button: Button = %WatchLevel2Button
@onready var watch_level_3_button: Button = %WatchLevel3Button
@onready var watch_arena_name: Label = %WatchArenaName
@onready var watch_arena_description: Label = %WatchArenaDescription
@onready var watch_arena_details: Label = %WatchArenaDetails
@onready var watch_ai_down_button: Button = %WatchAIDownButton
@onready var watch_ai_up_button: Button = %WatchAIUpButton
@onready var watch_ai_value: Label = %WatchAIValue
@onready var watch_ai_summary: Label = %WatchAISummary

var page_panels: Dictionary = {}
var nav_buttons: Dictionary = {}
var level_details: Dictionary = {}
var watch_level_details: Dictionary = {}
var current_page: int = MenuPage.HOME
var selected_level_button: Button
var selected_watch_button: Button
var watch_level_buttons: Array[Button] = []
var watch_ai_count: int = 2
var human_player_count: int = MATCH_SETTINGS_SCRIPT.DEFAULT_HUMAN_PLAYERS
var ai_player_count: int = MATCH_SETTINGS_SCRIPT.DEFAULT_AI_PLAYERS

func _ready() -> void:
	var match_settings = _get_match_settings()
	if match_settings != null:
		human_player_count = match_settings.human_player_count
		ai_player_count = match_settings.ai_player_count

	page_panels = {
		MenuPage.HOME: home_panel,
		MenuPage.PLAY: play_panel,
		MenuPage.CONTROLS: controls_panel,
		MenuPage.WATCH: watch_panel,
	}
	nav_buttons = {
		MenuPage.HOME: home_nav_button,
		MenuPage.PLAY: play_nav_button,
		MenuPage.CONTROLS: controls_nav_button,
		MenuPage.WATCH: watch_nav_button,
	}
	level_details = {
		level_1_button: {
			"scene": LEVEL_1,
			"title": "High Courtyard",
			"description": "Open lanes and a jump pad.",
			"details": "Jump pad  |  gates",
		},
		level_2_button: {
			"scene": LEVEL_2,
			"title": "Trap Circuit",
			"description": "Hazards and tighter timing.",
			"details": "Switch  |  spikes  |  platform",
		},
		level_3_button: {
			"scene": LEVEL_3,
			"title": "Split Tower",
			"description": "Vertical fights and recovery reads.",
			"details": "Vertical  |  split start  |  lift",
		},
	}

	for button in level_details.keys():
		button.focus_entered.connect(_select_level.bind(button))
		button.mouse_entered.connect(_select_level.bind(button))

	_refresh_match_setup()
	_populate_watch_levels()
	_refresh_watch_setup()
	_select_level(level_1_button)
	if not watch_level_buttons.is_empty():
		_select_watch_level(watch_level_buttons[0])
	_show_page(MenuPage.HOME, first_focus)
	_play_intro()
	_start_accent_motion()

func _input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null:
		return
	if not key_event.pressed or key_event.echo or key_event.keycode != KEY_ESCAPE:
		return
	if current_page == MenuPage.HOME:
		return
	get_viewport().set_input_as_handled()
	_show_page(MenuPage.HOME, home_primary_button)

func _play_intro() -> void:
	shell.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(shell, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _start_accent_motion() -> void:
	accent_glow_top.modulate.a = 0.55
	accent_glow_bottom.modulate.a = 0.85
	var tween := create_tween()
	tween.set_loops()
	tween.set_parallel(true)
	tween.tween_property(accent_glow_top, "modulate:a", 0.9, 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(accent_glow_bottom, "modulate:a", 0.35, 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.chain()
	tween.set_parallel(true)
	tween.tween_property(accent_glow_top, "modulate:a", 0.45, 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(accent_glow_bottom, "modulate:a", 0.85, 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _show_page(page: int, focus_button: Control = null) -> void:
	current_page = page
	for key in page_panels.keys():
		var panel := page_panels[key] as Control
		panel.visible = key == page
	for key in nav_buttons.keys():
		var button := nav_buttons[key] as Button
		button.set_pressed_no_signal(key == page)
	if focus_button:
		focus_button.grab_focus()

func _select_level(button: Button) -> void:
	selected_level_button = button
	for level_button in level_details.keys():
		level_button.set_pressed_no_signal(level_button == button)

	var data: Dictionary = level_details.get(button, {}) as Dictionary
	if data.is_empty():
		return
	arena_name.text = str(data.get("title", ""))
	arena_description.text = str(data.get("description", ""))
	arena_details.text = str(data.get("details", ""))

func _start_selected_level() -> void:
	if selected_level_button == null:
		return
	var data: Dictionary = level_details.get(selected_level_button, {}) as Dictionary
	if data.is_empty():
		return
	var match_settings = _get_match_settings()
	if match_settings != null:
		match_settings.configure(human_player_count, ai_player_count)
	var scene: PackedScene = data.get("scene") as PackedScene
	if scene:
		get_tree().change_scene_to_packed(scene)

func _refresh_match_setup() -> void:
	var max_ai_players := _get_max_ai_player_count()
	human_player_count = clampi(human_player_count, 1, MATCH_SETTINGS_SCRIPT.MAX_PLAYERS)
	ai_player_count = clampi(ai_player_count, 0, max_ai_players)

	players_value.text = str(human_player_count)
	ai_value.text = str(ai_player_count)
	roster_summary.text = _get_match_setup_summary()

	players_down_button.disabled = human_player_count <= 1
	players_up_button.disabled = human_player_count >= MATCH_SETTINGS_SCRIPT.MAX_PLAYERS
	ai_down_button.disabled = ai_player_count <= 0
	ai_up_button.disabled = ai_player_count >= max_ai_players

func _get_match_setup_summary() -> String:
	var summary := "%d human" % human_player_count
	if human_player_count != 1:
		summary += "s"
	if ai_player_count > 0:
		summary += "  |  %d AI" % ai_player_count
		if ai_player_count != 1:
			summary += "s"
	summary += "  |  %d total" % (human_player_count + ai_player_count)
	return summary

func _get_max_ai_player_count() -> int:
	var match_settings = _get_match_settings()
	if match_settings != null:
		return match_settings.get_max_ai_count_for(human_player_count)
	return maxi(MATCH_SETTINGS_SCRIPT.MAX_PLAYERS - human_player_count, 0)

func _get_match_settings():
	return get_node_or_null("/root/MatchSettings")

func _show_home() -> void:
	_show_page(MenuPage.HOME, home_primary_button)

func _show_play() -> void:
	_show_page(MenuPage.PLAY, selected_level_button)

func _show_controls() -> void:
	_show_page(MenuPage.CONTROLS, controls_play_button)

func _show_watch() -> void:
	_show_page(MenuPage.WATCH, selected_watch_button if selected_watch_button != null else watch_back_button)

func _populate_watch_levels() -> void:
	watch_level_details.clear()
	watch_level_buttons.clear()

	var base_buttons: Array[Button] = [
		watch_duel_open_button,
		watch_duel_platform_button,
		watch_duel_wrap_button,
		watch_level_1_button,
		watch_level_2_button,
		watch_level_3_button,
	]
	var scene_data_list: Array[Dictionary] = []
	for scene_path in _get_watch_scene_paths():
		var data := _build_watch_level_data(scene_path)
		if not data.is_empty():
			scene_data_list.append(data)

	if scene_data_list.is_empty():
		for button in base_buttons:
			button.visible = false
			button.disabled = true
			button.set_pressed_no_signal(false)
		selected_watch_button = null
		watch_start_button.disabled = true
		watch_arena_name.text = "No arenas found"
		watch_arena_description.text = "Add scene files under scenes/levels to populate the watch menu."
		watch_arena_details.text = WATCH_LEVELS_DIR
		return

	var template_button := base_buttons[base_buttons.size() - 1]
	for index in range(scene_data_list.size()):
		var button: Button
		if index < base_buttons.size():
			button = base_buttons[index]
		else:
			button = _create_watch_button_from_template(template_button, index)
			base_buttons.append(button)
			button.pressed.connect(_select_watch_level.bind(button))

		var data := scene_data_list[index]
		button.visible = true
		button.disabled = false
		button.text = str(data.get("title", ""))
		button.focus_entered.connect(_select_watch_level.bind(button))
		button.mouse_entered.connect(_select_watch_level.bind(button))
		button.set_pressed_no_signal(false)
		watch_level_details[button] = data
		watch_level_buttons.append(button)

	for index in range(scene_data_list.size(), base_buttons.size()):
		var button := base_buttons[index]
		button.visible = false
		button.disabled = true
		button.set_pressed_no_signal(false)

	watch_start_button.disabled = false

func _get_watch_scene_paths() -> Array[String]:
	var scene_paths: Array[String] = []
	var dir := DirAccess.open(WATCH_LEVELS_DIR)
	if dir == null:
		return scene_paths

	var file_names := dir.get_files()
	file_names.sort()
	for file_name_variant in file_names:
		var file_name := str(file_name_variant)
		if file_name.get_extension() != "tscn":
			continue
		scene_paths.append("%s/%s" % [WATCH_LEVELS_DIR, file_name])
	return scene_paths

func _build_watch_level_data(scene_path: String) -> Dictionary:
	var scene := load(scene_path) as PackedScene
	if scene == null:
		return {}

	var data := (WATCH_LEVEL_OVERRIDES.get(scene_path, {}) as Dictionary).duplicate(true)
	var scene_name := scene_path.get_file().get_basename()
	if not data.has("title"):
		data["title"] = _format_scene_name(scene_name)
	if not data.has("description"):
		data["description"] = "Auto-discovered arena from scenes/levels."
	if not data.has("details"):
		data["details"] = scene_path.get_file()
	data["scene"] = scene
	return data

func _create_watch_button_from_template(template: Button, index: int) -> Button:
	var button := Button.new()
	button.name = "WatchArenaButton%d" % (index + 1)
	for property_path in [
		"toggle_mode",
		"custom_minimum_size",
		"layout_mode",
		"size_flags_horizontal",
		"theme_override_colors/font_color",
		"theme_override_colors/font_focus_color",
		"theme_override_font_sizes/font_size",
		"theme_override_styles/focus",
		"theme_override_styles/hover",
		"theme_override_styles/normal",
		"theme_override_styles/pressed",
	]:
		button.set(property_path, template.get(property_path))
	watch_arena_buttons.add_child(button)
	return button

func _format_scene_name(scene_name: String) -> String:
	var words := scene_name.replace("_", " ").replace("-", " ").split(" ", false)
	for index in range(words.size()):
		words[index] = str(words[index]).capitalize()
	return " ".join(words)

func _select_watch_level(button: Button) -> void:
	selected_watch_button = button
	for b in watch_level_details.keys():
		b.set_pressed_no_signal(b == button)
	var data: Dictionary = watch_level_details.get(button, {}) as Dictionary
	if data.is_empty():
		return
	watch_arena_name.text = str(data.get("title", ""))
	watch_arena_description.text = str(data.get("description", ""))
	watch_arena_details.text = str(data.get("details", ""))

func _refresh_watch_setup() -> void:
	watch_ai_count = clampi(watch_ai_count, 2, MATCH_SETTINGS_SCRIPT.MAX_PLAYERS)
	watch_ai_value.text = str(watch_ai_count)
	watch_ai_summary.text = "%d AI  |  0 humans" % watch_ai_count
	watch_ai_down_button.disabled = watch_ai_count <= 2
	watch_ai_up_button.disabled = watch_ai_count >= MATCH_SETTINGS_SCRIPT.MAX_PLAYERS

func _start_watch_match() -> void:
	if selected_watch_button == null:
		return
	var data: Dictionary = watch_level_details.get(selected_watch_button, {}) as Dictionary
	if data.is_empty():
		return
	var match_settings = _get_match_settings()
	if match_settings != null:
		match_settings.configure_ai_only(watch_ai_count)
	var scene: PackedScene = data.get("scene") as PackedScene
	if scene:
		get_tree().change_scene_to_packed(scene)

func _on_home_nav_button_pressed() -> void:
	_show_home()

func _on_play_nav_button_pressed() -> void:
	_show_play()

func _on_controls_nav_button_pressed() -> void:
	_show_controls()

func _on_home_primary_button_pressed() -> void:
	_show_play()

func _on_home_secondary_button_pressed() -> void:
	_show_controls()

func _on_controls_back_button_pressed() -> void:
	_show_home()

func _on_controls_play_button_pressed() -> void:
	_show_play()

func _on_play_back_button_pressed() -> void:
	_show_home()

func _on_start_arena_button_pressed() -> void:
	_start_selected_level()

func _on_level_1_pressed() -> void:
	_select_level(level_1_button)

func _on_level_2_pressed() -> void:
	_select_level(level_2_button)

func _on_level_3_pressed() -> void:
	_select_level(level_3_button)

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _on_players_down_button_pressed() -> void:
	human_player_count -= 1
	_refresh_match_setup()

func _on_players_up_button_pressed() -> void:
	human_player_count += 1
	_refresh_match_setup()

func _on_ai_down_button_pressed() -> void:
	ai_player_count -= 1
	_refresh_match_setup()

func _on_ai_up_button_pressed() -> void:
	ai_player_count += 1
	_refresh_match_setup()

func _on_watch_nav_button_pressed() -> void:
	_show_watch()

func _on_watch_back_button_pressed() -> void:
	_show_home()

func _on_watch_start_button_pressed() -> void:
	_start_watch_match()

func _on_watch_duel_open_pressed() -> void:
	_select_watch_level(watch_duel_open_button)

func _on_watch_duel_platform_pressed() -> void:
	_select_watch_level(watch_duel_platform_button)

func _on_watch_duel_wrap_pressed() -> void:
	_select_watch_level(watch_duel_wrap_button)

func _on_watch_level_1_pressed() -> void:
	_select_watch_level(watch_level_1_button)

func _on_watch_level_2_pressed() -> void:
	_select_watch_level(watch_level_2_button)

func _on_watch_level_3_pressed() -> void:
	_select_watch_level(watch_level_3_button)

func _on_watch_ai_down_pressed() -> void:
	watch_ai_count -= 1
	_refresh_watch_setup()

func _on_watch_ai_up_pressed() -> void:
	watch_ai_count += 1
	_refresh_watch_setup()
