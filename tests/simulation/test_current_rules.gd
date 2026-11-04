extends SceneTree
const Battle = preload("res://src/combat/requested_battle.gd")
const Areas = preload("res://src/combat/current_rules.gd")
var checks := 0
var failures := 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(text)
func fresh() -> RefCounted:
	return Battle.new(Battle.load_mixed_config(),"A",42,true)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	check(Areas.area(4,"Adjacent") == [0,1,2,3,4,5,6,7,8],"Adjacent center includes diagonals")
	check(Areas.area(4,"Line Adjacent") == [1,4,7],"Line Adjacent both directions")
	check(Areas.area(7,"Full Line") == [1,4,7],"Full Line includes front of selected target")
	check(Areas.area(0,"Cross") == [0,1,3],"Cross no wrapping at corner")
	check(Areas.area(1,"Row Adjacent") == [0,1,2],"Row Adjacent")
	check(Areas.area(3,"Full Row") == [3,4,5],"Full Row")
	for slot in range(9):
		for shape in ["Single","Adjacent","Row Adjacent","Line Adjacent","Full Row","Full Line","Cross","All Allies","All Enemies"]:
			var a := Areas.area(slot,shape)
			check(a.has(slot),"Area includes center")
			var previous := -1
			for i in a:
				check(i>previous and i>=0 and i<9,"Recipients ascending, bounded and unique")
				previous=i
	var b=fresh()
	b.global_turn=29
	var u: Dictionary=b.teams.A[0]
	var hp: float=u.hp
	b._hp_decay("A")
	check(u.hp==hp,"No decay before30")
	b.global_turn=30
	var enemy_hp: float=b.teams.B[0].hp
	u.statuses.append({"tag":"invincible","expires":99,"applied":1})
	b._hp_decay("A")
	check(is_equal_approx(u.hp,hp-u.max_hp*.05),"Decay bypasses invincibility")
	check(b.teams.B[0].hp==enemy_hp and u.max_hp==hp,"Acting team only, max HP unchanged")
	check(u.damage_done==0,"Decay is not damage credit")
	b=fresh();b.global_turn=30
	u=b.teams.A[0];u.hp=1.0
	var ally: Dictionary=b.teams.A[1]
	var apr: float=ally.ap_recovery
	var ap: float=ally.ap
	b._hp_decay("A")
	check(u.hp==0 and ally.ap_recovery==apr+5,"Decay death grants surviving allies5 baseAPR")
	check(ally.ap==ap,"Death bonus does not restore current AP")
	b._death_event(u)
	check(ally.ap_recovery==apr+5,"Death counted once")
	b._take_hp(b.teams.A[2],1e9,b.teams.B[0])
	check(ally.ap_recovery==apr+10,"Different allied deaths stack")
	b=fresh();b.global_turn=30
	b.teams.A[b.scenario.main_index].hp=1
	b._hp_decay("A")
	check(b.finished and b.winner=="B","Decay can kill main and end battle")
	check(not b.teams.A[8].has("death_processed"),"No later events after battle end")
	b=fresh();b.global_turn=4
	u=b.teams.A[3];ally=b.teams.A[6]
	b._status_source="Grand Battery"
	b._effect(ally,"battery",3,{"attack_mod":.1},u)
	var first: Dictionary=ally.statuses[0].duplicate(true)
	b.global_turn=5
	b._effect(ally,"battery",5,{"attack_mod":.99},ally)
	first.expires=10
	check(ally.statuses.size()==1 and ally.statuses[0]==first,"Same source refreshes duration only, preserving caster/value")
	b._status_source="Other skill"
	b._effect(ally,"battery",2,{"attack_mod":.2},u)
	check(ally.statuses.size()==2,"Different skill source may coexist")
	ally.statuses.clear();b._status_source="Grand Battery"
	b._effect(ally,"battery",2,{"attack_mod":.3},ally)
	check(ally.statuses[0].creator==ally.index,"Reapply allowed after removal")
	b=fresh()
	b.teams.B[3].skills["Grand Battery"].remaining=0
	b._passives("A")
	check(not b._has(b.teams.B[3],"battery") and b.teams.B[3].skills["Grand Battery"].remaining==0,"Grand Battery waits for allied team turn")
	check(b.teams.A[2].attack<3000,"Latest Soldier Attack imported")
	check(is_equal_approx(b.teams.A[2].multi_hit_rate,1.2),"Latest Soldier MHR imported")
	b=fresh();u=b.teams.A[2]
	u.nodes=[];u.multi_hit_rate=3;u.attack=1;u.accuracy=1
	for v in b.teams.B:v.levels={"Phalanx":100};v.attack=1e9;v.accuracy=1;v.evasion=0
	b._normal(u,0)
	var names: Array=[]
	for action in b.timeline:names.append(action.name)
	check(names.size()==2 and str(names[1])=="Counterattack","Counter resolves immediately and interrupts remaining hits on death")
	print("CURRENT_RULES_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
