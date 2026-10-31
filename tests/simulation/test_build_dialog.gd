extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://src/ui/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene._show_builds()
	await process_frame
	var dialog: AcceptDialog
	for child in scene.get_children():
		if child is AcceptDialog:
			dialog=child
	var content: RichTextLabel=dialog.get_node("BuildContent")
	assert(content.text.contains("9. Napoleon"))
	assert(dialog.size.y<=get_root().size.y-70)
	var scrollbar=content.get_v_scroll_bar()
	assert(scrollbar.max_value>scrollbar.page)
	scrollbar.value=scrollbar.max_value
	await process_frame
	print("PASS Build dialog scrolls to all 9 entries within viewport")
	scene.queue_free()
	await process_frame
	quit()

