extends SceneTree
# tests/ai_battery_runner.gd
# Phase 4 — Ranked Duel And Arena Ladder
#
# Runs both Tier 3 (duel slices) and Tier 4 (authored arena ladder) in one pass,
# then emits a combined batch summary and diff.
#
# Run headless:
#   flatpak run org.godotengine.Godot --headless \
#     --path /home/matthiase/Github/Towerfall \
#     --script res://tests/ai_battery_runner.gd \
#     -- --battery=quick --candidate_id=candidate --opponent_id=baseline \
#        --output_dir=/tmp/towerfall_ai_reports
#
# --battery=quick  →  Tier 3: 2 slices × 4 seeds × 2 swaps × 1 opponent
#                      Tier 4: 3 levels × 4 seeds × 2 swaps × 1 opponent
# --battery=full   →  Tier 3: 3 slices × 6 seeds × 2 swaps × 3 opponents
#                      Tier 4: 3 levels × 6 seeds × 2 swaps × 3 opponents

const MATCH_SETTINGS_PATH := "/root/MatchSettings"
const MATCH_SETTINGS_SCRIPT = preload("res://scripts/systems/match_settings.gd")
const AI_MATCH_TELEMETRY_SCRIPT = preload("res://scripts/systems/ai_match_telemetry.gd")

# ── Tier 3 duel slices ──────────────────────────────────────────────────────
const DUEL_SCENE_MAP: Dictionary = {
	"open":     "res://scenes/levels/duel_open.tscn",
	"platform": "res://scenes/levels/duel_platform.tscn",
	"wrap":     "res://scenes/levels/duel_wrap.tscn",
}
const QUICK_DUEL_SLICES: Array[String] = ["open", "platform"]
const FULL_DUEL_SLICES: Array[String]  = ["open", "platform", "wrap"]

# ── Tier 4 authored levels ───────────────────────────────────────────────────
const TIER4_LEVELS: Array[String] = [
	"res://scenes/levels/level_1.tscn",
	"res://scenes/levels/level_2.tscn",
	"res://scenes/levels/level_3.tscn",
]

# ── Seed packs ───────────────────────────────────────────────────────────────
const QUICK_SEEDS: Array[int] = [101, 211, 307, 401]
const FULL_SEEDS: Array[int]  = [101, 211, 307, 401, 503, 601]

# ── Timeouts ─────────────────────────────────────────────────────────────────
const TIMEOUT_TIER3: float = 45.0
const TIMEOUT_TIER4: float = 60.0

const DEFAULT_OUTPUT_DIR: String = "/tmp/towerfall_ai_reports"

var _fatal_error: bool = false

