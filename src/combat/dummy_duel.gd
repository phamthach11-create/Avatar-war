extends RefCounted
## Deterministic rules for the approved one-versus-one Excel benchmark.
## No scene nodes, animation timing or asset dependencies belong in this module.

const CONFIG_PATH := "res://data/gameplay/balanced_dummy.json"

var global_turn: int = 0
var winner: String = ""
var finished: bool = false
var history: Array[Dictionary] = []
var _config: Dictionary
var _fighters: Dictionary = {}
var _next_team: String = "A"


static func load_config() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	assert(parsed is Dictionary, "The dummy configuration must be a JSON object.")
	return parsed


func _init(configuration: Dictionary, tie_winner: String = "A") -> void:
	_config = configuration.duplicate(true)
	assert(float(_config["power_constant"]) > 0.0)
	assert(float(_config["base_hp"]) > 0.0)
	assert(float(_config["stat_effectiveness"]) > 0.0)
	assert(float(_config["base_defense"]) >= 0.0)
	assert(float(_config["base_attack"]) >= 0.0)
	assert(float(_config["base_ap_recovery"]) >= 0.0)
	assert(float(_config["attack_ap_cost"]) >= 0.0)
	assert(float(_config["slot_ap_requirement"]) >= 0.0)
	assert(int(_config["max_global_turns"]) > 0)
	reset(tie_winner)


func reset(tie_winner: String = "A") -> void:
	assert(tie_winner in ["A", "B"])
	global_turn = 0
	winner = ""
	finished = false
	history.clear()
	_fighters.clear()
	var effectiveness: float = float(_config["stat_effectiveness"])
	for team in ["A", "B"]:
		var ap_key: String = "starting_ap_a" if team == "A" else "starting_ap_b"
		_fighters[team] = {
			"max_hp": float(_config["base_hp"]) * effectiveness,
			"hp": float(_config["base_hp"]) * effectiveness,
			"attack": float(_config["base_attack"]) * effectiveness,
			"defense": float(_config["base_defense"]) * effectiveness,
			"ap_recovery": float(_config["base_ap_recovery"]) * effectiveness,
			"ap": float(_config[ap_key]),
			"hits": 0,
		}
	# Initiative is determined before the first team's AP recovery.
	var a_ap: float = float(_fighters["A"]["ap"])
	var b_ap: float = float(_fighters["B"]["ap"])
	_next_team = "A" if a_ap > b_ap else ("B" if b_ap > a_ap else tie_winner)


func fighter(team: String) -> Dictionary:
	return _fighters[team].duplicate(true)


func next_team() -> String:
	return _next_team


func mitigation(team: String) -> float:
	var defense: float = float(_fighters[team]["defense"])
	return defense / (defense + float(_config["power_constant"]))


func step() -> Dictionary:
	if finished:
		return {}
	global_turn += 1
	var team: String = _next_team
	var target_team: String = "B" if team == "A" else "A"
	var actor: Dictionary = _fighters[team]
	var target: Dictionary = _fighters[target_team]
	var ap_before: float = float(actor["ap"])
	var recovered: float = float(actor["ap_recovery"])
	actor["ap"] = ap_before + recovered
	var slot_limit: int = 2 if global_turn <= 2 else (4 if global_turn <= 4 else 5)
	# One character can hold at most one initial slot, even when AP >= 200.
	var slots_assigned: int = 1 if float(actor["ap"]) >= float(_config["slot_ap_requirement"]) else 0
	var cost: float = 0.0
	var damage: float = 0.0
	var action: String = "Pass"
	if slots_assigned == 1:
		action = "Normal Attack"
		cost = float(_config["attack_ap_cost"])
		actor["ap"] = float(actor["ap"]) - cost
		var incoming: float = float(actor["attack"]) * (1.0 - mitigation(target_team))
		damage = minf(float(target["hp"]), maxf(0.0, incoming))
		target["hp"] = maxf(0.0, float(target["hp"]) - damage)
		actor["hits"] = int(actor["hits"]) + 1
		if float(target["hp"]) <= 0.0:
			winner = team
			finished = true
	if global_turn >= int(_config["max_global_turns"]):
		finished = true
	var result: String = "%s Wins" % winner if not winner.is_empty() else ("Turn limit reached" if finished else "Ongoing")
	var event: Dictionary = {
		"turn": global_turn,
		"team": team,
		"target": target_team,
		"slot_limit": slot_limit,
		"slots_assigned": slots_assigned,
		"action": action,
		"ap_before": ap_before,
		"ap_recovered": recovered,
		"ap_cost": cost,
		"ap_after": actor["ap"],
		"damage": damage,
		"hp_a": _fighters["A"]["hp"],
		"hp_b": _fighters["B"]["hp"],
		"ap_a": _fighters["A"]["ap"],
		"ap_b": _fighters["B"]["ap"],
		"hits_a": _fighters["A"]["hits"],
		"hits_b": _fighters["B"]["hits"],
		"result": result,
	}
	history.append(event)
	_next_team = target_team
	return event.duplicate(true)
