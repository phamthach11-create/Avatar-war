extends "res://src/combat/sword_battle.gd"
## Mixed roster uses the existing battle state, seeded RNG and Godot presentation.
const Dummy = preload("res://src/combat/sword_battle.gd")
var scenario: Dictionary
var skill_mode := true
var timeline: Array[Dictionary] = []
var _cast_count := 0

static func load_mixed_config() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/gameplay/mixed_9v9.json"))

func _init(config: Dictionary, first: String = "A", seed_value: int = 42, enable_skills: bool = true) -> void:
	super(Dummy.load_config(), first, seed_value, false)
	scenario = config.duplicate(true)
	skill_mode = enable_skills
	for side in ["A", "B"]:
		teams[side] = []
		for entry in scenario.roster:
			var u: Dictionary = entry.duplicate(true)
			u.merge({"hp": u.max_hp, "mp": u.max_mp, "ap": 0.0, "main": u.index == scenario.main_index, "stun_count": 0, "last_stack_turn": -10, "stunned_until": 0, "has_slot": false, "defending": false, "defend_until": 0, "remaining_cooldown": 0, "skill_level": 5, "statuses": [], "damage_done": 0.0, "side": side, "attack_effectiveness": 1.0, "attack_mod": 0.0, "def_mod": 0.0, "sdef_mod": 0.0, "ha_bonus": 0.0}, true)
			_apply_build(u)
			for name in u.skills:
				u.skills[name]["remaining"] = u.skills[name].cd
			teams[side].append(u)

func _apply_build(u: Dictionary) -> void:
	var nodes: Array = u.nodes
	match u.type:
		"Warrior":
			u.ap_recovery += 8
			u.character_ap_recovery += 8
			u.def_mod += 0.65
			u.max_hp += 4000
			u.sdef_mod += 0.27
		"Destroyer":
			u.ap_recovery += 16
			u.character_ap_recovery += 16
			u.attack_effectiveness += 0.20
			u.skills["Deadly Strike"].mp -= 2500
			u.skills["Deadly Strike"].ap -= 15
		"Soldier":
			if nodes.has("S1"):
				u.def_mod += 0.58
				u.multi_hit_rate += 0.23
				u.ap_recovery += 8
				u.character_ap_recovery += 8
			else:
				u.attack_mod += 0.20
				u.ha_bonus += 0.15
				u.stun_threshold += 2
		"Ranger":
			u.skills["Thief’s Mark"].mp *= 0.51
		"Piercer":
			u.skill_points += 4
		"Devastator":
			u.attack_mod += 0.20
			u.skills["Imperial Decree"].ap -= 80
			if nodes.has("S2.2.1"):
				u.ap_recovery += 8
				u.character_ap_recovery += 8
			if nodes.has("S2.2.2"):
				u.critical_chance += 0.23
	u.hp = u.max_hp
	u.mp = u.max_mp
	var spent := 0
	for value in u.levels.values():
		spent += int(value)
	assert(spent <= u.skill_points, "Build exceeds SP budget")
	assert(u.nodes.size() <= 6, "Build exceeds passive budget")

func _enemy(side: String) -> String:
	return "B" if side == "A" else "A"

func _unit(side: String, index: int) -> Dictionary:
	return teams[side][index]

func _alive(side: String) -> Array[int]:
	var result: Array[int] = []
	for u in teams[side]:
		if u.hp > 0:
			result.append(u.index)
	return result

func _has(u: Dictionary, tag: String) -> bool:
	for effect in u.statuses:
		if effect.tag == tag:
			return true
	return false

func _sum(u: Dictionary, key: String) -> float:
	var amount := 0.0
	for effect in u.statuses:
		amount += float(effect.get(key, 0.0))
	return amount

func _blocked(u: Dictionary) -> bool:
	return u.hp <= 0 or is_stunned(u.side, u.index) or _has(u, "immobilized")

func _effect(u: Dictionary, tag: String, duration: int, data: Dictionary, caster: Dictionary) -> void:
	if u.hp <= 0:
		return
	var effect: Dictionary = data.duplicate(true)
	effect.merge({"tag": tag, "expires": global_turn + duration, "creator_side": caster.side, "creator": caster.index, "applied": global_turn}, true)
	# Reapplication by the same source refreshes the effect, rather than stacking it.
	for i in range(u.statuses.size() - 1, -1, -1):
		var old: Dictionary = u.statuses[i]
		if old.tag == tag and old.creator_side == caster.side and old.creator == caster.index:
			u.statuses.remove_at(i)
	u.statuses.append(effect)