# ---------------------------------------------------------------------------

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var options: Dictionary = _parse_args(OS.get_cmdline_user_args())
	var battery: String = str(options.get("battery", "quick"))
	var output_dir: String = str(options.get("output_dir", DEFAULT_OUTPUT_DIR))
	var batch_id: String = str(options.get("batch_id", "battery_%s_%d" % [battery, int(Time.get_unix_time_from_system())]))
	var candidate_id: String = str(options.get("candidate_id", "candidate"))
	var candidate_name: String = str(options.get("candidate_name", "Candidate"))
	var candidate_difficulty: float = float(options.get("candidate_difficulty", 0.6))

	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		push_error("Unable to create output directory: %s" % output_dir)
		quit(1)
		return

	# ── Resolve opponent pool ─────────────────────────────────────────────
	# quick: single FrozenBaseline opponent
	# full:  three opponents from the frozen pool
	var opponents: Array[Dictionary]
	if battery == "full":
		opponents = [
			{"id": str(options.get("opponent_id", "baseline")), "name": str(options.get("opponent_name", "Opponent")), "difficulty": float(options.get("opponent_difficulty", 0.6))},
			{"id": candidate_id, "name": candidate_name, "difficulty": candidate_difficulty},  # MirrorCandidate
			{"id": str(options.get("pressure_id", str(options.get("opponent_id", "baseline")))), "name": "PressureOpponent", "difficulty": float(options.get("pressure_difficulty", 0.85))},
		]
	else:
		opponents = [
			{"id": str(options.get("opponent_id", "baseline")), "name": str(options.get("opponent_name", "Opponent")), "difficulty": float(options.get("opponent_difficulty", 0.6))},
		]

	var seeds: Array[int] = FULL_SEEDS if battery == "full" else QUICK_SEEDS
	var spawn_swaps: int = 2
	var duel_slices: Array[String] = FULL_DUEL_SLICES if battery == "full" else QUICK_DUEL_SLICES

	var all_run_reports: Array[Dictionary] = []

	# ── Tier 3: Duel Slices ───────────────────────────────────────────────
	for opponent in opponents:
		for slice_name in duel_slices:
			var level_path: String = DUEL_SCENE_MAP.get(slice_name, "")
			if level_path.is_empty():
				push_error("Unknown duel slice: %s" % slice_name)
				quit(1)
				return
			for seed_value in seeds:
				for swap_index in range(spawn_swaps):
					var run_config := _build_run_config(
						"duel_%s" % slice_name,
						level_path,
						seed_value,
						swap_index,
						TIMEOUT_TIER3,
						"tier3",
						battery,
						candidate_id,
						candidate_name,
						candidate_difficulty,
						opponent
					)
					var report: Dictionary = await _run_single_match(run_config)
					if _fatal_error:
						quit(1)
						return
					all_run_reports.append(report)
					_write_json("%s/%s.json" % [output_dir, str(run_config.get("run_id"))], report)
					print("run report [tier3]: %s" % run_config.get("run_id"))

	# ── Tier 4: Authored Arena Ladder ─────────────────────────────────────
	for opponent in opponents:
		for level_path in TIER4_LEVELS:
			var arena_name: String = level_path.get_file().get_basename()
			for seed_value in seeds:
				for swap_index in range(spawn_swaps):
					var run_config := _build_run_config(
						arena_name,
						level_path,
						seed_value,
						swap_index,
						TIMEOUT_TIER4,
						"tier4",
						battery,
						candidate_id,
						candidate_name,
						candidate_difficulty,
						opponent
					)
					var report: Dictionary = await _run_single_match(run_config)
					if _fatal_error:
						quit(1)
						return
					all_run_reports.append(report)
					_write_json("%s/%s.json" % [output_dir, str(run_config.get("run_id"))], report)
					print("run report [tier4]: %s" % run_config.get("run_id"))

	if all_run_reports.is_empty():
		push_error("No runs executed.")
		quit(1)
		return

	# ── Write combined batch summary and diff ─────────────────────────────
	var primary_opponent: Dictionary = opponents[0]
	var batch_meta: Dictionary = {
		"candidate_id": candidate_id,
		"baseline_id": primary_opponent.get("id", "baseline"),
		"battery_profile": battery,
		"seed_pack": seeds,
	}

	var batch_summary: Dictionary = AIMatchTelemetry.build_batch_summary(all_run_reports, batch_meta)
	var summary_path: String = "%s/%s_batch_summary.json" % [output_dir, batch_id]
	_write_json(summary_path, batch_summary)
	print("batch summary: %s" % summary_path)

	var batch_diff: Dictionary = AIMatchTelemetry.build_batch_diff(all_run_reports, batch_meta)
	var diff_path: String = "%s/%s_batch_diff.json" % [output_dir, batch_id]
	_write_json(diff_path, batch_diff)
	print("batch diff: %s" % diff_path)

	await _settle_frames(3)
	quit(0)

# ---------------------------------------------------------------------------

func _build_run_config(
	arena_name: String,
	level_path: String,
	seed_value: int,
	swap_index: int,
	timeout_seconds: float,
	tier: String,
	battery_profile: String,
	candidate_id: String,
	candidate_name_val: String,
	candidate_difficulty: float,
	opponent: Dictionary
) -> Dictionary:
	var opponent_id: String = str(opponent.get("id", "baseline"))
	var opponent_name: String = str(opponent.get("name", "Opponent"))
	var opponent_difficulty: float = float(opponent.get("difficulty", 0.6))
	return {
		"run_id": "%s_%s_seed%d_swap%d" % [tier, arena_name, seed_value, swap_index],
		"battery_profile": battery_profile,
		"tier": tier,
		"arena_name": arena_name,
		"level_path": level_path,
		"seed": seed_value,
		"spawn_swap_index": swap_index,
		"timeout_seconds": timeout_seconds,
		"candidate_id": candidate_id,
		"candidate_name": candidate_name_val,
		"candidate_difficulty": candidate_difficulty,
		"opponent_id": opponent_id,
		"opponent_name": opponent_name,
		"opponent_difficulty": opponent_difficulty,
	}

