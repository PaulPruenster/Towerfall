class_name AIDebugOverlay
extends CanvasLayer

const CARD_SCENE_PATH := "res://scripts/ui/ai_debug_overlay.gd"

# Colors used in BBCode labels
const C_HEADING  := "#f8f7eb"
const C_LABEL    := "#bdc9de"
const C_VALUE    := "#f0f7ff"
const C_GOOD     := "#58c7e3"
const C_WARN     := "#f0a040"
const C_BAD      := "#e05050"
const C_DIM      := "#7090b8"
const C_HIST     := "#9ab0d0"
const STUCK_ESCAPE_SHOW := 1.0

# State color map
const STATE_COLORS := {
	"idle":     "#9ab0d0",
	"approach": "#58c7e3",
	"aim":      "#f0a040",
	"shoot":    "#e05050",
	"dodge":    "#d0a0e8",
	"retreat":  "#e07840",
}
const GOAL_COLORS := {
	"fight":    "#e05050",
	"chest":    "#f0d050",
	"switch":   "#80e080",
	"recover":  "#e07840",
}

@onready var cards_vbox: VBoxContainer = $DebugWindow/ContentPanel/OuterMargin/RootVBox/ScrollContainer/CardsVBox
@onready var no_ai_label: Label = $DebugWindow/ContentPanel/OuterMargin/RootVBox/ScrollContainer/CardsVBox/NoAILabel
@onready var debug_window: Window = $DebugWindow

const MIN_SIDEBAR_WIDTH := 260.0
const MAX_SIDEBAR_WIDTH := 860.0

var tracked_players: Array[Player] = []
var overlay_enabled: bool = false
var _player_cards: Dictionary = {}
var _world_draw: Node2D = null

