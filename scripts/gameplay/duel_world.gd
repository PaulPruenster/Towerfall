# scripts/gameplay/duel_world.gd
# Minimal arena world for synthetic Tier 3 duel slices.
# Provides the same signals and match-lifecycle API as world.gd
# without any HUD, level overlay, or tile-map dependencies.
extends Node2D

signal match_setup_complete(players)
signal match_resolved(result)

const PLAYER_SCENE: PackedScene = preload("res://scenes/actors/player.tscn")
const MATCH_SETTINGS_SCRIPT = preload("res://scripts/systems/match_settings.gd")

@onready var timer: Timer = $RestartTimer
@onready var spawn_points_root: Node = $SpawnPoints

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var round_resolved: bool = false
var player_roster: Array[Player] = []
var eliminated_player_ids: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_configure_rng()
	_setup_match()

func _configure_rng() -> void:
	var match_settings = _get_match_settings()
	if match_settings != null and match_settings.has_method("build_rng"):
		var result = match_settings.call("build_rng", "world", 0)
		if result is RandomNumberGenerator:
			rng = result
			return
	rng = RandomNumberGenerator.new()

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

	match_setup_complete.emit(player_roster.duplicate())

func _get_spawn_points() -> Array[Marker2D]:
	var points: Array[Marker2D] = []
	if spawn_points_root == null:
		return points
	for child in spawn_points_root.get_children():
		var marker := child as Marker2D
		if marker != null:
			points.append(marker)
	points.sort_custom(func(a: Marker2D, b: Marker2D) -> bool:
		return a.name.naturalnocasecmp_to(b.name) < 0
	)
	return points

func _build_match_roster() -> Array[Dictionary]:
	var match_settings = _get_match_settings()
	if match_settings != null:
		return match_settings.build_match_roster()
	var fallback := MATCH_SETTINGS_SCRIPT.new()
	return fallback.build_match_roster()

func _get_match_settings() -> Node:
	return get_node_or_null("/root/MatchSettings")

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
	var remaining := _get_remaining_players()
	if remaining.size() > 1:
		return
	round_resolved = true
	var result := {
		"winner_name": "",
		"winner_slot": -1,
		"winner_role": "",
		"winner_id": "",
		"draw": remaining.is_empty(),
		"remaining_players": _serialize_players(remaining),
	}
	if remaining.size() == 1:
		var winner := remaining[0]
		result["winner_name"] = str(winner.get_meta(&"match_display_name", winner.name))
		result["winner_slot"] = int(winner.get_meta(&"match_slot", -1))
		result["winner_role"] = str(winner.get_meta(&"eval_role", ""))
		result["winner_id"] = str(winner.get_meta(&"eval_id", ""))
	match_resolved.emit(result)
	if _should_auto_restart_round() and timer != null:
		timer.start()

func _get_remaining_players() -> Array[Player]:
	var remaining: Array[Player] = []
	for player in player_roster:
		if not is_instance_valid(player):
			continue
		if eliminated_player_ids.has(player.get_instance_id()):
			continue
		remaining.append(player)
	return remaining

func _serialize_players(players: Array[Player]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for player in players:
		if player == null:
			continue
		out.append({
			"name": str(player.get_meta(&"match_display_name", player.name)),
			"slot": int(player.get_meta(&"match_slot", -1)),
			"role": str(player.get_meta(&"eval_role", "")),
			"eval_id": str(player.get_meta(&"eval_id", "")),
		})
	return out

func _should_auto_restart_round() -> bool:
	var match_settings = _get_match_settings()
	if match_settings != null and match_settings.has_method("should_auto_restart_round"):
		return bool(match_settings.call("should_auto_restart_round"))
	return true

func _exit_tree() -> void:
	if get_tree():
		get_tree().paused = false
	Engine.time_scale = 1.0

# No-ops so player/arrow scripts can call these on their world parent without crashing.
func trigger_screenshake(_intensity: float = 8.0, _duration: float = 0.12) -> void:
	pass

func trigger_hit_stop(_duration: float = 0.05, _slow_scale: float = 0.08) -> void:
	pass
