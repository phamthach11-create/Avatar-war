extends SceneTree
const Battle = preload("res://src/combat/mixed_battle.gd")
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func fresh() -> RefCounted:
	return Battle.new(Battle.load_mixed_config())
func ready_skill(b: RefCounted, side: String, i: int, name: String) -> Dictionary:
	var u: Dictionary = b.teams[side][i]
	u.skills[name].remaining = 0
	u.has_slot = true
	return u
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var b = fresh()
	check(b.teams.A.size()==9 and b.teams.B.size()==9,"9 per team")
	check(b.teams.A[4].main and b.teams.B[4].main,"same random main in both teams")
	for side in ["A","B"]:
		var cannons := 0
		for u in b.teams[side]:
			if u.type == "Devastator":
				cannons += 1
			var points := 0
			for level in u.levels.values():
				points += level
			check(points<=u.skill_points,"SP legal")
		check(cannons == 2,"two Napoleons")
	check(b.teams.A[0].defense*(1+b.teams.A[0].def_mod)>3800,"tank build defense")
	check(b.teams.A[4].accuracy==1 and b.teams.A[1].accuracy==1 and b.teams.B[4].evasion==0,"user correction: Leonidas Accuracy100/Evasion0")
	b.step()
	check(b.teams.A[4].skills["God-King Slayer"].remaining==4 and b.teams.B[4].skills["God-King Slayer"].remaining==4,"both teams recover at END global1")
	b = fresh()
	b.global_turn = 1
	b.add_stun_count("B",0,1)
	b.add_stun_count("B",0,1)
	check(b.teams.B[0].stun_count==1,"one stack per global turn")
	b.global_turn = 2
	b.add_stun_count("B",0,1)
	b.global_turn = 3
	b._end_turn()
	check(b.teams.B[0].stun_count==2,"gain turn2 refreshes whole stack")
	b.global_turn = 4
	b._end_turn()
	check(b.teams.B[0].stun_count==0,"whole stack expires end gain+2")
	b = fresh()
	for turn in range(1,5):
		b.global_turn = turn
		b.add_stun_count("B",2,1)
	check(b.is_stunned("B",2),"threshold triggers")
	b.global_turn = 6
	check(b.is_stunned("B",2),"stun active through third turn")
	b.global_turn = 7
	check(not b.is_stunned("B",2),"stun expires at next boundary")
	b = fresh()
	b.global_turn = 6
	var u := ready_skill(b,"A",0,"Holy Blade")
	b._cast(u,"Holy Blade",0)
	check(b.teams.B[0].hp<b.teams.B[0].max_hp and b.teams.B[3].hp<b.teams.B[3].max_hp,"Holy Blade primary and behind target")
	check(b.teams.B[1].hp==b.teams.B[1].max_hp,"Holy Blade no unrelated lane")
	check(b.teams.B[0].stun_count==1,"Holy Blade explicit stack")
	check(u.mp==u.max_mp-u.skills["Holy Blade"].mp,"skill MP once")
	b = fresh()
	u = ready_skill(b,"A",5,"Mona Lisa")
	b.teams.A[0].hp -= 10000
	b.teams.A[1].hp -= 10000
	b._effect(b.teams.A[0],"test",3,{"negative":true},b.teams.B[0])
	b._cast(u,"Mona Lisa",0)
	check(b.teams.A[0].hp>b.teams.A[0].max_hp-10000 and b.teams.A[1].hp>b.teams.A[1].max_hp-10000,"Mona Lisa heals all allies")
	check(not b._has(b.teams.A[0],"test"),"oldest negative status removed")
	b = fresh()
	u = ready_skill(b,"A",6,"Crushing Barrage")
	b.global_turn = 6
	b._cast(u,"Crushing Barrage",0)
	check(b.timeline[-1].impacts.size()==9,"Barrage all enemies")
	check(b.teams.B[0].hp==b.teams.B[0].max_hp,"Barrage has no invented direct strike")
	b._end_turn()
	check(b.teams.B[0].hp<b.teams.B[0].max_hp,"DOT includes casting turn")
	check(b._has(b.teams.B[0],"sunder"),"Sunder applied")
	b = fresh()
	u = ready_skill(b,"A",1,"War Cry")
	b.global_turn = 4
	b._cast(u,"War Cry",0)
	check(u.ap == -125,"expensive cast allows AP debt")
	check(b.teams.B[0].multi_hit_rate+b._sum(b.teams.B[0],"mhr_flat")<1,"War Cry reduces MHR before floor")
	b = fresh()
	u = ready_skill(b,"A",6,"Imperial Decree")
	b.teams.A[8].mp=0
	b._cast(u,"Imperial Decree",8)
	check(b.teams.A[8].mp==20000,"selected Decree node restores MP")
	check(b._has(b.teams.A[8],"decree"),"Decree adds follow-up trigger")
	b = fresh()
	u = ready_skill(b,"A",2,"Frozen Axe")
	b._cast(u,"Frozen Axe",0)
	check(b._blocked(b.teams.B[0]) and b._blocked(b.teams.B[1]) and b._blocked(b.teams.B[2]),"Frozen full front row immobilized")
	check(not b._blocked(b.teams.B[3]),"Frozen only target row")
	b = fresh()
	var archer: Dictionary=b.teams.A[7]
	archer.accuracy=1
	archer.critical_chance=0
	archer.multi_hit_rate=1
	b.teams.B[1].levels["Phalanx"]=25
	var hp: float=b.teams.B[1].hp
	b._normal(archer,1)
	check(b.teams.B[1].hp==hp,"Phalanx blocks ranged normal damage")
	b = fresh()
	for side in ["A","B"]:
		for index in [1,4]:
			var enemy: String = "B" if side == "A" else "A"
			var attacker: Dictionary = b.teams[side][index]
			var victim: Dictionary = b.teams[enemy][2]
			var before: float = victim.hp
			b._normal(attacker,2)
			check(victim.hp<before,"Leonidas normal attack deals damage for each side/build")
	var results: Array = []
	for side in ["A","B"]:
		for seed_value in range(3):
			b = Battle.new(Battle.load_mixed_config(),side,seed_value)
			while not b.finished:
				b.step()
				b.history.clear()
				for owner in ["A","B"]:
					for fighter in b.teams[owner]:
						check(fighter.hp>=0 and fighter.hp<=fighter.max_hp and fighter.mp>=0 and fighter.mp<=fighter.max_mp,"valid resources through battle")
			results.append([side,seed_value,b.winner,b.global_turn])
			check(b.finished,"battle terminates")
	print("BATTLES ",results)
	var scene = load("res://src/ui/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.animation_speed=0
	scene._sound_enabled=false
	for turn in range(12):
		scene._advance()
	check(not scene._busy and scene._duel.global_turn==12,"UI handles multi-recipient skills and DOT")
	scene._restart()
	scene.animation_speed=0.5
	scene._advance()
	await process_frame
	scene._restart()
	await create_timer(1).timeout
	check(not scene._busy and scene._duel.global_turn==0,"Restart cancels in-flight spell/attack")
	scene.queue_free()
	await process_frame
	await process_frame
	print("MIXED TEST ",checks," checks; failures ",failures)
	quit(1 if failures>0 else 0)
