extends "res://src/combat/mixed_battle.gd"
var _status_source := ""
var _weapon_presentation_sequence := 0

## Requested 2026-10-31 scenario. Reuses the existing battle state/timeline/UI contract.

static func load_mixed_config() -> Dictionary:
	return load_scenario("requested_9v9")

static func load_scenario(scenario_id: String) -> Dictionary:
	return preload("res://src/design/runtime_catalog.gd").scenario(scenario_id)

func _apply_build(u: Dictionary) -> void:
	var n: Array = u.nodes
	u.merge({"mhr_mod":0.0,"skill_effectiveness":1.0,"sub_penalty":0.5,"automata":[],"summon_attack_effectiveness":1.0,"summon_chc":0.0,"summon_mhr_mod":0.0},true)
	match u.type:
		"Caster":
			preload("res://src/combat/caster_kit.gd").apply_build(u)
			if not skill_mode: u.max_mp = u.mp_without_veil
		"Destroyer":
			if n.has("S1.1.1"): u.ap_recovery += 8; u.character_ap_recovery += 8
			if n.has("S1.2.1"): u.ap_recovery += 8; u.character_ap_recovery += 8
			if n.has("S1.2.2"): u.sub_penalty -= 0.30
			if n.has("S1.2.3"): u.critical_chance += 0.23
			if n.has("S1.2.4"): u.multi_hit_rate += 0.17; u.critical_chance += 0.17; u.critical_damage_bonus += 0.58
		"Warrior":
			if n.has("S1.1.1"): u.ap_recovery += 8; u.character_ap_recovery += 8
			if n.has("S1.2.1"): u.max_hp += 4000
			if n.has("S1.2.2"): u.sdef_mod += 0.27
			if n.has("S1.2.3"): u.max_mp += 20000
		"Soldier":
			if n.has("S1.1.1") or n.has("S2.2.1"): u.def_mod += 0.58
			if n.has("S1.2.1"): u.accuracy += 0.10; u.critical_chance += 0.12
			if n.has("S1.2.3"): u.defense += 576
			if n.has("S2.1.1"): u.attack_mod += 0.20
			if n.has("S2.1.2"): u.healing_amp += 0.15
			if n.has("S2.1.3"): u.stun_threshold += 2
		"Devastator":
			for node in ["S1.1.1","S1.2.1","S2.2.1"]:
				if n.has(node): u.ap_recovery += 8; u.character_ap_recovery += 8
			if n.has("S1.2.2"): u.max_hp += 4000
			if n.has("S2.1.2"): u.attack_mod += 0.20
			if n.has("S2.1.3"): u.skills["Imperial Decree"].ap -= 80
		"Piercer":
			if n.has("S1.2.1"):
				for name in u.skills: u.skills[name].mp *= 0.51
			if n.has("S1.3.1"): u.max_mp += 17920
			if n.has("S2.1.1"): u.summon_attack_effectiveness += 0.10
			if n.has("S2.1.2"): u.summon_chc += 0.12
			if n.has("S2.1.3"): u.max_hp += 2400
			if n.has("S2.2.1"): u.summon_mhr_mod += 0.12
		"Ranger":
			if n.has("S1.1.1"): u.attack_mod += 0.10; u.multi_hit_rate += 0.12
			if n.has("S1.1.2"): u.accuracy += 0.15; u.mhr_mod += 0.05
	u.hp = u.max_hp
	u.mp = u.max_mp
	var spent := 0
	for name in u.levels:
		spent += int(u.levels[name])
		assert(u.levels[name] <= u.skills[name].base_max_level,"Skill allocation cap")
	assert(spent <= u.skill_points and n.size() <= 6,"Build budget")

func _sum(u: Dictionary, key: String) -> float:
	var value := super(u,key)
	if not u.get("is_automaton",false) and key in ["def_mod","attack_mod"]:
		for source in teams[u.side]:
			if source.hp <= 0 or is_stunned(source.side,source.index) or source.type != "Soldier" or not source.nodes.has("S2.1.4"): continue
			if u.index in _area(source.index,"Adjacent"):
				value += 0.12 if key == "def_mod" else 0.04
				break # Same passive-node source contributes at most once.
	return value

