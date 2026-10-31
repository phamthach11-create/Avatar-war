extends Control
const Battle = preload("res://src/combat/mixed_battle.gd")
const RequestedBattle = preload("res://src/combat/requested_battle.gd")
@export var requested_scenario := false
const BattleLog = preload("res://src/combat/battle_log.gd")
const DummyView = preload("res://src/ui/dummy_view.gd")
const BLUE := Color("70cfff")
const CORAL := Color("ff9a86")
const MUTED := Color("b3c4d2")
var _duel: RefCounted
var _cards: Dictionary = {}
var _status: Label
var _turn_label: Label
var _log: RichTextLabel
var _next_button: Button
var _auto_button: Button
var _timer: Timer
var _busy := false
var _auto_running := false
var _playback_id := 0
var animation_speed := 1.0
var _display_teams: Dictionary = {}
var _acting_team := ""
var _acting_index := -1
var _target_team := ""
var _target_index := -1
var _result_panel: PanelContainer
var _result_title: Label
var _result_subtitle: Label
var _swing_audio: AudioStreamPlayer
var _hit_audio: AudioStreamPlayer
var _win_audio: AudioStreamPlayer
var _sound_enabled := true
var _export_button: Button
var _export_dialog: FileDialog
var _match_metadata: Dictionary = {}
var _export_expected_match := ""
var _skill_mode: CheckButton
var _action_name := ""
var _presented_actions := 0
var _initiative: OptionButton

func _ready() -> void:
	_build_interface()
	_restart()