func _run_single_match(run_config: Dictionary) -> Dictionary:
	var match_settings: Node = root.get_node_or_null(MATCH_SETTINGS_PATH)
	if match_settings == null:
		push_error("Missing MatchSettings autoload.")
		_fatal_error = true
		return {}

	var level_path: String = str(run_config.get("level_path", ""))
	var packed_scene: PackedScene = load(level_path) as PackedScene
	if packed_scene == null:
		push_error("Unable to load scene: %s" % level_path)
		_fatal_error = true
		return {}

	seed(int(run_config.get("seed", 0)))
	match_settings.call("set_explicit_roster", _build_explicit_roster(run_config))
	match_settings.call("set_evaluation_options", {
		"seed": int(run_config.get("seed", -1)),
		"suppress_round_restart": true,
	})

	var telemetry: AIMatchTelemetry = AI_MATCH_TELEMETRY_SCRIPT.new() as AIMatchTelemetry
	telemetry.name = "AIMatchTelemetry"
	telemetry.configure(run_config)
	root.add_child(telemetry)

	var scene: Node = packed_scene.instantiate()
	telemetry.bind_world(scene)
	root.add_child(scene)
	current_scene = scene

	var timeout: float = float(run_config.get("timeout_seconds", TIMEOUT_TIER4))
	while not telemetry.is_finished() and telemetry.get_elapsed_seconds() < timeout:
		await physics_frame
		await process_frame

	if not telemetry.is_finished():
		telemetry.mark_timeout()

	var report: Dictionary = telemetry.get_run_report()
	current_scene = null
	_free_immediately(telemetry)
	_free_immediately(scene)
	await _settle_frames(3)
	match_settings.call("clear_explicit_roster")
	match_settings.call("clear_evaluation_options")
	await _settle_frames(3)
	return report

func _build_explicit_roster(run_config: Dictionary) -> Array[Dictionary]:
	var swap_index: int = int(run_config.get("spawn_swap_index", 0))
	var candidate_first: bool = swap_index % 2 == 0
	var roster: Array[Dictionary] = []
	roster.append(_build_roster_entry(
		0,
		"candidate" if candidate_first else "opponent",
		str(run_config.get("candidate_name", "Candidate")) if candidate_first else str(run_config.get("opponent_name", "Opponent")),
		str(run_config.get("candidate_id", "candidate")) if candidate_first else str(run_config.get("opponent_id", "opponent")),
		float(run_config.get("candidate_difficulty", 0.6)) if candidate_first else float(run_config.get("opponent_difficulty", 0.6)),
		MATCH_SETTINGS_SCRIPT.PLAYER_COLORS[0]
	))
	roster.append(_build_roster_entry(
		1,
		"opponent" if candidate_first else "candidate",
		str(run_config.get("opponent_name", "Opponent")) if candidate_first else str(run_config.get("candidate_name", "Candidate")),
		str(run_config.get("opponent_id", "opponent")) if candidate_first else str(run_config.get("candidate_id", "candidate")),
		float(run_config.get("opponent_difficulty", 0.6)) if candidate_first else float(run_config.get("candidate_difficulty", 0.6)),
		MATCH_SETTINGS_SCRIPT.PLAYER_COLORS[1]
	))
	return roster

func _build_roster_entry(slot: int, eval_role: String, display_name: String, eval_id: String, ai_difficulty: float, player_color: Color) -> Dictionary:
	var input_config: Dictionary = MATCH_SETTINGS_SCRIPT.PLAYER_INPUTS[min(slot, MATCH_SETTINGS_SCRIPT.PLAYER_INPUTS.size() - 1)]
	return {
		"slot": slot,
		"display_name": display_name,
		"player_color": player_color,
		"is_ai": true,
		"ai_difficulty": ai_difficulty,
		"eval_role": eval_role,
		"eval_id": eval_id,
		"left_button": input_config.get("left_button", &""),
		"right_button": input_config.get("right_button", &""),
		"up_button": input_config.get("up_button", &""),
		"down_button": input_config.get("down_button", &""),
		"use_button": input_config.get("use_button", &""),
		"jump_button": input_config.get("jump_button", &""),
		"dash_button": input_config.get("dash_button", &""),
	}

func _write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Unable to write file: %s" % path)
		_fatal_error = true
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	file.close()

func _parse_args(args: Array[String]) -> Dictionary:
	var parsed: Dictionary = {}
	for arg in args:
		if not arg.begins_with("--"):
			continue
		var trimmed: String = arg.substr(2)
		var separator: int = trimmed.find("=")
		if separator == -1:
			parsed[trimmed] = true
			continue
		var key: String = trimmed.substr(0, separator)
		var value: String = trimmed.substr(separator + 1)
		parsed[key] = value
	return parsed

func _settle_frames(frame_count: int) -> void:
	for _index in range(frame_count):
		await physics_frame
		await process_frame

func _free_immediately(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.set_process(false)
	if node is CanvasItem:
		(node as CanvasItem).visible = false
	var parent := node.get_parent()
	if parent != null:
		parent.remove_child(node)
	node.free()