func _blocked(u: Dictionary) -> bool:
	if u.get("is_automaton",false): return _unit(u.side,u.owner).hp <= 0
	return super(u)

func _area(primary: int, shape: String) -> Array[int]:
	return preload("res://src/combat/current_rules.gd").area(primary,shape)

func _effect(u: Dictionary, tag: String, duration: int, data: Dictionary, caster: Dictionary) -> void:
	if u.hp <= 0 or duration <= 0: return
	var source_id := _status_source if not _status_source.is_empty() else tag
	for old in u.statuses:
		if old.tag == tag and old.get("source_id",old.tag) == source_id and int(old.expires) > global_turn:
			return # No refresh/replacement even from a different caster of the same source.
	var effect := data.duplicate(true)
	effect.merge({"tag":tag,"source_id":source_id,"expires":global_turn+duration,
		"creator_side":caster.side,"creator":caster.index,"applied":global_turn},true)
	u.statuses.append(effect)

func _death_event(v: Dictionary) -> void:
	if v.get("death_processed",false): return
	v.death_processed = true
	v.has_slot = false
	if v.has("automata"): v.automata.clear()
	for ally in teams[v.side]:
		if ally.hp > 0:
			ally.ap_recovery += 5.0
			ally.character_ap_recovery += 5.0
	_check_end()

func _hp_decay(side: String) -> void:
	if global_turn < 30: return
	for victim in teams[side]:
		if finished: return
		if victim.hp <= 0: continue
		var amount := minf(victim.hp, victim.max_hp * 0.05)
		victim.hp -= amount # Direct loss: no mitigation, damage credit, block or hit events.
		if victim.hp <= 0: _death_event(victim)
		_record(victim,"HP decay",victim.index,side,[_impact(side,victim.index,amount)],"hp_loss")

func _ready_skill(u: Dictionary, name: String) -> bool:
	if is_stunned(u.side,u.index): return false
	if _has(u,"silence") and name not in ["Maiden’s Care","Grand Battery","Avalon’s Veil","Phalanx","Thief’s Mark"]: return false
	if not super(u,name): return false
	if name == "Deadly Strike" and u.hp >= u.max_hp*0.5 and not u.nodes.has("S1.1.2"): return false
	if name.begins_with("Summon "): return not _has_automaton(u.side,name)
	return true

func _passive_skill_active(u: Dictionary, name: String) -> bool:
	return skill_mode and not is_stunned(u.side,u.index) and super(u,name)

func _refresh_continuous_stats() -> void:
	for side in ["A","B"]:
		for u in teams[side]:
			if u.get("character_id","") != "morgan_le_fay": continue
			var effectiveness: float = .02 * int(u.levels.get("Avalon’s Veil",0)) if _passive_skill_active(u,"Avalon’s Veil") else 0.0
			u.max_mp = u.mp_without_veil*(1+effectiveness)
			u.mp = minf(u.mp,u.max_mp)

func add_stun_count(side: String, index: int, amount: int) -> void:
	super(side,index,amount)
	_refresh_continuous_stats()

func _normal_targets(u: Dictionary) -> Array[int]:
	var front: bool = u.type not in ["Ranger","Devastator"]
	var result: Array[int] = []
	for i in _targets(_enemy(u.side),front):
		var target := _unit(_enemy(u.side),i)
		var veiled: bool = target.get("character_id","") == "morgan_le_fay" and _passive_skill_active(target,"Avalon’s Veil")
		if veiled and u.type in ["Warrior","Destroyer","Soldier","Devastator"]: continue
		result.append(i)
	return result

func _has_automaton(side: String, name: String) -> bool:
	for u in teams[side]:
		if u.hp <= 0: continue
		for machine in u.automata:
			if machine.summon_skill == name: return true
	return false

