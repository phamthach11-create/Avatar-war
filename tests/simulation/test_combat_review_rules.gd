extends SceneTree
const Battle = preload("res://src/combat/requested_battle.gd")
const Log = preload("res://src/combat/battle_log.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func fresh(first: String = "A") -> RefCounted:
	return Battle.new(Battle.load_mixed_config(),first,42,true)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	# Both initiative sides must receive Battery during their own attack opportunity.
	for first in ["A","B"]:
		var b = fresh(first)
		var casts := {"A":0,"B":0}
		for _turn in range(6):
			var event: Dictionary = b.step()
			for action in event.actions:
				if action.name == "Grand Battery":
					casts[action.team] += 1
					check(action.team == event.team,"Battery only casts on its allied turn")
					check(action.state_after[action.team][3].statuses.any(func(e: Dictionary) -> bool: return e.tag == "battery"),"Battery is active during the caster team's turn")
		check(casts.A == 2 and casts.B == 2,"Both sides cast twice in their first three team turns")
	# Stun affects only the imported Character source, never spec/death/item sources.
	var b = fresh()
	var u: Dictionary = b.teams.A[0]
	check(u.character_ap_recovery == 70 and u.ap_recovery == 86,"Bluetooth keeps base Character70 separate from spec16")
	b._take_hp(b.teams.A[6],1e9,b.teams.B[0])
	check(u.ap_recovery == 91 and u.character_ap_recovery == 70,"Death adds5 outside the Character source")
	b.global_turn = 9
	b._effect(u,"haste",8,{"apr_mod":.09},b.teams.A[7])
	for v in b.teams.A:
		v.ap = 0
		v.stunned_until = 20
	b.step()
	check(is_equal_approx(u.ap,21*1.09),"Stunned Bluetooth retains spec16 + death5, then Haste9%")
	check(is_equal_approx(b.teams.A[4].ap,13),"Stunned Morgan retains spec8 + death5")
	check(is_equal_approx(b.teams.A[1].ap,3),"Stunned Joan retains item-10 + spec8 + death5")
	u.stunned_until = 0
	b._next = "A"
	var old_ap: float = u.ap
	b.step()
	var recovered := -1.0
	for action in b.timeline:
		if str(action.name).begins_with("Start turn"): recovered = action.state_after.A[0].ap-old_ap
	check(is_equal_approx(recovered,91*1.09),"Character APR resumes on Stun expiration")
	# Refresh replaces duration, not magnitude/caster or remaining-duration arithmetic.
	b = fresh(); b.global_turn = 5
	u = b.teams.A[3]
	var target: Dictionary = b.teams.B[0]
	b._status_source = "Crushing Barrage"
	b._effect(target,"sunder",6,{"def_mod":-.58,"negative":true},u)
	b.global_turn = 9
	b._effect(target,"sunder",6,{"def_mod":-.90,"negative":true},b.teams.A[6])
	check(target.statuses.size() == 1 and target.statuses[0].expires == 15,"Repeated source resets expiry to end14, one instance")
	check(target.statuses[0].creator == 3 and is_equal_approx(target.statuses[0].def_mod,-.58),"Refresh preserves original caster and strength")
	check(target.statuses[0].applied == 5,"Refresh preserves order for oldest-status removal")
	b.global_turn = 10; b._end_turn()
	check(b._has(target,"sunder"),"Refreshed status survives its old expiration")
	b.global_turn = 14; b._end_turn()
	check(not b._has(target,"sunder"),"Refreshed status expires at end of new duration")
	b.global_turn = 15
	b._effect(target,"sunder",6,{"def_mod":-.90,"negative":true},b.teams.A[6])
	check(target.statuses[0].creator == 6,"After expiration a fresh application uses the new caster")
	b.global_turn = 16
	b._effect(target,"sunder",1,{"def_mod":-.3,"negative":true},u)
	check(target.statuses[0].expires == 17,"A shorter new duration replaces, not maximizes, remaining duration")
	b._status_source = "Other skill"
	b._effect(target,"sunder",3,{"def_mod":-.1,"negative":true},u)
	check(target.statuses.size() == 2,"Different source remains independent")
	# Actual War Cry and Back to Duty reapplications keep the corrected duration.
	b = fresh(); b.global_turn = 5
	b._cast(b.teams.A[2],"War Cry",0)
	b.global_turn = 9; b._cast(b.teams.A[2],"War Cry",0)
	for effect in b.teams.B[0].statuses:
		check(effect.expires == 15,"War Cry DOT/Falter both refresh to end14")
	b = fresh(); b.global_turn = 15
	b.teams.A[7].skills["Back to Duty"].remaining = 0
	b._cast(b.teams.A[7],"Back to Duty",4)
	b.global_turn = 21; b.teams.A[7].skills["Back to Duty"].remaining = 0
	b._cast(b.teams.A[7],"Back to Duty",4)
	var haste: Dictionary = b.teams.A[5].statuses[0]
	check(haste.expires == 29 and is_equal_approx(haste.apr_mod,.09),"Haste refresh lasts through28 without stacking")
	# Malediction cannot apply or refresh negative effects through Immunity.
	b = fresh(); b.global_turn = 10
	b._effect(b.teams.B[0],"immunity",4,{},b.teams.B[1])
	b._effect(b.teams.B[1],"invincible",4,{},b.teams.B[1])
	b.teams.A[4].skills["Malediction"].remaining = 0
	b._cast(b.teams.A[4],"Malediction",0)
	for i in [0,1]:
		check(not b.teams.B[i].statuses.any(func(e: Dictionary) -> bool: return e.get("negative",false)),"Protected row member receives no Malediction debuff")
	check(b._has(b.teams.B[2],"silence") and b._has(b.teams.B[2],"intimidated"),"Unprotected row member receives all effects")
	b.global_turn = 13; b._end_turn()
	b.global_turn = 14; b.teams.A[4].skills["Malediction"].remaining = 0
	b._cast(b.teams.A[4],"Malediction",0)
	check(b._has(b.teams.B[0],"silence"),"Malediction applies after Immunity expires")
	# A single queue must order summons and auto-casts by owner slot and sheet row.
	b = fresh(); b.global_turn = 10
	u = b.teams.A[5]
	b._summon(u,"Summon Bombard Automaton")
	b._summon(u,"Summon Piercing Automaton") # Deliberately reverse sheet order.
	u.skills["Grand Battery"] = b.teams.A[3].skills["Grand Battery"].duplicate(true)
	u.levels["Grand Battery"] = 5; u.skills["Grand Battery"].remaining = 0
	b.teams.A[3].skills["Grand Battery"].remaining = 0
	b.teams.B[3].skills["Grand Battery"].remaining = 0
	b.teams.A[8].skills["Maiden’s Care"] = b.teams.A[1].skills["Maiden’s Care"].duplicate(true)
	b.teams.A[8].levels["Maiden’s Care"] = 5
	b.teams.A[8].skills["Maiden’s Care"].remaining = 0
	b._passives("A")
	var sequence: Array[String] = []
	for action in b.timeline:
		check(action.team == "A","Opponent Battery cannot run ahead of allied summons")
		var key := str(int(action.actor))+":"+str(action.name)
		if sequence.is_empty() or sequence[-1] != key: sequence.append(key)
	check(sequence == ["3:Grand Battery","5:Piercing Automaton · Coordinated attack","5:Grand Battery","5:Bombard Automaton · Coordinated attack","8:Maiden’s Care"],"Owner slot order and design-sheet order interleave machines and auto-casts")
	# Export a new regression match, while also exercising both initiative sides.
	for first in ["A","B"]:
		b = fresh(first)
		while not b.finished:
			var event: Dictionary = b.step()
			for action in event.actions:
				if action.name == "Grand Battery": check(action.team == event.team,"Full-match allied-turn Battery")
				for side in ["A","B"]:
					for v in action.state_after[side]:
						check(v.hp >= 0 and v.hp <= v.max_hp and v.mp >= 0,"Legal resources after every event")
		check(not b.winner.is_empty(),"Complete regression match ends with a winner")
		print("REVIEW_MATCH first=",first," turn=",b.global_turn," winner=",b.winner)
		if first == "A":
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/combat-rules-20261105"))
			check(Log.save("res://artifacts/combat-rules-20261105/match.json",b,{"seed":42,"first_team":first,"purpose":"combat-rule regression"}) == OK,"Export corrected demo log")
	print("COMBAT_REVIEW_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
