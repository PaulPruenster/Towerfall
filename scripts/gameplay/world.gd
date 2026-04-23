extends Node2D

signal match_setup_complete(players)
signal match_resolved(result)

const MAIN_MENU_SCENE_PATH := "res://scenes/ui/main_menu.tscn"
const PLAYER_SCENE: PackedScene = preload("res://scenes/actors/player.tscn")
const AI_DEBUG_OVERLAY_SCENE: PackedScene = preload("res://scenes/ui/ai_debug_overlay.tscn")
const MATCH_SETTINGS_SCRIPT = preload("res://scripts/systems/match_settings.gd")

@onready var timer: Timer = $RestartTimer
@onready var hud: HUDController = $HUD
@onready var status_panel: PanelContainer = $LevelOverlay/TopBar/StatusCenter/StatusPanel
@onready var status: Label = $LevelOverlay/TopBar/StatusCenter/StatusPanel/StatusMargin/StatusLabel
@onready var pause_menu: PauseMenu = $LevelOverlay/PauseMenu
@onready var spawn_points_root: Node = $SpawnPoints

var shake_time_left: float = 0.0
var shake_strength: float = 0.0
var base_canvas_transform: Transform2D
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var hit_stop_request_id: int = 0
var default_status: String = ""
var round_resolved: bool = false
var player_roster: Array[Player] = []
var eliminated_player_ids: Dictionary = {}
var ai_debug_overlay: AIDebugOverlay

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	base_canvas_transform = get_viewport().canvas_transform
	_configure_rng()
	get_tree().paused = false
	Engine.time_scale = 1.0
	pause_menu.resume_requested.connect(_on_pause_menu_resume_requested)
	pause_menu.restart_requested.connect(_on_pause_menu_restart_requested)
	pause_menu.main_menu_requested.connect(_on_pause_menu_main_menu_requested)
	_setup_ai_debug_overlay()
	_setup_match()
	_set_status(default_status)

func _input(event: InputEvent) -> void:
	if _is_ai_debug_toggle_requested(event):
		get_viewport().set_input_as_handled()
		if ai_debug_overlay != null:
			ai_debug_overlay.toggle_overlay()
		return
	if not _is_pause_requested(event):
		return
	get_viewport().set_input_as_handled()
	if get_tree().paused:
		_resume_game()
	else:
		_pause_game()

func _process(delta: float) -> void:
	if get_tree().paused:
		if get_viewport().canvas_transform != base_canvas_transform:
			get_viewport().canvas_transform = base_canvas_transform
		return

	if shake_time_left <= 0.0:
		if get_viewport().canvas_transform != base_canvas_transform:
			get_viewport().canvas_transform = base_canvas_transform
		return

	shake_time_left = max(shake_time_left - delta, 0.0)
	var offset := Vector2(
		rng.randf_range(-shake_strength, shake_strength),
		rng.randf_range(-shake_strength, shake_strength)
	)
	get_viewport().canvas_transform = base_canvas_transform.translated(offset)
	shake_strength = lerpf(shake_strength, 0.0, delta * 10.0)

func trigger_screenshake(intensity: float = 8.0, duration: float = 0.12) -> void:
	shake_time_left = max(shake_time_left, duration)
	shake_strength = max(shake_strength, intensity)

func trigger_hit_stop(duration: float = 0.05, slow_scale: float = 0.08) -> void:
	hit_stop_request_id += 1
	var request_id := hit_stop_request_id
	Engine.time_scale = min(Engine.time_scale, slow_scale)
	await get_tree().create_timer(duration, true, false, true).timeout
	if request_id == hit_stop_request_id:
		Engine.time_scale = 1.0

func _setup_match() -> void:
	player_roster.clear()
	eliminated_player_ids.clear()
	round_resolved = false

	var roster_config := _build_match_roster()
	var spawn_points := _get_spawn_points()
	var spawn_count := mini(roster_config.size(), spawn_points.size())

	for slot in range(spawn_count):
		var player := _spawn_player(roster_config[slot], spawn_points[slot])
		if player == null:
			continue
		player_roster.append(player)

	if hud != null:
		hud.bind_players(player_roster)
	if ai_debug_overlay != null:
		ai_debug_overlay.bind_players(player_roster)
	match_setup_complete.emit(player_roster.duplicate())

func _setup_ai_debug_overlay() -> void:
	ai_debug_overlay = AI_DEBUG_OVERLAY_SCENE.instantiate() as AIDebugOverlay
	if ai_debug_overlay != null:
		add_child(ai_debug_overlay)
		var match_settings = _get_match_settings()
		if match_settings != null and bool(match_settings.get("ai_debug_open")):
			ai_debug_overlay.set_overlay_enabled(true)

func _build_match_roster() -> Array[Dictionary]:
	var match_settings = _get_match_settings()
	if match_settings != null:
		return match_settings.build_match_roster()

	var fallback_settings = MATCH_SETTINGS_SCRIPT.new()
	return fallback_settings.build_match_roster()

func _get_match_settings():
	return get_node_or_null("/root/MatchSettings")

func _get_spawn_points() -> Array[Marker2D]:
	var spawn_points: Array[Marker2D] = []
	if spawn_points_root == null:
		return spawn_points

	for child in spawn_points_root.get_children():
		var marker := child as Marker2D
		if marker != null:
			spawn_points.append(marker)

	spawn_points.sort_custom(_sort_spawn_points)
	return spawn_points

func _sort_spawn_points(a: Marker2D, b: Marker2D) -> bool:
	return a.name.naturalnocasecmp_to(b.name) < 0