# Player colors for route visualization (matches typical player tint order)
const PLAYER_ROUTE_COLORS: Array[Color] = [
	Color(0.35, 0.85, 1.0, 1.0),   # P1 cyan
	Color(1.0,  0.45, 0.45, 1.0),   # P2 red
	Color(0.45, 1.0,  0.45, 1.0),   # P3 green
	Color(1.0,  0.9,  0.2,  1.0),   # P4 yellow
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_world_draw = Node2D.new()
	_world_draw.name = &"WorldDraw"
	_world_draw.z_index = 10
	_world_draw.draw.connect(_on_world_draw)
	_world_draw.set_script(null)
	add_child(_world_draw)

func bind_players(players: Array[Player]) -> void:
	tracked_players = players.duplicate()
	_rebuild_cards()

func toggle_overlay() -> bool:
	set_overlay_enabled(not overlay_enabled)
	var match_settings = get_node_or_null("/root/MatchSettings")
	if match_settings != null:
		match_settings.ai_debug_open = overlay_enabled
	return overlay_enabled

func set_overlay_enabled(is_enabled: bool) -> void:
	overlay_enabled = is_enabled
	visible = overlay_enabled  # drives world-draw Node2D
	debug_window.visible = overlay_enabled
	if overlay_enabled:
		_rebuild_cards()

func _on_debug_window_close_requested() -> void:
	set_overlay_enabled(false)

func _process(_delta: float) -> void:
	if not overlay_enabled:
		return
	_refresh_all_cards()
	if is_instance_valid(_world_draw):
		_world_draw.queue_redraw()

func _on_world_draw() -> void:
	if not overlay_enabled or not is_instance_valid(_world_draw):
		return
	# All route points in the scene
	var scene := get_tree().current_scene if get_tree() != null else null
	if scene == null:
		return
	var xform := get_viewport().get_canvas_transform()
	var route_points: Array[Node2D] = []
	var route_point_script = preload("res://scripts/gameplay/ai_route_point.gd")
	for node in scene.find_children("*", "", true, false):
		var n2d := node as Node2D
		if n2d != null and node.get_script() == route_point_script:
			route_points.append(n2d)

	# Collect per-AI active sets
	var active_path_points: Dictionary = {}   # Node2D -> Color
	var active_step_source: Dictionary = {}   # Node2D -> Color
	var active_step_target: Dictionary = {}   # Node2D -> Color
	var active_focus: Array[Dictionary] = []  # [{pos, color}]
	var path_lines: Array[Dictionary] = []    # [{points: Array[Vector2], color}]
	var goal_lines: Array[Dictionary] = []    # [{from, to, color}]

	for idx in tracked_players.size():
		var pl: Player = tracked_players[idx]
		if not is_instance_valid(pl):
			continue
		var ctrl := pl.get_node_or_null(^"AIController") as AIController
		if ctrl == null or not ctrl.enabled:
			continue
		var col: Color = PLAYER_ROUTE_COLORS[idx % PLAYER_ROUTE_COLORS.size()]

		# Draw path as line through route point positions, world -> screen
		if ctrl.current_route_path.size() >= 2:
			var pts: Array[Vector2] = []
			pts.append(xform * pl.global_position)
			for rp: Node2D in ctrl.current_route_path:
				if is_instance_valid(rp):
					pts.append(xform * rp.global_position)
			var s_node := ctrl.current_route_step.get("source_point") as Node2D
			var t_node := ctrl.current_route_step.get("target_point") as Node2D
			var focus_pos: Vector2 = ctrl.current_route_step.get("focus_position", Vector2.ZERO)
			if focus_pos != Vector2.ZERO:
				pts.append(xform * focus_pos)
			path_lines.append({"points": pts, "color": col})
			if s_node != null and is_instance_valid(s_node):
				active_step_source[s_node] = col
			if t_node != null and is_instance_valid(t_node):
				active_step_target[t_node] = col
			for rp: Node2D in ctrl.current_route_path:
				if is_instance_valid(rp):
					active_path_points[rp] = col

		# Draw goal line (player -> goal node)
		if ctrl.goal_node != null and is_instance_valid(ctrl.goal_node):
			goal_lines.append({
				"from": xform * pl.global_position,
				"to":   xform * ctrl.goal_node.global_position,
				"color": col,
			})

	# Draw target lines (AI player -> targeted player)
	for idx in tracked_players.size():
		var pl: Player = tracked_players[idx]
		if not is_instance_valid(pl):
			continue
		var ctrl := pl.get_node_or_null(^"AIController") as AIController
		if ctrl == null or not ctrl.enabled or ctrl.target == null or not is_instance_valid(ctrl.target):
			continue
		var col: Color = PLAYER_ROUTE_COLORS[idx % PLAYER_ROUTE_COLORS.size()]
		var from_s := xform * pl.global_position
		var to_s   := xform * ctrl.target.global_position
		# Solid bright line
		_world_draw.draw_line(from_s, to_s, col, 2.0)
		# Arrowhead at target end
		var dir2 := (to_s - from_s).normalized()
		var perp2 := Vector2(-dir2.y, dir2.x)
		_world_draw.draw_line(to_s, to_s - dir2 * 10.0 + perp2 * 6.0, col, 2.0)
		_world_draw.draw_line(to_s, to_s - dir2 * 10.0 - perp2 * 6.0, col, 2.0)
		# Small circle on the targeted player
		_world_draw.draw_circle(to_s, 7.0, Color(col.r, col.g, col.b, 0.25))
		_world_draw.draw_arc(to_s, 7.0, 0.0, TAU, 16, col, 1.5)

	# Draw path lines
	for line_data in path_lines:
		var pts: Array[Vector2] = line_data["points"]
		var line_col: Color = line_data["color"]
		for i in range(pts.size() - 1):
			_world_draw.draw_line(pts[i], pts[i + 1], line_col.darkened(0.2), 2.0)

	# Draw goal dash lines
	for gl in goal_lines:
		_draw_dashed_line(_world_draw, gl["from"], gl["to"], (gl["color"] as Color).darkened(0.35), 1.5, 10.0)

	# Draw all route points
	for rp in route_points:
		if not is_instance_valid(rp):
			continue
		var sp := xform * rp.global_position
		var is_active_path := active_path_points.has(rp)
		var is_step_src := active_step_source.has(rp)
		var is_step_tgt := active_step_target.has(rp)

		var dot_color := Color(0.55, 0.65, 0.75, 0.55)  # default dim
		var radius := 5.0
		if is_step_tgt:
			dot_color = active_step_target[rp]
			dot_color.a = 1.0
			radius = 9.0
		elif is_step_src:
			dot_color = active_step_source[rp]
			dot_color.a = 0.85
			radius = 7.0
		elif is_active_path:
			dot_color = active_path_points[rp]
			dot_color.a = 0.7
			radius = 6.0

		_world_draw.draw_circle(sp, radius + 1.5, Color(0, 0, 0, 0.55))
		_world_draw.draw_circle(sp, radius, dot_color)
		# Draw links as thin arrows from each point
		for link in rp.get_route_links():
			var tgt := link.get_target_point() as Node2D
			if tgt == null or not is_instance_valid(tgt):
				continue
			var tp := xform * tgt.global_position
			var link_col := Color(0.45, 0.55, 0.65, 0.3)
			var traversal := int(link.traversal_type)
			if traversal == 1:   # JUMP
				link_col = Color(0.9, 0.7, 0.2, 0.45)
			elif traversal == 2: # DROP
				link_col = Color(0.5, 0.8, 1.0, 0.35)
			elif traversal == 3: # WALL_JUMP
				link_col = Color(0.8, 0.4, 0.9, 0.45)
			elif traversal == 4: # PAD
				link_col = Color(0.3, 1.0, 0.6, 0.5)
			elif traversal == 5: # GATE
				link_col = Color(1.0, 0.5, 0.2, 0.45)
			_world_draw.draw_line(sp, tp, link_col, 1.0)
			# Arrow head
			var dir := (tp - sp).normalized()
			var perp := Vector2(-dir.y, dir.x)
			var mid := sp.lerp(tp, 0.7)
			_world_draw.draw_line(mid, mid - dir * 6.0 + perp * 4.0, link_col, 1.0)
			_world_draw.draw_line(mid, mid - dir * 6.0 - perp * 4.0, link_col, 1.0)

func _draw_dashed_line(canvas: Node2D, from: Vector2, to: Vector2, col: Color, width: float, dash_len: float) -> void:
	var total := from.distance_to(to)
	if total < 1.0:
		return
	var dir := (to - from) / total
	var d := 0.0
	var drawing := true
	while d < total:
		var end_d := minf(d + dash_len, total)
		if drawing:
			canvas.draw_line(from + dir * d, from + dir * end_d, col, width)
		d = end_d
		drawing = not drawing

# --- Card management ---

func _rebuild_cards() -> void:
	for key in _player_cards.keys():
		var card: Control = _player_cards[key]
		if is_instance_valid(card):
			card.queue_free()
	_player_cards.clear()

	var ai_count := 0
	for player in tracked_players:
		if not is_instance_valid(player):
			continue
		var controller := player.get_node_or_null(^"AIController") as AIController
		if controller == null or not controller.enabled:
			continue
		ai_count += 1
		var card := _create_player_card(player)
		cards_vbox.add_child(card)
		_player_cards[player] = card

	no_ai_label.visible = ai_count == 0

func _create_player_card(player: Player) -> PanelContainer:
	var card := PanelContainer.new()
	card.layout_mode = 2

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.13, 0.2, 0.9)
	style.set_corner_radius_all(6)
	style.set_border_width_all(1)
	style.border_color = Color(0.2, 0.25, 0.38, 0.7)
	card.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.layout_mode = 2
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.layout_mode = 2
	vbox.add_theme_constant_override("separation", 5)
	margin.add_child(vbox)

	# Player name header
	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.layout_mode = 2
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(C_HEADING))
	vbox.add_child(name_label)

	# Separator
	var sep := HSeparator.new()
	sep.layout_mode = 2
	sep.add_theme_color_override("separator_color", Color(0.2, 0.25, 0.38, 0.5))
	vbox.add_child(sep)

	# All data rows use a single RichTextLabel per card — fast to update, BBCode colored
	var body := RichTextLabel.new()
	body.name = "BodyLabel"
	body.layout_mode = 2
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.add_theme_font_size_override("normal_font_size", 12)
	vbox.add_child(body)

	_update_card(card, player)
	return card

