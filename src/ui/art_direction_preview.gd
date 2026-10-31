extends Control
## Composition validation only. No combat state or gameplay data is changed.
const GROUND = preload("res://assets/art_direction/v1/stone_citadel_draft.png")
const NAPOLEON = preload("res://assets/art_direction/v1/napoleon_cel_draft.png")
const OLD_SHEET = preload("res://assets/characters/warrior_actions.png")
var _actors: Array[Dictionary] = []
var _roster: Array = []
var _scale_factor := 1.05
var _solo := false
var _size_label: Label
var _atlas: AtlasTexture

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_roster = JSON.parse_string(FileAccess.get_file_as_string("res://data/gameplay/mixed_9v9.json")).roster
	_atlas = AtlasTexture.new()
	_atlas.atlas = NAPOLEON
	_atlas.region = Rect2(NAPOLEON.get_image().get_used_rect())
	var background := TextureRect.new()
	background.texture = GROUND
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	for side in ["A","B"]:
		for i in range(9):
			_add_actor(side,i)
	_build_toolbar()
	_apply_scale()

func _add_actor(side: String, index: int) -> void:
	var entry: Dictionary = _roster[index]
	var napoleon: bool = entry.type == "Devastator"
	var root := Node2D.new()
	var lane := index % 3
	var depth := floori(index / 3.0)
	root.position = Vector2(490-depth*153 if side == "A" else 790+depth*153, 365+lane*170)
	root.z_index = int(root.position.y)
	add_child(root)
	var shadow := Polygon2D.new()
	var points := PackedVector2Array()
	for point in range(48):
		var angle := TAU*point/48.0
		points.append(Vector2(cos(angle)*32,sin(angle)*8))
	shadow.polygon = points
	shadow.color = Color(0.16,0.16,0.18,0.20)
	root.add_child(shadow)
	var ring := Line2D.new()
	ring.width = 1.5
	ring.default_color = Color(0.15,0.50,0.88,0.65) if side == "A" else Color(0.85,0.28,0.23,0.65)
	var outline := points.duplicate()
	outline.append(points[0])
	ring.points = outline
	root.add_child(ring)
	var figure := Node2D.new()
	figure.scale.x = -1 if side == "A" and napoleon else 1
	root.add_child(figure)
	var sprite := Sprite2D.new()
	sprite.centered = false
	if napoleon:
		sprite.texture = _atlas
	else:
		var old := AtlasTexture.new()
		old.atlas = OLD_SHEET
		old.region = Rect2(146,26,264,498)
		sprite.texture = old
		sprite.flip_h = side == "B"
		sprite.modulate = Color(0.68,0.72,0.78,0.72)
	figure.add_child(sprite)
	var label := _label("%s%d %s%s" % [side,index+1,"Napoleon" if napoleon else ("Joan" if entry.type == "Warrior" else ("Bluetooth" if entry.type == "Destroyer" else entry.name.split(" ")[0])), " · MAIN" if index == 4 else ""],12)
	label.position = Vector2(-85,9)
	label.size.x = 170
	root.add_child(label)
	var bar := ColorRect.new()
	bar.position = Vector2(-36,4)
	bar.size = Vector2(72,4)
	bar.color = Color("42b9ef") if side == "A" else Color("ed7263")
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)
	var tag := _label("MAIN" if index == 4 else ("STYLE 1" if napoleon else "PLACEHOLDER"),10)
	tag.visible = false
	tag.modulate = Color("ffe395") if index == 4 else (Color("ffebaf") if napoleon else Color(0.70,0.76,0.81))
	tag.size.x = 160
	root.add_child(tag)
	_actors.append({"root":root,"sprite":sprite,"napoleon":napoleon,"tag":tag,"index":index,"side":side})

func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color.WHITE)
	label.add_theme_color_override("font_outline_color",Color(0.10,0.15,0.20,0.95))
	label.add_theme_constant_override("outline_size",3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _build_toolbar() -> void:
	var top := PanelContainer.new()
	top.z_index = 2000
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 72
	add_child(top)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035,0.065,0.12,0.94)
	style.content_margin_left = 20
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	top.add_theme_stylebox_override("panel",style)
	var column := VBoxContainer.new()
	top.add_child(column)
	column.add_child(_label("AVATAR WAR · ART PREVIEW · Stone Citadel A + Napoleon Anime 1",20))
	column.add_child(_label("4 Napoleon mới / 18 vị trí — các nhân vật còn lại là mẫu cũ để so tỷ lệ",13))
	var bottom := PanelContainer.new()
	bottom.z_index = 2000
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -80
	bottom.add_theme_stylebox_override("panel",style)
	add_child(bottom)
	var stack := VBoxContainer.new()
	bottom.add_child(stack)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	stack.add_child(row)
	_size_label = _label("",14)
	_size_label.custom_minimum_size.x = 150
	row.add_child(_size_label)
	var slider := HSlider.new()
	slider.min_value = 0.8
	slider.max_value = 1.25
	slider.step = 0.05
	slider.value = 1.05
	slider.custom_minimum_size = Vector2(190,30)
	slider.value_changed.connect(func(value: float) -> void: _scale_factor=value; _apply_scale())
	row.add_child(slider)
	var solo := CheckButton.new()
	solo.text = "Chỉ xem Napoleon"
	solo.toggled.connect(func(value: bool) -> void: _solo=value; _apply_scale())
	row.add_child(solo)
	var closeup := Button.new()
	closeup.text = "Xem gần"
	closeup.pressed.connect(_show_closeup)
	row.add_child(closeup)
	var back := Button.new()
	back.text = "Về trận test"
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://src/ui/main.tscn"))
	row.add_child(back)
	stack.add_child(_label("Đang kiểm tra hình ảnh tĩnh, tỷ lệ và phối cảnh. Chưa có animation bắn mới hoặc thay đổi combat.",12))

func _apply_scale() -> void:
	for actor in _actors:
		var sprite: Sprite2D = actor.sprite
		var height := (150.0 if actor.napoleon else 126.0)*_scale_factor
		var texture_size: Vector2 = sprite.texture.get_size()
		var factor := height/texture_size.y
		sprite.scale = Vector2.ONE*factor
		var pivot := 0.68 if actor.napoleon else 0.5
		sprite.position = Vector2(-texture_size.x*factor*pivot,-height*(0.970 if actor.napoleon else 1.0))
		actor.tag.position = Vector2(-80,-height-22)
		actor.root.visible = actor.napoleon or not _solo
	if is_instance_valid(_size_label):
		_size_label.text = "Tỷ lệ: %d%%" % roundi(_scale_factor*100)

func _show_closeup() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Napoleon · Anime 1 · Static draft"
	var texture := TextureRect.new()
	texture.texture = _atlas
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture.custom_minimum_size = Vector2(400,550)
	dialog.add_child(texture)
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(520,680))

