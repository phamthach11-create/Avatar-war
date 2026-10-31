extends Control
## Isolated presentation sample; it never writes combat HP, AP, cooldown or rules.
const MAP = preload("res://assets/art_direction/v1/stone_citadel_draft.png")
const POSES = preload("res://assets/art_direction/firing_v1/commander-poses.png")
const PARTS = preload("res://assets/art_direction/firing_v1/cannon-parts.png")
const IMPACT = preload("res://assets/art_direction/firing_v1/impact-atlas.png")
const TARGETS = preload("res://assets/characters/warrior_actions.png")
var _atlas: Dictionary
var _time := 0.0
var _mode := 0
var _running := false
var _loop := true
var _paused := false
var _speed := 1.0
var _sound := true
var _shake_enabled := true
var _recoil := 0.0
var _flash := 0.0
var _shake := 0.0
var _shots_sent := 0
var _ticks_sent := 0
var _arrivals := 0
var _pose := 0
var _projectiles: Array[Dictionary] = []
var _bursts: Array[Dictionary] = []
var _particles: Array[Dictionary] = []
var _hits := {}
var _scorches: Array[Vector2] = []
var _events: Array[Dictionary] = []
var _phase: Label
var _gun: AudioStreamPlayer
var _boom: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
var _debuff := false
var _zoom := 1.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_atlas = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art_direction/firing_v1/atlas.json"))
	_rng.seed = 58
	_gun = _audio("res://assets/art_direction/firing_v1/cannon-shot.wav",-13)
	_boom = _audio("res://assets/art_direction/firing_v1/ground-impact.wav",-16)
	_build_ui()
	_start(0)

func _audio(path: String, volume: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = load(path)
	player.volume_db = volume
	add_child(player)
	return player

func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_bottom = 78
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025,0.045,0.09,0.95)
	style.content_margin_left = 18
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var title := Label.new()
	title.text = "NAPOLEON · FIRING SAMPLE · Anime 1 · 105%"
	title.add_theme_font_size_override("font_size",22)
	column.add_child(title)
	_phase = Label.new()
	column.add_child(_phase)
	var bottom := PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -87
	bottom.add_theme_stylebox_override("panel",style)
	add_child(bottom)
	var stack := VBoxContainer.new()
	bottom.add_child(stack)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	stack.add_child(row)
	for item in [["Bắn thường",func() -> void: _start(0)],["Barrage / DOT",func() -> void: _start(1)],["Dừng / Tiếp",func() -> void: _paused=not _paused; _gun.stop(); _boom.stop()]]:
		var button := Button.new()
		button.text = item[0]
		button.pressed.connect(item[1])
		row.add_child(button)
	var speed := OptionButton.new()
	speed.add_item("1x")
	speed.add_item("Chậm 0.5x")
	speed.item_selected.connect(func(i: int) -> void: _speed=1.0 if i==0 else 0.5)
	row.add_child(speed)
	for item in [["Lặp",true,func(v: bool) -> void: _loop=v],["Âm thanh",true,func(v: bool) -> void: _sound=v; _gun.stop(); _boom.stop()],["Rung",true,func(v: bool) -> void: _shake_enabled=v]]:
		var toggle := CheckButton.new()
		toggle.text = item[0]
		toggle.button_pressed = item[1]
		toggle.toggled.connect(item[2])
		row.add_child(toggle)
	var zoom := CheckButton.new()
	zoom.text = "Cận cảnh"
	zoom.toggled.connect(func(v: bool) -> void: _zoom=1.35 if v else 1.0)
	row.add_child(zoom)
	var back := Button.new()
	back.text = "Về bố cục 9vs9"
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://src/ui/art_direction_preview.tscn"))
	row.add_child(back)
	var note := Label.new()
	note.text = "Scene VFX riêng, chưa gắn combat. Barrage chỉ áp Sunder/DOT; 6 nhịp DOT được tua nhanh để xem hiệu ứng."
	note.add_theme_font_size_override("font_size",12)
	stack.add_child(note)

func _start(mode: int) -> void:
	_mode = mode
	_time = 0
	_pose = 0
	_shots_sent = 0
	_ticks_sent = 0
	_arrivals = 0
	_recoil = 0
	_flash = 0
	_shake = 0
	_running = true
	_paused = false
	_debuff = false
	_projectiles.clear()
	_bursts.clear()
	_particles.clear()
	_hits.clear()
	_scorches.clear()
	_events.clear()
	_gun.stop()
	_boom.stop()
	_phase.text = "Chuẩn bị · lấy đà ra lệnh"
	queue_redraw()

func _process(delta: float) -> void:
	if _paused:
		return
	var dt := delta*_speed
	_advance(dt)
	queue_redraw()