func add_stun_count(side: String, index: int, amount: int) -> void:
	var u := _unit(side,index)
	if amount <= 0 or u.hp <= 0 or is_stunned(side,index) or _has(u,"immunity") or u.last_stack_turn == global_turn:
		return
	u.stun_count += mini(1,amount)
	u.last_stack_turn = global_turn
	if u.stun_count >= u.stun_threshold:
		u.stun_count = 0
		u.stunned_until = global_turn + 3
		u.has_slot = false

func _targets(side: String, front: bool = false, first_two: bool = false) -> Array[int]:
	var result: Array[int] = []
	var exposed: Array[int] = legal_targets(side) if front else _alive(side)
	for index in exposed:
		if not _has(_unit(side,index),"invisible") and (not first_two or index < 6):
			result.append(index)
	return result

func _choose(indices: Array[int], side: String, low_hp: bool = false) -> int:
	if indices.is_empty():
		return -1
	if low_hp:
		var best: int = indices[0]
		for i in indices:
			if _unit(side,i).hp < _unit(side,best).hp:
				best = i
		return best
	return indices[_rng.randi_range(0,indices.size()-1)]

func _area(primary: int, shape: String) -> Array[int]:
	var result: Array[int] = [primary]
	var row: int = primary / 3
	var col: int = primary % 3
	for i in range(9):
		if i == primary:
			continue
		var r: int = i / 3
		var c: int = i % 3
		if (shape == "Row" or shape == "Full Row") and r == row:
			result.append(i)
		elif shape == "Row Adjacent" and r == row and absi(c-col) == 1:
			result.append(i)
		elif shape == "Line Adjacent" and c == col and r == row + 1:
			result.append(i)
		elif shape == "Full Line" and c == col and r > row:
			result.append(i)
		elif shape == "Cross" and absi(c-col)+absi(r-row) == 1:
			result.append(i)
		elif shape == "All":
			result.append(i)
	return result

func _ready_skill(u: Dictionary, name: String) -> bool:
	return skill_mode and u.hp > 0 and int(u.levels.get(name,0)) > 0 and u.skills.has(name) and u.skills[name].remaining == 0 and u.mp >= u.skills[name].mp

func _pay(u: Dictionary, name: String, automatic: bool = false) -> void:
	var skill: Dictionary = u.skills[name]
	u.mp -= skill.mp
	u.ap -= skill.ap
	skill.remaining = skill.cd
	if not automatic:
		u.has_slot = false
	_cast_count += 1

func _record(u: Dictionary, name: String, primary: int, side: String, impacts: Array, kind: String = "skill") -> void:
	timeline.append({"team": u.side, "actor": u.index, "target_team": side, "target": primary, "name": name, "kind": kind, "impacts": impacts.duplicate(true), "state_after": teams.duplicate(true)})

func _impact(side: String, index: int, damage: float, landed: bool = true, critical: bool = false, penetrated: bool = false) -> Dictionary:
	return {"team": side, "target": index, "damage": damage, "landed": landed, "critical": critical, "penetrated": penetrated, "target_state": _unit(side,index).duplicate(true)}

func _check_end() -> void:
	for side in ["A","B"]:
		if _unit(side,scenario.main_index).hp <= 0:
			finished = true
			winner = _enemy(side)
			return

func _take_hp(v: Dictionary, amount: float, source: Dictionary) -> float:
	var real := minf(v.hp,maxf(0,amount))
	v.hp -= real
	source.damage_done += real
	if v.hp <= 0:
		v.has_slot = false
	_check_end()
	return real

