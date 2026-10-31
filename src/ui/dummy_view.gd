extends Control
## Code-drawn feedback around the approved warrior illustration.
const SHEET = preload("res://assets/characters/warrior_actions.png")
# Atlas bounds follow each actual generated pose, including sword tips.
const REGIONS = [Rect2(146,26,264,498), Rect2(503,84,451,432), Rect2(1075,11,396,514), Rect2(26,578,584,385), Rect2(646,545,311,422), Rect2(1015,814,505,164)]
const ANCHORS = [Vector2(280,521), Vector2(785,513), Vector2(1260,522), Vector2(300,960), Vector2(800,964), Vector2(1250,975)]
var _pose := 0
var _travel := Vector2.ZERO
var _returning := false
var _travel_tween: Tween
var accent: Color = Color("66c8ff")
var faces_right := true
var active := false
var defeated := false
var is_main := false
var _heal_flash := 0.0
var unit_type := "Warrior"
var guarding := false
var stunned := false
var acting := false
var targeted := false
var _offset := 0.0
var _flash := 0.0
var _slash := 0.0
var _skill_hit := false
var _fall := 0.0
var _clock := 0.0
var _motion: Tween
var _effects: Array[Tween] = []

func _ready() -> void:
	custom_minimum_size = Vector2(260, 260)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()

func _draw() -> void:
	var ground := Vector2(size.x * 0.5, size.y - 12.0) + _travel
	var factor := minf(1.0, size.y / 240.0)
	_draw_shadow(ground, Vector2(65, 12) * factor, Color(0, 0, 0, 0.4))
	var ring_color := Color("ffd66b") if acting else (Color("ff6655") if targeted else accent)
	_draw_shadow(ground, Vector2(56, 9) * factor, Color(ring_color, 0.45 if acting or targeted else 0.12))
	if (active or acting or targeted) and not defeated:
		draw_arc(ground, 48 * factor, 0, TAU, 48, ring_color, 3.0 if acting or targeted else 1.0, true)
	var height := size.y - 18.0
	var scale_factor := height / 494.0
	var region: Rect2 = REGIONS[_pose]
	var anchor: Vector2 = ANCHORS[_pose]
	var draw_position := (region.position - anchor) * scale_factor
	var bob := sin(_clock * (20.0 if _pose == 1 else 2.6)) * (2.2 if _pose == 1 else 0.8) if not defeated else 0.0
	var direction := 1.0 if faces_right else -1.0
	if _returning:
		direction = -direction
	var type_color: Color = {"Warrior":Color("e4f0ff"),"Soldier":Color("fff0b0"),"Destroyer":Color("bbdbff"),"Ranger":Color("b3ffb3"),"Piercer":Color("e0b9ff"),"Devastator":Color("ffb8a8")}.get(unit_type,Color.WHITE)
	var tint := type_color.lerp(Color(1.0, 0.3, 0.2), _flash)
	tint = tint.lerp(Color(0.65, 0.65, 0.65, 0.6), _fall)
	draw_set_transform(ground + Vector2(_offset, bob), 0.0, Vector2(direction, 1.0))
	draw_texture_rect_region(SHEET, Rect2(draw_position, region.size * scale_factor), region, tint)
	draw_set_transform(Vector2.ZERO)

	if _heal_flash > 0.0:
		draw_arc(ground+Vector2(0,-height*0.4),height*0.35,0,TAU,32,Color(0.3,1.0,0.5,_heal_flash),3,true)
	if not defeated and unit_type == "Devastator":
		var cannon := ground + Vector2(0,-height*0.25)
		draw_circle(cannon+Vector2(-height*0.16,8),height*0.12,Color("292b32"))
		draw_circle(cannon+Vector2(height*0.16,8),height*0.12,Color("292b32"))
		draw_line(cannon,cannon+Vector2((1 if faces_right else -1)*height*0.45,-height*0.10),Color("66564a"),height*0.18,true)
	if not defeated and unit_type == "Ranger":
		draw_arc(ground+Vector2((1 if faces_right else -1)*height*0.22,-height*0.45),height*0.28,-PI/2,PI/2,16,Color("8d6e48"),2.5,true)
	if stunned and not defeated:
		for star in range(3):
			var angle := _clock * 2.0 + star * TAU / 3.0
			draw_circle(ground + Vector2(cos(angle) * 15.0, -height + sin(angle) * 4.0), 3.0, Color("ffd66b"))
	if guarding and not defeated:
		var shield := ground + Vector2(0, -height * 0.45)
		draw_arc(shield, height * 0.38, 0, TAU, 40, Color(0.3, 0.85, 1.0, 0.8), 3.0, true)
		draw_line(shield + Vector2(-6, 0), shield + Vector2(6, 0), Color("70dfff"), 2.0)
	if is_main and not defeated:
		var crown := ground + Vector2(0, -height + 2)
		draw_colored_polygon(PackedVector2Array([crown + Vector2(-8, 0), crown + Vector2(-8, -6), crown + Vector2(-3, -3), crown + Vector2(0, -9), crown + Vector2(3, -3), crown + Vector2(8, -6), crown + Vector2(8, 0)]), Color("ffd66b"))
	if acting and not defeated:
		var tip := Vector2(size.x * 0.5, 3) + _travel
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-6, -8), tip + Vector2(6, -8)]), Color("ffd66b"))
	if targeted:
		var center := ground + Vector2(0, -height * 0.5)
		draw_arc(center, height * 0.32, -0.7, 0.7, 16, Color("ff7863"), 2.0, true)
		draw_arc(center, height * 0.32, PI - 0.7, PI + 0.7, 16, Color("ff7863"), 2.0, true)
	if _slash > 0.0:
		var center := ground + Vector2(0, -height * 0.5)
		var radius := height * 0.35
		if _skill_hit:
			draw_arc(center, radius * (1.0 + (1.0 - _slash) * 0.4), 0, TAU, 40, Color(0.6, 0.5, 1.0, _slash), 3.0, true)
		draw_line(center + Vector2(-radius, radius), center + Vector2(radius, -radius), Color(0.5, 0.55, 1.0, _slash) if _skill_hit else Color(1, 0.82, 0.3, _slash), 6.0, true)
		draw_line(center + Vector2(-radius, radius), center + Vector2(radius, -radius), Color(1, 1, 0.9, _slash), 2.0, true)
		for i in range(6):
			var angle := TAU * i / 6.0
			var ray := Vector2(cos(angle), sin(angle))
			draw_line(center + ray * 5, center + ray * (8 + (1.0 - _slash) * 16), Color(1, 0.9, 0.55, _slash), 2.0, true)

