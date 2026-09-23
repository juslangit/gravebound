extends SceneTree
## Contact sheets show every source frame as cropped, anchored and mirrored in game.
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	root.content_scale_size = Vector2i(1440, 1500)
	root.size = Vector2i(1440, 1500)
	var board = load("res://tests/animation_board.gd").new()
	root.add_child(board)
	for mode in ["attack", "run"]:
		board.mode = mode
		board.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/shots/animation_" + mode + ".png")
	board.queue_free()
	await process_frame
	quit()
