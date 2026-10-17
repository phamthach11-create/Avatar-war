extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed = load("res://src/ui/main.tscn") as PackedScene
	if packed == null:
		push_error("The main scene could not be loaded.")
		quit(1)
		return
	var scene = packed.instantiate()
	root.add_child(scene)
	await process_frame
	if scene._duel.global_turn != 0:
		push_error("The scene must open before the first turn.")
		quit(1)
		return
	scene._advance()
	await process_frame
	if scene._duel.global_turn != 1 or scene._duel.fighter("B")["hp"] != 19000.0:
		push_error("The Next turn action did not update the combat state.")
		quit(1)
		return
	scene._restart()
	if scene._duel.global_turn != 0 or scene._duel.fighter("B")["hp"] != 20000.0:
		push_error("Restart did not restore the initial state.")
		quit(1)
		return
	scene._initiative.select(1)
	scene._restart()
	while not scene._duel.finished:
		scene._advance()
		await process_frame
	if scene._duel.winner != "B" or scene._duel.global_turn != 39:
		push_error("The alternate initiative scene did not match the Excel benchmark.")
		quit(1)
		return
	if not scene._next_button.disabled or not scene._auto_button.disabled:
		push_error("The UI must disable battle actions after victory.")
		quit(1)
		return
	scene._restart()
	scene._toggle_auto()
	await create_timer(0.75).timeout
	if scene._duel.global_turn < 1:
		push_error("Auto mode did not advance the battle.")
		quit(1)
		return
	scene._restart()
	if not scene._timer.is_stopped():
		push_error("Restart must stop automatic play.")
		quit(1)
		return
	scene.queue_free()
	await process_frame
	print("Main scene checks passed: load, next turn, restart, initiative, victory and auto play.")
	quit(0)