func _draw_shadow(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(48):
		var angle: float = TAU * index / 48.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)

func set_state(is_active: bool, is_defeated: bool) -> void:
	active = is_active
	if is_defeated and not defeated:
		var tween := create_tween()
		_effects.append(tween)
		tween.tween_property(self, "_fall", 1.0, 0.4)
	defeated = is_defeated
	if defeated:
		_pose = 5

func set_focus(is_acting: bool, is_targeted: bool) -> void:
	acting = is_acting
	targeted = is_targeted

func reset_animation() -> void:
	if is_instance_valid(_travel_tween):
		_travel_tween.kill()
	_travel = Vector2.ZERO
	_returning = false
	_pose = 0
	guarding = false
	_heal_flash = 0.0
	for fx in get_children():
		if fx is Node2D:
			fx.queue_free()
	z_index = 0
	if is_instance_valid(_motion):
		_motion.kill()
	for tween in _effects:
		if is_instance_valid(tween):
			tween.kill()
	_effects.clear()
	for child in get_children():
		if child is Label:
			remove_child(child)
			child.queue_free()
	_offset = 0.0
	_flash = 0.0
	_slash = 0.0
	_fall = 0.0
	defeated = false
	acting = false
	targeted = false

func approach(target: Control, speed: float) -> float:
	var direction := 1.0 if faces_right else -1.0
	var origin := global_position + Vector2(size.x * 0.5, size.y - 12.0)
	var destination := target.global_position + Vector2(target.size.x * 0.5, target.size.y - 12.0)
	var offset := destination - origin - Vector2(direction * 58.0, 0)
	var duration := clampf(offset.length() / 1100.0, 0.24, 0.55) * speed
	_pose = 1
	_returning = false
	z_index = 20
	if speed <= 0.0:
		_travel = offset
	else:
		_travel_tween = create_tween()
		_travel_tween.tween_property(self, "_travel", offset, duration).set_trans(Tween.TRANS_SINE)
	return duration

