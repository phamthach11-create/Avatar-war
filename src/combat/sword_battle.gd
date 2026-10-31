extends "res://src/combat/squad_battle.gd"
## Current 9v9 rules. Legacy simulations remain separate regression fixtures.

static func load_config() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/gameplay/dummy_9v9.json"))
	assert(parsed is Dictionary)
	return parsed

func _init(config: Dictionary, first: String = "A", seed_value: int = 42, skills_enabled: bool = true) -> void:
	var skills: Dictionary = config.duplicate(true) if skills_enabled else {}
	super(config, first, seed_value, skills)
	for team in ["A", "B"]:
		for unit in teams[team]:
			unit["max_mp"] = float(config["base_mp"])
			unit["mp"] = unit["max_mp"]
			unit["skill_defense"] = float(config["base_skill_defense"])
			unit["stun_count"] = 0
			unit["last_stack_turn"] = -1
			unit["stunned_until"] = 0
			unit["has_slot"] = false

func is_stunned(team: String, index: int) -> bool:
	return int(teams[team][index]["stunned_until"]) > global_turn

func legal_targets(team: String) -> Array[int]:
	var result: Array[int] = []
	for lane in range(3):
		for depth in range(3):
			var index := depth * 3 + lane
			if teams[team][index]["hp"] > 0.0:
				result.append(index)
				break
	return result

func target_index(team: String) -> int:
	var legal := legal_targets(team)
	return -1 if legal.is_empty() else legal[_rng.randi_range(0, legal.size() - 1)]

func skill_ready(team: String, index: int) -> bool:
	return not is_stunned(team, index) and super.skill_ready(team, index)

func _roll(chance: float) -> bool:
	return _rng.randf() < clampf(chance, 0.0, 1.0)

func add_stun_count(team: String, index: int, amount: int) -> void:
	var unit: Dictionary = teams[team][index]
	if amount <= 0 or unit["hp"] <= 0.0 or is_stunned(team, index):
		return
	unit["stun_count"] += amount
	unit["last_stack_turn"] = global_turn
	if unit["stun_count"] >= int(_config["stun_threshold"]):
		unit["stun_count"] = 0
		unit["stunned_until"] = global_turn + int(_config["stun_global_turns"])
		unit["has_slot"] = false

func _begin_turn(team: String) -> void:
	for owner in ["A", "B"]:
		for unit in teams[owner]:
			unit["has_slot"] = false
			if unit["defending"] and global_turn >= unit["defend_until"]:
				unit["defending"] = false
			if unit["stun_count"] > 0 and global_turn >= int(unit["last_stack_turn"]) + 3:
				unit["stun_count"] = 0
	_recover_cooldowns(team)
	for unit in teams[team]:
		if unit["hp"] <= 0.0:
			continue
		var gain: float = unit["ap_recovery"]
		if is_stunned(team, unit["index"]):
			gain = maxf(0.0, gain - float(_config["character_ap_recovery"]))
		unit["ap"] += gain

