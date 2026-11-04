extends RefCounted
## Keep the raw combat timeline/log unchanged. Present one weapon hit as one AoE.
## Counterattacks/procs retain their relative order, after that hit's impact.
static func _apply_delta(current: Dictionary, before: Dictionary, after: Dictionary) -> void:
	for side in after:
		for i in range(after[side].size()):
			for key in after[side][i]:
				var next_value = after[side][i][key]
				var old_value = before[side][i].get(key)
				if next_value == old_value: continue
				if typeof(next_value) in [TYPE_INT,TYPE_FLOAT] and typeof(old_value) in [TYPE_INT,TYPE_FLOAT]:
					current[side][i][key] += next_value-old_value
				else:
					current[side][i][key] = after[side][i][key]

static func group(actions: Array, start_state: Dictionary) -> Array:
	var result: Array = []
	var state: Dictionary = start_state.duplicate(true)
	var before: Array = []
	var previous: Dictionary = start_state
	for action in actions:
		before.append(previous)
		previous = action.state_after
	var consumed := {}
	for index in range(actions.size()):
		if consumed.has(index): continue
		var source: Dictionary = actions[index]
		var action: Dictionary = source.duplicate(true)
		var members: Array[int] = [index]
		var key: String = str(source.get("weapon_hit_id",""))
		if source.kind == "attack" and not key.is_empty():
			for j in range(index+1,actions.size()):
				if actions[j].get("weapon_hit_id","") == key:
					members.append(j)
		action.impacts = []
		for j in members:
			consumed[j] = true
			_apply_delta(state,before[j],actions[j].state_after)
			action.impacts.append_array(actions[j].impacts.duplicate(true))
		# Rebased snapshots prevent early counter damage or HP rolling back after AoE.
		for impact in action.impacts:
			impact.target_state = state[impact.team][impact.target].duplicate(true)
		action.state_after = state.duplicate(true)
		action["source_action_count"] = members.size()
		result.append(action)
	return result
