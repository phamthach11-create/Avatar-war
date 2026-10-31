extends "res://src/ui/napoleon_firing_preview.gd"
## V2: continuous Bone2D motion and layered continuous VFX, not four swapped poses.
const RIG_ART = preload("res://assets/art_direction/firing_v2/rig-atlas.png")
const GUN_ART = preload("res://assets/art_direction/firing_v2/fieldgun-v3.png")
const FX_ART = preload("res://assets/art_direction/firing_v2/impact-layers.png")
var _v2: Dictionary
var _layers: Array[Node2D] = []
var _skeleton: Skeleton2D
var _torso: Bone2D
var _upper: Bone2D
var _fore: Bone2D
var _cape: Sprite2D
var _fire_age := 100.0
var _motion_clock := 0.0
var _clouds: Array[Dictionary] = []
var _embers: Array[Dictionary] = []
var _fractures: Array[Dictionary] = []
var _fire_nodes: Array[Dictionary] = []
var _muzzle_nodes: Array[Dictionary] = []
var _fire_shader: Shader
var _cloth_shader: Shader

class DrawLayer extends Node2D:
	var host: Control
	var layer_index: int
	func _draw() -> void:
		host.render_layer(self,layer_index)

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_v2 = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art_direction/firing_v2/atlas.json"))
	_fire_shader = Shader.new()
	_fire_shader.code = "shader_type canvas_item; uniform float age=0.0; uniform float opacity=1.0; void fragment(){ vec2 p=UV; float weight=sin(clamp(p.y,0.0,1.0)*3.14159); p.x+=sin(p.y*21.0-age*14.0)*0.018*weight; p.y+=sin(p.x*19.0+age*10.0)*0.008*weight; vec4 c=texture(TEXTURE,clamp(p,vec2(0.002),vec2(0.998))); COLOR=vec4(c.rgb,c.a*opacity)*COLOR; }"
	_cloth_shader = Shader.new()
	_cloth_shader.code = "shader_type canvas_item; uniform float clock=0.0; void vertex(){ VERTEX.x += sin(UV.y*5.0-clock*2.8)*5.0*UV.y*UV.y; }"
	for i in range(6):
		var layer := DrawLayer.new()
		layer.host = self
		layer.layer_index = i
		layer.z_index = i
		add_child(layer)
		_layers.append(layer)
	_build_rig()
	super._ready()
	for node in find_children("*","PanelContainer",true,false):
		node.z_index = 100
	for button in find_children("*","Button",true,false):
		if button.text == "Barrage / DOT":
			button.hide()
	for label in find_children("*","Label",true,false):
		if label.text.begins_with("NAPOLEON"):
			label.text = "NAPOLEON · SHOT V2 · Anime 1 · 105%"
		if label.text.begins_with("Scene VFX"):
			label.text = "Một phát bắn để duyệt: chuyển động liên tục, pháo dài, đường đạn nặng, nổ nhiều lớp và nền nứt vỡ. Chưa ghép combat."

func _region(texture: Texture2D, rect_values: Array) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = _rect(rect_values)
	return atlas

func _bone(parent: Node2D, label: String, position_value: Vector2, bone_length: float) -> Bone2D:
	var bone := Bone2D.new()
	bone.name = label
	bone.position = position_value
	bone.set_autocalculate_length_and_angle(false)
	bone.length = bone_length
	parent.add_child(bone)
	bone.rest = bone.transform
	return bone

