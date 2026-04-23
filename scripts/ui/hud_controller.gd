class_name HUDController
extends CanvasLayer


const PANEL_BACKGROUND: Color = Color(0.035, 0.047, 0.082, 0.72)
const PANEL_BORDER_ALPHA: float = 0.68
const EMPTY_PIP_COLOR: Color = Color(1.0, 1.0, 1.0, 0.08)
const HEALTH_COLOR: Color = Color("#ff5967")
const AMMO_COLOR: Color = Color(0.96, 0.95, 0.9, 0.92)
const DASH_COLOR: Color = Color("#74d0ff")
const TRIPLE_SHOT_COLOR: Color = Color("#fff078")
const ARMOR_COLOR: Color = Color("#8fd9ff")
const SPEED_COLOR: Color = Color("#8ff06d")
const RAPID_COLOR: Color = Color("#ff7ae0")
const EXTRA_DASH_COLOR: Color = Color("#74d0ff")

@onready var player_grid: GridContainer = $Root/TopStrip/Margin/PlayerGrid

var slot_widgets: Array[Dictionary] = []
var active_tweens: Dictionary = {}

func _ready() -> void:
	slot_widgets.clear()
	for child in player_grid.get_children():
		var panel := child as PanelContainer
		if panel == null:
			continue
		slot_widgets.append(_collect_slot_widgets(panel))

	for slot in range(slot_widgets.size()):
		_set_slot_connected(slot, false)

func bind_players(players: Array[Player]) -> void:
	for slot in range(slot_widgets.size()):
		_set_slot_connected(slot, false)
		_kill_tween("%d:dash" % slot)
		_kill_tween("%d:buff_speed" % slot)
		_kill_tween("%d:buff_rapid" % slot)
		_kill_tween("%d:buff_dash" % slot)

	for slot in range(mini(slot_widgets.size(), players.size())):
		_bind_player(slot, players[slot])

func _collect_slot_widgets(panel: PanelContainer) -> Dictionary:
	return {
		"panel": panel,
		"marker": panel.get_node("Margin/Layout/TopRow/Marker") as Panel,
		"health_row": panel.get_node("Margin/Layout/TopRow/HealthRow") as HBoxContainer,
		"dash_row": panel.get_node("Margin/Layout/TopRow/DashRow") as HBoxContainer,
		"ammo_row": panel.get_node("Margin/Layout/BottomRow/AmmoRow") as HBoxContainer,
		"special_row": panel.get_node("Margin/Layout/BottomRow/SpecialRow") as HBoxContainer,
		"buff_row": panel.get_node("Margin/Layout/BottomRow/BuffRow") as HBoxContainer,
		"cooldown_track": panel.get_node("Margin/Layout/CooldownTrack") as Panel,
		"cooldown_fill": panel.get_node("Margin/Layout/CooldownTrack/Fill") as ColorRect,
}

func _bind_player(slot: int, player: Player) -> void:
	player.hud_player_color_changed.connect(update_player_color.bind(slot))
	player.hud_health_changed.connect(update_health.bind(slot))
	player.hud_ammo_changed.connect(update_ammo.bind(slot))
	player.hud_ammo_changed.connect(update_special_ammo.bind(slot))
	player.hud_dash_changed.connect(update_dash.bind(slot))
	player.hud_buffs_changed.connect(update_buffs.bind(slot))
	player.im_dead.connect(set_player_dead.bind(slot))

	player.set_world_hud_visible(false)
	_set_slot_connected(slot, true)
	player.emit_hud_state()

func _set_slot_connected(slot: int, is_connected: bool) -> void:
	var panel := slot_widgets[slot].get("panel") as PanelContainer
	if panel == null:
		return

	panel.visible = is_connected
	if is_connected:
		panel.modulate = Color.WHITE
		return

	panel.remove_theme_stylebox_override("panel")