func _damage(u: Dictionary, v: Dictionary, power: float, normal: bool, penalty: float = 0.0, force_crit: float = -1.0, counter: bool = false) -> Dictionary:
	if v.hp <= 0:
		return _impact(v.side,v.index,0,false)
	var landed := not normal or _roll(u.accuracy-v.evasion)
	var pen := normal and landed and _roll(u.penetration_chance)
	var crit := landed and _roll(u.critical_chance + _sum(u,"chc_flat") if normal else maxf(0,force_crit))
	var defense: float = v.defense * (1 + v.def_mod + _sum(v,"def_mod")) if normal else (v.skill_defense + _sum(v,"sdef_flat")) * (1 + v.sdef_mod + _sum(v,"sdef_mod"))
	if v.defending:
		defense *= 1.5
	defense = maxf(0,defense)
	var amount: float = power * (1 if pen else 1000/(defense+1000)) * (1+u.critical_damage_bonus if crit else 1.0)
	for mark in v.statuses:
		if mark.tag == "mark" and mark.creator_side == u.side and mark.creator == u.index:
			amount *= 1 + float(mark.vulnerable)
	amount *= 1 - penalty
	var ranged: bool = u.type in ["Ranger","Piercer","Devastator"]
	var phalanx: bool = skill_mode and int(v.levels.get("Phalanx",0)) > 0
	if normal and phalanx and ranged and _roll(0.04*int(v.levels["Phalanx"])):
		amount = 0.0
	if not landed or _has(v,"invincible") or (not normal and _has(v,"immunity")):
		amount = 0
	# Post-mitigation links, if a selected build ever enables them.
	var real := _take_hp(v,amount,u)
	if normal and landed and not finished:
		add_stun_count(v.side,v.index,u.attack_stun_count)
	var hit := _impact(v.side,v.index,real,landed,crit,pen)
	if normal and landed and not ranged and phalanx and not counter and not finished and not _blocked(v) and _roll(0.04*int(v.levels["Phalanx"])):
		hit["counter"] = true
	return hit

func _heal(u: Dictionary, v: Dictionary, value: float) -> Dictionary:
	var amount := minf(v.max_hp-v.hp,maxf(0,value*(1+v.healing_amp+v.ha_bonus))) if v.hp > 0 else 0.0
	v.hp += amount
	return _impact(v.side,v.index,-amount)

func _cleanse_oldest(v: Dictionary) -> void:
	var oldest := 2147483647
	var slot := -1
	for i in range(v.statuses.size()):
		var effect: Dictionary = v.statuses[i]
		if effect.get("negative",false) and int(effect.applied) < oldest:
			oldest = effect.applied
			slot = i
	if is_stunned(v.side,v.index) and v.stunned_until-3 <= oldest:
		v.stunned_until = 0
	elif v.stun_count > 0 and v.last_stack_turn <= oldest:
		v.stun_count = 0
	elif slot >= 0:
		v.statuses.remove_at(slot)

func _normal(u: Dictionary, primary: int, counter: bool = false, coordinated: bool = false) -> void:
	var side := _enemy(u.side)
	if primary < 0 or _blocked(u):
		return
	if not counter:
		u.ap -= 100
	u.has_slot = false if not counter and not coordinated else u.has_slot
	var shape := "Single"
	match u.type:
		"Destroyer": shape = "Row Adjacent"
		"Soldier": shape = "Line Adjacent"
		"Piercer": shape = "Full Line"
		"Devastator": shape = "Cross"
	if counter and u.type in ["Warrior","Destroyer","Soldier"]:
		shape = "Single"
	var recipients := _area(primary,shape)
	var rate := maxf(1.0,u.multi_hit_rate+_sum(u,"mhr_flat"))
	var count := 1 if counter else int(floor(rate)) + int(_roll(rate-floor(rate)))
	for hit_index in range(count):
		if finished or _blocked(u):
			break
		var impacts: Array = []
		var counters: Array[int] = []
		for target in recipients:
			var v := _unit(side,target)
			if finished or v.hp <= 0:
				continue
			var penalty := 0.0 if target == primary else (0.75 if u.type == "Piercer" and target / 3 - primary / 3 > 1 else 0.5)
			var power: float = u.attack * (1+u.attack_mod+_sum(u,"attack_mod")) * u.attack_effectiveness
			var hit := _damage(u,v,power,true,penalty,-1,counter)
			impacts.append(hit)
			if hit.get("counter",false):
				counters.append(target)
		_record(u,"Counterattack" if counter else ("Coordinated attack" if coordinated else "Normal attack · hit %d" % (hit_index+1)),primary,side,impacts,"attack")
		for target in counters:
			if not finished:
				_normal(_unit(side,target),u.index,true)
	if not counter and not coordinated and not finished:
		for decree in u.statuses.duplicate(true):
			if decree.tag != "decree":
				continue
			var napoleon := _unit(decree.creator_side,decree.creator)
			if not _blocked(napoleon) and napoleon.ap >= 100 and _unit(side,primary).hp > 0 and _roll(decree.chance):
				_normal(napoleon,primary,false,true)