func _advance(dt: float) -> void:
	_recoil = maxf(0,_recoil-dt*3)
	_flash = maxf(0,_flash-dt*7)
	_shake = maxf(0,_shake-dt*14)
	for key in _hits.keys():
		_hits[key] = maxf(0,_hits[key]-dt)
	for particle in _particles:
		particle.age += dt
		particle.p += particle.v*dt
		particle.v.y += (70 if particle.smoke else 180)*dt
	_particles = _particles.filter(func(p: Dictionary) -> bool: return p.age<p.life)
	for burst in _bursts:
		burst.age += dt
	_bursts = _bursts.filter(func(b: Dictionary) -> bool: return b.age<1.15)
	if not _running:
		return
	_time += dt
	_pose = 0 if _time<0.25 or _time>1.75 else (1 if _time<0.68 else (2 if _time<1.15 else 3))
	var total := 1 if _mode==0 else 3
	while _shots_sent<total and _time>=0.72+_shots_sent*0.28:
		_launch(4 if _mode==0 else [0,4,8][_shots_sent])
		_shots_sent += 1
	for shot in _projectiles.duplicate():
		shot.age += dt
		if shot.age>=shot.duration:
			_arrive(shot.target)
			_projectiles.erase(shot)
	if _mode==1 and _arrivals==3:
		while _ticks_sent<6 and _time>=2.2+_ticks_sent*0.55:
			_dot_tick()
			_ticks_sent += 1
	var end := 3.7 if _mode==0 else 6.9
	if _time>=end:
		_debuff = false
		if _loop:
			_start(_mode)
		else:
			_running = false
			_phase.text = "Hoàn tất · bấm Bắn thường hoặc Barrage để xem lại"

func _target(index: int) -> Vector2:
	return Vector2(840+(index%3)*116,430+floori(index/3.0)*118)

func _launch(target: int) -> void:
	_recoil = 1
	_flash = 1
	var start := Vector2(442,526)
	_projectiles.append({"start":start,"end":_target(target)-Vector2(0,40),"age":0.0,"duration":0.56,"target":target})
	_events.append({"kind":"fire","time":_time,"target":target})
	_spawn_particles(start,14,true)
	if _sound:
		_gun.play()
	_phase.text = "Khai hỏa · nòng giật lùi · đạn đang bay"

func _arrive(target: int) -> void:
	_arrivals += 1
	_events.append({"kind":"arrival","time":_time,"target":target})
	if _mode==0:
		_impact(target,168)
		for i in [1,3,4,5,7]:
			_hits[i] = 0.34
		_phase.text = "Đánh thường: mục tiêu chính + vùng Cross · phản ứng trúng đòn"
	elif _arrivals==3:
		_debuff = true
		_phase.text = "Barrage áp Sunder + DOT lên 9 mục tiêu · không có sát thương trực tiếp"
		_events.append({"kind":"apply_dot","time":_time})

func _dot_tick() -> void:
	_phase.text = "Cuối Global Turn · DOT tick %d/6 (tua nhanh trong cảnh mẫu)" % (_ticks_sent+1)
	_events.append({"kind":"dot_tick","time":_time,"tick":_ticks_sent+1})
	for i in range(9):
		_hits[i] = 0.25
		_bursts.append({"p":_target(i),"age":0.0,"size":110.0 if _ticks_sent==0 else 66.0})
	if _ticks_sent==0:
		_shake = 3.0
		if _sound:
			_boom.play()

func _impact(target: int, width: float) -> void:
	var p := _target(target)
	_bursts.append({"p":p,"age":0.0,"size":width})
	_scorches.append(p)
	_spawn_particles(p,22,false)
	_shake = 4
	if _sound:
		_boom.play()

func _spawn_particles(pos: Vector2, amount: int, smoke: bool) -> void:
	for i in range(amount):
		_particles.append({"p":pos,"v":Vector2(_rng.randf_range(-45,70),_rng.randf_range(-100,-20)),"age":0.0,"life":_rng.randf_range(0.4,1.3),"radius":_rng.randf_range(4,10) if smoke else _rng.randf_range(1,3),"smoke":smoke})

func _rect(values: Array) -> Rect2:
	return Rect2(values[0],values[1],values[2],values[3])