func _pay(u: Dictionary, name: String, automatic: bool = false) -> void:
	var skill: Dictionary = u.skills[name]
	u.mp -= skill.mp
	if not automatic: u.ap -= skill.ap; u.has_slot = false
	skill.remaining = skill.cd
	_cast_count += 1

func _take_hp(v: Dictionary, amount: float, source: Dictionary) -> float:
	var result := super(v,amount,source)
	if source.get("is_automaton",false): _unit(source.side,source.owner).damage_done += result
	if v.hp <= 0: _death_event(v)
	return result

func _record(u: Dictionary, name: String, primary: int, side: String, impacts: Array, kind: String = "skill") -> void:
	if u.get("is_automaton",false): name = u.machine_name+" · "+name
	super(u,name,primary,side,impacts,kind)

func _summon(u: Dictionary, name: String) -> void:
	assert(not _has_automaton(u.side,name),"Team-wide duplicate summon")
	var bombard := name == "Summon Bombard Automaton"
	var machine := {"side":u.side,"index":u.index,"owner":u.index,"is_automaton":true,"summon_skill":name,"machine_name":"Bombard Automaton" if bombard else "Piercing Automaton","type":"Devastator" if bombard else "Piercer","hp":1.0,"max_hp":1.0,"mp":0.0,"max_mp":0.0,"ap":0.0,"has_slot":false,"main":false,"stun_count":0,"last_stack_turn":-10,"stunned_until":0,"defending":false,"attack":u.attack*(0.5+0.1*u.levels[name]),"attack_mod":0.0,"attack_effectiveness":u.summon_attack_effectiveness,"critical_chance":u.summon_chc,"critical_damage_bonus":0.0,"multi_hit_rate":1.0,"mhr_mod":u.summon_mhr_mod,"penetration_chance":0.0,"accuracy":1.0,"evasion":0.0,"attack_stun_count":1 if bombard or u.nodes.has("S2.1.4") else 0,"statuses":[],"skills":{},"levels":{},"nodes":[],"damage_done":0.0,"sub_penalty":0.5,"created_turn":global_turn}
	u.automata.append(machine)

func _normal(u: Dictionary, primary: int, counter: bool = false, coordinated: bool = false) -> void:
	if primary < 0 or _blocked(u): return
	if not counter and primary not in _normal_targets(u): return
	var machine: bool = u.get("is_automaton",false)
	if not counter and not machine: u.ap -= 100
	if not counter and not coordinated: u.has_slot = false
	var shape: String = {"Destroyer":"Row Adjacent","Soldier":"Line Adjacent","Piercer":"Full Line","Devastator":"Cross"}.get(str(u.type),"Single")
	if counter and u.type in ["Warrior","Destroyer","Soldier"]: shape = "Single"
	var targets := _area(primary,shape)
	_weapon_presentation_sequence += 1
	var presentation_sequence := _weapon_presentation_sequence
	var rate: float = maxf(1.0,(u.multi_hit_rate+_sum(u,"mhr_flat"))*(1+u.mhr_mod+_sum(u,"mhr_mod")))
	var count := 1 if counter else int(floor(rate))+int(_roll(rate-floor(rate)))
	for hit_index in range(count):
		for target in targets:
			if finished or _blocked(u): break
			var v := _unit(_enemy(u.side),target)
			if v.hp <= 0: continue
			var penalty: float = 0.0 if target == primary else u.sub_penalty
			if target != primary and u.type == "Piercer" and absi(int(target)/3-int(primary)/3)>1: penalty = 0.75
			var power: float = u.attack*(1+u.attack_mod+_sum(u,"attack_mod"))*u.attack_effectiveness
			var hit := _damage(u,v,power,true,penalty,-1,counter)
			_record(u,"Counterattack" if counter else ("Coordinated attack" if coordinated else "Normal attack · hit %d" % (hit_index+1)),primary,_enemy(u.side),[hit],"attack")
			timeline[-1]["weapon_hit_id"] = "%d:%d" % [presentation_sequence,hit_index]
			# Resolve this recipient's hit effects before advancing to the next recipient/hit.
			if u.type == "Ranger" and hit.landed and u.nodes.has("S1.1.4") and _ready_skill(u,"Golden Arrow Shot") and _roll(0.20):
				if not finished and _unit(_enemy(u.side),primary).hp>0: _cast(u,"Golden Arrow Shot",primary,true)
			if hit.get("counter",false) and not finished: _normal(v,u.index,true)
	if not counter and not coordinated and not machine and not finished:
		for effect in u.statuses.duplicate(true):
			if effect.tag != "decree": continue
			var owner := _unit(effect.creator_side,effect.creator)
			if not _blocked(owner) and owner.ap>=100 and _unit(_enemy(u.side),primary).hp>0 and _roll(effect.chance): _normal(owner,primary,false,true)