func animate_attack(speed: float = 1.0) -> void:
	_pose = 2
	if is_instance_valid(_motion):
		_motion.kill()
	if speed <= 0.0:
		_pose = 3
		return
	_motion = create_tween()
	_motion.tween_interval(0.2 * speed)
	_motion.tween_callback(func() -> void: _pose = 3)

func return_home(speed: float) -> float:
	var duration := clampf(_travel.length() / 1300.0, 0.2, 0.45) * speed
	_pose = 1
	_returning = true
	if speed <= 0.0:
		_travel = Vector2.ZERO
		finish_return()
	else:
		_travel_tween = create_tween()
		_travel_tween.tween_property(self, "_travel", Vector2.ZERO, duration).set_trans(Tween.TRANS_SINE)
	return duration

func finish_return() -> void:
	_travel = Vector2.ZERO
	_returning = false
	_pose = 5 if defeated else 0
	z_index = 0

func animate_hit(damage: float = 0.0, is_skill: bool = false) -> void:
	_pose = 4
	_skill_hit = is_skill
	_effects = _effects.filter(func(effect: Tween) -> bool: return is_instance_valid(effect) and effect.is_running())
	var recovery := create_tween()
	_effects.append(recovery)
	recovery.tween_interval(0.34)
	recovery.tween_callback(func() -> void: _pose = 5 if defeated else 0)
	_flash = 1.0
	_slash = 1.0
	var tween := create_tween().set_parallel(true)
	_effects.append(tween)
	tween.tween_property(self, "_flash", 0.0, 0.28)
	tween.tween_property(self, "_slash", 0.0, 0.32)
	if damage <= 0.0:
		return
	var text := Label.new()
	text.text = "-%.0f" % damage
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.add_theme_font_size_override("font_size", 23)
	text.add_theme_color_override("font_color", Color("bab5ff") if is_skill else Color("ffdf88"))
	text.add_theme_color_override("font_outline_color", Color("20130c"))
	text.add_theme_constant_override("outline_size", 5)
	text.position = Vector2(size.x * 0.5 - 55, size.y * 0.28)
	text.size.x = 110
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.z_index = 10
	add_child(text)
	var popup := create_tween().set_parallel(true)
	_effects.append(popup)
	popup.tween_property(text, "position:y", text.position.y - 24, 0.55)
	popup.tween_property(text, "modulate:a", 0.0, 0.3).set_delay(0.25)
	popup.chain().tween_callback(text.queue_free)

func animate_heal(amount: float) -> void:
	_heal_flash = 1.0
	var glow := create_tween()
	_effects.append(glow)
	glow.tween_property(self,"_heal_flash",0.0,0.6)
	var popup := Label.new()
	popup.text = "+%.0f" % amount
	popup.position = Vector2(size.x*0.5-45,size.y*0.2)
	popup.add_theme_font_size_override("font_size",20)
	popup.add_theme_color_override("font_color",Color("7affab"))
	popup.add_theme_color_override("font_outline_color",Color("102a16"))
	popup.add_theme_constant_override("outline_size",4)
	popup.z_index = 25
	add_child(popup)
	var tween := create_tween().set_parallel(true)
	_effects.append(tween)
	tween.tween_property(popup,"position:y",popup.position.y-20,0.55)
	tween.tween_property(popup,"modulate:a",0.0,0.5)
	tween.chain().tween_callback(popup.queue_free)

func fire_at(target: Control, spell: bool, speed: float) -> void:
	if speed <= 0:
		return
	var start := Vector2(size.x*0.5,size.y*0.55)
	var end := target.global_position+Vector2(target.size.x*0.5,target.size.y*0.55)-global_position
	var bolt := Node2D.new()
	bolt.position = start
	bolt.z_index = 26
	var line := Line2D.new()
	line.width = 5.0 if spell or unit_type == "Devastator" else 2.5
	line.default_color = Color("c4a5ff") if spell else (Color("ffb65e") if unit_type == "Devastator" else Color("edffb4"))
	line.points = PackedVector2Array([Vector2.ZERO,(start-end).normalized()*20])
	bolt.add_child(line)
	add_child(bolt)
	var tween := create_tween()
	_effects.append(tween)
	tween.tween_property(bolt,"position",end,0.20*speed)
	tween.tween_callback(bolt.queue_free)
