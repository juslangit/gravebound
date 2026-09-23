extends SceneTree
## Captures the actual game renderer, including the default first playable state.
var game

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	root.size = Vector2i(1440, 900)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.cursor = Vector2(950, 420)
	await shot("default")
	game.start_attack(5, game.player + Vector2(600, -100))
	game.tick(0.35)
	await shot("draw")
	game.tick(0.13)
	await shot("volley")
	game.attack_time = -1
	game.destination = game.player + Vector2(-100, -100)
	game.tick(0.12)
	await shot("run")
	game.queue_free()
	await process_frame
	quit()

func shot(name: String) -> void:
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/shots/" + name + ".png")
	print("CAPTURE ", name)