func _cast(u: Dictionary, name: String, primary: int, automatic: bool = false) -> void:
	_pay(u,name,automatic)
	var side := _enemy(u.side)
	var skill: Dictionary = u.skills[name]
	var level: int = u.levels[name]
	var impacts: Array = []
	match name:
		"Holy Blade", "Golden Arrow Shot", "Deadly Strike", "God-King Slayer":
			var shape := "Line Adjacent" if name == "Holy Blade" else "Single"
			for target in _area(primary,shape):
				if finished:
					break
				var v := _unit(side,target)
				if v.hp <= 0:
					continue
				var power: float = skill.satk * level / 5.0
				if name == "God-King Slayer":
					power *= 1.26 + (0.5 if v.main else 0.0)
				var hit := _damage(u,v,power,false,0.0 if target == primary else 0.5,0.65 if name == "God-King Slayer" else -1)
				if name == "Holy Blade" and not finished:
					add_stun_count(side,target,1)
				hit.target_state = v.duplicate(true)
				impacts.append(hit)
		"Holy Guard", "Maiden’s Care", "Mona Lisa":
			side = u.side
			var recipients: Array = _alive(side) if name == "Mona Lisa" else [primary]
			for target in recipients:
				var v := _unit(side,target)
				if name == "Holy Guard":
					_effect(v,"immunity",skill.duration,{},u)
				if name == "Maiden’s Care":
					_effect(v,"resistance",skill.duration,{"sdef_flat":u.skill_defense*0.02*level},u)
				if name == "Mona Lisa":
					_cleanse_oldest(v)
				impacts.append(_heal(u,v,skill.satk*level/5.0))
		"Vitruvian Man":
			side = u.side
			for target in _area(primary,"Row"):
				var v := _unit(side,target)
				_effect(v,"precision",skill.duration,{"chc_flat":0.12+0.024*level},u)
				impacts.append(_impact(side,target,0))
		"War Cry", "Frozen Axe", "Crushing Barrage":
			var shape := "Cross" if name == "War Cry" else ("Full Row" if name == "Frozen Axe" else "All")
			for target in _area(primary,shape):
				var v := _unit(side,target)
				if v.hp <= 0 or _has(v,"immunity"):
					continue
				var dot_power := (248.1 if name == "War Cry" else (116.0 if name == "Frozen Axe" else 165.4))*level
				var penalty := 0.5 if name == "War Cry" and target != primary else 0.0
				_effect(v,"dot:"+name,skill.duration,{"power":dot_power,"penalty":penalty,"double_at_one":name == "War Cry","negative":true},u)
				if name == "War Cry":
					_effect(v,"falter",skill.duration,{"mhr_flat":-0.0475*level,"negative":true},u)
				elif name == "Frozen Axe":
					_effect(v,"immobilized",skill.duration,{"negative":true},u)
					v.has_slot = false
				else:
					_effect(v,"sunder",skill.duration,{"def_mod":-0.116*level,"negative":true},u)
				var hit := _damage(u,v,116.0*level,false) if name == "Frozen Axe" else _impact(side,target,0)
				impacts.append(hit)
		"Imperial Decree":
			side = u.side
			var v := _unit(side,primary)
			_effect(v,"decree",skill.duration,{"chance":0.13*level},u)
			v.mp = minf(v.max_mp,v.mp+4000*level)
			impacts.append(_impact(side,primary,0))
		"Thief’s Mark":
			var v := _unit(side,primary)
			if not _has(v,"immunity"):
				_effect(v,"mark",skill.duration,{"vulnerable":(0.03+0.01*level)*1.18,"negative":true},u)
			impacts.append(_impact(side,primary,0))
	_record(u,name,primary,side,impacts)

func _passives(side: String) -> void:
	for u in teams[side]:
		if finished:
			return
		if _ready_skill(u,"Maiden’s Care"):
			_cast(u,"Maiden’s Care",scenario.main_index,true)
		if _ready_skill(u,"Thief’s Mark"):
			var enemies := _targets(_enemy(side))
			enemies.sort_custom(func(a: int,b: int) -> bool: return _unit(_enemy(side),a).damage_done > _unit(_enemy(side),b).damage_done)
			var amount := mini(2,enemies.size())
			if amount > 0:
				_cast(u,"Thief’s Mark",enemies[0],true)
				# Additional-target node shares the same cast costs and cooldown.
				if amount > 1:
					var v := _unit(_enemy(side),enemies[1])
					if not _has(v,"immunity"):
						_effect(v,"mark",1,{"vulnerable":0.08*1.18,"negative":true},u)
					_record(u,"Thief’s Mark · extra target",enemies[1],v.side,[_impact(v.side,v.index,0)])

