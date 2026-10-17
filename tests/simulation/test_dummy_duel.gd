extends SceneTree

const Duel = preload("res://src/combat/dummy_duel.gd")
var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	var base: Dictionary = Duel.load_config()
	for first in ["A", "B"]:
		var duel = Duel.new(base, first)
		while not duel.finished:
			var event: Dictionary = duel.step()
			check(event["slots_assigned"] == 1, "One initial slot per dummy")
			check(is_equal_approx(float(event["damage"]), 1000.0), "Baseline hit is 1000 damage")
			check(is_zero_approx(float(event["ap_a"])) and is_zero_approx(float(event["ap_b"])), "Only acting team recovers and spends 100 AP")
		check(duel.winner == first, "Tie winner wins the symmetric duel")
		check(duel.global_turn == 39, "Baseline ends on global turn 39")
		check(duel.fighter(first)["hits"] == 20, "Winner lands 20 hits")
		check(duel.fighter(first)["hp"] == 1000.0, "Winner retains 1000 HP")
		var loser: String = "B" if first == "A" else "A"
		check(duel.fighter(loser)["hits"] == 19, "Loser lands 19 hits")
		check(duel.fighter(loser)["hp"] == 0.0, "Loser reaches zero HP")
		check(duel.step().is_empty() and duel.global_turn == 39, "No actions after victory")
		check(duel.history[0]["slot_limit"] == 2 and duel.history[2]["slot_limit"] == 4 and duel.history[4]["slot_limit"] == 5, "Opening slot caps are 2-2-4-4-5")
		duel.reset(first)
		check(duel.global_turn == 0 and duel.history.is_empty(), "Reset clears the battle")
		check(duel.fighter("A")["hp"] == 20000.0, "Reset restores HP")
	var slow: Dictionary = base.duplicate(true)
	slow["base_ap_recovery"] = 50.0
	var waiting = Duel.new(slow)
	check(waiting.step()["action"] == "Pass", "Insufficient AP passes A's first turn")
	check(waiting.step()["action"] == "Pass", "Insufficient AP passes B's first turn")
	check(waiting.step()["action"] == "Normal Attack", "Accumulated AP enables A's next turn")
	while not waiting.finished:
		waiting.step()
	check(waiting.global_turn == 79 and waiting.winner == "A", "AP waiting matches Excel's 79-turn case")
	var zero: Dictionary = base.duplicate(true)
	zero["base_ap_recovery"] = 0.0
	var stalled = Duel.new(zero)
	while not stalled.finished:
		stalled.step()
	check(stalled.global_turn == 100 and stalled.winner.is_empty(), "Turn limit stops a no-AP battle without inventing a winner")
	check(stalled.fighter("A")["hp"] == 20000.0, "Passing deals no damage")
	var initiative: Dictionary = base.duplicate(true)
	initiative["starting_ap_b"] = 50.0
	var faster = Duel.new(initiative, "A")
	check(faster.next_team() == "B", "Higher Starting AP overrides the selected tie winner")
	check(faster.step()["ap_before"] == 50.0, "Initiative uses AP before recovery")
	var rich: Dictionary = base.duplicate(true)
	rich["base_ap_recovery"] = 200.0
	var extra_ap = Duel.new(rich)
	var first_event: Dictionary = extra_ap.step()
	check(first_event["slots_assigned"] == 1 and extra_ap.fighter("A")["hits"] == 1, "200 AP does not create a second initial slot")
	check(extra_ap.fighter("A")["ap"] == 100.0, "Unused AP carries forward")
	check(base["base_ap_recovery"] == 100.0, "Test scenarios do not mutate shared configuration")
	print("Combat checks: %d passed, %d failed" % [checks - failures, failures])
	quit(0 if failures == 0 else 1)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