func update_player_color(player_color: Color, slot: int) -> void:
	var widgets := slot_widgets[slot]
	var panel := widgets.get("panel") as PanelContainer
	var marker := widgets.get("marker") as Panel
	var cooldown_fill := widgets.get("cooldown_fill") as ColorRect

	if panel == null or marker == null or cooldown_fill == null:
		return

	panel.add_theme_stylebox_override("panel", _make_panel_style(player_color))
	marker.add_theme_stylebox_override("panel", _make_pip_style(player_color, Vector2(10.0, 10.0), player_color.lightened(0.18)))
	cooldown_fill.color = player_color.lightened(0.08)

func update_health(current_health: int, slot: int) -> void:
	var container := slot_widgets[slot].get("health_row") as HBoxContainer
	if container == null:
		return

	_render_pips(container, maxi(current_health, 0), maxi(current_health, 1), HEALTH_COLOR, Vector2(8.0, 8.0))

func update_ammo(normal_ammo: int, _special_arrow_type: int, _special_ammo: int, _total_ammo: int, slot: int) -> void:
	var container := slot_widgets[slot].get("ammo_row") as HBoxContainer
	if container == null:
		return

	_render_pips(container, maxi(normal_ammo, 0), maxi(normal_ammo, 1), AMMO_COLOR, Vector2(4.0, 11.0), 3.0)

func update_special_ammo(_normal_ammo: int, special_arrow_type: int, special_ammo: int, _total_ammo: int, slot: int) -> void:
	var container := slot_widgets[slot].get("special_row") as HBoxContainer
	if container == null:
		return

	_clear_container(container)
	container.visible = special_ammo > 0
	if special_ammo <= 0:
		return

	var special_color := Arrow.get_arrow_color(special_arrow_type)
	container.add_child(_create_pip(special_color.darkened(0.05), Vector2(6.0, 11.0), special_color.lightened(0.2)))
	for _index in range(special_ammo):
		container.add_child(_create_pip(special_color, Vector2(4.0, 11.0), special_color.lightened(0.2)))

func update_dash(
	available: int,
	max_count: int,
	cooldown_remaining: float,
	cooldown_duration: float,
	slot: int
) -> void:
	var widgets := slot_widgets[slot]
	var dash_row := widgets.get("dash_row") as HBoxContainer
	var cooldown_track := widgets.get("cooldown_track") as Panel
	var cooldown_fill := widgets.get("cooldown_fill") as ColorRect
	if dash_row == null or cooldown_track == null or cooldown_fill == null:
		return

	_render_pips(dash_row, maxi(available, 0), maxi(max_count, 1), DASH_COLOR, Vector2(12.0, 5.0), 4.0)

	var tween_key := "%d:dash" % slot
	_kill_tween(tween_key)

	if available >= max_count or cooldown_duration <= 0.0:
		cooldown_track.hide()
		_set_fill_ratio(cooldown_fill, 0.0)
		return

	cooldown_track.show()
	cooldown_fill.color = DASH_COLOR
	var start_ratio := clampf(1.0 - (cooldown_remaining / cooldown_duration), 0.0, 1.0)
	_set_fill_ratio(cooldown_fill, start_ratio)
	if cooldown_remaining > 0.0:
		_start_fill_tween(tween_key, cooldown_fill, start_ratio, 1.0, cooldown_remaining)

func update_buffs(
	triple_shot_count: int,
	armor_count: int,
	speed_remaining: float,
	speed_duration: float,
	rapid_remaining: float,
	rapid_duration: float,
	extra_dash_remaining: float,
	extra_dash_duration: float,
	slot: int
) -> void:
	var container := slot_widgets[slot].get("buff_row") as HBoxContainer
	if container == null:
		return

	_kill_tween("%d:buff_speed" % slot)
	_kill_tween("%d:buff_rapid" % slot)
	_kill_tween("%d:buff_dash" % slot)
	_clear_container(container)

	for _index in range(triple_shot_count):
		container.add_child(_create_pip(TRIPLE_SHOT_COLOR, Vector2(4.0, 10.0), TRIPLE_SHOT_COLOR.lightened(0.18)))

	for _index in range(armor_count):
		container.add_child(_create_pip(ARMOR_COLOR, Vector2(6.0, 6.0), ARMOR_COLOR.lightened(0.18)))

	_append_timed_buff(container, slot, "speed", SPEED_COLOR, speed_remaining, speed_duration)
	_append_timed_buff(container, slot, "rapid", RAPID_COLOR, rapid_remaining, rapid_duration)
	_append_timed_buff(container, slot, "dash", EXTRA_DASH_COLOR, extra_dash_remaining, extra_dash_duration)

	container.visible = container.get_child_count() > 0

