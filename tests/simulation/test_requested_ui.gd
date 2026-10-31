extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var ui = load("res://src/ui/requested_9v9.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	assert(ui.requested_scenario)
	assert(ui._duel.teams.A[0].type=="Destroyer")
	assert(ui._duel.teams.A[7].levels['Mona Lisa']==10)
	ui.animation_speed=0
	for i in range(9):
		ui._advance()
		await process_frame
	assert(ui._duel._has_automaton('A','Summon Piercing Automaton'))
	assert(ui._duel._has_automaton('B','Summon Bombard Automaton'))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/requested-match-ui.png")
	ui._show_builds()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/requested-builds.png")
	ui._restart()
	assert(ui._duel.global_turn==0 and not ui._duel._has_automaton('A','Summon Piercing Automaton'))
	assert(not ui._auto_running)
	print('REQUESTED_UI_QA_PASS')
	quit()