func _draw() -> void:
	if _atlas.is_empty():
		return
	var offset := Vector2(sin(_time*97),cos(_time*83))*_shake if _shake_enabled else Vector2.ZERO
	draw_set_transform(offset+Vector2(640,480)*(1-_zoom),0,Vector2.ONE*_zoom)
	draw_texture_rect(MAP,Rect2(-10,-10,1300,840),false)
	for p in _scorches:
		_ellipse(p,Vector2(45,10),Color(0.25,0.18,0.12,0.20))
	# Temporary recipients use the existing hurt/idle poses, not new class designs.
	for i in range(9):
		var foot := _target(i)
		_ellipse(foot,Vector2(23,6),Color(0.1,0.1,0.15,0.20))
		var hit: float = _hits.get(i,0.0)
		var region := Rect2(646,545,311,422) if hit>0 else Rect2(146,26,264,498)
		var anchor := Vector2(800,964) if hit>0 else Vector2(280,521)
		var scale := 122.0/494.0
		var tint := Color.WHITE.lerp(Color(1,0.32,0.17),minf(1,hit*3))
		draw_set_transform(offset+Vector2(640,480)*(1-_zoom)+(foot+Vector2(sin(hit*80)*hit*12,0))*_zoom,0,Vector2(-_zoom,_zoom))
		draw_texture_rect_region(TARGETS,Rect2((region.position-anchor)*scale,region.size*scale),region,tint)
		draw_set_transform(offset+Vector2(640,480)*(1-_zoom),0,Vector2.ONE*_zoom)
		draw_line(foot+Vector2(-26,9),foot+Vector2(26,9),Color("ed7d6a"),3)
		if _debuff:
			draw_arc(foot+Vector2(0,-35),28,0,TAU,32,Color(0.65,0.25,0.88,0.65),2,true)
	# Commander uses genuinely different arm/torso drawings with fixed foot anchors.
	var frame: Dictionary = _atlas["commander-poses"].frames[_pose]
	var source := _rect(frame.rect)
	var factor := 157.5/731.0
	var base := Vector2(252,580)
	_ellipse(base,Vector2(25,7),Color(0.1,0.1,0.15,0.22))
	draw_texture_rect_region(POSES,Rect2(base-Vector2(frame.foot[0],frame.foot[1])*factor,source.size*factor),source)
	# Assemble cannon from independent carriage, rotating wheels and sliding barrel.
	var recoil := Vector2(-4*_recoil,0)
	var parts: Array = _atlas["cannon-parts"].frames
	var body := _rect(parts[0].rect)
	var barrel := _rect(parts[1].rect)
	var wheel := _rect(parts[2].rect)
	_ellipse(Vector2(350,580),Vector2(57,9),Color(0.1,0.1,0.15,0.22))
	draw_texture_rect_region(PARTS,Rect2(Vector2(318,533)+recoil,Vector2(80,52)),body)
	for center in [Vector2(376,560),Vector2(331,564)]:
		draw_set_transform(offset+Vector2(640,480)*(1-_zoom)+(center+recoil)*_zoom,_recoil*0.22,Vector2.ONE*_zoom)
		draw_texture_rect_region(PARTS,Rect2(-25,-25,50,50),wheel)
	draw_set_transform(offset+Vector2(640,480)*(1-_zoom),0,Vector2.ONE*_zoom)
	draw_texture_rect_region(PARTS,Rect2(Vector2(332-12*_recoil,508),Vector2(112,38)),barrel)
	if _flash>0.02:
		var muzzle := Vector2(443-12*_recoil,526)
		draw_circle(muzzle,12*_flash,Color(1,0.75,0.15,_flash*0.7))
		var flame := PackedVector2Array([muzzle+Vector2(-2,-5)*_flash,muzzle+Vector2(42*_flash,-18*_flash),muzzle+Vector2(24,-2)*_flash,muzzle+Vector2(63*_flash,0),muzzle+Vector2(25,6)*_flash,muzzle+Vector2(38*_flash,16*_flash),muzzle+Vector2(-2,5)*_flash])
		draw_colored_polygon(flame,Color(1,0.79,0.15,_flash))
		draw_line(muzzle,muzzle+Vector2(36*_flash,0),Color(1,1,0.88,_flash),7*_flash,true)
	for shot in _projectiles:
		var t := clampf(shot.age/shot.duration,0,1)
		var p: Vector2 = shot.start.lerp(shot.end,t)+Vector2(0,-sin(t*PI)*95)
		var prev_t := maxf(0,t-0.045)
		var prev: Vector2 = shot.start.lerp(shot.end,prev_t)+Vector2(0,-sin(prev_t*PI)*95)
		draw_line(prev,p,Color(1,0.46,0.08,0.30),10,true)
		draw_line(prev,p,Color(1,0.82,0.28,0.9),3,true)
		draw_circle(p,4,Color("fff5cf"))
	for particle in _particles:
		var alpha: float = 1.0-particle.age/particle.life
		var color := Color(0.49,0.45,0.39,alpha*0.18) if particle.smoke else Color(1,0.56,0.12,alpha)
		draw_circle(particle.p,particle.radius*(1+particle.age*2),color)
	for burst in _bursts:
		var index := mini(7,int(burst.age/1.15*8))
		var cell: Array = _atlas["impact-atlas"].frames[index].cell
		var ratio: float = burst.size/cell[2]
		var dest := Rect2(burst.p-Vector2(cell[2]*0.5,410)*ratio,Vector2(cell[2],cell[3])*ratio)
		draw_texture_rect_region(IMPACT,dest,_rect(cell),Color(1,1,1,minf(1,(1.15-burst.age)*4)))
		_ellipse(burst.p,Vector2(60,13)*minf(1,burst.age*5),Color(1,0.68,0.22,maxf(0,0.4-burst.age)))
	draw_set_transform(Vector2.ZERO)

func _ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	if radius.x<0.05 or radius.y<0.05 or color.a<=0.005:
		return
	var points := PackedVector2Array()
	for i in range(40):
		points.append(center+Vector2(cos(i*TAU/40)*radius.x,sin(i*TAU/40)*radius.y))
	draw_colored_polygon(points,color)