func _refresh_all_cards() -> void:
	var any_invalid := false
	for player in _player_cards.keys():
		if not is_instance_valid(player):
			any_invalid = true
			continue
		var card: Control = _player_cards[player]
		if is_instance_valid(card):
			_update_card(card, player)

	if any_invalid:
		_rebuild_cards()

func _update_card(card: PanelContainer, player: Player) -> void:
	var margin := card.get_child(0) as MarginContainer
	if margin == null:
		return
	var vbox := margin.get_child(0) as VBoxContainer
	if vbox == null:
		return

	var display_name := str(player.get_meta(&"match_display_name", player.name))
	var name_label := vbox.get_node_or_null(^"NameLabel") as Label
	if name_label != null:
		name_label.text = display_name

	var body := vbox.get_node_or_null(^"BodyLabel") as RichTextLabel
	if body == null:
		return

	var controller := player.get_node_or_null(^"AIController") as AIController
	if controller == null or not controller.enabled:
		body.text = "[color=%s]inactive[/color]" % C_DIM
		return

	var s := controller.get_debug_snapshot()
	if s.is_empty() or not bool(s.get("enabled", false)):
		body.text = "[color=%s]inactive[/color]" % C_DIM
		return

	body.text = _build_card_bbcode(s)

func _build_card_bbcode(s: Dictionary) -> String:
	var lines: Array[String] = []

	# Row 1: State + Goal
	var state_str := str(s.get("state", "-"))
	var goal_str := str(s.get("goal", "-"))
	var goal_node_str := str(s.get("goal_node", "-"))
	var state_col: String = str(STATE_COLORS.get(state_str, C_VALUE))
	var goal_col: String = str(GOAL_COLORS.get(goal_str, C_VALUE))
	var goal_display := goal_str
	if goal_node_str != "-":
		goal_display += " (%s)" % goal_node_str
	lines.append(
		"[color=%s]state[/color] [color=%s][b]%s[/b][/color]   [color=%s]goal[/color] [color=%s]%s[/color]" % [
			C_LABEL, state_col, state_str, C_LABEL, goal_col, goal_display
		]
	)

	# Row 2: Target
	var target_str := str(s.get("target", "-"))
	var dist := float(s.get("target_distance", -1.0))
	var dist_display := "-"
	if dist >= 0.0:
		dist_display = "%.0f px" % dist
	var dist_col := C_GOOD if dist >= 0.0 and dist < 200.0 else (C_WARN if dist < 360.0 else C_VALUE)
	lines.append(
		"[color=%s]target[/color] [color=%s]%s[/color]   [color=%s]dist[/color] [color=%s]%s[/color]" % [
			C_LABEL, C_VALUE, target_str, C_LABEL, dist_col, dist_display
		]
	)

	# Row 3: Shot info
	var shot_allowed := bool(s.get("shot_allowed", false))
	var shot_quality := float(s.get("shot_quality", -1.0))
	var shot_reason := str(s.get("shot_reason", "-"))
	var shot_col := C_GOOD if shot_allowed else C_BAD
	var quality_col := C_GOOD if shot_quality > 0.5 else (C_WARN if shot_quality > 0.0 else C_BAD)
	var quality_display := "%.2f" % shot_quality if shot_quality > -0.5 else "-"
	lines.append(
		"[color=%s]shot[/color] [color=%s]%s[/color]   [color=%s]q[/color] [color=%s]%s[/color]  [color=%s]%s[/color]" % [
			C_LABEL, shot_col, ("YES" if shot_allowed else "no"), C_LABEL, quality_col, quality_display, C_DIM, shot_reason
		]
	)

	# Row 4: Stomp
	var stomp_available := bool(s.get("stomp_available", false))
	var stomp_allowed := bool(s.get("stomp_allowed", false))
	var stomp_threat := bool(s.get("stomp_threat", false))
	var stomp_reason := str(s.get("stomp_reason", "-"))
	var stomp_col := C_GOOD if stomp_allowed else (C_WARN if stomp_available else C_DIM)
	var threat_col := C_BAD if stomp_threat else C_DIM
	lines.append(
		"[color=%s]stomp[/color] [color=%s]%s[/color]   [color=%s]threat[/color] [color=%s]%s[/color]  [color=%s]%s[/color]" % [
			C_LABEL, stomp_col, ("YES" if stomp_allowed else "no"), C_LABEL, threat_col, ("YES" if stomp_threat else "no"), C_DIM, stomp_reason
		]
	)

	# Row 5: Path probe
	var probe_blocked := bool(s.get("probe_blocked", false))
	var probe_jumpable := bool(s.get("probe_jumpable", false))
	var probe_hazard := bool(s.get("probe_hazard", false))
	var probe_reason := str(s.get("probe_reason", "clear"))
	var probe_col := C_BAD if probe_hazard else (C_WARN if probe_blocked else C_GOOD)
	var probe_bits: Array[String] = [probe_reason]
	if probe_blocked: probe_bits.append("blocked")
	if probe_jumpable: probe_bits.append("jumpable")
	if probe_hazard: probe_bits.append("hazard")
	var landing_display := "-"
	if bool(s.get("landing_available", false)):
		landing_display = _format_vector(s.get("landing_point", Vector2.ZERO))
	lines.append(
		"[color=%s]path[/color] [color=%s]%s[/color]   [color=%s]land[/color] [color=%s]%s[/color]" % [
			C_LABEL, probe_col, ", ".join(probe_bits), C_LABEL, C_VALUE, landing_display
		]
	)

	# Row 6: Route
	var route: Variant = s.get("route", {})
	var route_active := false
	var route_label := "-"
	if route is Dictionary:
		route_active = bool(route.get("active", false))
		route_label = str(route.get("label", "-"))
	var route_col := C_GOOD if route_active else C_DIM
	lines.append(
		"[color=%s]route[/color] [color=%s]%s[/color]" % [C_LABEL, route_col, route_label]
	)

	# Row 7: Input
	var dir: Vector2 = s.get("control_direction", Vector2.ZERO)
	var jump := bool(s.get("jump_pressed", false))
	var use_p := bool(s.get("use_pressed", false))
	var dash := bool(s.get("dash_pressed", false))
	var dir_str := _format_vector(dir)
	lines.append(
		"[color=%s]input[/color] [color=%s]%s[/color]  jump[color=%s]%s[/color]  use[color=%s]%s[/color]  dash[color=%s]%s[/color]" % [
			C_LABEL, C_VALUE, dir_str,
			(C_GOOD if jump else C_DIM), (" y" if jump else " -"),
			(C_GOOD if use_p else C_DIM), (" y" if use_p else " -"),
			(C_GOOD if dash else C_DIM), (" y" if dash else " -"),
		]
	)

	# Row 8: Stuck / dodge
	var stuck := float(s.get("stuck_time_left", 0.0))
	var escape_dir := int(s.get("escape_dir", 0))
	var dodge_active := bool(s.get("dodge_active", false))
	var dodge_pending := bool(s.get("dodge_pending", false))
	var stuck_col := C_BAD if stuck > 0.3 else (C_WARN if stuck > 0.0 else C_DIM)
	var dodge_col := C_WARN if dodge_active or dodge_pending else C_DIM
	var escape_display := "-"
	if escape_dir != 0:
		escape_display = ("escape >" if escape_dir > 0 else "escape <")
	elif stuck > STUCK_ESCAPE_SHOW:
		escape_display = "pending"
	lines.append(
		"[color=%s]stuck[/color] [color=%s]%.2fs[/color]  [color=%s]%s[/color]   [color=%s]dodge[/color] [color=%s]%s[/color]" % [
			C_LABEL, stuck_col, stuck, (C_WARN if escape_dir != 0 else C_DIM), escape_display,
			C_LABEL, dodge_col,
			("active" if dodge_active else ("pending" if dodge_pending else "-"))
		]
	)

	# Row 9: Session stats
	var shots := int(s.get("session_shots_fired", 0))
	var dodges := int(s.get("session_dodges_entered", 0))
	var stuck_total := float(s.get("session_stuck_total", 0.0))
	lines.append(
		"[color=%s]session[/color]  shots [color=%s]%d[/color]   dodges [color=%s]%d[/color]   stuck [color=%s]%.1fs[/color]" % [
			C_LABEL, C_VALUE, shots, C_VALUE, dodges, C_WARN if stuck_total > 2.0 else C_VALUE, stuck_total
		]
	)

	# Row 10: History
	var hist_raw: Array = s.get("action_history_names", [])
	var hist_colored: Array[String] = []
	for h_entry in hist_raw:
		var h_str := str(h_entry)
		var h_col: String = str(STATE_COLORS.get(h_str, C_HIST))
		hist_colored.append("[color=%s]%s[/color]" % [h_col, h_str])
	var hist_display := " > ".join(hist_colored) if not hist_colored.is_empty() else "[color=%s]-[/color]" % C_DIM
	lines.append("[color=%s]history[/color]  %s" % [C_LABEL, hist_display])

	return "\n".join(lines)

func _format_vector(value: Variant) -> String:
	if value is Vector2:
		var vec: Vector2 = value
		return "(%.0f, %.0f)" % [vec.x, vec.y]
	return "-"

func _format_bool(value: Variant) -> String:
	return "yes" if bool(value) else "no"
