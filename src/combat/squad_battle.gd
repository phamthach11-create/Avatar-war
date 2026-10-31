extends RefCounted
## 9v9 configurable skill test. Front row first; rear-center main determines victory.
const Base = preload("res://src/combat/dummy_duel.gd")
const MAIN_INDEX := 7
var global_turn: int = 0
var winner: String = ""
var finished: bool = false
var history: Array[Dictionary] = []
var teams: Dictionary = {}
var _next: String = "A"
var _config: Dictionary
var _rng := RandomNumberGenerator.new()
var _skill_config: Dictionary = {}
var _recovery_started := {"A": false, "B": false}

static func load_skill_config() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/gameplay/dummy_skill.json"))
	assert(parsed is Dictionary, "Skill configuration must be an object")
	return parsed

func _init(config: Dictionary, first: String = "A", seed_value: int = 42, skill_configuration: Dictionary = {}) -> void:
	_config = config.duplicate(true)
	_skill_config = skill_configuration.duplicate(true)
	_rng.seed = seed_value
	var duel = Base.new(config, first)
	_next = duel.next_team()
	for team in ["A", "B"]:
		teams[team] = []
		for index in range(9):
			var unit: Dictionary = duel.fighter(team)
			unit["index"] = index
			unit["main"] = index == MAIN_INDEX
			unit["max_mp"] = float(_skill_config.get("base_mp", 0.0))
			unit["mp"] = unit["max_mp"]
			unit["skill_defense"] = float(_skill_config.get("base_skill_defense", unit["defense"]))
			unit["skill_level"] = int(_skill_config.get("skill", {}).get("allocated_level", 0)) + int(_skill_config.get("skill", {}).get("level_bonus", 0))
			unit["defending"] = false
			unit["defend_until"] = 0
			unit["remaining_cooldown"] = int(_skill_config.get("skill", {}).get("cooldown", 0))
			teams[team].append(unit)

func next_team() -> String:
	return _next

func living(team: String) -> int:
	var count := 0
	for unit in teams[team]:
		if unit["hp"] > 0.0:
			count += 1
	return count

func target_index(team: String) -> int:
	# Row-major: front row 0..2, middle 3..5, back 6..8.
	for index in range(9):
		if teams[team][index]["hp"] > 0.0:
			return index
	return -1

func change_remaining_cooldown(team: String, index: int, change: int) -> void:
	var unit: Dictionary = teams[team][index]
	unit["remaining_cooldown"] = maxi(0, int(unit["remaining_cooldown"]) + change)

func skill_ready(team: String, index: int) -> bool:
	if _skill_config.is_empty():
		return false
	var unit: Dictionary = teams[team][index]
	var skill: Dictionary = _skill_config["skill"]
	return unit["hp"] > 0.0 and unit["skill_level"] > 0 and unit["remaining_cooldown"] == 0 and unit["mp"] >= skill["mp_cost"]

func _recover_cooldowns(acting_team: String) -> void:
	_recovery_started[acting_team] = true
	for team in ["A", "B"]:
		if not _recovery_started[team]:
			continue
		for unit in teams[team]:
			if unit["hp"] > 0.0:
				change_remaining_cooldown(team, unit["index"], -1)

func _resolve_action(team: String, index: int, target: int) -> Dictionary:
	var enemy := "B" if team == "A" else "A"
	var actor: Dictionary = teams[team][index]
	var victim: Dictionary = teams[enemy][target]
	var uses_skill := skill_ready(team, index)
	var skill: Dictionary = _skill_config.get("skill", {})
	var ap_cost: float = float(skill["ap_cost"]) if uses_skill else float(_config["attack_ap_cost"])
	var attack: float = float(_config["power_constant"]) * actor["skill_level"] * float(skill["attack_per_k_per_level"]) if uses_skill else float(actor["attack"])
	var defense: float = float(victim["skill_defense"]) if uses_skill else float(victim["defense"])
	if victim["defending"]:
		defense *= 1.5
	var mitigation: float = defense / (defense + float(_config["power_constant"]))
	var damage := minf(victim["hp"], maxf(0.0, attack * (1.0 - mitigation)))
	if uses_skill:
		# Assign cooldown at commitment, before resolving any on-use effects.
		actor["remaining_cooldown"] = int(skill["cooldown"])
		actor["mp"] -= float(skill["mp_cost"])
	actor["ap"] -= ap_cost
	actor["hits"] += 1
	victim["hp"] = maxf(0.0, victim["hp"] - damage)
	return {"actor": index, "target": target, "damage": damage, "target_hp_after": victim["hp"], "actor_ap_after": actor["ap"], "actor_mp_after": actor["mp"], "actor_cd_after": actor["remaining_cooldown"], "kind": "skill" if uses_skill else "attack", "name": str(skill["name"]) if uses_skill else "Normal Attack"}

func _defend(team: String, index: int) -> Dictionary:
	var unit: Dictionary = teams[team][index]
	unit["ap"] -= 50.0
	unit["defending"] = true
	unit["defend_until"] = global_turn + 2
	return {"actor": index, "target": index, "damage": 0.0, "actor_ap_after": unit["ap"], "actor_mp_after": unit["mp"], "actor_cd_after": unit["remaining_cooldown"], "kind": "defend", "name": "Defend", "defend_until": unit["defend_until"]}

func step() -> Dictionary:
	if finished:
		return {}
	global_turn += 1
	for status_team in ["A", "B"]:
		for unit in teams[status_team]:
			if unit["defending"] and global_turn >= unit["defend_until"]:
				unit["defending"] = false
	var team := _next
	var enemy := "B" if team == "A" else "A"
	_recover_cooldowns(team)
	var cap := 2 if global_turn <= 2 else (4 if global_turn <= 4 else 5)
	var eligible: Array = []
	for unit in teams[team]:
		if unit["hp"] <= 0.0:
			continue
		unit["ap"] += unit["ap_recovery"]
		if unit["ap"] >= _config["slot_ap_requirement"]:
			eligible.append({"index": unit["index"], "ap": unit["ap"], "tie": _rng.randf()})
	eligible.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["ap"] > b["ap"] if a["ap"] != b["ap"] else a["tie"] > b["tie"])
	var assigned := mini(cap, eligible.size())
	var holders: Array[int] = []
	for slot in range(assigned):
		holders.append(int(eligible[slot]["index"]))
	var turn_start_state: Dictionary = teams.duplicate(true)
	var actions: Array[Dictionary] = []
	for slot in range(assigned):
		var index: int = eligible[slot]["index"]
		var actor: Dictionary = teams[team][index]
		if slot == 0 and bool(_config.get("demo_defend", false)):
			actions.append(_defend(team, index))
			var recipient := -1
			for candidate in eligible:
				var candidate_index: int = candidate["index"]
				if not holders.has(candidate_index) and not teams[team][candidate_index]["defending"] and teams[team][candidate_index]["ap"] >= 100.0:
					recipient = candidate_index
					break
			if recipient < 0:
				continue
			index = recipient
		var target := target_index(enemy)
		if target < 0:
			break
		actions.append(_resolve_action(team, index, target))
		if teams[enemy][MAIN_INDEX]["hp"] <= 0.0:
			finished = true
			winner = team
			break
	if global_turn >= int(_config["max_global_turns"]):
		finished = true
	var event := {"turn": global_turn, "team": team, "enemy": enemy, "slot_limit": cap, "slots_assigned": assigned, "actions": actions, "turn_start_state": turn_start_state, "result": ("Team %s wins" % winner if not winner.is_empty() else ("Turn limit reached" if finished else "Ongoing"))}
	history.append(event.duplicate(true))
	_next = enemy
	return event