func resolve_action(team: String, index: int, target: int) -> Dictionary:
	var enemy := "B" if team == "A" else "A"
	var actor: Dictionary = teams[team][index]
	assert(actor["hp"] > 0.0 and actor["has_slot"] and not is_stunned(team, index))
	assert(legal_targets(enemy).has(target), "Warrior primary target must be exposed")
	var uses_skill := skill_ready(team, index)
	var skill: Dictionary = _skill_config.get("skill", {})
	var skill_attack: float = float(_config["power_constant"]) * actor["skill_level"] * float(skill.get("attack_per_k_per_level", 0.0))
	var count := 1
	if uses_skill:
		actor["remaining_cooldown"] = int(skill["cooldown"])
		actor["mp"] -= float(skill["mp_cost"])
		actor["ap"] -= float(skill["ap_cost"])
	else:
		actor["ap"] -= float(_config["attack_ap_cost"])
		var rate: float = float(_config["multi_hit_rate"])
		count = int(floor(rate)) + (1 if _roll(rate - floor(rate)) else 0)
	actor["has_slot"] = false
	var impacts: Array[Dictionary] = []
	var total := 0.0
	for hit_index in range(count):
		var victim: Dictionary = teams[enemy][target]
		# Single area remains at the original position, even after the primary dies.
		if finished or victim["hp"] <= 0.0:
			break
		var landed := _roll(float(_config["accuracy"]) - float(_config["evasion"]))
		var penetrated := false
		var critical := false
		var damage := 0.0
		if landed:
			penetrated = not uses_skill and _roll(float(_config["penetration_chance"]))
			critical = not uses_skill and _roll(float(_config["critical_chance"]))
			var defense: float = victim["skill_defense"] if uses_skill else victim["defense"]
			if victim["defending"]:
				defense *= 1.5
			var mitigation := 0.0 if penetrated else defense / (defense + float(_config["power_constant"]))
			var attack: float = skill_attack if uses_skill else float(actor["attack"])
			var multiplier := 1.0 + float(_config["critical_damage_bonus"]) if critical else 1.0
			damage = minf(victim["hp"], maxf(0.0, attack * (1.0 - mitigation) * multiplier))
			victim["hp"] -= damage
			actor["hits"] += 1
			add_stun_count(enemy, target, int(skill.get("stun_count", 0)) if uses_skill else int(_config["attack_stun_count"]))
			total += damage
		impacts.append({"target": target, "damage": damage, "landed": landed, "critical": critical, "penetrated": penetrated, "target_state": victim.duplicate(true), "hit_index": hit_index + 1})
		if victim["main"] and victim["hp"] <= 0.0:
			winner = team
			finished = true
	return {"actor": index, "target": target, "kind": "skill" if uses_skill else "attack", "name": str(skill["name"]) if uses_skill else "Normal Attack", "damage": total, "impacts": impacts, "planned_hits": count, "actor_state": actor.duplicate(true), "actor_ap_after": actor["ap"], "actor_mp_after": actor["mp"], "actor_cd_after": actor["remaining_cooldown"]}

func step() -> Dictionary:
	if finished:
		return {}
	global_turn += 1
	var team: String = _next
	var enemy := "B" if team == "A" else "A"
	_begin_turn(team)
	var cap := 2 if global_turn <= 2 else (4 if global_turn <= 4 else 5)
	var eligible: Array[Dictionary] = []
	for unit in teams[team]:
		if unit["hp"] > 0.0 and not is_stunned(team, unit["index"]) and unit["ap"] >= _config["slot_ap_requirement"]:
			eligible.append({"index": unit["index"], "ap": unit["ap"], "tie": _rng.randf()})
	eligible.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["ap"] > b["ap"] if a["ap"] != b["ap"] else a["tie"] > b["tie"])
	var assigned := mini(cap, eligible.size())
	for slot in range(assigned):
		teams[team][eligible[slot]["index"]]["has_slot"] = true
	var start: Dictionary = teams.duplicate(true)
	var actions: Array[Dictionary] = []
	for slot in range(assigned):
		if finished:
			break
		var index: int = eligible[slot]["index"]
		if not teams[team][index]["has_slot"] or is_stunned(team, index):
			continue
		if slot == 0 and bool(_config.get("demo_defend", false)):
			var guard: Dictionary = _defend(team, index)
			teams[team][index]["has_slot"] = false
			guard["actor_state"] = teams[team][index].duplicate(true)
			actions.append(guard)
			var recipient := -1
			for candidate in eligible:
				var candidate_index: int = candidate["index"]
				var unit: Dictionary = teams[team][candidate_index]
				if not unit["has_slot"] and not unit["defending"] and unit["hp"] > 0.0 and not is_stunned(team, candidate_index) and unit["ap"] >= 100.0:
					recipient = candidate_index
					break
			if recipient < 0:
				continue
			index = recipient
			teams[team][index]["has_slot"] = true
		var target := target_index(enemy)
		if target < 0:
			break
		actions.append(resolve_action(team, index, target))
	if global_turn >= int(_config["max_global_turns"]):
		finished = true
	var result := "Team %s wins" % winner if not winner.is_empty() else ("Turn limit reached" if finished else "Ongoing")
	var event := {"turn": global_turn, "team": team, "enemy": enemy, "slot_limit": cap, "slots_assigned": assigned, "turn_start_state": start, "actions": actions, "result": result}
	history.append(event.duplicate(true))
	_next = enemy
	return event