func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color("091322")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 7)
	margin.add_child(layout)
	layout.add_child(_label("AVATAR WAR  /  9 vs 9", 25, Color.WHITE))
	_status = _label("", 18, Color.WHITE)
	layout.add_child(_status)
	_turn_label = _label("", 13, MUTED)
	layout.add_child(_turn_label)
	var battlefield := PanelContainer.new()
	battlefield.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(battlefield)
	var map := TextureRect.new()
	map.texture = preload("res://assets/maps/stone_arena.png")
	map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battlefield.add_child(map)
	var arena := HBoxContainer.new()
	arena.add_theme_constant_override("separation", 16)
	battlefield.add_child(arena)
	_add_team(arena, "A", BLUE, true)
	var vs := _label("VS", 22, Color.WHITE)
	vs.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arena.add_child(vs)
	_add_team(arena, "B", CORAL, false)
	var controls := HBoxContainer.new()
	layout.add_child(controls)
	_next_button = _button("Next turn", _advance)
	controls.add_child(_next_button)
	_auto_button = _button("Auto: OFF", _toggle_auto)
	controls.add_child(_auto_button)
	controls.add_child(_button("Restart", _restart))
	var speed := OptionButton.new()
	for label in ["1x", "2x", "4x", "8x"]:
		speed.add_item(label)
	speed.selected = 2
	animation_speed = 0.25
	speed.item_selected.connect(func(i: int) -> void: animation_speed = 1.0 / pow(2.0,i))
	controls.add_child(speed)
	var sound_button := _button("Sound: ON", func() -> void:
		_sound_enabled = not _sound_enabled
		if not _sound_enabled:
			_swing_audio.stop()
			_hit_audio.stop()
			_win_audio.stop())
	sound_button.pressed.connect(func() -> void: sound_button.text = "Sound: ON" if _sound_enabled else "Sound: OFF")
	controls.add_child(sound_button)
	_skill_mode = CheckButton.new()
	_skill_mode.text = "Skills"
	_skill_mode.button_pressed = true
	_skill_mode.toggled.connect(func(_enabled: bool) -> void: _restart())
	controls.add_child(_skill_mode)
	controls.add_child(_button("Builds", _show_builds))
	_export_button = _button("Xuất log", _request_export)
	_export_button.tooltip_text = "Lưu JSON hoặc TXT. Chờ lượt hiện tại phát xong để xuất."
	controls.add_child(_export_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(spacer)
	controls.add_child(_label("First team:", 14, MUTED))
	_initiative = OptionButton.new()
	_initiative.add_item("Team A")
	_initiative.add_item("Team B")
	_initiative.item_selected.connect(func(_index: int) -> void: _restart())
	controls.add_child(_initiative)
	layout.add_child(_label("Requested roster: slots 1–9 fixed | MAIN Leonidas slot5 | Same builds both teams | Automata: one of each type/team", 13, MUTED))
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.custom_minimum_size.y = 105
	_log.add_theme_font_size_override("normal_font_size", 13)
	layout.add_child(_log)
	_timer = Timer.new()
	_timer.wait_time = 0.35
	_timer.one_shot = true
	_timer.timeout.connect(_advance)
	add_child(_timer)
	_build_feedback()

func _add_team(parent: HBoxContainer, team: String, accent: Color, right: bool) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.05, 0.05, 0.24), Color(accent, 0.4)))
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	panel.add_child(column)
	column.add_child(_label("TEAM " + team + "  /  3 x 3", 17, accent))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 3)
	column.add_child(grid)
	_cards[team] = []
	_cards[team].resize(9)
	for display_index in range(9):
		# Depth is mirrored across the central battlefield. Identity stays unchanged.
		var lane: int = floori(display_index / 3.0)
		var depth: int = 2 - display_index % 3 if right else display_index % 3
		var index: int = depth * 3 + lane
		var tile := VBoxContainer.new()
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tile.add_theme_constant_override("separation", 0)
		grid.add_child(tile)
		var roster: Array = _battle_config().roster
		var name_text := "%s%d %s%s" % [team, index + 1, roster[index].label, " / MAIN" if index == 4 else ""]
		var name_label := _label(name_text, 12, accent)
		name_label.tooltip_text = str(roster[index].levels) + "\n" + str(roster[index].nodes) + "\n" + str(roster[index].type)
		name_label.mouse_filter = Control.MOUSE_FILTER_STOP
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.add_child(name_label)
		var view := DummyView.new()
		view.accent = accent
		view.faces_right = right
		view.is_main = index == 4
		view.unit_type = _battle_config().roster[index].type
		tile.add_child(view)
		view.custom_minimum_size = Vector2(90, 70)
		view.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var health := ProgressBar.new()
		health.show_percentage = false
		health.custom_minimum_size.y = 7
		var fill := StyleBoxFlat.new()
		fill.bg_color = accent
		health.add_theme_stylebox_override("fill", fill)
		var track := StyleBoxFlat.new()
		track.bg_color = Color("18202a")
		health.add_theme_stylebox_override("background", track)
		tile.add_child(health)
		var detail := _label("", 11, Color.WHITE)
		detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.add_child(detail)
		var skill_detail := _label("", 11, Color("b5b7ff"))
		skill_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.add_child(skill_detail)
		var status_detail := _label("", 11, Color("ffd66b"))
		status_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.add_child(status_detail)
		_cards[team][index] = {"view": view, "health": health, "detail": detail, "skill_detail": skill_detail, "status_detail": status_detail}

func _build_feedback() -> void:
	_swing_audio = _audio("res://assets/audio/sword_swing.wav", -19.0)
	_hit_audio = _audio("res://assets/audio/sword_hit.wav", -17.0)
	_win_audio = _audio("res://assets/audio/victory.wav", -20.0)
	_result_panel = PanelContainer.new()
	_result_panel.add_theme_stylebox_override("panel", _panel_style(Color("101d2e"), Color("ffd66b")))
	_result_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_result_panel.position = Vector2(-220, -80)
	_result_panel.size = Vector2(440, 160)
	_result_panel.z_index = 30
	add_child(_result_panel)
	var column := VBoxContainer.new()
	_result_panel.add_child(column)
	_result_title = _label("", 28, Color("ffd66b"))
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_result_title)
	var subtitle := _label("Enemy MAIN defeated", 16, Color.WHITE)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	_result_subtitle = subtitle
	column.add_child(_button("Play again", _restart))
	_result_panel.hide()