func _piece(parent: Node2D, frame: int, height: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = _region(RIG_ART,_v2["rig-atlas"].frames[frame].rect)
	sprite.scale = Vector2.ONE*height/sprite.texture.get_height()
	sprite.centered = false
	parent.add_child(sprite)
	return sprite

func _build_rig() -> void:
	_skeleton = Skeleton2D.new()
	_skeleton.position = Vector2(255,580)
	_layers[2].add_child(_skeleton)
	_torso = _bone(_skeleton,"Body",Vector2.ZERO,100)
	var cape_bone := _bone(_torso,"Cape",Vector2(-16,-128),110)
	_cape = _piece(cape_bone,3,136)
	_cape.position = Vector2(-52,0)
	var material_value := ShaderMaterial.new()
	material_value.shader = _cloth_shader
	_cape.material = material_value
	var body := _piece(_torso,0,157.5)
	body.z_index = 1
	body.position = Vector2(-body.texture.get_width()*body.scale.x*0.50,-157.5)
	_upper = _bone(_torso,"CommandUpperArm",Vector2(-24,-123),32)
	var upper_sprite := _piece(_upper,1,37)
	upper_sprite.position = Vector2(-3,6)
	upper_sprite.rotation = -PI/2
	_fore = _bone(_upper,"CommandForearm",Vector2(31,0),38)
	_fore.z_index = 2
	var fore_sprite := _piece(_fore,2,41)
	fore_sprite.position = Vector2(-4,6)
	fore_sprite.rotation = -PI/2

func _build_ui() -> void:
	super._build_ui()

func _start(mode: int) -> void:
	for fx in _fire_nodes+_muzzle_nodes:
		if is_instance_valid(fx.node):
			fx.node.queue_free()
	_fire_nodes.clear()
	_muzzle_nodes.clear()
	_clouds.clear()
	_embers.clear()
	_fractures.clear()
	_fire_age = 100
	super._start(0)
	_update_rig()

func _smooth(a: float,b: float,t: float) -> float:
	var value := clampf(t,0,1)
	return lerpf(a,b,value*value*(3-2*value))

func _update_rig() -> void:
	if not is_instance_valid(_upper):
		return
	var arm := 1.28
	var fore := 0.08
	if _time>=0.12 and _time<0.61:
		arm = _smooth(1.28,-0.88,(_time-0.12)/0.49)
		fore = _smooth(0.08,-0.65,(_time-0.12)/0.49)
	elif _time>=0.61 and _time<0.78:
		arm = _smooth(-0.88,-0.08,(_time-0.61)/0.17)
		fore = _smooth(-0.65,0.03,(_time-0.61)/0.17)
	elif _time>=0.78 and _time<1.06:
		arm = -0.08
		fore = 0.03
	elif _time>=1.06 and _time<1.85:
		arm = _smooth(-0.08,1.28,(_time-1.06)/0.79)
		fore = _smooth(0.03,0.08,(_time-1.06)/0.79)
	_upper.rotation = arm
	_fore.rotation = fore
	_torso.rotation = -sin(clampf((_time-0.35)/1.25,0,1)*PI)*0.025
	_torso.scale.y = 1+sin(_motion_clock*2.2)*0.0025
	_cape.material.set_shader_parameter("clock",_motion_clock)

func _advance(dt: float) -> void:
	_fire_age += dt
	_motion_clock += dt
	super._advance(dt)
	_update_rig()
	for cloud in _clouds:
		cloud.age += dt
		cloud.p += cloud.v*dt
	_clouds = _clouds.filter(func(c: Dictionary) -> bool: return c.age<c.life)
	for ember in _embers:
		ember.age += dt
		ember.p += ember.v*dt
		ember.v.y += 260*dt
	_embers = _embers.filter(func(e: Dictionary) -> bool: return e.age<e.life)
	for fracture in _fractures:
		fracture.age += dt
	for collection in [_fire_nodes,_muzzle_nodes]:
		for fx in collection.duplicate():
			fx.age += dt
			var t: float = fx.age/fx.life
			if t>=1:
				fx.node.queue_free()
				collection.erase(fx)
				continue
			var grow := 0.25+0.75*minf(1,t/0.16)
			fx.node.scale = fx.base_scale*grow
			fx.node.modulate.a = pow(1-t,0.65)
			fx.node.material.set_shader_parameter("age",fx.age)
	var camera_offset := Vector2(sin(_motion_clock*65),cos(_motion_clock*53))*_shake if _shake_enabled else Vector2.ZERO
	for layer in _layers:
		layer.position = camera_offset+Vector2(640,480)*(1-_zoom)
		layer.scale = Vector2.ONE*_zoom
		layer.queue_redraw()

func _gun_recoil() -> float:
	if _fire_age<0.055:
		return _smooth(0,19,_fire_age/0.055)
	if _fire_age<0.17:
		return 19
	if _fire_age<1.10:
		return _smooth(19,0,(_fire_age-0.17)/0.93)
	return 0

func _muzzle() -> Vector2:
	return Vector2(487-_gun_recoil()*0.78,502)

func _launch(target: int) -> void:
	_fire_age = 0
	_flash = 1
	var start := Vector2(487,502)
	_projectiles.append({"start":start,"end":_target(target)-Vector2(0,24),"age":0.0,"duration":0.68,"target":target})
	_events.append({"kind":"fire","time":_time,"target":target})
	_emit_fire(start,88,0.18,true)
	for i in range(5):
		_clouds.append({"p":start,"v":Vector2(_rng.randf_range(25,60),_rng.randf_range(-25,-5)),"age":0.0,"life":0.9,"size":_rng.randf_range(28,48),"front":false,"type":1,"angle":_rng.randf_range(-0.4,0.4)})
	if _sound:
		_gun.play()
	_phase.text = "Ra lệnh → khai hỏa · cả giá pháo giật lùi · đạn đặc có vệt khí nóng"

func _emit_fire(p: Vector2,width: float,life: float,muzzle: bool = false) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = _region(FX_ART,_v2["impact-layers"].frames[0].rect)
	sprite.position = p
	sprite.offset = Vector2(0,-sprite.texture.get_height()*0.43)
	var scale_value := Vector2.ONE*width/sprite.texture.get_width()
	if muzzle:
		sprite.rotation = PI/2
		scale_value *= Vector2(0.48,0.95)
	sprite.scale = scale_value*0.25
	var material_value := ShaderMaterial.new()
	material_value.shader = _fire_shader
	sprite.material = material_value
	_layers[3].add_child(sprite)
	var data := {"node":sprite,"age":0.0,"life":life,"base_scale":scale_value}
	if muzzle:
		_muzzle_nodes.append(data)
	else:
		_fire_nodes.append(data)

func _impact(target: int, width: float) -> void:
	var point := _target(target)
	_emit_fire(point,155,0.64)
	var paths: Array = []
	for i in range(9):
		var angle := i*TAU/9+_rng.randf_range(-0.18,0.18)
		var length_value := _rng.randf_range(42,92)
		var path := PackedVector2Array([Vector2.ZERO])
		for part in range(1,5):
			var direction := angle+_rng.randf_range(-0.18,0.18)
			path.append(Vector2(cos(direction)*length_value*part/4,sin(direction)*length_value*part/4*0.40))
		paths.append(path)
	_fractures.append({"p":point,"age":0.0,"paths":paths})
	for i in range(13):
		_clouds.append({"p":point+Vector2(_rng.randf_range(-34,34),_rng.randf_range(-18,4)),"v":Vector2(_rng.randf_range(-23,23),_rng.randf_range(-32,-14)),"age":0.0,"life":_rng.randf_range(1.4,2.1),"size":_rng.randf_range(50,92),"front":i>=10,"type":1 if i<7 else 2,"angle":_rng.randf_range(-0.5,0.5)})
	for i in range(36):
		_embers.append({"p":point,"v":Vector2(_rng.randf_range(-125,125),_rng.randf_range(-170,-60)),"age":0.0,"life":_rng.randf_range(0.5,1.1),"size":_rng.randf_range(2,6),"rock":i<22,"angle":_rng.randf()*TAU})
	_shake = 5
	_phase.text = "Va chạm · chớp nóng + lửa + khói hai lớp · đá văng và mặt sân nứt vỡ"
	if _sound:
		_boom.play()

func _draw() -> void:
	var camera_offset := Vector2(sin(_motion_clock*65),cos(_motion_clock*53))*_shake if _shake_enabled else Vector2.ZERO
	draw_set_transform(camera_offset+Vector2(640,480)*(1-_zoom),0,Vector2.ONE*_zoom)
	draw_texture_rect(MAP,Rect2(-10,-10,1300,840),false)
	draw_set_transform(Vector2.ZERO)

func _draw_ellipse(c: CanvasItem, p: Vector2, radius: Vector2, color: Color) -> void:
	if radius.x<0.05 or radius.y<0.05 or color.a<=0.005:
		return
	var polygon := PackedVector2Array()
	for i in range(48):
		polygon.append(p+Vector2(cos(i*TAU/48)*radius.x,sin(i*TAU/48)*radius.y))
	c.draw_colored_polygon(polygon,color)

func render_layer(c: CanvasItem, index: int) -> void:
	if _v2.is_empty():
		return
	match index:
		0: _draw_ground(c)
		1: _draw_clouds(c,false)
		2: _draw_actors(c)
		3: _draw_air(c)
		4: _draw_clouds(c,true)
		5: _draw_debris(c)

func _draw_ground(c: CanvasItem) -> void:
	for fracture in _fractures:
		var growth := minf(1,fracture.age/0.14)
		var rect := _rect(_v2["impact-layers"].frames[3].rect)
		var size_value := Vector2(174,78)*growth
		if growth>0.01:
			c.draw_texture_rect_region(FX_ART,Rect2(fracture.p-size_value*0.5,size_value),rect,Color(1,1,1,0.95))
		for path in fracture.paths:
			for i in range(1,path.size()):
				var t := clampf(growth*4-(i-1),0,1)
				if t<=0:
					continue
				var a: Vector2 = fracture.p+path[i-1]
				var b: Vector2 = fracture.p+path[i-1].lerp(path[i],t)
				c.draw_line(a+Vector2(0,1),b+Vector2(0,1),Color(0.90,0.77,0.58,0.8),3,true)
				c.draw_line(a,b,Color(0.16,0.12,0.10,0.9),1.8,true)
		if fracture.age<0.45:
			var points := PackedVector2Array()
			for i in range(49):
				var angle := i*TAU/48
				points.append(fracture.p+Vector2(cos(angle)*130,sin(angle)*32)*minf(1,fracture.age/0.35))
			if fracture.age>0.01:
				c.draw_polyline(points,Color(0.9,0.73,0.49,(0.45-fracture.age)*0.8),3,true)
	for shot in _projectiles:
		var t: float = clampf(shot.age/shot.duration,0,1)
		_draw_ellipse(c,Vector2(shot.start.x,580).lerp(_target(shot.target),t),Vector2(12,3),Color(0.1,0.1,0.1,0.14))

func _draw_clouds(c: CanvasItem, front: bool) -> void:
	for cloud in _clouds:
		if cloud.front != front:
			continue
		var t: float = cloud.age/cloud.life
		var scale_value: float = cloud.size*(0.40+0.85*sin(t*PI*0.6))
		var opacity: float = sin(minf(1,t/0.1)*PI/2)*pow(1-t,1.2)*(0.28 if front else 0.58)
		var rect := _rect(_v2["impact-layers"].frames[cloud.type].rect)
		var size_value := Vector2(scale_value,scale_value*rect.size.y/rect.size.x)
		var heat := maxf(0,1-cloud.age/0.5)
		var tint := Color(1,0.92-heat*0.13,0.83-heat*0.25,opacity)
		c.draw_set_transform(cloud.p,cloud.angle)
		c.draw_texture_rect_region(FX_ART,Rect2(-size_value*0.5,size_value),rect,tint)
		c.draw_set_transform(Vector2.ZERO)

func _draw_actors(c: CanvasItem) -> void:
	for i in range(9):
		var foot := _target(i)
		_draw_ellipse(c,foot,Vector2(23,6),Color(0.1,0.1,0.15,0.18))
		var hit: float = _hits.get(i,0.0)
		var region := Rect2(646,545,311,422) if hit>0 else Rect2(146,26,264,498)
		var anchor := Vector2(800,964) if hit>0 else Vector2(280,521)
		var factor := 122.0/494.0
		c.draw_set_transform(foot+Vector2(sin(hit*70)*hit*9,0),0,Vector2(-1,1))
		c.draw_texture_rect_region(TARGETS,Rect2((region.position-anchor)*factor,region.size*factor),region,Color.WHITE.lerp(Color(1,0.4,0.25),minf(1,hit*2)))
		c.draw_set_transform(Vector2.ZERO)
		c.draw_line(foot+Vector2(-26,9),foot+Vector2(26,9),Color("ed7d6a"),3)
	_draw_ellipse(c,Vector2(255,580),Vector2(26,7),Color(0.1,0.1,0.15,0.18))
	var recoil := _gun_recoil()*0.78
	_draw_ellipse(c,Vector2(369-recoil,582),Vector2(94,10),Color(0.1,0.1,0.15,0.20))
	c.draw_texture_rect(GUN_ART,Rect2(280-recoil,478,210,105),false)

func _ball_position(shot: Dictionary, t: float) -> Vector2:
	return shot.start.lerp(shot.end,t)+Vector2(0,-4*95*t*(1-t))

func _draw_air(c: CanvasItem) -> void:
	for shot in _projectiles:
		var t := clampf(shot.age/shot.duration,0,1)
		var p := _ball_position(shot,t)
		for i in range(10):
			var a := maxf(0,t-i*0.008)
			var b := maxf(0,t-(i+1)*0.008)
			c.draw_line(_ball_position(shot,a),_ball_position(shot,b),Color(1,0.48+0.025*i,0.09,(1-i/10.0)*0.28),13-i*0.8,true)
		c.draw_line(_ball_position(shot,maxf(0,t-0.025)),p,Color(1,0.86,0.42,0.85),4,true)
		c.draw_circle(p,7,Color("292426"))
		c.draw_circle(p+Vector2(-2,-2),3,Color("c0a47a"))
		c.draw_arc(p,8,-0.3,1.7,18,Color(1,0.56,0.16,0.85),2,true)

func _draw_debris(c: CanvasItem) -> void:
	for piece in _embers:
		var t: float = piece.age/piece.life
		if piece.rock:
			var r: float = piece.size
			c.draw_set_transform(piece.p,piece.angle+piece.age*3)
			c.draw_colored_polygon(PackedVector2Array([Vector2(-r,-r*0.5),Vector2(r*0.6,-r),Vector2(r,r*0.6),Vector2(-r*0.4,r)]),Color(0.41,0.32,0.23,1-t))
			c.draw_line(Vector2(-r,-r*0.5),Vector2(r*0.6,-r),Color(0.85,0.75,0.58,1-t),1.5,true)
			c.draw_set_transform(Vector2.ZERO)
		else:
			c.draw_line(piece.p-piece.v.normalized()*6,piece.p,Color(1,0.62,0.14,1-t),1.7,true)




