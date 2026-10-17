extends Control
## Procedural placeholder art; can be replaced without changing combat rules.

var accent: Color = Color("66c8ff")
var faces_right: bool = true
var active: bool = false
var defeated: bool = false
var _offset: float = 0.0
var _flash: float = 0.0
var _motion: Tween


func _ready() -> void:
	custom_minimum_size = Vector2(260, 190)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var center := Vector2(size.x * 0.5 + _offset, size.y * 0.5)
	var tint: Color = accent.darkened(0.65) if defeated else accent
	tint = tint.lerp(Color.WHITE, _flash)
	_draw_shadow(center + Vector2(0, 70), Vector2(68, 13), Color(0.0, 0.0, 0.0, 0.35))
	if active and not defeated:
		draw_arc(center + Vector2(0, 66), 65, 0, TAU, 64, Color(accent, 0.8), 3.0, true)
	var body := Rect2(center + Vector2(-30, -15), Vector2(60, 75))
	draw_style_box(_body_style(tint), body)
	draw_circle(center + Vector2(0, -43), 25, tint, true, -1, true)
	draw_circle(center + Vector2(0, -43), 19, tint.lightened(0.15), true, -1, true)
	var eye_x: float = 9.0 if faces_right else -9.0
	draw_circle(center + Vector2(eye_x, -46), 3, Color("102238"), true, -1, true)
	draw_line(center + Vector2(-17, 60), center + Vector2(-22, 72), tint, 12.0, true)
	draw_line(center + Vector2(17, 60), center + Vector2(22, 72), tint, 12.0, true)
	draw_line(center + Vector2(-30, 0), center + Vector2(-45, 30), tint, 11.0, true)
	draw_line(center + Vector2(30, 0), center + Vector2(45, 30), tint, 11.0, true)
	draw_circle(center + Vector2(0, 13), 9, Color("102238"), true, -1, true)
	draw_circle(center + Vector2(0, 13), 4, Color.WHITE, true, -1, true)


func _draw_shadow(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(48):
		var angle: float = TAU * index / 48.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)


func _body_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(16)
	return style


func set_state(is_active: bool, is_defeated: bool) -> void:
	active = is_active
	defeated = is_defeated
	queue_redraw()


func animate_attack() -> void:
	if is_instance_valid(_motion):
		_motion.kill()
	var direction: float = 1.0 if faces_right else -1.0
	_motion = create_tween()
	_motion.tween_method(_set_offset, 0.0, direction * 32.0, 0.12).set_trans(Tween.TRANS_QUAD)
	_motion.tween_method(_set_offset, direction * 32.0, 0.0, 0.18)


func animate_hit() -> void:
	var tween := create_tween()
	tween.tween_method(_set_flash, 1.0, 0.0, 0.3)


func _set_offset(value: float) -> void:
	_offset = value
	queue_redraw()


func _set_flash(value: float) -> void:
	_flash = value
	queue_redraw()
