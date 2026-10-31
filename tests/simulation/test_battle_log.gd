extends SceneTree
const Battle = preload("res://src/combat/mixed_battle.gd")
const Log = preload("res://src/combat/battle_log.gd")
var checks := 0
var failures := 0
var output := ProjectSettings.globalize_path("res://artifacts").path_join("avatar-war-log-export-tests").path_join(str(OS.get_process_id())+"-"+str(Time.get_ticks_usec()))+"/"
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	check(DirAccess.make_dir_recursive_absolute(output)==OK,"test output directory")
	var b=Battle.new(Battle.load_mixed_config(),"B",42)
	var meta={"match_id":"test-match","seed":42,"first_team":"B","started_at_utc":"test"}
	check(Log.save(output+"empty.json",b,meta)==OK,"zero-turn export")
	var empty=JSON.parse_string(FileAccess.get_file_as_string(output+"empty.json"))
	check(empty.turns.is_empty() and empty.status=="in_progress","empty state truthful")
	while not b.finished:
		b.step()
	var count: int=b.history.size()
	var rng_state: int=b._rng.state
	check(Log.save(output+"finished.json",b,meta)==OK,"finished JSON export")
	check(Log.save(output+"finished.txt",b,meta)==OK,"finished TXT export")
	check(b.history.size()==count and b._rng.state==rng_state,"export never changes battle or RNG")
	var data=JSON.parse_string(FileAccess.get_file_as_string(output+"finished.json"))
	check(data.turns.size()==count and data.winner==b.winner and data.status=="finished","export matches completed result")
	var state: Dictionary=data.initial_state.duplicate(true)
	var impacts := 0
	var misses := 0
	var healing := 0
	var dots := 0
	for turn in data.turns:
		for change in turn.start_changes:
			state[change.team][int(change.index)]=change.state
		for action in turn.actions:
			if action.kind=="dot":
				dots+=1
			for hit in action.impacts:
				impacts+=1
				if not hit.landed:
					misses+=1
				if hit.damage<0:
					healing+=1
				check(hit.target_state.has("cooldowns") and hit.target_state.has("statuses"),"impact includes cooldown and effects")
			for change in action.state_changes:
				state[change.team][int(change.index)]=change.state
	for team in ["A","B"]:
		for i in range(9):
			check(state[team][i]==data.final_state[team][i],"state deltas reconstruct final state")
	check(impacts>100 and misses>0 and healing>0 and dots>0,"actual hits misses heals DOT exported")
	var text=FileAccess.get_file_as_string(output+"finished.txt")
	check(text.contains("GLOBAL TURN") and text.contains("MISS") and text.contains("HEAL") and text.contains("Crushing Barrage") and text.contains("FINAL STATE"),"readable log includes important events")
	check(Log.save(output+"invalid.csv",b,meta)==ERR_INVALID_PARAMETER,"unsupported formats rejected")
	var scene=load("res://src/ui/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene._sound_enabled=false
	scene.animation_speed=0.0
	scene._advance()
	check(scene._export_log_to(output+"partial.json")==OK,"UI partial export")
	var partial=JSON.parse_string(FileAccess.get_file_as_string(output+"partial.json"))
	check(partial.global_turn==1 and partial.status=="in_progress","partial match clearly identified")
	var id: String=scene._match_metadata.match_id
	scene._restart()
	check(scene._match_metadata.match_id!=id,"restart gets distinct match identity")
	check(scene._export_log_to(output+"stale.json",id)==ERR_SKIP,"stale export request rejected")
	scene._toggle_auto()
	scene._request_export()
	check(not scene._auto_running and scene._export_dialog.visible,"save dialog pauses Auto")
	scene._restart()
	check(not scene._export_dialog.visible,"restart closes stale dialog")
	scene.animation_speed=1.0
	scene._advance()
	check(scene._busy and scene._export_button.disabled,"export disabled during pending playback")
	check(scene._export_log_to(output+"busy.json")==ERR_BUSY,"unpresented turn never exported")
	scene._restart()
	await create_timer(1).timeout
	scene.queue_free()
	await process_frame
	await process_frame
	print("PASS LOG EXPORT: ",checks," checks, failures ",failures,"; turns ",count,"; impacts ",impacts,"; JSON bytes ",FileAccess.get_file_as_bytes(output+"finished.json").size())
	quit(1 if failures>0 else 0)
