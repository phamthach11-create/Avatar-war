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
	assert(ui._duel.teams.A[7].levels['Healing Hands']==6)
	assert(ui._duel.teams.A[4].character_id=='morgan_le_fay')
	assert(ui._duel.teams.A[7].main and not ui._duel.teams.A[4].main)
	assert(ui._duel.teams.A[7].character_id=='nightingale')
	assert(ui._duel.teams.A[4].skill_points==12 and ui._duel.teams.A[7].skill_points==12)
	ui.animation_speed=0
	for i in range(9):
		ui._advance()
		await process_frame
	assert(ui._duel._has_automaton('A','Summon Piercing Automaton'))
	assert(ui._duel._has_automaton('B','Summon Bombard Automaton'))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/requested-match-ui.png")
	# Exercise actual await/impact playback and cancellation, not only speed0.
	ui.animation_speed=.05
	var prior_count: int=ui._presented_actions
	ui._advance()
	while ui._busy: await process_frame
	var visible_events := 0
	for action in ui._duel.timeline:
		if action.kind!="system": visible_events+=1
	assert(ui._presented_actions==prior_count+visible_events)
	ui._advance()
	ui._restart()
	await create_timer(.25).timeout
	assert(not ui._busy and ui._duel.global_turn==0)
	ui._show_builds()
	await process_frame
	var build_content = ui.find_child("BuildContent",true,false)
	assert(build_content!=null and build_content.text.contains("MAIN: A8/B8"))
	assert(build_content.text.contains("Malediction: Stat Effectiveness +13%"))
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/requested-builds.png")
	ui._restart()
	assert(ui._duel.global_turn==0 and not ui._duel._has_automaton('A','Summon Piercing Automaton'))
	assert(not ui._auto_running)
	print('REQUESTED_UI_QA_PASS')
	quit()
