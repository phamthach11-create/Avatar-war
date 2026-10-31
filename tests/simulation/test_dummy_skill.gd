extends SceneTree
const Battle = preload("res://src/combat/squad_battle.gd")
const Base = preload("res://src/combat/dummy_duel.gd")
var checks := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		push_error(message)
		quit(1)
		assert(value, message)
func create_battle(config: Dictionary = {}, first: String = "A") -> RefCounted:
	return Battle.new(Base.load_config(), first, 42, Battle.load_skill_config() if config.is_empty() else config)
func _initialize() -> void:
	for first in ["A", "B"]:
		var enemy := "B" if first == "A" else "A"
		var battle = create_battle({}, first)
		check(battle.teams[first][0]["remaining_cooldown"] == 1, "Initial cooldown equals duration")
		var event: Dictionary = battle.step()
		check(event["actions"].size() == 2, "Initial slot cap remains two")
		check(event["turn_start_state"][first][0]["remaining_cooldown"] == 0, "First team recovers on its first turn")
		check(event["turn_start_state"][enemy][0]["remaining_cooldown"] == 1, "Second team has not recovered before its own first turn")
		for action in event["actions"]:
			check(action["kind"] == "skill" and action["damage"] == 1500.0, "SL10 special hit deals 1500 after skill defense")
			check(action["actor_mp_after"] == 19000.0 and action["actor_cd_after"] == 1, "MP and cooldown paid on use")
			check(action["actor_ap_after"] == 0.0, "AP cost is 100")
		var second: Dictionary = battle.step()
		check(second["turn_start_state"][enemy][0]["remaining_cooldown"] == 0, "Second team starts recovery on second global turn")
		for action in event["actions"]:
			check(second["turn_start_state"][first][action["actor"]]["remaining_cooldown"] == 0, "Both activated teams recover on later global turns")
		var casts: int = event["actions"].size() + second["actions"].size()
		while not battle.finished:
			var turn: Dictionary = battle.step()
			for action in turn["actions"]:
				check(action["damage"] > 0.0 and action["damage"] <= 1500.0, "Damage capped at remaining HP")
				if action["kind"] == "skill":
					casts += 1
			for team in ["A", "B"]:
				for unit in battle.teams[team]:
					check(unit["mp"] >= 0.0 and unit["remaining_cooldown"] >= 0 and unit["hp"] >= 0.0, "Resources stay valid")
		check(casts > 10 and not battle.winner.is_empty(), "Full skill battle ends with winner")
		check(battle.step().is_empty(), "No actions after battle end")
	var config := Battle.load_skill_config()
	config["skill"]["cooldown"] = 4
	var battle = create_battle(config)
	var first_event: Dictionary = battle.step()
	check(first_event["actions"][0]["kind"] == "attack", "Long initial cooldown falls back to normal attack")
	check(battle.teams["A"][0]["remaining_cooldown"] == 3 and battle.teams["B"][0]["remaining_cooldown"] == 4, "Staggered activation values")
	battle.step()
	check(battle.teams["A"][0]["remaining_cooldown"] == 2 and battle.teams["B"][0]["remaining_cooldown"] == 3, "Cooldown uses global turns")
	battle.change_remaining_cooldown("B", 0, -20)
	check(battle.teams["B"][0]["remaining_cooldown"] == 0 and battle.skill_ready("B", 0), "Immediate recovery clamps to zero")
	battle.change_remaining_cooldown("B", 0, 2)
	check(not battle.skill_ready("B", 0), "Immediate increase makes ready skill unavailable")
	# An already valid slot may use a skill again after immediate recovery.
	battle.change_remaining_cooldown("A", 0, -20)
	battle.teams["A"][0]["ap"] = 300.0
	var action: Dictionary = battle._resolve_action("A", 0, 0)
	battle.change_remaining_cooldown("A", 0, -4)
	check(battle.skill_ready("A", 0), "Recovery permits reuse without waiting")
	action = battle._resolve_action("A", 0, 0)
	check(action["actor_mp_after"] == 18000.0 and action["actor_cd_after"] == 4, "Reuse pays MP and resets cooldown")
	config = Battle.load_skill_config()
	config["skill"]["ap_cost"] = 250.0
	battle = create_battle(config)
	action = battle.step()["actions"][0]
	check(action["actor_ap_after"] == -150.0, "Skill AP can become negative")
	config = Battle.load_skill_config()
	config["base_mp"] = 999.0
	battle = create_battle(config)
	action = battle.step()["actions"][0]
	check(action["kind"] == "attack" and action["actor_mp_after"] == 999.0, "Insufficient MP falls back without spending MP")
	config = Battle.load_skill_config()
	config["skill"]["allocated_level"] = 5
	config["skill"]["level_bonus"] = 2
	battle = create_battle(config)
	action = battle.step()["actions"][0]
	check(action["damage"] == 1050.0, "Effective skill level includes flat bonuses")
	config = Battle.load_skill_config()
	battle = create_battle(config)
	for unit in battle.teams["B"]:
		unit["defense"] = 1000000.0
	check(battle.step()["actions"][0]["damage"] == 1500.0, "Skill uses skill defense, not normal defense")
	var defended_config := Base.load_config()
	defended_config["demo_defend"] = true
	battle = Battle.new(defended_config, "A", 42, Battle.load_skill_config())
	battle.teams["A"][0]["ap"] = 500.0
	var guard_turn: Dictionary = battle.step()
	check(guard_turn["slots_assigned"] == 2 and guard_turn["actions"].size() == 3, "Defend transfers one existing slot without adding initial slots")
	check(guard_turn["actions"][0]["kind"] == "defend" and guard_turn["actions"][0]["actor_ap_after"] == 550.0, "Defend costs 50 AP")
	check(battle.teams["A"][0]["defending"], "Guard status active")
	var response: Dictionary = battle.step()
	for hit in response["actions"]:
		if hit["kind"] == "skill":
			check(is_equal_approx(hit["damage"], 1200.0), "Defend boosts skill-defense effectiveness by 50 percent")
	var next_own_turn: Dictionary = battle.step()
	check(not next_own_turn["turn_start_state"]["A"][0]["defending"], "Defend expires at start of next own turn")
	battle = Battle.new(defended_config, "A", 42)
	battle.teams["A"][0]["ap"] = 500.0
	battle.step()
	response = battle.step()
	for hit in response["actions"]:
		if hit["kind"] == "attack":
			check(is_equal_approx(hit["damage"], 800.0), "Defend boosts normal-defense effectiveness")
	defended_config["base_ap_recovery"] = 0.0
	battle = Battle.new(defended_config, "A", 42)
	battle.teams["A"][0]["ap"] = 500.0
	battle.teams["A"][1]["ap"] = 100.0
	guard_turn = battle.step()
	check(guard_turn["actions"].size() == 2 and guard_turn["actions"][1]["kind"] == "attack", "Failed transfer ends only that slot, other slots still execute")
	print("Dummy skill checks passed: %d" % checks)
	quit(0)
