extends RefCounted
## Export battle events, not the screen's abbreviated text or Godot debug output.
const SCHEMA_VERSION := 1

static func unit_state(unit: Dictionary) -> Dictionary:
	var state: Dictionary = unit.duplicate(true)
	var cooldowns := {}
	for name in state.skills:
		cooldowns[name] = state.skills[name].remaining
	# Static descriptions belong in scenario.roster, not repeated at every hit.
	state.erase("skills")
	state.erase("nodes")
	state.erase("levels")
	state["cooldowns"] = cooldowns
	return state

static func states(teams: Dictionary) -> Dictionary:
	var result := {}
	for team in ["A","B"]:
		result[team] = []
		for unit in teams[team]:
			result[team].append(unit_state(unit))
	return result

static func changes(before: Dictionary, after: Dictionary) -> Array:
	var delta: Array = []
	for team in ["A","B"]:
		for index in range(after[team].size()):
			if before[team][index] != after[team][index]:
				delta.append({"team":team,"index":index,"state":after[team][index].duplicate(true)})
	return delta

static func snapshot(battle: RefCounted, metadata: Dictionary) -> Dictionary:
	var initial: Dictionary = battle.history[0].turn_start_state if not battle.history.is_empty() else battle.teams
	var current := states(initial)
	var turns: Array = []
	for event in battle.history:
		var start := states(event.turn_start_state)
		var turn := {"turn":event.turn,"team":event.team,"slot_limit":event.slot_limit,"result":event.result,"start_changes":changes(current,start),"actions":[]}
		current = start
		for action in event.actions:
			var after := states(action.state_after)
			var impacts: Array = []
			for impact in action.impacts:
				var item: Dictionary = impact.duplicate(true)
				item.target_state = unit_state(item.target_state)
				impacts.append(item)
			turn.actions.append({"team":action.team,"actor":action.actor,"target_team":action.target_team,"target":action.target,"name":action.name,"kind":action.kind,"impacts":impacts,"state_changes":changes(current,after)})
			current = after
		turns.append(turn)
	return {"schema_version":SCHEMA_VERSION,"exported_at_utc":Time.get_datetime_string_from_system(true),"metadata":metadata.duplicate(true),"scenario":battle.scenario.duplicate(true),"skills_enabled":battle.skill_mode,"status":"finished" if battle.finished else "in_progress","winner":battle.winner,"global_turn":battle.global_turn,"initial_state":states(initial),"turns":turns,"final_state":states(battle.teams),"indexing":"JSON unit indices are zero-based; text labels A1..A9/B1..B9 are one-based.","state_reconstruction":"Start with initial_state. Apply each turn's start_changes, then each action's state_changes in order. Each change replaces that unit's exported state. final_state is authoritative at export."}

static func text_report(data: Dictionary) -> String:
	var lines: Array[String] = ["AVATAR WAR — TEST BATTLE LOG","Match: %s" % data.metadata.get("match_id",""),"Started UTC: %s" % data.metadata.get("started_at_utc",""),"Exported UTC: %s" % data.exported_at_utc,"Status: %s | Winner: %s | Global turns: %d" % [data.status,data.winner if data.winner != "" else "none",data.global_turn],"Seed: %s | First team: %s | Skills: %s" % [str(data.metadata.get("seed",42)),data.metadata.get("first_team",""),str(data.skills_enabled)],"Design commit: %s" % data.scenario.source_commit,"Design blob: %s" % data.scenario.source_blob,"User clarifications: %s" % str(data.scenario.get("user_clarifications",[])),"MAIN: A%d / B%d" % [data.scenario.main_index+1,data.scenario.main_index+1],"","ROSTER / BUILDS"]
	for entry in data.scenario.roster:
		lines.append("%d. %s | Skills %s | Nodes %s" % [entry.index+1,entry.label,str(entry.levels),str(entry.nodes)])
	for turn in data.turns:
		lines.append("\nGLOBAL TURN %d | Team %s | Initial slot limit %d" % [turn.turn,turn.team,turn.slot_limit])
		for action in turn.actions:
			var target := "%s%d" % [action.target_team,action.target+1] if action.target >= 0 else "—"
			lines.append("  %s%d | %s | %s | Target %s" % [action.team,action.actor+1,action.kind,action.name,target])
			for impact in action.impacts:
				var label := "MISS" if not impact.landed else ("HEAL" if impact.damage < 0 else "HIT/EFFECT")
				lines.append("    %s%d %s %.2f | Crit %s | Pen %s | HP %.2f | MP %.2f | AP %.2f | Stacks %d | Stunned until T%d" % [impact.team,impact.target+1,label,absf(impact.damage),str(impact.critical),str(impact.penetrated),impact.target_state.hp,impact.target_state.mp,impact.target_state.ap,impact.target_state.stun_count,impact.target_state.stunned_until])
			for change in action.state_changes:
				var u: Dictionary = change.state
				lines.append("    State %s%d: HP %.2f MP %.2f AP %.2f | CD %s | Effects %s" % [change.team,change.index+1,u.hp,u.mp,u.ap,str(u.cooldowns),str(u.statuses)])
	lines.append("\nFINAL STATE")
	for team in ["A","B"]:
		for u in data.final_state[team]:
			lines.append("%s%d %s: HP %.2f/%.2f MP %.2f/%.2f AP %.2f" % [team,u.index+1,u.label,u.hp,u.max_hp,u.mp,u.max_mp,u.ap])
	return "\n".join(lines)+"\n"

static func save(path: String, battle: RefCounted, metadata: Dictionary) -> Error:
	var extension := path.get_extension().to_lower()
	if extension not in ["json","txt"]:
		return ERR_INVALID_PARAMETER
	var data := snapshot(battle,metadata)
	var text := JSON.stringify(data,"\t") if extension == "json" else text_report(data)
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.flush()
	var error := file.get_error()
	file.close()
	return error