func _act(u: Dictionary) -> void:
	var side := _enemy(u.side)
	var front := _targets(side,true)
	var any := _targets(side)
	if any.is_empty():
		u.has_slot = false
		return
	for name in ["Holy Guard","Mona Lisa","Vitruvian Man","Imperial Decree","Crushing Barrage","Frozen Axe","War Cry","God-King Slayer","Deadly Strike","Holy Blade","Golden Arrow Shot"]:
		if not _ready_skill(u,name):
			continue
		var target := -1
		if name in ["Holy Guard","Mona Lisa"]:
			var allies := _alive(u.side)
			target = _choose(allies,u.side,true)
			if target < 0 or _unit(u.side,target).hp > _unit(u.side,target).max_hp*0.85:
				continue
		elif name == "Vitruvian Man":
			target = 6
			if _has(_unit(u.side,target),"precision"):
				continue
		elif name == "Imperial Decree":
			for i in _alive(u.side):
				if i != u.index and _unit(u.side,i).type == "Devastator" and not _has(_unit(u.side,i),"decree"):
					target = i
					break
			if target < 0:
				continue
		elif name in ["War Cry","God-King Slayer"]:
			target = _choose(_targets(side,false,true),side,true)
		elif name in ["Frozen Axe","Holy Blade","Deadly Strike"]:
			target = _choose(front,side,true)
		else:
			target = _choose(any,side,true)
		if target >= 0:
			_cast(u,name,target)
			return
	var targets := any if u.type in ["Ranger","Devastator"] else front
	_normal(u,_choose(targets,side,true))

func _end_turn() -> void:
	for side in ["A","B"]:
		for v in teams[side]:
			if finished:
				return
			for effect in v.statuses.duplicate(true):
				if not str(effect.tag).begins_with("dot:") or v.hp <= 0:
					continue
				var source := _unit(effect.creator_side,effect.creator)
				var power: float = effect.power
				if effect.double_at_one and maxf(1.0,v.multi_hit_rate+_sum(v,"mhr_flat")) == 1.0:
					power *= 2
				var hit := _damage(source,v,power,false,effect.penalty)
				_record(source,"DOT · "+str(effect.tag).trim_prefix("dot:"),v.index,side,[hit],"dot")
				if finished:
					return
	for side in ["A","B"]:
		for u in teams[side]:
			u.statuses = u.statuses.filter(func(e: Dictionary) -> bool: return int(e.expires) > global_turn+1)
			if u.stun_count > 0 and global_turn >= u.last_stack_turn+2:
				u.stun_count = 0
			if u.hp > 0:
				for name in u.skills:
					u.skills[name].remaining = maxi(0,int(u.skills[name].remaining)-1)
	_record(_unit("A",0),"End turn · expire effects / recover cooldown",-1,"A",[],"system")

func step() -> Dictionary:
	if finished:
		return {}
	global_turn += 1
	var side: String = _next
	timeline.clear()
	var start: Dictionary = teams.duplicate(true)
	for owner in ["A","B"]:
		for u in teams[owner]:
			u.has_slot = false
	_passives(side)
	for u in teams[side]:
		if u.hp > 0:
			u.ap += u.ap_recovery-u.character_ap_recovery if is_stunned(side,u.index) else u.ap_recovery
	var cap := 2 if global_turn <= 2 else (4 if global_turn <= 4 else 5)
	var eligible: Array[Dictionary] = []
	for u in teams[side]:
		if not _blocked(u) and u.ap >= 100:
			eligible.append({"index":u.index,"ap":u.ap,"tie":_rng.randf()})
	eligible.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.ap > b.ap if a.ap != b.ap else a.tie > b.tie)
	_record(_unit(side,0),"Start turn · AP recovery / action slots",-1,side,[],"system")
	for entry in eligible.slice(0,mini(cap,eligible.size())):
		var u := _unit(side,entry.index)
		u.has_slot = true
	for entry in eligible.slice(0,mini(cap,eligible.size())):
		var u := _unit(side,entry.index)
		if not finished and not _blocked(u) and u.has_slot:
			_act(u)
	if not finished:
		_end_turn()
	if global_turn >= scenario.max_global_turns:
		finished = true
	var result := "Team %s wins" % winner if winner != "" else ("Turn limit" if finished else "Ongoing")
	var event := {"turn":global_turn,"team":side,"enemy":_enemy(side),"turn_start_state":start,"actions":timeline.duplicate(true),"result":result,"slot_limit":cap}
	history.append(event)
	_next = _enemy(side)
	return event