func _cast(u: Dictionary, name: String, primary: int, automatic: bool = false) -> void:
	var previous := _status_source
	_status_source = name
	_cast_impl(u, name, primary, automatic)
	_status_source = previous

func _cast_impl(u: Dictionary, name: String, primary: int, automatic: bool = false) -> void:
	var skill: Dictionary = u.skills[name]
	var level: int = u.levels[name]
	if preload("res://src/combat/caster_kit.gd").handles(name):
		if not _ready_skill(u,name): return
		if name == "Malediction" and primary not in _targets(_enemy(u.side),false,true): return
		_pay(u,name,automatic)
		preload("res://src/combat/caster_kit.gd").cast(self,u,name,primary)
		return
	if name.begins_with("Summon "):
		if not _ready_skill(u,name): return
		_pay(u,name,automatic)
		_summon(u,name)
		_record(u,name,u.index,u.side,[])
		return
	var handled := name in ["Mona Lisa","Grand Battery","Imperial Decree","God-King Slayer","Golden Arrow Shot","Man Under the Hood","Maiden’s Care"]
	if not handled: super._cast(u,name,primary,automatic); return
	_pay(u,name,automatic)
	var impacts: Array = []
	var side: String = u.side
	match name:
		"Mona Lisa":
			for i in _alive(side):
				var ally := _unit(side,i)
				for _k in range(2 if u.nodes.has("S1.2.2") else 1): _cleanse_oldest(ally)
				impacts.append(_heal(u,ally,skill.satk*level/5.0))
		"Maiden’s Care":
			var ally := _unit(side,scenario.main_index)
			var effectiveness := 1.26 if u.nodes.has("S1.2.4") else 1.0
			_effect(ally,"resistance",skill.duration,{"sdef_flat":u.skill_defense*0.02*level*effectiveness},u)
			impacts.append(_heal(u,ally,skill.satk*level/5.0*effectiveness))
		"Grand Battery":
			var effectiveness := 1.26 if u.nodes.has("S1.2.4") else 1.0
			for i in _alive(side):
				var ally := _unit(side,i)
				if ally.type != "Devastator": continue
				_effect(ally,"battery",skill.duration,{"attack_mod":0.02*level*effectiveness,"mhr_mod":0.024*level*effectiveness},u)
				impacts.append(_heal(u,ally,100*effectiveness) if u.nodes.has("S1.2.3") else _impact(side,i,0))
		"Imperial Decree":
			var ally := _unit(side,primary)
			_effect(ally,"decree",skill.duration,{"chance":0.13*level+(0.23 if u.nodes.has("S2.1.4") else 0.0)},u)
			if u.nodes.has("S2.1.1"): ally.mp = minf(ally.max_mp,ally.mp+4000*level)
			impacts.append(_impact(side,primary,0))
		"Man Under the Hood":
			_effect(u,"invisible",skill.duration,{},u)
			_effect(u,"hood_precision",skill.duration,{"chc_flat":0.02*level},u)
			if u.nodes.has("S1.1.3"): u.ap += 50
			u.has_slot = true
			impacts.append(_impact(side,u.index,0))
		"God-King Slayer", "Golden Arrow Shot":
			side = _enemy(side)
			var recipients: Array = _area(primary,"Line Adjacent") if name == "God-King Slayer" and u.nodes.has("S1.2.4") else [primary]
			for i in recipients:
				if finished: break
				var target := _unit(side,i)
				if target.hp <= 0: continue
				var effectiveness := 1.13 if name == "God-King Slayer" and u.nodes.has("S1.2.2") else 1.0
				var modifier := 1.14 if name == "Golden Arrow Shot" and u.nodes.has("S1.2.1") else 1.0
				var power: float = skill.satk*level/5.0*effectiveness*modifier
				if name == "God-King Slayer" and target.main: power = skill.satk*level/5.0*(effectiveness+0.5)*modifier
				impacts.append(_damage(u,target,power,false,0.5 if i!=primary else 0.0,0.65 if name == "God-King Slayer" else -1))
	_record(u,name,primary,side,impacts)

