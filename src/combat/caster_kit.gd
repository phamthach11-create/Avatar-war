extends RefCounted
## Only the selected Nightingale Matron / Morgan Enchantress builds. No fallback kits.
static func apply_build(u: Dictionary) -> void:
	var n: Array = u.nodes
	match str(u.get("character_id","")):
		"nightingale":
			for node in n: assert(node in ["S2","S2.1.1","S2.2.1","S2.2.2","S2.2.3","S2.2.4"],"Unimplemented Nightingale node")
			for name in u.levels: assert(name in ["Healing Hands","Back to Duty"],"Unimplemented Nightingale skill")
			if n.has("S2.1.1"): u.max_hp += 4000
			if n.has("S2.2.1"): u.skill_defense += 275
			if n.has("S2.2.2"): u.max_hp += 1500
			if n.has("S2.2.4"):
				assert(n.has("S2.2.3"),"Matron Cross prerequisite")
				u.skills["Back to Duty"].area = "Cross"
		"morgan_le_fay":
			for node in n: assert(node in ["S2","S2.1.1","S2.2.1","S2.2.2","S2.2.3","S2.2.4"],"Unimplemented Morgan node")
			for name in u.levels: assert(name in ["Fae Starfall","Malediction"],"Unimplemented Morgan skill")
			if n.has("S2.1.1"): u.ap_recovery += 8
			if n.has("S2.2.1"): u.max_hp += 5847
			if n.has("S2.2.2"): u.skills["Malediction"]["effectiveness"] = 1.13
			if n.has("S2.2.3"): u.skills["Fae Starfall"]["effectiveness"] = 1.13
			if n.has("S2.2.4"): u.skills["Fae Starfall"].cd -= 2
		_:
			assert(false,"Unimplemented Caster character")
	u["mp_without_veil"] = u.max_mp
	if u.get("character_id","") == "morgan_le_fay":
		u.max_mp *= 1.0 + .02 * int(u.levels.get("Avalon’s Veil",0))

static func handles(name: String) -> bool:
	return name in ["Healing Hands","Back to Duty","Fae Starfall","Malediction"]

static func cast(b: RefCounted, u: Dictionary, name: String, primary: int) -> void:
	var skill: Dictionary = u.skills[name]
	var level: int = u.levels[name]
	var side: String = b._enemy(u.side) if name in ["Fae Starfall","Malediction"] else u.side
	var shape: String = "All Enemies" if name == "Fae Starfall" else str(skill.area)
	var impacts: Array = []
	for i in b._area(primary,shape):
		if b.finished: break
		var recipient: Dictionary = b._unit(side,i)
		if recipient.hp <= 0: continue
		if name == "Fae Starfall":
			impacts.append(b._damage(u,recipient,skill.satk*level/5.0*skill.get("effectiveness",1.0),false))
		elif name == "Malediction":
			var effectiveness: float = skill.get("effectiveness",1.0)
			b._effect(recipient,"dot:Malediction",skill.duration,{"power":skill.satk*level/5.0*effectiveness,"penalty":0.0,"double_at_one":false,"negative":true},u)
			b._effect(recipient,"silence",skill.duration,{"negative":true},u)
			b._effect(recipient,"intimidated",skill.duration,{"attack_mod":-.04*level*effectiveness,"negative":true},u)
			impacts.append(b._impact(side,i,0))
		else:
			impacts.append(b._heal(u,recipient,skill.satk*level/5.0))
			if name == "Back to Duty":
				b._effect(recipient,"haste",skill.duration,{"apr_mod":.03+.01*level},u)
				# Capture the status too, not just the pre-Haste healing state.
				impacts[-1].target_state = recipient.duplicate(true)
	b._record(u,name,primary,side,impacts)
