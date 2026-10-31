extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://src/ui/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	assert(scene._duel.teams.A.size()==9)
	assert(scene._duel.teams.A[4].main and scene._duel.teams.B[4].main)
	scene._sound_enabled=false
	scene.animation_speed=0
	for turn in range(6):
		scene._advance()
	assert(scene._duel.global_turn==6 and not scene._busy)
	scene._restart()
	assert(scene._duel.global_turn==0)
	scene.queue_free()
	await process_frame
	print("PASS mixed main scene")
	quit()
