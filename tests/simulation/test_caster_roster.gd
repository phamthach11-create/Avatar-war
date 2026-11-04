extends SceneTree
const Battle = preload("res://src/combat/requested_battle.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func fresh(first: String = "A", seed_value: int = 42) -> RefCounted:
	return Battle.new(Battle.load_mixed_config(),first,seed_value,true)
func ready(b: RefCounted, index: int, name: String) -> Dictionary:
	var u: Dictionary = b.teams.A[index]
	u.skills[name].remaining=0
	u.ap=100
	u.has_slot=true
	return u
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var b=fresh()
	var m: Dictionary=b.teams.A[4]
	var n: Dictionary=b.teams.A[7]
	check(m.character_id=="morgan_le_fay" and not m.main and n.main,"Nightingale main8, Morgan5")
	check(m.skill_points==12 and n.skill_points==12,"Caster total12 SP from equipment included")
	check(m.levels["Fae Starfall"]==6 and m.levels["Malediction"]==6,"Morgan6/6")
	check(n.levels["Healing Hands"]==6 and n.levels["Back to Duty"]==6,"Nightingale6/6")
	check(m.max_hp==45647 and n.max_hp==44184,"Distinct character block HP + chosen node bonuses")
	check(is_equal_approx(m.max_mp,95600) and n.max_mp==89600,"Morgan no Veil/flat MP upgrade")
	check(is_zero_approx(m.def_mod) and is_equal_approx(n.skill_defense,2341.83870967742),"Morgan no DEF upgrade, Nightingale SDEF275")
	check(m.skills["Fae Starfall"].ap==300 and m.ap_recovery==103,"Starfall AP300; APR95+8")
	check(n.nodes.has("S2.2.3") and n.skills["Back to Duty"].area=="Cross","Matron prerequisite and Cross")
	for i in range(9):
		check(b.teams.A[i].name==b.teams.B[i].name and b.teams.A[i].levels==b.teams.B[i].levels,"Mirrored roster/build")
	b.global_turn=4
	for v in b.teams.A:v.hp=v.max_hp*.2
	n=ready(b,7,"Healing Hands")
	var hp: float=b.teams.A[4].hp
	var target: Dictionary=b.teams.A[1]
	var start_hp: float=target.hp
	var expected: float=n.skills["Healing Hands"].satk*6/5.0*(1+target.healing_amp+target.ha_bonus)
	b._cast(n,"Healing Hands",1)
	check(is_equal_approx(target.hp-start_hp,expected),"Healing Hands scales SL6, then recipient HA")
	check(b.timeline[-1].impacts.size()==3 and b.teams.A[4].hp==hp,"Healing Hands Full Row only")
	check(n.ap==-25 and not n.has_slot,"125AP cost allows negative AP, consumes slot")
	n=ready(b,7,"Back to Duty")
	b._cast(n,"Back to Duty",4)
	var ids: Array=[]
	for hit in b.timeline[-1].impacts:ids.append(hit.target)
	check(ids==[1,3,4,5,7],"Back to Duty Cross sorted unique")
	check(is_equal_approx(b._sum(b.teams.A[4],"apr_mod"),.09),"Haste is3%+1%*SL6")
	b.global_turn=10;b._end_turn()
	check(b._has(b.teams.A[4],"haste"),"Haste active through seventh turn")
	b.global_turn=11;b._end_turn()
	check(not b._has(b.teams.A[4],"haste"),"Haste expires end of eighth turn")
	b=fresh();b.global_turn=10
	m=ready(b,4,"Fae Starfall")
	var mp: float=m.mp
	b._cast(m,"Fae Starfall",0)
	check(b.timeline[-1].impacts.size()==9,"Starfall all9 enemies")
	var victim: Dictionary=b.teams.B[0]
	var power: float=16540*6/5.0*1.13
	var sdef: float=victim.skill_defense
	check(is_equal_approx(b.timeline[-1].impacts[0].damage,power*1000/(sdef+1000)),"Starfall SATK effectiveness13%, skill mitigation only")
	check(is_equal_approx(mp-m.mp,12382.84) and m.ap==-200,"Starfall pays listedMP and baseAP")
	check(m.skills["Fae Starfall"].remaining==8,"Starfall cooldown starts on cast")
	b=fresh();b.global_turn=4
	m=ready(b,4,"Malediction")
	var before: float=b.teams.B[0].hp
	b._cast(m,"Malediction",0)
	check(b.timeline[-1].impacts.size()==3 and b.teams.B[0].hp==before,"Malediction row, no direct damage")
	check(is_equal_approx(b._sum(b.teams.B[0],"attack_mod"),-.04*6*1.13),"Intimidated effectiveness13%")
	var dot: Dictionary=b.teams.B[0].statuses[0]
	check(is_equal_approx(dot.power,2067.5*6/5.0*1.13),"DOT effectiveness13%")
	var victim_skill: Dictionary=b.teams.B[0]
	victim_skill.skills["Frozen Axe"].remaining=0
	check(not b._ready_skill(victim_skill,"Frozen Axe") and not b._blocked(victim_skill),"Silence blocks skills but permits normals")
	b._next="A";b._end_turn()
	check(b.teams.B[0].hp<before,"Malediction DOT ticks at end turn")
	b.global_turn=7;b._end_turn()
	check(not b._has(victim_skill,"silence") and b._ready_skill(victim_skill,"Frozen Axe"),"Silence expires after4 global turns")
	m=ready(b,4,"Malediction");var mana: float=m.mp
	b._cast(m,"Malediction",7)
	check(m.mp==mana,"Malediction cannot target rear row")
	check(m.max_hp==45647 and m.max_mp==95600 and m.ap_recovery==103,"Enchantress final stats")
	check(not b._passive_skill_active(m,"Avalon’s Veil"),"Enchantress has no Veil")
	var tank: Dictionary=b.teams.A[2]
	tank.stunned_until=b.global_turn+3
	check(is_zero_approx(b._sum(b.teams.A[1],"def_mod")),"Stunned Leonidas emits no aura")
	check(not b._passive_skill_active(tank,"Phalanx"),"Stun suspends Phalanx")
	tank.stunned_until=0
	check(is_equal_approx(b._sum(b.teams.A[1],"def_mod"),.12) and is_equal_approx(b._sum(b.teams.A[1],"attack_mod"),.04),"New aura12%/4%")
	var cannon: Dictionary=b.teams.A[3]
	cannon.skills["Grand Battery"].remaining=0;cannon.stunned_until=b.global_turn+3
	check(not b._ready_skill(cannon,"Grand Battery"),"Stun blocks passive auto-cast")
	b=fresh();b.global_turn=5
	n=ready(b,7,"Back to Duty");b._cast(n,"Back to Duty",4)
	for v in b.teams.A:v.ap=0
	b._next="A"
	b.step()
	var recovered := -1.0
	for action in b.timeline:
		if action.kind=="system" and str(action.name).begins_with("Start turn"):
			recovered=action.state_after.A[7].ap
	check(is_equal_approx(recovered,95*1.09),"Haste affects subsequent AP recovery")
	var matches: Array=[]
	for first in ["A","B"]:
		for seed_value in [42,43,44]:
			b=fresh(first,seed_value)
			var casts := {"Healing Hands":0,"Back to Duty":0,"Fae Starfall":0,"Malediction":0}
			while not b.finished and b.global_turn<300:
				var event: Dictionary=b.step()
				for action in event.actions:
					if casts.has(action.name):casts[action.name]+=1
				for side in ["A","B"]:
					for v in b.teams[side]:
						check(v.hp>=0 and v.hp<=v.max_hp and v.mp>=-.001,"Legal resources throughout match")
			check(b.finished and not b.winner.is_empty(),"Complete9v9 ends on main death")
			check(casts["Healing Hands"]>0 and casts["Back to Duty"]>0 and casts["Fae Starfall"]>0 and casts["Malediction"]>0,"Actual match casts all selected actives")
			matches.append([first,seed_value,b.global_turn,b.winner,casts])
	print("CASTER_MATCHES ",matches)
	print("CASTER_TEST_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
