extends Control

const Duel = preload("res://src/combat/dummy_duel.gd")
const DummyView = preload("res://src/ui/dummy_view.gd")
const BLUE := Color("70cfff")
const CORAL := Color("ff9a86")
const MUTED := Color("9aafc8")

var _duel: RefCounted
var _cards: Dictionary = {}
var _status: Label
var _turn_label: Label
var _log: RichTextLabel
var _next_button: Button
var _auto_button: Button
var _timer: Timer
var _initiative: OptionButton


func _ready() -> void:
	_build_interface()
	_restart()


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color("091322")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := _label("AVATAR WAR", 30, Color.WHITE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_label("COMBAT LAB / 01", 16, BLUE))
	layout.add_child(_label("Two Balanced Dummies  |  Normal attacks only  |  Excel benchmark", 15, MUTED))
	_status = _label("", 21, Color.WHITE)
	layout.add_child(_status)
	_turn_label = _label("", 14, MUTED)
	layout.add_child(_turn_label)
	var arena := HBoxContainer.new()
	arena.add_theme_constant_override("separation", 18)
	layout.add_child(arena)
	_add_fighter_card(arena, "A", BLUE, true)
	var versus := _label("VS", 24, MUTED)
	versus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arena.add_child(versus)
	_add_fighter_card(arena, "B", CORAL, false)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 12)
	layout.add_child(controls)
	_next_button = _button("Next turn", _advance)
	controls.add_child(_next_button)
	_auto_button = _button("Auto: OFF", _toggle_auto)
	controls.add_child(_auto_button)
	controls.add_child(_button("Restart", _restart))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(spacer)
	controls.add_child(_label("Initiative tie winner:", 14, MUTED))
	_initiative = OptionButton.new()
	_initiative.add_item("Team A")
	_initiative.add_item("Team B")
	_initiative.custom_minimum_size = Vector2(110, 42)
	_initiative.item_selected.connect(func(_index: int) -> void: _restart())
	controls.add_child(_initiative)
	layout.add_child(_label("One slot per character. AP recovery does not create extra action slots.", 13, MUTED))
	var log_panel := PanelContainer.new()
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_panel.add_theme_stylebox_override("panel", _panel_style(Color("101e31")))
	layout.add_child(log_panel)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.custom_minimum_size.y = 130
	_log.add_theme_font_size_override("normal_font_size", 15)
	log_panel.add_child(_log)
	_timer = Timer.new()
	_timer.wait_time = 0.65
	_timer.timeout.connect(_advance)
	add_child(_timer)


func _add_fighter_card(parent: HBoxContainer, team: String, accent: Color, right: bool) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color("132239"), accent.darkened(0.6)))
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	panel.add_child(column)
	column.add_child(_label("TEAM %s / BALANCED DUMMY" % team, 18, accent))
	var view := DummyView.new()
	view.accent = accent
	view.faces_right = right
	column.add_child(view)
	var health := ProgressBar.new()
	health.show_percentage = false
	health.custom_minimum_size.y = 15
	var fill := StyleBoxFlat.new()
	fill.bg_color = accent
	fill.set_corner_radius_all(6)
	var track := StyleBoxFlat.new()
	track.bg_color = Color("253750")
	track.set_corner_radius_all(6)
	health.add_theme_stylebox_override("fill", fill)
	health.add_theme_stylebox_override("background", track)
	column.add_child(health)
	var hp_text := _label("", 17, Color.WHITE)
	column.add_child(hp_text)
	var stats := _label("", 14, MUTED)
	column.add_child(stats)
	var detail := _label("", 14, MUTED)
	column.add_child(detail)
	_cards[team] = {"view": view, "health": health, "hp": hp_text, "stats": stats, "detail": detail}


func _restart() -> void:
	if is_instance_valid(_timer):
		_timer.stop()
	var first: String = "A" if _initiative.selected == 0 else "B"
	_duel = Duel.new(Duel.load_config(), first)
	_log.clear()
	_log.append_text("[b]Battle ready.[/b] Starting AP: 0. Each team recovers AP only on its own turn.\n")
	_log.append_text("Equal starting AP: Team %s selected as the deterministic tie winner.\n" % first)
	_auto_button.text = "Auto: OFF"
	_refresh()


func _advance() -> void:
	var event: Dictionary = _duel.step()
	if event.is_empty():
		return
	var team: String = str(event["team"])
	var accent: Color = BLUE if team == "A" else CORAL
	var text: String
	if event["action"] == "Normal Attack":
		_cards[team]["view"].animate_attack()
		_cards[event["target"]]["view"].animate_hit()
		text = "Turn %02d | Team %s attacks %s: %.0f damage | AP %.0f + %.0f - %.0f = %.0f" % [
			event["turn"], team, event["target"], event["damage"], event["ap_before"],
			event["ap_recovered"], event["ap_cost"], event["ap_after"],
		]
	else:
		text = "Turn %02d | Team %s passes: AP %.0f + %.0f = %.0f, below the slot requirement." % [
			event["turn"], team, event["ap_before"], event["ap_recovered"], event["ap_after"],
		]
	_log.append_text("[color=#%s]%s[/color]\n" % [accent.to_html(false), text])
	if _duel.finished:
		_timer.stop()
		_auto_button.text = "Auto: OFF"
		_log.append_text("[b]%s. No further turns are executed.[/b]\n" % event["result"])
	_refresh()


func _toggle_auto() -> void:
	if _duel.finished:
		return
	if _timer.is_stopped():
		_timer.start()
		_auto_button.text = "Auto: ON"
	else:
		_timer.stop()
		_auto_button.text = "Auto: OFF"
	_refresh()


func _refresh() -> void:
	for team in ["A", "B"]:
		var state: Dictionary = _duel.fighter(team)
		var card: Dictionary = _cards[team]
		card["health"].max_value = state["max_hp"]
		card["health"].value = state["hp"]
		card["hp"].text = "HP  %.0f / %.0f" % [state["hp"], state["max_hp"]]
		card["stats"].text = "ATK %.0f    DEF %.0f    MIT %.0f%%" % [state["attack"], state["defense"], _duel.mitigation(team) * 100.0]
		card["detail"].text = "AP %.0f    Recovery +%.0f    Hits %d" % [state["ap"], state["ap_recovery"], state["hits"]]
		card["view"].set_state(not _duel.finished and _duel.next_team() == team, float(state["hp"]) <= 0.0)
	if _duel.finished:
		_status.text = "TEAM %s WINS" % _duel.winner if not _duel.winner.is_empty() else "TURN LIMIT REACHED"
	elif _duel.global_turn == 0:
		_status.text = "READY — Team %s acts first" % _duel.next_team()
	else:
		_status.text = "NEXT: Team %s" % _duel.next_team()
	_turn_label.text = "Global turn %d  |  Benchmark: 1,000 damage / hit, defeated on hit 20" % _duel.global_turn
	_next_button.disabled = _duel.finished or not _timer.is_stopped()
	_auto_button.disabled = _duel.finished


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(130, 42)
	button.pressed.connect(callback)
	return button


func _panel_style(color: Color, border: Color = Color("263b56")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style