func set_player_dead(slot: int) -> void:
	var panel := slot_widgets[slot].get("panel") as PanelContainer
	if panel == null:
		return

	panel.modulate = Color(1.0, 1.0, 1.0, 0.35)
	_kill_tween("%d:dash" % slot)
	_kill_tween("%d:buff_speed" % slot)
	_kill_tween("%d:buff_rapid" % slot)
	_kill_tween("%d:buff_dash" % slot)

func _append_timed_buff(
	container: HBoxContainer,
	slot: int,
	buff_name: String,
	buff_color: Color,
	remaining: float,
	duration: float
) -> void:
	if remaining <= 0.0 or duration <= 0.0:
		return

	var track := Panel.new()
	track.custom_minimum_size = Vector2(18.0, 6.0)
	track.clip_contents = true
	track.add_theme_stylebox_override("panel", _make_track_style())

	var fill := ColorRect.new()
	fill.color = buff_color
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.anchor_bottom = 1.0
	track.add_child(fill)
	_set_fill_ratio(fill, clampf(remaining / duration, 0.0, 1.0))

	container.add_child(track)
	_start_fill_tween("%d:buff_%s" % [slot, buff_name], fill, fill.anchor_right, 0.0, remaining)

func _render_pips(
	container: HBoxContainer,
	filled_count: int,
	total_count: int,
	filled_color: Color,
	pip_size: Vector2,
	separation: float = 3.0
) -> void:
	_clear_container(container)
	container.add_theme_constant_override("separation", int(separation))

	for pip_index in range(total_count):
		var color := filled_color if pip_index < filled_count else EMPTY_PIP_COLOR
		var border_color := filled_color.lightened(0.18) if pip_index < filled_count else Color(1.0, 1.0, 1.0, 0.06)
		container.add_child(_create_pip(color, pip_size, border_color))

func _create_pip(color: Color, pip_size: Vector2, border_color: Color) -> Panel:
	var pip := Panel.new()
	pip.custom_minimum_size = pip_size
	pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pip.add_theme_stylebox_override("panel", _make_pip_style(color, pip_size, border_color))
	return pip

func _make_panel_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BACKGROUND
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(accent.r, accent.g, accent.b, PANEL_BORDER_ALPHA)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_right = 16
	style.corner_radius_bottom_left = 16
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	style.shadow_size = 8
	return style

func _make_pip_style(color: Color, pip_size: Vector2, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border_color
	var radius := int(minf(pip_size.x, pip_size.y) * 0.5)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	return style

func _make_track_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, 0.08)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	return style

func _set_fill_ratio(fill: ColorRect, ratio: float) -> void:
	fill.anchor_left = 0.0
	fill.anchor_top = 0.0
	fill.anchor_bottom = 1.0
	fill.anchor_right = clampf(ratio, 0.0, 1.0)
	fill.offset_left = 0.0
	fill.offset_top = 0.0
	fill.offset_right = 0.0
	fill.offset_bottom = 0.0

func _start_fill_tween(key: String, fill: ColorRect, from_ratio: float, to_ratio: float, duration: float) -> void:
	_kill_tween(key)
	_set_fill_ratio(fill, from_ratio)
	if duration <= 0.0:
		_set_fill_ratio(fill, to_ratio)
		return

	var tween := create_tween()
	tween.tween_property(fill, "anchor_right", clampf(to_ratio, 0.0, 1.0), duration).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	active_tweens[key] = tween
	tween.finished.connect(_on_tween_finished.bind(key))

func _kill_tween(key: String) -> void:
	var tween := active_tweens.get(key) as Tween
	if tween != null:
		tween.kill()
	active_tweens.erase(key)

func _on_tween_finished(key: String) -> void:
	active_tweens.erase(key)

func _clear_container(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()
