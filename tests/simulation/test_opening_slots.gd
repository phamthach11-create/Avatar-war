extends SceneTree
const Battle = preload("res://src/combat/requested_battle.gd")
const Rules = preload("res://src/combat/current_rules.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func config() -> Dictionary: return Battle.load_mixed_config()
func prepare(b: RefCounted, ap: float) -> void:
	for side in ["A","B"]:
		for u in b.teams[side]:
			u.ap=ap;u.ap_recovery=0;u.character_ap_recovery=0;u.attack=0;u.attack_stun_count=0
func actors(event: Dictionary) -> int:
	var seen := {}
	for a in event.actions:
		if a.kind=="attack":seen[a.actor]=true
	return seen.size()
func _initialize() -> void:call_deferred("run")
func run() -> void:
	for turn in range(1,21):check(Rules.initial_slot_limit(turn)==mini(5,turn+1),"2/3/4/5 then5")
	for first in ["A","B"]:
		var b=Battle.new(config(),first,42,false);prepare(b,1000)
		for turn in range(1,9):
			var event: Dictionary=b.step()
			check(event.slot_limit==mini(5,turn+1),"Cap follows global turn")
			check(event.team==(first if turn%2==1 else b._enemy(first)),"Rule independent of A/B label")
			check(actors(event)==event.slot_limit,"Actual initial allocations match cap when all eligible")
		b=Battle.new(config(),first,42,false);prepare(b,0)
		for turn in range(1,6):
			var event: Dictionary=b.step()
			check(actors(event)==0 and event.slot_limit==mini(5,turn+1),"No-action turns still advance opening sequence")
		b=Battle.new(config(),first,42,false);prepare(b,0)
		b.global_turn=1;b._next=first;b.teams[first][0].ap=1000
		var event: Dictionary=b.step()
		check(event.slot_limit==3 and actors(event)==1,"Maximum does not create extra eligible characters")
	print("OPENING_SLOTS_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
