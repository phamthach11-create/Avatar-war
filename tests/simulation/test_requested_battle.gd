extends SceneTree
const Battle = preload("res://src/combat/requested_battle.gd")
const Log = preload("res://src/combat/battle_log.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func fresh() -> RefCounted:
	return Battle.new(Battle.load_mixed_config(),"A",42,true)
func ready(b: RefCounted, i: int, name: String) -> Dictionary:
	var u: Dictionary = b.teams.A[i]
	u.skills[name].remaining=0
	u.has_slot=true
	return u
func total_hp(b: RefCounted,side: String) -> float:
	var sum := 0.0
	for u in b.teams[side]: sum+=u.hp
	return sum
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var b=fresh()
	check(b.teams.A.size()==9 and b.teams.B.size()==9,"9vs9")
	for side in ["A","B"]:
		check(b.teams[side][4].main,"main slot5")
		for i in range(9):
			var u: Dictionary=b.teams[side][i]
			check(u.nodes==b.scenario.roster[i].nodes,"exact nodes")
			check(u.levels==b.scenario.roster[i].levels,"exact levels")
	check(b.teams.A[7].levels['Mona Lisa']==10 and b.teams.A[7].levels['Summon Piercing Automaton']==7,"healer priority allocation")
	check(is_equal_approx(b.teams.A[7].skills['Mona Lisa'].mp,20415*.51),"49% skill mana reduction")
	check(is_equal_approx(b._sum(b.teams.A[1],'def_mod'),.07),"tank aura adjacent")
	check(is_equal_approx(b._sum(b.teams.A[4],'def_mod'),0),"aura does not reach diagonal")
	check(not b._ready_skill(b.teams.A[0],'Deadly Strike'),"Deadly locked by cooldown/health")
	var u=ready(b,0,'Deadly Strike')
	check(not b._ready_skill(u,'Deadly Strike'),"HP restriction retained")
	u.hp=u.max_hp*.4
	check(b._ready_skill(u,'Deadly Strike'),"Deadly below50%")
	b=fresh()
	u=ready(b,5,'Summon Piercing Automaton')
	var mp: float=u.mp
	b._cast(u,'Summon Piercing Automaton',5)
	check(u.automata.size()==1 and is_equal_approx(mp-u.mp,u.skills['Summon Piercing Automaton'].mp),"summon resource cost once")
	var other: Dictionary=b.teams.A[7]
	check(not b._ready_skill(other,'Summon Piercing Automaton'),"team-wide duplicate rejected")
	var other_mp: float=other.mp
	b._cast(other,'Summon Piercing Automaton',7)
	check(other.automata.size()==0 and other.mp==other_mp,"duplicate cast has no costs")
	var machine: Dictionary=u.automata[0]
	check(machine.multi_hit_rate==1 and is_equal_approx(machine.mhr_mod,.12) and is_equal_approx(machine.critical_chance,.12),"fixed automaton base plus selected upgrades")
	check(machine.penetration_chance==0 and machine.critical_damage_bonus==0 and machine.accuracy==1,"no inherited PEN CDB accuracy")
	check(is_equal_approx(machine.attack,u.attack),"SL5 inheritance100%")
	check(machine.attack_stun_count==1,"piercing stun upgrade")
	b._cast(u,'Summon Bombard Automaton',5)
	check(u.automata.size()==2,"different types coexist")
	b.global_turn=3
	u.stunned_until=8
	var hp: float=total_hp(b,'B')
	b._passives('A')
	check(total_hp(b,'B')<hp,"summons act even if owner stunned")
	b._take_hp(u,u.hp,b.teams.B[0])
	check(u.automata.is_empty() and not b._has_automaton('A','Summon Piercing Automaton'),"summons despawn on owner death")
	check(b._ready_skill(other,'Summon Piercing Automaton'),"cap released after owner death")
	b._cast(other,'Summon Piercing Automaton',7)
	check(other.automata.size()==1,"other Leonardo may summon replacement")
	check(is_equal_approx(other.automata[0].attack,other.attack*1.2),"SL7 inheritance120%")
	check(other.automata[0].critical_chance==0 and other.automata[0].mhr_mod==0,"healer summon has no inventor upgrades")
	b=fresh()
	u=ready(b,7,'Mona Lisa')
	b.teams.A[4].hp*=.3
	b._effect(b.teams.A[4],'test1',5,{'negative':true},b.teams.B[0])
	b._effect(b.teams.A[4],'test2',5,{'negative':true},b.teams.B[0])
	hp=b.teams.A[4].hp
	b._act(u)
	check(b.timeline[-1].name=='Mona Lisa' and b.teams.A[4].hp>hp,"low HP prioritizes Mona over summon")
	check(not b._has(b.teams.A[4],'test1') and not b._has(b.teams.A[4],'test2'),"Mona removes two oldest statuses")
	b=fresh()
	u=ready(b,3,'Grand Battery')
	b.teams.A[6].hp-=1000
	var ap: float=u.ap
	b._passives('A')
	check(b._has(b.teams.A[3],'battery') and b._has(b.teams.A[6],'battery'),"Grand Battery affects both Napoleons")
	check(not b._has(b.teams.A[0],'battery'),"Grand Battery only Devastators")
	check(b.teams.A[6].hp>b.teams.A[6].max_hp-1000 and u.ap==ap,"aura heal and no AP cost")
	b=fresh()
	u=ready(b,4,'God-King Slayer')
	b._cast(u,'God-King Slayer',0)
	check(b.teams.B[0].hp<b.teams.B[0].max_hp and b.teams.B[3].hp<b.teams.B[3].max_hp,"Slayer inherits Soldier area through selected node")
	b=fresh()
	u=b.teams.A[8]
	u.skills['Golden Arrow Shot'].remaining=0
	u.has_slot=true
	b._act(u)
	check(str(b.timeline[0].name).begins_with('Normal attack'),"Robin normal priority while Golden ready")
	b=fresh()
	u=ready(b,5,'Summon Piercing Automaton')
	b._cast(u,'Summon Piercing Automaton',5)
	for enemy in b.teams.B:
		if not enemy.main: enemy.hp=0
	b.teams.B[4].hp=.01
	ap=u.ap
	b.step()
	check(b.finished and b.winner=='A',"summon can end battle at turn start")
	check(u.ap==ap,"no AP recovery after passive kills main")
	check(not str(b.timeline[-1].name).begins_with('Start turn'),"no turn processing after battle end")
	b=fresh()
	var initial: Dictionary=b.teams.duplicate(true)
	var summons := 0
	var heals := 0
	while not b.finished and b.global_turn<300:
		var event: Dictionary=b.step()
		for action in event.actions:
			if str(action.name).begins_with('Summon '):summons+=1
			if action.name=='Mona Lisa':heals+=1
		for side in ['A','B']:
			var kinds := {}
			for unit in b.teams[side]:
				check(unit.hp>=0 and unit.hp<=unit.max_hp and unit.mp>=-.001,"resources legal")
				for auto in unit.automata:
					check(unit.hp>0,"summon owner living")
					check(not kinds.has(auto.summon_skill),"one per type per team through full battle")
					kinds[auto.summon_skill]=true
	check(summons>=4,"actual match summons both types both teams")
	check(heals>0,"actual match uses Mona Lisa")
	var report: Dictionary=Log.snapshot(b,{'match_id':'requested-test','seed':42,'first_team':'A'})
	var path := 'res://tests/requested-match.json'
	var file=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(report));file.close()
	print('REQUESTED_TEST_RESULT checks=',checks,' failures=',failures,' turns=',b.global_turn,' winner=',b.winner,' summons=',summons,' Mona=',heals)
	quit(1 if failures else 0)


