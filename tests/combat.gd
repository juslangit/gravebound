extends SceneTree
## Exercise real input handlers, release timing, fan geometry, collision and resets.
var game
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run_checks")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
	else:
		print("PASS ", message)

func click(position: Vector2, button: int, shift := false) -> void:
	var e := InputEventMouseButton.new()
	e.position = position
	e.button_index = button
	e.pressed = true
	e.shift_pressed = shift
	game._input(e)

func run_checks() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.muted = true
	check(game.attack_atlas != null and game.run_atlas != null and game.axial_atlas != null and game.walk_atlas != null, "all four painted animation atlases load")
	check(game.targets.size() == 5, "five dummies available immediately")
	for p in [Vector2.ZERO, Vector2(1040, 1040), Vector2(217, 841)]:
		check(game.unproject(game.project(p)).distance_to(p) < .01, "isometric click projection round trip")
	var before: Vector2 = game.player
	click(game.project(before + Vector2(100, 60)) - game.camera, MOUSE_BUTTON_LEFT)
	game.tick(.10)
	check(game.player.distance_to(before) > 10, "left click moves ranger")
	check(game.shots_fired == 0, "movement click never fires")
	click(Vector2(950, 440), MOUSE_BUTTON_LEFT, true)
	check(game.attack_count == 1 and game.attack_time == 0, "Shift-left click begins single shot")
	before = game.player
	game.tick(.40)
	check(game.arrows_fired == 0, "no arrow before bow release")
	check(game.player == before, "drawing bow stops movement")
	check(not game.start_attack(5, before + Vector2(200, 0)), "drawing cannot be interrupted by an extra attack")
	game.tick(.04)
	check(game.arrows_fired == 1 and game.arrows.size() == 1, "single release creates exactly one arrow")
	for i in range(20): game.tick(.05)
	check(game.arrows_fired == 1, "one click cannot trigger repeat firing")
	game.arrows.clear()
	click(Vector2(1030, 450), MOUSE_BUTTON_RIGHT)
	var cursor_world: Vector2 = game.unproject(Vector2(1030, 450) + game.camera + Vector2(0, game.ARROW_HEIGHT))
	check(game.shot_direction.distance_to(game.player.direction_to(cursor_world)) < .001, "aim compensates for arrow height above the floor")
	game.tick(.44)
	check(game.arrows.size() == 5, "right click creates exactly five simultaneous arrows")
	var angles: Array[float] = []
	for arrow in game.arrows: angles.append(arrow.v.angle())
	check(absf(angle_difference(angles[0], angles[4]) - deg_to_rad(32)) < .001, "five-arrow fan spans 32 degrees")
	check(absf(angle_difference(angles[2], game.shot_direction.angle())) < .001, "middle arrow aims exactly at cursor")
	game.attack_time = -1
	game.reset_targets()
	game.player = Vector2(520, 420)
	game.destination = game.player
	game.camera = game.project(game.player) - Vector2(720, 490)
	var t: Dictionary = game.targets[1]
	click(game.project(t.p) - game.camera - Vector2(0, 71), MOUSE_BUTTON_LEFT)
	check(game.attack_time == 0, "ordinary left click on dummy attacks it")
	for i in range(18): game.tick(.05)
	check(t.hp == 75 and game.hits == 1, "single arrow hits dummy for 25 damage")
	for n in range(3):
		game.start_attack(1, t.p)
		for i in range(18): game.tick(.05)
	check(t.hp == 0, "four hits disable dummy")
	for i in range(60): game.tick(.05)
	check(t.hp == 100, "disabled dummy automatically resets")
	game.player = Vector2(70, 70)
	game.destination = Vector2(42, 42)
	for i in range(100): game.tick(.05)
	check(game.player.x >= 42 and game.player.y >= 42, "ranger respects courtyard boundary")
	game.destination = game.player
	game.arrows.clear()
	game.start_attack(1, Vector2(-1000, -1000))
	for i in range(60): game.tick(.05)
	check(game.arrows.is_empty(), "arrows expire at courtyard boundary")
	game.player = Vector2(520, 330)
	game.destination = Vector2(520, 110)
	for i in range(90): game.tick(.025)
	check(game.player.distance_to(game.destination) < 8, "click movement steers around dummy")
	var last_destination: Vector2 = game.destination
	click(Vector2(500, 850), MOUSE_BUTTON_LEFT)
	check(game.destination == last_destination, "combat bar clicks do not move player")
	click(Vector2(500, 40), MOUSE_BUTTON_RIGHT)
	check(game.attack_time < 0, "header clicks do not fire")
	game.paused = true
	check(not game.start_attack(1, Vector2(900, 900)), "paused game rejects attacks")
	game.paused = false
	game.start_attack(1, Vector2(900, 900))
	game.reset_targets()
	check(game.shots_fired == 0 and game.hits == 0 and game.arrows.is_empty(), "reset clears shot statistics and projectiles")
	check(game.attack_time < 0, "reset also cancels a drawing bow")
	print("RESULT ", checks - failures, "/", checks, " checks passed")
	quit(1 if failures else 0)