func _passives(side: String) -> void:
	# Independent auto-casts: acting team first, then opposing team, slot order.
	for owner in [side,_enemy(side)]:
		for caster in teams[owner]:
			if finished: return
			if owner == side and _ready_skill(caster,"Maiden’s Care"): _cast(caster,"Maiden’s Care",scenario.main_index,true)
			if not finished and _ready_skill(caster,"Grand Battery"): _cast(caster,"Grand Battery",caster.index,true)
	for u in teams[side]:
		if u.hp<=0: u.automata.clear(); continue
		for machine in u.automata.duplicate():
			if finished: return
			var targets := _targets(_enemy(side),machine.type=="Piercer")
			if not targets.is_empty(): _normal(machine,_choose(targets,_enemy(side)),false,true)

func _heal_target(side: String) -> int:
	var best := -1
	for i in _alive(side):
		if best<0 or _unit(side,i).hp/_unit(side,i).max_hp < _unit(side,best).hp/_unit(side,best).max_hp: best=i
	return best

func _act(u: Dictionary) -> void:
	var enemies := _targets(_enemy(u.side))
	if enemies.is_empty(): u.has_slot=false; return
	var low := _heal_target(u.side)
	if u.get("character_id","") == "nightingale":
		if low >= 0 and _unit(u.side,low).hp < _unit(u.side,low).max_hp:
			for healing in ["Healing Hands","Back to Duty"]:
				if _ready_skill(u,healing): _cast(u,healing,low); return
		if _ready_skill(u,"Back to Duty"):
			for i in _alive(u.side):
				if not _has(_unit(u.side,i),"haste"): _cast(u,"Back to Duty",i); return
	elif u.get("character_id","") == "morgan_le_fay" and _ready_skill(u,"Fae Starfall"):
		_cast(u,"Fae Starfall",enemies[0]); return
	if u.get("character_id","") == "morgan_le_fay" and _ready_skill(u,"Malediction"):
		var rows := _targets(_enemy(u.side),false,true)
		if not rows.is_empty(): _cast(u,"Malediction",_choose(rows,_enemy(u.side))); return
	for name in ["Mona Lisa","Holy Guard"]:
		if _ready_skill(u,name) and low>=0 and _unit(u.side,low).hp<=_unit(u.side,low).max_hp*u.ai.heal_hp_ratio:
			_cast(u,name,low); return
	for name in ["Summon Bombard Automaton","Summon Piercing Automaton"]:
		if _ready_skill(u,name): _cast(u,name,u.index); return
	if u.type == "Ranger":
		if _ready_skill(u,"Man Under the Hood") and not _has(u,"invisible"):
			_cast(u,"Man Under the Hood",u.index)
			if not finished and u.has_slot: _normal(u,_choose(enemies,_enemy(u.side),true))
		else: _normal(u,_choose(enemies,_enemy(u.side),true))
		return
	if _ready_skill(u,"Imperial Decree"):
		for i in _alive(u.side):
			var ally := _unit(u.side,i)
			if ally.type=="Devastator" and i!=u.index and not _has(ally,"decree"): _cast(u,"Imperial Decree",i); return
	for name in ["Crushing Barrage","Frozen Axe","War Cry","God-King Slayer","Deadly Strike","Holy Blade"]:
		if not _ready_skill(u,name): continue
		var targets := enemies
		if name in ["Frozen Axe","Deadly Strike","Holy Blade"]: targets = _targets(_enemy(u.side),true)
		elif name in ["War Cry","God-King Slayer"]: targets = _targets(_enemy(u.side),false,true)
		if targets.is_empty(): continue
		_cast(u,name,_choose(targets,_enemy(u.side),true)); return
	var targets := _normal_targets(u)
	if targets.is_empty(): u.has_slot=false; return
	_normal(u,_choose(targets,_enemy(u.side),true))


