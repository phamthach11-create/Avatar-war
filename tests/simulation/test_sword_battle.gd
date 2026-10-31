extends SceneTree
const Battle = preload("res://src/combat/sword_battle.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
		quit(1)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var config := Battle.load_config()
	var b = Battle.new(config)
	check(b.teams.A.size() == 9 and b.teams.B.size() == 9, "18 fighters")
	check(b.teams.A[0].hp == 40000 and b.teams.A[0].attack == 2000, "total stats without weapon duplication")
	check(b.legal_targets("B") == [0,1,2], "three exposed lanes")
	b.teams.B[0].hp = 0
	check(b.legal_targets("B") == [3,1,2], "frontmost living in each lane")
	b = Battle.new(config)
	b.global_turn = 1
	b.add_stun_count("B", 0, 1)
	b.global_turn = 3
	b._begin_turn("A")
	check(b.teams.B[0].stun_count == 1, "stacks survive turn 3")
	b.global_turn = 4
	b._begin_turn("B")
	check(b.teams.B[0].stun_count == 0, "all stacks expire start turn 4")
	b.global_turn = 1
	b.add_stun_count("B", 0, 1)
	b.global_turn = 3
	b.add_stun_count("B", 0, 1)
	b.global_turn = 4
	b._begin_turn("B")
	check(b.teams.B[0].stun_count == 2, "new gain refreshes entire stack")
	b.global_turn = 6
	b._begin_turn("B")
	check(b.teams.B[0].stun_count == 0, "refreshed whole stack expires together")
	b = Battle.new(config)
	b.global_turn = 1
	b.add_stun_count("B", 0, 4)
	check(b.is_stunned("B",0) and b.teams.B[0].stun_count == 0, "threshold stuns and clears stacks")
	b.global_turn = 2
	b._begin_turn("B")
	check(b.teams.B[0].ap == 0, "stun blocks character AP recovery")
	b.add_stun_count("B",0,1)
	check(b.teams.B[0].stun_count == 0, "no stacks while stunned")
	b.global_turn = 3
	check(not b.is_stunned("B",0), "turn 1 stun expires start turn 3")
	b = Battle.new(config)
	b._begin_turn("A")
	check(b.teams.A[0].remaining_cooldown == 3 and b.teams.B[0].remaining_cooldown == 4, "first recovery staggered")
	b._begin_turn("B")
	check(b.teams.A[0].remaining_cooldown == 2 and b.teams.B[0].remaining_cooldown == 3, "both recover after activation")
	b.teams.A[0].remaining_cooldown = 0
	b.teams.A[0].has_slot = true
	var action: Dictionary = b.resolve_action("A",0,0)
	check(action.damage == 2400 and action.impacts.size() == 1, "skill damage and single hit")
	check(b.teams.A[0].mp == 39000 and b.teams.A[0].remaining_cooldown == 4, "skill cost and cooldown")
	var force := config.duplicate(true)
	force.multi_hit_rate = 3.0
	force.critical_chance = 1.0
	force.penetration_chance = 1.0
	b = Battle.new(force,"A",42,false)
	b.teams.A[0].has_slot = true
	action = b.resolve_action("A",0,0)
	check(action.impacts.size() == 3 and action.damage == 12000, "three independent critical penetrating hits")
	check(b.teams.A[0].ap == -100, "AP cost paid once and may go negative")
	b = Battle.new(force,"A",42,false)
	b.teams.A[0].has_slot = true
	b.teams.B[0].hp = 1
	action = b.resolve_action("A",0,0)
	check(action.impacts.size() == 1 and b.teams.B[3].hp == 40000, "no retarget after primary death")
	for first in ["A", "B"]:
		for seed_value in range(20):
			var fight = Battle.new(config,first,seed_value)
			while not fight.finished:
				var event: Dictionary = fight.step()
				for unit in fight.teams[event.team]:
					check(unit.hp >= 0 and unit.mp >= 0 and unit.stun_count < 4, "valid unit state")
			check(not fight.winner.is_empty(), "battle reaches main defeat")
	print("PASS new 9v9 rules: %d checks" % checks)
	var scene = load("res://src/ui/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.animation_speed = 0.0
	scene._sound_enabled = false
	scene._advance()
	check(not scene._busy and scene._duel.global_turn == 1, "UI presents full turn")
	scene._restart()
	check(scene._duel.global_turn == 0, "restart resets battle")
	for turn in range(12):
		scene._advance()
	check(scene._presented_actions > 20, "UI handles skills and multiple impacts")
	scene._restart()
	scene.animation_speed = 1.0
	scene._advance()
	await process_frame
	scene._restart()
	await create_timer(1.5).timeout
	check(scene._duel.global_turn == 0 and not scene._busy, "restart cancels pending impact")
	print("PASS UI lifecycle; total %d checks" % checks)
	quit()

