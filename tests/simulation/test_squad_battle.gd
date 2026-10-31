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
func _initialize() -> void:
	for first in ["A", "B"]:
		var battle = Battle.new(Base.load_config(), first)
		check(battle.teams["A"].size() == 9 and battle.teams["B"].size() == 9, "18 units")
		var previous_hp := 360000.0
		while not battle.finished:
			var event: Dictionary = battle.step()
			check(event["slot_limit"] == (2 if battle.global_turn <= 2 else (4 if battle.global_turn <= 4 else 5)), "Opening caps")
			var actors := {}
			for action in event["actions"]:
				check(not actors.has(action["actor"]), "At most one initial action per unit")
				actors[action["actor"]] = true
				check(action["damage"] == 1000.0, "Baseline damage")
			var hp := 0.0
			for team in ["A", "B"]:
				for unit in battle.teams[team]:
					check(unit["hp"] >= 0.0 and unit["ap"] >= 0.0, "Valid HP and AP")
					hp += unit["hp"]
			check(previous_hp - hp == 1000.0 * event["actions"].size(), "Damage conservation")
			previous_hp = hp
		check(not battle.winner.is_empty(), "Battle finishes with winner within cap")
		var enemy := "B" if battle.winner == "A" else "A"
		check(battle.teams[enemy][Battle.MAIN_INDEX]["hp"] == 0.0, "Victory requires dead main")
		check(battle.step().is_empty(), "No action after victory")
	var rich = Base.load_config()
	rich["base_ap_recovery"] = 200.0
	var battle = Battle.new(rich)
	check(battle.step()["actions"].size() == 2, "Extra AP does not create extra slots")
	var slow = Base.load_config()
	slow["base_ap_recovery"] = 0.0
	battle = Battle.new(slow)
	check(battle.step()["actions"].is_empty(), "No AP passes")
	battle = Battle.new(Base.load_config())
	battle.teams["A"][8]["ap"] = 500.0
	var first_event: Dictionary = battle.step()
	check(first_event["actions"][0]["actor"] == 8, "Highest AP prioritized")
	print("Squad battle checks passed: %d" % checks)
	quit(0)