func _end_turn() -> void:
	for side in [_next,_enemy(_next)]:
		for victim in teams[side]:
			if finished: return
			for effect in victim.statuses.duplicate(true):
				if not str(effect.tag).begins_with("dot:") or victim.hp<=0: continue
				var source := _unit(effect.creator_side,effect.creator)
				var power: float = effect.power
				var final_mhr: float = maxf(1.0,(victim.multi_hit_rate+_sum(victim,"mhr_flat"))*(1+victim.mhr_mod+_sum(victim,"mhr_mod")))
				if effect.double_at_one and is_equal_approx(final_mhr,1.0): power*=2
				var hit := _damage(source,victim,power,false,effect.penalty)
				_record(source,"DOT · "+str(effect.tag).trim_prefix("dot:"),victim.index,side,[hit],"dot")
				if finished: return
	for side in [_next,_enemy(_next)]:
		for unit in teams[side]:
			unit.statuses=unit.statuses.filter(func(e: Dictionary) -> bool: return int(e.expires)>global_turn+1)
			if unit.stun_count>0 and global_turn>=unit.last_stack_turn+2: unit.stun_count=0
			if unit.hp>0:
				for name in unit.skills: unit.skills[name].remaining=maxi(0,int(unit.skills[name].remaining)-1)
	_record(_unit("A",0),"End turn · expire effects / recover cooldown",-1,"A",[],"system")

func step() -> Dictionary:
	if finished: return {}
	global_turn += 1
	_refresh_continuous_stats()
	var side: String = _next
	timeline.clear()
	var start: Dictionary = teams.duplicate(true)
	for owner in ["A","B"]:
		for unit in teams[owner]: unit.has_slot=false
	_hp_decay(side)
	if not finished: _passives(side)
	var cap := 2 if global_turn<=2 else (4 if global_turn<=4 else 5)
	if not finished:
		for unit in teams[side]:
			if unit.hp>0:
				var base: float = unit.ap_recovery-unit.character_ap_recovery if is_stunned(side,unit.index) else unit.ap_recovery
				unit.ap += base*(1+_sum(unit,"apr_mod"))
		var eligible: Array[Dictionary] = []
		for unit in teams[side]:
			if not _blocked(unit) and unit.ap>=100: eligible.append({"index":unit.index,"ap":unit.ap,"tie":_rng.randf()})
		eligible.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.ap>b.ap if a.ap!=b.ap else a.tie>b.tie)
		_record(_unit(side,0),"Start turn · AP recovery / action slots",-1,side,[],"system")
		for entry in eligible.slice(0,mini(cap,eligible.size())): _unit(side,entry.index).has_slot=true
		for entry in eligible.slice(0,mini(cap,eligible.size())):
			var unit := _unit(side,entry.index)
			if not finished and not _blocked(unit) and unit.has_slot: _act(unit)
	if not finished: _end_turn()
	if global_turn>=scenario.max_global_turns: finished=true
	var result := "Team %s wins" % winner if winner!="" else ("Turn limit" if finished else "Ongoing")
	var event := {"turn":global_turn,"team":side,"enemy":_enemy(side),"turn_start_state":start,"actions":timeline.duplicate(true),"result":result,"slot_limit":cap}
	history.append(event)
	_next=_enemy(side)
	return event
