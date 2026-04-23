class_name MatchSettingsState
extends Node


const MAX_PLAYERS: int = 4
const DEFAULT_HUMAN_PLAYERS: int = 2
const DEFAULT_AI_PLAYERS: int = 0
const DEFAULT_AI_DIFFICULTY: float = 0.6
const PLAYER_COLORS: Array[Color] = [
	Color("#4df56b"),
	Color("#ff5c5c"),
	Color("#5cb9ff"),
	Color("#ffd85c"),
]
const PLAYER_INPUTS: Array[Dictionary] = [
	{
		"left_button": &"p1_left",
		"right_button": &"p1_right",
		"up_button": &"p1_up",
		"down_button": &"p1_down",
		"use_button": &"p1_use",
		"jump_button": &"p1_jump",
		"dash_button": &"p1_dash",
	},
	{
		"left_button": &"p2_left",
		"right_button": &"p2_right",
		"up_button": &"p2_up",
		"down_button": &"p2_down",
		"use_button": &"p2_use",
		"jump_button": &"p2_jump",
		"dash_button": &"p2_dash",
	},
	{
		"left_button": &"p3_left",
		"right_button": &"p3_right",
		"up_button": &"p3_up",
		"down_button": &"p3_down",
		"use_button": &"p3_use",
		"jump_button": &"p3_jump",
		"dash_button": &"p3_dash",
	},
	{
		"left_button": &"p4_left",
		"right_button": &"p4_right",
		"up_button": &"p4_up",
		"down_button": &"p4_down",
		"use_button": &"p4_use",
		"jump_button": &"p4_jump",
		"dash_button": &"p4_dash",
	},
]

var human_player_count: int = DEFAULT_HUMAN_PLAYERS
var ai_player_count: int = DEFAULT_AI_PLAYERS
var explicit_roster_override: Array[Dictionary] = []
var evaluation_options: Dictionary = {}
var ai_debug_open: bool = false

func configure(players: int, ai_players: int) -> void:
	human_player_count = clampi(players, 1, MAX_PLAYERS)
	ai_player_count = clampi(ai_players, 0, MAX_PLAYERS - human_player_count)
	clear_explicit_roster()

func configure_ai_only(ai_players: int) -> void:
	human_player_count = 0
	ai_player_count = clampi(ai_players, 1, MAX_PLAYERS)
	clear_explicit_roster()

func set_explicit_roster(roster: Array[Dictionary]) -> void:
	explicit_roster_override.clear()
	for entry in roster:
		explicit_roster_override.append(entry.duplicate(true))

func clear_explicit_roster() -> void:
	explicit_roster_override.clear()

func set_evaluation_options(options: Dictionary) -> void:
	evaluation_options = options.duplicate(true)

func get_evaluation_options() -> Dictionary:
	return evaluation_options.duplicate(true)

func clear_evaluation_options() -> void:
	evaluation_options.clear()

func should_auto_restart_round() -> bool:
	return not bool(evaluation_options.get("suppress_round_restart", false))

func get_evaluation_seed() -> int:
	return int(evaluation_options.get("seed", -1))

func build_rng(tag: String, salt: int = 0) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	var evaluation_seed := get_evaluation_seed()
	if evaluation_seed >= 0:
		rng.seed = hash("%d:%s:%d" % [evaluation_seed, tag, salt])
	else:
		rng.randomize()
	return rng

func get_total_player_count() -> int:
	return human_player_count + ai_player_count

func get_max_ai_count_for(players: int = human_player_count) -> int:
	return maxi(MAX_PLAYERS - clampi(players, 1, MAX_PLAYERS), 0)

func build_match_roster() -> Array[Dictionary]:
	if not explicit_roster_override.is_empty():
		return _duplicate_roster(explicit_roster_override)

	var roster: Array[Dictionary] = []
	var total_players := get_total_player_count()
	var cpu_index := 1

	for slot in range(total_players):
		var slot_inputs: Dictionary = PLAYER_INPUTS[min(slot, PLAYER_INPUTS.size() - 1)]
		var is_ai := slot >= human_player_count
		var entry := {
			"slot": slot,
			"display_name": "CPU %d" % cpu_index if is_ai else "Player %d" % (slot + 1),
			"player_color": PLAYER_COLORS[min(slot, PLAYER_COLORS.size() - 1)],
			"is_ai": is_ai,
			"ai_difficulty": DEFAULT_AI_DIFFICULTY,
			"left_button": slot_inputs.get("left_button", &""),
			"right_button": slot_inputs.get("right_button", &""),
			"up_button": slot_inputs.get("up_button", &""),
			"down_button": slot_inputs.get("down_button", &""),
			"use_button": slot_inputs.get("use_button", &""),
			"jump_button": slot_inputs.get("jump_button", &""),
			"dash_button": slot_inputs.get("dash_button", &""),
		}
		roster.append(entry)
		if is_ai:
			cpu_index += 1

	return roster

func _duplicate_roster(source_roster: Array[Dictionary]) -> Array[Dictionary]:
	var roster: Array[Dictionary] = []
	for entry in source_roster:
		roster.append(entry.duplicate(true))
	return roster

func get_summary_text() -> String:
	var total_players := get_total_player_count()
	var player_label := "player" if human_player_count == 1 else "players"
	var summary := "%d human %s" % [human_player_count, player_label]
	if ai_player_count > 0:
		var ai_label := "AI" if ai_player_count == 1 else "AIs"
		summary += "  |  %d %s" % [ai_player_count, ai_label]
	summary += "  |  %d total" % total_players
	return summary
