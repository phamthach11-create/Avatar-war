extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var ui = load("res://src/ui/requested_9v9.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	assert(ui.requested_scenario and ui._duel.teams.A[7].main)
	assert(ui._duel.teams.A[4].character_id == "morgan_le_fay")
	ui.animation_speed = 0
	for _turn in range(10):
		ui._advance()
		await process_frame
	assert(ui._duel._has_automaton("A","Summon Bombard Automaton"))
	assert(ui._duel._has_automaton("B","Summon Piercing Automaton"))
	ui._show_builds()
	await process_frame
	var content = ui.find_child("BuildContent",true,false)
	assert(content != null and content.text.contains("MAIN: A8/B8"))
	ui.animation_speed = .01
	ui._advance()
	while ui._busy: await process_frame
	ui._advance()
	ui._restart()
	await create_timer(.25).timeout
	assert(not ui._busy and not ui._auto_running and ui._duel.global_turn == 0)
	ui.queue_free()
	await process_frame
	print("REQUESTED_HEADLESS_UI_PASS: scene, playback, builds, restart; no visual rendering claim")
	quit()
