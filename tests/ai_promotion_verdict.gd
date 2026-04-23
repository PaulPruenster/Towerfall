extends SceneTree
# tests/ai_promotion_verdict.gd
# Appends a human-reviewed promotion verdict to an existing batch diff JSON file.
#
# Run headless:
#   flatpak run org.godotengine.Godot --headless \
#     --path /home/matthiase/Github/Towerfall \
#     --script res://tests/ai_promotion_verdict.gd \
#     -- --diff=/home/user/reports/batch_diff.json \
#        --verdict=approved \
#        --candidate_id=my_branch \
#        --notes="Shot discipline improved. Wrap behavior looks intentional." \
#        --output=/home/user/reports/batch_diff_with_verdict.json
#
# Supported --verdict values:
#   approved      All guardrails pass; candidate is promoted to baseline.
#   rejected      One or more guardrails failed; candidate is not promoted.
#   conditional   Guardrails pass but behaviour concerns noted; re-review required.
#
# If --output is omitted the verdict is written back into the --diff file.
# The promotion_record is stored under the "promotion_record" key in the root
# of the diff object and uses the same vocabulary as the batch summary.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var options: Dictionary = _parse_args(OS.get_cmdline_user_args())

	var diff_path: String = str(options.get("diff", ""))
	if diff_path.is_empty():
		push_error("--diff is required (path to a batch diff JSON file)")
		quit(1)
		return

	var verdict: String = str(options.get("verdict", ""))
	if verdict not in ["approved", "rejected", "conditional"]:
		push_error("--verdict must be approved, rejected, or conditional (got: '%s')" % verdict)
		quit(1)
		return

	var candidate_id: String = str(options.get("candidate_id", ""))
	var notes: String = str(options.get("notes", ""))
	var output_path: String = str(options.get("output", diff_path))

	# ── Read batch diff ──────────────────────────────────────────────────
	var in_file := FileAccess.open(diff_path, FileAccess.READ)
	if in_file == null:
		push_error("Cannot open diff file: %s" % diff_path)
		quit(1)
		return

	var raw: String = in_file.get_as_text()
	in_file.close()

	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary:
		push_error("Diff file is not a valid JSON object: %s" % diff_path)
		quit(1)
		return

	var batch_diff: Dictionary = parsed as Dictionary

	# ── Build promotion record ───────────────────────────────────────────
	var resolved_candidate_id: String = candidate_id if not candidate_id.is_empty() \
		else str(batch_diff.get("candidate_id", ""))

	var promotion_record: Dictionary = {
		"verdict": verdict,
		"candidate_id": resolved_candidate_id,
		"baseline_id": str(batch_diff.get("baseline_id", "")),
		"reviewer_date": Time.get_datetime_string_from_system(false, true),
		"notes": notes,
		"batch_score_delta": float(batch_diff.get("overall_batch_score_delta", 0.0)),
		"guardrails_evaluated": true,
		"checklist": {
			"tier1_pass": null,
			"tier2_pass": null,
			"batch_score_above_threshold": null,
			"timeout_rate_acceptable": null,
			"self_hazard_rate_acceptable": null,
			"shot_discipline_acceptable": null,
			"stuck_time_acceptable": null,
			"mechanic_success_acceptable": null,
			"spawn_bias_acceptable": null,
			"manual_feel_pass": null,
		},
	}

	# Populate read-only metrics from the diff where available so the record
	# is self-contained when opened for archiving.
	var cand_minus_opp: Variant = batch_diff.get("candidate_minus_opponent", {})
	if cand_minus_opp is Dictionary:
		promotion_record["candidate_minus_opponent_snapshot"] = (cand_minus_opp as Dictionary).duplicate(true)

	batch_diff["promotion_record"] = promotion_record

	# ── Write output ─────────────────────────────────────────────────────
	var out_file := FileAccess.open(output_path, FileAccess.WRITE)
	if out_file == null:
		push_error("Cannot write output file: %s" % output_path)
		quit(1)
		return

	out_file.store_string(JSON.stringify(batch_diff, "\t"))
	out_file.flush()
	out_file.close()

	print("promotion record written: %s" % output_path)
	print("  verdict:      %s" % verdict)
	print("  candidate_id: %s" % resolved_candidate_id)
	print("  batch_score_delta: %.3f" % float(batch_diff.get("overall_batch_score_delta", 0.0)))
	if not notes.is_empty():
		print("  notes: %s" % notes)

	await process_frame
	quit(0)

func _parse_args(args: Array[String]) -> Dictionary:
	var parsed: Dictionary = {}
	for arg in args:
		if not arg.begins_with("--"):
			continue
		var trimmed: String = arg.substr(2)
		var sep: int = trimmed.find("=")
		if sep == -1:
			parsed[trimmed] = true
			continue
		parsed[trimmed.substr(0, sep)] = trimmed.substr(sep + 1)
	return parsed
