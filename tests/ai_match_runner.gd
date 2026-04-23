extends SceneTree

const MATCH_SETTINGS_PATH := "/root/MatchSettings"
const MATCH_SETTINGS_SCRIPT = preload("res://scripts/systems/match_settings.gd")
const AI_MATCH_TELEMETRY_SCRIPT = preload("res://scripts/systems/ai_match_telemetry.gd")

const DEFAULT_LEVEL := "res://scenes/levels/level_1.tscn"
const DEFAULT_OUTPUT_DIR := "/tmp/towerfall_ai_reports"
const DEFAULT_TIMEOUT_SECONDS: float = 60.0

var _fatal_error: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var options: Dictionary = _parse_args(OS.get_cmdline_user_args())
	var output_dir: String = str(options.get("output_dir", DEFAULT_OUTPUT_DIR))
	var levels: Array[String] = _parse_csv_strings(str(options.get("levels", options.get("level", DEFAULT_LEVEL))))
	var seeds: Array[int] = _parse_csv_ints(str(options.get("seeds", options.get("seed", "101"))))
	var spawn_swaps: int = maxi(int(options.get("spawn_swaps", 2)), 1)
	var timeout_seconds: float = maxf(float(options.get("timeout", DEFAULT_TIMEOUT_SECONDS)), 5.0)
	var batch_id: String = str(options.get("batch_id", "ai_batch_%d" % int(Time.get_unix_time_from_system())))
	var candidate_id: String = str(options.get("candidate_id", "candidate"))
	var opponent_id: String = str(options.get("opponent_id", "baseline"))
	var battery_profile: String = str(options.get("battery_profile", "phase2"))
	var tier: String = str(options.get("tier", "phase2"))

	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		push_error("Unable to create output directory: %s" % output_dir)
		quit(1)
		return

	var run_reports: Array[Dictionary] = []
	for level_path in levels:
		for seed_value in seeds:
			for swap_index in range(spawn_swaps):
				var run_config := _build_run_config(
					options,
					level_path,
					seed_value,
					swap_index,
					timeout_seconds,
					candidate_id,
					opponent_id,
					battery_profile,
					tier
				)
				var report: Dictionary = await _run_single_match(run_config)
				if _fatal_error:
					quit(1)
					return
				run_reports.append(report)
				var run_report_path: String = "%s/%s.json" % [output_dir, str(run_config.get("run_id", "run"))]
				_write_json(run_report_path, report)
				print("run report: %s" % run_report_path)

	if run_reports.is_empty():
		push_error("No runs were executed.")
		quit(1)
		return

	var batch_summary: Dictionary = AIMatchTelemetry.build_batch_summary(run_reports, {
		"candidate_id": candidate_id,
		"baseline_id": opponent_id,
		"battery_profile": battery_profile,
		"seed_pack": seeds,
	})
	var batch_summary_path: String = "%s/%s_batch_summary.json" % [output_dir, batch_id]
	_write_json(batch_summary_path, batch_summary)
	print("batch summary: %s" % batch_summary_path)

	var batch_diff: Dictionary = AIMatchTelemetry.build_batch_diff(run_reports, {
		"candidate_id": candidate_id,
		"baseline_id": opponent_id,
		"battery_profile": battery_profile,
		"seed_pack": seeds,
	})
	var batch_diff_path: String = "%s/%s_batch_diff.json" % [output_dir, batch_id]
	_write_json(batch_diff_path, batch_diff)
	print("batch diff: %s" % batch_diff_path)
	await _settle_frames(3)
	quit(0)

func _run_single_match(run_config: Dictionary) -> Dictionary:
	var match_settings: Node = root.get_node_or_null(MATCH_SETTINGS_PATH)
	if match_settings == null:
		push_error("Missing MatchSettings autoload.")
		_fatal_error = true
		return {}

	var level_path: String = str(run_config.get("level_path", DEFAULT_LEVEL))
	var packed_scene: PackedScene = load(level_path) as PackedScene
	if packed_scene == null:
		push_error("Unable to load level scene: %s" % level_path)
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

	while not telemetry.is_finished() and telemetry.get_elapsed_seconds() < float(run_config.get("timeout_seconds", DEFAULT_TIMEOUT_SECONDS)):
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

func _build_run_config(
	options: Dictionary,
	level_path: String,
	seed_value: int,
	swap_index: int,
	timeout_seconds: float,
	candidate_id: String,
	opponent_id: String,
	battery_profile: String,
	tier: String
) -> Dictionary:
	var arena_name: String = str(options.get("arena_name", level_path.get_file().get_basename()))
	return {
		"run_id": "%s_seed%d_swap%d" % [arena_name, seed_value, swap_index],
		"battery_profile": battery_profile,
		"tier": tier,
		"arena_name": arena_name,
		"level_path": level_path,
		"seed": seed_value,
		"spawn_swap_index": swap_index,
		"timeout_seconds": timeout_seconds,
		"candidate_id": candidate_id,
		"opponent_id": opponent_id,
		"candidate_name": str(options.get("candidate_name", "Candidate")),
		"opponent_name": str(options.get("opponent_name", "Opponent")),
		"candidate_difficulty": float(options.get("candidate_difficulty", 0.6)),
		"opponent_difficulty": float(options.get("opponent_difficulty", 0.6)),
	}

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

func _parse_csv_strings(value: String) -> Array[String]:
	var items: Array[String] = []
	for part in value.split(",", false):
		var trimmed := part.strip_edges()
		if not trimmed.is_empty():
			items.append(trimmed)
	if items.is_empty():
		items.append(DEFAULT_LEVEL)
	return items

func _parse_csv_ints(value: String) -> Array[int]:
	var items: Array[int] = []
	for part in value.split(",", false):
		var trimmed := part.strip_edges()
		if trimmed.is_empty():
			continue
		items.append(int(trimmed))
	if items.is_empty():
		items.append(101)
	return items

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
