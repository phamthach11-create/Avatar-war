extends SceneTree
const Battle = preload("res://src/combat/requested_battle.gd")
const Playback = preload("res://src/ui/weapon_playback.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func same(a, b) -> bool:
	if typeof(a) in [TYPE_INT,TYPE_FLOAT] and typeof(b) in [TYPE_INT,TYPE_FLOAT]: return is_equal_approx(a,b)
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not same(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for i in range(a.size()):
			if not same(a[i],b[i]): return false
		return true
	return a==b
func fresh() -> RefCounted:
	return Battle.new(Battle.load_mixed_config(),"A",42,true)
func verify(actions: Array, start: Dictionary) -> Array:
	var untouched=actions.duplicate(true)
	var frames: Array=Playback.group(actions,start)
	check(actions==untouched,"Raw log and combat snapshots unchanged")
	var count := 0
	var raw_damage := 0.0
	var shown_damage := 0.0
	for a in actions:
		for hit in a.impacts: raw_damage+=hit.damage
	for a in frames:
		count+=a.source_action_count
		for hit in a.impacts: shown_damage+=hit.damage
	check(count==actions.size(),"All original events accounted for")
	check(is_equal_approx(raw_damage,shown_damage),"Damage/healing conserved")
	if not actions.is_empty(): check(same(frames[-1].state_after,actions[-1].state_after),"Rebased final state matches combat")
	return frames
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var specs={"Warrior":[1,[1]],"Destroyer":[0,[0,1,2]],"Soldier":[2,[1,4]],"Ranger":[8,[1]],"Piercer":[5,[1,4,7]],"Devastator":[3,[0,1,2,4]],"Caster":[7,[1]]}
	for weapon in specs:
		var b=fresh();b.global_turn=4
		for v in b.teams.B:v.levels["Phalanx"]=0
		var u: Dictionary=b.teams.A[specs[weapon][0]]
		u.multi_hit_rate=2;u.mhr_mod=0;u.statuses=[];u.accuracy=1;u.ap=300
		var start: Dictionary=b.teams.duplicate(true)
		b._normal(u,1)
		var frames=verify(b.timeline,start)
		check(frames.size()==2,"%s: two hits, not one swing per recipient"%weapon)
		for a in frames:
			var ids: Array=[]
			for hit in a.impacts: ids.append(hit.target)
			check(ids==specs[weapon][1],"%s exact weapon area per hit"%weapon)
	# Both independent Automaton weapons use the same presentation path.
	for skill in ["Summon Bombard Automaton","Summon Piercing Automaton"]:
		var b=fresh();b.global_turn=4
		for v in b.teams.B:v.levels["Phalanx"]=0
		b._summon(b.teams.A[5],skill)
		b.teams.A[5].automata[0].multi_hit_rate=1
		b.teams.A[5].automata[0].mhr_mod=0
		var start: Dictionary=b.teams.duplicate(true)
		b._normal(b.teams.A[5].automata[0],1,false,true)
		var frames=verify(b.timeline,start)
		check(frames.size()==1,"One Automaton shot")
		check(frames[0].impacts.size()==(4 if skill.contains("Bombard") else 3),"Automaton entire weapon AoE together")
	# Force a counter BETWEEN two recipients, not just after the last recipient.
	var b=fresh();b.global_turn=4
	b.teams.B[1].levels["Phalanx"]=25
	b.teams.B[2].levels["Phalanx"]=0
	var u: Dictionary=b.teams.A[0];u.multi_hit_rate=1;u.mhr_mod=0;u.attack_stun_count=0
	var start: Dictionary=b.teams.duplicate(true)
	b._normal(u,1)
	var frames=verify(b.timeline,start)
	check(frames[0].impacts.size()==3,"AoE remains one impact despite intervening counter")
	check(frames.size()==2 and frames[1].name=="Counterattack","Counter retained after hit")
	check(frames[0].state_after.A[0].hp==start.A[0].hp,"Counter damage not applied before its animation")
	check(frames[1].state_after.A[0].hp<start.A[0].hp,"Counter damage applied on counter frame")
	for first in ["A","B"]:
		b=Battle.new(Battle.load_mixed_config(),first,42,true)
		while not b.finished and b.global_turn<300:
			var event: Dictionary=b.step()
			verify(event.actions,event.turn_start_state)
	print("WEAPON_PLAYBACK_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