func _spawn_player(config: Dictionary, spawn_point: Marker2D) -> Player:
	var player := PLAYER_SCENE.instantiate() as Player
	if player == null:
		return null

	var slot := int(config.get("slot", 0))
	player.name = "Player%d" % (slot + 1)
	player.position = to_local(spawn_point.global_position)
	player.player_color = config.get("player_color", Color.WHITE)
	player.left_button = config.get("left_button", player.left_button)
	player.right_button = config.get("right_button", player.right_button)
	player.up_button = config.get("up_button", player.up_button)
	player.down_button = config.get("down_button", player.down_button)
	player.use_button = config.get("use_button", player.use_button)
	player.jump_button = config.get("jump_button", player.jump_button)
	player.dash_button = config.get("dash_button", player.dash_button)
	player.set_meta(&"match_display_name", str(config.get("display_name", player.name)))
	player.set_meta(&"match_slot", slot)
	player.set_meta(&"roster_entry", config.duplicate(true))
	player.set_meta(&"eval_role", str(config.get("eval_role", "")))
	player.set_meta(&"eval_id", str(config.get("eval_id", "")))

	var ai_controller := player.get_node_or_null(^"AIController") as AIController
	if ai_controller != null:
		ai_controller.enabled = bool(config.get("is_ai", false))
		ai_controller.difficulty = float(config.get("ai_difficulty", ai_controller.difficulty))

	add_child(player)
	player.im_dead.connect(_on_player_im_dead.bind(player))
	return player

func _on_player_im_dead(player: Player) -> void:
	if player == null:
		return
	eliminated_player_ids[player.get_instance_id()] = true
	call_deferred("_resolve_round_if_needed")

func _resolve_round_if_needed() -> void:
	if round_resolved:
		return

	var remaining_players := _get_remaining_players()
	if remaining_players.size() > 1:
		return

	round_resolved = true
	var result := {
		"winner_name": "",
		"winner_slot": -1,
		"winner_role": "",
		"winner_id": "",
		"draw": remaining_players.is_empty(),
		"remaining_players": _serialize_players(remaining_players),
	}
	if remaining_players.size() == 1:
		var winner := remaining_players[0]
		var winner_name := str(winner.get_meta(&"match_display_name", winner.name))
		_set_status("%s wins!" % winner_name)
		result["winner_name"] = winner_name
		result["winner_slot"] = int(winner.get_meta(&"match_slot", -1))
		result["winner_role"] = str(winner.get_meta(&"eval_role", ""))
		result["winner_id"] = str(winner.get_meta(&"eval_id", ""))
	else:
		_set_status("Match over")
	match_resolved.emit(result)
	if _should_auto_restart_round():
		timer.start()

func _get_remaining_players() -> Array[Player]:
	var remaining_players: Array[Player] = []
	for player in player_roster:
		if not is_instance_valid(player):
			continue
		if eliminated_player_ids.has(player.get_instance_id()):
			continue
		remaining_players.append(player)
	return remaining_players

func _on_timer_timeout() -> void:
	_set_status(default_status)
	get_tree().reload_current_scene()

func _serialize_players(players: Array[Player]) -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for player in players:
		if player == null:
			continue
		serialized.append({
			"name": str(player.get_meta(&"match_display_name", player.name)),
			"slot": int(player.get_meta(&"match_slot", -1)),
			"role": str(player.get_meta(&"eval_role", "")),
			"eval_id": str(player.get_meta(&"eval_id", "")),
		})
	return serialized

func _should_auto_restart_round() -> bool:
	var match_settings = _get_match_settings()
	if match_settings != null and match_settings.has_method("should_auto_restart_round"):
		return bool(match_settings.call("should_auto_restart_round"))
	return true

func _exit_tree() -> void:
	if get_tree():
		get_tree().paused = false
	hit_stop_request_id += 1
	Engine.time_scale = 1.0
	if is_inside_tree():
		get_viewport().canvas_transform = base_canvas_transform

func _pause_game() -> void:
	if get_tree().paused:
		return
	_reset_feedback()
	pause_menu.open("Arena Paused", "Resume the match, restart this arena, or return to the main menu.")
	get_tree().paused = true

func _resume_game() -> void:
	if not get_tree().paused:
		return
	pause_menu.close()
	get_tree().paused = false

func _set_status(message: String) -> void:
	status.text = message
	status_panel.visible = not message.is_empty()

func _reset_feedback() -> void:
	hit_stop_request_id += 1
	shake_time_left = 0.0
	shake_strength = 0.0
	Engine.time_scale = 1.0
	get_viewport().canvas_transform = base_canvas_transform

func _is_pause_requested(event: InputEvent) -> bool:
	if event.is_echo():
		return false
	if event.is_action_pressed("pause_game"):
		return true
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and key_event.keycode == KEY_ESCAPE

func _is_ai_debug_toggle_requested(event: InputEvent) -> bool:
	if event.is_echo():
		return false
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and key_event.keycode == KEY_F7

func _on_pause_menu_resume_requested() -> void:
	_resume_game()

func _on_pause_menu_restart_requested() -> void:
	_resume_game()
	_set_status(default_status)
	get_tree().reload_current_scene()

func _on_pause_menu_main_menu_requested() -> void:
	_resume_game()
	_set_status(default_status)
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

func _configure_rng() -> void:
	var match_settings = _get_match_settings()
	if match_settings != null and match_settings.has_method("build_rng"):
		rng = match_settings.call("build_rng", "world:%s" % scene_file_path)
	else:
		rng.randomize()