func _audio(path: String, volume: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = load(path)
	player.volume_db = volume
	add_child(player)
	return player

func _restart() -> void:
	if is_instance_valid(_export_dialog):
		_export_dialog.hide()
	_export_expected_match = ""
	_playback_id += 1
	_busy = false
	_auto_running = false
	_display_teams.clear()
	_clear_focus()
	_timer.stop()
	for player in [_swing_audio, _hit_audio, _win_audio]:
		player.stop()
	_result_panel.hide()
	for team in ["A", "B"]:
		for card in _cards[team]:
			card["view"].reset_animation()
	var scenario: Dictionary = _battle_config()
	scenario["demo_defend"] = false
	_duel = RequestedBattle.new(scenario, "A" if _initiative.selected == 0 else "B", 42, _skill_mode.button_pressed) if requested_scenario else Battle.new(scenario, "A" if _initiative.selected == 0 else "B", 42, _skill_mode.button_pressed)
	_match_metadata = {"match_id":Time.get_datetime_string_from_system(true).replace(":","-")+"-"+str(Time.get_ticks_usec()), "started_at_utc":Time.get_datetime_string_from_system(true), "seed":42, "first_team":"A" if _initiative.selected == 0 else "B", "godot_version":Engine.get_version_info().string, "engine_sha256":FileAccess.get_sha256("res://src/combat/requested_battle.gd" if requested_scenario else "res://src/combat/mixed_battle.gd"), "config_sha256":FileAccess.get_sha256("res://data/gameplay/requested_9v9.json" if requested_scenario else "res://data/gameplay/mixed_9v9.json")}
	_presented_actions = 0
	_log.clear()
	_log.append_text("Mixed 9 vs 9 ready. 2 Napoleons per team. Gold: actor; red: target; crown: MAIN.\n")
	if _skill_mode.button_pressed:
		_log.append_text("Each character uses its own skills, costs and weapon area. Cooldowns recover at END of every global turn for both teams.\n")
	_auto_button.text = "Auto: OFF"
	_refresh()

func _clear_focus() -> void:
	_acting_team = ""
	_action_name = ""
	_acting_index = -1
	_target_team = ""
	_target_index = -1

func _advance() -> void:
	if _busy or _duel.finished:
		return
	_timer.stop()
	var event: Dictionary = _duel.step()
	if event.is_empty():
		return
	_display_teams = event["turn_start_state"].duplicate(true)
	_busy = true
	var ticket := _playback_id
	for action in event["actions"]:
		var team: String = action.team
		_acting_team = team
		_acting_index = action.actor
		_target_team = action.target_team
		_target_index = action.target
		_action_name = action.name
		if action.kind == "system":
			_display_teams = action.state_after.duplicate(true)
			_refresh()
			continue
		var attacker: Control = _cards[team][_acting_index].view
		var melee: bool = action.kind == "attack" and _display_teams[team][_acting_index].type in ["Warrior","Soldier","Destroyer"]
		_refresh()
		if melee and _target_index >= 0:
			var travel: float = attacker.approach(_cards[_target_team][_target_index].view, animation_speed)
			if animation_speed > 0:
				await get_tree().create_timer(travel).timeout
			if ticket != _playback_id:
				return
		if action.kind != "dot":
			attacker.animate_attack(animation_speed)
			if not melee and action.target >= 0 and action.target_team != action.team:
				attacker.fire_at(_cards[action.target_team][action.target].view, action.kind != "attack", animation_speed)
			if _sound_enabled:
				_swing_audio.play()
			if animation_speed > 0:
				await get_tree().create_timer(0.22 * animation_speed).timeout
			if ticket != _playback_id:
				return
		var total := 0.0
		var misses := 0
		for impact in action.impacts:
			_display_teams[impact.team][impact.target] = impact.target_state.duplicate(true)
			var view: Control = _cards[impact.team][impact.target].view
			if impact.damage < 0:
				view.animate_heal(-impact.damage)
			elif impact.damage > 0:
				view.animate_hit(impact.damage, action.kind != "attack")
				if _sound_enabled and impact.damage > 0:
					_hit_audio.play()
			if not impact.landed:
				misses += 1
			total += impact.damage
		_display_teams = action.state_after.duplicate(true)
		_presented_actions += 1
		_log.append_text("T%d | %s%d %s | %s | %d target(s) | HP change %.0f\n" % [event.turn,team,action.actor+1,_display_teams[team][action.actor].name,action.name + (" · MISS %d" % misses if misses > 0 else ""),action.impacts.size(),-total])
		_refresh()
		if animation_speed > 0:
			await get_tree().create_timer((0.05 if action.kind == "dot" else 0.40)*animation_speed).timeout
		if ticket != _playback_id:
			return
		if melee:
			var travel: float = attacker.return_home(animation_speed)
			if animation_speed > 0:
				await get_tree().create_timer(travel).timeout
			if ticket != _playback_id:
				return
		attacker.finish_return()
	_clear_focus()
	_busy = false
	_display_teams.clear()
	if _duel.finished:
		_auto_running = false
		_auto_button.text = "Auto: OFF"
		_result_title.text = "TEAM %s WINS" % _duel.winner if _duel.winner != "" else "TURN LIMIT"
		_result_subtitle.text = "Enemy MAIN defeated" if _duel.winner != "" else "No winner within the turn limit"
		_result_panel.show()
		if _sound_enabled:
			_win_audio.play()
	_refresh()
	if _auto_running:
		_timer.start()

func _toggle_auto() -> void:
	if _duel.finished and not _busy:
		return
	_auto_running = not _auto_running
	_auto_button.text = "Auto: ON" if _auto_running else "Auto: OFF"
	if not _auto_running:
		_timer.stop()
	elif not _busy:
		_timer.start()
	_refresh()

func _refresh() -> void:
	for team in ["A", "B"]:
		for index in range(9):
			var unit: Dictionary = _display_teams[team][index] if _busy else _duel.teams[team][index]
			var card: Dictionary = _cards[team][index]
			card["health"].max_value = unit["max_hp"]
			card["health"].value = unit["hp"]
			card["detail"].text = "HP %.0f | AP %.0f" % [unit["hp"], unit["ap"]] if unit["hp"] > 0.0 else "DEFEATED"
			var cds: Array[String] = []
			for skill_name in unit.levels:
				cds.append("%s:%d" % [skill_name.substr(0,1), unit.skills[skill_name].remaining])
			var tooltip := ""
			for skill_name in unit.levels:
				var data: Dictionary = unit.skills[skill_name]
				tooltip += "%s SL%d | AP %.0f MP %.0f | CD %d/%d\n" % [skill_name,unit.levels[skill_name],data.ap,data.mp,data.remaining,data.cd]
			card["skill_detail"].tooltip_text = tooltip
			card["skill_detail"].mouse_filter = Control.MOUSE_FILTER_STOP
			card["status_detail"].tooltip_text = str(unit.statuses)
			card["status_detail"].mouse_filter = Control.MOUSE_FILTER_STOP
			card["skill_detail"].text = "MP %.0f | %s" % [unit.mp, " ".join(cds)] if unit.hp > 0 else ""
			var stunned: bool = int(unit["stunned_until"]) > _duel.global_turn
			card["status_detail"].text = "STUN until T%d" % unit["stunned_until"] if stunned else "Stacks %d/%d | effects %d" % [unit.stun_count,unit.stun_threshold,unit.statuses.size()]
			card["view"].stunned = stunned
			card["view"].guarding = bool(unit.get("defending", false))
			card["view"].set_state(not _busy and not _duel.finished and _duel.next_team() == team, unit["hp"] <= 0.0)
			card["view"].set_focus(team == _acting_team and index == _acting_index, team == _target_team and index == _target_index)
	_status.text = "TEAM %s WINS — enemy MAIN defeated" % _duel.winner if _duel.finished and not _duel.winner.is_empty() else ("TURN LIMIT REACHED" if _duel.finished else "NEXT: Team %s  |  Alive A: %d/9  B: %d/9" % [_duel.next_team(), _duel.living("A"), _duel.living("B")])
	if _busy:
		_status.text = "%s: %s%d" % [_action_name, _acting_team, _acting_index + 1] if _target_index < 0 else "%s: %s%d > %s%d" % [_action_name, _acting_team, _acting_index + 1, _target_team, _target_index + 1]
	_turn_label.text = "Global Turn %d | MAIN A5/B5: Leonidas | End turn: DOT > expiration > cooldown | Build and skill details: hover names" % _duel.global_turn
	if requested_scenario:
		_turn_label.text = "Turn %d | Main A5/B5 | Automata P=Piercing B=Bombard: %s | Mona Lisa: HP <=65%%" % [_duel.global_turn,_automation_summary(_display_teams if _busy else _duel.teams)]
	_export_button.disabled = _busy
	_next_button.disabled = _busy or _duel.finished or _auto_running
	_auto_button.disabled = _duel.finished and not _busy

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




func _show_builds() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Builds · both teams"
	dialog.min_size = Vector2i(520,320)
	dialog.max_size = Vector2i(1000,760)
	var content := RichTextLabel.new()
	content.name = "BuildContent"
	content.bbcode_enabled = true
	content.scroll_active = true
	content.fit_content = false
	content.custom_minimum_size = Vector2(500,280)
	content.add_theme_font_size_override("normal_font_size",15)
	content.add_theme_font_size_override("bold_font_size",17)
	content.selection_enabled = true
	var text := "[b]Same roster and builds on both teams[/b]\nFront: 1–3 | Middle: 4–6 | Rear: 7–9 | MAIN: A5/B5\nScroll to see all 9 characters.\n\n"
	for entry in _battle_config().roster:
		text += "[b]%d. %s%s[/b]\n" % [entry.index+1,entry.label," · MAIN" if entry.index == 4 else ""]
		var skills: Array[String] = []
		for skill_name in entry.levels:
			skills.append("%s: SL %d" % [skill_name,entry.levels[skill_name]])
		text += "Skills: %s\n" % ", ".join(skills)
		text += "Nodes: %s\n" % ", ".join(entry.nodes)
		text += "Source stats: HP %.0f | MP %.0f | ATK %.0f | Accuracy %.0f%%\n\n" % [entry.max_hp,entry.max_mp,entry.attack,entry.accuracy*100]
	content.text = text
	dialog.add_child(content)
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	var viewport := get_viewport_rect().size
	dialog.popup_centered(Vector2i(mini(900,int(viewport.x)-80),mini(680,int(viewport.y)-100)))

func _request_export() -> void:
	if _busy:
		return
	if _auto_running:
		_toggle_auto()
	if not is_instance_valid(_export_dialog):
		_export_dialog = FileDialog.new()
		_export_dialog.title = "Xuất log trận test"
		_export_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		_export_dialog.filters = PackedStringArray(["*.json ; JSON - detailed battle data", "*.txt ; TXT - readable battle report"])
		_export_dialog.exclusive = true
		_export_dialog.current_dir = ProjectSettings.globalize_path("res://")
		_export_dialog.file_selected.connect(_save_selected_log)
		add_child(_export_dialog)
	_export_expected_match = _match_metadata.match_id
	_export_dialog.current_file = "avatar-war-"+_match_metadata.match_id+".json"
	_export_dialog.popup_centered_ratio(0.8)

func _save_selected_log(path: String) -> void:
	if path.get_extension().is_empty():
		path += ".json"
	var error := _export_log_to(path, _export_expected_match)
	if error == OK:
		_log.add_text("Đã xuất log: %s\n" % path)
	else:
		_log.add_text("Không thể xuất log (%s). Kiểm tra định dạng JSON/TXT và quyền ghi, rồi thử lại.\n" % error_string(error))

func _export_log_to(path: String, expected_match: String = "") -> Error:
	if _busy:
		return ERR_BUSY
	if expected_match != "" and expected_match != _match_metadata.match_id:
		return ERR_SKIP
	return BattleLog.save(path,_duel,_match_metadata)

func _battle_config() -> Dictionary:
	return RequestedBattle.load_mixed_config() if requested_scenario else Battle.load_mixed_config()

func _automation_summary(state: Dictionary) -> String:
	var sides: Array[String] = []
	for side in ["A","B"]:
		var machines: Array[String] = []
		for unit in state[side]:
			for machine in unit.get("automata",[]):
				machines.append(("B" if machine.type=="Devastator" else "P")+"("+str(int(unit.index)+1)+")")
		sides.append(side+": "+(",".join(machines) if not machines.is_empty() else "none"))
	return " / ".join(sides)

